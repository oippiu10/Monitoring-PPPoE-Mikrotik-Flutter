<?php
require __DIR__ . '/config.php';
$r = $conn->query('SELECT * FROM users LIMIT 1');
print_r($r->fetch_assoc());
