"""Reject non-owner PR changes using only trusted base code and GitHub metadata."""
import json
import os
from pathlib import Path
import re
import urllib.parse
import urllib.request

PROJECT = Path(__file__).resolve().parent.parent
CONFIG_PATH = PROJECT / '.github/contributors-ownership.json'


def policy():
    return json.loads(CONFIG_PATH.read_text())


def protected_changes(files, config):
    def protected(path):
        path = path.casefold().rstrip('/')
        for rule in config['protected_paths']:
            target = rule.casefold().rstrip('/')
            if path == target or target.startswith(path + '/'):
                return True
            if rule.endswith('/') and path.startswith(target + '/'):
                return True
        return False

    changed = set()
    for record in files:
        # Renaming or deleting a protected file is also a modification.
        for field in ('filename', 'previous_filename'):
            path = record.get(field)
            if path and protected(path):
                changed.add(path)
    return sorted(changed)


def assess(pr, files, config):
    changed = protected_changes(files, config)
    if not changed:
        return True, 'No owner-only files changed'
    owner_id = config['owner_user_id']
    source = (pr.get('head') or {}).get('repo') or {}
    # PR identity comes from GitHub authentication, never from commit email,
    # labels, approvals, the rerunning actor, or editable contribution data.
    if ((pr.get('user') or {}).get('id') == owner_id
            and (source.get('owner') or {}).get('id') == owner_id
            and source.get('full_name') == config['repository']
            and re.fullmatch(re.escape(config['owner_branch_prefix']) + r'[A-Za-z0-9][A-Za-z0-9._-]*',
                             pr['head'].get('ref') or '')):
        return True, 'Owner-authored PR from the protected owner branch'
    return False, 'Only ' + config['owner_login'] + ' may modify contributor-page files'


class GitHub:
    def __init__(self, token):
        self.token = token

    def request(self, path, body=None):
        request = urllib.request.Request(
            'https://api.github.com/' + path,
            data=None if body is None else json.dumps(body).encode(),
            headers={
                'Authorization': 'Bearer ' + self.token,
                'Accept': 'application/vnd.github+json',
                'Content-Type': 'application/json',
                'User-Agent': 'frameapp-ownership-check',
                'X-GitHub-Api-Version': '2022-11-28',
            },
        )
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)


def pull_files(api, repository, number, expected):
    if type(expected) is not int or not 0 <= expected <= 3000:
        raise ValueError('PR file list exceeds the API limit; split the PR')
    files = []
    page = 1
    while len(files) < expected:
        records = api.request(f'repos/{repository}/pulls/{number}/files?per_page=100&page={page}')
        if not isinstance(records, list) or not records:
            raise ValueError('Incomplete PR file list')
        files.extend(records)
        page += 1
        if page > 31:
            raise ValueError('PR file list exceeds the API limit')
    if len(files) != expected:
        raise ValueError('PR changed while listing files')
    return files


def verify_source_branch(api, pr, config):
    """Prevent another writer from adding commits to an owner-authored PR."""
    repository = config['repository']
    ref = urllib.parse.quote(pr['head']['ref'], safe='')
    active_rules = api.request(f'repos/{repository}/rules/branches/{ref}')
    candidates = {}
    for rule in active_rules:
        if rule.get('ruleset_source_type') == 'Repository' and rule.get('ruleset_source') == repository:
            candidates.setdefault(rule['ruleset_id'], set()).add(rule['type'])
    for ruleset_id, types in candidates.items():
        if not {'creation', 'update', 'deletion'}.issubset(types):
            continue
        ruleset = api.request(f'repos/{repository}/rulesets/{ruleset_id}')
        bypass = [{'actor_id': config['owner_user_id'], 'actor_type': 'User', 'bypass_mode': 'always'}]
        expected_conditions = {'ref_name': {
            'include': ['refs/heads/' + config['owner_branch_prefix'] + '*'], 'exclude': [],
        }}
        if (ruleset.get('enforcement') == 'active' and ruleset.get('target') == 'branch'
                and ruleset.get('bypass_actors') == bypass
                and ruleset.get('conditions') == expected_conditions
                and {'creation', 'update', 'deletion'}.issubset(
                    {rule['type'] for rule in ruleset.get('rules', [])})):
            return
    raise ValueError('Source branch must restrict creation, updates and deletion to the owner')


def run_check(event, api, config, target_url):
    repository = config['repository']
    if event['repository']['full_name'] != repository:
        raise ValueError('This check is only for the configured repository')
    number = event['pull_request']['number']
    sha = event['pull_request']['head']['sha']
    if type(number) is not int or number < 1 or not re.fullmatch(r'[a-f0-9]{40}', sha):
        raise ValueError('Invalid PR metadata')

    def status(state, description):
        api.request(f'repos/{repository}/statuses/{sha}', {
            'state': state, 'context': config['status_context'],
            'description': description[:140], 'target_url': target_url,
        })

    status('pending', 'Checking owner-only contributor-page changes')
    try:
        pr = api.request(f'repos/{repository}/pulls/{number}')
        if (pr['base']['ref'] != config['base_branch']
                or pr['base']['repo']['full_name'] != repository):
            raise ValueError('PR must target the protected branch in the owner repository')
        if pr['head']['sha'] != sha:
            raise ValueError('Outdated PR event; the current revision needs its own check')
        files = pull_files(api, repository, number, pr['changed_files'])
        allowed, reason = assess(pr, files, config)
        if allowed and protected_changes(files, config):
            verify_source_branch(api, pr, config)
        current = api.request(f'repos/{repository}/pulls/{number}')
        if (current['head']['sha'] != sha
                or current['base']['sha'] != pr['base']['sha']
                or current['base']['ref'] != pr['base']['ref']
                or current['base']['repo']['full_name'] != repository
                or current['changed_files'] != pr['changed_files']):
            raise ValueError('PR changed during validation')
        allowed, reason = assess(current, files, config)
        status('success' if allowed else 'failure', reason)
        print(reason)
        # JSON encoding avoids interpreting a filename as a workflow command.
        if not allowed:
            print(json.dumps({'restricted_files': protected_changes(files, config)}))
        return allowed
    except Exception:
        status('error', 'Unable to verify ownership; check must pass before merging')
        raise


def main():
    if os.environ.get('GITHUB_EVENT_NAME') != 'pull_request_target':
        raise SystemExit('Only trusted pull_request_target metadata is supported')
    config = policy()
    event = json.loads(Path(os.environ['GITHUB_EVENT_PATH']).read_text())
    target = (os.environ['GITHUB_SERVER_URL'] + '/' + config['repository']
              + '/actions/runs/' + os.environ['GITHUB_RUN_ID'])
    if not run_check(event, GitHub(os.environ['GH_TOKEN']), config, target):
        raise SystemExit(1)


if __name__ == '__main__':
    main()
