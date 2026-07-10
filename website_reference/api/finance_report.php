<?php
/**
 * Finance Report API
 * Menyediakan data untuk modul laporan keuangan lengkap
 *
 * Actions:
 *   profile_revenue   → revenue per paket/profile bulan ini atau range tertentu
 *   recent_payments   → transaksi pembayaran terbaru
 *   receivable        → daftar piutang (belum bayar) + hitung bulan nunggak
 *   annual_report     → laporan per bulan dalam 1 tahun
 *   monthly_kpi       → KPI bulan ini vs bulan lalu
 */

header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit(); }

require_once __DIR__ . '/config.php';
require_once __DIR__ . '/auth/require_auth.php';

$action    = trim($_GET['action'] ?? '');
$router_id = trim($_GET['router_id'] ?? '');
$year      = intval($_GET['year'] ?? date('Y'));
$month     = max(1, min(12, intval($_GET['month'] ?? date('n'))));
$limit     = max(5, intval($_GET['limit'] ?? 10));

if (empty($router_id)) {
    echo json_encode(['success' => false, 'message' => 'Parameter router_id wajib']);
    exit;
}

// Frontend kadang mengirim id numeric router. Normalisasi ke software_id karena tabel users/payments memakai software_id.
$stmtRouter = $conn->prepare("SELECT software_id FROM mikrotik_routers WHERE software_id = ? OR id = ? LIMIT 1");
$stmtRouter->bind_param('ss', $router_id, $router_id);
$stmtRouter->execute();
if ($routerRow = $stmtRouter->get_result()->fetch_assoc()) {
    if (!empty($routerRow['software_id'])) {
        $router_id = $routerRow['software_id'];
    }
}
$stmtRouter->close();

