import paramiko

def fix_marzuq():
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect('13.88.220.161', port=22, username='yhs', password='yahahahusein112!', timeout=10)
    
    # Create directory and set permissions
    ssh.exec_command("echo 'yahahahusein112!' | sudo -S mkdir -p /www/wwwroot/billing.marzuqnetwork.online/files")
    ssh.exec_command("echo 'yahahahusein112!' | sudo -S chown www:www /www/wwwroot/billing.marzuqnetwork.online/files")
    
    # Copy APK
    ssh.exec_command("echo 'yahahahusein112!' | sudo -S cp /tmp/app-release.apk /www/wwwroot/billing.marzuqnetwork.online/files/app-release.apk")
    ssh.exec_command("echo 'yahahahusein112!' | sudo -S chown www:www /www/wwwroot/billing.marzuqnetwork.online/files/app-release.apk")
    ssh.exec_command("echo 'yahahahusein112!' | sudo -S chmod 644 /www/wwwroot/billing.marzuqnetwork.online/files/app-release.apk")
    
    # Also fix CMM permissions just in case
    ssh2 = paramiko.SSHClient()
    ssh2.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh2.connect('10.5.6.2', port=22, username='root', password='ilman271196', timeout=10)
    ssh2.exec_command("chmod 644 /www/wwwroot/cmmnetwork.online/files/app-release.apk")
    
    print("Fixed!")
    ssh.close()
    ssh2.close()

fix_marzuq()
