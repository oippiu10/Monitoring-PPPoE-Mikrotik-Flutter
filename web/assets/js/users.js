// ===================================
      // STATE
      // ===================================
      let currentPage = 1;
      let totalPages = 1;
      let searchTimer = null;
      let globalUsersData = [];
      let currentSortBy = 'username';
      let currentSortOrder = 'asc';
      const perPage = 20;

      // ===================================
      // INIT
      // ===================================
      function initAuth() {
        loadTheme();
        try {
          const u = JSON.parse(sessionStorage.getItem("userInfo") || "{}");
          document.getElementById("sidebarUserName").textContent =
            u.full_name || u.username || "Admin";
          document.getElementById("userAvatarLetter").textContent = (
            u.full_name ||
            u.username ||
            "A"
          )
            .charAt(0)
            .toUpperCase();
        } catch (e) {}
      }

      window.addEventListener("DOMContentLoaded", () => {
        initAuth();
        loadUsers();
        loadProfiles();
      });

      // ===================================
      // THEME & SIDEBAR
      // ===================================
      function loadTheme() {
        if (localStorage.getItem("theme") === "light") {
          document.body.classList.add("light-theme");
          document.getElementById("themeIcon").className = "fas fa-sun";
        }
      }
      function toggleTheme() {
        document.body.classList.toggle("light-theme");
        const isLight = document.body.classList.contains("light-theme");
        document.getElementById("themeIcon").className = isLight
          ? "fas fa-sun"
          : "fas fa-moon";
        localStorage.setItem("theme", isLight ? "light" : "dark");
      }
      function toggleSidebar() {
        document.getElementById("sidebar").classList.toggle("show");
      }
      document.addEventListener("click", (e) => {
        if (
          window.innerWidth <= 768 &&
          !document.getElementById("sidebar").contains(e.target) &&
          !e.target.closest(".mobile-menu-toggle")
        )
          document.getElementById("sidebar").classList.remove("show");
      });
      async function logout() {
        if (!confirm("Yakin logout?")) return;
        try {
          await fetch("api/auth/logout.php", { method: "POST" });
        } catch (e) {}
        sessionStorage.clear();
        window.location.href = "login.html";
      }

      // ===================================
      // TOAST
      // ===================================
      function showToast(title, message, type = "info") {
        const icons = {
          success: "fa-check-circle",
          error: "fa-times-circle",
          warning: "fa-exclamation-triangle",
          info: "fa-info-circle",
        };
        const t = document.createElement("div");
        t.className = `toast ${type}`;
        t.innerHTML = `<i class="fas ${icons[type]} toast-icon"></i><div class="toast-content"><div class="toast-title">${title}</div>${message ? `<div class="toast-message">${message}</div>` : ""}</div><button class="toast-close" onclick="this.parentElement.remove()"><i class="fas fa-times"></i></button>`;
        document.getElementById("toastContainer").appendChild(t);
        setTimeout(() => t.remove(), 4000);
      }

      // ===================================
      // LOAD USERS
      // ===================================
      function onSearch() {
        clearTimeout(searchTimer);
        searchTimer = setTimeout(() => {
          currentPage = 1;
          loadUsers();
        }, 400);
      }

      async function loadUsers() {
        const search = document.getElementById("searchInput").value;
        const status = document.getElementById("filterStatus").value;
        const profile = document.getElementById("filterProfile").value;
        const odpElement = document.getElementById("filterOdp");
        const odp = odpElement ? odpElement.value : '';
        const sid = await (typeof getActiveSoftwareId === 'function' ? getActiveSoftwareId() : Promise.resolve(''));

        const tbody = document.getElementById("usersTableBody");
        tbody.innerHTML = `<tr><td colspan="8" style="padding:0;">
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
          const params = new URLSearchParams({
            page: currentPage,
            per_page: perPage,
            search,
            status,
            profile,
            odp,
            sort_by: currentSortBy,
            sort_order: currentSortOrder,
            router_id: sid || ''
          });
          const r = typeof getActiveRouter === 'function' ? getActiveRouter() : null;
          if (r) {
            params.append('router_host', r.host || '');
            params.append('router_port', r.port || 8728);
            params.append('router_user', r.username || 'admin');
            params.append('router_pass', r.password || '');
          }
          const res = await fetch(`api/get_all_users_paginated.php?${params}`);
          const data = await res.json();

          if (data.success && data.data) {
            globalUsersData = data.data;
            renderTable(data.data);
            renderPagination(data.total, data.page, data.per_page);
            updateSummary(data);
            
            // Render ODPs
            if (data.odps && odpElement) {
                const currentOdpVal = odpElement.value;
                odpElement.innerHTML = `<option value="">Semua ODP</option>` + data.odps.map(o => `<option value="${escHtml(o)}"${currentOdpVal===o?' selected':''}>${escHtml(o)}</option>`).join("");
            }
          } else {
            tbody.innerHTML = `<tr><td colspan="6"><div class="empty-state"><i class="fas fa-users"></i><h4>Tidak ada data</h4><p>${data.message || "Tidak dapat memuat pengguna"}</p></div></td></tr>`;
          }
        } catch (e) {
          tbody.innerHTML = `<tr><td colspan="6"><div class="empty-state"><i class="fas fa-plug"></i><h4>Koneksi gagal</h4><p>Pastikan server PHP dan database berjalan</p></div></td></tr>`;
        }
      }

      function updateSummary(data) {
        document.getElementById("summTotal").textContent = data.total_all || data.total || 0;
        document.getElementById("summActive").textContent = data.active || 0;
        document.getElementById("summDisabled").textContent =
          data.disabled || 0;
        document.getElementById("summUnpaid").textContent = data.unpaid || 0;
      }

      function renderTable(users) {
        const tbody = document.getElementById("usersTableBody");
        if (!users || users.length === 0) {
          tbody.innerHTML = `<tr><td colspan="6"><div class="empty-state"><i class="fas fa-users"></i><h4>Tidak ada user</h4><p>Coba ubah filter pencarian</p></div></td></tr>`;
          return;
        }

        tbody.innerHTML = users
          .map((u, index) => {
            const statusBadge =
              u.disabled === "yes"
                ? `<span class="badge badge-danger"><i class="fas fa-ban"></i> Disabled</span>`
                : `<span class="badge badge-success"><i class="fas fa-check-circle"></i> Aktif</span>`;

            const avatar = (u.nama || u.username || "U")
              .charAt(0)
              .toUpperCase();
            const avatarColor = stringToColor(u.username || "");

            return `
        <tr>
            <td data-label="Username">
                <div class="user-name-cell">
                    <div class="user-avatar" style="background:${avatarColor}">${avatar}</div>
                    <div class="user-info-cell">
                        <div class="username" style="display:flex;align-items:center;gap:6px;text-align:left;">${escHtml(u.username)} ${statusBadge}</div>
                        <div class="service" style="text-align:left;">${escHtml(u.service || "ppp")}</div>
                    </div>
                </div>
            </td>
            <td data-label="Profile"><span class="badge badge-primary">${escHtml(u.profile || "—")}</span></td>
            <td data-label="WA">${escHtml(u.wa || "—")}</td>
            <td data-label="Redaman">${escHtml(u.redaman || "—")}</td>
            <td data-label="Aksi" style="text-align:right">
                <button class="btn btn-outline btn-sm" onclick="viewDetail(${index})"><i class="fas fa-eye"></i> Detail</button>
            </td>
        </tr>`;
          })
          .join("");
      }

      function renderPagination(total, page, perPage) {
        totalPages = Math.ceil(total / perPage);
        currentPage = page;

        const start = (page - 1) * perPage + 1;
        const end = Math.min(page * perPage, total);
        document.getElementById("paginationInfo").textContent =
          `Menampilkan ${start}–${end} dari ${total} user`;

        const ctrl = document.getElementById("paginationControls");
        let html = `<button class="page-btn" onclick="goPage(${page - 1})" ${page <= 1 ? "disabled" : ""}><i class="fas fa-chevron-left"></i></button>`;

        const from = Math.max(1, page - 2);
        const to = Math.min(totalPages, page + 2);
        if (from > 1)
          html += `<button class="page-btn" onclick="goPage(1)">1</button>${from > 2 ? '<span style="padding:0 4px;color:var(--text-muted)">…</span>' : ""}`;
        for (let i = from; i <= to; i++)
          html += `<button class="page-btn ${i === page ? "active" : ""}" onclick="goPage(${i})">${i}</button>`;
        if (to < totalPages)
          html += `${to < totalPages - 1 ? '<span style="padding:0 4px;color:var(--text-muted)">…</span>' : ""}<button class="page-btn" onclick="goPage(${totalPages})">${totalPages}</button>`;

        html += `<button class="page-btn" onclick="goPage(${page + 1})" ${page >= totalPages ? "disabled" : ""}><i class="fas fa-chevron-right"></i></button>`;
        ctrl.innerHTML = html;
      }

      function goPage(p) {
        if (p < 1 || p > totalPages) return;
        currentPage = p;
        loadUsers();
      }

      // ===================================
      // MODAL UX
      // ===================================
      function viewDetail(index) {
          const u = globalUsersData[index];
          if(!u) return;

          const avatar = (u.username || "U").substring(0, 2).toUpperCase();
          const avatarColor = stringToColor(u.username || "");
          const statusBadge = u.status === 'online' ? '<span class="badge badge-success"><i class="fas fa-wifi"></i> Online</span>' : '<span class="badge badge-danger"><i class="fas fa-plug"></i> Offline</span>';

          let html = `
          <div style="display:flex; align-items:center; gap:16px; margin-bottom:24px; padding:20px; background:linear-gradient(135deg, rgba(255,255,255,0.05), rgba(0,0,0,0.15)), var(--bg-card); border-radius:12px; box-shadow:0 4px 15px rgba(0,0,0,0.3); border:1px solid var(--border);">
              <div style="width:64px; height:64px; border-radius:50%; background:${avatarColor}; display:flex; align-items:center; justify-content:center; color:#fff; font-size:24px; font-weight:bold; box-shadow:0 4px 10px rgba(0,0,0,0.4);">${avatar}</div>
              <div style="flex:1;">
                  <h2 style="margin:0 0 6px 0; font-size:20px; color:var(--text-primary); display:flex; align-items:center; gap:8px;">${escHtml(u.username)} ${statusBadge}</h2>
                  <p style="margin:0; color:var(--text-muted); font-size:13px;">
                      UID: <strong style="color:var(--text-primary);">${escHtml(u.id||'—')}</strong> &nbsp;&bull;&nbsp; 
                      <i class="fas fa-box" style="color:var(--primary);"></i> Paket: <strong style="color:var(--primary);">${escHtml(u.profile || '—')}</strong>
                  </p>
              </div>
          </div>
          `;

          const fields = [
              {key: 'password', label: 'Password (Secret)', icon: 'fa-key'},
              {key: 'wa', label: 'WhatsApp', icon: 'fa-whatsapp'},
              {key: 'alamat', label: 'Alamat Tagihan', icon: 'fa-home'},
              {key: 'redaman', label: 'Redaman FO', icon: 'fa-signal'},
              {key: 'tanggal_tagihan', label: 'Jatuh Tempo', icon: 'fa-calendar'},
              {key: 'odp_name', label: 'Info ODP', icon: 'fa-sitemap'},
              {key: 'tanggal_dibuat', label: 'Tgl Pembuatan Berkas', icon: 'fa-clock'}
          ];

          let gridHtml = '<div class="detail-grid" style="display:grid; grid-template-columns:repeat(auto-fit, minmax(200px, 1fr)); gap:16px;">';
          fields.forEach(f => {
              gridHtml += `
              <div class="detail-item" style="background:var(--bg-input); padding:16px; border-radius:10px; border:1px solid var(--border); box-shadow:0 2px 5px rgba(0,0,0,0.05); transition:transform 0.2s;">
                  <div class="detail-label" style="font-size:11px; color:var(--text-muted); margin-bottom:8px; display:flex; align-items:center; gap:6px; text-transform:uppercase; letter-spacing:0.5px;"><i class="fas ${f.icon}"></i> ${f.label}</div>
                  <div class="detail-val" style="font-size:15px; font-weight:600; color:var(--text-primary); word-break:break-all;">${escHtml(u[f.key] || '—')}</div>
              </div>`;
          });
          gridHtml += '</div>';
          
          html += gridHtml;

          // Ekstraksi Maps
          if ((u.lat && u.lng) || u.maps) {
              const mapLink = (u.lat && u.lng) ? `https://www.google.com/maps/search/?api=1&query=${u.lat},${u.lng}` : u.maps;
              html += `
              <div style="margin-top:20px; text-align:center;">
                  <a href="${escHtml(mapLink)}" target="_blank" style="display:inline-flex; align-items:center; justify-content:center; gap:8px; background:linear-gradient(135deg, #e74c3c, #c0392b); color:#fff; padding:12px 24px; border-radius:8px; text-decoration:none; font-weight:600; font-size:14px; box-shadow:0 6px 15px rgba(231, 76, 60, 0.4); transition:all 0.2s; width:100%;">
                      <i class="fas fa-map-marked-alt" style="font-size:16px;"></i> Buka Koordinat Lokasi di Google Maps
                  </a>
              </div>`;
          }

          document.getElementById('modalTitle').textContent = `Profil Pelanggan`;
          document.getElementById('modalBody').innerHTML = html;
          document.getElementById('detailModal').classList.add('active');
      }

      function closeModal(id) {
          if (id) {
              const m = document.getElementById(id);
              if (m) m.style.display = 'none';
          } else {
              const m = document.getElementById('detailModal');
              if(m) m.classList.remove('active');
          }
      }

      // ===================================
      // BULK IMPORT
      // ===================================
      function openImportModal() {
          const fi = document.getElementById('importFile');
          if(fi) fi.value = '';
          const m = document.getElementById('importModal');
          if (m) m.style.display = 'flex';
      }

      function downloadCsvTemplate() {
          const csvContent = "username,password,profile,wa,alamat\nuserbaru1,123456,Paket 100k,628xxx,Jalan Sudirman\nuserbaru2,rahasia,Paket 165k,,";
          const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
          const link = document.createElement("a");
          link.href = URL.createObjectURL(blob);
          link.download = "Template_Import_Users.csv";
          link.click();
      }

      async function processImport() {
          const fileInput = document.getElementById('importFile');
          if (!fileInput || !fileInput.files || fileInput.files.length === 0) {
              showToast('Error', 'Silakan pilih file CSV terlebih dahulu', 'error');
              return;
          }

          const btn = document.getElementById('btnProcessImport');
          btn.disabled = true;
          btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Mengunggah...';

          const r = typeof getActiveRouter === 'function' ? getActiveRouter() : null;
          const router_id = r ? (r.software_id || '') : '';

          const formData = new FormData();
          formData.append('csv_file', fileInput.files[0]);
          formData.append('router_id', router_id);

          try {
              const res = await fetch('api/import_users.php', {
                  method: 'POST',
                  body: formData
              });
              
              let data;
              try {
                  data = await res.json();
              } catch(jsonErr) {
                  showToast('Fatal Server Error', 'Respon server tidak terbaca (Kemungkinan Fatal Exception).', 'error');
                  return;
              }
              
              if (data.success) {
                  showToast('Sukses', data.message, 'success');
                  closeModal('importModal');
                  loadUsers();
              } else {
                  showToast('Gagal Impor', data.message || 'Gagal import, Cek struktur file CSV Anda', 'error');
                  alert("INFORMASI ERROR DB:\n" + (data.message || 'Error internal backend.'));
              }
          } catch (e) {
              showToast('Error', 'Gagal terhubung ke server Backend', 'error');
              console.error(e);
          } finally {
              btn.disabled = false;
              btn.innerHTML = '<i class="fas fa-upload"></i> Upload & Import';
          }
      }

      // ===================================
      // SORTING
      // ===================================
      function toggleSort(field) {
          if (currentSortBy === field) {
              currentSortOrder = currentSortOrder === 'asc' ? 'desc' : 'asc';
          } else {
              currentSortBy = field;
              currentSortOrder = 'asc';
          }
          // Update icons
          document.querySelectorAll('.sort-icon').forEach(i => {
              i.className = 'fas fa-sort sort-icon';
              i.style.opacity = '0.3';
          });
          const activeIcon = document.getElementById('sort-' + field);
          if(activeIcon) {
              activeIcon.className = currentSortOrder === 'asc' ? 'fas fa-sort-up sort-icon' : 'fas fa-sort-down sort-icon';
              activeIcon.style.opacity = '1';
          }
          currentPage = 1;
          loadUsers();
      }

      // ===================================
      // PROFILES
      // ===================================
      async function loadProfiles() {
        try {
          // Ambil profile list dari endpoint users
          const res = await fetch("api/get_all_users_paginated.php?per_page=1");
          const data = await res.json();
          if (data.success && data.profiles) {
            const opts = data.profiles
              .map(
                (p) => `<option value="${escHtml(p)}">${escHtml(p)}</option>`,
              )
              .join("");
            document.getElementById("filterProfile").innerHTML =
              `<option value="">Semua Profile</option>${opts}`;
            document.getElementById("fProfile").innerHTML =
              `<option value="">Pilih Profile</option>${opts}`;
          }
        } catch (e) {}
      }

      // ===================================
      // EXPORT
      // ===================================
      document.addEventListener('click', e => {
          const m = document.getElementById('exportMenu');
          if(m && !e.target.closest('.dropdown')) { m.style.display = 'none'; }
      });

      async function exportData(format = 'csv') {
        const m = document.getElementById('exportMenu');
        if(m) m.style.display = 'none';
        
        const search = document.getElementById("searchInput").value;
        const status = document.getElementById("filterStatus").value;
        const profile = document.getElementById("filterProfile").value;
        const odpElement = document.getElementById("filterOdp");
        const odp = odpElement ? odpElement.value : '';
        const sid = await (typeof getActiveSoftwareId === 'function' ? getActiveSoftwareId() : Promise.resolve(''));
        
        try {
            const btnIcon = document.querySelector('.fa-file-export');
            if(btnIcon) btnIcon.className = 'fas fa-spinner fa-spin';

            const params = new URLSearchParams({ page: 1, per_page: 999999, search, status, profile, odp, router_id: sid || '' });
            const res = await fetch(`api/get_all_users_paginated.php?${params}`);
            const data = await res.json();

            if(btnIcon) btnIcon.className = 'fas fa-file-export';
            
            if(!data.success || !data.data) {
                alert('Gagal mengambil data untuk export');
                return;
            }

            const rows = data.data.map((u, i) => ({
                No: i+1,
                Username: u.username || '-',
                Profile: u.profile || '-',
                Status: u.status || 'offline',
                Disabled: u.disabled === 'yes' ? 'Yes' : 'No',
                WA: u.wa || '-',
                Redaman: u.redaman || '-'
            }));

            const dateStr = new Date().toISOString().split('T')[0];

            if (format === 'csv' || format === 'excel') {
                const worksheet = XLSX.utils.json_to_sheet(rows);
                if (format === 'csv') {
                    const csv = XLSX.utils.sheet_to_csv(worksheet);
                    const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
                    const link = document.createElement("a");
                    link.href = URL.createObjectURL(blob);
                    link.download = `Users_Export_${dateStr}.csv`;
                    link.click();
                } else {
                    const workbook = XLSX.utils.book_new();
                    XLSX.utils.book_append_sheet(workbook, worksheet, "Users");
                    XLSX.writeFile(workbook, `Users_Export_${dateStr}.xlsx`);
                }
            } else if (format === 'pdf') {
                const { jsPDF } = window.jspdf;
                const doc = new jsPDF();
                doc.text("Laporan Data Pelanggan PPPoE", 14, 15);
                doc.setFontSize(10);
                doc.text(`Tanggal Export: ${dateStr}`, 14, 22);

                const tableColumn = ["No", "Username", "Profile", "Status", "WA", "Redaman"];
                const tableRows = [];

                rows.forEach(r => {
                    const rowData = [r.No, r.Username, r.Profile, r.Status + (r.Disabled==='Yes'?' (Dis)':''), r.WA, r.Redaman];
                    tableRows.push(rowData);
                });

                doc.autoTable({
                    startY: 28,
                    head: [tableColumn],
                    body: tableRows,
                    headStyles: { fillColor: [41, 128, 185] },
                });
                doc.save(`Users_Export_${dateStr}.pdf`);
            }
        } catch(e) {
            alert("Error saat export data");
            console.error(e);
            const btnIcon = document.querySelector('.fa-spinner');
            if(btnIcon) btnIcon.className = 'fas fa-file-export';
        }
      }

      // ===================================
      // HELPERS
      // ===================================
      function escHtml(str) {
        return String(str || "")
          .replace(/&/g, "&amp;")
          .replace(/</g, "&lt;")
          .replace(/>/g, "&gt;")
          .replace(/"/g, "&quot;");
      }

      function stringToColor(str) {
        let hash = 0;
        for (let i = 0; i < str.length; i++)
          hash = str.charCodeAt(i) + ((hash << 5) - hash);
        const colors = [
          "#4f8ef7",
          "#a855f7",
          "#22c55e",
          "#f59e0b",
          "#ef4444",
          "#f97316",
          "#06b6d4",
          "#ec4899",
        ];
        return colors[Math.abs(hash) % colors.length];
      }