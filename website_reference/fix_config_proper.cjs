const { NodeSSH } = require('node-ssh');
const ssh = new NodeSSH();

async function fixConfigProperly() {
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
        
        // Remove the old buggy replacements if they exist
        \\$content = str_replace('@\\$conn->query', '\\$conn->query', \\$content);

        // Replace the specific lines with a try-catch wrapped version
        \\$odp_search = '\\$resOdpCols = \\$conn->query(\\"SHOW COLUMNS FROM odp\\");';
        \\$odp_replace = 'try { \\$resOdpCols = \\$conn->query(\\"SHOW COLUMNS FROM odp\\"); } catch (Exception \\$e) { \\$resOdpCols = false; }';
        \\$content = str_replace(\\$odp_search, \\$odp_replace, \\$content);

        \\$odc_search = '\\$resOdcCols = \\$conn->query(\\"SHOW COLUMNS FROM odc\\");';
        \\$odc_replace = 'try { \\$resOdcCols = \\$conn->query(\\"SHOW COLUMNS FROM odc\\"); } catch (Exception \\$e) { \\$resOdcCols = false; }';
        \\$content = str_replace(\\$odc_search, \\$odc_replace, \\$content);

        \\$users_search = '\\$resUserCols = \\$conn->query(\\"SHOW COLUMNS FROM users\\");';
        \\$users_replace = 'try { \\$resUserCols = \\$conn->query(\\"SHOW COLUMNS FROM users\\"); } catch (Exception \\$e) { \\$resUserCols = false; }';
        \\$content = str_replace(\\$users_search, \\$users_replace, \\$content);

        file_put_contents(\\$file, \\$content);
        echo 'Config patched properly with try-catch!';
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
fixConfigProperly();
