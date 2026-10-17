import copy
from decimal import Decimal
import sys
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from community import ranking, render, validate


def sample():
    return {
        'repository_url': 'https://github.com/lianjiehao/frameapp',
        'accepting_contributions': True,
        'updated_at': '2026-10-09',
        'maintainers': ['lianjiehao'],
        'people': [
            {'login': 'alice', 'name': 'Alice', 'display_consent': True, 'featured': True},
            {'login': 'bob', 'name': 'Bob', 'display_consent': True, 'featured': True},
        ],
        'entries': [{
            'id': 'pr-1', 'source': 'https://github.com/lianjiehao/frameapp/pull/1',
            'kind': 'fix', 'summary': '修复已复现的问题', 'accepted_at': '2026-10-08',
            'points': 3, 'confirmed_by': 'lianjiehao', 'status': 'accepted',
            'credits': [{'login': 'alice', 'share': .5}, {'login': 'bob', 'share': .5}],
        }],
    }


class CommunityTests(unittest.TestCase):
    def test_shared_credit_is_split_and_equal_totals_share_rank(self):
        data = sample()
        rows = ranking(data)
        self.assertEqual([row['points'] for row in rows], [Decimal('1.5'), Decimal('1.5')])
        self.assertEqual(render(data).count('<span class="rank">01</span>'), 2)

    def test_nonconsenting_unfeatured_and_reverted_people_are_hidden(self):
        data = sample()
        data['people'][0]['display_consent'] = False
        self.assertEqual([row['person']['login'] for row in ranking(data)], ['bob'])
        data['people'][1]['featured'] = False
        self.assertEqual(ranking(data), [])
        data = sample()
        data['entries'][0]['status'] = 'reverted'
        self.assertEqual(ranking(data), [])

    def test_recent_activity_does_not_erase_lifetime_credit(self):
        data = sample()
        data['entries'][0]['accepted_at'] = '2026-01-01'
        rows = ranking(data)
        self.assertEqual(rows[0]['points'], Decimal('1.5'))
        self.assertEqual(rows[0]['recent'], Decimal(0))

    def test_duplicate_evidence_and_invalid_shares_are_rejected(self):
        data = sample()
        duplicate = copy.deepcopy(data['entries'][0])
        duplicate['id'] = 'different-id'
        duplicate['source'] += '#issuecomment-1'
        data['entries'].append(duplicate)
        with self.assertRaises(ValueError): validate(data)
        data = sample()
        data['entries'][0]['credits'][0]['share'] = .9
        with self.assertRaises(ValueError): validate(data)

    def test_external_evidence_future_work_and_unknown_reviewer_are_rejected(self):
        for field, value in [
            ('source', 'https://github.com/somewhere/else/pull/1'),
            ('source', 'javascript:alert(1)'),
            ('accepted_at', '2026-10-10'),
            ('confirmed_by', 'unknown-user'),
        ]:
            data = sample()
            data['entries'][0][field] = value
            with self.subTest(field=field, value=value), self.assertRaises(ValueError): validate(data)

    def test_nickname_and_summary_cannot_inject_html(self):
        data = sample()
        data['people'][0]['name'] = '<script>alert(1)</script>'
        data['entries'][0]['summary'] = '<img src=x onerror=alert(1)>'
        output = render(data)
        self.assertNotIn('<script>', output)
        self.assertNotIn('<img', output)
        self.assertIn('&lt;script&gt;', output)

    def test_prelaunch_empty_page_has_no_fake_people_or_private_repo_link(self):
        data = sample()
        data.update(people=[], entries=[], accepting_contributions=False)
        output = render(data)
        self.assertIn('贡献接收已暂停', output)
        self.assertNotIn('前往 GitHub', output)
        self.assertNotIn('class="contributor"', output)


if __name__ == '__main__':
    unittest.main()
