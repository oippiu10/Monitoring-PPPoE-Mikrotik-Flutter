const { NodeSSH } = require('node-ssh');
const ssh = new NodeSSH();

async function checkNginx() {
  try {
    await ssh.connect({
      host: '10.5.6.2',
      username: 'root',
      password: 'ilman271196',
      port: 22
    });

    const cmd = `
      echo "=== FILES IN ROOT ==="
      ls -la /www/wwwroot/web.cmmnetwork.online/
      echo "=== NGINX REWRITE CONFIG ==="
      cat /www/server/panel/vhost/rewrite/web.cmmnetwork.online.conf
      echo "=== NGINX SITE CONFIG ==="
      cat /www/server/panel/vhost/nginx/web.cmmnetwork.online.conf
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
checkNginx();
