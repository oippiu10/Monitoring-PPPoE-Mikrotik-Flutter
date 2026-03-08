<?php
/**
 * Database Connection Test
 * Upload file ini ke web/api/ dan akses via browser
 * untuk cek koneksi database
 */

error_reporting(E_ALL);
ini_set('display_errors', 1);

echo "<h2>Database Connection Test</h2>";
echo "<hr>";

// Test 1: Check config file
echo "<h3>1. Config File Check</h3>";
$configPath = __DIR__ . '/config.php';
if (file_exists($configPath)) {
    echo "✅ config.php exists<br>";
    require_once $configPath;
} else {
    echo "❌ config.php NOT FOUND at: $configPath<br>";
    die();
}

// Test 2: Check database connection
echo "<h3>2. Database Connection</h3>";
if (isset($conn) && $conn instanceof mysqli) {
    if ($conn->connect_error) {
        echo "❌ Connection FAILED: " . $conn->connect_error . "<br>";
        echo "Error Code: " . $conn->connect_errno . "<br>";
    } else {
        echo "✅ Connected successfully<br>";
        echo "Database: " . $conn->get_server_info() . "<br>";
    }
} else {
    echo "❌ Connection object not created<br>";
    die();
}

// Test 3: Check database exists
echo "<h3>3. Database Check</h3>";
$result = $conn->query("SELECT DATABASE()");
if ($result) {
    $row = $result->fetch_row();
    echo "✅ Current database: " . $row[0] . "<br>";
} else {
    echo "❌ Cannot get database name<br>";
}

// Test 4: Check admin_users table
echo "<h3>4. Table Check</h3>";
$result = $conn->query("SHOW TABLES LIKE 'admin_users'");
if ($result && $result->num_rows > 0) {
    echo "✅ Table 'admin_users' exists<br>";
    
    // Count records
    $count = $conn->query("SELECT COUNT(*) as total FROM admin_users");
    $row = $count->fetch_assoc();
    echo "Records in admin_users: " . $row['total'] . "<br>";
    
    // Show users
    $users = $conn->query("SELECT id, username, role, is_active FROM admin_users");
    if ($users && $users->num_rows > 0) {
        echo "<table border='1' cellpadding='5'>";
        echo "<tr><th>ID</th><th>Username</th><th>Role</th><th>Active</th></tr>";
        while ($user = $users->fetch_assoc()) {
            echo "<tr>";
            echo "<td>" . $user['id'] . "</td>";
            echo "<td>" . $user['username'] . "</td>";
            echo "<td>" . $user['role'] . "</td>";
            echo "<td>" . ($user['is_active'] ? 'Yes' : 'No') . "</td>";
            echo "</tr>";
        }
        echo "</table>";
    }
} else {
    echo "❌ Table 'admin_users' NOT FOUND<br>";
    echo "<strong>SOLUTION:</strong> Run setup_web_admin.sql in phpMyAdmin<br>";
}

// Test 5: Test login API
echo "<h3>5. Login API Test</h3>";
$loginPath = __DIR__ . '/auth/login.php';
if (file_exists($loginPath)) {
    echo "✅ login.php exists<br>";
} else {
    echo "❌ login.php NOT FOUND at: $loginPath<br>";
}

echo "<hr>";
echo "<h3>Summary</h3>";
echo "If all tests pass, login should work!<br>";
echo "If admin_users table not found, run setup_web_admin.sql<br>";

$conn->close();
?>
