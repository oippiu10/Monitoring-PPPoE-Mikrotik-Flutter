<?php
/**
 * Version Configuration
 * Central place to manage app version and download URL
 */

const LATEST_VERSION = '1.0.16+20';
const LATEST_BUILD_NUMBER = 20;

// The direct URL to the APK file
// Change this when you upload a new APK
$protocol = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off' || $_SERVER['SERVER_PORT'] == 443) ? "https://" : "http://";
$domainName = $_SERVER['HTTP_HOST'] ?? 'cmmnetwork.online';
define('REAL_APK_URL', $protocol . $domainName . '/files/app-release.apk');

// Minimum version required to force update
const MINIMUM_REQUIRED_VERSION = '1.0.12';
?>
