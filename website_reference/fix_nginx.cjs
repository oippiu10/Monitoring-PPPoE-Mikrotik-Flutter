const { NodeSSH } = require('node-ssh');
const ssh = new NodeSSH();

async function fixNginx() {
  try {
    await ssh.connect({
      host: '10.5.6.2',
      username: 'root',
      password: 'ilman271196',
      port: 22
    });

    const cmd = `
      sed -i "s|root /www/wwwroot/web.cmmnetwork.online/dist;|root /www/wwwroot/web.cmmnetwork.online;|g" /www/server/panel/vhost/nginx/web.cmmnetwork.online.conf
      systemctl reload nginx
    `;
    const res = await ssh.execCommand(cmd);
    console.log("Fix Result:", res.stdout, res.stderr);

    ssh.dispose();
  } catch (err) {
    console.error(err);
    ssh.dispose();
  }
}
fixNginx();
