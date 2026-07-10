<?php
require_once __DIR__ . '/config.php';
require_once __DIR__ . '/auth/require_auth.php';
require_once __DIR__ . '/auth/activity_log.php';

header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

require_admin_role(['admin', 'administrator', 'finance'], 'Akses ditolak. Hanya admin/finance yang boleh mengelola catatan keuangan.');

// Gunakan nama tabel finance_memos agar tidak bentrok dengan tabel finance_notes lama
$conn->query("
    CREATE TABLE IF NOT EXISTS finance_memos (
        id INT AUTO_INCREMENT PRIMARY KEY,
        router_id VARCHAR(255) NOT NULL,
        content TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
");

$input = [];
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $input = json_decode(file_get_contents('php://input'), true) ?: $_POST;
}

$action = $_REQUEST['action'] ?? $input['action'] ?? '';
$router_id = $_REQUEST['router_id'] ?? $input['router_id'] ?? '';
$router_id = trim($router_id);

if (!$router_id) {
    echo json_encode(['success' => false, 'message' => 'Router ID diperlukan']);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    if ($action === 'list') {
        $stmt = $conn->prepare("SELECT * FROM finance_memos WHERE router_id = ? ORDER BY created_at DESC");
        $stmt->bind_param('s', $router_id);
        $stmt->execute();
        $res = $stmt->get_result();
        $data = [];
        while ($row = $res->fetch_assoc()) {
            $data[] = $row;
        }
        echo json_encode(['success' => true, 'data' => $data]);
        exit;
    }
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if ($action === 'add') {
        $content = $input['content'] ?? '';
        
        if (trim($content) === '') {
            echo json_encode(['success' => false, 'message' => 'Catatan tidak boleh kosong']);
            exit;
        }
        
        $stmt = $conn->prepare("INSERT INTO finance_memos (router_id, content) VALUES (?, ?)");
        $stmt->bind_param('ss', $router_id, $content);
        
        if ($stmt->execute()) {
            log_admin_activity($conn, 'finance_note_add', "Menambahkan memo keuangan pada router {$router_id}", (int)($_SESSION['admin_id'] ?? 0));
            echo json_encode(['success' => true, 'message' => 'Catatan tersimpan']);
        } else {
            echo json_encode(['success' => false, 'message' => 'Gagal menyimpan catatan: ' . $conn->error]);
        }
        exit;
    }
    
    if ($action === 'delete') {
        $id = isset($input['id']) ? intval($input['id']) : 0;
        
        if (!$id) {
            echo json_encode(['success' => false, 'message' => 'ID catatan tidak valid']);
            exit;
        }
        
        $stmt = $conn->prepare("DELETE FROM finance_memos WHERE id = ? AND router_id = ?");
        $stmt->bind_param('is', $id, $router_id);
        
        if ($stmt->execute()) {
            log_admin_activity($conn, 'finance_note_delete', "Menghapus memo keuangan ID {$id}", (int)($_SESSION['admin_id'] ?? 0));
            echo json_encode(['success' => true, 'message' => 'Catatan dihapus']);
        } else {
            echo json_encode(['success' => false, 'message' => 'Gagal menghapus catatan']);
        }
        exit;
    }

    if ($action === 'edit') {
        $id = isset($input['id']) ? intval($input['id']) : 0;
        $content = $input['content'] ?? '';
        
        if (!$id || trim($content) === '') {
            echo json_encode(['success' => false, 'message' => 'ID dan konten tidak boleh kosong']);
            exit;
        }
        
        $stmt = $conn->prepare("UPDATE finance_memos SET content = ? WHERE id = ? AND router_id = ?");
        $stmt->bind_param('sis', $content, $id, $router_id);
        
        if ($stmt->execute()) {
            log_admin_activity($conn, 'finance_note_edit', "Mengubah memo keuangan ID {$id}", (int)($_SESSION['admin_id'] ?? 0));
            echo json_encode(['success' => true, 'message' => 'Catatan diperbarui']);
        } else {
            echo json_encode(['success' => false, 'message' => 'Gagal memperbarui catatan']);
        }
        exit;
    }
}

echo json_encode(['success' => false, 'message' => 'Invalid action']);
?>
