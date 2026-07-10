const { NodeSSH } = require('node-ssh');
const ssh = new NodeSSH();

async function fixConfigAutoMigrate() {
  try {
    await ssh.connect({
      host: '10.5.6.2',
      username: 'root',
      password: 'ilman271196',
      port: 22
    });

    const cmd = `
      cd /www/wwwroot/web.cmmnetwork.online/api
      sed -i 's/$resOdpCols = $conn->query("SHOW COLUMNS FROM odp");/$resOdpCols = @$conn->query("SHOW COLUMNS FROM odp");/g' config.php
      sed -i 's/$resOdcCols = $conn->query("SHOW COLUMNS FROM odc");/$resOdcCols = @$conn->query("SHOW COLUMNS FROM odc");/g' config.php
      sed -i 's/$resUserCols = $conn->query("SHOW COLUMNS FROM users");/$resUserCols = @$conn->query("SHOW COLUMNS FROM users");/g' config.php
    `;
    const res = await ssh.execCommand(cmd);
    console.log("Fix Result:", res.stdout, res.stderr);

    ssh.dispose();
  } catch (err) {
    console.error(err);
    ssh.dispose();
  }
}
fixConfigAutoMigrate();
