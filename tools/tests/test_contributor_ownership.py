import copy
from contextlib import redirect_stdout
import io
import json
import sys
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from check_contributor_ownership import assess, policy, protected_changes, pull_files, run_check

CONFIG = policy()
HEAD = 'a' * 40
BASE = 'b' * 40


def pull(owner=False):
    return {
        'number': 7,
        'user': {'id': CONFIG['owner_user_id'] if owner else 123, 'login': 'someone'},
        'head': {'sha': HEAD, 'ref': 'owner-contributors', 'repo': {
            'full_name': CONFIG['repository'],
            'owner': {'id': CONFIG['owner_user_id'] if owner else 123},
        }},
        'base': {'sha': BASE, 'ref': 'main', 'repo': {'full_name': CONFIG['repository']}},
        'changed_files': 1,
    }


def event():
    return {'repository': {'full_name': CONFIG['repository']}, 'pull_request': pull()}


class FakeAPI:
    def __init__(self, pr, files, after=None):
        self.pr = copy.deepcopy(pr)
        self.after = copy.deepcopy(after or pr)
        self.files = files
        self.statuses = []
        self.reads = 0
        self.pages = []
        self.branch_policy = json.loads((Path(__file__).resolve().parents[2]
                                         / '.github/rulesets/owner-branches.json').read_text())
        self.branch_rules = [{
            'type': rule['type'], 'ruleset_id': 8, 'ruleset_source_type': 'Repository',
            'ruleset_source': CONFIG['repository'],
        } for rule in self.branch_policy['rules']]

    def request(self, path, body=None):
        if body is not None:
            self.statuses.append((path, body))
            return {}
        if '/files?' in path:
            page = int(path.split('page=')[-1])
            self.pages.append(page)
            return self.files[(page - 1) * 100:page * 100]
        if '/rules/branches/' in path:
            return self.branch_rules
        if '/rulesets/' in path:
            return self.branch_policy
        self.reads += 1
        return copy.deepcopy(self.pr if self.reads == 1 else self.after)


