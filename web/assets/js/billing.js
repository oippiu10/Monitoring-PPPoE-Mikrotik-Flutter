let currentMonth = new Date().getMonth() + 1;
let currentYear = new Date().getFullYear();
let currentPage = 1;
let totalPages = 1;
let paymentTarget = null;
let searchTimer = null;
const perPage = 25;

const MONTHS_ID = ['Januari','Februari','Maret','April','Mei','Juni','Juli','Agustus','September','Oktober','November','Desember'];

function init() {
    loadTheme();
    try {
        const u = JSON.parse(sessionStorage.getItem('userInfo') || '{}');
        document.getElementById('sidebarUserName').textContent = u.full_name || u.username || 'Admin';
        document.getElementById('userAvatarLetter').textContent = (u.full_name || u.username || 'A').charAt(0).toUpperCase();
    } catch(e) {}
    updateMonthDisplay();
    loadBilling();
    loadProfiles();
}

function updateMonthDisplay() {
    document.getElementById('monthDisplay').textContent = `${MONTHS_ID[currentMonth-1]} ${currentYear}`;
}

function changeMonth(dir) {
    currentMonth += dir;
    if (currentMonth > 12) { currentMonth = 1; currentYear++; }
    if (currentMonth < 1) { currentMonth = 12; currentYear--; }
    updateMonthDisplay();
    currentPage = 1;
    loadBilling();
}

function loadTheme() {
    if (localStorage.getItem('theme') === 'light') {
        document.body.classList.add('light-theme');
        document.getElementById('themeIcon').className = 'fas fa-sun';
    }
}
function toggleTheme() {
    document.body.classList.toggle('light-theme');
    const isLight = document.body.classList.contains('light-theme');
    document.getElementById('themeIcon').className = isLight ? 'fas fa-sun' : 'fas fa-moon';
    localStorage.setItem('theme', isLight ? 'light' : 'dark');
}
function toggleSidebar() { document.getElementById('sidebar').classList.toggle('show'); }
document.addEventListener('click', e => {
    if (window.innerWidth <= 768 && !document.getElementById('sidebar').contains(e.target) && !e.target.closest('.mobile-menu-toggle'))
        document.getElementById('sidebar').classList.remove('show');
});
async function logout() {
    if (!confirm('Yakin logout?')) return;
    try { await fetch('api/auth/logout.php', { method: 'POST' }); } catch(e) {}
    sessionStorage.clear(); window.location.href = 'login.html';
}

function showToast(title, msg, type = 'info') {
    const icons = { success:'fa-check-circle', error:'fa-times-circle', warning:'fa-exclamation-triangle', info:'fa-info-circle' };
    const t = document.createElement('div');
    t.className = `toast ${type}`;
    t.innerHTML = `<i class="fas ${icons[type]} toast-icon"></i><div class="toast-content"><div class="toast-title">${title}</div>${msg?`<div class="toast-message">${msg}</div>`:''}</div><button class="toast-close" onclick="this.parentElement.remove()"><i class="fas fa-times"></i></button>`;
    document.getElementById('toastContainer').appendChild(t);
    setTimeout(() => t.remove(), 4000);
}

function onSearch() {
    clearTimeout(searchTimer);
    searchTimer = setTimeout(() => { currentPage = 1; loadBilling(); }, 400);
}

