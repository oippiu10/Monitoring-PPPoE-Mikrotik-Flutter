<?php
// ============================================
// KONFIGURASI DATABASE
// ============================================
require_once __DIR__ . '/config.php';
// Pastikan config.php memiliki objek $conn yang valid

// ============================================
// AUTO-MIGRATION (Cek Kolom Baru)
// ============================================
$conn->query("ALTER TABLE app_licenses ADD COLUMN IF NOT EXISTS client_address TEXT AFTER client_email");
$conn->query("ALTER TABLE app_licenses ADD COLUMN IF NOT EXISTS notes TEXT AFTER mikrotik_name");

// ============================================
// GENERATOR LISENSI (Logika Sama dengan App)
// ============================================

function generateLicenseCode($mikrotikId) {
    $secretKey = APP_SECRET_KEY;
    $dateObj = new DateTime();
    $strBulan = $dateObj->format('m');
    $strTahun = $dateObj->format('y');

    $rawData = $mikrotikId . $secretKey;
    $digest  = hash('sha256', $rawData, true); // Raw binary bytes
    $hashStr = strtoupper(hash('sha256', $rawData));

    // Digest[0] byte value
    $modulusAngka = ord($digest[0]) % 10;
    
    $blok1 = $strBulan . $modulusAngka . $strTahun;
    $blok2 = substr($hashStr, 0, 5);
    $blok3 = substr($hashStr, 5, 5);

    return "MKM-$blok1-$blok2-$blok3";
}

// Handle AJAX request untuk generate
if (isset($_GET['ajax_gen']) && !empty($_GET['rid'])) {
    header('Content-Type: application/json');
    echo json_encode(['code' => generateLicenseCode($_GET['rid'])]);
    exit;
}

// ============================================
// LOGIKA CRUD
// ============================================
if (isset($_POST['add_license'])) {
    $code = !empty($_POST['final_license_code']) ? $_POST['final_license_code'] : ($_POST['license_code'] ?? $_POST['license_code_auto'] ?? '');
    $code = $conn->real_escape_string($code);
    $client_name  = $conn->real_escape_string($_POST['client_name']);
    $client_phone = $conn->real_escape_string($_POST['client_phone']);
    $client_email = $conn->real_escape_string($_POST['client_email']);
    $client_addr  = $conn->real_escape_string($_POST['client_address']);
    $name         = $conn->real_escape_string($_POST['mikrotik_name']);
    $notes        = $conn->real_escape_string($_POST['notes']);
    $expired      = $conn->real_escape_string($_POST['expired_at']);
    $active       = isset($_POST['is_active']) ? 1 : 0;
    $conn->query("INSERT INTO app_licenses (license_code, client_name, client_phone, client_email, client_address, mikrotik_name, notes, is_active, expired_at) VALUES ('$code','$client_name','$client_phone','$client_email','$client_addr','$name','$notes',$active,'$expired')");
    // Hapus dari pending setelah didaftarkan
    $conn->query("DELETE FROM pending_requests WHERE license_code='$code'");
    header("Location: license_panel.php?msg=added");
    exit;
}
if (isset($_POST['edit_license'])) {
    $id    = (int)$_POST['id'];
    $code  = $conn->real_escape_string($_POST['license_code']);
    $name  = $conn->real_escape_string($_POST['client_name']);
    $phone = $conn->real_escape_string($_POST['client_phone']);
    $email = $conn->real_escape_string($_POST['client_email']);
    $addr  = $conn->real_escape_string($_POST['client_address']);
    $mtk   = $conn->real_escape_string($_POST['mikrotik_name']);
    $notes = $conn->real_escape_string($_POST['notes']);
    $exp   = $conn->real_escape_string($_POST['expired_at']);
    $act   = isset($_POST['is_active']) ? 1 : 0;
    
    $conn->query("UPDATE app_licenses SET license_code='$code', client_name='$name', client_phone='$phone', client_email='$email', client_address='$addr', mikrotik_name='$mtk', notes='$notes', is_active=$act, expired_at='$exp' WHERE id=$id");
    header("Location: license_panel.php?msg=updated");
    exit;
}
if (isset($_GET['delete'])) {
    $id = (int)$_GET['delete'];
    $conn->query("DELETE FROM app_licenses WHERE id=$id");
    header("Location: license_panel.php?msg=deleted");
    exit;
}
if (isset($_GET['toggle'])) {
    $id = (int)$_GET['toggle'];
    $conn->query("UPDATE app_licenses SET is_active = NOT is_active WHERE id=$id");
    header("Location: license_panel.php?msg=updated");
    exit;
}

// ============================================
// STATISTIK
// ============================================
$total      = $conn->query("SELECT COUNT(*) as c FROM app_licenses")->fetch_assoc()['c'];
$active_cnt = $conn->query("SELECT COUNT(*) as c FROM app_licenses WHERE is_active=1 AND expired_at >= CURDATE()")->fetch_assoc()['c'];
$expired_c  = $conn->query("SELECT COUNT(*) as c FROM app_licenses WHERE expired_at < CURDATE()")->fetch_assoc()['c'];
$blocked_c  = $conn->query("SELECT COUNT(*) as c FROM app_licenses WHERE is_active=0")->fetch_assoc()['c'];

// Pendng requests (perangkat belum terdaftar)
$conn->query("CREATE TABLE IF NOT EXISTS pending_requests (
    id INT AUTO_INCREMENT PRIMARY KEY, license_code VARCHAR(100) NOT NULL,
    router_id VARCHAR(100) DEFAULT NULL, attempt_count INT DEFAULT 1,
    first_seen DATETIME DEFAULT NOW(), last_seen DATETIME DEFAULT NOW(),
    UNIQUE KEY uq_license (license_code)
)");
$pendingResult = $conn->query("SELECT * FROM pending_requests ORDER BY last_seen DESC");
$pendingCount  = $pendingResult ? $pendingResult->num_rows : 0;

// Handle dismiss pending
if (isset($_GET['dismiss_pending'])) {
    $pid = (int)$_GET['dismiss_pending'];
    $conn->query("DELETE FROM pending_requests WHERE id=$pid");
    header('Location: license_panel.php?msg=updated'); exit;
}

// ============================================
// LOGIKA AKSI MASSAL (BULK ACTIONS)
// ============================================
if (isset($_POST['bulk_action']) && !empty($_POST['selected_ids'])) {
    $ids = implode(',', array_map('intval', $_POST['selected_ids']));
    $action = $_POST['bulk_action'];
    
    if ($action === 'delete') {
        $conn->query("DELETE FROM app_licenses WHERE id IN ($ids)");
        $msg = "deleted";
    } elseif ($action === 'block') {
        $conn->query("UPDATE app_licenses SET is_active = 0 WHERE id IN ($ids)");
        $msg = "updated";
    } elseif ($action === 'unblock') {
        $conn->query("UPDATE app_licenses SET is_active = 1 WHERE id IN ($ids)");
        $msg = "updated";
    }
    header("Location: license_panel.php?msg=$msg");
    exit;
}

// ============================================
// LOGIKA INSPEKSI LISENSI (AJAX)
// ============================================
if (isset($_GET['ajax_inspect'])) {
    header('Content-Type: application/json');
    $code = $conn->real_escape_string($_GET['code']);
    $q = $conn->query("SELECT * FROM app_licenses WHERE license_code = '$code' LIMIT 1");
    if ($row = $q->fetch_assoc()) {
        $row['status_text'] = ($row['is_active'] == 1) ? 'Aktif' : 'Diblokir';
        $row['status_class'] = ($row['is_active'] == 1) ? 'badge-active' : 'badge-blocked';
        echo json_encode(['success' => true, 'data' => $row]);
    } else {
        echo json_encode(['success' => false, 'message' => 'Kode tidak ditemukan']);
    }
    exit;
}

// ============================================
// PENCARIAN, FILTER & PAGINATION
// ============================================
$search = isset($_GET['q']) ? $conn->real_escape_string($_GET['q']) : '';
$filter = isset($_GET['status']) ? $conn->real_escape_string($_GET['status']) : '';
$page   = isset($_GET['page']) ? (int)$_GET['page'] : 1;
$limit  = 10;
$offset = ($page - 1) * $limit;

$sort      = isset($_GET['sort']) ? $_GET['sort'] : 'created_at';
$order     = isset($_GET['order']) ? $_GET['order'] : 'DESC';
$allowed   = ['license_code', 'client_name', 'client_address', 'mikrotik_name', 'created_at', 'expired_at', 'is_active'];
$sortField = in_array($sort, $allowed) ? $sort : 'created_at';
$orderDir  = ($order === 'ASC') ? 'ASC' : 'DESC';

// Query base untuk filter
$conditions = [];
if ($search) {
    $conditions[] = "(license_code LIKE '%$search%' OR client_name LIKE '%$search%' OR client_phone LIKE '%$search%' OR client_email LIKE '%$search%' OR client_address LIKE '%$search%' OR mikrotik_name LIKE '%$search%' OR notes LIKE '%$search%')";
}
if ($filter) {
    if ($filter == 'active')   $conditions[] = "is_active = 1 AND expired_at >= CURDATE()";
    if ($filter == 'expired')  $conditions[] = "expired_at < CURDATE()";
    if ($filter == 'blocked')  $conditions[] = "is_active = 0";
}

$whereSQL = count($conditions) > 0 ? "WHERE " . implode(" AND ", $conditions) : "";

// Hitung total untuk pagination
$totalRows = $conn->query("SELECT COUNT(*) as c FROM app_licenses $whereSQL")->fetch_assoc()['c'];
$totalPages = ceil($totalRows / $limit);

// Query utama dengan LIMIT & OFFSET
$query  = "SELECT * FROM app_licenses $whereSQL ORDER BY $sortField $orderDir LIMIT $limit OFFSET $offset";
$result = $conn->query($query);

// Helper: buat URL pagination & sort
function pageUrl($p) {
    $params = $_GET;
    $params['page'] = $p;
    return "?" . http_build_query($params);
}

function sortUrl($col) {
    global $sort, $order;
    $params = $_GET;
    $params['sort'] = $col;
    $params['order'] = ($sort == $col && $order == 'ASC') ? 'DESC' : 'ASC';
    $params['page'] = 1; // Kembali ke hal 1 saat urutan berubah
    return "?" . http_build_query($params);
}

