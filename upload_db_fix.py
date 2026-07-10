import paramiko
import sys

local_f = r"d:\Kuliah\Semester 6\Pemrograman Mobile II\CMM\mikrotik_monitor\api\fix_method_column.php"
filename = "fix_method_column.php"

# Server 1: CMM
print("Connecting to 10.5.6.2...")
ssh1 = paramiko.SSHClient()
ssh1.set_missing_host_key_policy(paramiko.AutoAddPolicy())
try:
    ssh1.connect("10.5.6.2", port=22, username="root", password="ilman271196", timeout=10)
    sftp1 = ssh1.open_sftp()
    
    dirs1 = ["/www/wwwroot/cmmnetwork.online/api", "/www/wwwroot/web.cmmnetwork.online/api"]
    for d in dirs1:
        remote_path = f"{d}/{filename}"
        print(f"Uploading to {remote_path}")
        sftp1.put(local_f, remote_path)
    
    # Executing the PHP script on the server!
    print("Executing on Server 1...")
    stdin, stdout, stderr = ssh1.exec_command("php /www/wwwroot/cmmnetwork.online/api/fix_method_column.php")
    print(stdout.read().decode())
    
    sftp1.close()
    ssh1.close()
except Exception as e:
    print(f"Error on Server 1: {e}")

# Server 2: Marzuq
print("\nConnecting to 13.88.220.161...")
ssh2 = paramiko.SSHClient()
ssh2.set_missing_host_key_policy(paramiko.AutoAddPolicy())
try:
    ssh2.connect("13.88.220.161", port=22, username="yhs", password="yahahahusein112!", timeout=10)
    sftp2 = ssh2.open_sftp()
    
    remote_tmp = f"/tmp/{filename}"
    sftp2.put(local_f, remote_tmp)
    
    dirs2 = ["/www/wwwroot/billing.marzuqnetwork.online/api2", "/www/wwwroot/billing.marzuqnetwork.online/api"]
    for d in dirs2:
        remote_dest = f"{d}/{filename}"
        stdin, stdout, stderr = ssh2.exec_command(f"sudo cp {remote_tmp} {remote_dest} && sudo chown www:www {remote_dest}")
        stdin.write("yahahahusein112!\n")
        stdin.flush()
        print(stdout.read().decode(), stderr.read().decode())
        
    print("Executing on Server 2...")
    stdin, stdout, stderr = ssh2.exec_command("php /www/wwwroot/billing.marzuqnetwork.online/api2/fix_method_column.php")
    print(stdout.read().decode())
    
    sftp2.close()
    ssh2.close()
except Exception as e:
    print(f"Error on Server 2: {e}")

print("Done")
