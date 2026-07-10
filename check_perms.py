import paramiko

def check_perms(host, user, passwd, path):
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(host, port=22, username=user, password=passwd, timeout=10)
    stdin, stdout, stderr = ssh.exec_command(f"ls -l {path}")
    print(f"[{host}] {stdout.read().decode().strip()}")
    ssh.close()

check_perms('10.5.6.2', 'root', 'ilman271196', '/www/wwwroot/cmmnetwork.online/files/app-release.apk')
check_perms('13.88.220.161', 'yhs', 'yahahahusein112!', '/www/wwwroot/billing.marzuqnetwork.online/files/app-release.apk')
