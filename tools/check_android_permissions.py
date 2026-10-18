"""Check sensitive permissions and backup behavior in the merged APK.

Including transitive plugin contributions: the merged manifest is what ships,
so both the permission list and the explicit allowBackup=false flag are
verified against the final artifact, not the source manifest.
"""
import os
from pathlib import Path
import re
import subprocess
import sys

ALLOWED_PERMISSIONS = {'android.permission.INTERNET', 'android.permission.CAMERA',
                       'android.permission.WRITE_EXTERNAL_STORAGE', 'android.permission.ACCESS_NETWORK_STATE',
                       'studio.framecoach.framecoach.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION'}


def verify_permissions(manifest_dump: str) -> None:
    for line in manifest_dump.splitlines():
        if line.startswith('uses-permission:'):
            name = line.split("name='", 1)[1].split("'", 1)[0]
            if name not in ALLOWED_PERMISSIONS:
                raise SystemExit(f'Unreviewed permission in final APK: {name}')
            if name == 'android.permission.WRITE_EXTERNAL_STORAGE' and "maxSdkVersion='29'" not in line:
                raise SystemExit('Storage write permission must be restricted to Android API 29 or earlier')


def verify_backup_disabled(manifest_xml: str) -> None:
    line = next((l for l in manifest_xml.splitlines() if 'android:allowBackup' in l), None)
    if line is None:
        raise SystemExit('Merged manifest must explicitly set android:allowBackup=false')
    match = re.search(r'android:allowBackup[^=]*=\(type=[^)]*\)(0x[0-9a-fA-F]+)', line)
    if match is None or int(match.group(1), 16) != 0:
        raise SystemExit('android:allowBackup must be false: uninstalling must clear local consent state')


def main() -> None:
    apk = Path(sys.argv[1])
    sdk = os.environ.get('ANDROID_SDK_ROOT') or os.environ.get('ANDROID_HOME')
    if not sdk:
        local = Path('android/local.properties')
        if local.exists():
            sdk = next((line.split('=', 1)[1] for line in local.read_text().splitlines()
                        if line.startswith('sdk.dir=')), None)
    if not sdk:
        raise SystemExit('Android SDK path is unavailable')
    tools = list((Path(sdk) / 'build-tools').glob('*/aapt'))
    if not tools:
        raise SystemExit('aapt is unavailable')
    aapt = max(tools, key=lambda path: tuple(int(part) if part.isdigit() else 0
                                             for part in path.parent.name.split('.')))
    permissions = subprocess.check_output([str(aapt), 'dump', 'permissions', str(apk)], text=True)
    verify_permissions(permissions)
    manifest = subprocess.check_output([str(aapt), 'dump', 'xmltree', str(apk), 'AndroidManifest.xml'], text=True)
    verify_backup_disabled(manifest)
    print(permissions)
    print('Merged APK permission check passed')


if __name__ == '__main__':
    main()
