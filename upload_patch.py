import paramiko
import sys
import os

files_to_upload = {
    r"c:\laragon\www\websitemonitoringbaru\api\config.php": "config.php",
    r"c:\laragon\www\websitemonitoringbaru\api\expense_operations.php": "expense_operations.php"
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
            "/www/wwwroot/billing.marzuqnetwork.online/api2",
            "/www/wwwroot/billing.marzuqnetwork.online/api"
        ]
    }
]

for t in targets:
    print(f"Connecting to {t['host']} as {t['user']}...")
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        ssh.connect(t['host'], port=22, username=t['user'], password=t['pass'], timeout=10)
        sftp = ssh.open_sftp()
        for d in t['dirs']:
            for local_f, remote_f in files_to_upload.items():
                remote_path = f"{d}/{remote_f}"
                print(f"Uploading {local_f} -> {t['host']}:{remote_path}")
                try:
                    sftp.put(local_f, remote_path)
                except Exception as e:
                    print(f"  FAILED: {e}")
                    
        sftp.close()
        ssh.close()
        print(f"Successfully uploaded to {t['host']}\n")
    except Exception as e:
        print(f"Could not connect to {t['host']}: {e}\n")
