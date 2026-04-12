// ===== HomiX Admin Dashboard JS =====
const API = (window.HOMIX_API && String(window.HOMIX_API).trim()) || '';
let allOrders = [], allHouses = [], allClients = [], allSales = [], allSupport = [], allInstallations = [];
let allUsers = [], allEmployees = [];

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

function getHouseCode(h) {
  return h?.code || h?.home_code || h?.house_code || '-';
}

function normalizeApiError(data) {
  if (!data) return 'خطأ غير متوقع';
  if (data.message) return data.message;
  if (data.error === 'unauthorized') return 'انتهت الجلسة، يرجى تسجيل الدخول من جديد';
  if (typeof data.error === 'string' && data.error.trim()) return data.error;
  return 'خطأ غير متوقع';
}

function showToast(message, type = 'success') {
  const t = document.getElementById('toast');
  t.textContent = (type === 'success' ? 'تم: ' : 'خطأ: ') + message;
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
  dashboard: 'لوحة التحكم',
  orders: 'الطلبات',
  houses: 'المنازل والأكواد',
  clients: 'العملاء',
  sales: 'المبيعات',
  support: 'الدعم الفني',
  installation: 'التركيب',
  accounts: 'الحسابات',
  settings: 'الإعدادات'
};

function showSection(name, el) {
  document.querySelectorAll('.tab-content').forEach(s => s.classList.remove('active'));
  document.querySelectorAll('.sidebar-nav a').forEach(a => a.classList.remove('active'));
  document.getElementById('section-' + name).classList.add('active');
  if (el) el.classList.add('active');
  document.getElementById('pageTitle').textContent = sectionTitles[name] || name;
  if (name === 'support') {
    loadSupport();
  }
  if (name === 'installation') {
    loadInstallation();
  }
  // Close sidebar on mobile
  document.getElementById('sidebar').classList.remove('open');
}

// ===== API Calls =====
async function apiRequest(endpoint, options = {}) {
  const res = await fetch(API + endpoint, {
    headers: authHeaders(),
    ...options
  });

  let data = {};
  try {
    data = await res.json();
  } catch {
    data = { success: false, message: 'استجابة غير صالحة من الخادم' };
  }

  if (res.status === 401) {
    sessionStorage.removeItem('homix_token');
    sessionStorage.removeItem('homix_admin');
    showToast('انتهت الجلسة، يرجى تسجيل الدخول من جديد', 'error');
    setTimeout(() => { window.location.href = '../login.html'; }, 700);
    return { success: false, error: 'unauthorized', message: 'انتهت الجلسة، يرجى تسجيل الدخول من جديد' };
  }

  if (!res.ok && !data.message) {
    data.message = normalizeApiError(data);
  }

  return data;
}

async function apiGet(endpoint) {
  return apiRequest(endpoint);
}

async function apiPost(endpoint, body) {
  return apiRequest(endpoint, {
    method: 'POST',
    body: JSON.stringify(body)
  });
}

async function apiPut(endpoint, body) {
  return apiRequest(endpoint, {
    method: 'PUT',
    body: JSON.stringify(body)
  });
}

