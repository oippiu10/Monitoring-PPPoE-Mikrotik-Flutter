// ===================================
// DASHBOARD FUNCTIONALITY
// ===================================

// Check authentication on load
window.addEventListener('DOMContentLoaded', () => {
    checkAuthentication();
    loadDashboardData();
    initializeCharts();
    loadUserInfo();
});

// Check if user is logged in
function checkAuthentication() {
    // TODO: Implement proper session check
    const isLoggedIn = sessionStorage.getItem('logged_in');
    if (!isLoggedIn) {
        // window.location.href = 'login.html';
    }
}

// Load user info
async function loadUserInfo() {
    try {
        // Get user info from session storage (saved during login)
        const userInfo = JSON.parse(sessionStorage.getItem('userInfo') || '{}');
        
        if (userInfo.full_name) {
            document.getElementById('userName').textContent = userInfo.full_name;
        } else if (userInfo.username) {
            document.getElementById('userName').textContent = userInfo.username;
        }
        
        // Set user role badge if exists
        if (userInfo.role) {
            const roleBadge = document.createElement('span');
            roleBadge.className = 'user-role-badge';
            roleBadge.textContent = userInfo.role === 'admin' ? 'Admin' : 'Operator';
            roleBadge.style.cssText = 'font-size: 10px; background: var(--primary-orange); padding: 2px 6px; border-radius: 4px; margin-left: 8px;';
            document.getElementById('userName').appendChild(roleBadge);
        }
    } catch (error) {
        console.error('Error loading user info:', error);
    }
}

// Toggle Sidebar
function toggleSidebar() {
    const sidebar = document.getElementById('sidebar');
    sidebar.classList.toggle('show');
}

// Toggle Theme
function toggleTheme() {
    const body = document.body;
    const themeIcon = document.getElementById('themeIcon');
    
    body.classList.toggle('light-theme');
    
    if (body.classList.contains('light-theme')) {
        themeIcon.classList.remove('fa-moon');
        themeIcon.classList.add('fa-sun');
        localStorage.setItem('theme', 'light');
    } else {
        themeIcon.classList.remove('fa-sun');
        themeIcon.classList.add('fa-moon');
        localStorage.setItem('theme', 'dark');
    }
}

// Load saved theme
const savedTheme = localStorage.getItem('theme');
if (savedTheme === 'light') {
    document.body.classList.add('light-theme');
    document.getElementById('themeIcon').classList.replace('fa-moon', 'fa-sun');
}

// Logout
async function logout() {
    if (!confirm('Apakah Anda yakin ingin logout?')) {
        return;
    }
    
    try {
        await fetch('api/auth/logout.php', {
            method: 'POST'
        });
        
        sessionStorage.clear();
        localStorage.removeItem('remember_user');
        window.location.href = 'login.html';
    } catch (error) {
        console.error('Logout error:', error);
        window.location.href = 'login.html';
    }
}

// ===================================
// DATA LOADING
// ===================================

// Load dashboard stats
async function loadDashboardStats() {
    try {
        // Load stats from API
        const response = await fetch('api/dashboard_stats.php');
        const data = await response.json();
        
        if (data.success) {
            updateStats(data.data);
        } else {
            // Use demo data if API fails
            useDemoData();
        }
    } catch (error) {
        console.error('Error loading dashboard data:', error);
        useDemoData();
    }
}

function updateStats(data) {
    document.getElementById('totalUsers').textContent = formatNumber(data.total_users || 0);
    document.getElementById('onlineUsers').textContent = formatNumber(data.online_users || 0);
    document.getElementById('revenue').textContent = formatCurrency(data.revenue || 0);
    document.getElementById('pendingPayments').textContent = formatNumber(data.pending_payments || 0);
}

function useDemoData() {
    // Demo data for testing
    updateStats({
        total_users: 1234,
        online_users: 856,
        revenue: 45000000,
        pending_payments: 23
    });
}

// Format numbers
function formatNumber(num) {
    return new Intl.NumberFormat('id-ID').format(num);
}

// Format currency
function formatCurrency(num) {
    return new Intl.NumberFormat('id-ID', {
        style: 'currency',
        currency: 'IDR',
        minimumFractionDigits: 0
    }).format(num);
}

// ===================================
// CHARTS
// ===================================

