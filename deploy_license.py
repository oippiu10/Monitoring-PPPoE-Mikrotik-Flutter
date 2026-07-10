import paramiko

targets = [
    {
        "host": "10.5.6.2",
        "user": "root",
        "pass": "ilman271196",
        "dir": "/www/wwwroot/cmmnetwork.online/api"
    },
    {
        "host": "13.88.220.161",
        "user": "yhs",
        "pass": "yahahahusein112!",
        "dir": "/www/wwwroot/billing.marzuqnetwork.online/api2"
    }
]

print("Uploading updated check_license.php to both servers...")

for t in targets:
    try:
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect(t['host'], port=22, username=t['user'], password=t['pass'], timeout=10)
        sftp = ssh.open_sftp()
        remote_path = t['dir'] + "/check_license.php"
        if t['host'] == '13.88.220.161':
            sftp.put("check_license.php", "/tmp/check_license.php")
            stdin, stdout, stderr = ssh.exec_command("echo 'yahahahusein112!' | sudo -S cp /tmp/check_license.php " + remote_path)
            stdout.read() # wait
            ssh.exec_command("echo 'yahahahusein112!' | sudo -S chown www:www " + remote_path)
        else:
            sftp.put("check_license.php", remote_path)
        sftp.close()
        ssh.close()
        print("Successfully uploaded to " + t['host'])
    except Exception as e:
        print("Failed to upload to " + t['host'] + ": " + str(e))
