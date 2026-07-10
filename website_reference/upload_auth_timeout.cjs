const { NodeSSH } = require('node-ssh');
const path = require('path');

async function uploadToVPS(config, vpsName, remoteDir) {
    const ssh = new NodeSSH();
    try {
        console.log(`Connecting to ${vpsName} (${config.host})...`);
        await ssh.connect(config);
        
        const filesToUpload = [
            'api/auth/require_auth.php',
            'api/auth/verify_session.php'
        ];
        
        for (const file of filesToUpload) {
            const localPath = path.join(__dirname, file);
            const remotePath = `${remoteDir}/${file}`;
            console.log(`Uploading ${file} to ${vpsName}...`);
            await ssh.putFile(localPath, remotePath);
        }
        
        console.log(`Successfully updated ${vpsName}!`);
    } catch (err) {
        console.error(`Error on ${vpsName}:`, err.message);
    } finally {
        ssh.dispose();
    }
}

async function main() {
    const vps1 = {
        host: '13.88.220.161',
        port: 22,
        username: 'yhs',
        password: 'yahahahusein112!'
    };
    const dir1 = '/www/wwwroot/billing.marzuqnetwork.online';
    
    const vps2 = {
        host: '10.5.6.2',
        port: 22,
        username: 'root',
        password: 'ilman271196'
    };
    const dir2 = '/www/wwwroot/web.cmmnetwork.online';

    console.log("Starting upload of auth timeout fix...");
    await uploadToVPS(vps1, "Marzuq VPS", dir1);
    await uploadToVPS(vps2, "CMM VPS", dir2);
    console.log("All done!");
}

main();
