import paramiko
import sys
import os

files_to_upload_api = {
    r"d:\Kuliah\Semester 6\Pemrograman Mobile II\CMM\mikrotik_monitor\api\version_config.php": "version_config.php",
    r"d:\Kuliah\Semester 6\Pemrograman Mobile II\CMM\mikrotik_monitor\api\check_update.php": "check_update.php",
}

targets = [
    {
        "host": "10.5.6.2",
        "user": "root",
        "pass": "ilman271196",
        "dirs": [
            "/www/wwwroot/cmmnetwork.online/api",
            "/www/wwwroot/web.cmmnetwork.online/api"
        ]
    },
    {
        "host": "13.88.220.161",
        "user": "yhs",
        "pass": "yahahahusein112!",
        "dirs": [
            "/www/wwwroot/billing.marzuqnetwork.online/api",
            "/www/wwwroot/billing.marzuqnetwork.online/api2"
        ]
    }
]

# Upload version_config.php
for t in targets:
    print(f"Connecting to {t['host']} as {t['user']}...")
    try:
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect(t['host'], port=22, username=t['user'], password=t['pass'], timeout=10)
        sftp = ssh.open_sftp()
        for d in t['dirs']:
            for local_f, remote_f in files_to_upload_api.items():
                remote_path = f"{d}/{remote_f}"
                print(f"Uploading {local_f} -> {remote_path}")
                try:
                    sftp.put(local_f, remote_path)
                    print("  SUCCESS")
                except Exception as e:
                    print(f"  FAILED: {e}")
                    # for 13.88.220.161 we might need to use /tmp and sudo cp
                    if t['host'] == '13.88.220.161':
                        tmp_path = f"/tmp/{remote_f}"
                        sftp.put(local_f, tmp_path)
                        ssh.exec_command(f"echo '{t['pass']}' | sudo -S cp {tmp_path} {remote_path}")
                        ssh.exec_command(f"echo '{t['pass']}' | sudo -S chown www:www {remote_path}")
                        print(f"  SUCCESS via sudo cp for {remote_path}")
                        
        sftp.close()
        ssh.close()
        print(f"Done with {t['host']}\n")
    except Exception as e:
        print(f"Could not connect to {t['host']}: {e}\n")

local_apk = r"d:\Kuliah\Semester 6\Pemrograman Mobile II\CMM\mikrotik_monitor\build\app\outputs\flutter-apk\app-release.apk"
for t in targets:
    print(f"Connecting to {t['host']} as {t['user']} for APK upload...")
    try:
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect(t['host'], port=22, username=t['user'], password=t['pass'], timeout=10)
        sftp = ssh.open_sftp()
        # Upload to files/app-release.apk (assuming it is inside /www/wwwroot/...)
        if t['host'] == '10.5.6.2':
            remote_apk = "/www/wwwroot/cmmnetwork.online/files/app-release.apk"
            print(f"Uploading APK to {remote_apk}...")
            sftp.put(local_apk, remote_apk)
        elif t['host'] == '13.88.220.161':
            remote_apk = "/www/wwwroot/billing.marzuqnetwork.online/files/app-release.apk"
            tmp_apk = "/tmp/app-release.apk"
            print(f"Uploading APK to {remote_apk} via {tmp_apk}...")
            sftp.put(local_apk, tmp_apk)
            ssh.exec_command(f"echo '{t['pass']}' | sudo -S mkdir -p /www/wwwroot/billing.marzuqnetwork.online/files")
            ssh.exec_command(f"echo '{t['pass']}' | sudo -S cp {tmp_apk} {remote_apk}")
            ssh.exec_command(f"echo '{t['pass']}' | sudo -S chown www:www {remote_apk}")
        sftp.close()
        ssh.close()
        print(f"Done uploading APK to {t['host']}\n")
    except Exception as e:
        print(f"Could not upload APK to {t['host']}: {e}\n")
