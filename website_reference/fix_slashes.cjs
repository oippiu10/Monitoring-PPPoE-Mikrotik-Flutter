const { NodeSSH } = require('node-ssh');
const ssh = new NodeSSH();

async function fixSlashes() {
  try {
    await ssh.connect({
      host: '10.5.6.2',
      username: 'root',
      password: 'ilman271196',
      port: 22
    });

    const cmd = `
      php -r "
        \\$file = '/www/wwwroot/web.cmmnetwork.online/api/config.php';
        \\$content = file_get_contents(\\$file);
        \\$content = str_replace('\\\\\`', '\`', \\$content);
        file_put_contents(\\$file, \\$content);
        echo 'Slashes fixed!';
      "
    `;
    const res = await ssh.execCommand(cmd);
    console.log("Fix Result:", res.stdout, res.stderr);

    ssh.dispose();
  } catch (err) {
    console.error(err);
    ssh.dispose();
  }
}
fixSlashes();
