const { NodeSSH } = require('node-ssh');
const ssh = new NodeSSH();

async function checkCurl() {
  try {
    await ssh.connect({
      host: '10.5.6.2',
      username: 'root',
      password: 'ilman271196',
      port: 22
    });

    const cmd = `
      echo "=== CURL TEST ==="
      curl -s -o /dev/null -w "%{http_code}" https://web.cmmnetwork.online/api/setup_database.php
      echo ""
      echo "=== PHP LOG CHECK ==="
      tail -n 5 /www/wwwroot/web.cmmnetwork.online/api/error.log
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
checkCurl();
