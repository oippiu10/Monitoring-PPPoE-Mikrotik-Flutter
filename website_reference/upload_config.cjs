const { NodeSSH } = require('node-ssh');
const path = require('path');
const ssh = new NodeSSH();

async function uploadConfig() {
  try {
    await ssh.connect({
      host: '10.5.6.2',
      username: 'root',
      password: 'ilman271196',
      port: 22
    });

    const localFile = path.join(__dirname, 'remote_config.php');
    const remoteFile = '/www/wwwroot/web.cmmnetwork.online/api/config.php';

    await ssh.putFile(localFile, remoteFile);
    console.log("Config uploaded successfully!");

    ssh.dispose();
  } catch (err) {
    console.error(err);
    ssh.dispose();
  }
}
uploadConfig();
