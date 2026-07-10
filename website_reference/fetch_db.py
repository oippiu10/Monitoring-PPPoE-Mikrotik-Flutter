import paramiko
import sys
import subprocess

host = "13.88.220.161"
port = 22
usernames = ["yhs", "root"]
password = "yahahahusein112!"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

connected_user = None
for user in usernames:
    print(f"Connecting to {host} as {user}...")
    try:
        ssh.connect(host, port=port, username=user, password=password, timeout=10)
        print("Connected!")
        connected_user = user
        break
    except Exception as e:
        print(f"Failed: {e}")

if not connected_user:
    sys.exit(1)

print("Exporting database on remote server...")
stdin, stdout, stderr = ssh.exec_command("mysqldump -h 127.0.0.1 -u root -pyahahahusein112 pppoe_monitor > /tmp/backup.sql")
print(stderr.read().decode())
print(stdout.read().decode())

print("Downloading backup file...")
sftp = ssh.open_sftp()
sftp.get("/tmp/backup.sql", "c:\\laragon\\www\\websitemonitoringbaru\\backup_marzuq.sql")
sftp.close()

print("Cleaning up remote file...")
ssh.exec_command("rm /tmp/backup.sql")
ssh.close()

print("Done downloading!")
