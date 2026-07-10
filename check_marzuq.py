import paramiko

def run_ssh(host, user, passwd, cmd):
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(host, port=22, username=user, password=passwd, timeout=10)
    stdin, stdout, stderr = ssh.exec_command(cmd)
    print(f"[{host}] OUT: {stdout.read().decode().strip()}")
    print(f"[{host}] ERR: {stderr.read().decode().strip()}")
    ssh.close()

run_ssh('13.88.220.161', 'yhs', 'yahahahusein112!', 'ls -la /www/wwwroot/billing.marzuqnetwork.online/files/')
run_ssh('13.88.220.161', 'yhs', 'yahahahusein112!', 'ls -la /tmp/app-release.apk')
