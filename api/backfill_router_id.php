<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/config.php';
require_once __DIR__ . '/router_id_helper.php';

try {
$raw = file_get_contents('php://input');
$data = json_decode($raw, true);
// Terima juga form-data/x-www-form-urlencoded atau GET jika tidak JSON
if (!is_array($data)) {
    $data = [];
    // Kumpulkan dari POST/GET jika tersedia
    if (isset($_POST['router_id'])) $data['router_id'] = $_POST['router_id'];
    if (isset($_POST['old_value'])) $data['old_value'] = $_POST['old_value'];
    if (isset($_POST['include_empty'])) $data['include_empty'] = $_POST['include_empty'];
    if (isset($_GET['router_id']) && empty($data['router_id'])) $data['router_id'] = $_GET['router_id'];
    if (isset($_GET['old_value']) && empty($data['old_value'])) $data['old_value'] = $_GET['old_value'];
    if (isset($_GET['include_empty']) && empty($data['include_empty'])) $data['include_empty'] = $_GET['include_empty'];
    // Jika tetap kosong, anggap invalid
    if (!isset($data['router_id'])) { throw new Exception('Invalid JSON'); }
}

    $router_id = requireRouterId($conn, $data);

    // Optional: nilai placeholder lama yang ingin diganti (default: 'DEFAULT-ROUTER' dan kosong)
    $old1 = isset($data['old_value']) ? trim($data['old_value']) : 'DEFAULT-ROUTER';
    // Default sengaja false: kalau true, satu panggilan menyapu SEMUA baris
    // ber-router_id kosong ke router yang kebetulan login saat itu — cara
    // paling gampang data antar router tertukar. Pemanggil harus meminta
    // perilaku itu secara eksplisit.
    $includeEmpty = isset($data['include_empty']) ? (bool)$data['include_empty'] : false;

    $conn->begin_transaction();

    // 1) users
    $whereUsers = [];
    $paramsUsers = [];
    $typesUsers = '';
    if ($includeEmpty) { $whereUsers[] = "router_id = ''"; }
    if ($old1 !== '') { $whereUsers[] = 'router_id = ?'; $paramsUsers[] = $old1; $typesUsers .= 's'; }
    if (!$whereUsers) { $whereUsers[] = "router_id = ''"; }
    $sqlUsers = "UPDATE users SET router_id = ? WHERE (" . implode(' OR ', $whereUsers) . ")";
    $stmt = $conn->prepare($sqlUsers);
    if (!$stmt) { throw new Exception($conn->error); }
    if ($typesUsers) {
      $types = 's' . $typesUsers;
      $stmt->bind_param($types, $router_id, ...$paramsUsers);
    } else {
      $stmt->bind_param('s', $router_id);
    }
    $stmt->execute();
    $affectedUsers = $stmt->affected_rows;
    $stmt->close();

    // 2) payments: sinkron ke users agar aman
    $sqlPay = "UPDATE payments p JOIN users u ON p.user_id = u.id SET p.router_id = u.router_id WHERE p.router_id = '' OR p.router_id = ?";
    $stmt = $conn->prepare($sqlPay);
    if (!$stmt) { throw new Exception($conn->error); }
    $oldPay = $old1;
    $stmt->bind_param('s', $oldPay);
    $stmt->execute();
    $affectedPayments = $stmt->affected_rows;
    $stmt->close();

    // 3) odp: opsional, ikut diganti placeholder
    $sqlOdp = "UPDATE odp SET router_id = ? WHERE router_id = '' OR router_id = ?";
    $stmt = $conn->prepare($sqlOdp);
    if (!$stmt) { throw new Exception($conn->error); }
    $stmt->bind_param('ss', $router_id, $old1);
    $stmt->execute();
    $affectedOdp = $stmt->affected_rows;
    $stmt->close();

    $conn->commit();

    echo json_encode([
      'success' => true,
      'router_id' => $router_id,
      'updated' => [
        'users' => $affectedUsers,
        'payments' => $affectedPayments,
        'odp' => $affectedOdp,
      ]
    ]);
} catch (Exception $e) {
    if (isset($conn) && $conn->errno === 0) { $conn->rollback(); }
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => $e->getMessage()]);
}

if (isset($conn)) { $conn->close(); }
?>


