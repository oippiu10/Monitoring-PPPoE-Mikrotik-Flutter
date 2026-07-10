<?php
require_once __DIR__ . '/api/version_config.php';
function isUpdateRequired($clientVersion, $clientBuild) {
    $checkVersion = preg_replace('/[^0-9\.]/', '', $clientVersion);
    $parts = explode('.', $checkVersion);
    while (count($parts) < 3 && $checkVersion !== '') {
        $parts[] = '0';
        $checkVersion = implode('.', $parts);
    }
    echo "CheckVersion: $checkVersion\n";
    if (version_compare($checkVersion, MINIMUM_REQUIRED_VERSION, '<')) { return true; }
    if ($clientBuild < LATEST_BUILD_NUMBER) { return false; }
    return false;
}
echo 'Required: ' . (isUpdateRequired('1.0.12', 14) ? 'true' : 'false') . "\n";
echo 'Available: ' . ((14 < LATEST_BUILD_NUMBER) ? 'true' : 'false') . "\n";
