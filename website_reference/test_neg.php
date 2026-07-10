<?php
require 'api/config.php';
$res = $conn->query("SELECT id, name, capacity, ratio_total, splitter_type, type FROM odp WHERE ratio_total < 0 OR capacity < 0");
print_r($res->fetch_all(MYSQLI_ASSOC));
