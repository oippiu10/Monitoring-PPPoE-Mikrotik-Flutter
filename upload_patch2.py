import paramiko
import sys
import os

files_to_upload = {
    r"c:\laragon\www\websitemonitoringbaru\api\config.php": "config.php",
    r"c:\laragon\www\websitemonitoringbaru\api\expense_operations.php": "expense_operations.php"
}

targets = [
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
                tmp_path = f"/tmp/{remote_f}"
                print(f"Uploading {local_f} -> {t['host']}:{remote_path} via /tmp")
                try:
                    sftp.put(local_f, tmp_path)
                    cmd = f"echo '{t['pass']}' | sudo -S cp {tmp_path} {remote_path} && sudo -S chown www:www {remote_path}"
                    stdin, stdout, stderr = ssh.exec_command(cmd)
                    err = stderr.read().decode()
                    if "incorrect password" in err.lower() or "not found" in err.lower():
                        print(f"  SUDO FAILED: {err}")
                    else:
                        print(f"  SUCCESS")
                except Exception as e:
                    print(f"  FAILED: {e}")
                    
        sftp.close()
        ssh.close()
        print(f"Successfully processed {t['host']}\n")
    except Exception as e:
        print(f"Could not connect to {t['host']}: {e}\n")
