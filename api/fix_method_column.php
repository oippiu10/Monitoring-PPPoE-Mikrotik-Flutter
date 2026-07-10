<?php
require_once __DIR__ . '/config.php';

echo "Checking payments table structure...\n";

// Mengubah tipe kolom method dari ENUM menjadi VARCHAR(50) agar bisa menerima 'qris', 'e-wallet', 'titipan', dll.
$alter_sql = "ALTER TABLE payments MODIFY COLUMN method VARCHAR(50) NOT NULL DEFAULT 'cash'";

if ($conn->query($alter_sql)) {
    echo "SUCCESS: Column 'method' has been successfully changed to VARCHAR(50).\n";
    echo "You can now safely insert 'titipan', 'qris', 'e-wallet', etc.\n";
} else {
    echo "ERROR changing column: " . $conn->error . "\n";
}

$conn->close();
?>