async function apiDelete(endpoint) {
  return apiRequest(endpoint, {
    method: 'DELETE'
  });
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
        <button class="btn btn-outline btn-sm" onclick="viewOrderDetail(${o.id})">تفاصيل</button>
        ${o.status === 'pending' ? `
          <button class="btn btn-success btn-sm" onclick="updateOrder(${o.id}, 'approved')">قبول</button>
          <button class="btn btn-danger btn-sm" onclick="updateOrder(${o.id}, 'rejected')">رفض</button>
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
    if (status === 'approved') {
      if (data.mail?.sent) {
        showToast('تم قبول الطلب وإرسال الإيميل إلى العميل');
      } else if (data.mail?.reason === 'client_email_missing') {
        showToast('تم قبول الطلب لكن لا يوجد بريد للعميل', 'error');
      } else if (data.mail?.reason === 'mailer_not_configured') {
        showToast('تم قبول الطلب لكن SMTP غير مضبوط', 'error');
      } else if (data.mail && !data.mail.sent) {
        showToast('تم قبول الطلب لكن فشل إرسال الإيميل', 'error');
      } else {
        showToast('تم قبول الطلب');
      }
    } else {
      showToast('تم تحديث حالة الطلب');
    }
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
    populateHouseOperationSelects();
  } catch (e) { console.error(e); }
}

function populateHouseOperationSelects() {
  const options = '<option value="">اختر المنزل</option>' +
    allHouses.map(h => `<option value="${h.id}">${getHouseCode(h)} — ${h.client_name || 'بدون عميل'}</option>`).join('');

  const saleSelect = document.getElementById('saleHouseSelect');
  if (saleSelect) saleSelect.innerHTML = options;

  const installSelect = document.getElementById('installHouseSelect');
  if (installSelect) installSelect.innerHTML = options;
}

function renderHouses(houses) {
  const tbody = document.querySelector('#housesTable tbody');
  const empty = document.getElementById('housesEmpty');
  updateHousesSectionStats();
  if (!houses.length) {
    tbody.innerHTML = '';
    empty.style.display = 'block';
    return;
  }
  empty.style.display = 'none';
  tbody.innerHTML = houses.map(h => `
    <tr>
      <td><span class="house-code">${getHouseCode(h)}</span></td>
      <td>${h.client_name || '-'}</td>
      <td>${h.address || '-'}</td>
      <td>${packageLabel(h.package_type)}</td>
      <td>${getHouseOrders(h).length}</td>
      <td>${getHouseSalesTotal(h).toLocaleString('ar-DZ')} دج</td>
      <td>${getHouseOpenSupportCount(h)}</td>
      <td>${formatDateTime(getHouseLastActivityDate(h))}</td>
      <td>${h.activated ? '<span class="badge-status badge-active">● مفعّل</span>' : '<span class="badge-status badge-inactive">● غير مفعّل</span>'}</td>
      <td>${h.activated_at ? formatDate(h.activated_at) : '-'}</td>
      <td>
        <button class="btn btn-outline btn-sm" onclick="viewHouseDetail(${h.id})">تفاصيل</button>
        <button class="btn btn-outline btn-sm" onclick="sendHouseCodeEmail(${h.id})">إرسال الكود</button>
        ${!h.activated
          ? `<button class="btn btn-success btn-sm" onclick="activateHouse(${h.id})">تفعيل</button>`
          : `<button class="btn btn-danger btn-sm" onclick="deactivateHouse(${h.id})">إلغاء التفعيل</button>`}
      </td>
    </tr>
  `).join('');
}

function getHouseOrders(h) {
  const hid = Number(h.id);
  const hcode = String(getHouseCode(h));
  return allOrders.filter(o =>
    (o.home_id != null && Number(o.home_id) === hid) ||
    (o.house_code && String(o.house_code) === hcode)
  );
}

function getHouseSales(h) {
  const hid = Number(h.id);
  const hcode = String(getHouseCode(h));
  return allSales.filter(s =>
    (s.home_id != null && Number(s.home_id) === hid) ||
    (s.house_code && String(s.house_code) === hcode)
  );
}

function getHouseSalesTotal(h) {
  return getHouseSales(h).reduce((sum, s) => sum + (s.amount || 0), 0);
}

function getHouseSupport(h) {
  const hcode = String(getHouseCode(h));
  return allSupport.filter(t => t.house_code && String(t.house_code) === hcode);
}

function getHouseOpenSupportCount(h) {
  return getHouseSupport(h).filter(t => String(t.status || '').toLowerCase() === 'open').length;
}

function getHouseInstallations(h) {
  const hcode = String(getHouseCode(h));
  return allInstallations.filter(i => i.house_code && String(i.house_code) === hcode);
}

function getHouseLastActivityDate(h) {
  const dates = [];
  getHouseOrders(h).forEach(o => o.created_at && dates.push(new Date(o.created_at).getTime()));
  getHouseSales(h).forEach(s => s.created_at && dates.push(new Date(s.created_at).getTime()));
  getHouseSupport(h).forEach(t => t.created_at && dates.push(new Date(t.created_at).getTime()));
  getHouseInstallations(h).forEach(i => (i.install_date || i.created_at) && dates.push(new Date(i.install_date || i.created_at).getTime()));
  if (!dates.length) return null;
  return new Date(Math.max(...dates)).toISOString();
}

function updateHousesSectionStats() {
  const totalNode = document.getElementById('housesTotalCount');
  const activeNode = document.getElementById('housesActiveCount');
  const salesNode = document.getElementById('housesSalesTotal');
  const supportNode = document.getElementById('housesOpenSupport');
  if (!totalNode || !activeNode || !salesNode || !supportNode) return;

  const total = allHouses.length;
  const active = allHouses.filter(h => !!h.activated).length;
  const salesTotal = allHouses.reduce((sum, h) => sum + getHouseSalesTotal(h), 0);
  const openSupport = allHouses.reduce((sum, h) => sum + getHouseOpenSupportCount(h), 0);

  totalNode.textContent = total;
  activeNode.textContent = active;
  salesNode.textContent = salesTotal.toLocaleString('ar-DZ');
  supportNode.textContent = openSupport;
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
    if (data.mail?.sent) {
      showToast('تم إرسال الكود إلى بريد العميل');
    } else if (data.mail?.reason === 'client_email_missing' || data.mail?.reason === 'client_missing') {
      showToast('تم إنشاء الكود لكن لا يوجد بريد للعميل', 'error');
    } else if (data.mail?.reason === 'mailer_not_configured') {
      showToast('تم إنشاء الكود لكن SMTP غير مضبوط', 'error');
    } else if (data.mail && !data.mail.sent) {
      showToast('تم إنشاء الكود لكن فشل إرسال الإيميل', 'error');
    }
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

async function deactivateHouse(id) {
  const ok = confirm('هل تريد إلغاء تفعيل هذا الكود؟');
  if (!ok) return;
  const data = await apiPut('/api/admin/houses/' + id + '/deactivate', {});
  if (data.success) {
    showToast('تم إلغاء تفعيل المنزل');
    loadAll();
  } else {
    showToast(data.message || 'تعذر إلغاء التفعيل', 'error');
  }
}

async function sendHouseCodeEmail(id) {
  const data = await apiGet('/api/admin/houses/' + id);
  const h = data.house;
  if (!h) {
    showToast('لم يتم العثور على المنزل', 'error');
    return;
  }

  const clientEmail = (h.client_email || '').trim() || '';
  document.getElementById('sendCodeHouseId').value = id;
  document.getElementById('sendCodeHouseName').value = getHouseCode(h) + ' - ' + (h.client_name || 'بدون اسم عميل');
  document.getElementById('sendCodeEmail').value = clientEmail;
  document.getElementById('sendCodeEmail').placeholder = clientEmail ? 'اترك فارغاً لاستخدام البريد الموجود' : 'ادخل البريد الإلكتروني';

  openModal('sendCodeEmailModal');
}

async function confirmSendCodeEmail() {
  const houseId = document.getElementById('sendCodeHouseId').value;
  const emailInput = document.getElementById('sendCodeEmail').value.trim();

  const payload = emailInput ? { email: emailInput } : {};

  const data = await apiPost('/api/admin/houses/' + houseId + '/send-code', payload);
  if (!data.success) {
    showToast(data.message || 'تعذر إرسال الكود', 'error');
    return;
  }

  if (data.mail?.sent) {
    showToast('تم إرسال كود المنزل إلى البريد الإلكتروني بنجاح');
    closeModal('sendCodeEmailModal');
    return;
  }

  if (data.mail?.reason === 'client_missing' || data.mail?.reason === 'client_email_missing') {
    showToast('لا يوجد بريد إلكتروني، يرجى إدخال ايميل صحيح', 'error');
    return;
  }

  if (data.mail?.reason === 'mailer_not_configured') {
    showToast('SMTP غير مضبوط في السيرفر', 'error');
    return;
  }

  showToast('فشل إرسال الإيميل، تحقق من صحة البريد الإلكتروني', 'error');
}

async function viewHouseDetail(id) {
  const data = await apiGet('/api/admin/houses/' + id);
  const h = data.house;
  if (!h) return;
  document.getElementById('houseDetailContent').innerHTML = `
    <div style="text-align:center; margin-bottom:24px;">
      <span class="house-code" style="font-size:1.4rem;">${getHouseCode(h)}</span>
      <div style="margin-top:8px;">${h.activated ? '<span class="badge-status badge-active">● مفعّل</span>' : '<span class="badge-status badge-inactive">● غير مفعّل</span>'}</div>
    </div>
    <div class="house-detail-grid">
      <div class="detail-item">
        <div class="detail-icon">عم</div>
        <div><div class="detail-label">العميل</div><div class="detail-value">${h.client_name || '-'}</div></div>
      </div>
      <div class="detail-item">
        <div class="detail-icon">هت</div>
        <div><div class="detail-label">الهاتف</div><div class="detail-value">${h.client_phone || '-'}</div></div>
      </div>
      <div class="detail-item">
        <div class="detail-icon">مو</div>
        <div><div class="detail-label">الولاية / المدينة</div><div class="detail-value">${h.wilaya || '-'} / ${h.city || '-'}</div></div>
      </div>
      <div class="detail-item">
        <div class="detail-icon">عن</div>
        <div><div class="detail-label">العنوان</div><div class="detail-value">${h.address || '-'}</div></div>
      </div>
      <div class="detail-item">
        <div class="detail-icon">با</div>
        <div><div class="detail-label">الميزات</div><div class="detail-value">${packageLabel(h.package_type)}</div></div>
      </div>
      <div class="detail-item">
        <div class="detail-icon">تو</div>
        <div><div class="detail-label">تاريخ الإنشاء</div><div class="detail-value">${formatDate(h.created_at)}</div></div>
      </div>
    </div>
    ${h.sales && h.sales.length ? `
      <h4 style="margin-top:24px; margin-bottom:12px;">المبيعات المرتبطة</h4>
      <table class="data-table">
        <thead><tr><th>المبلغ</th><th>التاريخ</th><th>ملاحظات</th></tr></thead>
        <tbody>${h.sales.map(s => `<tr><td>${s.amount.toLocaleString('ar-DZ')} دج</td><td>${formatDate(s.created_at)}</td><td>${s.notes || '-'}</td></tr>`).join('')}</tbody>
      </table>
    ` : ''}
    ${h.support_tickets && h.support_tickets.length ? `
      <h4 style="margin-top:24px; margin-bottom:12px;">تذاكر الدعم</h4>
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
    getHouseCode(h).toLowerCase().includes(q) ||
    (h.client_name || '').toLowerCase().includes(q) ||
    (h.address || '').toLowerCase().includes(q) ||
    (h.wilaya || '').toLowerCase().includes(q) ||
    (h.city || '').toLowerCase().includes(q)
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
      <td>${getClientHouses(c).length}</td>
      <td>${getClientOrders(c).length}</td>
      <td>${getClientSales(c).reduce((sum, s) => sum + (s.amount || 0), 0).toLocaleString('ar-DZ')}</td>
      <td>${(() => {
        const orders = getClientOrders(c);
        return orders.length ? formatDate(orders[0].created_at) : '-';
      })()}</td>
      <td>${formatDate(c.created_at)}</td>
      <td>
        <button class="btn btn-outline btn-sm" onclick="viewClientDetail(${c.id})">تفاصيل</button>
        <button class="btn btn-outline btn-sm" onclick="deleteClient(${c.id})">حذف</button>
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
  const email = document.getElementById('clientEmail').value.trim().toLowerCase();
  const address = document.getElementById('clientAddress').value.trim();

  if (!name || !phone || !email) {
    showToast('يرجى إدخال الاسم ورقم الهاتف والبريد الإلكتروني', 'error');
    return;
  }

  if (!/^\S+@\S+\.\S+$/.test(email)) {
    showToast('صيغة البريد الإلكتروني غير صحيحة', 'error');
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
    populateHouseOperationSelects();
    // Stats
    const total = allSales.reduce((s, x) => s + (x.amount || 0), 0);
    document.getElementById('salesTotal').textContent = total.toLocaleString('ar-DZ');
    document.getElementById('salesCount').textContent = allSales.length;
    document.getElementById('salesAvg').textContent = allSales.length ? Math.round(total / allSales.length).toLocaleString('ar-DZ') : 0;
  } catch (e) { console.error(e); }
}

function renderSales(sales) {
  const tbody = document.querySelector('#salesTable tbody');
  const empty = document.getElementById('salesEmpty');
  if (!sales.length) {
    tbody.innerHTML = '';
    if (empty) empty.style.display = 'block';
    return;
  }
  if (empty) empty.style.display = 'none';
  tbody.innerHTML = sales.map((s, i) => `
    <tr>
      <td>${s.id || i + 1}</td>
      <td>${s.client_name || '-'}</td>
      <td><span class="house-code">${s.house_code || '-'}</span></td>
      <td>${packageLabel(s.package_type)}</td>
      <td>${(s.amount || 0).toLocaleString('ar-DZ')} دج</td>
      <td>${formatDate(s.created_at)}</td>
      <td><button class="btn btn-outline btn-sm" onclick="viewSaleDetail(${s.id || i + 1})">تفاصيل</button></td>
    </tr>
  `).join('');
}

async function addSale() {
  const home_id = Number(document.getElementById('saleHouseSelect').value);
  const amount = parseInt(document.getElementById('saleAmount').value);
  const notes = document.getElementById('saleNotes').value.trim();

  if (!home_id || !amount || amount <= 0) {
    showToast('يرجى اختيار المنزل وإدخال المبلغ', 'error');
    return;
  }

  const data = await apiPost('/api/admin/sales', { home_id, amount, notes });
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
    const tickets = (data.tickets || []).map(t => ({
      ...t,
      status: String(t.status || '').toLowerCase()
    }));
    allSupport = tickets;
    renderSupport(tickets);
  } catch (e) {
    console.error(e);
    allSupport = [];
    renderSupport([]);
    showToast('تعذر تحميل طلبات الدعم الفني', 'error');
  }
}

function renderSupport(tickets) {
  const tbody = document.querySelector('#supportTable tbody');
  const empty = document.getElementById('supportEmpty');
  if (!tbody || !empty) return;

  if (!tickets.length) {
    tbody.innerHTML = '';
    empty.style.display = 'block';
    return;
  }

  empty.style.display = 'none';
  tbody.innerHTML = tickets.map(t => `
    <tr>
      <td>${t.id}</td>
      <td>${t.client_name || '-'}</td>
      <td><span class="house-code">${t.house_code || '-'}</span></td>
      <td>${t.issue || '-'}</td>
      <td>${statusBadge(t.status)}</td>
      <td>${formatDate(t.created_at)}</td>
      <td>
        <button class="btn btn-outline btn-sm" onclick="viewSupportDetail(${t.id})">تفاصيل</button>
        ${t.status === 'open' ? `<button class="btn btn-success btn-sm" onclick="resolveTicket(${t.id})">حل</button>` : '-'}
      </td>
    </tr>
  `).join('');
}

function filterSupport(status, btn) {
  if (btn && btn.parentElement) {
    btn.parentElement.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
  }
  const filtered = status === 'all' ? allSupport : allSupport.filter(t => t.status === status);
  renderSupport(filtered);
}

function searchSupport(q) {
  const x = String(q || '').toLowerCase();
  const filtered = allSupport.filter(t =>
    String(t.client_name || '').toLowerCase().includes(x) ||
    String(t.house_code || '').toLowerCase().includes(x) ||
    String(t.issue || '').toLowerCase().includes(x)
  );
  renderSupport(filtered);
}

async function resolveTicket(id) {
  try {
    const data = await apiPut('/api/admin/support/' + id, { status: 'resolved' });
    if (data.success) {
      showToast('تم حل التذكرة');
      await loadSupport();
      refreshDetailedDashboard();
    } else {
      showToast(data.message || 'تعذر تحديث حالة التذكرة', 'error');
    }
  } catch (e) {
    console.error(e);
    showToast('تعذر الاتصال بخدمة الدعم الفني', 'error');
  }
}

async function loadInstallation() {
  try {
    const data = await apiGet('/api/admin/installations');
    const items = (data.installations || []).map(i => ({
      ...i,
      status: String(i.status || '').toLowerCase()
    }));
    allInstallations = items;
    renderInstallation(items);
  } catch (e) {
    console.error(e);
    allInstallations = [];
    renderInstallation([]);
    showToast('تعذر تحميل مواعيد التركيب', 'error');
  }
}

function renderInstallation(items) {
  const tbody = document.querySelector('#installTable tbody');
  const empty = document.getElementById('installEmpty');
  if (!tbody || !empty) return;
  if (!items.length) {
    tbody.innerHTML = '';
    empty.style.display = 'block';
    return;
  }

  empty.style.display = 'none';
  tbody.innerHTML = items.map(i => `
    <tr>
      <td>${i.id}</td>
      <td>${i.client_name || '-'}</td>
      <td><span class="house-code">${i.house_code || '-'}</span></td>
      <td>${i.address || '-'}</td>
      <td>${formatDateTime(i.install_date || i.created_at)}</td>
      <td>${statusBadge(i.status)}</td>
      <td>
        <button class="btn btn-outline btn-sm" onclick="viewInstallDetail(${i.id})">تفاصيل</button>
        ${i.status !== 'completed' ? `<button class="btn btn-outline btn-sm" onclick="scheduleInstall(${i.id})">تحديد موعد</button>` : '-'}
        ${i.status === 'scheduled' ? `<button class="btn btn-success btn-sm" onclick="completeInstall(${i.id})">إنجاز</button>` : ''}
      </td>
    </tr>
  `).join('');
}

function filterInstallation(status, btn) {
  if (btn && btn.parentElement) {
    btn.parentElement.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
  }
  const filtered = status === 'all' ? allInstallations : allInstallations.filter(i => i.status === status);
  renderInstallation(filtered);
}

function searchInstallation(q) {
  const x = String(q || '').toLowerCase();
  const filtered = allInstallations.filter(i =>
    String(i.client_name || '').toLowerCase().includes(x) ||
    String(i.house_code || '').toLowerCase().includes(x) ||
    String(i.address || '').toLowerCase().includes(x)
  );
  renderInstallation(filtered);
}

async function addInstallation() {
  const home_id = Number(document.getElementById('installHouseSelect').value);
  const installDateRaw = document.getElementById('installDate').value;
  const notes = document.getElementById('installNotes').value.trim();

  if (!home_id || !installDateRaw) {
    showToast('يرجى اختيار المنزل وتحديد موعد التركيب', 'error');
    return;
  }

  const install_date = new Date(installDateRaw).toISOString();
  const data = await apiPost('/api/admin/installations', { home_id, install_date, notes, status: 'scheduled' });
  if (data.success) {
    showToast('تمت إضافة موعد التركيب');
    document.getElementById('installDate').value = '';
    document.getElementById('installNotes').value = '';
    closeModal('addInstallModal');
    await loadInstallation();
    refreshDetailedDashboard();
  } else {
    showToast(data.message || 'تعذر إضافة الموعد', 'error');
  }
}

async function scheduleInstall(id) {
  const input = prompt('أدخل الموعد (مثال: 2026-03-28 14:30)');
  if (!input) return;
  const parsed = new Date(input.replace(' ', 'T'));
  if (Number.isNaN(parsed.getTime())) {
    showToast('صيغة الموعد غير صحيحة', 'error');
    return;
  }

  const data = await apiPut('/api/admin/installations/' + id, {
    status: 'scheduled',
    install_date: parsed.toISOString()
  });

  if (data.success) {
    showToast('تم تحديث موعد التركيب');
    await loadInstallation();
    refreshDetailedDashboard();
  } else {
    showToast(data.message || 'تعذر تحديث الموعد', 'error');
  }
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

// ===== Accounts =====
async function loadAppUsers() {
  try {
    const data = await apiGet('/api/admin/users');
    allUsers = data.users || [];
    renderAppUsers(allUsers);
  } catch (e) {
    console.error(e);
  }
}

function renderAppUsers(users) {
  const tbody = document.querySelector('#usersTable tbody');
  if (!tbody) return;
  tbody.innerHTML = users.map(u => `
    <tr>
      <td>${u.id}</td>
      <td>${u.full_name || '-'}</td>
      <td>${u.phone || '-'}</td>
      <td>${u.email || '-'}</td>
      <td>${u.active_home_role || '-'}</td>
      <td>${u.homes_count || 0}</td>
      <td>${formatDate(u.created_at)}</td>
    </tr>
  `).join('');
}

function searchAppUsers(q) {
  const x = (q || '').toLowerCase();
  const filtered = allUsers.filter(u =>
    (u.full_name || '').toLowerCase().includes(x) ||
    (u.phone || '').toLowerCase().includes(x) ||
    (u.email || '').toLowerCase().includes(x)
  );
  renderAppUsers(filtered);
}

async function loadEmployees() {
  try {
    const data = await apiGet('/api/admin/employees');
    allEmployees = data.employees || [];
    renderEmployees(allEmployees);
  } catch (e) {
    console.error(e);
  }
}

function renderEmployees(employees) {
  const tbody = document.querySelector('#employeesTable tbody');
  if (!tbody) return;
  tbody.innerHTML = employees.map(e => `
    <tr>
      <td>${e.id}</td>
      <td>${e.username}</td>
      <td>${e.full_name}</td>
      <td>${e.role === 'manager' ? 'مدير فرعي' : 'موظف'}</td>
      <td>${e.is_active === 1 ? '<span class="badge-status badge-active">نشط</span>' : '<span class="badge-status badge-inactive">معطل</span>'}</td>
      <td>${e.last_login_at ? formatDateTime(e.last_login_at) : '-'}</td>
      <td>
        <button class="btn btn-outline btn-sm" onclick="toggleEmployeeStatus(${e.id}, ${e.is_active === 1 ? 0 : 1})">${e.is_active === 1 ? 'تعطيل' : 'تفعيل'}</button>
        <button class="btn btn-outline btn-sm" onclick="resetEmployeePassword(${e.id})">إعادة كلمة المرور</button>
      </td>
    </tr>
  `).join('');
}

async function createEmployeeAccount() {
  const username = document.getElementById('employeeUsername').value.trim();
  const full_name = document.getElementById('employeeFullName').value.trim();
  const password = document.getElementById('employeePassword').value;
  const role = document.getElementById('employeeRole').value;

  if (!username || !full_name || !password) {
    showToast('يرجى ملء جميع الحقول', 'error');
    return;
  }

  const data = await apiPost('/api/admin/employees', { username, full_name, password, role });
  if (data.success) {
    showToast('تم إنشاء حساب الموظف');
    document.getElementById('employeeUsername').value = '';
    document.getElementById('employeeFullName').value = '';
    document.getElementById('employeePassword').value = '';
    closeModal('addEmployeeModal');
    loadEmployees();
  } else {
    showToast(data.message || 'تعذر إنشاء الحساب', 'error');
  }
}

async function toggleEmployeeStatus(id, is_active) {
  const data = await apiPut('/api/admin/employees/' + id, { is_active });
  if (data.success) {
    showToast('تم تحديث حالة الحساب');
    loadEmployees();
  } else {
    showToast(data.message || 'تعذر تحديث الحالة', 'error');
  }
}

async function resetEmployeePassword(id) {
  const pwd = prompt('أدخل كلمة المرور الجديدة (6 أحرف على الأقل):');
  if (!pwd) return;
  if (pwd.length < 6) {
    showToast('كلمة المرور قصيرة', 'error');
    return;
  }
  const data = await apiPut('/api/admin/employees/' + id, { password: pwd });
  if (data.success) {
    showToast('تم تحديث كلمة المرور');
  } else {
    showToast(data.message || 'تعذر تحديث كلمة المرور', 'error');
  }
}

// ===== Utilities =====
function statusBadge(status) {
  const map = {
    pending: '<span class="badge-status badge-pending">معلّق</span>',
    approved: '<span class="badge-status badge-active">مقبول</span>',
    rejected: '<span class="badge-status badge-inactive">مرفوض</span>',
    active: '<span class="badge-status badge-active">نشط</span>',
    open: '<span class="badge-status badge-new">مفتوح</span>',
    resolved: '<span class="badge-status badge-active">محلول</span>',
    scheduled: '<span class="badge-status badge-pending">مجدول</span>',
    completed: '<span class="badge-status badge-active">مكتمل</span>'
  };
  return map[status] || `<span class="badge-status badge-new">${status}</span>`;
}

function packageLabel(pkg) {
  const map = {
    basic: 'تنبيهات فورية + تحكم أساسي',
    premium: 'كاميرات + سجلات + تحكم موسع',
    enterprise: 'كل الميزات + إدارة متعددة'
  };
  return map[pkg] || pkg || '-';
}

function formatDate(d) {
  if (!d) return '-';
  try {
    return new Date(d).toLocaleDateString('ar-DZ', { year: 'numeric', month: 'short', day: 'numeric' });
  } catch { return d; }
}

function formatDateTime(d) {
  if (!d) return '-';
  try {
    return new Date(d).toLocaleString('ar-DZ', {
      year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit'
    });
  } catch {
    return d;
  }
}

function safePercent(numerator, denominator) {
  if (!denominator) return 0;
  return Math.round((numerator / denominator) * 100);
}

function refreshDetailedDashboard() {
  const approvedOrders = allOrders.filter(o => o.status === 'approved').length;
  const processedOrders = allOrders.filter(o => o.status === 'approved' || o.status === 'rejected').length;
  const activeHouses = allHouses.filter(h => !!h.activated).length;
  const openTickets = allSupport.filter(t => t.status === 'open').length;
  const scheduledInstalls = allInstallations.filter(i => i.status === 'scheduled').length;

  document.getElementById('kpiApprovalRate').textContent = safePercent(approvedOrders, processedOrders) + '%';
  document.getElementById('kpiActivationRate').textContent = safePercent(activeHouses, allHouses.length) + '%';
  document.getElementById('kpiOpenTickets').textContent = openTickets;
  document.getElementById('kpiScheduledInstalls').textContent = scheduledInstalls;

  renderPackageDistribution();
  renderActivityFeed();
}

function renderPackageDistribution() {
  const body = document.getElementById('packageStatsBody');
  if (!body) return;

  const total = allHouses.length || 0;
  const packages = [
    { key: 'basic', label: 'تنبيهات فورية + تحكم أساسي' },
    { key: 'premium', label: 'كاميرات + سجلات + تحكم موسع' },
    { key: 'enterprise', label: 'كل الميزات + إدارة متعددة' }
  ];

  body.innerHTML = packages.map(p => {
    const count = allHouses.filter(h => h.package_type === p.key).length;
    const ratio = safePercent(count, total);
    return `
      <tr>
        <td><span class="package-label">${p.label}</span></td>
        <td>${count}</td>
        <td>${ratio}%</td>
        <td class="progress-cell">
          <div class="progress-track">
            <div class="progress-fill" style="width:${ratio}%;"></div>
          </div>
        </td>
      </tr>
    `;
  }).join('');
}

function renderActivityFeed() {
  const target = document.getElementById('activityFeed');
  if (!target) return;

  const feed = [];

  allOrders.forEach(o => {
    feed.push({
      icon: 'OR',
      title: `طلب #${o.id} - ${o.client_name || 'عميل'}`,
      sub: `الحالة: ${o.status || '-'} | الميزات: ${packageLabel(o.package_type)}`,
      date: o.created_at
    });
  });

  allSales.forEach(s => {
    feed.push({
      icon: 'SA',
      title: `مبيعة ${((s.amount || 0).toLocaleString('ar-DZ'))} دج`,
      sub: `${s.client_name || 'عميل'} | كود ${s.house_code || '-'}`,
      date: s.created_at
    });
  });

  allSupport.forEach(t => {
    feed.push({
      icon: 'SU',
      title: `تذكرة دعم #${t.id}`,
      sub: `${t.client_name || 'عميل'} | ${t.issue || '-'}`,
      date: t.created_at
    });
  });

  allInstallations.forEach(i => {
    feed.push({
      icon: 'IN',
      title: `تركيب #${i.id}`,
      sub: `${i.client_name || 'عميل'} | الحالة: ${i.status || '-'}`,
      date: i.install_date || i.created_at
    });
  });

  feed.sort((a, b) => new Date(b.date || 0) - new Date(a.date || 0));
  const top = feed.slice(0, 12);

  if (!top.length) {
    target.innerHTML = '<div class="empty-state" style="padding: 16px;"><p>لا يوجد نشاط حديث بعد</p></div>';
    return;
  }

  target.innerHTML = top.map(item => `
    <div class="activity-item">
      <span class="activity-icon">${item.icon}</span>
      <div>
        <div class="activity-main">${item.title}</div>
        <div class="activity-sub">${item.sub}</div>
      </div>
      <span class="activity-time">${formatDateTime(item.date)}</span>
    </div>
  `).join('');
}

