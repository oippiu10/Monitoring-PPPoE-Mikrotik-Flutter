const MONTHS_ID = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
]

const fmt = (n: number) =>
  new Intl.NumberFormat('id-ID', {
    style: 'currency',
    currency: 'IDR',
    maximumFractionDigits: 0,
  }).format(n)

const humanizeName = (username: string) => {
  if (!username) return ''
  return username.replace(/[._]/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase())
}

export const printBulkThermal = (usersToPrint: any[], month: number, year: number, settings?: any) => {
  if (usersToPrint.length === 0) return

  let html = `<!doctype html><html><head><title>Print Thermal Massal</title><style>
  body{font-family:monospace;margin:0;padding:0;background:#f3f4f6}
  .receipt{width:58mm;margin:20px auto;background:white;padding:10px;box-shadow:0 4px 6px -1px rgb(0 0 0 / .1)}
  .center{text-align:center}.bold{font-weight:bold}.line{border-top:1px dashed #000;margin:10px 0}
  .mb-1{margin-bottom:4px}.mb-2{margin-bottom:8px}.mt-2{margin-top:8px}
  .table{width:100%;font-size:12px;border-collapse:collapse}.table td{padding:2px 0}
  .right{text-align:right}.title{font-size:12px}.page-break{page-break-after:always}
  @media print{body{background:white}.receipt{box-shadow:none;margin:0;padding:0}.no-print{display:none}}
  </style></head><body>`

  html += `<div class="no-print center" style="padding:10px"><button onclick="window.print()" style="padding:8px 16px;background:black;color:white;border-radius:4px;cursor:pointer">Print Thermal (${usersToPrint.length})</button></div>`

  usersToPrint.forEach((u, idx) => {
    const isPaid = u.status === 'paid'
    const statusText = isPaid ? 'LUNAS' : 'BELUM BAYAR'
    const statusNo = `INV-${year}${String(month).padStart(2, '0')}-${u.user_id || u.id || u.username}`
    const amount = fmt(parseFloat(u.harga || u.paid_amount || 0))
    const ispName = settings?.isp_name || 'WIFIKU NET'

    html += `
    <div class="receipt ${idx < usersToPrint.length - 1 ? 'page-break' : ''}">
      <div style="padding:5px;">
        <div class="center bold mb-1" style="font-size:14px">${ispName}</div>
        <div class="center mb-2">BUKTI PEMBAYARAN</div>
        <div class="line"></div>
        <table class="table">
          <tr><td>No.</td><td class="right">${statusNo}</td></tr>
          <tr><td>Tgl</td><td class="right">${new Date().toISOString().slice(0, 10)}</td></tr>
          <tr><td>Pel.</td><td class="right">${humanizeName(u.username)}</td></tr>
        </table>
        <div class="line"></div>
        <table class="table">
          <tr><td>Internet WiFi</td><td class="right"></td></tr>
          <tr><td>Bln ${MONTHS_ID[month - 1]} ${year}</td><td class="right">${amount}</td></tr>
          <tr><td class="bold mt-2">TOTAL</td><td class="right bold mt-2">${amount}</td></tr>
        </table>
        <div class="center mt-2">
          <div style="display:inline-block;padding:4px 12px;border:2px solid ${isPaid ? '#000' : '#666'};font-weight:bold;border-radius:4px;letter-spacing:1px;font-size:14px">${statusText}</div>
        </div>
        <div class="center" style="font-size:10px;margin-top:10px">Terima kasih atas pembayaran Anda.</div>
      </div>
    </div>`
  })

  html += '<script>window.onload=()=>window.print();</script></body></html>'

  const w = window.open('', '_blank')
  w?.document.write(html)
  w?.document.close()
}

