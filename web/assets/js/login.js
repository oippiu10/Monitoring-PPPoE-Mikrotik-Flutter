// ===================================
// LOGIN FUNCTIONALITY
// ===================================

// Toggle Password Visibility
function togglePassword() {
    const passwordInput = document.getElementById('password');
    const toggleIcon = document.getElementById('toggleIcon');
    
    if (passwordInput.type === 'password') {
        passwordInput.type = 'text';
        toggleIcon.classList.remove('fa-eye');
        toggleIcon.classList.add('fa-eye-slash');
    } else {
        passwordInput.type = 'password';
        toggleIcon.classList.remove('fa-eye-slash');
        toggleIcon.classList.add('fa-eye');
    }
}

// Show Alert Message
function showAlert(message, type = 'error') {
    // Remove existing alerts
    const existingAlert = document.querySelector('.alert');
    if (existingAlert) {
        existingAlert.remove();
    }
    
    // Create new alert
    const alert = document.createElement('div');
    alert.className = `alert alert-${type} show`;
    alert.innerHTML = `
        <i class="fas fa-${type === 'success' ? 'check-circle' : 'exclamation-circle'}"></i>
        ${message}
    `;
    
    // Insert before form
    const form = document.getElementById('loginForm');
    form.parentNode.insertBefore(alert, form);
    
    // Auto hide after 5 seconds
    setTimeout(() => {
        alert.classList.remove('show');
        setTimeout(() => alert.remove(), 300);
    }, 5000);
}

// Login Form Submit
document.getElementById('loginForm').addEventListener('submit', async function(e) {
    e.preventDefault();
    
    const username = document.getElementById('username').value;
    const password = document.getElementById('password').value;
    const remember = document.querySelector('input[name="remember"]').checked;
    const submitBtn = document.querySelector('.btn-login');
    
    // Validation
    if (!username || !password) {
        showAlert('Username dan password harus diisi!', 'error');
        return;
    }
    
    // Show loading state
    submitBtn.classList.add('loading');
    submitBtn.innerHTML = '<i class="fas fa-sign-in-alt"></i> Memproses...';
    
    try {
        // Call login API
        const response = await fetch('api/auth/login.php', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                username: username,
                password: password,
                remember: remember
            })
        });
        
        const data = await response.json();
        
        if (data.success) {
            showAlert('Login berhasil! Mengalihkan ke dashboard...', 'success');
            
            // Save session
            if (remember) {
                localStorage.setItem('remember_user', username);
            }
            // Save user info to session storage
            sessionStorage.setItem('username', data.data.username);
            sessionStorage.setItem('userInfo', JSON.stringify(data.data));
            
            // Redirect to dashboard
            setTimeout(() => {
                window.location.href = 'dashboard.html';
            }, 1000);
        } else {
            showAlert(data.message || 'Username atau password salah!', 'error');
            submitBtn.classList.remove('loading');
            submitBtn.innerHTML = '<i class="fas fa-sign-in-alt"></i> Login';
        }
    } catch (error) {
        console.error('Login error:', error);
        showAlert('Terjadi kesalahan koneksi. Silakan coba lagi.', 'error');
        submitBtn.classList.remove('loading');
        submitBtn.innerHTML = '<i class="fas fa-sign-in-alt"></i> Login';
    }
});

// Demo Mode Login
function loginDemo() {
    document.getElementById('username').value = 'admin';
    document.getElementById('password').value = 'demo123';
    
    showAlert('Demo credentials telah diisi. Klik Login untuk melanjutkan.', 'success');
}

// Load Remembered User
window.addEventListener('DOMContentLoaded', () => {
    const rememberedUser = localStorage.getItem('remember_user');
    if (rememberedUser) {
        document.getElementById('username').value = rememberedUser;
        document.querySelector('input[name="remember"]').checked = true;
    }
    
    // Focus on first empty field
    if (!rememberedUser) {
        document.getElementById('username').focus();
    } else {
        document.getElementById('password').focus();
    }
});

// Keyboard Shortcuts
document.addEventListener('keydown', (e) => {
    // Ctrl/Cmd + K to focus username
    if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
        e.preventDefault();
        document.getElementById('username').focus();
    }
});

// Prevent multiple form submissions
let isSubmitting = false;
document.getElementById('loginForm').addEventListener('submit', function(e) {
    if (isSubmitting) {
        e.preventDefault();
        return false;
    }
    isSubmitting = true;
    
    // Reset after 3 seconds
    setTimeout(() => {
        isSubmitting = false;
    }, 3000);
});
