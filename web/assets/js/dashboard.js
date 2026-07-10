// ===================================
    // AUTH CHECK
    // ===================================
    function checkAuth() {
        const userInfo = sessionStorage.getItem('userInfo');
        // Uncomment baris di bawah jika sudah deploy dengan PHP
        // if (!userInfo) { window.location.href = 'login.html'; return; }

        try {
            const user = JSON.parse(userInfo || '{"username":"Admin","full_name":"Administrator","role":"admin"}');
            document.getElementById('sidebarUserName').textContent = user.full_name || user.username || 'Admin';
            document.getElementById('topbarUserName').textContent = user.full_name || user.username || 'Admin';
            document.getElementById('sidebarUserRole').textContent = user.role === 'admin' ? 'Administrator' : 'Operator';
            const letter = (user.full_name || user.username || 'A').charAt(0).toUpperCase();
            document.getElementById('userAvatarLetter').textContent = letter;
        } catch(e) {}
    }

    // ===================================
    // THEME
    // ===================================
    function toggleTheme() {
        const body = document.body;
        const icon = document.getElementById('themeIcon');
        body.classList.toggle('light-theme');
        const isLight = body.classList.contains('light-theme');
        icon.className = isLight ? 'fas fa-sun' : 'fas fa-moon';
        localStorage.setItem('theme', isLight ? 'light' : 'dark');
    }

    function loadTheme() {
        if (localStorage.getItem('theme') === 'light') {
            document.body.classList.add('light-theme');
            document.getElementById('themeIcon').className = 'fas fa-sun';
        }
    }

    // ===================================
    // SIDEBAR
    // ===================================
    function toggleSidebar() {
        document.getElementById('sidebar').classList.toggle('show');
    }

    document.addEventListener('click', (e) => {
        const sidebar = document.getElementById('sidebar');
        if (window.innerWidth <= 768 && !sidebar.contains(e.target) && !e.target.closest('.mobile-menu-toggle')) {
            sidebar.classList.remove('show');
        }
    });

    // ===================================
    // LOGOUT
    // ===================================
    async function logout() {
        if (!confirm('Yakin ingin logout?')) return;
        try {
            await fetch('api/auth/logout.php', { method: 'POST' });
        } catch(e) {}
        sessionStorage.clear();
        window.location.href = 'login.html';
    }

    // ===================================
    // TOAST
    // ===================================
    function showToast(title, message, type = 'info') {
        const icons = { success: 'fa-check-circle', error: 'fa-times-circle', warning: 'fa-exclamation-triangle', info: 'fa-info-circle' };
        const toast = document.createElement('div');
        toast.className = `toast ${type}`;
        toast.innerHTML = `
            <i class="fas ${icons[type]} toast-icon"></i>
            <div class="toast-content">
                <div class="toast-title">${title}</div>
                ${message ? `<div class="toast-message">${message}</div>` : ''}
            </div>
            <button class="toast-close" onclick="this.parentElement.remove()"><i class="fas fa-times"></i></button>
        `;
        document.getElementById('toastContainer').appendChild(toast);
        setTimeout(() => toast.remove(), 4000);
    }

    // ===================================
    // DASHBOARD DATA
    // ===================================
    function formatNumber(n) {
        return new Intl.NumberFormat('id-ID').format(n || 0);
    }

    function formatCurrency(n) {
        return new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', minimumFractionDigits: 0 }).format(n || 0);
    }

    async function loadDashboardStats() {
        try {
            const sid = await (typeof getActiveSoftwareId === 'function' ? getActiveSoftwareId() : Promise.resolve(''));
            const params = new URLSearchParams({ router_id: sid || '' });
            const response = await fetch(`api/dashboard_stats.php?${params}`);
            const data = await response.json();

            if (data.success) {
                const d = data.data;
                // Ambil data Real-time Mikrotik
                const r = typeof getActiveRouter === 'function' ? getActiveRouter() : null;
                let realOnline = 0, realOffline = 0, realDisabled = 0;
                if (r) {
                    const p1 = new URLSearchParams({ host: r.host, port: r.port||8728, user: r.username||'admin', pass: r.password||'', cmd: 'ppp_active' });
                    const p2 = new URLSearchParams({ host: r.host, port: r.port||8728, user: r.username||'admin', pass: r.password||'', cmd: 'ppp_secret' });
                    try {
                        const [res1, res2] = await Promise.all([
                            fetch('api/mikrotik_live.php?'+p1).then(o=>o.json()),
                            fetch('api/mikrotik_live.php?'+p2).then(o=>o.json())
                        ]);
                        if(res1.success && res1.data) realOnline = res1.data.length;
                        if(res2.success && res2.data) {
                            realDisabled = res2.data.filter(s => s.disabled === 'true' || s.disabled === true).length;
                            realOffline = res2.data.length - realOnline;
                            if(realOffline < 0) realOffline = 0;
                            d.total_users = res2.data.length; // Override SQL Users
                        }
                    } catch(e) {}
                }
                
                d.online_users = realOnline;
                const pct = d.total_users > 0 ? Math.round((d.online_users / d.total_users) * 100) : 0;
                
                document.getElementById('valTotalUsers').textContent = formatNumber(d.total_users);
                document.getElementById('valOnlineUsers').textContent = formatNumber(d.online_users);
                document.getElementById('valRevenue').textContent = formatCurrency(d.revenue);
                document.getElementById('valUnpaid').textContent = formatNumber(d.pending_payments);

                // Update badges in sidebar if elements exist
                const bdgUsr = document.getElementById('badge-users');
                const bdgOnl = document.getElementById('badge-online');
                const bdgUnp = document.getElementById('badge-unpaid');
                if(bdgUsr) bdgUsr.textContent = formatNumber(d.total_users);
                if(bdgOnl) bdgOnl.textContent = formatNumber(d.online_users);

                if (bdgUnp && d.pending_payments > 0) {
                    bdgUnp.textContent = d.pending_payments;
                    bdgUnp.style.display = '';
                }

                // Change indicators
                document.getElementById('chgOnlineUsers').innerHTML = `<i class="fas fa-signal"></i> ${pct}% dari total`;
                document.getElementById('chgOnlineUsers').className = 'stat-change ' + (pct > 50 ? 'positive' : 'neutral');
                document.getElementById('chgRevenue').innerHTML = `<i class="fas fa-calendar"></i> Bulan ini`;
                document.getElementById('chgRevenue').className = 'stat-change positive';
                document.getElementById('chgTotalUsers').innerHTML = `<i class="fas fa-server"></i> Sinkron Mikrotik`;
                document.getElementById('chgTotalUsers').className = 'stat-change positive';
                document.getElementById('chgUnpaid').innerHTML = `<i class="fas fa-clock"></i> Perlu ditagih`;
                document.getElementById('chgUnpaid').className = `stat-change ${d.pending_payments > 0 ? 'negative' : 'positive'}`;

                // Update status chart
                updateStatusChart(realOnline, realOffline, realDisabled);
                
                // Update Traffic Chart if function exists
                if(typeof updateTrafficChart === 'function' && d.traffic_data) {
                    updateTrafficChart(d.traffic_data);
                }
            } else {
                useDemoStats();
            }
        } catch(e) {
            console.error(e);
            useDemoStats();
        }
    }

    function useDemoStats() {
        document.getElementById('valTotalUsers').textContent = '—';
        document.getElementById('valOnlineUsers').textContent = '—';
        document.getElementById('valRevenue').textContent = '—';
        document.getElementById('valUnpaid').textContent = '—';
        ['chgTotalUsers','chgOnlineUsers','chgRevenue','chgUnpaid'].forEach(id => {
            document.getElementById(id).innerHTML = '<i class="fas fa-exclamation-circle"></i> Tidak terhubung ke API';
            document.getElementById(id).className = 'stat-change neutral';
        });
    }

    async function loadRecentActivity() {
        try {
            const r = typeof getActiveRouter === 'function' ? getActiveRouter() : null;
            if (!r) throw new Error('No router selected');
            
            const params = new URLSearchParams({ host: r.host, port: r.port||8728, user: r.username||'admin', pass: r.password||'', cmd: 'log' });
            const response = await fetch('api/mikrotik_live.php?' + params);
            const data = await response.json();
            const el = document.getElementById('activityList');

            if (data.success && data.data && data.data.length > 0) {
                // Ambil 6 log terbaru, karena mikrotik return oldest first
                const recentLogs = data.data.slice(-6).reverse();
                
                el.innerHTML = recentLogs.map(log => {
                    const msg = log.message || '';
                    const topic = log.topics || '';
                    
                    let icon = 'fa-info-circle blue';
                    if(topic.includes('error') || topic.includes('critical')) icon = 'fa-times-circle red';
                    else if(topic.includes('warning')) icon = 'fa-exclamation-triangle orange';
                    else if(topic.includes('pppoe') || topic.includes('ppp') || msg.includes('logged in')) icon = 'fa-network-wired green';
                    else if(msg.includes('logged out') || msg.includes('disconnected')) icon = 'fa-plug gray';
                    else if(topic.includes('system')) icon = 'fa-cog gray';
                    
                    const iconParts = icon.split(' ');
                    
                    return `
                    <div class="activity-item">
                        <div class="activity-icon ${iconParts[1] || 'blue'}">
                            <i class="fas ${iconParts[0]}"></i>
                        </div>
                        <div>
                            <div class="activity-text">${escHtml(msg)}</div>
                            <div class="activity-time"><i class="fas fa-clock"></i> ${escHtml(log.time || 'Baru saja')}</div>
                        </div>
                    </div>`;
                }).join('');
            } else {
                el.innerHTML = `
                <div class="activity-item">
                    <div class="activity-icon blue"><i class="fas fa-check-circle"></i></div>
                    <div>
                        <div class="activity-text">Log Mikrotik kosong</div>
                        <div class="activity-time">Sekarang</div>
                    </div>
                </div>`;
            }
        } catch(e) {
            document.getElementById('activityList').innerHTML = `
            <div class="empty-state" style="padding:30px">
                <i class="fas fa-plug" style="font-size:30px"></i>
                <p>Tidak dapat memuat log dari Mikrotik</p>
            </div>`;
        }
    }

    // ===================================
    // SYNC DATA
    // ===================================
    async function syncData() {
        showToast('Sinkronisasi', 'Memulai sinkronisasi data...', 'info');
        try {
            const sid = typeof getActiveSoftwareId === 'function' ? await getActiveSoftwareId() : '';
            const res = await fetch('../api/sync_ppp_to_db.php?router_id=' + encodeURIComponent(sid || ''));
            const data = await res.json();
            if (data.success) {
                showToast('Berhasil', 'Data berhasil disinkronkan!', 'success');
                loadDashboardStats();
            } else {
                showToast('Gagal', data.message || 'Sinkronisasi gagal', 'error');
            }
        } catch(e) {
            showToast('Error', 'Tidak dapat terhubung ke server', 'error');
        }
    }

    // ===================================
    // REFRESH
    // ===================================
    function refreshData() {
        const icon = document.getElementById('refreshIcon');
        icon.style.animation = 'spin 0.5s linear';
        loadDashboardStats();
        loadRecentActivity();
        setTimeout(() => { icon.style.animation = ''; }, 600);
        showToast('Refresh', 'Data diperbarui', 'info');
    }

    // ===================================
    // CHARTS
    // ===================================
    let trafficChart, statusChart;

    function initCharts() {
        // Traffic / Pertumbuhan Chart
        const ctx1 = document.getElementById('trafficChart').getContext('2d');
        const g1 = ctx1.createLinearGradient(0, 0, 0, 280);
        g1.addColorStop(0, 'rgba(79,142,247,0.4)');
        g1.addColorStop(1, 'rgba(79,142,247,0)');

        const g2 = ctx1.createLinearGradient(0, 0, 0, 280);
        g2.addColorStop(0, 'rgba(34,197,94,0.3)');
        g2.addColorStop(1, 'rgba(34,197,94,0)');

        const labels = [];
        for (let i = 6; i >= 0; i--) {
            const d = new Date();
            d.setDate(d.getDate() - i);
            labels.push(d.toLocaleDateString('id-ID', { weekday: 'short', day: 'numeric' }));
        }

        trafficChart = new Chart(ctx1, {
            type: 'line',
            data: {
                labels,
                datasets: [
                    { label: 'Total User', data: [0,0,0,0,0,0,0], borderColor: '#4f8ef7', backgroundColor: g1, tension: 0.4, fill: true, borderWidth: 2, pointRadius: 4, pointBackgroundColor: '#4f8ef7' },
                    { label: 'Online', data: [0,0,0,0,0,0,0], borderColor: '#22c55e', backgroundColor: g2, tension: 0.4, fill: true, borderWidth: 2, pointRadius: 4, pointBackgroundColor: '#22c55e' }
                ]
            },
            options: {
                responsive: true, maintainAspectRatio: false,
                plugins: { legend: { labels: { color: '#94a3b8', font: { size: 12, family: 'Inter' } } } },
                scales: {
                    y: { beginAtZero: true, grid: { color: 'rgba(255,255,255,0.05)' }, ticks: { color: '#64748b' } },
                    x: { grid: { color: 'rgba(255,255,255,0.05)' }, ticks: { color: '#64748b' } }
                }
            }
        });

        // Status Donut Chart
        const ctx2 = document.getElementById('statusChart').getContext('2d');
        statusChart = new Chart(ctx2, {
            type: 'doughnut',
            data: {
                labels: ['Online', 'Offline', 'Disabled'],
                datasets: [{ data: [0, 0, 0], backgroundColor: ['#22c55e', '#f97316', '#ef4444'], borderWidth: 0, hoverOffset: 6 }]
            },
            options: {
                responsive: true, maintainAspectRatio: false,
                cutout: '70%',
                plugins: { legend: { position: 'bottom', labels: { color: '#94a3b8', font: { size: 12, family: 'Inter' }, padding: 16 } } }
            }
        });
    }

    function updateStatusChart(online, offline, disabled) {
        if (statusChart) {
            statusChart.data.datasets[0].data = [online, offline, disabled];
            statusChart.update();
        }
    }

    function updateTrafficChart(trafficData) {
        if (trafficChart && trafficData && trafficData.length > 0) {
            const labels = [];
            const totalUsers = [];
            const onlineUsers = [];
            trafficData.forEach(d => {
                labels.push(d.date);
                totalUsers.push(d.upload);  // treating demo upload as total
                onlineUsers.push(d.download); // treating demo download as online
            });
            trafficChart.data.labels = labels;
            trafficChart.data.datasets[0].data = totalUsers;
            trafficChart.data.datasets[1].data = onlineUsers;
            trafficChart.update();
        }
    }

    // ===================================
    // LIVE MIKROTIK
    // ===================================
    async function loadLiveRouter() {
        const r = typeof getActiveRouter === 'function' ? getActiveRouter() : null;
        if (!r) {
            document.getElementById('liveResourceBody').innerHTML = '<div class="empty-state">Router belum disetel di <a href="settings.html" style="color:var(--primary);">Settings</a>.</div>';
            document.getElementById('liveInterfacesBody').innerHTML = '<div style="padding:20px;text-align:center;color:var(--text-muted);">Belum disetel</div>';
            return;
        }
        
        const icon = document.getElementById('syncResourceIcon');
        if(icon) icon.className = 'fas fa-sync fa-spin';
        
        // 1. Resource
        try {
            const pRes = new URLSearchParams({host: r.host, port: r.port||8728, user: r.username||'admin', pass: r.password||'', cmd: 'resource'});
            const resData = await fetch('api/mikrotik_live.php?' + pRes).then(o=>o.json());
            if(resData.success && resData.data && resData.data[0]) {
                const mk = resData.data[0];
                const memFree = parseInt(mk['free-memory']||0);
                const memTotal = parseInt(mk['total-memory']||0);
                const memUsed = memTotal - memFree;
                const memPct = memTotal > 0 ? Math.round((memUsed/memTotal)*100) : 0;
                
                const hddFree = parseInt(mk['free-hdd-space']||0);
                const hddTotal = parseInt(mk['total-hdd-space']||0);
                const hddUsed = hddTotal - hddFree;
                const hddPct = hddTotal > 0 ? Math.round((hddUsed/hddTotal)*100) : 0;

                document.getElementById('liveResourceBody').innerHTML = `
                <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px;">
                    <div>
                        <div style="margin-bottom:12px;">
                            <div style="display:flex;justify-content:space-between;font-size:12px;margin-bottom:4px;color:var(--text-primary);"><span>CPU Load (${mk['cpu-load']||'0'}%)</span><span>${mk['cpu-count']||'1'} Core</span></div>
                            <div style="width:100%;background:var(--bg-input);border-radius:4px;height:8px;overflow:hidden;">
                                <div style="width:${mk['cpu-load']||0}%;background:var(--primary);height:100%;"></div>
                            </div>
                        </div>
                        <div style="margin-bottom:12px;">
                            <div style="display:flex;justify-content:space-between;font-size:12px;margin-bottom:4px;color:var(--text-primary);"><span>RAM (${memPct}%)</span><span>${formatBytesLong(memFree)} free</span></div>
                            <div style="width:100%;background:var(--bg-input);border-radius:4px;height:8px;overflow:hidden;">
                                <div style="width:${memPct}%;background:var(--success);height:100%;"></div>
                            </div>
                        </div>
                        <div style="margin-bottom:12px;">
                            <div style="display:flex;justify-content:space-between;font-size:12px;margin-bottom:4px;color:var(--text-primary);"><span>Storage (${hddPct}%)</span><span>${formatBytesLong(hddFree)} free</span></div>
                            <div style="width:100%;background:var(--bg-input);border-radius:4px;height:8px;overflow:hidden;">
                                <div style="width:${hddPct}%;background:var(--orange);height:100%;"></div>
                            </div>
                        </div>
                    </div>
                    <div>
                        <div style="font-size:12px;color:var(--text-muted);margin-bottom:8px;font-weight:600;text-transform:uppercase;letter-spacing:0.5px;">Router Info</div>
                        <table style="width:100%;font-size:13px;color:var(--text-primary);border-collapse:collapse;">
                            <tr><td style="padding:5px 0;border-bottom:1px solid var(--border);">Board</td><td style="text-align:right;border-bottom:1px solid var(--border);">${escHtml(mk['board-name']||'—')}</td></tr>
                            <tr><td style="padding:5px 0;border-bottom:1px solid var(--border);">Version</td><td style="text-align:right;border-bottom:1px solid var(--border);">${escHtml(mk['version']||'—')}</td></tr>
                            <tr><td style="padding:5px 0;border-bottom:1px solid var(--border);">Arch</td><td style="text-align:right;border-bottom:1px solid var(--border);">${escHtml(mk['architecture-name']||'—')}</td></tr>
                            <tr><td style="padding:5px 0;border-bottom:1px solid var(--border);">Uptime</td><td style="text-align:right;border-bottom:1px solid var(--border);">${escHtml(mk['uptime']||'—')}</td></tr>
                        </table>
                    </div>
                </div>`;
            } else {
                document.getElementById('liveResourceBody').innerHTML = '<div class="empty-state">Respons kosong atau gagal.</div>';
            }
        } catch(e) {
            document.getElementById('liveResourceBody').innerHTML = '<div class="empty-state">Gagal terhubung ke API lokal (Resource).</div>';
        }

        if(icon) icon.className = 'fas fa-sync';

        // 2. Interfaces
        try {
            const pInt = new URLSearchParams({host: r.host, port: r.port||8728, user: r.username||'admin', pass: r.password||'', cmd: 'interface'});
            const intData = await fetch('api/mikrotik_live.php?' + pInt).then(o=>o.json());
            if(intData.success && intData.data) {
                const tbody = intData.data.map(i => {
                    const isRunning = i.running === 'true' || i['running'] === true;
                    const isDisabled = i.disabled === 'true' || i['disabled'] === true;
                    let dotClass = isDisabled ? 'offline' : (isRunning ? 'online' : 'offline');
                    let dotColor = isDisabled ? '#94a3b8' : (isRunning ? '#22c55e' : '#ef4444');
                    const bIn = formatBytesLong(parseInt(i['rx-byte']||0));
                    const bOut = formatBytesLong(parseInt(i['tx-byte']||0));
                    
                    return `<div style="display:flex;justify-content:space-between;padding:12px 16px;border-bottom:1px solid var(--border);">
                        <div>
                            <div style="font-size:13px;font-weight:600;color:var(--text-primary);"><span style="display:inline-block;width:8px;height:8px;border-radius:50%;background:${dotColor};margin-right:8px;box-shadow:0 0 6px ${dotColor}80"></span>${escHtml(i.name)}</div>
                            <div style="font-size:11px;color:var(--text-muted);margin-top:4px;">Type: ${escHtml(i.type||'—')}</div>
                        </div>
                        <div style="text-align:right;font-size:12px;font-family:monospace;color:var(--text-secondary);">
                            <div style="color:var(--success);margin-bottom:2px;">↓ ${bIn}</div>
                            <div style="color:var(--primary);">↑ ${bOut}</div>
                        </div>
                    </div>`;
                }).join('');
                document.getElementById('liveInterfacesBody').innerHTML = tbody || '<div style="padding:20px;text-align:center;color:var(--text-muted);">Tidak ada interface</div>';
            }
        } catch(e) {}
    }

    function formatBytesLong(b) {
        if(!b) return '0 B';
        const u = ['B','KB','MB','GB','TB'];
        let i = 0;
        while(b>=1024 && i<4){b/=1024;i++;}
        return b.toFixed(1)+' '+u[i];
    }

    function escHtml(s) {
        return String(s||'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
    }

    // ===================================
    // INIT
    // ===================================
    window.addEventListener('DOMContentLoaded', () => {
        loadTheme();
        checkAuth();
        initCharts();
        loadDashboardStats();
        loadRecentActivity();

        // Auto-refresh data database lokal setiap 60 detik
        setInterval(() => {
            loadDashboardStats();
        }, 60000);

        // Auto-refresh data live Mikrotik setiap 1.5 detik (Real-time fast pooling)
        setInterval(() => {
            loadLiveRouter();
        }, 1500);
        
        // Initial call
        loadLiveRouter();
    });

    // Expose globals
    window.toggleSidebar = toggleSidebar;
    window.toggleTheme = toggleTheme;
    window.logout = logout;
    window.refreshData = refreshData;
    window.syncData = syncData;