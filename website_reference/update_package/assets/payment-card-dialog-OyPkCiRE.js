import{a as e,n as t,t as n}from"./jsx-runtime-m7G7yzlP.js";import{t as r}from"./useQuery-xsYv6W8o.js";import{t as i}from"./utils--OkM5yWA.js";import{t as a}from"./check-check-BOP7hhS0.js";import{a as o,i as s,n as c,r as l,t as u}from"./select-B9ugumZB.js";import{t as d}from"./loader-circle-s04KhxZY.js";import{t as f}from"./printer-BxEX4nuX.js";import{t as p}from"./refresh-cw-BhFpbNXX.js";import{I as m,X as h}from"./index-BtVsGsbP.js";import{t as g}from"./input-CvTztNF7.js";import{t as _}from"./api-BGWiaYdG.js";import{t as v}from"./router-store-Bnquxf0N.js";import{a as y,o as b,r as x,s as S,t as C}from"./dialog-FTxLAW0D.js";var w=e(t(),1),T=e(n(),1),E=[`Januari`,`Februari`,`Maret`,`April`,`Mei`,`Juni`,`Juli`,`Agustus`,`September`,`Oktober`,`November`,`Desember`],D=e=>new Intl.NumberFormat(`id-ID`,{style:`currency`,currency:`IDR`,maximumFractionDigits:0}).format(e),O=e=>e?e.replace(/[._]/g,` `).replace(/\b\w/g,e=>e.toUpperCase()):``,k=(e,t,n,r)=>{if(e.length===0)return;let i=`<!doctype html><html><head><title>Print Thermal Massal</title><style>
  body{font-family:monospace;margin:0;padding:0;background:#f3f4f6}
  .receipt{width:58mm;margin:20px auto;background:white;padding:10px;box-shadow:0 4px 6px -1px rgb(0 0 0 / .1)}
  .center{text-align:center}.bold{font-weight:bold}.line{border-top:1px dashed #000;margin:10px 0}
  .mb-1{margin-bottom:4px}.mb-2{margin-bottom:8px}.mt-2{margin-top:8px}
  .table{width:100%;font-size:12px;border-collapse:collapse}.table td{padding:2px 0}
  .right{text-align:right}.title{font-size:12px}.page-break{page-break-after:always}
  @media print{body{background:white}.receipt{box-shadow:none;margin:0;padding:0}.no-print{display:none}}
  </style></head><body>`;i+=`<div class="no-print center" style="padding:10px"><button onclick="window.print()" style="padding:8px 16px;background:black;color:white;border-radius:4px;cursor:pointer">Print Thermal (${e.length})</button></div>`,e.forEach((a,o)=>{let s=a.status===`paid`,c=s?`LUNAS`:`BELUM BAYAR`,l=`INV-${n}${String(t).padStart(2,`0`)}-${a.user_id||a.id||a.username}`,u=D(parseFloat(a.harga||a.paid_amount||0)),d=r?.isp_name||`WIFIKU NET`;i+=`
    <div class="receipt ${o<e.length-1?`page-break`:``}">
      <div style="padding:5px;">
        <div class="center bold mb-1" style="font-size:14px">${d}</div>
        <div class="center mb-2">BUKTI PEMBAYARAN</div>
        <div class="line"></div>
        <table class="table">
          <tr><td>No.</td><td class="right">${l}</td></tr>
          <tr><td>Tgl</td><td class="right">${new Date().toISOString().slice(0,10)}</td></tr>
          <tr><td>Pel.</td><td class="right">${O(a.username)}</td></tr>
        </table>
        <div class="line"></div>
        <table class="table">
          <tr><td>Internet WiFi</td><td class="right"></td></tr>
          <tr><td>Bln ${E[t-1]} ${n}</td><td class="right">${u}</td></tr>
          <tr><td class="bold mt-2">TOTAL</td><td class="right bold mt-2">${u}</td></tr>
        </table>
        <div class="center mt-2">
          <div style="display:inline-block;padding:4px 12px;border:2px solid ${s?`#000`:`#666`};font-weight:bold;border-radius:4px;letter-spacing:1px;font-size:14px">${c}</div>
        </div>
        <div class="center" style="font-size:10px;margin-top:10px">Terima kasih atas pembayaran Anda.</div>
      </div>
    </div>`}),i+=`<script>window.onload=()=>window.print();<\/script></body></html>`;let a=window.open(``,`_blank`);a?.document.write(i),a?.document.close()},A=(e,t,n,r)=>{let i=e.status===`paid`,a=i?`LUNAS`:`BELUM BAYAR`,o=`INV-${n}${String(t).padStart(2,`0`)}-${e.user_id||e.id||e.username}`,s=D(parseFloat(e.harga||e.paid_amount||0)),c=`<!doctype html><html><head><title>Print Thermal</title><style>
  body{font-family:monospace;margin:0;padding:0;background:#f3f4f6}
  .receipt{width:58mm;margin:40px auto;background:white;padding:10px;box-shadow:0 4px 6px -1px rgb(0 0 0 / .1)}
  .center{text-align:center}.bold{font-weight:bold}.line{border-top:1px dashed #000;margin:10px 0}
  .mb-1{margin-bottom:4px}.mb-2{margin-bottom:8px}.mt-2{margin-top:8px}
  .table{width:100%;font-size:12px;border-collapse:collapse}.table td{padding:2px 0}
  .right{text-align:right}.title{font-size:12px}
  @media print{body{background:white}.receipt{box-shadow:none;margin:0;padding:0}.no-print{display:none}}
  </style></head><body>
  <div class="receipt">
    <div class="no-print center" style="padding:10px"><button onclick="window.print()" style="padding:8px 16px;background:black;color:white;border-radius:4px;cursor:pointer">Print Thermal</button></div>
    <div style="padding:5px;">
      <div class="center bold mb-1" style="font-size:14px">${r?.isp_name||`WIFIKU NET`}</div>
      <div class="center mb-2">BUKTI PEMBAYARAN</div>
      <div class="line"></div>
      <table class="table">
        <tr><td>No.</td><td class="right">${o}</td></tr>
        <tr><td>Tgl</td><td class="right">${new Date().toISOString().slice(0,10)}</td></tr>
        <tr><td>Pel.</td><td class="right">${O(e.username)}</td></tr>
      </table>
      <div class="line"></div>
      <table class="table">
        <tr><td>Internet WiFi</td><td class="right"></td></tr>
        <tr><td>Bln ${E[t-1]} ${n}</td><td class="right">${s}</td></tr>
        <tr><td class="bold mt-2">TOTAL</td><td class="right bold mt-2">${s}</td></tr>
      </table>
      <div class="center mt-2">
        <div style="display:inline-block;padding:4px 12px;border:2px solid ${i?`#000`:`#666`};font-weight:bold;border-radius:4px;letter-spacing:1px;font-size:14px">${a}</div>
      </div>
      <div class="center" style="font-size:10px;margin-top:10px">Terima kasih atas pembayaran Anda.</div>
    </div>
  </div>
  <script>window.onload=()=>window.print();<\/script>
  </body></html>`,l=window.open(``,`_blank`);l?.document.write(c),l?.document.close()},j=(e,t,n,r)=>{if(e.length===0)return;let i=`<!doctype html><html><head><title>Print Invoice Massal</title><style>
  body{font-family:Arial,sans-serif;margin:0;padding:0;background:#f3f4f6}
  .paper{max-width:760px;margin:40px auto;background:white;padding:48px;border-radius:16px;box-shadow:0 10px 35px rgba(0,0,0,.08)}
  .top{display:flex;justify-content:space-between;gap:24px;border-bottom:2px solid #111827;padding-bottom:24px;margin-bottom:32px}
  h1{margin:0;font-size:32px}.muted{color:#6b7280;font-size:14px}.badge{display:inline-block;padding:8px 16px;border-radius:999px;font-weight:800;font-size:12px}
  .paid{background:#dcfce7;color:#166534}.unpaid{background:#ffedd5;color:#9a3412}
  table{width:100%;border-collapse:collapse;margin-top:32px}td,th{padding:16px;border-bottom:1px solid #e5e7eb;text-align:left}th{font-size:12px;text-transform:uppercase;color:#6b7280}.right{text-align:right}.total{font-size:24px;font-weight:900}.footer{margin-top:48px;font-size:13px;color:#6b7280;text-align:center}.page-break{page-break-after:always}
  @media print{body{background:white}.paper{box-shadow:none;margin:0;border-radius:0;padding:20px}.no-print{display:none}}
  </style></head><body>`;i+=`<div class="no-print" style="text-align:center;padding:20px"><button onclick="window.print()" style="padding:10px 20px;background:#111827;color:white;border-radius:8px;font-weight:bold;cursor:pointer">Print Semua (${e.length} Invoice)</button></div>`,e.forEach((a,o)=>{let s=a.status===`paid`,c=s?`paid`:`unpaid`,l=s?`LUNAS`:`BELUM BAYAR`,u=`INV-${n}${String(t).padStart(2,`0`)}-${a.user_id||a.id||a.username}`,d=D(parseFloat(a.harga||a.paid_amount||0)),f=r?.isp_name||`WIFIKU NET`,p=r?.isp_tagline||`Layanan Internet Cepat & Terpercaya`,m=r?.isp_address||``,h=r?.isp_phone||``,g=r?.isp_email||``,_=r?.isp_logo||``;i+=`
    <div class="paper ${o<e.length-1?`page-break`:``}">
      <div class="top">
        <div style="display:flex; align-items:center; gap:16px;">
          ${_?`<img src="${_}" style="height:60px; max-width:180px; object-fit:contain;" />`:``}
          <div>
            <h1>INVOICE TAGIHAN</h1>
            <div class="muted">No: ${u} &bull; Tgl: ${new Date().toISOString().slice(0,10)}</div>
          </div>
        </div>
        <div style="text-align:right">
          <div class="badge ${c}">${l}</div>
          <div style="margin-top:12px;font-weight:bold;font-size:20px">${f}</div>
          ${p?`<div class="muted" style="font-size:12px;">${p}</div>`:``}
        </div>
      </div>
      
      <div style="display:flex; justify-content:space-between; margin-bottom:32px; gap:20px;">
        <div>
          <div class="muted" style="margin-bottom:4px">Ditagihkan kepada:</div>
          <div style="font-weight:bold;font-size:18px">Saudara/i ${O(a.username)}</div>
          <div class="muted">${a.wa||``}</div>
          <div class="muted" style="font-size:12px; max-width:300px;">${a.alamat||``}</div>
        </div>
        <div style="text-align:right">
          <div class="muted" style="margin-bottom:4px">Dari:</div>
          <div style="font-weight:bold;font-size:16px">${f}</div>
          <div class="muted" style="font-size:12px; max-width:250px;">${m}</div>
          <div class="muted" style="font-size:12px;">Telp: ${h}</div>
          <div class="muted" style="font-size:12px;">Email: ${g}</div>
        </div>
      </div>

      <table>
        <thead>
          <tr><th>Deskripsi Layanan</th><th class="right">Jumlah</th></tr>
        </thead>
        <tbody>
          <tr>
            <td>Layanan Internet WiFi<br><span class="muted">Periode: ${E[t-1]} ${n}</span></td>
            <td class="right" style="font-weight:bold">${d}</td>
          </tr>
          <tr><td colspan="2" style="border-bottom:none;padding-top:32px"></td></tr>
          <tr>
            <td class="right" style="font-size:16px">TOTAL TAGIHAN</td>
            <td class="right total">${d}</td>
          </tr>
        </tbody>
      </table>
      
      <div class="footer">
        Terima kasih telah menggunakan layanan ${f}.<br>
        Simpan invoice ini sebagai bukti pembayaran yang sah.
      </div>
    </div>`}),i+=`<script>window.onload=()=>window.print();<\/script></body></html>`;let a=window.open(``,`_blank`);a?.document.write(i),a?.document.close()},M=(e,t,n,r)=>{let i=`INV-${n}${String(t).padStart(2,`0`)}-${e.user_id||e.id||e.username}`,a=D(parseFloat(e.harga||e.paid_amount||0)),o=e.status===`paid`?`paid`:`unpaid`,s=e.status===`paid`?`LUNAS`:`BELUM BAYAR`,c=r?.isp_name||`WIFIKU NET`,l=r?.isp_tagline||`Layanan Internet Cepat & Terpercaya`,u=r?.isp_address||``,d=r?.isp_phone||``,f=r?.isp_email||``,p=r?.isp_logo||``,m=`<!doctype html><html><head><title>Invoice ${e.username}</title><style>
  body{font-family:Arial,sans-serif;margin:0;padding:0;background:#f3f4f6}
  .paper{max-width:760px;margin:40px auto;background:white;padding:48px;border-radius:16px;box-shadow:0 10px 35px rgba(0,0,0,.08)}
  .top{display:flex;justify-content:space-between;gap:24px;border-bottom:2px solid #111827;padding-bottom:24px;margin-bottom:32px}
  h1{margin:0;font-size:32px}.muted{color:#6b7280;font-size:14px}.badge{display:inline-block;padding:8px 16px;border-radius:999px;font-weight:800;font-size:12px}
  .paid{background:#dcfce7;color:#166534}.unpaid{background:#ffedd5;color:#9a3412}
  table{width:100%;border-collapse:collapse;margin-top:32px}td,th{padding:16px;border-bottom:1px solid #e5e7eb;text-align:left}th{font-size:12px;text-transform:uppercase;color:#6b7280}.right{text-align:right}.total{font-size:24px;font-weight:900}.footer{margin-top:48px;font-size:13px;color:#6b7280;text-align:center}@media print{body{background:white}.paper{box-shadow:none;margin:0;border-radius:0;padding:20px}.no-print{display:none}}
  </style></head><body>
  <div class="no-print" style="text-align:center;padding:20px"><button onclick="window.print()" style="padding:10px 20px;background:#111827;color:white;border-radius:8px;font-weight:bold;cursor:pointer">Print Invoice</button></div>
  <div class="paper">
    <div class="top">
      <div style="display:flex; align-items:center; gap:16px;">
        ${p?`<img src="${p}" style="height:60px; max-width:180px; object-fit:contain;" />`:``}
        <div>
          <h1>INVOICE TAGIHAN</h1>
          <div class="muted">No: ${i} &bull; Tgl: ${new Date().toISOString().slice(0,10)}</div>
        </div>
      </div>
      <div style="text-align:right">
        <div class="badge ${o}">${s}</div>
        <div style="margin-top:12px;font-weight:bold;font-size:20px">${c}</div>
        ${l?`<div class="muted" style="font-size:12px;">${l}</div>`:``}
      </div>
    </div>
    
    <div style="display:flex; justify-content:space-between; margin-bottom:32px; gap:20px;">
      <div>
        <div class="muted" style="margin-bottom:4px">Ditagihkan kepada:</div>
        <div style="font-weight:bold;font-size:18px">Saudara/i ${O(e.username)}</div>
        <div class="muted">${e.wa||``}</div>
        <div class="muted" style="font-size:12px; max-width:300px;">${e.alamat||``}</div>
      </div>
      <div style="text-align:right">
        <div class="muted" style="margin-bottom:4px">Dari:</div>
        <div style="font-weight:bold;font-size:16px">${c}</div>
        <div class="muted" style="font-size:12px; max-width:250px;">${u}</div>
        <div class="muted" style="font-size:12px;">Telp: ${d}</div>
        <div class="muted" style="font-size:12px;">Email: ${f}</div>
      </div>
    </div>

    <table>
      <thead>
        <tr><th>Deskripsi Layanan</th><th class="right">Jumlah</th></tr>
      </thead>
      <tbody>
        <tr>
          <td>Layanan Internet WiFi<br><span class="muted">Periode: ${E[t-1]} ${n}</span></td>
          <td class="right" style="font-weight:bold">${a}</td>
        </tr>
        <tr><td colspan="2" style="border-bottom:none;padding-top:32px"></td></tr>
        <tr>
          <td class="right" style="font-size:16px">TOTAL TAGIHAN</td>
          <td class="right total">${a}</td>
        </tr>
      </tbody>
    </table>
    
    <div class="footer">
      Terima kasih telah menggunakan layanan ${c}.<br>
      Simpan invoice ini sebagai bukti pembayaran yang sah.
    </div>
  </div>
  <script>window.onload=()=>window.print();<\/script>
  </body></html>`,h=window.open(``,`_blank`);h?.document.write(m),h?.document.close()},N=(e,t,n,r,i)=>{let a=i?.isp_name||`WIFIKU NET`,o=i?.isp_logo||``,s=`<!doctype html><html><head><title>Kartu Pembayaran ${e?.username}</title><style>
  body{font-family:Arial,sans-serif;margin:0;padding:0;background:#f3f4f6}
  .paper{max-width:900px;margin:20px auto;background:white;padding:30px;border-radius:8px;box-shadow:0 4px 15px rgba(0,0,0,.05)}
  .header{text-align:center;margin-bottom:20px;border-bottom:2px solid #111827;padding-bottom:15px}
  .header h1{margin:0;font-size:24px;text-transform:uppercase}
  .header p{margin:5px 0 0;color:#4b5563;font-size:14px}
  .info{display:flex;justify-content:space-between;margin-bottom:20px;font-size:14px}
  .info div{line-height:1.5}
  .bold{font-weight:bold}
  table{width:100%;border-collapse:collapse;font-size:13px}
  th,td{border:1px solid #d1d5db;padding:8px 10px}
  th{background:#f3f4f6;text-align:center}
  .right{text-align:right}
  .center{text-align:center}
  .footer{margin-top:30px;font-size:12px;text-align:center;color:#6b7280}
  @media print{body{background:white}.paper{box-shadow:none;margin:0;padding:10px;max-width:100%}.no-print{display:none}}
  </style></head><body>
  <div class="no-print center" style="padding:15px"><button onclick="window.print()" style="padding:10px 20px;background:#111827;color:white;border-radius:6px;font-weight:bold;cursor:pointer">Cetak Kartu</button></div>
  <div class="paper">
    <div class="header">
      ${o?`<img src="${o}" style="height:50px;margin-bottom:10px;" />`:``}
      <h1>KARTU PEMBAYARAN IURAN INTERNET</h1>
      <p>${a}</p>
    </div>
    
    <div class="info">
      <div>
        <span class="bold">Nama Pelanggan:</span> ${O(e?.username)}<br>
        <span class="bold">Alamat:</span> ${e?.alamat||`-`}<br>
        <span class="bold">Paket / Layanan:</span> ${e?.profile||`-`}
      </div>
      <div class="right">
        <span class="bold">Tahun:</span> ${t}<br>
        <span class="bold">Tanggal Cetak:</span> ${new Date().toLocaleDateString(`id-ID`)}
      </div>
    </div>

    <table>
      <thead>
        <tr>
          <th style="width:40px">Bln</th>
          <th>Iuran Bulanan</th>
          <th>Kekurangan Bln Kemarin</th>
          <th>Tagihan Bln Ini</th>
          <th>Jumlah Bayar</th>
          <th>Sisa Tagihan</th>
          <th>Ket</th>
        </tr>
      </thead>
      <tbody>`;n.forEach(e=>{s+=`
        <tr>
          <td class="center bold">${e.bulan.slice(0,3)}</td>
          <td class="right">${D(e.iuran_bulanan)}</td>
          <td class="right">${D(e.kekurangan_kemarin)}</td>
          <td class="right bold">${D(e.tagihan_bulan_ini)}</td>
          <td class="right">${D(e.bayar)}</td>
          <td class="right">${e.sisa_tagihan>0?`-${D(e.sisa_tagihan)}`:D(0)}</td>
          <td>${e.keterangan||`-`}</td>
        </tr>`}),s+=`
      </tbody>
      <tfoot>
        <tr style="background:#f9fafb;font-weight:bold">
          <td class="right">TOTAL:</td>
          <td class="right">${D(r?.total_iuran||0)}</td>
          <td></td>
          <td></td>
          <td class="right">${D(r?.total_bayar||0)}</td>
          <td class="right">${(r?.sisa_akhir||0)>0?`-${D(r?.sisa_akhir)}`:D(0)}</td>
          <td></td>
        </tr>
      </tfoot>
    </table>
    
    <div class="footer">
      Dokumen ini dicetak secara otomatis dari sistem dan sah sebagai catatan pembayaran.
    </div>
  </div>
  <script>window.onload=()=>window.print();<\/script>
  </body></html>`;let c=window.open(``,`_blank`);c?.document.write(s),c?.document.close()};function P({isOpen:e,onClose:t,paidDialog:n,privacyMode:r,onSave:d,isPending:f,fmt:_}){let v=new Date,[E,D]=(0,w.useState)(!1),[O,k]=(0,w.useState)(``),[A,j]=(0,w.useState)(v.toISOString().slice(0,10)),[M,N]=(0,w.useState)(`cash`),[P,F]=(0,w.useState)(``),[I,L]=(0,w.useState)(``),[R,z]=(0,w.useState)(``);if((0,w.useEffect)(()=>{if(n){let e=n.paid_amount||n.harga||0;k(String(e)),j(n.paid_at||v.toISOString().slice(0,10)),N(n.method||`cash`),F(n.note||``),L(``),z(``),D(!1)}},[n,e]),!n)return null;let B=parseFloat(String(n.paid_amount||0))>0;return(0,T.jsx)(C,{open:e,onOpenChange:e=>!e&&t(),children:(0,T.jsxs)(x,{className:`max-w-sm rounded-3xl border shadow-2xl`,children:[(0,T.jsx)(b,{children:(0,T.jsxs)(S,{className:`text-base font-black tracking-tight`,children:[B?`Edit Pembayaran`:`Tandai Lunas`,` — `,n.username]})}),B&&(0,T.jsxs)(`div`,{className:`grid grid-cols-2 gap-1 bg-muted p-1 rounded-lg text-xs font-bold mb-1 select-none border`,children:[(0,T.jsx)(`button`,{type:`button`,onClick:()=>D(!1),className:i(`py-1.5 rounded-md transition-all font-semibold`,E?`text-muted-foreground hover:text-foreground`:`bg-background shadow-xs text-foreground`),children:`Koreksi Total`}),(0,T.jsx)(`button`,{type:`button`,onClick:()=>D(!0),className:i(`py-1.5 rounded-md transition-all font-semibold`,E?`bg-background shadow-xs text-foreground`:`text-muted-foreground hover:text-foreground`),children:`Tambah Angsuran`})]}),(0,T.jsx)(`div`,{className:`space-y-3 py-2`,children:E?(0,T.jsxs)(T.Fragment,{children:[(0,T.jsxs)(`div`,{className:`bg-slate-50 dark:bg-slate-900/60 p-3 rounded-2xl border text-xs space-y-1.5 mb-2`,children:[(0,T.jsxs)(`div`,{className:`flex justify-between`,children:[(0,T.jsx)(`span`,{className:`text-muted-foreground font-medium`,children:`Total Tagihan Paket:`}),(0,T.jsx)(`span`,{className:`font-mono font-extrabold text-foreground`,children:_(parseFloat(String(n.harga||0)))})]}),(0,T.jsxs)(`div`,{className:`flex justify-between text-emerald-600 dark:text-emerald-400 font-medium`,children:[(0,T.jsx)(`span`,{children:`Terbayar Sebelumnya:`}),(0,T.jsx)(`span`,{className:`font-mono font-extrabold`,children:_(parseFloat(String(n.paid_amount||0)))})]}),(0,T.jsxs)(`div`,{className:`flex justify-between text-rose-500 font-bold border-t border-dashed pt-1.5`,children:[(0,T.jsx)(`span`,{children:`Sisa Kekurangan:`}),(0,T.jsx)(`span`,{className:`font-mono font-extrabold`,children:_(Math.max(0,parseFloat(String(n.harga||0))-parseFloat(String(n.paid_amount||0))))})]})]}),(0,T.jsxs)(`div`,{children:[(0,T.jsx)(`label`,{className:`text-[10px] font-bold tracking-wider text-muted-foreground uppercase`,children:`Nominal Tambahan Setor (Rp)`}),(0,T.jsx)(g,{type:r?`password`:`number`,value:I,onChange:e=>L(e.target.value),className:`mt-1 font-mono rounded-xl`,placeholder:`0`}),parseFloat(I||`0`)>0&&(0,T.jsxs)(`div`,{className:`flex items-center justify-between text-[10px] font-bold text-muted-foreground bg-slate-100 dark:bg-slate-900 px-2 py-1.5 rounded-lg mt-1.5 select-none`,children:[(0,T.jsx)(`span`,{children:`Total Setelah Setor:`}),(0,T.jsx)(`span`,{className:i(`font-mono font-extrabold`,parseFloat(String(n.paid_amount||0))+parseFloat(I||`0`)>=parseFloat(String(n.harga||0))?`text-emerald-600`:`text-amber-600`),children:_(parseFloat(String(n.paid_amount||0))+parseFloat(I||`0`))})]})]}),(0,T.jsxs)(`div`,{children:[(0,T.jsx)(`label`,{className:`text-[10px] font-bold tracking-wider text-muted-foreground uppercase`,children:`Tanggal Setor`}),(0,T.jsx)(g,{type:`date`,value:A,onChange:e=>j(e.target.value),className:`mt-1 rounded-xl`})]}),(0,T.jsxs)(`div`,{children:[(0,T.jsx)(`label`,{className:`text-[10px] font-bold tracking-wider text-muted-foreground uppercase`,children:`Metode Setor`}),(0,T.jsxs)(u,{value:M,onValueChange:N,children:[(0,T.jsx)(s,{className:`mt-1 rounded-xl`,children:(0,T.jsx)(o,{})}),(0,T.jsxs)(c,{className:`rounded-2xl`,children:[(0,T.jsx)(l,{value:`cash`,children:`Tunai`}),(0,T.jsx)(l,{value:`transfer`,children:`Transfer Bank`}),(0,T.jsx)(l,{value:`qris`,children:`QRIS`}),(0,T.jsx)(l,{value:`e-wallet`,children:`E-Wallet`}),(0,T.jsx)(l,{value:`titipan`,children:`Titipan / Deposit`})]})]})]}),(0,T.jsxs)(`div`,{children:[(0,T.jsx)(`label`,{className:`text-[10px] font-bold tracking-wider text-muted-foreground uppercase`,children:`Catatan Setoran (Opsional)`}),(0,T.jsx)(g,{value:R,onChange:e=>z(e.target.value),className:`mt-1 rounded-xl`,placeholder:`Misal: Pelunasan sisa...`})]})]}):(0,T.jsxs)(T.Fragment,{children:[(0,T.jsxs)(`div`,{children:[(0,T.jsx)(`label`,{className:`text-[10px] font-bold tracking-wider text-muted-foreground uppercase`,children:`Nominal (Rp)`}),(0,T.jsx)(g,{type:r?`password`:`number`,value:O,onChange:e=>k(e.target.value),className:`mt-1 font-mono rounded-xl`,placeholder:`0`}),parseFloat(String(n.harga||0))>0&&(0,T.jsxs)(`div`,{className:`flex items-center justify-between text-[10px] font-bold text-muted-foreground bg-slate-100 dark:bg-slate-900 px-2 py-1.5 rounded-lg mt-1.5 select-none`,children:[(0,T.jsxs)(`span`,{children:[`Paket:`,` `,(0,T.jsx)(`span`,{className:`font-mono font-extrabold text-foreground`,children:_(parseFloat(String(n.harga||0)))})]}),parseFloat(String(O||0))<parseFloat(String(n.harga||0))?(0,T.jsxs)(`span`,{className:`text-rose-500 font-black uppercase tracking-wider scale-95`,children:[`Kurang:`,` `,_(parseFloat(String(n.harga||0))-parseFloat(String(O||0)))]}):(0,T.jsx)(`span`,{className:`text-emerald-600 font-black uppercase tracking-wider scale-95`,children:`Lunas`})]})]}),(0,T.jsxs)(`div`,{children:[(0,T.jsx)(`label`,{className:`text-[10px] font-bold tracking-wider text-muted-foreground uppercase`,children:`Tanggal Bayar`}),(0,T.jsx)(g,{type:`date`,value:A,onChange:e=>j(e.target.value),className:`mt-1 rounded-xl`})]}),(0,T.jsxs)(`div`,{children:[(0,T.jsx)(`label`,{className:`text-[10px] font-bold tracking-wider text-muted-foreground uppercase`,children:`Metode`}),(0,T.jsxs)(u,{value:M,onValueChange:N,children:[(0,T.jsx)(s,{className:`mt-1 rounded-xl`,children:(0,T.jsx)(o,{})}),(0,T.jsxs)(c,{className:`rounded-2xl`,children:[(0,T.jsx)(l,{value:`cash`,children:`Tunai`}),(0,T.jsx)(l,{value:`transfer`,children:`Transfer Bank`}),(0,T.jsx)(l,{value:`qris`,children:`QRIS`}),(0,T.jsx)(l,{value:`e-wallet`,children:`E-Wallet`}),(0,T.jsx)(l,{value:`titipan`,children:`Titipan / Deposit`})]})]})]}),(0,T.jsxs)(`div`,{children:[(0,T.jsx)(`label`,{className:`text-[10px] font-bold tracking-wider text-muted-foreground uppercase`,children:`Catatan (Opsional)`}),(0,T.jsx)(g,{value:P,onChange:e=>F(e.target.value),className:`mt-1 rounded-xl`,placeholder:`Catatan tambahan...`}),P&&P.includes(`[Angsuran:`)&&(0,T.jsxs)(m,{type:`button`,variant:`outline`,size:`sm`,onClick:()=>{let e=P.split(`
`).find(e=>e.startsWith(`[Awal:`));if(e){F(e);let t=e.match(/\[Awal:\s*Rp\s*([\d.]+)/);if(t){let e=parseFloat(t[1].replace(/\./g,``));k(String(e))}}else F(``),k(String(n.harga||0));h.success(`Log angsuran dibersihkan! Nominal dikembalikan ke pembayaran awal.`)},className:`mt-2 text-[9px] h-7 px-2.5 text-rose-500 border-rose-200 hover:bg-rose-50 rounded-xl transition-all w-full justify-center flex`,children:[(0,T.jsx)(p,{className:`mr-1.5 h-3.5 w-3.5 animate-spin`}),` Reset Log Angsuran`]})]})]})}),(0,T.jsxs)(y,{className:`flex gap-2`,children:[(0,T.jsx)(m,{variant:`outline`,onClick:t,className:`rounded-xl font-bold border-2`,children:`Batal`}),(0,T.jsxs)(m,{className:`bg-green-500 hover:bg-green-600 rounded-xl font-bold px-5 text-white`,onClick:()=>{if(E){let e=parseFloat(I||`0`);if(!e||e<=0){h.error(`Nominal angsuran harus diisi dan lebih dari 0`);return}}else{let e=parseFloat(O||`0`);if(!e||e<=0){h.error(`Nominal pembayaran harus diisi dan lebih dari 0`);return}}if(!A){h.error(`Tanggal bayar harus diisi`);return}let e=parseFloat(O)||parseFloat(n.harga||0)||0,t=P;if(E){let r=parseFloat(String(n.paid_amount||0)),i=parseFloat(I||`0`);e=r+i;let a=`[Angsuran: +${_(i)} tgl ${A} (${M.toUpperCase()})${R?` - `+R:``}]`;t=n.note&&n.note.includes(`[Angsuran:`)?`${n.note}\n${a}`:`${`[Awal: ${_(r)} tgl ${n.paid_at||A} (${(n.method||`CASH`).toUpperCase()})${n.note?` - `+n.note:``}]`}\n${a}`}else{let n=P.match(/\[Awal:\s*Rp\s*([\d.]+)/),r=n?parseFloat(n[1].replace(/\./g,``)):0;if(e===r&&P.includes(`[Angsuran:`)){let e=P.split(`
`).find(e=>e.startsWith(`[Awal:`));e&&(t=e)}}d({calculatedAmount:e,calculatedNote:t,calculatedMethod:M,calculatedDate:A})},disabled:f,children:[(0,T.jsx)(a,{className:`mr-1.5 h-4 w-4`}),` Simpan Pembayaran`]})]})]})})}function F({open:e,onOpenChange:t,user:n}){let{activeRouter:a}=v(),[p,h]=(0,w.useState)(new Date().getFullYear()),g=n?.user_id||n?.id;(0,w.useEffect)(()=>{e&&h(new Date().getFullYear())},[e,g]);let{data:y,isLoading:E}=r({queryKey:[`payment-card`,g,p,a?.id],queryFn:async()=>g?(await _.get(`/get_payment_card.php`,{params:{user_id:g,router_id:a?.software_id||a?.id,year:p}})).data:null,enabled:e&&!!g}),D=e=>new Intl.NumberFormat(`id-ID`,{style:`currency`,currency:`IDR`,minimumFractionDigits:0,maximumFractionDigits:0}).format(e),O=new Date().getFullYear(),k=Array.from({length:5},(e,t)=>O-t);return(0,T.jsx)(C,{open:e,onOpenChange:t,children:(0,T.jsxs)(x,{className:`max-w-[95vw] w-full md:max-w-6xl max-h-[90vh] overflow-hidden flex flex-col p-0 gap-0`,children:[(0,T.jsxs)(b,{className:`px-6 py-4 border-b shrink-0 flex flex-row items-center justify-between`,children:[(0,T.jsxs)(`div`,{children:[(0,T.jsxs)(S,{className:`text-xl font-bold uppercase tracking-wide`,children:[`KARTU PEMBAYARAN: `,y?.user?.username||n?.username]}),(0,T.jsxs)(`div`,{className:`text-sm text-muted-foreground mt-1`,children:[y?.user?.profile||n?.profile,` | `,y?.user?.alamat||n?.alamat||`Tanpa Alamat`]})]}),(0,T.jsxs)(`div`,{className:`flex items-center gap-3`,children:[(0,T.jsxs)(u,{value:p.toString(),onValueChange:e=>h(parseInt(e)),children:[(0,T.jsx)(s,{className:`w-[120px] font-bold`,children:(0,T.jsx)(o,{})}),(0,T.jsx)(c,{children:k.map(e=>(0,T.jsx)(l,{value:e.toString(),children:e},e))})]}),(0,T.jsx)(m,{variant:`outline`,size:`icon`,title:`Cetak Kartu`,onClick:()=>{y?.data&&y?.user&&N(y.user,p,y.data,y.summary,void 0)},children:(0,T.jsx)(f,{className:`h-4 w-4`})})]})]}),(0,T.jsx)(`div`,{className:`flex-1 overflow-auto p-6 bg-slate-50/50 dark:bg-slate-950/50`,children:E?(0,T.jsx)(`div`,{className:`flex items-center justify-center h-[400px]`,children:(0,T.jsx)(d,{className:`h-8 w-8 animate-spin text-primary`})}):(0,T.jsx)(T.Fragment,{children:(0,T.jsx)(`div`,{className:`rounded-xl border shadow-sm bg-background overflow-hidden`,children:(0,T.jsxs)(`table`,{className:`w-full text-sm`,children:[(0,T.jsx)(`thead`,{children:(0,T.jsxs)(`tr`,{className:`bg-[#8CB4E2] dark:bg-blue-900/40 text-black dark:text-blue-100`,children:[(0,T.jsx)(`th`,{className:`border-r border-b border-[#5B88C6] dark:border-blue-800/50 p-2.5 font-bold text-center w-12`,children:`No`}),(0,T.jsx)(`th`,{className:`border-r border-b border-[#5B88C6] dark:border-blue-800/50 p-2.5 font-bold text-left`,children:`Bulan`}),(0,T.jsx)(`th`,{className:`border-r border-b border-[#5B88C6] dark:border-blue-800/50 p-2.5 font-bold text-right`,children:`Iuran Bulanan`}),(0,T.jsx)(`th`,{className:`border-r border-b border-[#5B88C6] dark:border-blue-800/50 p-2.5 font-bold text-right`,children:`Kekurangan Bln Kemarin`}),(0,T.jsx)(`th`,{className:`border-r border-b border-[#5B88C6] dark:border-blue-800/50 p-2.5 font-bold text-right`,children:`Tagihan Bulan Ini`}),(0,T.jsx)(`th`,{className:`border-r border-b border-[#5B88C6] dark:border-blue-800/50 p-2.5 font-bold text-right w-32`,children:`Bayar`}),(0,T.jsx)(`th`,{className:`border-r border-b border-[#5B88C6] dark:border-blue-800/50 p-2.5 font-bold text-right w-32`,children:`Sisa Tagihan`}),(0,T.jsx)(`th`,{className:`border-b border-[#5B88C6] dark:border-blue-800/50 p-2.5 font-bold text-left`,children:`Ket`})]})}),(0,T.jsx)(`tbody`,{className:`font-mono text-[13px]`,children:y?.data?.map((e,t)=>{let n=e.sisa_tagihan<=0&&e.tagihan_bulan_ini>0,r=e.sisa_tagihan>0;return(0,T.jsxs)(`tr`,{className:`hover:bg-muted/50 border-b last:border-0 transition-colors`,children:[(0,T.jsx)(`td`,{className:`p-2 border-r text-center font-sans font-medium`,children:e.no}),(0,T.jsx)(`td`,{className:`p-2 border-r font-sans font-medium`,children:e.bulan}),(0,T.jsx)(`td`,{className:`p-2 border-r text-right`,children:D(e.iuran_bulanan)}),(0,T.jsx)(`td`,{className:`p-2 border-r text-right`,children:D(e.kekurangan_kemarin)}),(0,T.jsx)(`td`,{className:`p-2 border-r text-right font-bold bg-slate-50 dark:bg-slate-900/50`,children:D(e.tagihan_bulan_ini)}),(0,T.jsx)(`td`,{className:i(`p-2 border-r text-right font-bold transition-colors`,n?`bg-[#32CD32]/20 dark:bg-[#32CD32]/30 text-emerald-800 dark:text-emerald-300`:e.bayar>0&&r?`bg-amber-500/20 dark:bg-amber-500/30 text-amber-800 dark:text-amber-300`:e.tagihan_bulan_ini>0&&e.bayar===0?`bg-[#FF4500]/20 dark:bg-[#FF4500]/30 text-red-800 dark:text-red-300`:``),children:D(e.bayar)}),(0,T.jsx)(`td`,{className:i(`p-2 border-r text-right transition-colors font-bold`,e.sisa_tagihan>0?`text-red-600 dark:text-red-400`:`text-emerald-600 dark:text-emerald-400`),children:e.sisa_tagihan>0?`-${D(e.sisa_tagihan)}`:D(0)}),(0,T.jsx)(`td`,{className:`p-2 text-left font-sans text-xs text-muted-foreground`,children:e.keterangan||`-`})]},t)})}),(0,T.jsx)(`tfoot`,{children:(0,T.jsxs)(`tr`,{className:`bg-slate-100 dark:bg-slate-900 font-bold border-t-2 border-slate-300 dark:border-slate-800`,children:[(0,T.jsxs)(`td`,{colSpan:2,className:`p-3 text-right`,children:[`TOTAL `,p,`:`]}),(0,T.jsx)(`td`,{className:`p-3 text-right`,children:D(y?.summary?.total_iuran||0)}),(0,T.jsx)(`td`,{className:`p-3 text-right`}),(0,T.jsx)(`td`,{className:`p-3 text-right`}),(0,T.jsx)(`td`,{className:`p-3 text-right text-emerald-700 dark:text-emerald-400`,children:D(y?.summary?.total_bayar||0)}),(0,T.jsx)(`td`,{className:`p-3 text-right text-red-600 dark:text-red-400`,children:(y?.summary?.sisa_akhir||0)>0?`-${D(y?.summary?.sisa_akhir)}`:D(0)}),(0,T.jsx)(`td`,{})]})})]})})})})]})})}export{M as a,k as i,P as n,A as o,j as r,F as t};