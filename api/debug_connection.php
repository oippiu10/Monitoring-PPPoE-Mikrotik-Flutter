<?php
header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');

// Ambil parameter dari GET
$host    = isset($_GET['host']) ? trim($_GET['host']) : '';
$port    = isset($_GET['port']) ? intval($_GET['port']) : 8728;
$user    = isset($_GET['user']) ? trim($_GET['user']) : 'admin';
$pass    = isset($_GET['pass']) ? trim($_GET['pass']) : '';
$timeout = 5;

if (!$host) {
    echo json_encode(['success' => false, 'message' => 'Parameter host wajib diisi']);
    exit;
}

// Validasi port
if ($port <= 0 || $port > 65535) {
    $port = 8728;
}

// Step 1: Cek apakah host/port bisa dicapai (TCP socket)
$start  = microtime(true);
$socket = @fsockopen($host, $port, $errno, $errstr, $timeout);
$elapsed = round((microtime(true) - $start) * 1000, 1); // ms

if (!$socket) {
    echo json_encode([
        'success' => false,
        'message' => "Tidak dapat terhubung ke $host:$port — $errstr ($errno)",
        'latency_ms' => $elapsed,
        'tips' => [
            'Pastikan IP Mikrotik benar dan dapat dijangkau dari server PHP',
            'Port API Mikrotik default: 8728 (atau 8729 untuk SSL)',
            'Aktifkan API service di Mikrotik: IP > Services > api > enable',
            'Cek firewall Mikrotik tidak memblokir port 8728'
        ]
    ]);
    exit;
}

// Step 2: Socket berhasil — coba login via Mikrotik API protocol
try {
    stream_set_timeout($socket, $timeout);

    // Helper: kirim word ke API
    function writeWord($socket, $word) {
        $len = strlen($word);
        $out = '';
        if ($len < 0x80)        $out = chr($len);
        elseif ($len < 0x4000)  $out = chr(($len >> 8) | 0x80) . chr($len & 0xFF);
        else                    $out = chr(($len >> 16) | 0xC0) . chr(($len >> 8) & 0xFF) . chr($len & 0xFF);
        fwrite($socket, $out . $word);
    }

    // Helper: baca word dari API
    function readWord($socket) {
        $byte = fread($socket, 1);
        if ($byte === false || $byte === '') return null;
        $len  = ord($byte);
        if ($len & 0xC0) {
            $b2  = ord(fread($socket, 1));
            $len = (($len & 0x3F) << 8) | $b2;
        }
        if ($len === 0) return '';
        return fread($socket, $len);
    }

    // Kirim /login username
    writeWord($socket, '/login');
    writeWord($socket, '=name=' . $user);
    writeWord($socket, '=password=' . $pass);
    writeWord($socket, ''); // end of sentence

    // Baca respons
    $result = [];
    $word = readWord($socket);
    while ($word !== '' && $word !== null) {
        $result[] = $word;
        $word = readWord($socket);
    }

    fclose($socket);

    if (in_array('!done', $result)) {
        echo json_encode([
            'success'    => true,
            'message'    => "Berhasil terhubung ke Mikrotik di $host:$port",
            'latency_ms' => $elapsed,
            'response'   => $result
        ]);
    } else {
        $errMsg = '';
        foreach ($result as $r) {
            if (strpos($r, '=message=') === 0) {
                $errMsg = substr($r, 9);
            }
        }
        echo json_encode([
            'success'    => false,
            'message'    => 'Terhubung ke port tapi login gagal: ' . ($errMsg ?: implode(', ', $result)),
            'latency_ms' => $elapsed,
            'tips'       => [
                'Periksa username dan password Mikrotik',
                'Pastikan user Mikrotik memiliki akses API',
                'Tambahkan IP web server ke allowed addresses di API service'
            ]
        ]);
    }
} catch (Exception $e) {
    if ($socket) fclose($socket);
    echo json_encode([
        'success' => false,
        'message' => 'Error: ' . $e->getMessage(),
        'latency_ms' => $elapsed
    ]);
}
?>
