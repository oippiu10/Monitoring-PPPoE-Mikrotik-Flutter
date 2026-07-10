import sys
import os
import subprocess
import zipfile

# Auto-install paramiko if not present
try:
    import paramiko
except ImportError:
    print("Paramiko library not found. Installing paramiko...")
    try:
        subprocess.check_call([sys.executable, "-m", "pip", "install", "paramiko"])
        import paramiko
    except Exception as e:
        print(f"Failed to install paramiko automatically: {e}")
        print("Please run: pip install paramiko")
        sys.exit(1)

def main():
    # 1. Run npm run build
    print("=== 1. BUILDING FRONTEND ===")
    try:
        # Use shell=True to support windows npm/npx resolving
        subprocess.run("npm run build", shell=True, check=True)
        print("Build success!\n")
    except subprocess.CalledProcessError as e:
        print(f"Build failed: {e}")
        sys.exit(1)

    # 2. Zip dist & api
    print("=== 2. ZIPPING BUILD ASSETS ===")
    local_zip = "update.zip"
    if os.path.exists(local_zip):
        os.remove(local_zip)

    try:
        with zipfile.ZipFile(local_zip, "w", zipfile.ZIP_DEFLATED) as zipf:
            # Add dist contents at root of zip
            dist_dir = "dist"
            if not os.path.exists(dist_dir):
                print("Error: dist/ folder not found. Did the build complete?")
                sys.exit(1)
            for root, dirs, files in os.walk(dist_dir):
                for file in files:
                    filepath = os.path.join(root, file)
                    arcname = os.path.relpath(filepath, dist_dir)
                    zipf.write(filepath, arcname)

            # Add api directory
            api_dir = "api"
            if os.path.exists(api_dir):
                for root, dirs, files in os.walk(api_dir):
                    for file in files:
                        filepath = os.path.join(root, file)
                        arcname = os.path.relpath(filepath, ".")
                        zipf.write(filepath, arcname)
            else:
                print("Warning: api/ folder not found. Skipping api packaging.")

        print(f"Zip archive created: {local_zip}\n")
    except Exception as e:
        print(f"Failed to zip files: {e}")
        sys.exit(1)

    # 3. SSH Connect and Deploy
    print("=== 3. DEPLOYING TO VPS ===")
    host = "10.5.6.2"
    port = 22
    usernames = ["yhs", "root"]
    password = "ilman271196"
    remote_dir = "/www/wwwroot/web.cmmnetwork.online"

    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    connected_user = None
    for username in usernames:
        print(f"Connecting to SSH {host}:{port} as {username}...")
        try:
            ssh.connect(host, port=port, username=username, password=password, timeout=10)
            print(f"SSH Connection successful as {username}!")
            connected_user = username
            break
        except paramiko.AuthenticationException:
            print(f"Authentication failed for {username}")
        except Exception as e:
            print(f"Error connecting as {username}: {e}")

    if not connected_user:
        print("Failed to authenticate with all provided usernames.")
        sys.exit(1)

    # Get whoami
    stdin, stdout, stderr = ssh.exec_command("whoami")
    whoami = stdout.read().decode().strip()
    print(f"Logged in as: {whoami}")

    # Check directory status
    cmd_check = f"[ -w {remote_dir} ] && echo 'writable' || echo 'not_writable'"
    stdin, stdout, stderr = ssh.exec_command(cmd_check)
    writable_status = stdout.read().decode().strip()
    print(f"Directory {remote_dir} status: {writable_status}")

    # SFTP Upload
    sftp = ssh.open_sftp()
    remote_file_path = f"/tmp/{local_zip}"
    print(f"Uploading {local_zip} to {remote_file_path}...")
    try:
        sftp.put(local_zip, remote_file_path)
        print("Upload successful!")
    except Exception as e:
        print(f"Upload failed: {e}")
        sftp.close()
        ssh.close()
        sys.exit(1)
    sftp.close()

    # Extract update.zip
    print("Extracting archive at remote destination...")
    # Use sudo with password stdin
    cmd_sudo_unzip = f"echo '{password}' | sudo -S unzip -o {remote_file_path} -d {remote_dir}"
    stdin, stdout, stderr = ssh.exec_command(cmd_sudo_unzip)
    out = stdout.read().decode()
    err = stderr.read().decode()

    # Cleanup remote tmp zip and local zip
    ssh.exec_command(f"rm {remote_file_path}")
    if os.path.exists(local_zip):
        os.remove(local_zip)

    print("STDOUT:")
    print(out)
    if err:
        print("STDERR:")
        print(err)

    print("\n=== DEPLOYMENT COMPLETED SUCCESSFULLY ===")
    ssh.close()

if __name__ == "__main__":
    main()
