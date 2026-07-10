<?php
header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');
error_reporting(E_ALL);

require_once __DIR__ . '/config.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method Not Allowed']);
    exit;
}

if (!isset($_FILES['csv_file']) || $_FILES['csv_file']['error'] !== UPLOAD_ERR_OK) {
    $errCode = isset($_FILES['csv_file']['error']) ? $_FILES['csv_file']['error'] : 'NULL';
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => "File CSV tidak ditemukan atau format sistem menolak unggahan server (PHP Error Code: $errCode). Coba ulangi dengan file lebih kecil."]);
    exit;
}

$routerId = trim($_POST['router_id'] ?? '');

$filename = $_FILES['csv_file']['tmp_name'];
$successCount = 0;
$errorCount = 0;

if (($handle = fopen($filename, "r")) !== FALSE) {
    // Read header line
    $header = fgetcsv($handle, 1000, ",");
    if (!$header) {
        echo json_encode(['success' => false, 'message' => 'Format CSV tidak valid atau kosong.']);
        exit;
    }
    
    // Normalize header formatting
    $header = array_map('strtolower', array_map('trim', $header));
    
    $expectedCols = ['username', 'password', 'profile'];
    $valid = true;
    foreach($expectedCols as $col) {
        if (!in_array($col, $header)) {
            $valid = false;
        }
    }
    
    if (!$valid) {
        echo json_encode(['success' => false, 'message' => 'Gagal: Kolom CSV tidak lengkap. Harap gunakan template yang disediakan.']);
        exit;
    }
    
    // Preparation
    $stmt = $conn->prepare("INSERT IGNORE INTO users (router_id, username, password, profile, wa, alamat) VALUES (?, ?, ?, ?, ?, ?)");
    
    while (($data = fgetcsv($handle, 1000, ",")) !== FALSE) {
        // Prevent mismatch between header rows and missing data rows
        if (count($header) !== count($data)) {
            // Fill missing trailing columns
            $data = array_pad($data, count($header), "");
        }
        $row = array_combine($header, $data);
        
        if (!$row || empty(trim($row['username'])) || empty(trim($row['password'])) || empty(trim($row['profile']))) {
            $errorCount++;
            continue;
        }
        
        $u  = trim($row['username']);
        $p  = trim($row['password']);
        $pr = trim($row['profile']);
        $w  = isset($row['wa']) ? trim($row['wa']) : '';
        $a  = isset($row['alamat']) ? trim($row['alamat']) : '';
        
        $stmt->bind_param("ssssss", $routerId, $u, $p, $pr, $w, $a);
        if ($stmt->execute()) {
            if ($stmt->affected_rows > 0) {
                $successCount++;
            } else {
                $errorCount++; // username might already exist in IGNORE constraint
            }
        } else {
            $errorCount++;
            $lastSqlErr = $stmt->error;
        }
    }
    fclose($handle);
    $stmt->close();
    
    $pesan = "Import selesai. Berhasil: $successCount, Dilewati/Gagal: $errorCount.";
    if (isset($lastSqlErr) && $lastSqlErr) $pesan .= " (Error Log Database: " . $lastSqlErr . ")";

    echo json_encode([
        'success' => true, 
        'message' => $pesan
    ]);
} else {
    echo json_encode(['success' => false, 'message' => 'Keamanan: Sistem anda tidak dapat membaca temporary file CSV.']);
}
?>