try {
    switch ($action) {

        // ── KPI Bulan Ini vs Bulan Lalu ──────────────────────────────────────
        case 'monthly_kpi':
            // Hitung bulan lalu
            $prevMonth = $month === 1 ? 12 : $month - 1;
            $prevYear  = $month === 1 ? $year - 1 : $year;

            $getMonthData = function ($m, $y) use ($conn, $router_id) {
                $stmt = $conn->prepare("
                    SELECT
                        COUNT(DISTINCT u.id) as total_customers,
                        SUM(CASE WHEN p.id IS NOT NULL AND p.method != 'titipan' THEN 1 ELSE 0 END) as paid_count,
                        SUM(IF(p.id IS NULL AND (inv.status IS NULL OR inv.status != 'isolir'), 1, 0)) as unpaid_count,
                        IFNULL(SUM(CASE WHEN p.method != 'titipan' THEN p.amount ELSE 0 END), 0) as revenue,
                        IFNULL(SUM(CASE WHEN p.id IS NULL AND (inv.status IS NULL OR inv.status != 'isolir') THEN IFNULL(inv.amount, IFNULL(pr.price, 0)) ELSE 0 END), 0) as receivable
                    FROM users u
                    LEFT JOIN invoices inv ON inv.user_id = u.id AND inv.month = ? AND inv.year = ? AND inv.router_id = u.router_id
                    LEFT JOIN payments p ON p.user_id = u.id AND p.payment_month = ? AND p.payment_year = ? AND p.router_id = u.router_id
                    LEFT JOIN ppp_profile_pricing pr ON pr.profile_name = u.profile AND pr.router_id = u.router_id
                    WHERE u.router_id = ?
                ");
                $stmt->bind_param("iiiis", $m, $y, $m, $y, $router_id);
                $stmt->execute();
                $row = $stmt->get_result()->fetch_assoc();
                $stmt->close();
                
                // Get expense
                $stmtExp = $conn->prepare("SELECT IFNULL(SUM(amount), 0) as expense FROM expenses WHERE router_id = ? AND MONTH(spent_at) = ? AND YEAR(spent_at) = ?");
                $stmtExp->bind_param("sii", $router_id, $m, $y);
                $stmtExp->execute();
                $expRow = $stmtExp->get_result()->fetch_assoc();
                $stmtExp->close();
                
                $row['expense'] = $expRow['expense'];
                $row['net_profit'] = floatval($row['revenue']) - floatval($row['expense']);
                
                return $row;
            };

            $current  = $getMonthData($month, $year);
            $previous = $getMonthData($prevMonth, $prevYear);

            echo json_encode([
                'success' => true,
                'current' => $current,
                'previous' => $previous,
                'month' => $month,
                'year' => $year,
            ], JSON_UNESCAPED_UNICODE);
            break;

        // ── Revenue Per Profile/Paket ─────────────────────────────────────────
        case 'profile_revenue':
            $stmt = $conn->prepare("
                SELECT
                    u.profile,
                    COUNT(DISTINCT u.id) as total_users,
                    SUM(CASE WHEN p.id IS NOT NULL AND p.method != 'titipan' THEN 1 ELSE 0 END) as paid_count,
                    IFNULL(SUM(CASE WHEN p.method != 'titipan' THEN p.amount ELSE 0 END), 0) as revenue,
                    IFNULL(MAX(pr.price), 0) as price_per_user
                FROM users u
                LEFT JOIN payments p ON p.user_id = u.id AND p.payment_month = ? AND p.payment_year = ? AND p.router_id = u.router_id
                LEFT JOIN ppp_profile_pricing pr ON pr.profile_name = u.profile AND pr.router_id = u.router_id
                WHERE u.router_id = ? AND u.profile IS NOT NULL AND u.profile != ''
                GROUP BY u.profile
                ORDER BY revenue DESC
            ");
            $stmt->bind_param("iis", $month, $year, $router_id);
            $stmt->execute();
            $result = $stmt->get_result();
            $data = [];
            while ($row = $result->fetch_assoc()) $data[] = $row;
            $stmt->close();

            echo json_encode(['success' => true, 'data' => $data], JSON_UNESCAPED_UNICODE);
            break;

        // ── Revenue & Piutang Per ODP ─────────────────────────────────────────
        case 'odp_revenue':
            $stmt = $conn->prepare("
                SELECT
                    IFNULL(o.name, 'Tanpa ODP') as odp_name,
                    COUNT(DISTINCT u.id) as total_users,
                    SUM(CASE WHEN p.id IS NOT NULL AND p.method != 'titipan' THEN 1 ELSE 0 END) as paid_count,
                    IFNULL(SUM(CASE WHEN p.method != 'titipan' THEN p.amount ELSE 0 END), 0) as revenue,
                    IFNULL(SUM(CASE WHEN p.id IS NULL AND (inv.status IS NULL OR inv.status != 'isolir') THEN IFNULL(inv.amount, IFNULL(pr.price, 0)) ELSE 0 END), 0) as receivable
                FROM users u
                LEFT JOIN odp o ON u.odp_id = o.id
                LEFT JOIN invoices inv ON inv.user_id = u.id AND inv.month = ? AND inv.year = ? AND inv.router_id = u.router_id
                LEFT JOIN payments p ON p.user_id = u.id AND p.payment_month = ? AND p.payment_year = ? AND p.router_id = u.router_id
                LEFT JOIN ppp_profile_pricing pr ON pr.profile_name = u.profile AND pr.router_id = u.router_id
                WHERE u.router_id = ?
                GROUP BY u.odp_id
                ORDER BY revenue DESC, receivable DESC
            ");
            $stmt->bind_param("iiiis", $month, $year, $month, $year, $router_id);
            $stmt->execute();
            $result = $stmt->get_result();
            $data = [];
            while ($row = $result->fetch_assoc()) $data[] = $row;
            $stmt->close();

            echo json_encode(['success' => true, 'data' => $data], JSON_UNESCAPED_UNICODE);
            break;

        // ── Transaksi Terbaru ─────────────────────────────────────────────────
        case 'recent_payments':
            $stmt = $conn->prepare("
                SELECT p.id, p.amount, p.payment_date, p.method, p.note,
                       p.payment_month, p.payment_year,
                       u.username, u.alamat, u.profile
                FROM payments p
                JOIN users u ON u.id = p.user_id
                WHERE p.router_id = ?
                ORDER BY p.payment_date DESC, p.id DESC
                LIMIT ?
            ");
            $stmt->bind_param("si", $router_id, $limit);
            $stmt->execute();
            $result = $stmt->get_result();
            $data = [];
            while ($row = $result->fetch_assoc()) $data[] = $row;
            $stmt->close();

            echo json_encode(['success' => true, 'data' => $data], JSON_UNESCAPED_UNICODE);
            break;

        // ── Riwayat Keuangan Terbaru ──────────────────────────────────────────
        case 'recent_activities':
            $searchRouter = "%[R:{$router_id}]%";
            $stmt = $conn->prepare("
                SELECT al.id, al.action, al.description, al.created_at, a.username as admin_name
                FROM admin_activity_logs al
                LEFT JOIN admin_users a ON al.user_id = a.id
                WHERE (al.action LIKE '%payment%' OR al.action LIKE '%invoice%') 
                  AND al.description LIKE ?
                ORDER BY al.id DESC
                LIMIT ?
            ");
            $stmt->bind_param("si", $searchRouter, $limit);
            $stmt->execute();
            $result = $stmt->get_result();
            $data = [];
            while ($row = $result->fetch_assoc()) $data[] = $row;
            $stmt->close();

            echo json_encode(['success' => true, 'data' => $data], JSON_UNESCAPED_UNICODE);
            break;

        // ── Daftar Piutang (Belum Bayar) ─────────────────────────────────────
        case 'receivable':
            $page    = max(1, intval($_GET['page'] ?? 1));
            $perPage = max(5, intval($_GET['per_page'] ?? 20));
            $offset  = ($page - 1) * $perPage;
            $search  = trim($_GET['search'] ?? '');
            $profile = trim($_GET['profile'] ?? '');

            $where  = ["u.router_id = ?", "p.id IS NULL", "(inv.status IS NULL OR inv.status != 'isolir')"];
            $params = [$router_id];
            $types  = "s";

            if ($search !== '') {
                $where[] = "(u.username LIKE ? OR u.alamat LIKE ?)";
                $like = "%$search%";
                $params = array_merge($params, [$like, $like]);
                $types .= "ss";
            }
            if ($profile !== '') {
                $where[] = "u.profile = ?";
                $params[] = $profile;
                $types .= "s";
            }

            $whereSQL = "WHERE " . implode(" AND ", $where);

            // Total
            $cntSQL = "SELECT COUNT(*) as total,
                              IFNULL(SUM(IFNULL(inv.amount, IFNULL(pr.price, 0))), 0) as total_receivable
                       FROM users u
                       LEFT JOIN invoices inv ON inv.user_id = u.id AND inv.month = ? AND inv.year = ?
                       LEFT JOIN payments p ON p.user_id = u.id AND p.payment_month = ? AND p.payment_year = ? AND p.router_id = u.router_id
                       LEFT JOIN ppp_profile_pricing pr ON pr.profile_name = u.profile AND pr.router_id = u.router_id
                       $whereSQL";
            $allParams = array_merge([$month, $year, $month, $year], $params);
            $allTypes  = "iiii" . $types;
            $cntStmt   = $conn->prepare($cntSQL);
            if (!$cntStmt) {
                throw new Exception('prepare() failed: ' . $conn->error);
            }
            $cntStmt->bind_param($allTypes, ...$allParams);
            $cntStmt->execute();
            $cnt = $cntStmt->get_result()->fetch_assoc();
            $cntStmt->close();

            // Data
            $dataSQL = "SELECT u.id, u.username, u.alamat, u.profile, u.tanggal_tagihan,
                               IFNULL(inv.amount, IFNULL(pr.price, 0)) as harga,
                               IFNULL(pay_stats.months_paid, 0) as months_paid,
                               6 - IFNULL(pay_stats.months_paid, 0) as months_overdue
                        FROM users u
                        LEFT JOIN invoices inv ON inv.user_id = u.id AND inv.month = ? AND inv.year = ?
                        LEFT JOIN payments p ON p.user_id = u.id AND p.payment_month = ? AND p.payment_year = ? AND p.router_id = u.router_id
                        LEFT JOIN ppp_profile_pricing pr ON pr.profile_name = u.profile AND pr.router_id = u.router_id
                        LEFT JOIN (
                            SELECT user_id, COUNT(id) as months_paid
                            FROM payments
                            WHERE router_id = ?
                              AND (payment_year * 12 + payment_month) >= (? * 12 + ? - 5)
                              AND (payment_year * 12 + payment_month) <= (? * 12 + ?)
                            GROUP BY user_id
                        ) pay_stats ON pay_stats.user_id = u.id
                        $whereSQL
                        ORDER BY months_overdue DESC, u.username ASC
                        LIMIT ? OFFSET ?";

            $dataParams = array_merge(
                [$month, $year, $month, $year, $router_id, $year, $month, $year, $month],
                $params,
                [$perPage, $offset]
            );
            $dataTypes = "iiiisiiii" . $types . "ii";
            $dataStmt = $conn->prepare($dataSQL);
            $dataStmt->bind_param($dataTypes, ...$dataParams);
            $dataStmt->execute();
            $result = $dataStmt->get_result();
            $data = [];
            while ($row = $result->fetch_assoc()) $data[] = $row;
            $dataStmt->close();

            $profileStmt = $conn->prepare("SELECT DISTINCT profile FROM users WHERE router_id = ? AND profile IS NOT NULL AND profile != '' ORDER BY profile ASC");
            $profileStmt->bind_param('s', $router_id);
            $profileStmt->execute();
            $profileRes = $profileStmt->get_result();
            $profiles = [];
            while ($p = $profileRes->fetch_assoc()) {
                $profiles[] = $p['profile'];
            }
            $profileStmt->close();

            echo json_encode([
                'success'          => true,
                'data'             => $data,
                'total'            => (int)($cnt['total'] ?? 0),
                'total_receivable' => (float)($cnt['total_receivable'] ?? 0),
                'page'             => $page,
                'per_page'         => $perPage,
                'month'            => $month,
                'year'             => $year,
                'profiles'         => $profiles,
            ], JSON_UNESCAPED_UNICODE);
            break;

        // ── Export Piutang CSV ───────────────────────────────────────────────
        case 'receivable_export':
            $search  = trim($_GET['search'] ?? '');
            $profile = trim($_GET['profile'] ?? '');

            $where  = ["u.router_id = ?", "p.id IS NULL", "(inv.status IS NULL OR inv.status != 'isolir')"];
            $params = [$router_id];
            $types  = "s";

            if ($search !== '') {
                $where[] = "(u.username LIKE ? OR u.alamat LIKE ? OR u.wa LIKE ?)";
                $like = "%$search%";
                $params = array_merge($params, [$like, $like, $like]);
                $types .= "sss";
            }
            if ($profile !== '') {
                $where[] = "u.profile = ?";
                $params[] = $profile;
                $types .= "s";
            }

            header('Content-Type: text/csv; charset=UTF-8');
            header('Content-Disposition: attachment;filename="piutang_'.$year.'_'.$month.'.csv"');
            $output = fopen('php://output', 'w');
            fprintf($output, chr(0xEF).chr(0xBB).chr(0xBF));
            fputcsv($output, ['Username', 'Profile', 'WA', 'Alamat', 'Tanggal Tagihan', 'Nominal Piutang']);

            $sql = "SELECT u.username, u.profile, u.wa, u.alamat, u.tanggal_tagihan, IFNULL(inv.amount, IFNULL(pr.price, 0)) as harga
                    FROM users u
                    LEFT JOIN invoices inv ON inv.user_id = u.id AND inv.month = ? AND inv.year = ?
                    LEFT JOIN payments p ON p.user_id = u.id AND p.payment_month = ? AND p.payment_year = ? AND p.router_id = u.router_id
                    LEFT JOIN ppp_profile_pricing pr ON pr.profile_name = u.profile AND pr.router_id = u.router_id
                    WHERE " . implode(" AND ", $where) . "
                    ORDER BY u.username ASC";
            $stmt = $conn->prepare($sql);
            $allParams = array_merge([$month, $year, $month, $year], $params);
            $allTypes = "iiii" . $types;
            $stmt->bind_param($allTypes, ...$allParams);
            $stmt->execute();
            $result = $stmt->get_result();
            while ($row = $result->fetch_assoc()) {
                fputcsv($output, [$row['username'], $row['profile'], $row['wa'], $row['alamat'], $row['tanggal_tagihan'], $row['harga']]);
            }
            fclose($output);
            exit;

        // ── Laporan Tahunan ───────────────────────────────────────────────────
        case 'annual_report':
            $monthsMap = [1=>'Jan',2=>'Feb',3=>'Mar',4=>'Apr',5=>'Mei',6=>'Jun',7=>'Jul',8=>'Agu',9=>'Sep',10=>'Okt',11=>'Nov',12=>'Des'];
            $fullMonthsMap = [1=>'Januari',2=>'Februari',3=>'Maret',4=>'April',5=>'Mei',6=>'Juni',7=>'Juli',8=>'Agustus',9=>'September',10=>'Oktober',11=>'November',12=>'Desember'];
            $result = [];
            $ytd_revenue = 0;
            $ytd_expense = 0;

            $stmt = $conn->prepare("SELECT COUNT(id) as total_users FROM users WHERE router_id = ?");
            $stmt->bind_param("s", $router_id);
            $stmt->execute();
            $total_users = $stmt->get_result()->fetch_assoc()['total_users'] ?? 0;
            $stmt->close();

            $stmt = $conn->prepare("
                SELECT payment_month as m,
                       COUNT(id) as paid_count,
                       SUM(CASE WHEN method != 'titipan' THEN amount ELSE 0 END) as revenue
                FROM payments
                WHERE router_id = ? AND payment_year = ?
                GROUP BY payment_month
            ");
            $stmt->bind_param("si", $router_id, $year);
            $stmt->execute();
            $payData = [];
            $res = $stmt->get_result();
            while ($row = $res->fetch_assoc()) {
                $payData[$row['m']] = $row;
            }
            $stmt->close();

            $stmtExp = $conn->prepare("
                SELECT MONTH(spent_at) as m, SUM(amount) as expense
                FROM expenses
                WHERE router_id = ? AND YEAR(spent_at) = ?
                GROUP BY MONTH(spent_at)
            ");
            $stmtExp->bind_param("si", $router_id, $year);
            $stmtExp->execute();
            $expData = [];
            $resExp = $stmtExp->get_result();
            while ($row = $resExp->fetch_assoc()) {
                $expData[$row['m']] = $row['expense'];
            }
            $stmtExp->close();

            for ($m = 1; $m <= 12; $m++) {
                $total = intval($total_users);
                $paid = isset($payData[$m]) ? intval($payData[$m]['paid_count']) : 0;
                $unpaid = $total - $paid;
                $revenue = isset($payData[$m]) ? floatval($payData[$m]['revenue']) : 0;
                $expense = isset($expData[$m]) ? floatval($expData[$m]) : 0;
                
                if ($m <= date('n') || $year < date('Y')) {
                    $ytd_revenue += $revenue;
                    $ytd_expense += $expense;
                }

                $result[] = [
                    'month' => $m,
                    'month_short' => $monthsMap[$m],
                    'month_name' => $fullMonthsMap[$m],
                    'paid' => $paid,
                    'unpaid' => $unpaid,
                    'collection_rate' => $total > 0 ? round(($paid / $total) * 100, 1) : 0,
                    'revenue' => $revenue,
                    'expense' => $expense,
                    'net_profit' => $revenue - $expense
                ];
            }

            echo json_encode([
                'success' => true,
                'data' => $result,
                'ytd_revenue' => $ytd_revenue,
                'ytd_expense' => $ytd_expense,
                'ytd_net_profit' => $ytd_revenue - $ytd_expense,
                'total_users' => intval($result[0]['total_users'] ?? 0) // rough estimation
            ], JSON_UNESCAPED_UNICODE);
            break;

        default:
            echo json_encode(['success' => false, 'message' => "Action '$action' tidak dikenal"]);
    }

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
}
?>
