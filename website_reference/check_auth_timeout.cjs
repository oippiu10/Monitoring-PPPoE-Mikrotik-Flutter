const { NodeSSH } = require('node-ssh');

async function checkVPS(config, vpsName, remoteDir) {
    const ssh = new NodeSSH();
    try {
        await ssh.connect(config);
        
        const cmd = `cd ${remoteDir} && grep "\\$timeout = " api/auth/require_auth.php`;
        const res = await ssh.execCommand(cmd);
        console.log(`[${vpsName}] result: ${res.stdout.trim()}`);
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

    console.log("Checking timeout on servers...");
    await checkVPS(vps1, "Marzuq VPS", dir1);
    await checkVPS(vps2, "CMM VPS", dir2);
}

main();
