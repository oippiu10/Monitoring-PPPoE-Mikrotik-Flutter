<?php
require_once __DIR__ . '/config.php';
header('Content-Type: text/plain');
$r = $conn->query('SHOW COLUMNS FROM users');
while($row = $r->fetch_row()) {
    echo $row[0] . ': ' . $row[1] . "\n";
}
?>
