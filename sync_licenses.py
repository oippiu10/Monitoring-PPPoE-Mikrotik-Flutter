import paramiko

def run_ssh_command(host, user, passwd, cmd):
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(host, port=22, username=user, password=passwd, timeout=10)
    stdin, stdout, stderr = ssh.exec_command(cmd)
    out = stdout.read().decode('utf-8')
    err = stderr.read().decode('utf-8')
    ssh.close()
    if err and "Warning" not in err:
        print(f"[{host}] ERROR: {err}")
    return out

print("Extracting licenses from CMM (10.5.6.2)...")
cmm_out = run_ssh_command(
    '10.5.6.2', 'root', 'ilman271196',
    "mysql -u root -pyahahahusein112 pppoe_monitor -B -N -e 'SELECT license_code, router_id, is_active, expired_at FROM app_licenses;'"
)

if not cmm_out.strip():
    print("No licenses found on CMM.")
else:
    lines = cmm_out.strip().split('\n')
    print(f"Found {len(lines)} licenses on CMM. Syncing to Marzuq (13.88.220.161)...")
    
    insert_values = []
    for line in lines:
        parts = line.split('\t')
        if len(parts) >= 4:
            lcode = parts[0]
            rid = parts[1]
            active = parts[2]
            exp = parts[3]
            
            # handle NULLs
            rid_val = f"'{rid}'" if rid != 'NULL' else "NULL"
            exp_val = f"'{exp}'" if exp != 'NULL' else "NULL"
            
            insert_values.append(f"('{lcode}', {rid_val}, {active}, {exp_val})")
            
    if insert_values:
        values_str = ",\n".join(insert_values)
        sql = f"""
        INSERT IGNORE INTO app_licenses (license_code, router_id, is_active, expired_at) 
        VALUES {values_str}
        ON DUPLICATE KEY UPDATE 
            is_active=VALUES(is_active), 
            expired_at=VALUES(expired_at);
        """
        
        # Save to a local temp file, send via SFTP, and run it
        with open("sync.sql", "w") as f:
            f.write(sql)
            
        print("Uploading sync.sql to Marzuq...")
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect('13.88.220.161', port=22, username='yhs', password='yahahahusein112!', timeout=10)
        sftp = ssh.open_sftp()
        sftp.put("sync.sql", "/tmp/sync.sql")
        sftp.close()
        
        print("Executing sync.sql on Marzuq...")
        stdin, stdout, stderr = ssh.exec_command("mysql -h 127.0.0.1 -u root -pyahahahusein112 pppoe_monitor < /tmp/sync.sql")
        print("OUT:", stdout.read().decode())
        print("ERR:", stderr.read().decode())
        ssh.exec_command("rm /tmp/sync.sql")
        ssh.close()
        
        print("Sync completed successfully!")
