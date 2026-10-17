from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from check_docs import check_document


class DocumentationTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.page = self.root / 'README.md'

    def test_valid_chinese_fragment_and_html_image(self):
        (self.root / 'guide.md').write_text('# 提交前检查\n')
        (self.root / 'shot.png').write_bytes(b'fixture')
        self.page.write_text('[Guide](guide.md#提交前检查)\n<img src="shot.png" alt="shot">')
        self.assertEqual(check_document(self.page, self.root), [])

    def test_missing_file_and_heading_are_reported(self):
        (self.root / 'guide.md').write_text('# Run\n')
        self.page.write_text('[Guide](guide.md#missing)\n![Shot](missing.png)')
        errors = check_document(self.page, self.root)
        self.assertEqual(len(errors), 2)
        self.assertTrue(any('missing heading' in error for error in errors))
        self.assertTrue(any('missing target' in error for error in errors))

    def test_external_links_and_fenced_examples_are_ignored(self):
        self.page.write_text('[Web](https://example.com)\n~~~md\n[Example](absent.md)\n~~~\n')
        self.assertEqual(check_document(self.page, self.root), [])

    def test_repository_escape_is_rejected(self):
        self.page.write_text('[Outside](../outside.md)')
        self.assertIn('escapes repository', check_document(self.page, self.root)[0])

    def test_encoded_path_and_repeated_heading(self):
        (self.root / 'my guide.md').write_text('# Run\n# Run\n')
        self.page.write_text('[Guide](my%20guide.md#run-1)')
        self.assertEqual(check_document(self.page, self.root), [])


if __name__ == '__main__':
    unittest.main()
