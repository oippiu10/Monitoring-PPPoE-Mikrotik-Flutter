import paramiko

servers = [
    {'host': '13.88.220.161', 'user': 'yhs', 'pass': 'yahahahusein112!', 'dir': '/www/wwwroot/billing.marzuqnetwork.online'},
    {'host': '10.5.6.2', 'user': 'root', 'pass': 'ilman271196', 'dir': '/www/wwwroot/web.cmmnetwork.online'}
]

for s in servers:
    print('=== Checking ' + s['host'] + ' ===')
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        ssh.connect(s['host'], username=s['user'], password=s['pass'], timeout=10)
        cmd = 'ls -la --time-style=long-iso ' + s['dir'] + '/api/bulk_update_users.php && ls -la --time-style=long-iso ' + s['dir'] + '/index.html'
        stdin, stdout, stderr = ssh.exec_command(cmd)
        print(stdout.read().decode())
        ssh.close()
    except Exception as e:
        if s['host'] == '13.88.220.161':
            try:
                ssh.connect(s['host'], username='root', password=s['pass'], timeout=10)
                cmd = 'ls -la --time-style=long-iso ' + s['dir'] + '/api/bulk_update_users.php && ls -la --time-style=long-iso ' + s['dir'] + '/index.html'
                stdin, stdout, stderr = ssh.exec_command(cmd)
                print(stdout.read().decode())
                ssh.close()
            except Exception as e2:
                print('Error:', e2)
        else:
            print('Error:', e)
