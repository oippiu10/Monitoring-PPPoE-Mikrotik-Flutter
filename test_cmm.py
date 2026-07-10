import paramiko
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
try:
    ssh.connect('10.5.6.2', port=22, username='root', password='ilman271196', timeout=5)
    print("Connected to CMM!")
    ssh.close()
except Exception as e:
    print(f"Failed: {e}")
