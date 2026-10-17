"""Read GitHub evidence before publishing maintainer-reviewed contributions."""
import json
from pathlib import Path
import subprocess
from urllib.parse import urlparse
from community import validate

PROJECT = Path(__file__).resolve().parent.parent
data = json.loads((PROJECT / 'policies/community.json').read_text())
validate(data)
cache = {}
for entry in data['entries']:
    if entry['status'] != 'accepted':
        continue
    source = urlparse(entry['source'])
    owner, repo, kind, number = source.path.strip('/').split('/')
    route = f'repos/{owner}/{repo}/{"pulls" if kind == "pull" else "issues"}/{number}'
    if route not in cache:
        cache[route] = json.loads(subprocess.check_output(['gh', 'api', route], text=True))
    record = cache[route]
    if kind == 'pull' and not record.get('merged_at'):
        raise SystemExit(f'PR evidence is not merged: {entry["source"]}')
    if kind == 'issues' and (record.get('state') != 'closed' or 'pull_request' in record):
        raise SystemExit(f'Non-code evidence must identify a closed accepted issue: {entry["source"]}')
    if entry['kind'] in {'fix', 'feature'} and kind != 'pull':
        raise SystemExit('Code contributions require a merged PR')
    print('Verified ' + entry['source'])
print(f'Contribution evidence verified: {len(cache)} GitHub records')