function openGenericDetails(title, entries) {
  const titleNode = document.getElementById('genericDetailTitle');
  const content = document.getElementById('genericDetailContent');
  if (!titleNode || !content) return;

  titleNode.textContent = title;
  content.innerHTML = `
    <div class="details-grid">
      ${entries.map(entry => `
        <div class="details-item">
          <div class="details-label">${entry.label}</div>
          <div class="details-value">${entry.value ?? '-'}</div>
        </div>
      `).join('')}
    </div>
  `;
  openModal('genericDetailModal');
}

function getClientIdentifier(c) {
  return {
    id: c?.id,
    phone: String(c?.phone || '').trim(),
    name: String(c?.name || '').trim(),
    email: String(c?.email || '').trim().toLowerCase()
  };
}

function getClientHouses(c) {
  const key = getClientIdentifier(c);
  return allHouses.filter(h =>
    (key.id && Number(h.client_id) === Number(key.id)) ||
    (key.name && String(h.client_name || '').trim() === key.name)
  );
}

function getClientOrders(c) {
  const key = getClientIdentifier(c);
  return allOrders.filter(o =>
    (key.id && Number(o.client_id) === Number(key.id)) ||
    (key.phone && String(o.phone || '').trim() === key.phone) ||
    (key.name && String(o.client_name || '').trim() === key.name)
  ).sort((a, b) => new Date(b.created_at || 0) - new Date(a.created_at || 0));
}