export const printThermal = (row: any, month: number, year: number, settings?: any) => {
  const isPaid = row.status === 'paid'
  const statusText = isPaid ? 'LUNAS' : 'BELUM BAYAR'
  const invoiceNo = `INV-${year}${String(month).padStart(2, '0')}-${row.user_id || row.id || row.username}`
  const amount = fmt(parseFloat(row.harga || row.paid_amount || 0))
  const ispName = settings?.isp_name || 'WIFIKU NET'

  const html = `<!doctype html><html><head><title>Print Thermal</title><style>
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
      <div class="center bold mb-1" style="font-size:14px">${ispName}</div>
      <div class="center mb-2">BUKTI PEMBAYARAN</div>
      <div class="line"></div>
      <table class="table">
        <tr><td>No.</td><td class="right">${invoiceNo}</td></tr>
        <tr><td>Tgl</td><td class="right">${new Date().toISOString().slice(0, 10)}</td></tr>
        <tr><td>Pel.</td><td class="right">${humanizeName(row.username)}</td></tr>
      </table>
      <div class="line"></div>
      <table class="table">
        <tr><td>Internet WiFi</td><td class="right"></td></tr>
        <tr><td>Bln ${MONTHS_ID[month - 1]} ${year}</td><td class="right">${amount}</td></tr>
        <tr><td class="bold mt-2">TOTAL</td><td class="right bold mt-2">${amount}</td></tr>
      </table>
      <div class="center mt-2">
        <div style="display:inline-block;padding:4px 12px;border:2px solid ${isPaid ? '#000' : '#666'};font-weight:bold;border-radius:4px;letter-spacing:1px;font-size:14px">${statusText}</div>
      </div>
      <div class="center" style="font-size:10px;margin-top:10px">Terima kasih atas pembayaran Anda.</div>
    </div>
  </div>
  <script>window.onload=()=>window.print();</script>
  </body></html>`

  const w = window.open('', '_blank')
  w?.document.write(html)
  w?.document.close()
}

export const printBulkInvoice = (usersToPrint: any[], month: number, year: number, settings?: any) => {
  if (usersToPrint.length === 0) return

  let html = `<!doctype html><html><head><title>Print Invoice Massal</title><style>
  body{font-family:Arial,sans-serif;margin:0;padding:0;background:#f3f4f6}
  .paper{max-width:760px;margin:40px auto;background:white;padding:48px;border-radius:16px;box-shadow:0 10px 35px rgba(0,0,0,.08)}
  .top{display:flex;justify-content:space-between;gap:24px;border-bottom:2px solid #111827;padding-bottom:24px;margin-bottom:32px}
  h1{margin:0;font-size:32px}.muted{color:#6b7280;font-size:14px}.badge{display:inline-block;padding:8px 16px;border-radius:999px;font-weight:800;font-size:12px}
  .paid{background:#dcfce7;color:#166534}.unpaid{background:#ffedd5;color:#9a3412}
  table{width:100%;border-collapse:collapse;margin-top:32px}td,th{padding:16px;border-bottom:1px solid #e5e7eb;text-align:left}th{font-size:12px;text-transform:uppercase;color:#6b7280}.right{text-align:right}.total{font-size:24px;font-weight:900}.footer{margin-top:48px;font-size:13px;color:#6b7280;text-align:center}.page-break{page-break-after:always}
  @media print{body{background:white}.paper{box-shadow:none;margin:0;border-radius:0;padding:20px}.no-print{display:none}}
  </style></head><body>`

  html += `<div class="no-print" style="text-align:center;padding:20px"><button onclick="window.print()" style="padding:10px 20px;background:#111827;color:white;border-radius:8px;font-weight:bold;cursor:pointer">Print Semua (${usersToPrint.length} Invoice)</button></div>`

  usersToPrint.forEach((u, idx) => {
    const isPaid = u.status === 'paid'
    const statusClass = isPaid ? 'paid' : 'unpaid'
    const statusText = isPaid ? 'LUNAS' : 'BELUM BAYAR'
    const invoiceNo = `INV-${year}${String(month).padStart(2, '0')}-${u.user_id || u.id || u.username}`
    const amount = fmt(parseFloat(u.harga || u.paid_amount || 0))
    const ispName = settings?.isp_name || 'WIFIKU NET'
    const ispTagline = settings?.isp_tagline || 'Layanan Internet Cepat & Terpercaya'
    const ispAddress = settings?.isp_address || ''
    const ispPhone = settings?.isp_phone || ''
    const ispEmail = settings?.isp_email || ''
    const ispLogo = settings?.isp_logo || ''

    html += `
    <div class="paper ${idx < usersToPrint.length - 1 ? 'page-break' : ''}">
      <div class="top">
        <div style="display:flex; align-items:center; gap:16px;">
          ${ispLogo ? `<img src="${ispLogo}" style="height:60px; max-width:180px; object-fit:contain;" />` : ''}
          <div>
            <h1>INVOICE TAGIHAN</h1>
            <div class="muted">No: ${invoiceNo} &bull; Tgl: ${new Date().toISOString().slice(0, 10)}</div>
          </div>
        </div>
        <div style="text-align:right">
          <div class="badge ${statusClass}">${statusText}</div>
          <div style="margin-top:12px;font-weight:bold;font-size:20px">${ispName}</div>
          ${ispTagline ? `<div class="muted" style="font-size:12px;">${ispTagline}</div>` : ''}
        </div>
      </div>
      
      <div style="display:flex; justify-content:space-between; margin-bottom:32px; gap:20px;">
        <div>
          <div class="muted" style="margin-bottom:4px">Ditagihkan kepada:</div>
          <div style="font-weight:bold;font-size:18px">Saudara/i ${humanizeName(u.username)}</div>
          <div class="muted">${u.wa || ''}</div>
          <div class="muted" style="font-size:12px; max-width:300px;">${u.alamat || ''}</div>
        </div>
        <div style="text-align:right">
          <div class="muted" style="margin-bottom:4px">Dari:</div>
          <div style="font-weight:bold;font-size:16px">${ispName}</div>
          <div class="muted" style="font-size:12px; max-width:250px;">${ispAddress}</div>
          <div class="muted" style="font-size:12px;">Telp: ${ispPhone}</div>
          <div class="muted" style="font-size:12px;">Email: ${ispEmail}</div>
        </div>
      </div>

      <table>
        <thead>
          <tr><th>Deskripsi Layanan</th><th class="right">Jumlah</th></tr>
        </thead>
        <tbody>
          <tr>
            <td>Layanan Internet WiFi<br><span class="muted">Periode: ${MONTHS_ID[month - 1]} ${year}</span></td>
            <td class="right" style="font-weight:bold">${amount}</td>
          </tr>
          <tr><td colspan="2" style="border-bottom:none;padding-top:32px"></td></tr>
          <tr>
            <td class="right" style="font-size:16px">TOTAL TAGIHAN</td>
            <td class="right total">${amount}</td>
          </tr>
        </tbody>
      </table>
      
      <div class="footer">
        Terima kasih telah menggunakan layanan ${ispName}.<br>
        Simpan invoice ini sebagai bukti pembayaran yang sah.
      </div>
    </div>`
  })

  html += '<script>window.onload=()=>window.print();</script></body></html>'
  const w = window.open('', '_blank')
  w?.document.write(html)
  w?.document.close()
}

