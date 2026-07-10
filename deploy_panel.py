import paramiko

def run_ssh_command(host, user, passwd, cmd):
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(host, port=22, username=user, password=passwd, timeout=10)
    stdin, stdout, stderr = ssh.exec_command(cmd)
    out = stdout.read().decode('utf-8')
    err = stderr.read().decode('utf-8')
    ssh.close()
    return out, err

print("Downloading license_panel.php from CMM...")
out, err = run_ssh_command('10.5.6.2', 'root', 'ilman271196', 'cat /www/wwwroot/cmmnetwork.online/api/license_panel.php')

if not out.strip():
    print("Error: Could not read license_panel.php from CMM.")
    if err: print("Stderr:", err)
else:
    print("Saving to local file...")
    with open("license_panel.php", "w", encoding="utf-8") as f:
        f.write(out)
        
    print("Uploading to Marzuq...")
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect('13.88.220.161', port=22, username='yhs', password='yahahahusein112!', timeout=10)
    sftp = ssh.open_sftp()
    
    # Upload to API 1 (Website)
    remote_path1 = "/www/wwwroot/billing.marzuqnetwork.online/api/license_panel.php"
    # Upload to API 2 (Flutter) - Just in case
    remote_path2 = "/www/wwwroot/billing.marzuqnetwork.online/api2/license_panel.php"
    
    try:
        sftp.put("license_panel.php", "/tmp/license_panel.php")
        ssh.exec_command(f"echo 'yahahahusein112!' | sudo -S cp /tmp/license_panel.php {remote_path1}")
        ssh.exec_command(f"echo 'yahahahusein112!' | sudo -S chown www:www {remote_path1}")
        
        ssh.exec_command(f"echo 'yahahahusein112!' | sudo -S cp /tmp/license_panel.php {remote_path2}")
        ssh.exec_command(f"echo 'yahahahusein112!' | sudo -S chown www:www {remote_path2}")
        
        print("Successfully deployed license_panel.php to Marzuq!")
    except Exception as e:
        print("Failed to deploy to Marzuq:", e)
    finally:
        sftp.close()
        ssh.close()
