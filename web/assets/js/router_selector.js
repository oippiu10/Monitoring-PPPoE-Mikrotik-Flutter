// assets/js/router_selector.js
function initRouterSelector() {
    const routers = JSON.parse(localStorage.getItem('routers') || '[]');
    if(routers.length <= 1) return; // if 0 or 1 router, no need for dropdown
    
    // Create dropdown HTML
    let options = routers.map((r, i) => `<option value="${i}">${r.name || r.host}</option>`).join('');
    
    // Inject into topbar-right as first child
    const topbarRight = document.querySelector('.topbar-right');
    if(!topbarRight) return;
    
    const selectHtml = `
        <div class="router-selector" style="margin-right: 15px; display:flex; align-items:center; gap:8px;">
            <i class="fas fa-server" style="color:var(--primary); font-size:14px;"></i>
            <select id="globalRouterSelect" onchange="changeActiveRouter(this.value)" style="padding: 4px 8px; border-radius: 4px; border: 1px solid var(--border); background: var(--bg-input); color: var(--text-primary); font-size:13px; outline:none; cursor:pointer; min-width:140px; font-weight:600;">
                ${options}
            </select>
        </div>
    `;
    
    topbarRight.insertAdjacentHTML('afterbegin', selectHtml);
    
    const activeIdx = localStorage.getItem('activeRouterIndex') || '0';
    document.getElementById('globalRouterSelect').value = activeIdx;
}

function changeActiveRouter(idx) {
    localStorage.setItem('activeRouterIndex', idx);
    location.reload();
}

// Global helper to replace `routers[0]`
function getActiveRouter() {
    const routers = JSON.parse(localStorage.getItem('routers') || '[]');
    if(routers.length === 0) return null;
    let idx = parseInt(localStorage.getItem('activeRouterIndex') || '0');
    if(idx >= routers.length) idx = 0;
    return routers[idx];
}

async function getActiveSoftwareId() {
    const r = getActiveRouter();
    if (!r) return null;
    if (r.software_id) return r.software_id;
    
    try {
        const p = new URLSearchParams({host: r.host, port: r.port||8728, user: r.username||'admin', pass: r.password||'', cmd: 'license'});
        const res = await fetch('api/mikrotik_live.php?' + p).then(o => o.json());
        if(res.success && res.data && res.data[0] && res.data[0]['software-id']) {
            r.software_id = res.data[0]['software-id'];
            const routers = JSON.parse(localStorage.getItem('routers') || '[]');
            const idx = parseInt(localStorage.getItem('activeRouterIndex') || '0');
            if(routers[idx]) {
                routers[idx].software_id = r.software_id;
                localStorage.setItem('routers', JSON.stringify(routers));
            }
            return r.software_id;
        }
    } catch(e) {}
    return null;
}

document.addEventListener('DOMContentLoaded', initRouterSelector);