export const printInvoice = (row: any, month: number, year: number, settings?: any) => {
  const invoiceNo = `INV-${year}${String(month).padStart(2, '0')}-${row.user_id || row.id || row.username}`
  const amount = fmt(parseFloat(row.harga || row.paid_amount || 0))
  const statusClass = row.status === 'paid' ? 'paid' : 'unpaid'
  const statusText = row.status === 'paid' ? 'LUNAS' : 'BELUM BAYAR'

  const ispName = settings?.isp_name || 'WIFIKU NET'
  const ispTagline = settings?.isp_tagline || 'Layanan Internet Cepat & Terpercaya'
  const ispAddress = settings?.isp_address || ''
  const ispPhone = settings?.isp_phone || ''
  const ispEmail = settings?.isp_email || ''
  const ispLogo = settings?.isp_logo || ''

  const html = `<!doctype html><html><head><title>Invoice ${row.username}</title><style>
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
        ${ispLogo ? `<img src="${ispLogo}" style="height:60px; max-width:180px; object-fit:contain;" />` : ''}
        <div>
          <h1>INVOICE TAGIHAN</h1>
          <div class="muted">No: ${invoiceNo} &bull; Tgl: ${new Date().toISOString().slice(0, 10)}</div>
        </div>
      </div>
      <div style="text-align:right">
        <div class="badge ${statusClass}">${statusText}</div>
        <div style="margin-top:12px;font-weight:bold;font-size:20px">${ispName}</div>
        ${ispTagline ? `<div class="muted" style="font-size:12px;">${ispTagline}</div>` : ''}
      </div>
    </div>
    
    <div style="display:flex; justify-content:space-between; margin-bottom:32px; gap:20px;">
      <div>
        <div class="muted" style="margin-bottom:4px">Ditagihkan kepada:</div>
        <div style="font-weight:bold;font-size:18px">Saudara/i ${humanizeName(row.username)}</div>
        <div class="muted">${row.wa || ''}</div>
        <div class="muted" style="font-size:12px; max-width:300px;">${row.alamat || ''}</div>
      </div>
      <div style="text-align:right">
        <div class="muted" style="margin-bottom:4px">Dari:</div>
        <div style="font-weight:bold;font-size:16px">${ispName}</div>
        <div class="muted" style="font-size:12px; max-width:250px;">${ispAddress}</div>
        <div class="muted" style="font-size:12px;">Telp: ${ispPhone}</div>
        <div class="muted" style="font-size:12px;">Email: ${ispEmail}</div>
      </div>
    </div>

    <table>
      <thead>
        <tr><th>Deskripsi Layanan</th><th class="right">Jumlah</th></tr>
      </thead>
      <tbody>
        <tr>
          <td>Layanan Internet WiFi<br><span class="muted">Periode: ${MONTHS_ID[month - 1]} ${year}</span></td>
          <td class="right" style="font-weight:bold">${amount}</td>
        </tr>
        <tr><td colspan="2" style="border-bottom:none;padding-top:32px"></td></tr>
        <tr>
          <td class="right" style="font-size:16px">TOTAL TAGIHAN</td>
          <td class="right total">${amount}</td>
        </tr>
      </tbody>
    </table>
    
    <div class="footer">
      Terima kasih telah menggunakan layanan ${ispName}.<br>
      Simpan invoice ini sebagai bukti pembayaran yang sah.
    </div>
  </div>
  <script>window.onload=()=>window.print();</script>
  </body></html>`

  const w = window.open('', '_blank')
  w?.document.write(html)
  w?.document.close()
}

