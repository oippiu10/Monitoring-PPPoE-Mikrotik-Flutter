const { NodeSSH } = require('node-ssh');
const path = require('path');

async function main() {
    const ssh = new NodeSSH();
    
    const config = {
        host: '10.5.6.2',
        port: 22,
        username: 'root',
        password: 'ilman271196'
    };

    try {
        console.log('Connecting via SSH...');
        await ssh.connect(config);
        
        console.log('Uploading update-frontend.zip...');
        const localPath = path.join(__dirname, 'update-frontend.zip');
        const remotePath = '/www/wwwroot/web.cmmnetwork.online/update-frontend.zip';
        
        await ssh.putFile(localPath, remotePath);
        console.log('Upload complete!');
        
        console.log('Unzipping...');
        const cmd = 'cd /www/wwwroot/web.cmmnetwork.online && unzip -o update-frontend.zip && rm update-frontend.zip';
        const res = await ssh.execCommand(cmd);
        console.log('STDOUT: ' + res.stdout);
        console.log('STDERR: ' + res.stderr);
        
        console.log('Deployment completed successfully!');
        ssh.dispose();
    } catch (err) {
        console.error('Error:', err.message);
        ssh.dispose();
    }
}

main();