async function loadBilling() {
    const search = document.getElementById('searchInput').value;
    const status = document.getElementById('filterStatus').value;
    const profile = document.getElementById('filterProfile').value;

    document.getElementById('billingTableBody').innerHTML = `<tr><td colspan="8" style="padding:0;">
<div style="display:flex; flex-direction:column;">
    <div style="padding:16px; border-bottom:1px solid var(--border); display:flex; align-items:center; justify-content:space-between; gap:16px;">
        <div class="skeleton-line" style="flex:2;"><div class="skeleton skeleton-circle"></div><div style="flex:1;"><div class="skeleton skeleton-text" style="width:60%; margin-bottom:6px;"></div><div class="skeleton skeleton-text" style="width:40%;"></div></div></div>
        <div class="skeleton skeleton-badge" style="flex:1;"></div>
        <div class="skeleton skeleton-text" style="flex:1; height:20px;"></div>
        <div class="skeleton skeleton-text" style="flex:1; height:20px;"></div>
    </div>
    <div style="padding:16px; border-bottom:1px solid var(--border); display:flex; align-items:center; justify-content:space-between; gap:16px;">
        <div class="skeleton-line" style="flex:2;"><div class="skeleton skeleton-circle"></div><div style="flex:1;"><div class="skeleton skeleton-text" style="width:70%; margin-bottom:6px;"></div><div class="skeleton skeleton-text" style="width:50%;"></div></div></div>
        <div class="skeleton skeleton-badge" style="flex:1;"></div>
        <div class="skeleton skeleton-text" style="flex:1; height:20px;"></div>
        <div class="skeleton skeleton-text" style="flex:1; height:20px;"></div>
    </div>
    <div style="padding:16px; border-bottom:1px solid var(--border); display:flex; align-items:center; justify-content:space-between; gap:16px;">
        <div class="skeleton-line" style="flex:2;"><div class="skeleton skeleton-circle"></div><div style="flex:1;"><div class="skeleton skeleton-text" style="width:50%; margin-bottom:6px;"></div><div class="skeleton skeleton-text" style="width:30%;"></div></div></div>
        <div class="skeleton skeleton-badge" style="flex:1;"></div>
        <div class="skeleton skeleton-text" style="flex:1; height:20px;"></div>
        <div class="skeleton skeleton-text" style="flex:1; height:20px;"></div>
    </div>
</div>
</td></tr>`;

    try {
        const r = typeof getActiveRouter === 'function' ? getActiveRouter() : null;
        const router_id = r ? (r.software_id || '') : '';
        const params = new URLSearchParams({ month: currentMonth, year: currentYear, page: currentPage, per_page: perPage, search, status, profile, router_id });
        const res = await fetch(`../../api/get_all_payments_for_month_year.php?${params}`);
        const data = await res.json();

        if (data.success) {
            renderTable(data.data || []);
            renderPagination(data.total || 0, data.page || 1, data.per_page || perPage);
            updateSummary(data.summary || {});
        } else {
            showEmpty(data.message);
        }
    } catch(e) {
        showEmpty('Tidak dapat terhubung ke server');
    }
}

function showEmpty(msg) {
    document.getElementById('billingTableBody').innerHTML = `<tr><td colspan="8"><div class="empty-state"><i class="fas fa-plug"></i><h4>Gagal memuat data</h4><p>${msg || ''}</p></div></td></tr>`;
}

function updateSummary(s) {
    const total = (s.paid || 0) + (s.unpaid || 0);
    const pct = total > 0 ? Math.round((s.paid || 0) / total * 100) : 0;

    document.getElementById('sumTotalRevenue').textContent = total;
    document.getElementById('sumPaid').textContent = s.paid || 0;
    document.getElementById('sumUnpaid').textContent = s.unpaid || 0;
    document.getElementById('sumCollected').textContent = formatCurrency(s.collected || 0);
    document.getElementById('sumPaidPct').textContent = `${pct}% lunas`;
    document.getElementById('sumUnpaidPct').textContent = `${100 - pct}% perlu ditagih`;
    document.getElementById('paymentBar').style.width = `${pct}%`;
}

