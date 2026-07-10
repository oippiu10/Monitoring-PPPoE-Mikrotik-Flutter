<?php
require_once __DIR__ . '/api/config.php';
$res = $conn->query("SHOW COLUMNS FROM finance_notes");
while($row = $res->fetch_assoc()) {
    print_r($row);
}
echo "TEST INSERT:\n";
$stmt = $conn->prepare("INSERT INTO finance_notes (router_id, content) VALUES ('global', 'test')");
if (!$stmt) echo "Prepare error: " . $conn->error . "\n";
else {
    if (!$stmt->execute()) echo "Execute error: " . $stmt->error . "\n";
    else echo "Insert OK\n";
}
