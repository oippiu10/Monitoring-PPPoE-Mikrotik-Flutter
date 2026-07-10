const { NodeSSH } = require('node-ssh');
const ssh = new NodeSSH();

async function fixConfig() {
  try {
    await ssh.connect({
      host: '10.5.6.2',
      username: 'root',
      password: 'ilman271196',
      port: 22
    });

    const cmd = `
      cd /www/wwwroot/web.cmmnetwork.online/api
      sed -i "s/\\$db_host = 'pma.cmmnetwork.online'/\\$db_host = 'localhost'/g" config.php
      mysql -u root -pyahahahusein112 -e "CREATE DATABASE IF NOT EXISTS pppoe_monitor;"
    `;
    const res = await ssh.execCommand(cmd);
    console.log("Fix Result:", res.stdout, res.stderr);

    ssh.dispose();
  } catch (err) {
    console.error(err);
    ssh.dispose();
  }
}
fixConfig();
