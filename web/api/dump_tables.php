<?php
require __DIR__ . '/config.php';
$r = $conn->query("SHOW TABLES");
while($row = $r->fetch_array()) {
    echo $row[0] . "\n";
}
