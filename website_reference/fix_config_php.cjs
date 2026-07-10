const { NodeSSH } = require('node-ssh');
const ssh = new NodeSSH();

async function fixConfigWithPHP() {
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
        \\$content = str_replace('\\$conn->query(\\"SHOW COLUMNS FROM odp\\")', '@\\$conn->query(\\"SHOW COLUMNS FROM odp\\")', \\$content);
        \\$content = str_replace('\\$conn->query(\\"SHOW COLUMNS FROM odc\\")', '@\\$conn->query(\\"SHOW COLUMNS FROM odc\\")', \\$content);
        \\$content = str_replace('\\$conn->query(\\"SHOW COLUMNS FROM users\\")', '@\\$conn->query(\\"SHOW COLUMNS FROM users\\")', \\$content);
        file_put_contents(\\$file, \\$content);
        echo 'Config patched!';
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
fixConfigWithPHP();
