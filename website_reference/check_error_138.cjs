const { NodeSSH } = require('node-ssh');
const ssh = new NodeSSH();

async function checkSpecificError() {
  try {
    await ssh.connect({
      host: '10.5.6.2',
      username: 'root',
      password: 'ilman271196',
      port: 22
    });

    const cmd = `
      echo "=== EXACT ERROR ==="
      tail -n 15 /www/wwwroot/web.cmmnetwork.online/api/error.log
      echo "=== LINE 135-145 ==="
      sed -n '135,145p' /www/wwwroot/web.cmmnetwork.online/api/config.php
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
checkSpecificError();