function sortIcon($col) {
    global $sort, $order;
    if ($sort !== $col) return '<i class="bi bi-arrow-down-up sort-icon"></i>';
    return $order === 'ASC' ? '<i class="bi bi-sort-alpha-down sort-icon active"></i>' : '<i class="bi bi-sort-alpha-up sort-icon active"></i>';
}
?>
<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
<link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.0/font/bootstrap-icons.css" rel="stylesheet">
<style>
  :root {
    --bg: #0b0e14;
    /* HSL Palette for dynamic gradients */
    --accent-h: 235; --accent-s: 85%; --accent-l: 65%;
    --accent: hsl(var(--accent-h), var(--accent-s), var(--accent-l));
    --accent-light: hsl(var(--accent-h), var(--accent-s), 75%);
    --accent-dark: hsl(var(--accent-h), var(--accent-s), 50%);
    
    --card: #151921;
    --card-glass: rgba(21, 25, 33, 0.8);
    --card2: #1c222d;
    --border: rgba(255, 255, 255, 0.06);
    --border-bright: rgba(255, 255, 255, 0.12);
    
    --green: #10b981;
    --red: #ef4444;
    --yellow: #f59e0b;
    --text: #f1f5f9;
    --muted: #64748b;
    --sidebar-w: 260px;
  }
  * { box-sizing: border-box; -webkit-font-smoothing: antialiased; }
  body { background: var(--bg); color: var(--text); font-family: 'Inter', system-ui, -apple-system, sans-serif; min-height: 100vh; margin: 0; line-height: 1.5; }

  /* SIDEBAR */
  .sidebar { width: var(--sidebar-w); height: 100vh; background: var(--card-glass); backdrop-filter: blur(16px); -webkit-backdrop-filter: blur(16px); border-right: 1px solid var(--border); position: fixed; top: 0; left: 0; z-index: 100; display: flex; flex-direction: column; transition: all 0.3s ease; }
  .sidebar-logo { padding: 32px 24px; display: flex; align-items: center; gap: 12px; }
  .sidebar-logo i { font-size: 24px; color: var(--accent); filter: drop-shadow(0 0 8px hsla(var(--accent-h), var(--accent-s), var(--accent-l), 0.4)); }
  .sidebar-logo span { font-weight: 800; font-size: 20px; letter-spacing: -0.5px; background: linear-gradient(135deg, #fff 0%, var(--accent-light) 100%); -webkit-background-clip: text; -webkit-text-fill-color: transparent; }

  .sidebar-nav { flex: 1; padding: 0 16px; }
  .nav-label { font-size: 10px; font-weight: 800; text-transform: uppercase; letter-spacing: 1.5px; color: var(--muted); margin: 24px 12px 12px; opacity: 0.6; }
  
  .nav-item { display: flex; align-items: center; gap: 12px; padding: 12px 16px; color: var(--muted); text-decoration: none; border-radius: 12px; font-size: 14px; font-weight: 600; transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1); margin-bottom: 4px; }
  .nav-item i { font-size: 18px; transition: transform 0.2s; }
  .nav-item:hover { background: rgba(255, 255, 255, 0.04); color: #fff; }
  .nav-item:hover i { transform: translateX(2px); }
  
  .nav-item.active { background: hsla(var(--accent-h), var(--accent-s), var(--accent-l), 0.1); color: var(--accent-light); position: relative; }
  .nav-item.active::before { content: ''; position: absolute; left: 0; top: 15%; height: 70%; width: 3px; background: var(--accent); border-radius: 0 4px 4px 0; box-shadow: 0 0 10px var(--accent); }
  .nav-item.active i { color: var(--accent); }

  .sidebar-footer { padding: 24px; border-top: 1px solid var(--border); font-size: 11px; color: var(--muted); }
  .sidebar-footer p { margin: 0; opacity: 0.7; }

  /* MAIN AREA */
  .main { margin-left: var(--sidebar-w); padding: 48px; min-height: 100vh; position: relative; }
  
  /* TOPBAR */
  .topbar { display: flex; align-items: flex-start; justify-content: space-between; margin-bottom: 40px; }
  .topbar h1 { font-size: 32px; font-weight: 800; margin: 0; letter-spacing: -0.8px; }
  .topbar p { font-size: 14px; color: var(--muted); margin-top: 6px; }

  /* STAT CARDS */
  /* STAT CARDS */
  .stat-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 24px; margin-bottom: 40px; }
  .stat-card { background: var(--card); border: 1px solid var(--border); border-radius: 20px; padding: 24px; display: flex; align-items: center; gap: 20px; transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1); position: relative; overflow: hidden; }
  .stat-card::after { content: ''; position: absolute; inset: 0; background: linear-gradient(135deg, rgba(255,255,255,0.05) 0%, rgba(255,255,255,0) 100%); opacity: 0; transition: opacity 0.3s; }
  .stat-card:hover { transform: translateY(-5px); border-color: var(--border-bright); box-shadow: 0 20px 40px rgba(0,0,0,0.4); }
  .stat-card:hover::after { opacity: 1; }
  .stat-icon { width: 56px; height: 56px; border-radius: 16px; display: flex; align-items: center; justify-content: center; font-size: 24px; flex-shrink: 0; transition: transform 0.3s; }
  .stat-card:hover .stat-icon { transform: scale(1.1) rotate(-5deg); }
  .stat-icon.purple { background: hsla(var(--accent-h), var(--accent-s), var(--accent-l), 0.1); color: var(--accent); }
  .stat-icon.green  { background: rgba(16,185,129, 0.1); color: var(--green); }
  .stat-icon.red    { background: rgba(239,68,68, 0.1); color: var(--red); }
  .stat-icon.yellow { background: rgba(245,158,11, 0.1); color: var(--yellow); }
  .stat-val { font-size: 32px; font-weight: 800; line-height: 1; letter-spacing: -1px; }
  .stat-lbl { font-size: 13px; color: var(--muted); margin-top: 6px; font-weight: 500; }

  /* TABLE CARD */
  .table-card { background: var(--card); border: 1px solid var(--border); border-radius: 24px; overflow: hidden; box-shadow: 0 10px 30px rgba(0,0,0,0.2); }
  .table-card-header { padding: 24px 30px; border-bottom: 1px solid var(--border); display: flex; align-items: center; gap: 16px; flex-wrap: wrap; background: rgba(255,255,255,0.01); }
  .table-card-header h2 { font-size: 18px; font-weight: 700; margin: 0; flex: 1; letter-spacing: -0.3px; }

  .search-box { position: relative; }
  .search-box input { background: var(--card2); border: 1px solid var(--border); color: var(--text); border-radius: 12px; padding: 12px 16px 12px 42px; font-size: 14px; width: 280px; transition: all 0.2s; }
  .search-box input::placeholder { color: var(--muted); }
  .search-box input:focus { outline: none; border-color: var(--accent); background: var(--bg); box-shadow: 0 0 0 4px hsla(var(--accent-h), var(--accent-s), var(--accent-l), 0.1); }
  .search-box i { position: absolute; left: 16px; top: 50%; transform: translateY(-50%); color: var(--muted); font-size: 16px; }

  table { width: 100%; border-collapse: separate; border-spacing: 0; }
  th { font-size: 11px; font-weight: 700; letter-spacing: 1px; text-transform: uppercase; color: var(--muted); padding: 16px 24px; background: rgba(255,255,255,0.02); height: 50px; }
  td { padding: 18px 24px; border-bottom: 1px solid var(--border); font-size: 14px; vertical-align: middle; transition: background 0.2s; }
  tr:hover td { background: rgba(255,255,255,0.03); }

  .code-badge { font-family: 'JetBrains Mono', monospace; font-size: 12px; font-weight: 700; color: var(--accent-light); background: hsla(var(--accent-h), var(--accent-s), var(--accent-l), 0.1); padding: 6px 12px; border-radius: 8px; border: 1px solid hsla(var(--accent-h), var(--accent-s), var(--accent-l), 0.2); }
  .client-name { font-weight: 700; color: #fff; font-size: 14px; }
  .client-sub  { font-size: 12px; color: var(--muted); margin-top: 4px; display: flex; align-items: center; gap: 6px; }
  .router-id   { font-family: monospace; font-size: 11px; color: var(--muted); background: var(--card2); padding: 2px 6px; border-radius: 4px; border: 1px solid var(--border); }

  .status-pill { font-size: 11px; font-weight: 800; padding: 5px 12px; border-radius: 50px; white-space: nowrap; text-transform: uppercase; letter-spacing: 0.5px; }
  .badge-active  { background: rgba(16,185,129, 0.12); color: #10b981; border: 1px solid rgba(16,185,129, 0.2); }
  .badge-expired { background: rgba(239,68,68, 0.12); color: #ef4444; border: 1px solid rgba(239,68,68, 0.2); }
  .badge-blocked { background: rgba(245,158,11, 0.12); color: #f59e0b; border: 1px solid rgba(245,158,11, 0.2); }

  .btn-action { border: 1px solid var(--border); border-radius: 10px; padding: 8px 14px; font-size: 13px; font-weight: 600; cursor: pointer; transition: all 0.2s; background: var(--card2); color: var(--text); display: inline-flex; align-items: center; gap: 6px; }
  .btn-action:hover { border-color: var(--muted); background: var(--bg); transform: translateY(-2px); }
  .btn-block:hover { color: var(--yellow); border-color: var(--yellow); }
  .btn-delete:hover { color: var(--red); border-color: var(--red); }
  .btn-unblock:hover { color: var(--green); border-color: var(--green); }

  .btn-add { background: var(--accent); color: #fff; border: none; border-radius: 12px; padding: 12px 24px; font-size: 14px; font-weight: 700; cursor: pointer; display: flex; align-items: center; gap: 8px; transition: all 0.3s; box-shadow: 0 4px 15px hsla(var(--accent-h), var(--accent-s), var(--accent-l), 0.3); }
  .btn-add:hover { background: var(--accent-light); transform: translateY(-2px); box-shadow: 0 8px 25px hsla(var(--accent-h), var(--accent-s), var(--accent-l), 0.4); }

  /* MODAL */
  .modal-overlay { display: none; position: fixed; inset: 0; background: rgba(3, 7, 18, 0.85); backdrop-filter: blur(8px); -webkit-backdrop-filter: blur(8px); z-index: 1100; align-items: center; justify-content: center; padding: 20px; }
  .modal-overlay.show { display: flex; }
  .modal-box { background: var(--card); border: 1px solid var(--border-bright); border-radius: 28px; padding: 32px; width: 100%; max-width: 540px; animation: modalIn 0.4s cubic-bezier(0.16, 1, 0.3, 1); max-height: 90vh; overflow-y: auto; box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5); }
  @keyframes modalIn { from { opacity: 0; transform: scale(0.95) translateY(10px); } to { opacity: 1; transform: scale(1) translateY(0); } }
  
  .modal-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 28px; }
  .modal-header h3 { font-size: 20px; font-weight: 800; margin: 0; letter-spacing: -0.5px; }
  .modal-close { background: var(--card2); border: 1px solid var(--border); color: var(--muted); width: 32px; height: 32px; border-radius: 50%; display: flex; align-items: center; justify-content: center; cursor: pointer; transition: all 0.2s; }
  .modal-close:hover { background: var(--red); color: #fff; border-color: var(--red); transform: rotate(90deg); }

  .form-label { font-size: 11px; font-weight: 800; letter-spacing: 1px; text-transform: uppercase; color: var(--muted); margin-bottom: 8px; display: block; opacity: 0.8; }
  .form-ctrl { width: 100%; background: var(--card2); border: 1px solid var(--border); color: var(--text); border-radius: 12px; padding: 12px 16px; font-size: 14px; margin-bottom: 20px; transition: all 0.2s; }
  .form-ctrl:focus { outline: none; border-color: var(--accent); background: var(--bg); box-shadow: 0 0 0 4px hsla(var(--accent-h), var(--accent-s), var(--accent-l), 0.1); }
  .form-ctrl::placeholder { color: var(--muted); opacity: 0.5; }

  .btn-primary-modal { background: var(--accent); color: #fff; border: none; border-radius: 12px; padding: 14px 24px; font-size: 15px; font-weight: 700; cursor: pointer; width: 100%; transition: all 0.3s; box-shadow: 0 4px 15px hsla(var(--accent-h), var(--accent-s), var(--accent-l), 0.3); }
  .btn-primary-modal:hover { background: var(--accent-light); transform: translateY(-2px); box-shadow: 0 8px 25px hsla(var(--accent-h), var(--accent-s), var(--accent-l), 0.4); }
  .btn-cancel { background: transparent; color: var(--muted); border: 1px solid var(--border); border-radius: 12px; padding: 14px 24px; font-size: 15px; font-weight: 600; cursor: pointer; width: 100%; margin-bottom: 12px; transition: all 0.2s; }
  .btn-cancel:hover { background: rgba(255,255,255,0.03); color: #fff; }

  /* COMPONENT: PENDING ACTIVATION */
  .pending-alert { background: hsla(38, 92%, 50%, 0.1); border: 1px solid hsla(38, 92%, 50%, 0.2); border-radius: 16px; padding: 16px 24px; margin-bottom: 32px; display: flex; align-items: center; justify-content: space-between; animation: pulseGlow 3s infinite; }
  @keyframes pulseGlow { 0%, 100% { box-shadow: 0 0 0 rgba(245,158,11,0); } 50% { box-shadow: 0 0 20px rgba(245,158,11,0.15); } }
  .pending-info { display: flex; align-items: center; gap: 16px; }
  .pending-badge { background: var(--yellow); color: #000; font-size: 10px; font-weight: 800; padding: 2px 8px; border-radius: 20px; }
  
  .bulk-bar { position: fixed; bottom: 32px; left: calc(var(--sidebar-w) + 48px); right: 48px; background: hsla(235, 85%, 65%, 0.95); backdrop-filter: blur(10px); color: #fff; padding: 16px 32px; border-radius: 20px; display: flex; align-items: center; justify-content: space-between; z-index: 1000; transform: translateY(150%); transition: all 0.4s cubic-bezier(0.175, 0.885, 0.32, 1.275); box-shadow: 0 20px 40px rgba(0,0,0,0.5); }
  .bulk-bar.show { transform: translateY(0); }
  .toast-item { background: var(--card); border: 1px solid var(--border); border-radius: 10px; padding: 14px 20px; display: flex; align-items: center; gap: 10px; font-size: 13px; box-shadow: 0 4px 20px rgba(0,0,0,.4); animation: fadeIn .3s ease; }
  .toast-item i { font-size: 18px; }
  .toast-item.success { border-left: 3px solid var(--green); }
  .toast-item.success i { color: var(--green); }
  @keyframes fadeIn { from { opacity: 0; transform: translateX(20px); } to { opacity: 1; transform: translateX(0); } }

  /* EMPTY */
  .empty-state { text-align: center; padding: 60px 20px; color: var(--muted); }
  .empty-state i { font-size: 48px; display: block; margin-bottom: 16px; opacity: .3; }

  /* LAST SEEN dot */
  .live-dot { width: 7px; height: 7px; border-radius: 50%; background: var(--green); display: inline-block; margin-right: 5px; animation: pulse 1.5s infinite; }
  @keyframes pulse { 0%,100%{opacity:1;} 50%{opacity:.3;} }

  /* PENDING CARD */
  .pending-section { margin-bottom: 20px; }
  .pending-alert { background: rgba(245,158,11,.08); border: 1px solid rgba(245,158,11,.3); border-radius: 14px; overflow: hidden; }
  .pending-header { padding: 14px 20px; display: flex; align-items: center; gap: 10px; border-bottom: 1px solid rgba(245,158,11,.2); }
  .pending-header h3 { font-size: 14px; font-weight: 700; color: var(--yellow); margin: 0; flex: 1; }
  .pending-badge { background: var(--yellow); color: #000; font-size: 11px; font-weight: 800; border-radius: 20px; padding: 2px 8px; }
  .pending-item { display: flex; align-items: center; gap: 12px; padding: 12px 20px; border-bottom: 1px solid rgba(245,158,11,.1); flex-wrap: wrap; }
  .pending-item:last-child { border-bottom: none; }
  .pending-code { font-family: monospace; font-size: 13px; font-weight: 700; color: var(--yellow); background: rgba(245,158,11,.1); padding: 4px 10px; border-radius: 6px; }
  .pending-meta { font-size: 11px; color: var(--muted); flex: 1; }
  .btn-approve { background: var(--green); color: #fff; border: none; border-radius: 7px; padding: 6px 14px; font-size: 12px; font-weight: 700; cursor: pointer; transition: all .2s; white-space: nowrap; }
  .btn-approve:hover { background: #059669; }
  .btn-dismiss { background: transparent; color: var(--muted); border: 1px solid var(--border); border-radius: 7px; padding: 6px 12px; font-size: 12px; cursor: pointer; }
  .btn-dismiss:hover { color: var(--red); border-color: var(--red); }

  /* METHOD TOGGLE */
  .method-toggle { display: flex; background: var(--bg); border-radius: 10px; padding: 4px; margin-bottom: 20px; border: 1px solid var(--border); }
  .method-btn { flex: 1; border: none; background: transparent; color: var(--muted); padding: 8px; border-radius: 8px; font-size: 13px; cursor: pointer; font-weight: 600; transition: all .2s; }
  .method-btn.active { background: var(--accent); color: #fff; }
  .method-content { display: none; }
  .method-content.active { display: block; }

  /* HELP CONTENT */
  .help-card { background: var(--card); border: 1px solid var(--border); border-radius: 14px; padding: 30px; max-width: 800px; margin: 0 auto; }
  .help-step { display: flex; gap: 20px; align-items: flex-start; margin-bottom: 25px; padding-bottom: 20px; border-bottom: 1px solid rgba(255,255,255,0.05); }
  .help-step:last-child { border-bottom: none; margin-bottom: 0; padding-bottom: 0; }
  .help-icon { width: 44px; height: 44px; background: rgba(99,102,241,0.1); color: var(--accent2); border-radius: 10px; display: flex; align-items: center; justify-content: center; font-size: 20px; flex-shrink: 0; }
  .help-content h4 { font-size: 16px; font-weight: 700; margin: 0 0 6px 0; color: var(--text); }
  .help-content p { font-size: 13px; color: var(--muted); margin: 0; line-height: 1.6; }

  /* SORTABLE TH */
  .sortable { cursor: pointer; user-select: none; }
  .sortable:hover { color: var(--accent2); }
  .sort-icon { font-size: 10px; margin-left: 4px; opacity: .5; }
  .sort-icon.active { opacity: 1; color: var(--accent2); }

  /* CLICKABLE ROW */
  tbody tr { cursor: pointer; }
  tbody tr:hover td { background: rgba(99,102,241,0.06); }

  /* MOBILE TOPBAR */
  .mobile-topbar { display: none; background: var(--card); border-bottom: 1px solid var(--border); padding: 12px 16px; align-items: center; justify-content: space-between; position: sticky; top:0; z-index: 50; }
  .hamburger { background: none; border: none; color: var(--text); font-size: 22px; cursor: pointer; padding: 0; }
  .sidebar-overlay { display: none; position: fixed; inset: 0; background: rgba(0,0,0,.6); z-index: 99; }
  .sidebar-overlay.show { display: block; }
  .sidebar.mobile-open { display: flex !important; }

  /* DETAIL MODAL */
  .detail-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; margin-bottom: 4px; }
  .detail-item label { font-size: 10px; font-weight: 700; letter-spacing: .5px; text-transform: uppercase; color: var(--muted); display: block; margin-bottom: 4px; }
  .detail-item .val { font-size: 13px; color: var(--text); word-break: break-all; }
  .detail-divider { border: none; border-top: 1px solid var(--border); margin: 16px 0; }
  .detail-actions { display: flex; gap: 8px; margin-top: 16px; }
  .detail-actions a, .detail-actions button { flex: 1; text-align: center; }

  @media (max-width: 900px) {
    .sidebar { display: none; }
    .mobile-topbar { display: flex; }
    .main { margin-left: 0; padding: 16px; padding-top: 8px; }
    .stat-grid { grid-template-columns: 1fr 1fr; }
    .topbar p { display: none; }
    .detail-grid { grid-template-columns: 1fr; }
    .form-row { grid-template-columns: 1fr; }
    .search-box input { width: 160px; }
  }

  /* PAGINATION */
  .pagination { display: flex; gap: 5px; justify-content: center; margin-top: 25px; align-items: center; }
  .page-link { background: var(--bg); border: 1px solid var(--border); color: var(--muted); padding: 7px 14px; border-radius: 8px; text-decoration: none; font-size: 13px; font-weight: 600; transition: all .2s; }
  .page-link:hover { border-color: var(--accent); color: var(--text); }
  .page-link.active { background: var(--accent); border-color: var(--accent); color: #fff; }
  .page-link.disabled { opacity: 0.4; cursor: not-allowed; }

  /* FILTER DROPDOWN */
  .filter-ctrl { background: var(--bg); border: 1px solid var(--border); color: var(--text); padding: 8px 12px; border-radius: 9px; font-size: 13px; outline: none; cursor: pointer; }
  .filter-ctrl:focus { border-color: var(--accent); }

  /* BULK ACTION BAR */
  .bulk-bar { position: fixed; bottom: 20px; left: 50%; transform: translateX(-50%) translateY(100px); background: #1e1e2e; border: 1px solid var(--accent); padding: 12px 24px; border-radius: 50px; display: flex; align-items: center; gap: 15px; box-shadow: 0 10px 30px rgba(0,0,0,0.5); z-index: 900; transition: transform 0.3s cubic-bezier(0.175, 0.885, 0.32, 1.275); }
  .bulk-bar.show { transform: translateX(-50%) translateY(0); }
  .bulk-info { color: #fff; font-size: 13px; font-weight: 600; border-right: 1px solid rgba(255,255,255,0.1); padding-right: 15px; }
  .btn-bulk { background: none; border: none; color: #fff; font-size: 13px; font-weight: 600; cursor: pointer; display: flex; align-items: center; gap: 6px; padding: 6px 12px; border-radius: 8px; transition: background 0.2s; }
  .btn-bulk:hover { background: rgba(255,255,255,0.05); }
  .btn-bulk-delete:hover { color: var(--red); background: rgba(239, 68, 68, 0.1); }

  /* CHECKBOX CUSTOM */
  .td-check { width: 30px; text-align: center; }
  .custom-check { width: 18px; height: 18px; cursor: pointer; accent-color: var(--accent); }

  @media (max-width: 600px) {
    .stat-grid { grid-template-columns: 1fr 1fr; }
    .stat-val { font-size: 22px; }
    .topbar { flex-wrap: wrap; gap: 10px; }
  }
</style>
</head>
<body>

<!-- MOBILE OVERLAY -->
<div class="sidebar-overlay" id="sidebarOverlay" onclick="closeSidebar()"></div>

<!-- MOBILE TOPBAR -->
<div class="mobile-topbar" id="mobileTopbar">
  <button class="hamburger" onclick="openSidebar()"><i class="bi bi-list"></i></button>
  <strong style="color:var(--accent);">LicenseHub</strong>
  <div style="width:22px;"></div>
</div>

<div class="sidebar-overlay" id="sidebarOverlay" onclick="closeSidebar()"></div>

<!-- SIDEBAR -->
<div class="sidebar" id="sidebar">
  <div class="sidebar-logo">
    <i class="bi bi-cpu-fill"></i>
    <span>LicenseHub</span>
  </div>
  
  <nav class="sidebar-nav">
    <div class="sidebar-label">Menu Utama</div>
    <a href="javascript:void(0)" class="nav-item active" id="nav-main" onclick="switchSection('main')">
      <i class="bi bi-grid-1x2-fill"></i>
      <span>Dashboard Lisensi</span>
    </a>
    
    <div class="sidebar-label">Informasi</div>
    <a href="javascript:void(0)" class="nav-item" id="nav-help" onclick="switchSection('help')">
      <i class="bi bi-info-circle-fill"></i>
      <span>Dokumentasi Sistem</span>
    </a>
  </nav>

  <div class="sidebar-footer">
    <div style="background:hsla(var(--accent-h), var(--accent-s), var(--accent-l), 0.05); padding:12px; border-radius:14px; margin-bottom:16px; border:1px solid hsla(var(--accent-h), var(--accent-s), var(--accent-l), 0.1);">
        <small style="display:block; color:var(--muted); font-size:9px; text-transform:uppercase; letter-spacing:0.5px; margin-bottom:4px;">Waktu Server (WIB)</small>
        <div style="font-size:13px; font-weight:700; color:var(--accent-light);"><i class="bi bi-clock-history"></i> <?= date('d M Y, H:i') ?></div>
    </div>
    <p>CMM Network &copy; 2026</p>
    <p style="font-size:9px; opacity:0.5; margin-top:4px;">Premium Management Suite</p>
  </div>
</div>

<!-- MAIN CONTENT AREA -->
<div class="main">
  
  <!-- SECTION: MANAJEMEN LISENSI -->
  <div id="section-main">
    <div class="topbar">
      <div>
        <h1>Manajemen Lisensi</h1>
        <p>Pantau & kelola seluruh lisensi aktif Mikrotik Monitor</p>
      </div>
      <div style="display:flex; gap:12px;">
        <button class="btn-action" style="padding:12px 20px;" onclick="document.getElementById('inspectModal').classList.add('show')">
          <i class="bi bi-search"></i> Cek Lisensi
        </button>
        <button class="btn-add" onclick="document.getElementById('addModal').classList.add('show')">
          <i class="bi bi-plus-lg"></i> Tambah Lisensi
        </button>
      </div>
    </div>

    <!-- STAT CARDS -->
    <div class="stat-grid">
      <div class="stat-card">
        <div class="stat-icon purple"><i class="bi bi-key-fill"></i></div>
        <div>
          <div class="stat-val"><?= $total ?></div>
          <div class="stat-lbl">Total Lisensi</div>
        </div>
      </div>
    <div class="stat-card">
      <div class="stat-icon green"><i class="bi bi-check-circle-fill"></i></div>
      <div>
        <div class="stat-val"><?= $active_cnt ?></div>
        <div class="stat-lbl">Lisensi Aktif</div>
      </div>
    </div>
    <div class="stat-card">
      <div class="stat-icon red"><i class="bi bi-clock-history"></i></div>
      <div>
        <div class="stat-val"><?= $expired_c ?></div>
        <div class="stat-lbl">Sudah Expired</div>
      </div>
    </div>
    <div class="stat-card">
      <div class="stat-icon yellow"><i class="bi bi-slash-circle-fill"></i></div>
      <div>
        <div class="stat-val"><?= $blocked_c ?></div>
        <div class="stat-lbl">Diblokir</div>
      </div>
    </div>
  </div>

    <!-- PENDING ACTIVATION ALERT -->
    <?php if ($pendingCount > 0): ?>
    <div class="pending-alert">
      <div class="pending-info">
        <div style="width:48px; height:48px; background:hsla(38, 92%, 50%, 0.15); border-radius:14px; display:flex; align-items:center; justify-content:center; color:var(--yellow); font-size:20px;">
          <i class="bi bi-bell-fill"></i>
        </div>
        <div>
          <div style="font-weight:800; font-size:15px; letter-spacing:-0.3px;">Permintaan Aktivasi Masuk</div>
          <div style="font-size:13px; color:var(--muted); margin-top:2px;">Ada <?= $pendingCount ?> perangkat menunggu validasi Anda.</div>
        </div>
      </div>
      <div style="display:flex; align-items:center; gap:12px;">
          <div class="pending-badge"><?= $pendingCount ?> BARU</div>
          <a href="#section-pending" class="btn-action" style="font-size:11px; padding:8px 16px;">Lihat Rincian</a>
      </div>
    </div>
    <?php endif; ?>

    <!-- DETAIL PENDING SECTION (Optional show) -->
    <?php if ($pendingCount > 0): ?>
    <div id="section-pending" style="margin-bottom:40px; background:var(--card); border:1px solid var(--border); border-radius:24px; padding:24px;">
      <h3 style="font-size:15px; font-weight:800; margin-bottom:20px; color:var(--muted); text-transform:uppercase; letter-spacing:1px;">Daftar Permintaan Baru</h3>
      <div style="display:grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap:16px;">
        <?php $pendingResult->data_seek(0); while($p = $pendingResult->fetch_assoc()): ?>
        <div style="background:var(--card2); border:1px solid var(--border); border-radius:18px; padding:20px; position:relative;">
          <div style="font-family:'JetBrains Mono', monospace; font-weight:800; color:var(--accent-light); margin-bottom:8px; font-size:14px;"><?= htmlspecialchars($p['license_code']) ?></div>
          <div style="font-size:12px; color:var(--muted); line-height:1.6; margin-bottom:16px;">
            Router ID: <code style="color:var(--text);"><?= $p['router_id'] ?: '-' ?></code><br>
            Aktivasi: <strong><?= $p['attempt_count'] ?>x Percobaan</strong><br>
            Waktu: <?= date('d M, H:i', strtotime($p['last_seen'])) ?>
          </div>
          <div style="display:flex; gap:8px;">
            <button class="btn-add" style="flex:1; justify-content:center; padding:10px;" onclick="prefillForm('<?= htmlspecialchars($p['license_code'], ENT_QUOTES) ?>', '<?= htmlspecialchars($p['router_id'] ?? '', ENT_QUOTES) ?>')">
              <i class="bi bi-check2-circle"></i> Terima
            </button>
            <a href="?dismiss_pending=<?= $p['id'] ?>" class="btn-action" style="background:rgba(239, 68, 68, 0.1); color:var(--red); border-color:transparent;" onclick="return confirm('Abaikan permintaan ini?')">
              <i class="bi bi-trash"></i>
            </a>
          </div>
        </div>
        <?php endwhile; ?>
      </div>
    </div>
    <?php endif; ?>

  <!-- TABLE CARD -->
  <div class="table-card">
    <div class="table-card-header">
      <h2><i class="bi bi-list-ul" style="margin-right:8px;"></i>Daftar Lisensi Klien</h2>
      <div style="display:flex;gap:10px;align-items:center;flex-wrap:wrap;">
        <select id="filterStatus" class="filter-ctrl" onchange="applyFilters()">
          <option value="">Semua Status</option>
          <option value="active" <?= $filter=='active'?'selected':'' ?>>Aktif</option>
          <option value="expired" <?= $filter=='expired'?'selected':'' ?>>Expired</option>
          <option value="blocked" <?= $filter=='blocked'?'selected':'' ?>>Diblokir</option>
        </select>
        <div class="search-box">
          <i class="bi bi-search"></i>
          <input type="text" id="searchInput" placeholder="Cari apa saja..." value="<?= htmlspecialchars($search) ?>" oninput="debounceSearch()">
        </div>
      </div>
    </div>

    <div style="overflow-x:auto;">
      <form id="bulkForm" method="POST">
      <input type="hidden" name="bulk_action" id="bulkActionInput">
      <table>
        <thead>
          <tr>
            <th class="td-check"><input type="checkbox" id="selectAll" class="custom-check" onclick="toggleSelectAll(this)"></th>
            <th style="width:40px;text-align:center;">No.</th>
            <th>Kode Lisensi</th>
            <th class="sortable" onclick="location.href='<?= sortUrl('client_name') ?>'">
              Data Klien <?= sortIcon('client_name') ?>
            </th>
            <th class="sortable" onclick="location.href='<?= sortUrl('client_address') ?>'">
              Lokasi/Alamat <?= sortIcon('client_address') ?>
            </th>
            <th>Router ID Asli</th>
            <th class="sortable" onclick="location.href='<?= sortUrl('created_at') ?>'">
              Tgl. Didaftarkan <?= sortIcon('created_at') ?>
            </th>
            <th class="sortable" onclick="location.href='<?= sortUrl('expired_at') ?>'">
              Expired <?= sortIcon('expired_at') ?>
            </th>
            <th class="sortable" onclick="location.href='<?= sortUrl('is_active') ?>'">
              Status <?= sortIcon('is_active') ?>
            </th>
            <th style="text-align:right;">Aksi</th>
          </tr>
        </thead>
        <tbody>
          <?php if($result && $result->num_rows > 0): ?>
            <?php $no = 1 + $offset; while($row = $result->fetch_assoc()):
                // Perbandingan string YYYY-MM-DD paling aman & cepat
                $today_str  = date('Y-m-d');
                $expire_str = date('Y-m-d', strtotime($row['expired_at']));
                $is_expired = ($expire_str < $today_str);
                $is_blocked = ($row['is_active'] == 0);
              
              if ($is_blocked) {
                $statusClass = 'badge-blocked';
                $statusText  = 'Diblokir';
              } else if ($is_expired) {
                $statusClass = 'badge-expired';
                $statusText  = 'Masa Aktif Habis';
              } else {
                $statusClass = 'badge-active';
                $statusText  = 'Aktif';
              }

              $isRecent = false;
              if (!empty($row['last_seen'])) {
                $diff = time() - strtotime($row['last_seen']);
                $isRecent = $diff < 300;
              }
            ?>
            <?php
              $rowData = json_encode([
                'id'           => $row['id'],
                'license_code' => $row['license_code'],
                'client_name'  => $row['client_name'] ?? '',
                'client_phone' => $row['client_phone'] ?? '',
                'client_email' => $row['client_email'] ?? '',
                'client_address' => $row['client_address'] ?? '',
                'mikrotik_name'=> $row['mikrotik_name'] ?? '',
                'notes'        => $row['notes'] ?? '',
                'router_id'    => $row['router_id'] ?? '',
                'created_at'   => !empty($row['created_at']) ? date('d M Y', strtotime($row['created_at'])) : '-',
                'last_seen'    => !empty($row['last_seen'])  ? date('d M Y H:i', strtotime($row['last_seen'])) : 'Belum pernah',
                'expired_at'   => date('d M Y', strtotime($row['expired_at'])),
                'exp_raw'      => date('Y-m-d', strtotime($row['expired_at'])),
                'status'       => $statusText,
                'statusClass'  => $statusClass,
                'is_active'    => $row['is_active'],
                'is_expired'   => $is_expired ? 1 : 0,
              ], JSON_HEX_APOS|JSON_HEX_QUOT);
            ?>
            <tr onclick="showDetail(<?= htmlspecialchars($rowData, ENT_QUOTES) ?>)">
               <td class="td-check"><input type="checkbox" name="selected_ids[]" value="<?= $row['id'] ?>" class="custom-check row-check" onclick="event.stopPropagation(); updateBulkBar();"></td>
               <td style="text-align:center;color:var(--muted);font-size:12px;font-weight:700;"><?= $no++ ?></td>
              <td><span class="code-badge"><?= htmlspecialchars($row['license_code']) ?></span></td>
              <td>
                <div class="client-name"><?= htmlspecialchars($row['client_name'] ?? '-') ?></div>
                <?php if(!empty($row['client_phone'])): ?>
                <div class="client-sub"><i class="bi bi-telephone" style="color:#6366f1;"></i><?= htmlspecialchars($row['client_phone']) ?></div>
                <?php endif; ?>
                <?php if(!empty($row['client_email'])): ?>
                <div class="client-sub"><i class="bi bi-envelope" style="color:#6366f1;"></i><?= htmlspecialchars($row['client_email']) ?></div>
                <?php endif; ?>
              </td>
              <td>
                <div style="font-size:12px; font-weight:600; color:var(--text);"><?= htmlspecialchars($row['client_address'] ?: '-') ?></div>
                <div style="font-size:11px; color:var(--muted); margin-top:4px; max-width:200px; overflow:hidden; text-overflow:ellipsis; white-space:nowrap;" title="<?= htmlspecialchars($row['notes']??'') ?>">
                  <i class="bi bi-journal-text"></i> <?= htmlspecialchars($row['notes'] ?: 'Tidak ada catatan') ?>
                </div>
              </td>
              <td>
                <?php if(!empty($row['router_id'])): ?>
                  <span class="router-id"><?= htmlspecialchars($row['router_id']) ?></span>
                <?php else: ?>
                  <span style="color:var(--muted);font-size:12px;">Belum terdaftar</span>
                <?php endif; ?>
              </td>
              <td>
                <?php if(!empty($row['created_at'])): ?>
                  <span style="font-size:12px;font-weight:600;"><?= date('d M Y', strtotime($row['created_at'])) ?></span>
                  <?php if(!empty($row['last_seen'])): ?>
                    <div style="font-size:11px;color:var(--muted);margin-top:3px;">
                      <?php if($isRecent): ?><span class="live-dot"></span><?php endif; ?>
                      Login: <?= date('d M H:i', strtotime($row['last_seen'])) ?>
                    </div>
                  <?php else: ?>
                    <div style="font-size:11px;color:var(--muted);margin-top:3px;">Belum pernah login</div>
                  <?php endif; ?>
                <?php else: ?>
                  <span style="color:var(--muted);font-size:12px;">-</span>
                <?php endif; ?>
              </td>
              <td>
                <span class="exp-date <?= $is_expired ? 'text-danger' : '' ?>" style="font-weight:600;">
                  <?= date('d M Y', strtotime($row['expired_at'])) ?>
                  <?php if($is_expired): ?><br><small style="color:var(--red); font-size:10px; font-weight:700;">(SUDAH EXPIRED)</small><?php endif; ?>
                </span>
              </td>
              <td><span class="status-pill <?= $statusClass ?>"><?= $statusText ?></span></td>
              <td style="text-align:right;">
                <div style="display:flex;gap:6px;justify-content:flex-end;">
                  <a href="?toggle=<?= $row['id'] ?>" class="btn-action <?= $is_blocked?'btn-unblock':'btn-block' ?>" title="<?= $is_blocked?'Buka':'Blokir' ?>">
                    <?= $is_blocked ? '<i class="bi bi-unlock"></i>' : '<i class="bi bi-slash-circle"></i>' ?>
                  </a>
                  <button class="btn-action btn-unblock" onclick="openEditModal(<?= htmlspecialchars($rowData, ENT_QUOTES) ?>)" title="Edit Lisensi">
                    <i class="bi bi-pencil-square"></i>
                  </button>
                  <button class="btn-action btn-delete" onclick="confirmDelete(<?= $row['id'] ?>)" title="Hapus">
                    <i class="bi bi-trash"></i>
                  </button>
                </div>
              </td>
            </tr>
            <?php endwhile; ?>
          <?php else: ?>
            <tr>
              <td colspan="8">
                <div class="empty-state">
                  <i class="bi bi-inbox"></i>
                  <?= $search ? "Tidak ada hasil untuk \"$search\"" : "Belum ada lisensi yang didaftarkan." ?>
                </div>
              </td>
            </tr>
          <?php endif; ?>
        </tbody>
      </table>
      </form>
    </div>
    </div> <!-- End table-card -->

    <!-- BULK ACTION BAR -->
    <div class="bulk-bar" id="bulkBar">
        <div class="bulk-info"><span id="selectedCount">0</span> Terpilih</div>
        <button class="btn-bulk" onclick="submitBulkAction('unblock')"><i class="bi bi-unlock"></i> Buka</button>
        <button class="btn-bulk" onclick="submitBulkAction('block')"><i class="bi bi-slash-circle"></i> Blokir</button>
        <button class="btn-bulk btn-bulk-delete" onclick="submitBulkAction('delete')"><i class="bi bi-trash"></i> Hapus</button>
    </div>

    <!-- PAGINATION CONTROLS -->
    <?php if($totalPages > 1): ?>
    <div class="pagination">
      <a href="<?= pageUrl($page-1) ?>" class="page-link <?= $page<=1?'disabled':'' ?>"><i class="bi bi-chevron-left"></i></a>
      
      <?php for($i=1; $i<=$totalPages; $i++): ?>
        <?php if($i == 1 || $i == $totalPages || ($i >= $page-1 && $i <= $page+1)): ?>
          <a href="<?= pageUrl($i) ?>" class="page-link <?= $i==$page?'active':'' ?>"><?= $i ?></a>
        <?php elseif($i == 2 || $i == $totalPages-1): ?>
          <span style="color:var(--muted);">...</span>
        <?php endif; ?>
      <?php endfor; ?>

      <a href="<?= pageUrl($page+1) ?>" class="page-link <?= $page>=$totalPages?'disabled':'' ?>"><i class="bi bi-chevron-right"></i></a>
    </div>
    <?php endif; ?>

  </div> <!-- End section-main -->

  <!-- SECTION: DOKUMENTASI SISTEM LISENSI DEEP DIVE -->
  <div id="section-help" style="display:none;">
    <div class="topbar">
      <div>
        <h1>Deep Dive: Arsitektur Lisensi</h1>
        <p>Penjelasan menyeluruh mekanisme keamanan, alur, dan struktur kode MKM</p>
      </div>
      <button class="btn-action" onclick="switchSection('main')">
        <i class="bi bi-arrow-left"></i> Kembali ke Dashboard
      </button>
    </div>

    <!-- 1. FILOSOFI & MEGA-TEKNIS ANATOMI -->
    <div style="display:grid; grid-template-columns: 1fr; gap:24px; margin-bottom:24px;">
      <div class="card-glass" style="padding:32px; background:var(--card); border:1px solid var(--border); border-radius:24px;">
        <h3 style="font-size:18px; font-weight:800; margin-bottom:24px; color:var(--accent-light);"><i class="bi bi-shield-lock-fill"></i> 1. Keamanan & Algoritma (Deep Dive)</h3>
        <p style="font-size:13px; color:var(--muted); line-height:1.7; margin-bottom:24px;">Sistem menggunakan <strong>SHA256 Hardware-Binding</strong>. Artinya, lisensi diciptakan dari sidik jari unik hardware Mikrotik yang digabung dengan kunci rahasia aplikasi Anda.</p>
        
        <div style="background:rgba(0,0,0,0.2); border:1px solid var(--border); border-radius:20px; overflow:hidden;">
            <div style="background:rgba(255,255,255,0.03); padding:16px 24px; border-bottom:1px solid var(--border); display:flex; justify-content:space-between; align-items:center;">
                <span style="font-size:12px; font-weight:800; letter-spacing:1px; color:var(--accent-light);">BEDAH ANATOMI KODE (RUMUS 21 KARAKTER)</span>
                <span style="font-size:11px; font-weight:600; color:var(--muted);">Format: MKM-MMHYY-XXXXX-XXXXX</span>
            </div>
            <div style="overflow-x:auto;">
                <table style="width:100%; border-collapse:collapse; font-size:12px; min-width:600px;">
                <thead>
                    <tr style="background:rgba(255,255,255,0.01);">
                        <th style="padding:15px 24px; text-align:left; color:var(--muted); width:80px;">Posisi</th>
                        <th style="padding:15px 24px; text-align:left; color:var(--muted); width:100px;">Karakter</th>
                        <th style="padding:15px 24px; text-align:left; color:var(--muted); width:150px;">Nama Blok</th>
                        <th style="padding:15px 24px; text-align:left; color:var(--muted);">Sumber Data & Logika Sistem</th>
                    </tr>
                </thead>
                <tbody>
                    <tr>
                        <td style="padding:15px 24px; color:var(--muted);">1 - 3</td>
                        <td style="padding:15px 24px;"><code style="color:var(--text); font-weight:800;">MKM</code></td>
                        <td style="padding:15px 24px; font-weight:600; color:var(--yellow);">Prefix</td>
                        <td style="padding:15px 24px; color:var(--muted);">Kode tetap (Fixed) sebagai identitas aplikasi **Mikrotik Monitor**.</td>
                    </tr>
                    <tr style="background:rgba(255,255,255,0.01);">
                        <td style="padding:15px 24px; color:var(--muted);">5 - 6</td>
                        <td style="padding:15px 24px;"><code style="color:var(--text); font-weight:800;">MM</code></td>
                        <td style="padding:15px 24px; font-weight:600; color:var(--yellow);">Bulan</td>
                        <td style="padding:15px 24px; color:var(--muted);">Diambil dari <strong>Bulan Saat Ini</strong> (01-12) saat kode pertama kali dibuat.</td>
                    </tr>
                    <tr>
                        <td style="padding:15px 24px; color:var(--muted);">7</td>
                        <td style="padding:15px 24px;"><code style="color:var(--accent-light); font-weight:800;">H</code></td>
                        <td style="padding:15px 24px; font-weight:600; color:var(--accent-light);">Verify Digit</td>
                        <td style="padding:15px 24px; color:var(--muted);">Hasil dari <code>ord(bin_hash[0]) % 10</code>. Ini adalah **Sidik Jari Pengaman** tambahan berbasis modulo hash.</td>
                    </tr>
                    <tr style="background:rgba(255,255,255,0.01);">
                        <td style="padding:15px 24px; color:var(--muted);">8 - 9</td>
                        <td style="padding:15px 24px;"><code style="color:var(--text); font-weight:800;">YY</code></td>
                        <td style="padding:15px 24px; font-weight:600; color:var(--yellow);">Tahun</td>
                        <td style="padding:15px 24px; color:var(--muted);">Diambil dari 2 digit terakhir **Tahun Saat Ini** (misal 26).</td>
                    </tr>
                    <tr>
                        <td style="padding:15px 24px; color:var(--muted);">11 - 15</td>
                        <td style="padding:15px 24px;"><code style="color:var(--green); font-weight:800;">XXXXX</code></td>
                        <td style="padding:15px 24px; font-weight:600; color:var(--green);">Hash-Alpha</td>
                        <td style="padding:15px 24px; color:var(--muted);">Diambil dari **5 karakter pertama** hasil encoding SHA256 (<code>SoftwareID + Key</code>).</td>
                    </tr>
                    <tr style="background:rgba(255,255,255,0.01);">
                        <td style="padding:15px 24px; color:var(--muted);">17 - 21</td>
                        <td style="padding:15px 24px;"><code style="color:var(--green); font-weight:800;">XXXXX</code></td>
                        <td style="padding:15px 24px; font-weight:600; color:var(--green);">Hash-Beta</td>
                        <td style="padding:15px 24px; color:var(--muted);">Diambil dari **karakter ke 6 sampai 10** hasil encoding SHA256.</td>
                    </tr>
                </tbody>
                </table>
            </div>
        </div>
      </div>
    </div>

    <!-- 2. SIKLUS HIDUP & LOGIKA WAKTU -->
    <div style="display:grid; grid-template-columns: 1.5fr 1fr; gap:24px;">
      <div class="card-glass" style="padding:32px; background:var(--card); border:1px solid var(--border); border-radius:24px;">
        <h3 style="font-size:18px; font-weight:800; margin-bottom:24px; color:var(--green);"><i class="bi bi-clock-fill"></i> 3. Siklus Hidup & Logika Waktu</h3>
        
        <div style="display:flex; flex-direction:column; gap:20px;">
            <div style="display:flex; gap:16px;">
                <div style="width:32px; height:32px; background:var(--green); border-radius:50%; display:flex; align-items:center; justify-content:center; color:#000; font-weight:800; flex-shrink:0;">1</div>
                <div>
                    <h4 style="font-size:14px; margin:0 0 4px; font-weight:700;">Deteksi & Pending (0 Menit)</h4>
                    <p style="font-size:12px; color:var(--muted); margin:0;">Aplikasi Flutter menghitung kode secara lokal. Jika server (API) menolak karena belum terdaftar, entri otomatis masuk ke tabel <code>pending_requests</code>.</p>
                </div>
            </div>
            <div style="display:flex; gap:16px;">
                <div style="width:32px; height:32px; background:var(--green); border-radius:50%; display:flex; align-items:center; justify-content:center; color:#000; font-weight:800; flex-shrink:0;">2</div>
                <div>
                    <h4 style="font-size:14px; margin:0 0 4px; font-weight:700;">Aktivasi Admin</h4>
                    <p style="font-size:12px; color:var(--muted); margin:0;">Admin memetakan <code>LicenseCode</code> ke identitas klien di database. Status berubah menjadi <strong>Aktif</strong>.</p>
                </div>
            </div>
            <div style="display:flex; gap:16px;">
                <div style="width:32px; height:32px; background:var(--red); border-radius:50%; display:flex; align-items:center; justify-content:center; color:#fff; font-weight:800; flex-shrink:0;">3</div>
                <div>
                    <h4 style="font-size:14px; margin:0 0 4px; font-weight:700;">Masa Kadaluarsa (Expired)</h4>
                    <p style="font-size:12px; color:var(--muted); margin:0;">Sistem melakukan pengecekan setiap kali login. Jika <code>expired_at < CURDATE()</code>, server akan mengembalikan feedback <strong>Expired</strong> dan memutus akses aplikasi.</p>
                </div>
            </div>
        </div>
      </div>

      <div style="display:flex; flex-direction:column; gap:24px;">
        <div style="background:var(--card2); border:1px solid var(--border); border-radius:24px; padding:24px;">
          <h4 style="font-size:14px; font-weight:800; color:var(--accent-light); margin-bottom:12px;"><i class="bi bi-hdd-network-fill"></i> Hardware Binding</h4>
          <p style="font-size:12px; color:var(--muted); line-height:1.6;">
            Satu lisensi hanya valid untuk satu <code>Software ID</code>. 
            Jika klien mengganti router Mikrotik-nya, lisensi lama <strong>tidak akan berfungsi</strong> di router baru meskipun kodenya sama. Hal ini karena input dasar Hash (Software ID) telah berubah.
          </p>
        </div>

        <div style="background:hsla(0, 84%, 60%, 0.05); border:1px solid hsla(0, 84%, 60%, 0.1); border-radius:24px; padding:24px;">
          <h4 style="font-size:14px; font-weight:800; color:var(--red); margin-bottom:12px;"><i class="bi bi-exclamation-triangle-fill"></i> Peringatan Krusial</h4>
          <p style="font-size:11px; color:var(--muted); line-height:1.5;">
            Jangan pernah mengubah <code>APP_SECRET_KEY</code> jika sistem sudah berjalan di banyak klien. Mengubah key ini akan menyebabkan <strong>seluruh lisensi aktif menjadi tidak valid</strong> seketika karena hasil Hashing tidak akan cocok lagi.
          </p>
        </div>
      </div>
    </div>
    <!-- 3. TANYA JAWAB (FAQ) & TROUBLESHOOTING -->
    <div style="margin-top:24px; display:grid; grid-template-columns: 1.2fr 1fr; gap:24px;">
      <div class="card-glass" style="padding:32px; background:var(--card); border:1px solid var(--border); border-radius:24px;">
        <h3 style="font-size:18px; font-weight:800; margin-bottom:20px; color:var(--accent-light);"><i class="bi bi-question-circle-fill"></i> Tanya Jawab Umum</h3>
        
        <div style="margin-bottom:16px;">
            <div style="font-weight:700; font-size:13px; color:var(--text);">Q: Berapa lama masa aktif lisensi ini?</div>
            <p style="font-size:12px; color:var(--muted); margin-top:4px;">A: Tergantung pada kolom <code>expired_at</code> yang Anda set. Sistem secara otomatis memutus akses pada pukul 00:01 hari berikutnya setelah tanggal expired tercapai.</p>
        </div>
        <div style="margin-bottom:16px;">
            <div style="font-weight:700; font-size:13px; color:var(--text);">Q: Bagaimana jika klien ganti Handphone?</div>
            <p style="font-size:12px; color:var(--muted); margin-top:4px;">A: Ganti HP tidak masalah selama <strong>Router Mikrotik-nya tetap sama</strong>. Lisensi terikat pada Router, bukan pada perangkat Android/iOS.</p>
        </div>
        <div>
            <div style="font-weight:700; font-size:13px; color:var(--text);">Q: Bisakah satu lisensi dipakai di dua Router?</div>
            <p style="font-size:12px; color:var(--muted); margin-top:4px;">A: Tidak bisa. Karena Software ID masing-masing router berbeda, maka hasil Hashing SHA256 akan selalu berbeda.</p>
        </div>
      </div>

      <div class="card-glass" style="padding:32px; background:var(--card); border:1px solid var(--border); border-radius:24px;">
        <h3 style="font-size:18px; font-weight:800; margin-bottom:20px; color:var(--accent-light);"><i class="bi bi-tools"></i> Troubleshooting</h3>
        
        <div style="background:rgba(255,255,255,0.02); padding:16px; border-radius:14px; margin-bottom:12px;">
            <div style="font-size:12px; font-weight:700; color:var(--red);">Masalah: Lisensi "Tersedia" tapi App bilang "Tidak Valid"</div>
            <p style="font-size:11px; color:var(--muted); margin-top:4px;">Kemungkinan besar <code>Secret Key</code> di App Flutter berbeda dengan di Backend. Pastikan keduanya menggunakan <code>MKM_LICENSE_KEY_2026</code>.</p>
        </div>
        <div style="background:rgba(255,255,255,0.02); padding:16px; border-radius:14px;">
            <div style="font-size:12px; font-weight:700; color:var(--yellow);">Masalah: Waktu Expired Tidak Akurat</div>
            <p style="font-size:11px; color:var(--muted); margin-top:4px;">Pastikan Timezone di <code>config.php</code> sudah <code>Asia/Jakarta</code> agar perhitungan hari sesuai dengan waktu Indonesia.</p>
        </div>
      </div>
    </div>
  </div> <!-- End section-help -->

</div> <!-- End Main Content Wrapper -->

<!-- MODAL DETAIL -->
<div class="modal-overlay" id="detailModal">
  <div class="modal-box" style="max-width:480px;">
    <div class="modal-header">
      <h3><i class="bi bi-person-badge" style="color:var(--accent);margin-right:8px;"></i>Detail Lisensi</h3>
      <button class="modal-close" onclick="document.getElementById('detailModal').classList.remove('show')">&times;</button>
    </div>
    <div class="detail-grid">
      <div class="detail-item" style="grid-column:1/-1;">
        <label>Kode Lisensi</label>
        <div class="val"><span class="code-badge" id="d_code" style="font-size:14px;"></span></div>
      </div>
      <div class="detail-item">
        <label>Nama Klien</label>
        <div class="val" id="d_name"></div>
      </div>
      <div class="detail-item">
        <label>Status</label>
        <div class="val"><span class="status-pill" id="d_status"></span></div>
      </div>
      <div class="detail-item">
        <label>Nomor WhatsApp</label>
        <div class="val" id="d_phone"></div>
      </div>
      <div class="detail-item">
        <label>Email</label>
        <div class="val" id="d_email"></div>
      </div>
      <div class="detail-item" style="grid-column:1/-1;">
        <label>Alamat Klien</label>
        <div class="val" id="d_address"></div>
      </div>
      <div class="detail-item">
        <label>Nama Router/Alat</label>
        <div class="val" id="d_router"></div>
      </div>
      <div class="detail-item">
        <label>Router ID Asli</label>
        <div class="val"><code id="d_rid" style="font-size:12px;"></code></div>
      </div>
      <div class="detail-item" style="grid-column:1/-1;">
        <label>Catatan Internal</label>
        <div class="val" id="d_notes" style="background:rgba(255,255,255,0.03);padding:8px;border-radius:6px;font-style:italic;"></div>
      </div>
      <div class="detail-item">
        <label>Tgl. Didaftarkan</label>
        <div class="val" id="d_created"></div>
      </div>
      <div class="detail-item">
        <label>Login Terakhir</label>
        <div class="val" id="d_seen"></div>
      </div>
      <div class="detail-item">
        <label>Expired</label>
        <div class="val" id="d_exp"></div>
      </div>
    </div>
    <div class="detail-footer" style="display:flex;gap:10px;margin-top:20px;padding-top:20px;border-top:1px solid var(--border);">
      <button class="btn-primary-modal" id="btnEditFromDetail" onclick="openEditFromDetail()" style="flex:1;">
        <i class="bi bi-pencil-square"></i> Edit Data
      </button>
      <button class="btn-action btn-block" style="flex:1; justify-content:center; padding:12px;" id="btnBlockFromDetail">
        <i class="bi bi-slash-circle"></i> Blokir
      </button>
      <button class="btn-action btn-delete" style="flex:1; justify-content:center; padding:12px;" id="btnDeleteFromDetail">
        <i class="bi bi-trash"></i> Hapus
      </button>
    </div>
  </div>
</div>

<!-- MODAL EDIT -->
<div class="modal-overlay" id="editModal">
  <div class="modal-box">
    <div class="modal-header">
      <h3><i class="bi bi-pencil-square" style="color:var(--accent);margin-right:8px;"></i>Edit Lisensi Klien</h3>
      <button class="modal-close" onclick="document.getElementById('editModal').classList.remove('show')">&times;</button>
    </div>
    <form method="POST">
      <input type="hidden" name="id" id="edit_id">
      
      <label class="form-label">Kode Lisensi</label>
      <input type="text" name="license_code" id="edit_code" class="form-ctrl" required>

      <label class="form-label">Nama Lengkap Klien</label>
      <input type="text" name="client_name" id="edit_name" class="form-ctrl" required>

      <div class="form-row">
        <div>
          <label class="form-label">Nomor WhatsApp</label>
          <input type="text" name="client_phone" id="edit_phone" class="form-ctrl">
        </div>
        <div>
          <label class="form-label">Email Klien</label>
          <input type="email" name="client_email" id="edit_email" class="form-ctrl">
        </div>
      </div>

      <label class="form-label">Alamat Klien</label>
      <textarea name="client_address" id="edit_address" class="form-ctrl" rows="2"></textarea>

      <div class="form-row">
        <div>
          <label class="form-label">Nama Router / Alat</label>
          <input type="text" name="mikrotik_name" id="edit_router" class="form-ctrl" required>
        </div>
        <div>
          <label class="form-label">Expired Date</label>
          <input type="date" name="expired_at" id="edit_exp" class="form-ctrl" required>
        </div>
      </div>

      <label class="form-label">Catatan Internal / Router ID</label>
      <textarea name="notes" id="edit_notes" class="form-ctrl" rows="2"></textarea>

      <div class="toggle-row">
        <span>Status Aktif</span>
        <label class="toggle-input">
          <input type="checkbox" name="is_active" id="edit_active" value="1">
          <span class="toggle-slider"></span>
        </label>
      </div>

      <button type="submit" name="edit_license" class="btn-primary-modal">
        <i class="bi bi-check2-circle"></i> Simpan Perubahan
      </button>
      <button type="button" class="btn-cancel" onclick="document.getElementById('editModal').classList.remove('show')">Batal</button>
    </form>
  </div>
</div>

<!-- MODAL TAMBAH -->
<div class="modal-overlay" id="addModal">
  <div class="modal-box">
    <div class="modal-header">
      <h3><i class="bi bi-plus-circle" style="color:var(--accent);margin-right:8px;"></i>Tambah Lisensi Klien</h3>
      <button class="modal-close" onclick="document.getElementById('addModal').classList.remove('show')">&times;</button>
    </div>
    <div class="method-toggle">
      <button type="button" class="method-btn active" onclick="switchMethod('manual')">Mode Manual</button>
      <button type="button" class="method-btn" onclick="switchMethod('auto')">Generate Otomatis</button>
    </div>

    <form method="POST">
      <!-- MODE MANUAL -->
      <div id="method_manual" class="method-content active">
        <label class="form-label">Kode dari Aplikasi (Kiriman Klien)</label>
        <input type="text" name="license_code" id="input_license_manual" class="form-ctrl" placeholder="MKM-XXXXX-XXXXX-XXXXX">
      </div>

      <!-- MODE OTOMATIS -->
      <div id="method_auto" class="method-content">
        <label class="form-label">Masukkan Router ID / Software ID</label>
        <div style="display:flex;gap:8px;margin-bottom:16px;">
          <input type="text" id="input_router_id_gen" class="form-ctrl" placeholder="Contoh: HHJH-UFWL" style="margin-bottom:0;flex:1;">
          <button type="button" class="btn-action btn-unblock" onclick="generateFromId()" style="padding:0 15px;">
            <i class="bi bi-magic"></i> Generate
          </button>
        </div>
        <label class="form-label">Hasil Kode Generate</label>
        <input type="text" name="license_code_auto" id="input_license_auto" class="form-ctrl" readonly style="background:rgba(255,255,255,0.03);cursor:default;">
      </div>

      <!-- HIDDEN FIELD UNTUK FINAL CODE -->
      <input type="hidden" name="final_license_code" id="final_license_code">

      <label class="form-label">Nama Lengkap Klien</label>
      <input type="text" name="client_name" class="form-ctrl" placeholder="Budi Santoso" required>

      <div class="form-row">
        <div>
          <label class="form-label">Nomor WhatsApp</label>
          <input type="text" name="client_phone" class="form-ctrl" placeholder="0812...">
        </div>
        <div>
          <label class="form-label">Email Klien</label>
          <input type="email" name="client_email" class="form-ctrl" placeholder="budi@email.com">
        </div>
      </div>

      <label class="form-label">Alamat Klien</label>
      <textarea name="client_address" class="form-ctrl" placeholder="Jl. Merdeka No. 123..." rows="2"></textarea>

      <div class="form-row">
        <div>
          <label class="form-label">Nama Router / Alat</label>
          <input type="text" name="mikrotik_name" id="input_mikrotik_name" class="form-ctrl" placeholder="Router Utama" required>
        </div>
        <div>
          <label class="form-label">Expired Date</label>
          <input type="date" name="expired_at" class="form-ctrl" value="<?= date('Y-m-d', strtotime('+6 months')) ?>" required>
        </div>
      </div>

      <label class="form-label">Catatan Internal / Router ID</label>
      <textarea name="notes" id="input_notes" class="form-ctrl" placeholder="Lokasi pemasangan, Router ID: XXXX, dll..." rows="2"></textarea>

      <div class="toggle-row">
        <span>Langsung Aktifkan Sekarang</span>
        <label class="toggle-input">
          <input type="checkbox" name="is_active" value="1" checked>
          <span class="toggle-slider"></span>
        </label>
      </div>

      <button type="submit" name="add_license" class="btn-primary-modal">
        <i class="bi bi-save2"></i> Simpan Lisensi
      </button>
      <button type="button" class="btn-cancel" onclick="document.getElementById('addModal').classList.remove('show')">Batal</button>
    </form>
  </div>
</div>

<!-- MODAL INSPECTOR (REVERSE LOOKUP) -->
<div id="inspectModal" class="modal-overlay">
  <div class="modal-box" style="max-width: 480px;">
    <div class="modal-header">
      <div style="display:flex; align-items:center; gap:12px;">
        <i class="bi bi-shield-check" style="font-size:24px; color:var(--accent);"></i>
        <h3>License Inspector</h3>
      </div>
      <button class="modal-close" onclick="document.getElementById('inspectModal').classList.remove('show')"><i class="bi bi-x"></i></button>
    </div>
    
    <p style="font-size:13px; color:var(--muted); margin-bottom:20px;">Deteksi data pemilik asli berdasarkan kode lisensi.</p>

    <div class="search-box" style="width:100%; margin-bottom:24px;">
      <i class="bi bi-upc-scan"></i>
      <input type="text" id="inspectInput" placeholder="Tempel kode MKM-XXXX di sini..." style="width:100%;" oninput="doInspect()">
    </div>

    <div id="inspectEmpty" style="display:none; text-align:center; padding:20px; color:var(--muted); font-size:13px;">
      <i class="bi bi-exclamation-circle" style="display:block; font-size:24px; margin-bottom:8px;"></i>
      Kode lisensi tidak ditemukan di database.
    </div>

    <!-- ID CARD RESULT -->
    <div id="inspectResult" class="inspect-card">
      <div class="scan-line" id="scanLine"></div>
      
      <div style="display:flex; justify-content:space-between; align-items:flex-start; margin-bottom:20px;">
        <div>
          <span style="font-size:10px; font-weight:800; color:var(--muted); text-transform:uppercase; letter-spacing:1px;">Pemilik Lisensi</span>
          <h4 id="ins_name" style="margin:4px 0 0; font-size:18px; font-weight:800; color:var(--accent-light);">Loading...</h4>
        </div>
        <div id="ins_status" class="status-pill badge-active">AKTIF</div>
      </div>

      <div style="display:grid; grid-template-columns: 1fr 1fr; gap:16px;">
        <div>
          <span style="font-size:10px; font-weight:800; color:var(--muted); text-transform:uppercase; letter-spacing:1px;">Router ID</span>
          <div id="ins_rid" style="font-family:monospace; font-weight:700; color:var(--text); margin-top:4px;">-</div>
        </div>
        <div>
          <span style="font-size:10px; font-weight:800; color:var(--muted); text-transform:uppercase; letter-spacing:1px;">Lokasi</span>
          <div id="ins_address" style="font-size:12px; color:var(--text); margin-top:4px;">-</div>
        </div>
      </div>

      <div style="margin-top:20px; padding-top:16px; border-top:1px dashed var(--border); display:flex; align-items:center; gap:8px; color:var(--green); font-size:11px; font-weight:700;">
        <i class="bi bi-patch-check-fill"></i> TERVERIFIKASI OLEH SISTEM
      </div>
    </div>
  </div>
</div>

<!-- TOAST -->
<div class="toast-wrap" id="toastWrap"></div>

<!-- Hidden delete form -->
<form id="deleteForm" method="GET" style="display:none;">
  <input type="hidden" name="delete" id="deleteId">
</form>

<script>
  // === SIDEBAR NAV ===
  function switchSection(id) {
    document.getElementById('section-main').style.display = (id === 'main') ? 'block' : 'none';
    document.getElementById('section-help').style.display = (id === 'help') ? 'block' : 'none';
    document.getElementById('nav-main').classList.toggle('active', id === 'main');
    document.getElementById('nav-help').classList.toggle('active', id === 'help');
    closeSidebar();
  }

  // === DETAIL MODAL ===
  function showDetail(data) {
    const modal = document.getElementById('detailModal');
    if (!modal) return;
    
    modal.dataset.activeData = JSON.stringify(data);
    document.getElementById('d_code').textContent    = data.license_code;
    document.getElementById('d_name').textContent    = data.client_name  || '-';
    document.getElementById('d_phone').textContent   = data.client_phone || '-';
    document.getElementById('d_email').textContent   = data.client_email || '-';
    document.getElementById('d_address').textContent = data.client_address || '-';
    document.getElementById('d_router').textContent  = data.mikrotik_name || '-';
    document.getElementById('d_rid').textContent     = data.router_id    || '-';
    document.getElementById('d_notes').textContent   = data.notes        || '-';
    document.getElementById('d_created').textContent = data.created_at;
    document.getElementById('d_seen').textContent    = data.last_seen;
    document.getElementById('d_exp').textContent     = data.expired_at;
    const sp = document.getElementById('d_status');
    sp.textContent = data.status;
    sp.className = 'status-pill ' + data.statusClass;
    
    // Block Toggle Button in Detail
    const bl = document.getElementById('btnBlockFromDetail');
    bl.onclick = (e) => { e.stopPropagation(); location.href = '?toggle=' + data.id; };
    bl.className = 'btn-action ' + (data.is_active == 1 ? 'btn-block' : 'btn-unblock');
    bl.innerHTML = data.is_active == 1 ? '<i class="bi bi-slash-circle"></i> Blokir' : '<i class="bi bi-unlock"></i> Buka';
    bl.style.justifyContent = "center"; bl.style.padding = "12px"; bl.style.flex = "1";

    // Delete Button in Detail
    const dl = document.getElementById('btnDeleteFromDetail');
    dl.onclick = (e) => { e.stopPropagation(); confirmDelete(data.id); };
    dl.style.justifyContent = "center"; dl.style.padding = "12px"; dl.style.flex = "1";

    document.getElementById('detailModal').classList.add('show');
  }

  // === EDIT MODAL ===
  function openEditModal(data) {
    document.getElementById('edit_id').value      = data.id;
    document.getElementById('edit_code').value    = data.license_code;
    document.getElementById('edit_name').value    = data.client_name;
    document.getElementById('edit_phone').value   = data.client_phone;
    document.getElementById('edit_email').value   = data.client_email;
    document.getElementById('edit_address').value = data.client_address;
    document.getElementById('edit_router').value  = data.mikrotik_name;
    document.getElementById('edit_notes').value   = data.notes;
    // Format tanggal untuk input date (YYYY-MM-DD)
    const rawExp = data.expired_at; // Berformat "d M Y" dari database PHP formatting? 
    // Wait, rowData PHP formatting: 'expired_at' => date('d M Y', strtotime($row['expired_at']))
    // Kita butuh YYYY-MM-DD. Mari kita ubah rowData di PHP ke Y-m-d.
    document.getElementById('edit_exp').value     = data.exp_raw; 
    document.getElementById('edit_active').checked = (data.is_active == 1);
    document.getElementById('editModal').classList.add('show');
  }

  // === SWITCH METHOD ===
  let currentMethod = 'manual';
  function switchMethod(method) {
    currentMethod = method;
    document.querySelectorAll('.method-btn').forEach(b => b.classList.remove('active'));
    document.querySelectorAll('.method-content').forEach(c => c.classList.remove('active'));
    
    event.target.classList.add('active');
    document.getElementById('method_' + method).classList.add('active');
    syncFinalCode();
  }

  function syncFinalCode() {
    const manual = document.getElementById('input_license_manual').value;
    const auto   = document.getElementById('input_license_auto').value;
    document.getElementById('final_license_code').value = (currentMethod === 'manual') ? manual : auto;
  }

  document.getElementById('input_license_manual').addEventListener('input', syncFinalCode);

  // === PRE-FILL FORM DARI PENDING ===
  function prefillForm(licenseCode, routerId) {
    switchMethod('manual');
    document.getElementById('input_license_manual').value = licenseCode;
    document.getElementById('input_router_id_gen').value = routerId || '';
    document.getElementById('input_mikrotik_name').value = ''; 
    document.getElementById('input_notes').value = 'Router ID: ' + (routerId || '');
    document.getElementById('addModal').classList.add('show');
    syncFinalCode();
    setTimeout(() => document.querySelector('[name="client_name"]').focus(), 200);
  }

  // === GENERATE DARI ID ===
  function generateFromId() {
    const rid = document.getElementById('input_router_id_gen').value;
    if (!rid) { alert("Masukkan Router ID Terlebih Dahulu"); return; }
    
    const btn = event.target;
    const oldHtml = btn.innerHTML;
    btn.innerHTML = '<i class="bi bi-hourglass-split"></i>...';
    btn.disabled = true;

    fetch('?ajax_gen=1&rid=' + encodeURIComponent(rid))
      .then(r => r.json())
      .then(data => {
        if (data.code) {
          document.getElementById('input_license_auto').value = data.code;
          syncFinalCode();
        }
      })
      .finally(() => {
        btn.innerHTML = oldHtml;
        btn.disabled = false;
      });
  }

  // Cegah klik tombol di baris membuka detail modal
  document.querySelectorAll('.btn-action, .btn-delete').forEach(btn => {
    btn.addEventListener('click', e => e.stopPropagation());
  });

  // === MOBILE SIDEBAR ===
  function openSidebar() {
    document.querySelector('.sidebar').classList.add('mobile-open');
    document.getElementById('sidebarOverlay').classList.add('show');
  }
  function closeSidebar() {
    document.querySelector('.sidebar').classList.remove('mobile-open');
    document.getElementById('sidebarOverlay').classList.remove('show');
  }

  // === TOAST ===
  <?php if(isset($_GET['msg'])): ?>
  window.addEventListener('load', () => {
    const msgs = {
      added: ['Lisensi berhasil ditambahkan!', 'bi-check-circle-fill'],
      deleted: ['Lisensi berhasil dihapus.', 'bi-trash-fill'],
      updated: ['Status lisensi diperbarui!', 'bi-arrow-repeat'],
    };
    const m = msgs['<?= $_GET['msg'] ?>'] || ['Tindakan berhasil!', 'bi-check'];
    const div = document.createElement('div');
    div.className = 'toast-item success';
    div.innerHTML = `<i class="bi ${m[1]}" style="color:var(--green);"></i> ${m[0]}`;
    document.getElementById('toastWrap').appendChild(div);
    setTimeout(() => div.remove(), 4000);
  });
  <?php endif; ?>

  // === DELETE ===
  function confirmDelete(id) {
    if (confirm('Yakin ingin menghapus lisensi ini secara permanen?')) {
      document.getElementById('deleteId').value = id;
      document.getElementById('deleteForm').submit();
    }
  }

  // Tutup modal klik luar
  ['addModal','detailModal'].forEach(id => {
    document.getElementById(id).addEventListener('click', function(e) {
      if (e.target === this) this.classList.remove('show');
    });
  });
  // === ADVANCED FILTERS & SEARCH ===
  let searchTimeout = null;
  function copyToClipboard(text) {
    navigator.clipboard.writeText(text).then(() => {
      alert("Secret Key berhasil disalin ke clipboard!");
    });
  }

  // === INSPECTOR LOGIC ===
  let inspectTimer;
  function doInspect() {
    clearTimeout(inspectTimer);
    const code = document.getElementById('inspectInput').value.trim();
    const resDiv = document.getElementById('inspectResult');
    const empDiv = document.getElementById('inspectEmpty');
    const scanLine = document.getElementById('scanLine');

    if (code.length < 5) {
        resDiv.style.display = 'none';
        empDiv.style.display = 'none';
        return;
    }

    inspectTimer = setTimeout(() => {
        // Show scanning effect first
        resDiv.style.display = 'block';
        empDiv.style.display = 'none';
        scanLine.style.display = 'block';
        document.getElementById('ins_name').innerText = 'Scanning...';
        document.getElementById('ins_rid').innerText = '...';
        document.getElementById('ins_address').innerText = '...';

        fetch('?ajax_inspect=1&code=' + encodeURIComponent(code))
            .then(r => r.json())
            .then(res => {
                // Simulate processing delay for "Wow" effect
                setTimeout(() => {
                    scanLine.style.display = 'none';
                    if (res.success) {
                        const d = res.data;
                        document.getElementById('ins_name').innerText = d.client_name || '-';
                        document.getElementById('ins_rid').innerText  = d.router_id || '-';
                        document.getElementById('ins_address').innerText = d.client_address || '-';
                        const st = document.getElementById('ins_status');
                        st.innerText = d.status_text;
                        st.className = 'status-pill ' + d.status_class;
                    } else {
                        resDiv.style.display = 'none';
                        empDiv.style.display = 'block';
                    }
                }, 1200);
            });
    }, 400);
  }

  function debounceSearch() {
    clearTimeout(searchTimeout);
    searchTimeout = setTimeout(() => {
      applyFilters();
    }, 600);
  }

  function applyFilters() {
    const q = document.getElementById('searchInput').value;
    const s = document.getElementById('filterStatus').value;
    const url = new URL(window.location.href);
    url.searchParams.set('q', q);
    url.searchParams.set('status', s);
    url.searchParams.set('page', 1); // Reset ke hal 1 saat filter berubah
    window.location.href = url.toString();
  }

  // === BULK ACTIONS ===
  function toggleSelectAll(source) {
    const checkboxes = document.querySelectorAll('.row-check');
    checkboxes.forEach(cb => cb.checked = source.checked);
    updateBulkBar();
  }

  function updateBulkBar() {
    const checked = document.querySelectorAll('.row-check:checked');
    const bar = document.getElementById('bulkBar');
    const count = document.getElementById('selectedCount');
    
    if (checked.length > 0) {
      count.innerText = checked.length;
      bar.classList.add('show');
    } else {
      bar.classList.remove('show');
    }
  }

  function submitBulkAction(action) {
    const msg = action === 'delete' ? "Hapus semua lisensi terpilih?" : 
                (action === 'block' ? "Blokir semua lisensi terpilih?" : "Buka blokir semua lisensi terpilih?");
                
    if (confirm(msg)) {
      document.getElementById('bulkActionInput').value = action;
      document.getElementById('bulkForm').submit();
    }
  }

  function openEditFromDetail() {
    const data = JSON.parse(document.getElementById('detailModal').dataset.activeData);
    document.getElementById('editModal').classList.remove('show');
    openEditModal(data);
  }
</script>
</body>
</html>
