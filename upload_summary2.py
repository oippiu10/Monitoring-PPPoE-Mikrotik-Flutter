import paramiko
import sys

target = {
    "host": "13.88.220.161",
    "user": "yhs",
    "pass": "yahahahusein112!",
}

print(f"Connecting to {target['host']} as {target['user']}...")
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
try:
    ssh.connect(target['host'], port=22, username=target['user'], password=target['pass'], timeout=10)
    sftp = ssh.open_sftp()
    
    local_f = r"d:\Kuliah\Semester 6\Pemrograman Mobile II\CMM\mikrotik_monitor\api\payment_summary_operations.php"
    remote_tmp = "/tmp/payment_summary_operations.php"
    
    print(f"Uploading {local_f} to {remote_tmp}")
    sftp.put(local_f, remote_tmp)
    
    # move using sudo
    remote_dest = "/www/wwwroot/billing.marzuqnetwork.online/api2/payment_summary_operations.php"
    print(f"Moving {remote_tmp} to {remote_dest} using sudo...")
    stdin, stdout, stderr = ssh.exec_command(f"sudo cp {remote_tmp} {remote_dest} && sudo chown www:www {remote_dest}")
    stdin.write(target['pass'] + '\n')
    stdin.flush()
    
    out = stdout.read().decode()
    err = stderr.read().decode()
    
    if err and "password" not in err.lower():
        print("Error:", err)
    else:
        print("Success:", out)
        
    sftp.close()
    ssh.close()
    print("Done")
except Exception as e:
    print(f"Could not connect to {target['host']}: {e}\n")