function getClientSales(c) {
  const houses = getClientHouses(c);
  const houseIds = new Set(houses.map(h => Number(h.id)));
  const houseCodes = new Set(houses.map(h => String(getHouseCode(h))));
  return allSales.filter(s =>
    (s.home_id != null && houseIds.has(Number(s.home_id))) ||
    (s.house_code && houseCodes.has(String(s.house_code))) ||
    (String(s.client_name || '').trim() && String(s.client_name || '').trim() === String(c.name || '').trim())
  );
}

function getClientSupportTickets(c) {
  const houses = getClientHouses(c);
  const houseCodes = new Set(houses.map(h => String(getHouseCode(h))));
  return allSupport.filter(t =>
    (t.house_code && houseCodes.has(String(t.house_code))) ||
    (String(t.client_name || '').trim() && String(t.client_name || '').trim() === String(c.name || '').trim())
  );
}

function getClientInstallations(c) {
  const houses = getClientHouses(c);
  const houseCodes = new Set(houses.map(h => String(getHouseCode(h))));
  return allInstallations.filter(i =>
    (i.house_code && houseCodes.has(String(i.house_code))) ||
    (String(i.client_name || '').trim() && String(i.client_name || '').trim() === String(c.name || '').trim())
  );
}

function viewOrderDetail(id) {
  const o = allOrders.find(x => x.id === id);
  if (!o) return;
  openGenericDetails(`تفاصيل الطلب #${o.id}`, [
    { label: 'العميل', value: o.client_name || '-' },
    { label: 'الهاتف', value: o.phone || '-' },
    { label: 'العنوان', value: o.address || '-' },
    { label: 'كود المنزل', value: o.house_code || '-' },
    { label: 'الميزات', value: packageLabel(o.package_type) },
    { label: 'الحالة', value: o.status || '-' },
    { label: 'التاريخ', value: formatDateTime(o.created_at) }
  ]);
}

