<?php
/**
 * Diagnosa Koneksi Mikrotik — Tool analisis lengkap
 */
header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');
header('Cache-Control: no-cache');

$host    = isset($_GET['host']) ? trim($_GET['host']) : '';
$port    = isset($_GET['port']) ? intval($_GET['port']) : 8728;
$user    = isset($_GET['user']) ? trim($_GET['user']) : 'admin';
$pass    = isset($_GET['pass']) ? trim($_GET['pass']) : '';
$timeout = 5;

if (!$host) {
    echo json_encode(['error' => 'Parameter host wajib']);
    exit;
}

$result = [
    'host'   => $host,
    'port'   => $port,
    'checks' => []
];

// ================================================
// CHECK 1: Resolve DNS
// ================================================
$ip = gethostbyname($host);
$dnsOk = ($ip !== $host || filter_var($host, FILTER_VALIDATE_IP));
$result['checks'][] = [
    'step'    => 'DNS / IP Resolve',
    'ok'      => $dnsOk,
    'detail'  => $dnsOk ? "IP: $ip" : "Tidak bisa resolve hostname '$host'",
];

if (!$dnsOk) {
    $result['conclusion'] = 'IP/hostname tidak valid atau tidak bisa diresolve';
    $result['fix'] = 'Pastikan IP Mikrotik benar. Coba ping dari CMD: ping ' . $host;
    echo json_encode($result, JSON_PRETTY_PRINT);
    exit;
}

// ================================================
// CHECK 2: Test berbagai port (bukan hanya 8728)
// ================================================
$commonPorts = [
    8728 => 'Mikrotik API',
    8729 => 'Mikrotik API-SSL',
    80   => 'HTTP (Mikrotik Web)',
    443  => 'HTTPS',
    22   => 'SSH',
    23   => 'Telnet/Winbox',
    8291 => 'Winbox',
];

$portResults = [];
foreach ($commonPorts as $p => $name) {
    $t   = microtime(true);
    $sock = @fsockopen($ip, $p, $en, $es, 2); // timeout 2s per port
    $ms  = round((microtime(true) - $t) * 1000, 0);
    $open = ($sock !== false);
    if ($sock) fclose($sock);
    $portResults[$p] = ['name' => $name, 'open' => $open, 'ms' => $ms, 'errno' => $en, 'errstr' => $es];
}

$apiPortOpen = $portResults[$port]['open'] ?? false;
$anyPortOpen = array_filter($portResults, fn($r) => $r['open']);

$result['port_scan'] = $portResults;
$result['checks'][] = [
    'step'   => "Port $port ($commonPorts[$port] ?? 'Custom') terbuka?",
    'ok'     => $apiPortOpen,
    'detail' => $apiPortOpen
        ? "Port $port TERBUKA ({$portResults[$port]['ms']}ms)"
        : "Port $port TERTUTUP — errno {$portResults[$port]['errno']}: {$portResults[$port]['errstr']}",
];

$openPortList = implode(', ', array_keys($anyPortOpen));
$result['checks'][] = [
    'step'   => 'Port lain yang terbuka',
    'ok'     => count($anyPortOpen) > 0,
    'detail' => count($anyPortOpen) > 0
        ? "Port terbuka: $openPortList"
        : "Semua port tertutup — kemungkinan IP salah atau firewall total",
];