class OwnershipTests(unittest.TestCase):
    def run_guard(self, api, metadata=None):
        with redirect_stdout(io.StringIO()):
            return run_check(metadata or event(), api, CONFIG, 'https://github.com/example/run')

    def test_contributor_can_change_app_code(self):
        self.assertTrue(assess(pull(), [{'filename': 'lib/core/composition.dart'}], CONFIG)[0])

    def test_all_restricted_paths_reject_add_modify_and_delete(self):
        for rule in CONFIG['protected_paths']:
            filename = rule + 'nested/file' if rule.endswith('/') else rule
            for status in ['added', 'modified', 'removed']:
                with self.subTest(filename=filename, status=status):
                    self.assertFalse(assess(pull(), [{'filename': filename, 'status': status}], CONFIG)[0])

    def test_only_authenticated_owner_from_owner_repository_passes(self):
        files = [{'filename': 'policies/community.json'}]
        self.assertTrue(assess(pull(owner=True), files, CONFIG)[0])
        for author, source_owner in [(123, CONFIG['owner_user_id']), (CONFIG['owner_user_id'], 123)]:
            pr = pull(owner=True)
            pr['user']['id'] = author
            pr['head']['repo']['owner']['id'] = source_owner
            self.assertFalse(assess(pr, files, CONFIG)[0])

    def test_owner_cannot_use_an_unprotected_branch_or_different_repository(self):
        for ref, repository in [('feature-page', CONFIG['repository']),
                                ('owner-nested/page', CONFIG['repository']),
                                ('owner-page', 'lianjiehao/another-repo')]:
            pr = pull(owner=True)
            pr['head']['ref'] = ref
            pr['head']['repo']['full_name'] = repository
            self.assertFalse(assess(pr, [{'filename': 'policies/community.json'}], CONFIG)[0])

    def test_display_name_sender_and_editable_confirmation_do_not_grant_access(self):
        pr = pull()
        pr.update(sender={'id': CONFIG['owner_user_id']}, confirmed_by=CONFIG['owner_login'])
        pr['user']['login'] = CONFIG['owner_login']
        self.assertFalse(assess(pr, [{'filename': 'policies/community.json'}], CONFIG)[0])

    def test_missing_author_or_deleted_source_repository_is_rejected(self):
        for field in ['user', 'repo']:
            pr = pull(owner=True)
            if field == 'user':
                pr['user'] = None
            else:
                pr['head']['repo'] = None
            self.assertFalse(assess(pr, [{'filename': 'policies/community.json'}], CONFIG)[0])

    def test_renames_cannot_move_protected_files_out_or_in(self):
        for record in [
            {'filename': 'unrestricted.json', 'previous_filename': 'policies/community.json'},
            {'filename': 'policies/community.json', 'previous_filename': 'unrestricted.json'},
            {'filename': 'moved.yml', 'previous_filename': '.github/workflows/ci.yml'},
        ]:
            self.assertFalse(assess(pull(), [record], CONFIG)[0])

    def test_case_variations_and_directory_replacement_are_protected(self):
        for path in ['POLICIES/COMMUNITY.JSON', 'policies', 'tools', '.GITHUB', 'assets/legal', 'lib/services']:
            self.assertEqual(protected_changes([{'filename': path}], CONFIG), [path])
        self.assertEqual(protected_changes([{'filename': 'policies/community.json.backup'}], CONFIG), [])

    def test_new_modules_cannot_shadow_trusted_tool_imports(self):
        for path in ['tools/json.py', 'tools/subprocess.py', 'tools/community/__init__.py']:
            self.assertFalse(assess(pull(), [{'filename': path}], CONFIG)[0])

    def test_files_after_first_page_cannot_escape_check(self):
        pr = pull()
        files = [{'filename': 'lib/file' + str(i) + '.dart'} for i in range(100)]
        files.append({'filename': 'policies/community.json'})
        pr['changed_files'] = len(files)
        api = FakeAPI(pr, files)
        self.assertFalse(self.run_guard(api))
        self.assertEqual(api.pages, [1, 2])
        self.assertEqual([item[1]['state'] for item in api.statuses], ['pending', 'failure'])

    def test_api_limit_and_incomplete_file_lists_fail_closed(self):
        for expected in [3001, -1, '1', True, 2]:
            with self.subTest(expected=expected), self.assertRaises(ValueError):
                pull_files(FakeAPI(pull(), [{'filename': 'lib/main.dart'}]), CONFIG['repository'], 7, expected)

    def test_api_failure_does_not_leave_a_success_status(self):
        class UnavailableAPI(FakeAPI):
            def request(self, path, body=None):
                if body is None:
                    raise ConnectionError('GitHub unavailable')
                return super().request(path, body)

        api = UnavailableAPI(pull(owner=True), [{'filename': 'policies/community.json'}])
        with self.assertRaises(ConnectionError):
            self.run_guard(api)
        self.assertEqual([item[1]['state'] for item in api.statuses], ['pending', 'error'])

    def test_required_status_is_written_to_exact_pr_head(self):
        api = FakeAPI(pull(owner=True), [{'filename': 'policies/community.json'}])
        self.assertTrue(self.run_guard(api))
        self.assertEqual([item[1]['state'] for item in api.statuses], ['pending', 'success'])
        for path, body in api.statuses:
            self.assertTrue(path.endswith('/statuses/' + HEAD))
            self.assertEqual(body['context'], CONFIG['status_context'])

    def test_owner_pr_requires_active_source_branch_write_protection(self):
        for defect in ['missing_rule', 'changed_rule', 'disabled', 'extra_bypass', 'excluded_branch', 'other_source']:
            api = FakeAPI(pull(owner=True), [{'filename': 'policies/community.json'}])
            if defect == 'missing_rule':
                api.branch_rules = [rule for rule in api.branch_rules if rule['type'] != 'update']
            elif defect == 'changed_rule':
                api.branch_policy['rules'] = [{'type': 'creation'}, {'type': 'deletion'}]
            elif defect == 'disabled':
                api.branch_policy['enforcement'] = 'disabled'
            elif defect == 'extra_bypass':
                api.branch_policy['bypass_actors'].append({
                    'actor_id': 123, 'actor_type': 'User', 'bypass_mode': 'always',
                })
            elif defect == 'excluded_branch':
                api.branch_policy['conditions']['ref_name']['exclude'] = ['refs/heads/owner-page']
            else:
                for rule in api.branch_rules:
                    rule['ruleset_source'] = 'another/repo'
            with self.subTest(defect=defect), self.assertRaises(ValueError):
                self.run_guard(api)
            self.assertEqual(api.statuses[-1][1]['state'], 'error')

    def test_normal_contribution_does_not_require_owner_branch_rules(self):
        api = FakeAPI(pull(), [{'filename': 'lib/main.dart'}])
        api.branch_rules = []
        self.assertTrue(self.run_guard(api))

    def test_old_event_cannot_pass_new_revision(self):
        pr = pull(owner=True)
        pr['head']['sha'] = 'c' * 40
        api = FakeAPI(pr, [{'filename': 'policies/community.json'}])
        with self.assertRaisesRegex(ValueError, 'Outdated'):
            self.run_guard(api)
        self.assertEqual(api.statuses[-1][1]['state'], 'error')
        self.assertEqual(api.pages, [])

    def test_changes_during_listing_require_another_check(self):
        for field in ['head', 'base', 'changed_files', 'base_branch', 'base_repository']:
            pr = pull(owner=True)
            after = copy.deepcopy(pr)
            if field in ['head', 'base']:
                after[field]['sha'] = 'c' * 40
            elif field == 'changed_files':
                after[field] = 2
            elif field == 'base_branch':
                after['base']['ref'] = 'another-branch'
            else:
                after['base']['repo']['full_name'] = 'another/repo'
            api = FakeAPI(pr, [{'filename': 'policies/community.json'}], after)
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.run_guard(api)
            self.assertEqual(api.statuses[-1][1]['state'], 'error')

    def test_wrong_repository_or_branch_is_rejected(self):
        metadata = event()
        metadata['repository']['full_name'] = 'another/repo'
        api = FakeAPI(pull(), [{'filename': 'lib/main.dart'}])
        with self.assertRaises(ValueError):
            self.run_guard(api, metadata)
        self.assertEqual(api.statuses, [])
        pr = pull(owner=True)
        pr['base']['ref'] = 'another-branch'
        api = FakeAPI(pr, [{'filename': 'policies/community.json'}])
        with self.assertRaises(ValueError):
            self.run_guard(api)
        self.assertEqual(api.statuses[-1][1]['state'], 'error')

    def test_invalid_head_metadata_never_creates_a_success_status(self):
        for sha in ['short', '../path', BASE + '/extra']:
            metadata = event()
            metadata['pull_request']['head']['sha'] = sha
            api = FakeAPI(pull(), [])
            with self.subTest(sha=sha), self.assertRaises(ValueError):
                self.run_guard(api, metadata)
            self.assertEqual(api.statuses, [])

if __name__ == '__main__':
    unittest.main()