export const printPaymentCard = (user: any, year: number, data: any[], summary: any, settings?: any) => {
  const ispName = settings?.isp_name || 'WIFIKU NET'
  const ispLogo = settings?.isp_logo || ''

  let html = `<!doctype html><html><head><title>Kartu Pembayaran ${user?.username}</title><style>
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
      ${ispLogo ? `<img src="${ispLogo}" style="height:50px;margin-bottom:10px;" />` : ''}
      <h1>KARTU PEMBAYARAN IURAN INTERNET</h1>
      <p>${ispName}</p>
    </div>
    
    <div class="info">
      <div>
        <span class="bold">Nama Pelanggan:</span> ${humanizeName(user?.username)}<br>
        <span class="bold">Alamat:</span> ${user?.alamat || '-'}<br>
        <span class="bold">Paket / Layanan:</span> ${user?.profile || '-'}
      </div>
      <div class="right">
        <span class="bold">Tahun:</span> ${year}<br>
        <span class="bold">Tanggal Cetak:</span> ${new Date().toLocaleDateString('id-ID')}
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
      <tbody>`

  const fmtSaldo = (num: number) => {
    if (num > 0) return fmt(num)
    if (num < 0) return '+' + fmt(Math.abs(num))
    return fmt(0)
  }

  data.forEach((row) => {
    html += `
        <tr>
          <td class="center bold">${row.bulan.slice(0,3)}</td>
          <td class="right">${fmt(row.iuran_bulanan)}</td>
          <td class="right">${fmtSaldo(row.kekurangan_kemarin)}</td>
          <td class="right bold">${fmtSaldo(row.tagihan_bulan_ini)}</td>
          <td class="right">${fmt(row.bayar)}</td>
          <td class="right">${fmtSaldo(row.sisa_tagihan)}</td>
          <td>${row.keterangan || '-'}</td>
        </tr>`
  })

  html += `
      </tbody>
      <tfoot>
        <tr style="background:#f9fafb;font-weight:bold">
          <td class="right">TOTAL:</td>
          <td class="right">${fmt(summary?.total_iuran || 0)}</td>
          <td></td>
          <td></td>
          <td class="right">${fmt(summary?.total_bayar || 0)}</td>
          <td class="right">${fmtSaldo(summary?.sisa_akhir || 0)}</td>
          <td></td>
        </tr>
      </tfoot>
    </table>
    
    <div class="footer">
      Dokumen ini dicetak secara otomatis dari sistem dan sah sebagai catatan pembayaran.
    </div>
  </div>
  <script>window.onload=()=>window.print();</script>
  </body></html>`

  const w = window.open('', '_blank')
  w?.document.write(html)
  w?.document.close()
}