// ================================================
// CHECK 3: Jika port 8728 open, coba login API
// ================================================
if ($apiPortOpen) {
    $t = microtime(true);
    $sock = @fsockopen($ip, $port, $en, $es, $timeout);
    $ms = round((microtime(true) - $t) * 1000, 1);

    if ($sock) {
        stream_set_timeout($sock, $timeout);

        function sendWord($s, $w) {
            $l = strlen($w);
            if ($l < 0x80) fwrite($s, chr($l) . $w);
            elseif ($l < 0x4000) fwrite($s, chr(($l >> 8) | 0x80) . chr($l & 0xFF) . $w);
            else fwrite($s, chr(($l >> 16) | 0xC0) . chr(($l >> 8) & 0xFF) . chr($l & 0xFF) . $w);
        }
        function recvWord($s) {
            $b = fread($s, 1);
            if ($b === false || $b === '') return null;
            $l = ord($b);
            if ($l & 0xC0) { $b2 = ord(fread($s, 1)); $l = (($l & 0x3F) << 8) | $b2; }
            if ($l === 0) return '';
            return fread($s, $l);
        }

        sendWord($sock, '/login');
        sendWord($sock, '=name=' . $user);
        sendWord($sock, '=password=' . $pass);
        sendWord($sock, '');

        $words = [];
        $w = recvWord($sock);
        while ($w !== '' && $w !== null) { $words[] = $w; $w = recvWord($sock); }
        fclose($sock);

        $loginOk = in_array('!done', $words);
        $errMsg  = '';
        foreach ($words as $wr) {
            if (strpos($wr, '=message=') === 0) $errMsg = substr($wr, 9);
        }

        $result['checks'][] = [
            'step'   => 'Login API Mikrotik',
            'ok'     => $loginOk,
            'detail' => $loginOk
                ? "Login berhasil! Latency: {$ms}ms"
                : 'Login gagal: ' . ($errMsg ?: implode(', ', $words)),
            'latency_ms' => $ms,
            'raw' => $words,
        ];

        if ($loginOk) {
            $result['conclusion'] = '✅ Koneksi berhasil!';
            $result['success']    = true;
        } else {
            $result['conclusion'] = '❌ Port terbuka tapi login gagal';
            $result['fix_steps']  = [
                '1. Periksa username dan password Mikrotik',
                '2. Pastikan user memiliki izin akses API (group yang punya policy api)',
                '3. Cek: IP > Services > api > Allowed Addresses — pastikan IP server ada di sana',
                '4. Di Mikrotik: /user print — lihat user dan groupnya',
                '5. Di Mikrotik: /user group print — cek group punya policy=api',
            ];
        }
    } else {
        $result['checks'][] = ['step' => 'Login API', 'ok' => false, 'detail' => "Gagal buka socket: $es ($en)"];
    }
} else {
    // Port tertutup — analisis errno
    $errno = $portResults[$port]['errno'] ?? 0;
    $errstr = $portResults[$port]['errstr'] ?? '';

    $result['checks'][] = ['step' => 'Login API', 'ok' => false, 'detail' => 'Skip — port tertutup'];

    if ($errno == 10060 || $errno == 110) {
        $result['conclusion'] = '❌ Timeout — IP tidak terjangkau atau port diblokir firewall';
        $result['fix_steps']  = [
            '1. Pastikan laptop dan Mikrotik berada di jaringan yang sama',
            '2. Coba ping dari CMD: ping ' . $host,
            '3. Di Mikrotik: IP > Services > api — pastikan Enable dan bukan Disabled',
            '4. Di Mikrotik: IP > Firewall — tambah rule Allow port 8728 dari src-address=' . $_SERVER['SERVER_ADDR'],
            '5. Cek "Allowed Addresses" di API service — kosongkan untuk allow semua atau masukkan IP server ini (' . $_SERVER['SERVER_ADDR'] . ')',
        ];
    } elseif ($errno == 10061 || $errno == 111) {
        $result['conclusion'] = '❌ Connection Refused — Host terjangkau tapi port 8728 ditolak';
        $result['fix_steps']  = [
            '1. Di Mikrotik: IP > Services > api — pastikan statusnya Enabled',
            '2. Ubah port jika berbeda (default: 8728)',
            '3. Cek firewall Mikrotik tidak memblokir port 8728',
        ];
    } elseif (count($anyPortOpen) === 0) {
        $result['conclusion'] = '❌ Semua port tertutup — IP kemungkinan salah atau Mikrotik mati';
        $result['fix_steps']  = [
            '1. Verifikasi IP Mikrotik: di Winbox atau terminal Mikrotik ketik: ip address print',
            '2. Coba ping: ping ' . $host . ' dari CMD',
            '3. Pastikan kabel/WiFi antara server dan Mikrotik terhubung',
            '4. Cek apakah Mikrotik nyala',
        ];
    } else {
        $result['conclusion'] = "❌ Port API ($port) tertutup tapi port lain terbuka (" . $openPortList . ")";
        $result['fix_steps']  = [
            '1. Di Mikrotik: IP > Services > api — Enable dan pastikan port 8728',
            '2. Cek firewall Mikrotik tidak memblokir port 8728',
            '3. Cek Allowed Addresses di API service — tambah IP server: ' . $_SERVER['SERVER_ADDR'],
        ];
    }
}

// Server IP info
$result['server_ip'] = $_SERVER['SERVER_ADDR'] ?? 'unknown';
$result['timestamp'] = date('Y-m-d H:i:s');

echo json_encode($result, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
?>
