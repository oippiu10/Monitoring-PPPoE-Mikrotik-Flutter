<?php
ini_set('display_errors', 0);
ini_set('display_startup_errors', 0);
error_reporting(0);

// Set timeout limit to prevent long-running queries
set_time_limit(30);

header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE");
header("Access-Control-Allow-Headers: Content-Type");

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

try {
    // Koneksi ke database via config terpusat
    require_once __DIR__ . '/config.php';

    $action = isset($_GET['action']) ? $_GET['action'] : '';
    $router_id = isset($_GET['router_id']) ? trim($_GET['router_id']) : '';
    if ($router_id === '') { throw new Exception('router_id is required'); }

    // Summary: Ringkasan pembayaran per bulan/tahun
    if ($action === 'summary') {
        // Query summary pembayaran per bulan/tahun
        $sql = "SELECT payment_month, payment_year, 
                       SUM(CASE WHEN method != 'titipan' THEN amount ELSE 0 END) as total, 
                       COUNT(CASE WHEN method != 'titipan' THEN 1 ELSE NULL END) as count 
                FROM payments 
                WHERE router_id = ?
                GROUP BY payment_year, payment_month 
                ORDER BY payment_year DESC, payment_month DESC";
        
        $stmt = $conn->prepare($sql);
        $stmt->bind_param("s", $router_id);
        $stmt->execute();
        $result = $stmt->get_result();
        
        if (!$result) {
            throw new Exception("Database error: " . $conn->error);
        }
        
        $summary = [];
        while ($row = $result->fetch_assoc()) {
            $summary[] = [
                'month' => intval($row['payment_month']),
                'year' => intval($row['payment_year']),
                'total' => floatval($row['total']),
                'count' => intval($row['count'])
            ];
        }
        
        echo json_encode(["success" => true, "data" => $summary]);
        $stmt->close();
    }
    // Detail: Semua pembayaran untuk bulan/tahun tertentu
    else if ($action === 'detail') {
        $month = isset($_GET['month']) ? intval($_GET['month']) : 0;
        $year = isset($_GET['year']) ? intval($_GET['year']) : 0;
        
        if ($month <= 0 || $year <= 0) {
            throw new Exception("Parameter bulan/tahun tidak valid");
        }
        
        $sql = "SELECT p.*, u.username 
                FROM payments p
                LEFT JOIN users u ON p.user_id = u.id
                WHERE p.payment_month = ? AND p.payment_year = ? AND p.router_id = ?
                ORDER BY p.payment_date DESC";
        
        $stmt = $conn->prepare($sql);
        
        if (!$stmt) {
            throw new Exception("Database error: " . $conn->error);
        }
        
        $stmt->bind_param("iis", $month, $year, $router_id);
        $stmt->execute();
        $result = $stmt->get_result();
        
        $data = [];
        while ($row = $result->fetch_assoc()) {
            $data[] = $row;
        }
        
        $stmt->close();
        echo json_encode(["success" => true, "data" => $data]);
    }
    // Invalid action
    else {
        throw new Exception("Invalid action parameter");
    }

    $conn->close();
} catch (Exception $e) {
    // Tangani error dan kembalikan respons JSON yang valid
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "error" => $e->getMessage()
    ]);
}
exit();