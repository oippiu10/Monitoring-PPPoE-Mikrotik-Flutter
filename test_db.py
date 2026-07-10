import paramiko
import sys

# Server 2: Marzuq
print("\nConnecting to 13.88.220.161...")
ssh2 = paramiko.SSHClient()
ssh2.set_missing_host_key_policy(paramiko.AutoAddPolicy())
try:
    ssh2.connect("13.88.220.161", port=22, username="yhs", password="yahahahusein112!", timeout=10)
    
    stdin, stdout, stderr = ssh2.exec_command('mysql -u yhs -pyahahahusein112\! billing_marzuqnetw -e "SELECT id, user_id, amount, method, router_id FROM payments ORDER BY id DESC LIMIT 5"')
    print("Latest 5 payments in DB:")
    print(stdout.read().decode())
    
    ssh2.close()
except Exception as e:
    print(f"Error on Server 2: {e}")
