import json
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from policy_config import validate_config

ROOT = Path(__file__).resolve().parents[2]


class PolicyConfigTests(unittest.TestCase):
    def setUp(self):
        self.config = json.loads((ROOT / 'policies/config.json').read_text())

    def test_template_metadata_is_valid(self):
        validate_config(self.config)

    def test_distributor_can_customize_metadata(self):
        validate_config(dict(self.config, operator='Example contributor',
                             email='support@example.com', version='2026-10-17'))

    def test_required_metadata_cannot_be_empty_or_nontext(self):
        for key in ('operator', 'email', 'version'):
            for value in (None, '', '  ', 123, False):
                with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                    validate_config(dict(self.config, **{key: value}))
            incomplete = dict(self.config)
            del incomplete[key]
            with self.subTest(missing=key), self.assertRaises(ValueError):
                validate_config(incomplete)

    def test_contact_address_has_no_whitespace(self):
        for email in ('missing-at', 'support @example.com', 'support@example.com\n'):
            with self.subTest(email=email), self.assertRaises(ValueError):
                validate_config(dict(self.config, email=email))

    def test_version_is_a_calendar_date(self):
        for version in ('tomorrow', '2026-02-30', '2026-13-01'):
            with self.subTest(version=version), self.assertRaises(ValueError):
                validate_config(dict(self.config, version=version))


if __name__ == '__main__':
    unittest.main()
