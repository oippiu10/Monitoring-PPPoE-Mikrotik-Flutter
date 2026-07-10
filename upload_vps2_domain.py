import paramiko

host = "cmmnetwork.online"
user = "root"
password = "ilman271196"

files_to_upload = {
    r"c:\laragon\www\websitemonitoringbaru\api\config.php": "config.php",
    r"c:\laragon\www\websitemonitoringbaru\api\expense_operations.php": "expense_operations.php"
}

dirs = [
    "/www/wwwroot/cmmnetwork.online/api",
    "/www/wwwroot/web.cmmnetwork.online/api"
]

try:
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    print(f"Connecting to {host}...")
    ssh.connect(host, port=22, username=user, password=password, timeout=10)
    
    sftp = ssh.open_sftp()
    for d in dirs:
        for local_f, remote_f in files_to_upload.items():
            remote_path = f"{d}/{remote_f}"
            print(f"Uploading to {remote_path}...")
            try:
                sftp.put(local_f, remote_path)
                print("SUCCESS")
            except Exception as e:
                print("FAILED:", e)
    
    sftp.close()
    ssh.close()
except Exception as e:
    print(f"Error: {e}")
