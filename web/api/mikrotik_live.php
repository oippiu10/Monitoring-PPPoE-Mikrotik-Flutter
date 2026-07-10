<?php
/**
 * Mikrotik Live Data API — dengan caching
 *
 * Query yang didukung (?cmd=...):
 *   ppp_active    — daftar PPPoE active connections
 *   ppp_secret    — daftar PPPoE secrets (user list)
 *   interface     — daftar interface + traffic
 *   resource      — CPU, RAM, uptime router
 *   log           — system log Mikrotik (TTL pendek)
 *   cache_status  — lihat status cache (debug)
 *   cache_clear   — hapus cache spesifik / semua
 *
 * Params: host, port, user, pass, cmd, ttl (opsional, default per cmd)
 */

header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');
header('Cache-Control: no-store');

require_once __DIR__ . '/config.php';          // DB connection ($conn)
require_once __DIR__ . '/routerosAPI.php';     // RouterosAPI class
require_once __DIR__ . '/mikrotik_cache.php';  // MikrotikCache class

// ─── Ambil parameter ────────────────────────────────────────────────────────
$host = trim($_GET['host'] ?? '');
$port = intval($_GET['port'] ?? 8728);
$user = trim($_GET['user'] ?? 'admin');
$pass = $_GET['pass'] ?? '';
$cmd  = trim($_GET['cmd']  ?? 'ppp_active');
$ttl  = intval($_GET['ttl'] ?? 0); // 0 = gunakan default per cmd

// TTL default per command (detik)
$defaultTtl = [
    'ppp_active'  => 1,
    'ppp_secret'  => 2,
    'ppp_profile' => 2,
    'interface'   => 1,
    'resource'    => 1,
    'log'         => 1,
    'ip_address'  => 1,
];
if ($ttl <= 0) $ttl = $defaultTtl[$cmd] ?? 1;

// Command mapping ke Mikrotik API path
$cmdMap = [
    'ppp_active'  => '/ppp/active/print',
    'ppp_secret'  => '/ppp/secret/print',
    'ppp_profile' => '/ppp/profile/print',
    'interface'   => '/interface/print',
    'resource'    => '/system/resource/print',
    'license'     => '/system/license/print',
    'log'         => '/log/print',
    'ip_address'  => '/ip/address/print',
];

// ─── Cache status / clear (tidak perlu host) ────────────────────────────────
$cache = new MikrotikCache($conn);

if ($cmd === 'cache_status') {
    echo json_encode([
        'success' => true,
        'cache'   => $cache->listAll(),
        'time'    => date('Y-m-d H:i:s')
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    exit;
}

if ($cmd === 'cache_clear') {
    $key = $_GET['key'] ?? '';
    if ($key) {
        $cache->invalidate($key);
        echo json_encode(['success' => true, 'message' => "Cache '$key' dihapus"]);
    } else {
        $cleaned = $cache->cleanup();
        echo json_encode(['success' => true, 'message' => "$cleaned cache expired dihapus"]);
    }
    exit;
}

// ─── Validasi ────────────────────────────────────────────────────────────────
if (!$host) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Parameter host wajib']);
    exit;
}

if (!isset($cmdMap[$cmd])) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => "Command '$cmd' tidak dikenal. Pilihan: " . implode(', ', array_keys($cmdMap))]);
    exit;
}

// ─── Fetch dengan cache ──────────────────────────────────────────────────────
$cacheKey = "mt_{$host}_{$port}_{$cmd}";

try {
    $result = $cache->getOrFetch($cacheKey, $ttl, function() use ($host, $port, $user, $pass, $cmdMap, $cmd) {
        $api = new RouterosAPI();
        $api->port    = $port ?: 8728;
        $api->timeout = 5;

        if (!$api->connect($host, $user, $pass)) {
            throw new Exception("Gagal konek ke Mikrotik $host:$api->port");
        }

        $data = $api->comm($cmdMap[$cmd]);
        $api->disconnect();
        return $data;
    });

    echo json_encode([
        'success'    => true,
        'cmd'        => $cmd,
        'host'       => $host,
        'from_cache' => $result['from_cache'],
        'stale'      => $result['stale'] ?? false,
        'ttl_sec'    => $ttl,
        'cache_key'  => $cacheKey,
        'count'      => count($result['data'] ?? []),
        'data'       => $result['data'],
        'time'       => date('Y-m-d H:i:s'),
    ], JSON_UNESCAPED_UNICODE);

} catch (Exception $e) {
    http_response_code(503);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage(),
        'cmd'     => $cmd,
        'host'    => $host,
    ]);
}
?>
