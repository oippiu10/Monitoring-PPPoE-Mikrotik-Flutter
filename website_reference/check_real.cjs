const { NodeSSH } = require('node-ssh');
const ssh = new NodeSSH();

async function checkRealError() {
  try {
    await ssh.connect({
      host: '10.5.6.2',
      username: 'root',
      password: 'ilman271196',
      port: 22
    });

    const cmd = `
      tail -n 10 /www/wwwroot/web.cmmnetwork.online/api/error.log
    `;
    const res = await ssh.execCommand(cmd);
    console.log("=== LATEST ERRORS ===");
    console.log(res.stdout);

    ssh.dispose();
  } catch (err) {
    console.error(err);
    ssh.dispose();
  }
}
checkRealError();
