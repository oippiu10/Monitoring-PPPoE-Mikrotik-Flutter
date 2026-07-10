import paramiko

print("Connecting to 13.88.220.161...")
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
try:
    ssh.connect("13.88.220.161", port=22, username="yhs", password="yahahahusein112!", timeout=10)
    # Get last 50 lines of PHP error log or Nginx error log
    stdin, stdout, stderr = ssh.exec_command("sudo tail -n 100 /www/wwwlogs/billing.marzuqnetwork.online.error.log")
    stdin.write("yahahahusein112!\n")
    stdin.flush()
    print("NGINX ERROR LOG:")
    print(stdout.read().decode())
    
    stdin, stdout, stderr = ssh.exec_command("sudo tail -n 100 /www/server/php/80/var/log/php-fpm.log")
    stdin.write("yahahahusein112!\n")
    stdin.flush()
    print("PHP-FPM LOG:")
    print(stdout.read().decode())
    
    ssh.close()
except Exception as e:
    print(f"Error: {e}")