let trafficChart, statusChart;

function initializeCharts() {
    initTrafficChart();
    initStatusChart();
}

function initTrafficChart() {
    const ctx = document.getElementById('trafficChart').getContext('2d');
    
    const gradient1 = ctx.createLinearGradient(0, 0, 0, 400);
    gradient1.addColorStop(0, 'rgba(30, 136, 229, 0.5)');
    gradient1.addColorStop(1, 'rgba(30, 136, 229, 0)');
    
    const gradient2 = ctx.createLinearGradient(0, 0, 0, 400);
    gradient2.addColorStop(0, 'rgba(255, 111, 0, 0.5)');
    gradient2.addColorStop(1, 'rgba(255, 111, 0, 0)');
    
    trafficChart = new Chart(ctx, {
        type: 'line',
        data: {
            labels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
            datasets: [
                {
                    label: 'Upload (GB)',
                    data: [65, 59, 80, 81, 56, 55, 70],
                    borderColor: '#1e88e5',
                    backgroundColor: gradient1,
                    borderWidth: 2,
                    fill: true,
                    tension: 0.4
                },
                {
                    label: 'Download (GB)',
                    data: [28, 48, 40, 19, 86, 27, 90],
                    borderColor: '#ff6f00',
                    backgroundColor: gradient2,
                    borderWidth: 2,
                    fill: true,
                    tension: 0.4
                }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    display: true,
                    position: 'top',
                    labels: {
                        color: '#b0bec5',
                        font: {
                            size: 12
                        }
                    }
                }
            },
            scales: {
                y: {
                    beginAtZero: true,
                    grid: {
                        color: 'rgba(255, 255, 255, 0.05)'
                    },
                    ticks: {
                        color: '#b0bec5'
                    }
                },
                x: {
                    grid: {
                        color: 'rgba(255, 255, 255, 0.05)'
                    },
                    ticks: {
                        color: '#b0bec5'
                    }
                }
            }
        }
    });
}

function initStatusChart() {
    const ctx = document.getElementById('statusChart').getContext('2d');
    
    statusChart = new Chart(ctx, {
        type: 'doughnut',
        data: {
            labels: ['Online', 'Offline', 'Disabled'],
            datasets: [{
                data: [856, 345, 33],
                backgroundColor: [
                    '#4caf50',
                    '#ff6f00',
                    '#f44336'
                ],
                borderWidth: 0
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    display: true,
                    position: 'bottom',
                    labels: {
                        color: '#b0bec5',
                        font: {
                            size: 12
                        },
                        padding: 15
                    }
                }
            }
        }
    });
}

// ===================================
// REAL-TIME UPDATES
// ===================================

// Update dashboard every 30 seconds
setInterval(() => {
    loadDashboardData();
}, 30000);

// ===================================
// RESPONSIVE SIDEBAR
// ===================================

// Close sidebar when clicking outside on mobile
document.addEventListener('click', (e) => {
    const sidebar = document.getElementById('sidebar');
    const menuToggle = document.querySelector('.mobile-menu-toggle');
    
    if (window.innerWidth <= 768) {
        if (!sidebar.contains(e.target) && !menuToggle.contains(e.target)) {
            sidebar.classList.remove('show');
        }
    }
});

// Handle window resize
window.addEventListener('resize', () => {
    const sidebar = document.getElementById('sidebar');
    if (window.innerWidth > 768) {
        sidebar.classList.remove('show');
    }
});

// ===================================
// KEYBOARD SHORTCUTS
// ===================================

document.addEventListener('keydown', (e) => {
    // Ctrl/Cmd + K to focus search
    if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
        e.preventDefault();
        document.querySelector('.search-box input').focus();
    }
    
    // Ctrl/Cmd + B to toggle sidebar
    if ((e.ctrlKey || e.metaKey) && e.key === 'b') {
        e.preventDefault();
        toggleSidebar();
    }
});

// ===================================
// NOTIFICATIONS
// ===================================

function showNotification(message, type = 'info') {
    // TODO: Implement notification system
    console.log(`[${type}] ${message}`);
}

// ===================================
// EXPORT FUNCTIONS
// ===================================

window.toggleSidebar = toggleSidebar;
window.toggleTheme = toggleTheme;
window.logout = logout;