function viewClientDetail(id) {
  const c = allClients.find(x => x.id === id);
  if (!c) return;
  const houses = getClientHouses(c);
  const orders = getClientOrders(c);
  const sales = getClientSales(c);
  const support = getClientSupportTickets(c);
  const installations = getClientInstallations(c);

  const totalSales = sales.reduce((sum, s) => sum + (s.amount || 0), 0);
  const approvedOrders = orders.filter(o => o.status === 'approved').length;
  const pendingOrders = orders.filter(o => o.status === 'pending').length;
  const openSupport = support.filter(t => t.status === 'open').length;

  const titleNode = document.getElementById('genericDetailTitle');
  const content = document.getElementById('genericDetailContent');
  if (!titleNode || !content) return;

  titleNode.textContent = `تفاصيل العميل: ${c.name || '-'} (#${c.id})`;
  content.innerHTML = `
    <div class="details-grid" style="margin-bottom:14px;">
      <div class="details-item"><div class="details-label">الهاتف</div><div class="details-value">${c.phone || '-'}</div></div>
      <div class="details-item"><div class="details-label">البريد</div><div class="details-value">${c.email || '-'}</div></div>
      <div class="details-item"><div class="details-label">العنوان</div><div class="details-value">${c.address || '-'}</div></div>
      <div class="details-item"><div class="details-label">تاريخ التسجيل</div><div class="details-value">${formatDateTime(c.created_at)}</div></div>
    </div>

    <div class="details-grid" style="margin-bottom:18px;">
      <div class="details-item"><div class="details-label">عدد المنازل</div><div class="details-value">${houses.length}</div></div>
      <div class="details-item"><div class="details-label">إجمالي الطلبات</div><div class="details-value">${orders.length}</div></div>
      <div class="details-item"><div class="details-label">طلبات معلّقة</div><div class="details-value">${pendingOrders}</div></div>
      <div class="details-item"><div class="details-label">طلبات مقبولة</div><div class="details-value">${approvedOrders}</div></div>
      <div class="details-item"><div class="details-label">إجمالي المبيعات</div><div class="details-value">${totalSales.toLocaleString('ar-DZ')} دج</div></div>
      <div class="details-item"><div class="details-label">تذاكر دعم مفتوحة</div><div class="details-value">${openSupport}</div></div>
    </div>

    <h4 style="margin:0 0 8px 0;">المنازل</h4>
    <table class="data-table" style="margin-bottom:14px;">
      <thead><tr><th>الكود</th><th>العنوان</th><th>الميزات</th><th>الحالة</th></tr></thead>
      <tbody>
        ${houses.length ? houses.map(h => `
          <tr>
            <td>${getHouseCode(h)}</td>
            <td>${h.address || '-'}</td>
            <td>${packageLabel(h.package_type)}</td>
            <td>${h.activated ? 'مفعّل' : 'غير مفعّل'}</td>
          </tr>
        `).join('') : '<tr><td colspan="4" style="text-align:center;">لا توجد منازل</td></tr>'}
      </tbody>
    </table>

    <h4 style="margin:0 0 8px 0;">آخر الطلبات</h4>
    <table class="data-table" style="margin-bottom:14px;">
      <thead><tr><th>#</th><th>الميزات</th><th>الحالة</th><th>التاريخ</th></tr></thead>
      <tbody>
        ${orders.slice(0, 5).length ? orders.slice(0, 5).map(o => `
          <tr>
            <td>${o.id}</td>
            <td>${packageLabel(o.package_type)}</td>
            <td>${statusBadge(o.status)}</td>
            <td>${formatDate(o.created_at)}</td>
          </tr>
        `).join('') : '<tr><td colspan="4" style="text-align:center;">لا توجد طلبات</td></tr>'}
      </tbody>
    </table>

    <h4 style="margin:0 0 8px 0;">آخر المبيعات</h4>
    <table class="data-table" style="margin-bottom:14px;">
      <thead><tr><th>#</th><th>القيمة</th><th>ملاحظات</th><th>التاريخ</th></tr></thead>
      <tbody>
        ${sales.slice(0, 5).length ? sales.slice(0, 5).map(s => `
          <tr>
            <td>${s.id || '-'}</td>
            <td>${(s.amount || 0).toLocaleString('ar-DZ')} دج</td>
            <td>${s.notes || '-'}</td>
            <td>${formatDate(s.created_at)}</td>
          </tr>
        `).join('') : '<tr><td colspan="4" style="text-align:center;">لا توجد مبيعات</td></tr>'}
      </tbody>
    </table>

    <h4 style="margin:0 0 8px 0;">الدعم والتركيب</h4>
    <table class="data-table">
      <thead><tr><th>النوع</th><th>الوصف</th><th>الحالة</th><th>التاريخ</th></tr></thead>
      <tbody>
        ${[
          ...support.slice(0, 3).map(t => ({ type: 'دعم', desc: t.issue || '-', status: t.status || '-', date: t.created_at })),
          ...installations.slice(0, 3).map(i => ({ type: 'تركيب', desc: i.address || i.house_code || '-', status: i.status || '-', date: i.install_date || i.created_at }))
        ].length ? [
          ...support.slice(0, 3).map(t => ({ type: 'دعم', desc: t.issue || '-', status: t.status || '-', date: t.created_at })),
          ...installations.slice(0, 3).map(i => ({ type: 'تركيب', desc: i.address || i.house_code || '-', status: i.status || '-', date: i.install_date || i.created_at }))
        ].map(r => `
          <tr>
            <td>${r.type}</td>
            <td>${r.desc}</td>
            <td>${statusBadge(r.status)}</td>
            <td>${formatDate(r.date)}</td>
          </tr>
        `).join('') : '<tr><td colspan="4" style="text-align:center;">لا توجد سجلات</td></tr>'}
      </tbody>
    </table>
  `;
  openModal('genericDetailModal');
}

