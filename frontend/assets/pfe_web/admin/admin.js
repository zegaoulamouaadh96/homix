// ===== HomiX Admin Dashboard JS =====
const API = '';
let allOrders = [], allHouses = [], allClients = [], allSales = [];

// ===== Auth Check =====
(function checkAuth() {
  const token = sessionStorage.getItem('homix_token');
  if (!token) {
    window.location.href = '../login.html';
    return;
  }
  const name = sessionStorage.getItem('homix_admin') || 'المسؤول';
  document.getElementById('adminNameDisplay').textContent = name;
})();

// ===== Date Display =====
document.getElementById('currentDate').textContent =
  new Date().toLocaleDateString('ar-DZ', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' });

// ===== Helpers =====
function authHeaders() {
  return {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ' + sessionStorage.getItem('homix_token')
  };
}

function showToast(message, type = 'success') {
  const t = document.getElementById('toast');
  t.textContent = (type === 'success' ? '✅ ' : '❌ ') + message;
  t.className = 'toast show ' + type;
  setTimeout(() => t.className = 'toast', 3000);
}

function openModal(id) { document.getElementById(id).classList.add('active'); }
function closeModal(id) { document.getElementById(id).classList.remove('active'); }

function toggleSidebar() {
  document.getElementById('sidebar').classList.toggle('open');
}

function logout() {
  sessionStorage.removeItem('homix_token');
  sessionStorage.removeItem('homix_admin');
  window.location.href = '../login.html';
}

// ===== Navigation =====
const sectionTitles = {
  dashboard: '📊 لوحة التحكم',
  orders: '📋 الطلبات',
  houses: '🏠 المنازل والأكواد',
  clients: '👥 العملاء',
  sales: '💰 المبيعات',
  support: '🛠️ الدعم الفني',
  installation: '🔧 التركيب',
  settings: '⚙️ الإعدادات'
};

function showSection(name, el) {
  document.querySelectorAll('.tab-content').forEach(s => s.classList.remove('active'));
  document.querySelectorAll('.sidebar-nav a').forEach(a => a.classList.remove('active'));
  document.getElementById('section-' + name).classList.add('active');
  if (el) el.classList.add('active');
  document.getElementById('pageTitle').textContent = sectionTitles[name] || name;
  // Close sidebar on mobile
  document.getElementById('sidebar').classList.remove('open');
}

// ===== API Calls =====
async function apiGet(endpoint) {
  const res = await fetch(API + endpoint, { headers: authHeaders() });
  return res.json();
}

async function apiPost(endpoint, body) {
  const res = await fetch(API + endpoint, {
    method: 'POST',
    headers: authHeaders(),
    body: JSON.stringify(body)
  });
  return res.json();
}

async function apiPut(endpoint, body) {
  const res = await fetch(API + endpoint, {
    method: 'PUT',
    headers: authHeaders(),
    body: JSON.stringify(body)
  });
  return res.json();
}

async function apiDelete(endpoint) {
  const res = await fetch(API + endpoint, {
    method: 'DELETE',
    headers: authHeaders()
  });
  return res.json();
}

// ===== Load Data =====
async function loadDashboard() {
  try {
    const data = await apiGet('/api/admin/stats');
    document.getElementById('totalHouses').textContent = data.totalHouses || 0;
    document.getElementById('activeHouses').textContent = data.activeHouses || 0;
    document.getElementById('totalOrders').textContent = data.totalOrders || 0;
    document.getElementById('pendingOrders').textContent = data.pendingOrders || 0;
    document.getElementById('totalRevenue').textContent = (data.totalRevenue || 0).toLocaleString('ar-DZ');
    document.getElementById('totalClients').textContent = data.totalClients || 0;
    document.getElementById('pendingOrdersBadge').textContent = data.pendingOrders || 0;
  } catch (e) { console.error(e); }
}

async function loadOrders() {
  try {
    const data = await apiGet('/api/admin/orders');
    allOrders = data.orders || [];
    renderOrders(allOrders);
    renderRecentOrders(allOrders.slice(0, 5));
  } catch (e) { console.error(e); }
}

function renderOrders(orders) {
  const tbody = document.querySelector('#ordersTable tbody');
  const empty = document.getElementById('ordersEmpty');
  if (!orders.length) {
    tbody.innerHTML = '';
    empty.style.display = 'block';
    return;
  }
  empty.style.display = 'none';
  tbody.innerHTML = orders.map(o => `
    <tr>
      <td>${o.id}</td>
      <td>${o.client_name}</td>
      <td>${o.phone || '-'}</td>
      <td>${o.address || '-'}</td>
      <td>${packageLabel(o.package_type)}</td>
      <td>${statusBadge(o.status)}</td>
      <td>${formatDate(o.created_at)}</td>
      <td>
        ${o.status === 'pending' ? `
          <button class="btn btn-success btn-sm" onclick="updateOrder(${o.id}, 'approved')">✅ قبول</button>
          <button class="btn btn-danger btn-sm" onclick="updateOrder(${o.id}, 'rejected')">❌ رفض</button>
        ` : '-'}
      </td>
    </tr>
  `).join('');
}

function renderRecentOrders(orders) {
  const tbody = document.querySelector('#recentOrdersTable tbody');
  if (!orders.length) {
    tbody.innerHTML = '<tr><td colspan="5" style="text-align:center; color:var(--text-gray);">لا توجد طلبات</td></tr>';
    return;
  }
  tbody.innerHTML = orders.map(o => `
    <tr>
      <td>${o.id}</td>
      <td>${o.client_name}</td>
      <td>${o.house_code || '-'}</td>
      <td>${statusBadge(o.status)}</td>
      <td>${formatDate(o.created_at)}</td>
    </tr>
  `).join('');
}

async function updateOrder(id, status) {
  const data = await apiPut('/api/admin/orders/' + id, { status });
  if (data.success) {
    showToast('تم تحديث حالة الطلب');
    loadAll();
  } else {
    showToast(data.message || 'خطأ', 'error');
  }
}

function filterOrders(status, btn) {
  btn.parentElement.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
  btn.classList.add('active');
  const filtered = status === 'all' ? allOrders : allOrders.filter(o => o.status === status);
  renderOrders(filtered);
}

function searchOrders(q) {
  q = q.toLowerCase();
  const filtered = allOrders.filter(o =>
    (o.client_name || '').toLowerCase().includes(q) ||
    (o.phone || '').includes(q) ||
    (o.house_code || '').includes(q)
  );
  renderOrders(filtered);
}

// ===== Houses =====
async function loadHouses() {
  try {
    const data = await apiGet('/api/admin/houses');
    allHouses = data.houses || [];
    renderHouses(allHouses);
  } catch (e) { console.error(e); }
}

function renderHouses(houses) {
  const tbody = document.querySelector('#housesTable tbody');
  const empty = document.getElementById('housesEmpty');
  if (!houses.length) {
    tbody.innerHTML = '';
    empty.style.display = 'block';
    return;
  }
  empty.style.display = 'none';
  tbody.innerHTML = houses.map(h => `
    <tr>
      <td><span class="house-code">${h.code}</span></td>
      <td>${h.client_name || '-'}</td>
      <td>${h.address || '-'}</td>
      <td>${packageLabel(h.package_type)}</td>
      <td>${h.activated ? '<span class="badge-status badge-active">● مفعّل</span>' : '<span class="badge-status badge-inactive">● غير مفعّل</span>'}</td>
      <td>${h.activated_at ? formatDate(h.activated_at) : '-'}</td>
      <td>
        <button class="btn btn-outline btn-sm" onclick="viewHouseDetail(${h.id})">👁️ تفاصيل</button>
        ${!h.activated ? `<button class="btn btn-success btn-sm" onclick="activateHouse(${h.id})">✅ تفعيل</button>` : ''}
      </td>
    </tr>
  `).join('');
}

async function generateHouseCode() {
  const client_id = document.getElementById('houseClientSelect').value;
  const wilaya = document.getElementById('houseWilaya').value.trim();
  const city = document.getElementById('houseCity').value.trim();
  const address = document.getElementById('houseAddress').value.trim();
  const package_type = document.getElementById('housePackage').value;

  if (!client_id || !wilaya || !address) {
    showToast('يرجى ملء جميع الحقول المطلوبة', 'error');
    return;
  }

  const data = await apiPost('/api/admin/houses', { client_id, wilaya, city, address, package_type });
  if (data.success) {
    showToast('تم إنشاء الكود: ' + data.code);
    closeModal('generateCodeModal');
    // Reset form
    document.getElementById('houseWilaya').value = '';
    document.getElementById('houseCity').value = '';
    document.getElementById('houseAddress').value = '';
    loadAll();
  } else {
    showToast(data.message || 'خطأ', 'error');
  }
}

async function activateHouse(id) {
  const data = await apiPut('/api/admin/houses/' + id + '/activate', {});
  if (data.success) {
    showToast('تم تفعيل المنزل');
    loadAll();
  } else {
    showToast(data.message || 'خطأ', 'error');
  }
}

async function viewHouseDetail(id) {
  const data = await apiGet('/api/admin/houses/' + id);
  const h = data.house;
  if (!h) return;
  document.getElementById('houseDetailContent').innerHTML = `
    <div style="text-align:center; margin-bottom:24px;">
      <span class="house-code" style="font-size:1.4rem;">${h.code}</span>
      <div style="margin-top:8px;">${h.activated ? '<span class="badge-status badge-active">● مفعّل</span>' : '<span class="badge-status badge-inactive">● غير مفعّل</span>'}</div>
    </div>
    <div class="house-detail-grid">
      <div class="detail-item">
        <div class="detail-icon">👤</div>
        <div><div class="detail-label">العميل</div><div class="detail-value">${h.client_name || '-'}</div></div>
      </div>
      <div class="detail-item">
        <div class="detail-icon">📞</div>
        <div><div class="detail-label">الهاتف</div><div class="detail-value">${h.client_phone || '-'}</div></div>
      </div>
      <div class="detail-item">
        <div class="detail-icon">📍</div>
        <div><div class="detail-label">الولاية / المدينة</div><div class="detail-value">${h.wilaya || '-'} / ${h.city || '-'}</div></div>
      </div>
      <div class="detail-item">
        <div class="detail-icon">🏠</div>
        <div><div class="detail-label">العنوان</div><div class="detail-value">${h.address || '-'}</div></div>
      </div>
      <div class="detail-item">
        <div class="detail-icon">📦</div>
        <div><div class="detail-label">الباقة</div><div class="detail-value">${packageLabel(h.package_type)}</div></div>
      </div>
      <div class="detail-item">
        <div class="detail-icon">📅</div>
        <div><div class="detail-label">تاريخ الإنشاء</div><div class="detail-value">${formatDate(h.created_at)}</div></div>
      </div>
    </div>
    ${h.sales && h.sales.length ? `
      <h4 style="margin-top:24px; margin-bottom:12px;">💰 المبيعات المرتبطة</h4>
      <table class="data-table">
        <thead><tr><th>المبلغ</th><th>التاريخ</th><th>ملاحظات</th></tr></thead>
        <tbody>${h.sales.map(s => `<tr><td>${s.amount.toLocaleString('ar-DZ')} دج</td><td>${formatDate(s.created_at)}</td><td>${s.notes || '-'}</td></tr>`).join('')}</tbody>
      </table>
    ` : ''}
    ${h.support_tickets && h.support_tickets.length ? `
      <h4 style="margin-top:24px; margin-bottom:12px;">🛠️ تذاكر الدعم</h4>
      <table class="data-table">
        <thead><tr><th>المشكلة</th><th>الحالة</th><th>التاريخ</th></tr></thead>
        <tbody>${h.support_tickets.map(t => `<tr><td>${t.issue}</td><td>${statusBadge(t.status)}</td><td>${formatDate(t.created_at)}</td></tr>`).join('')}</tbody>
      </table>
    ` : ''}
  `;
  openModal('houseDetailModal');
}

function filterHouses(status, btn) {
  btn.parentElement.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
  btn.classList.add('active');
  const filtered = status === 'all' ? allHouses :
    status === 'active' ? allHouses.filter(h => h.activated) :
    allHouses.filter(h => !h.activated);
  renderHouses(filtered);
}

function searchHouses(q) {
  q = q.toLowerCase();
  const filtered = allHouses.filter(h =>
    (h.code || '').toLowerCase().includes(q) ||
    (h.client_name || '').toLowerCase().includes(q)
  );
  renderHouses(filtered);
}

// ===== Clients =====
async function loadClients() {
  try {
    const data = await apiGet('/api/admin/clients');
    allClients = data.clients || [];
    renderClients(allClients);
    populateClientSelects();
  } catch (e) { console.error(e); }
}

function renderClients(clients) {
  const tbody = document.querySelector('#clientsTable tbody');
  tbody.innerHTML = clients.map(c => `
    <tr>
      <td>${c.id}</td>
      <td>${c.name}</td>
      <td>${c.phone || '-'}</td>
      <td>${c.email || '-'}</td>
      <td>${c.house_count || 0}</td>
      <td>${formatDate(c.created_at)}</td>
      <td>
        <button class="btn btn-outline btn-sm" onclick="deleteClient(${c.id})">🗑️</button>
      </td>
    </tr>
  `).join('');
}

function populateClientSelects() {
  const html = '<option value="">اختر العميل</option>' +
    allClients.map(c => `<option value="${c.id}">${c.name} — ${c.phone || ''}</option>`).join('');
  document.getElementById('houseClientSelect').innerHTML = html;
}

async function addClient() {
  const name = document.getElementById('clientName').value.trim();
  const phone = document.getElementById('clientPhone').value.trim();
  const email = document.getElementById('clientEmail').value.trim();
  const address = document.getElementById('clientAddress').value.trim();

  if (!name || !phone) {
    showToast('يرجى إدخال الاسم ورقم الهاتف', 'error');
    return;
  }

  const data = await apiPost('/api/admin/clients', { name, phone, email, address });
  if (data.success) {
    showToast('تم إضافة العميل');
    closeModal('addClientModal');
    document.getElementById('clientName').value = '';
    document.getElementById('clientPhone').value = '';
    document.getElementById('clientEmail').value = '';
    document.getElementById('clientAddress').value = '';
    loadClients();
  } else {
    showToast(data.message || 'خطأ', 'error');
  }
}

async function deleteClient(id) {
  if (!confirm('هل أنت متأكد من حذف هذا العميل؟')) return;
  const data = await apiDelete('/api/admin/clients/' + id);
  if (data.success) {
    showToast('تم حذف العميل');
    loadAll();
  } else {
    showToast(data.message || 'خطأ', 'error');
  }
}

function searchClients(q) {
  q = q.toLowerCase();
  const filtered = allClients.filter(c =>
    (c.name || '').toLowerCase().includes(q) ||
    (c.phone || '').includes(q)
  );
  renderClients(filtered);
}

// ===== Sales =====
async function loadSales() {
  try {
    const data = await apiGet('/api/admin/sales');
    allSales = data.sales || [];
    renderSales(allSales);
    // Populate house select for sale modal
    const houseOptions = '<option value="">اختر المنزل</option>' +
      allHouses.map(h => `<option value="${h.id}">${h.code} — ${h.client_name || 'بدون عميل'}</option>`).join('');
    document.getElementById('saleHouseSelect').innerHTML = houseOptions;
    // Stats
    const total = allSales.reduce((s, x) => s + (x.amount || 0), 0);
    document.getElementById('salesTotal').textContent = total.toLocaleString('ar-DZ');
    document.getElementById('salesCount').textContent = allSales.length;
    document.getElementById('salesAvg').textContent = allSales.length ? Math.round(total / allSales.length).toLocaleString('ar-DZ') : 0;
  } catch (e) { console.error(e); }
}

function renderSales(sales) {
  const tbody = document.querySelector('#salesTable tbody');
  tbody.innerHTML = sales.map((s, i) => `
    <tr>
      <td>${s.id || i + 1}</td>
      <td>${s.client_name || '-'}</td>
      <td><span class="house-code">${s.house_code || '-'}</span></td>
      <td>${packageLabel(s.package_type)}</td>
      <td>${(s.amount || 0).toLocaleString('ar-DZ')} دج</td>
      <td>${formatDate(s.created_at)}</td>
    </tr>
  `).join('');
}

async function addSale() {
  const house_id = document.getElementById('saleHouseSelect').value;
  const amount = parseInt(document.getElementById('saleAmount').value);
  const notes = document.getElementById('saleNotes').value.trim();

  if (!house_id || !amount) {
    showToast('يرجى اختيار المنزل وإدخال المبلغ', 'error');
    return;
  }

  const data = await apiPost('/api/admin/sales', { house_id, amount, notes });
  if (data.success) {
    showToast('تم تسجيل المبيعة');
    closeModal('addSaleModal');
    document.getElementById('saleAmount').value = '';
    document.getElementById('saleNotes').value = '';
    loadAll();
  } else {
    showToast(data.message || 'خطأ', 'error');
  }
}

// ===== Support & Installation (load from API) =====
async function loadSupport() {
  try {
    const data = await apiGet('/api/admin/support');
    const tickets = data.tickets || [];
    const tbody = document.querySelector('#supportTable tbody');
    const empty = document.getElementById('supportEmpty');
    if (!tickets.length) { tbody.innerHTML = ''; empty.style.display = 'block'; return; }
    empty.style.display = 'none';
    tbody.innerHTML = tickets.map(t => `
      <tr>
        <td>${t.id}</td>
        <td>${t.client_name || '-'}</td>
        <td><span class="house-code">${t.house_code || '-'}</span></td>
        <td>${t.issue}</td>
        <td>${statusBadge(t.status)}</td>
        <td>${formatDate(t.created_at)}</td>
        <td>
          ${t.status === 'open' ? `<button class="btn btn-success btn-sm" onclick="resolveTicket(${t.id})">✅ حل</button>` : '-'}
        </td>
      </tr>
    `).join('');
  } catch (e) { console.error(e); }
}

async function resolveTicket(id) {
  const data = await apiPut('/api/admin/support/' + id, { status: 'resolved' });
  if (data.success) { showToast('تم حل التذكرة'); loadSupport(); }
}

async function loadInstallation() {
  try {
    const data = await apiGet('/api/admin/installations');
    const items = data.installations || [];
    const tbody = document.querySelector('#installTable tbody');
    const empty = document.getElementById('installEmpty');
    if (!items.length) { tbody.innerHTML = ''; empty.style.display = 'block'; return; }
    empty.style.display = 'none';
    tbody.innerHTML = items.map(i => `
      <tr>
        <td>${i.id}</td>
        <td>${i.client_name || '-'}</td>
        <td><span class="house-code">${i.house_code || '-'}</span></td>
        <td>${i.address || '-'}</td>
        <td>${formatDate(i.install_date)}</td>
        <td>${statusBadge(i.status)}</td>
        <td>
          ${i.status === 'scheduled' ? `<button class="btn btn-success btn-sm" onclick="completeInstall(${i.id})">✅ إنجاز</button>` : '-'}
        </td>
      </tr>
    `).join('');
  } catch (e) { console.error(e); }
}

async function completeInstall(id) {
  const data = await apiPut('/api/admin/installations/' + id, { status: 'completed' });
  if (data.success) { showToast('تم إنجاز التركيب'); loadInstallation(); }
}

// ===== Settings =====
async function saveSettings() {
  const name = document.getElementById('settingsAdminName').value.trim();
  const oldPass = document.getElementById('settingsOldPass').value;
  const newPass = document.getElementById('settingsNewPass').value;
  const data = await apiPut('/api/admin/settings', { name, oldPassword: oldPass, newPassword: newPass });
  if (data.success) {
    showToast('تم حفظ الإعدادات');
    sessionStorage.setItem('homix_admin', name);
    document.getElementById('adminNameDisplay').textContent = name;
    document.getElementById('settingsOldPass').value = '';
    document.getElementById('settingsNewPass').value = '';
  } else {
    showToast(data.message || 'خطأ', 'error');
  }
}

// ===== Utilities =====
function statusBadge(status) {
  const map = {
    pending: '<span class="badge-status badge-pending">⏳ معلّق</span>',
    approved: '<span class="badge-status badge-active">✅ مقبول</span>',
    rejected: '<span class="badge-status badge-inactive">❌ مرفوض</span>',
    active: '<span class="badge-status badge-active">● نشط</span>',
    open: '<span class="badge-status badge-new">● مفتوح</span>',
    resolved: '<span class="badge-status badge-active">✅ محلول</span>',
    scheduled: '<span class="badge-status badge-pending">📅 مجدول</span>',
    completed: '<span class="badge-status badge-active">✅ تم</span>'
  };
  return map[status] || `<span class="badge-status badge-new">${status}</span>`;
}

function packageLabel(pkg) {
  const map = {
    basic: '📦 أساسية',
    premium: '⭐ متقدمة',
    enterprise: '🏢 شاملة'
  };
  return map[pkg] || pkg || '-';
}

function formatDate(d) {
  if (!d) return '-';
  try {
    return new Date(d).toLocaleDateString('ar-DZ', { year: 'numeric', month: 'short', day: 'numeric' });
  } catch { return d; }
}

// ===== Load All =====
async function loadAll() {
  await loadDashboard();
  await loadOrders();
  await loadClients();
  await loadHouses();
  await loadSales();
  await loadSupport();
  await loadInstallation();
}

loadAll();