function renderTable(rows) {
    const tbody = document.getElementById('billingTableBody');
    if (!rows.length) {
        tbody.innerHTML = `<tr><td colspan="8"><div class="empty-state"><i class="fas fa-receipt"></i><h4>Tidak ada data billing</h4><p>Tidak ada tagihan untuk bulan ini</p></div></td></tr>`;
        return;
    }

    tbody.innerHTML = rows.map(r => {
        const isPaid = r.status === 'paid' || r.is_paid == 1;
        const statusBadge = isPaid
            ? `<span class="badge badge-success"><i class="fas fa-check-circle"></i> Lunas</span>`
            : `<span class="badge badge-danger"><i class="fas fa-clock"></i> Belum Bayar</span>`;

        const aksiBtn = isPaid
            ? `<button class="btn btn-outline btn-sm btn-icon-only" onclick="undoPayment('${escHtml(r.username)}','${r.id}')" title="Batalkan pembayaran"><i class="fas fa-undo"></i></button> 
               <button class="btn btn-primary btn-sm btn-icon-only" onclick="openInvoice('${escHtml(r.username)}','${r.amount||r.harga||0}','${escHtml(r.profile||'-')}','${r.paid_at ? formatDate(r.paid_at) : formatDate(new Date())}','${MONTHS_ID[currentMonth-1]} ${currentYear}')" title="Cetak Struk"><i class="fas fa-print"></i></button>`
            : `<button class="btn btn-success btn-sm" onclick="openPaymentModal('${escHtml(r.username)}','${r.id}','${r.amount||r.harga||0}')"><i class="fas fa-check"></i> Bayar</button>`;

        return `<tr>
            <td><strong class="fs-13">${escHtml(r.username)}</strong></td>
            <td>${escHtml(r.nama || '—')}</td>
            <td><span class="badge badge-primary">${escHtml(r.profile || '—')}</span></td>
            <td>${r.tanggal_tagihan ? `Tgl ${r.tanggal_tagihan}` : '—'}</td>
            <td><span class="bill-amount">${formatCurrency(r.amount || r.harga || 0)}</span></td>
            <td>${statusBadge}</td>
            <td class="text-muted fs-12">${r.paid_at ? formatDate(r.paid_at) : '—'}</td>
            <td><div class="action-btns">${aksiBtn}</div></td>
        </tr>`;
    }).join('');
}

function renderPagination(total, page, perPage) {
    totalPages = Math.ceil(total / perPage);
    const start = (page-1)*perPage+1, end = Math.min(page*perPage, total);
    document.getElementById('paginationInfo').textContent = `Menampilkan ${start}–${end} dari ${total} tagihan`;
    const ctrl = document.getElementById('paginationControls');
    let html = `<button class="page-btn" onclick="goPage(${page-1})" ${page<=1?'disabled':''}><i class="fas fa-chevron-left"></i></button>`;
    for (let i = Math.max(1,page-2); i <= Math.min(totalPages,page+2); i++) html += `<button class="page-btn ${i===page?'active':''}" onclick="goPage(${i})">${i}</button>`;
    html += `<button class="page-btn" onclick="goPage(${page+1})" ${page>=totalPages?'disabled':''}><i class="fas fa-chevron-right"></i></button>`;
    ctrl.innerHTML = html;
}

function goPage(p) { if (p>=1 && p<=totalPages) { currentPage=p; loadBilling(); } }

async function loadProfiles() {
    try {
        const r = typeof getActiveRouter === 'function' ? getActiveRouter() : null;
        const router_id = r ? (r.software_id || '') : '';
        const res = await fetch(`../../api/profile_pricing_operations.php?action=list&router_id=${router_id}`);
        const data = await res.json();
        if (data.success && data.data) {
            const opts = data.data.map(p => `<option value="${escHtml(p.name)}">${escHtml(p.name)}</option>`).join('');
            document.getElementById('filterProfile').innerHTML = `<option value="">Semua Profile</option>${opts}`;
        }
    } catch(e) {}
}

function openPaymentModal(username, id, amount) {
    paymentTarget = { username, id };
    document.getElementById('pmUsername').value = username;
    document.getElementById('pmAmount').value = amount;
    document.getElementById('pmDate').value = new Date().toISOString().substr(0,10);
    document.getElementById('pmNote').value = '';
    document.getElementById('paymentModalTitle').textContent = `Bayar Tagihan — ${username}`;
    openModal('paymentModal');
}

