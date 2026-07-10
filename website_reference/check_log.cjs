const { NodeSSH } = require('node-ssh');
const ssh = new NodeSSH();

async function checkLog() {
  try {
    await ssh.connect({
      host: '10.5.6.2',
      username: 'root',
      password: 'ilman271196',
      port: 22
    });

    const cmd = `
      echo "=== PHP ERROR LOG ==="
      cat /www/wwwroot/web.cmmnetwork.online/api/error.log | tail -n 25
      echo "=== CONFIG.PHP CONTENT ==="
      cat /www/wwwroot/web.cmmnetwork.online/api/config.php
      echo "=== NGINX ERROR LOG ==="
      tail -n 10 /www/wwwlogs/web.cmmnetwork.online.error.log
    `;
    const res = await ssh.execCommand(cmd);
    console.log(res.stdout);
    if (res.stderr) console.error(res.stderr);

    ssh.dispose();
  } catch (err) {
    console.error(err);
    ssh.dispose();
  }
}
checkLog();
