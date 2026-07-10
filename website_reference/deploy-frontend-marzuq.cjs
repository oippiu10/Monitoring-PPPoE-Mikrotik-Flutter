const { NodeSSH } = require('node-ssh');
const path = require('path');

async function main() {
    const ssh = new NodeSSH();
    
    const config = {
        host: '13.88.220.161',
        port: 22,
        username: 'yhs',
        password: 'yahahahusein112!'
    };

    try {
        console.log('Connecting to Marzuq VPS via SSH...');
        await ssh.connect(config);
        
        console.log('Uploading update-frontend.zip...');
        const localPath = path.join(__dirname, 'update-frontend.zip');
        const remotePath = '/www/wwwroot/billing.marzuqnetwork.online/update-frontend.zip';
        
        await ssh.putFile(localPath, remotePath);
        console.log('Upload complete!');
        
        console.log('Unzipping...');
        const cmd = 'cd /www/wwwroot/billing.marzuqnetwork.online && echo "yahahahusein112!" | sudo -S unzip -o update-frontend.zip && rm update-frontend.zip';
        const res = await ssh.execCommand(cmd);
        console.log('STDOUT: ' + res.stdout);
        console.log('STDERR: ' + res.stderr);
        
        console.log('Deployment to Marzuq VPS completed successfully!');
        ssh.dispose();
    } catch (err) {
        console.error('Error:', err.message);
        ssh.dispose();
    }
}

main();
