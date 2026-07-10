<?php
require_once __DIR__ . '/config.php';
require_once __DIR__ . '/router_id_helper.php';
// Auth session removed for mobile app API access

$router_id = requireRouterIdFromGet($conn);

// Convert to software_id if a numeric ID was passed
$stmtRouter = $conn->prepare("SELECT software_id FROM mikrotik_routers WHERE software_id = ? OR id = ? LIMIT 1");
$stmtRouter->bind_param('ss', $router_id, $router_id);
$stmtRouter->execute();
if ($routerRow = $stmtRouter->get_result()->fetch_assoc()) {
    if (!empty($routerRow['software_id'])) {
        $router_id = $routerRow['software_id'];
    }
}
$stmtRouter->close();

$action = $_GET['action'] ?? '';

switch ($action) {
    case 'list':
        $month = $_GET['month'] ?? date('m');
        $year = $_GET['year'] ?? date('Y');
        $stmt = $conn->prepare("SELECT * FROM expenses WHERE router_id = ? AND MONTH(spent_at) = ? AND YEAR(spent_at) = ? ORDER BY spent_at DESC");
        $stmt->bind_param("sii", $router_id, $month, $year);
        $stmt->execute();
        $res = $stmt->get_result();
        $expenses = [];
        while ($row = $res->fetch_assoc()) {
            $expenses[] = $row;
        }
        echo json_encode(['success' => true, 'data' => $expenses]);
        break;

    case 'add':
        $isJson = (strpos($_SERVER['CONTENT_TYPE'] ?? '', 'application/json') !== false);
        $data = $isJson ? json_decode(file_get_contents('php://input'), true) : $_POST;
        $created_by = $data['created_by'] ?? null;
        
        $receipt_image = null;
        if (isset($_FILES['receipt_image']) && $_FILES['receipt_image']['error'] === UPLOAD_ERR_OK) {
            $ext = pathinfo($_FILES['receipt_image']['name'], PATHINFO_EXTENSION);
            $filename = uniqid('receipt_') . '.' . $ext;
            $uploadPath = __DIR__ . '/uploads/receipts/' . $filename;
            if (move_uploaded_file($_FILES['receipt_image']['tmp_name'], $uploadPath)) {
                $receipt_image = 'uploads/receipts/' . $filename;
            }
        }

        $stmt = $conn->prepare("INSERT INTO expenses (router_id, category, amount, note, spent_at, created_by, receipt_image) VALUES (?, ?, ?, ?, ?, ?, ?)");
        $stmt->bind_param("ssdssss", $router_id, $data['category'], $data['amount'], $data['note'], $data['spent_at'], $created_by, $receipt_image);
        if ($stmt->execute()) {
            echo json_encode(['success' => true, 'message' => 'Pengeluaran berhasil dicatat']);
        } else {
            echo json_encode(['success' => false, 'message' => $conn->error]);
        }
        break;

    case 'edit':
        $isJson = (strpos($_SERVER['CONTENT_TYPE'] ?? '', 'application/json') !== false);
        $data = $isJson ? json_decode(file_get_contents('php://input'), true) : $_POST;
        
        // Fetch old image to delete if necessary
        $stmtOld = $conn->prepare("SELECT receipt_image FROM expenses WHERE id = ? AND router_id = ?");
        $stmtOld->bind_param("is", $data['id'], $router_id);
        $stmtOld->execute();
        $oldImage = $stmtOld->get_result()->fetch_assoc()['receipt_image'] ?? null;
        $stmtOld->close();

        $receipt_image = $oldImage;
        if (isset($_FILES['receipt_image']) && $_FILES['receipt_image']['error'] === UPLOAD_ERR_OK) {
            $ext = pathinfo($_FILES['receipt_image']['name'], PATHINFO_EXTENSION);
            $filename = uniqid('receipt_') . '.' . $ext;
            $uploadPath = __DIR__ . '/uploads/receipts/' . $filename;
            if (move_uploaded_file($_FILES['receipt_image']['tmp_name'], $uploadPath)) {
                $receipt_image = 'uploads/receipts/' . $filename;
                // Delete old image
                if (!empty($oldImage) && file_exists(__DIR__ . '/' . $oldImage)) {
                    @unlink(__DIR__ . '/' . $oldImage);
                }
            }
        }

        $stmt = $conn->prepare("UPDATE expenses SET category = ?, amount = ?, note = ?, spent_at = ?, receipt_image = ? WHERE id = ? AND router_id = ?");
        $stmt->bind_param("sdsssss", $data['category'], $data['amount'], $data['note'], $data['spent_at'], $receipt_image, $data['id'], $router_id);
        if ($stmt->execute()) {
            echo json_encode(['success' => true, 'message' => 'Pengeluaran berhasil diubah']);
        } else {
            echo json_encode(['success' => false, 'message' => $conn->error]);
        }
        break;

    case 'delete':
        $id = $_GET['id'] ?? 0;
        
        $stmtOld = $conn->prepare("SELECT receipt_image FROM expenses WHERE id = ? AND router_id = ?");
        $stmtOld->bind_param("is", $id, $router_id);
        $stmtOld->execute();
        $oldImage = $stmtOld->get_result()->fetch_assoc()['receipt_image'] ?? null;
        $stmtOld->close();

        $stmt = $conn->prepare("DELETE FROM expenses WHERE id = ? AND router_id = ?");
        $stmt->bind_param("is", $id, $router_id);
        if ($stmt->execute()) {
            if (!empty($oldImage) && file_exists(__DIR__ . '/' . $oldImage)) {
                @unlink(__DIR__ . '/' . $oldImage);
            }
            echo json_encode(['success' => true, 'message' => 'Pengeluaran berhasil dihapus']);
        } else {
            echo json_encode(['success' => false, 'message' => $conn->error]);
        }
        break;

    case 'summary':
        $year = intval($_GET['year'] ?? date('Y'));
        $stmt = $conn->prepare("SELECT MONTH(spent_at) as month, SUM(amount) as total, COUNT(id) as count FROM expenses WHERE router_id = ? AND YEAR(spent_at) = ? GROUP BY MONTH(spent_at) ORDER BY month DESC");
        $stmt->bind_param("si", $router_id, $year);
        $stmt->execute();
        $res = $stmt->get_result();
        $summary = [];
        // Isi dengan 12 bulan atau bulan yang ada saja
        while ($row = $res->fetch_assoc()) {
            $summary[] = [
                'month' => intval($row['month']),
                'year' => $year,
                'total' => floatval($row['total']),
                'count' => intval($row['count'])
            ];
        }
        // Pastikan array terurut dari bulan terbaru (Desember -> Januari)
        echo json_encode(['success' => true, 'data' => $summary]);
        break;

    default:
        echo json_encode(['success' => false, 'message' => 'Aksi tidak valid']);
}
$conn->close();
?>