function viewSaleDetail(id) {
  const s = allSales.find(x => (x.id || 0) === id) || allSales[id - 1];
  if (!s) return;
  openGenericDetails(`تفاصيل المبيعة #${s.id || id}`, [
    { label: 'العميل', value: s.client_name || '-' },
    { label: 'كود المنزل', value: s.house_code || '-' },
    { label: 'الميزات', value: packageLabel(s.package_type) },
    { label: 'المبلغ', value: `${(s.amount || 0).toLocaleString('ar-DZ')} دج` },
    { label: 'ملاحظات', value: s.notes || '-' },
    { label: 'تاريخ التسجيل', value: formatDateTime(s.created_at) }
  ]);
}

function viewSupportDetail(id) {
  const t = allSupport.find(x => x.id === id);
  if (!t) return;
  openGenericDetails(`تفاصيل تذكرة الدعم #${t.id}`, [
    { label: 'العميل', value: t.client_name || '-' },
    { label: 'كود المنزل', value: t.house_code || '-' },
    { label: 'المشكلة', value: t.issue || '-' },
    { label: 'الحالة', value: t.status || '-' },
    { label: 'التاريخ', value: formatDateTime(t.created_at) }
  ]);
}

function viewInstallDetail(id) {
  const i = allInstallations.find(x => x.id === id);
  if (!i) return;
  openGenericDetails(`تفاصيل التركيب #${i.id}`, [
    { label: 'العميل', value: i.client_name || '-' },
    { label: 'كود المنزل', value: i.house_code || '-' },
    { label: 'العنوان', value: i.address || '-' },
    { label: 'الحالة', value: i.status || '-' },
    { label: 'تاريخ التركيب', value: formatDateTime(i.install_date) }
  ]);
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
  await loadAppUsers();
  await loadEmployees();
  renderHouses(allHouses);
  refreshDetailedDashboard();
}

loadAll();