async function savePayment() {
    if (!paymentTarget) return;
    const btn = document.getElementById('savePaymentBtn');
    btn.disabled = true;
    btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Menyimpan...';

    try {
        const r = typeof getActiveRouter === 'function' ? getActiveRouter() : null;
        const payload = {
            action: 'mark_paid',
            router_id: r ? (r.software_id || '') : '',
            username: paymentTarget.username,
            payment_id: paymentTarget.id,
            amount: document.getElementById('pmAmount').value,
            paid_date: document.getElementById('pmDate').value,
            method: document.getElementById('pmMethod').value,
            note: document.getElementById('pmNote').value,
            month: currentMonth,
            year: currentYear
        };

        const res = await fetch('../../api/payment_operations.php', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        const data = await res.json();

        if (data.success) {
            showToast('Berhasil', `Pembayaran ${paymentTarget.username} dicatat`, 'success');
            closeModal('paymentModal');
            loadBilling();
        } else {
            showToast('Gagal', data.message || 'Gagal mencatat pembayaran', 'error');
        }
    } catch(e) {
        showToast('Error', 'Tidak dapat terhubung ke server', 'error');
    } finally {
        btn.disabled = false;
        btn.innerHTML = '<i class="fas fa-check"></i> Konfirmasi Bayar';
        paymentTarget = null;
    }
}

async function undoPayment(username, id) {
    if (!confirm(`Batalkan pembayaran ${username}?`)) return;
    try {
        const r = typeof getActiveRouter === 'function' ? getActiveRouter() : null;
        const res = await fetch('../../api/payment_operations.php', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action: 'mark_unpaid', username, payment_id: id, month: currentMonth, year: currentYear, router_id: r ? (r.software_id || '') : '' })
        });
        const data = await res.json();
        if (data.success) {
            showToast('Berhasil', 'Pembayaran dibatalkan', 'success');
            loadBilling();
        } else {
            showToast('Gagal', data.message, 'error');
        }
    } catch(e) {
        showToast('Error', 'Tidak dapat terhubung ke server', 'error');
    }
}

function exportBilling() {
    const r = typeof getActiveRouter === 'function' ? getActiveRouter() : null;
    const params = new URLSearchParams({ month: currentMonth, year: currentYear, format: 'csv', search: document.getElementById('searchInput').value, router_id: r ? (r.software_id || '') : '' });
    window.open(`../../api/payment_operations.php?action=export&${params}`, '_blank');
    showToast('Export', 'Mengunduh laporan billing...', 'info');
}

function openModal(id) { document.getElementById(id).classList.add('show'); }
function closeModal(id) { document.getElementById(id).classList.remove('show'); }
document.addEventListener('click', e => { if (e.target.classList.contains('modal-overlay')) closeModal(e.target.id); });

function formatCurrency(n) {
    return new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', minimumFractionDigits: 0 }).format(n || 0);
}
function formatDate(d) { return new Date(d).toLocaleDateString('id-ID', { day:'numeric', month:'short', year:'numeric' }); }
function escHtml(s) { return String(s||'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;'); }

function openInvoice(username, amount, profile, paidDate, monthStr) {
    const invHtml = `
<div style="text-align:center; border-bottom:1px dashed #ccc; padding-bottom:12px; margin-bottom:12px;">
    <h3 style="margin:0; font-size:18px;">PPPoE INVOICE</h3>
    <small style="color:#666;">Terima kasih atas pembayaran Anda</small>
</div>
<div style="margin-bottom:8px;"><strong>Pelanggan:</strong><div style="float:right;">${escHtml(username)}</div><div style="clear:both;"></div></div>
<div style="margin-bottom:8px;"><strong>Paket:</strong><div style="float:right;">${escHtml(profile)}</div><div style="clear:both;"></div></div>
<div style="margin-bottom:8px;"><strong>Periode:</strong><div style="float:right;">${escHtml(monthStr)}</div><div style="clear:both;"></div></div>
<div style="margin-bottom:8px;"><strong>Tanggal:</strong><div style="float:right;">${escHtml(paidDate)}</div><div style="clear:both;"></div></div>
<div style="margin-bottom:8px;"><strong>Status:</strong><div style="float:right;">LUNAS</div><div style="clear:both;"></div></div>
<div style="border-top:1px dashed #ccc; padding-top:12px; margin-top:12px; font-weight:bold; font-size:16px;">
    <strong>TOTAL:</strong><div style="float:right;">${formatCurrency(amount)}</div><div style="clear:both;"></div>
</div>
    `;
    document.getElementById('invoiceBody').innerHTML = invHtml;
    openModal('invoiceModal');
}

function printInvoice() {
    const content = document.getElementById('invoiceBody').innerHTML;
    const printWindow = window.open('', '_blank', 'width=400,height=600');
    printWindow.document.write('<html><head><title>Print Struk</title>');
    printWindow.document.write('<style>body{font-family:monospace; padding:10px 20px;} @media print { body { padding: 0; } }</style></head><body>');
    printWindow.document.write(content);
    printWindow.document.write('</body></html>');
    printWindow.document.close();
    printWindow.focus();
    setTimeout(() => { printWindow.print(); printWindow.close(); }, 250);
}

window.addEventListener('DOMContentLoaded', init);