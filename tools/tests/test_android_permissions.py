from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from check_android_permissions import verify_backup_disabled, verify_permissions


class BackupCheckTests(unittest.TestCase):
    def test_explicit_false_passes(self):
        verify_backup_disabled(
            'E: application (line=7)\n'
            '  A: android:label(0x01010001)="取景"\n'
            '  A: android:allowBackup(0x01010448)=(type=0x12)0x00\n'
        )

    def test_missing_attribute_fails(self):
        with self.assertRaises(SystemExit):
            verify_backup_disabled('E: application (line=7)\n  A: android:label(0x01010001)="取景"\n')

    def test_enabled_backup_fails(self):
        with self.assertRaises(SystemExit):
            verify_backup_disabled('A: android:allowBackup(0x01010448)=(type=0x12)0x01\n')


class PermissionCheckTests(unittest.TestCase):
    def test_reviewed_permissions_pass(self):
        verify_permissions(
            "uses-permission: name='android.permission.CAMERA'\n"
            "uses-permission: name='android.permission.WRITE_EXTERNAL_STORAGE' maxSdkVersion='29'\n"
        )

    def test_unreviewed_permission_fails(self):
        with self.assertRaises(SystemExit):
            verify_permissions("uses-permission: name='android.permission.RECORD_AUDIO'\n")

    def test_uncapped_storage_permission_fails(self):
        with self.assertRaises(SystemExit):
            verify_permissions("uses-permission: name='android.permission.WRITE_EXTERNAL_STORAGE'\n")


if __name__ == '__main__':
    unittest.main()
