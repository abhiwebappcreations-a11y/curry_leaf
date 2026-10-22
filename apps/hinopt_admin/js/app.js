// Hinopt Admin Application Controller
document.addEventListener('DOMContentLoaded', function () {
  initApp();
});

let currentTab = 'overview';
let activeFilter = '';

async function initApp() {
  setupNavigation();
  setupEventListeners();
  renderAll();

  if (window.SupabaseClient) {
    try {
      const liveRests = await window.SupabaseClient.fetchRestaurants();
      const liveLics = await window.SupabaseClient.fetchLicenses();
      if (liveRests && liveRests.length > 0) {
        const merged = liveRests.map(r => {
          const lic = (liveLics || []).find(l => l.restaurant_id === r.id);
          return {
            id: r.id,
            name: r.name,
            city: r.city,
            contactName: r.contact_name,
            phone: r.phone,
            hwid: r.hwid,
            licenseKey: lic ? lic.license_key : (r.id),
            status: lic ? lic.status : 'ACTIVE',
            issuedAt: lic && lic.valid_from ? lic.valid_from.split('T')[0] : '2026-10-17',
            expiresAt: lic && lic.valid_until ? lic.valid_until.split('T')[0] : '2027-10-17',
            counterIp: r.counter_ip || '192.168.1.100',
            notes: r.notes || ''
          };
        });
        window.HinoptData.restaurants = merged;
        renderAll();
        console.log('[Hinopt Admin] Live Supabase cloud records synced successfully');
      }
    } catch (e) {
      console.warn('[Hinopt Admin] Live sync fallback:', e);
    }
  }
}

function setupNavigation() {
  const navItems = document.querySelectorAll('.nav-item');
  navItems.forEach(item => {
    item.addEventListener('click', function () {
      navItems.forEach(n => n.classList.remove('active'));
      this.classList.add('active');

      const targetTab = this.getAttribute('data-tab');
      switchTab(targetTab);
    });
  });
}

function switchTab(tabName) {
  currentTab = tabName;
  document.querySelectorAll('.tab-view').forEach(view => {
    view.classList.remove('active');
  });

  const activeView = document.getElementById(`tab-${tabName}`);
  if (activeView) activeView.classList.add('active');

  const titles = {
    overview: 'Operations Overview & License Health',
    restaurants: 'Client Restaurants Directory',
    licenses: 'License Token Issuance & Lifecycle',
    audit: 'Immutable Security & Administrative Audit Logs',
    security: 'Cloud Signing Keys & Protocol Info'
  };
  document.getElementById('header-title').textContent = titles[tabName] || 'Hinopt Admin';

  renderAll();
}

function setupEventListeners() {
  // Search inputs
  const searchRest = document.getElementById('search-restaurants');
  if (searchRest) {
    searchRest.addEventListener('input', function (e) {
      activeFilter = e.target.value.toLowerCase();
      renderRestaurants();
    });
  }

  // Register Form
  const regForm = document.getElementById('form-register-restaurant');
  if (regForm) {
    regForm.addEventListener('submit', function (e) {
      e.preventDefault();
      const name = document.getElementById('reg-name').value.trim();
      const city = document.getElementById('reg-city').value.trim();
      const contactName = document.getElementById('reg-contact').value.trim();
      const phone = document.getElementById('reg-phone').value.trim();
      const hwid = document.getElementById('reg-hwid').value.trim();
      const notes = document.getElementById('reg-notes').value.trim();

      if (name) {
        window.LicenseService.registerRestaurant({ name, city, contactName, phone, hwid, notes });
        closeModal('modal-register');
        regForm.reset();
        renderAll();
        showToast(`Restaurant "${name}" registered and 1-Year license issued!`);
      }
    });
  }
}

function renderAll() {
  renderKpis();
  renderRestaurants();
  renderLicenses();
  renderAuditLogs();
}

function renderKpis() {
  const restaurants = window.HinoptData.restaurants;
  const activeCount = restaurants.filter(r => r.status === 'ACTIVE').length;
  const expiringCount = restaurants.filter(r => r.status === 'EXPIRING_SOON').length;
  const suspendedCount = restaurants.filter(r => r.status === 'SUSPENDED').length;
  const totalCount = restaurants.length;

  document.getElementById('kpi-active').textContent = activeCount;
  document.getElementById('kpi-expiring').textContent = expiringCount;
  document.getElementById('kpi-suspended').textContent = suspendedCount;
  document.getElementById('kpi-total').textContent = totalCount;
}

function renderRestaurants() {
  const tbody = document.getElementById('table-restaurants-body');
  if (!tbody) return;

  const data = window.HinoptData.restaurants.filter(r => {
    if (!activeFilter) return true;
    return r.name.toLowerCase().includes(activeFilter) ||
           r.city.toLowerCase().includes(activeFilter) ||
           r.hwid.toLowerCase().includes(activeFilter);
  });

  tbody.innerHTML = data.map(r => {
    const badgeClass = r.status === 'ACTIVE' ? 'badge-success' : (r.status === 'EXPIRING_SOON' ? 'badge-warning' : 'badge-danger');
    return `
      <tr>
        <td>
          <div style="font-weight: 800; font-size: 14px;">${r.name}</div>
          <div style="font-size: 11px; color: var(--text-secondary);">${r.city}</div>
        </td>
        <td>
          <div style="font-weight: 600;">${r.contactName}</div>
          <div style="font-size: 11px; color: var(--text-secondary);">${r.phone}</div>
        </td>
        <td>
          <code style="background: var(--surface-muted); padding: 2px 6px; border-radius: 4px; font-size: 11px;">${r.hwid}</code>
        </td>
        <td>
          <span class="badge ${badgeClass}">${r.status}</span>
        </td>
        <td>
          <div style="font-size: 12px; font-weight: 600;">${r.expiresAt}</div>
        </td>
        <td>
          <button class="btn btn-outline btn-sm" onclick="openLicenseModal('${r.id}')">View License</button>
        </td>
      </tr>
    `;
  }).join('');
}

function renderLicenses() {
  const tbody = document.getElementById('table-licenses-body');
  if (!tbody) return;

  tbody.innerHTML = window.HinoptData.restaurants.map(r => {
    const badgeClass = r.status === 'ACTIVE' ? 'badge-success' : (r.status === 'EXPIRING_SOON' ? 'badge-warning' : 'badge-danger');
    return `
      <tr>
        <td>
          <div style="font-weight: 800;">${r.name}</div>
          <div style="font-size: 11px; color: var(--text-secondary);">ID: ${r.id}</div>
        </td>
        <td>
          <code style="background: var(--surface-muted); padding: 3px 6px; border-radius: 4px; font-size: 12px; font-weight: 700;">${r.licenseKey}</code>
        </td>
        <td>
          <span class="badge ${badgeClass}">${r.status}</span>
        </td>
        <td>
          <div style="font-size: 12px; font-weight: 700;">${r.expiresAt}</div>
          <div style="font-size: 10px; color: var(--text-muted);">Issued: ${r.issuedAt}</div>
        </td>
        <td>
          <div style="display: flex; gap: 6px;">
            <button class="btn btn-outline btn-sm" onclick="renewRestaurantLicense('${r.id}')">Renew +1Y</button>
            <button class="btn ${r.status === 'SUSPENDED' ? 'btn-success' : 'btn-danger'} btn-sm" onclick="toggleRestaurantSuspension('${r.id}')">
              ${r.status === 'SUSPENDED' ? 'Reactivate' : 'Suspend'}
            </button>
            <button class="btn btn-outline btn-sm" onclick="downloadSignedToken('${r.id}')" title="Download signed license.json">Download</button>
          </div>
        </td>
      </tr>
    `;
  }).join('');
}

function renderAuditLogs() {
  const tbody = document.getElementById('table-audit-body');
  if (!tbody) return;

  tbody.innerHTML = window.HinoptData.auditLogs.map(log => {
    return `
      <tr>
        <td>
          <div style="font-weight: 700; font-size: 11px; letter-spacing: 0.5px;">${log.action}</div>
        </td>
        <td>
          <div style="font-weight: 600;">${log.restaurantName}</div>
        </td>
        <td>
          <div style="font-size: 12px; color: var(--text-secondary);">${log.details}</div>
        </td>
        <td>
          <div style="font-size: 11px; color: var(--text-muted);">${log.operator}</div>
        </td>
        <td>
          <div style="font-size: 11px; font-weight: 600;">${log.timestamp}</div>
        </td>
      </tr>
    `;
  }).join('');
}

// Modal & Action Helpers
window.openModal = function (id) {
  const modal = document.getElementById(id);
  if (modal) modal.classList.add('active');
};

window.closeModal = function (id) {
  const modal = document.getElementById(id);
  if (modal) modal.classList.remove('active');
};

window.openLicenseModal = function (restaurantId) {
  const r = window.HinoptData.restaurants.find(item => item.id === restaurantId);
  if (!r) return;

  const payload = window.LicenseService.generateSignedPayload(r);

  document.getElementById('modal-license-name').textContent = r.name;
  document.getElementById('modal-license-json').textContent = JSON.stringify(payload, null, 2);
  document.getElementById('modal-download-btn').onclick = function () {
    window.LicenseService.downloadLicenseFile(r);
  };

  openModal('modal-license-details');
};

window.renewRestaurantLicense = function (restaurantId) {
  const r = window.HinoptData.restaurants.find(item => item.id === restaurantId);
  if (!r) return;

  if (confirm(`Renew license for ${r.name} for 1 Year?`)) {
    window.LicenseService.renewLicense(restaurantId, 1);
    renderAll();
    showToast(`License renewed for ${r.name} successfully! New expiry: ${r.expiresAt}`);
  }
};

window.toggleRestaurantSuspension = function (restaurantId) {
  const r = window.HinoptData.restaurants.find(item => item.id === restaurantId);
  if (!r) return;

  const willSuspend = r.status !== 'SUSPENDED';
  const reason = prompt(`Enter reason for ${willSuspend ? 'suspension' : 'reactivation'}:`, willSuspend ? 'Non-payment of subscription' : 'Account cleared');

  if (reason) {
    window.LicenseService.toggleSuspension(restaurantId, reason);
    renderAll();
    showToast(`Restaurant ${r.name} has been ${willSuspend ? 'suspended' : 'reactivated'}.`);
  }
};

window.downloadSignedToken = function (restaurantId) {
  const r = window.HinoptData.restaurants.find(item => item.id === restaurantId);
  if (r) {
    window.LicenseService.downloadLicenseFile(r);
    showToast(`Signed license file downloaded for ${r.name}.`);
  }
};

function showToast(message) {
  const toast = document.createElement('div');
  toast.style.position = 'fixed';
  toast.style.bottom = '24px';
  toast.style.right = '24px';
  toast.style.background = 'var(--primary)';
  toast.style.color = 'white';
  toast.style.padding = '12px 20px';
  toast.style.borderRadius = '8px';
  toast.style.boxShadow = '0 6px 16px rgba(0,0,0,0.15)';
  toast.style.fontSize = '13px';
  toast.style.fontWeight = '700';
  toast.style.zIndex = '9999';
  toast.style.transition = 'all 0.3s ease';
  toast.textContent = message;

  document.body.appendChild(toast);
  setTimeout(() => {
    toast.style.opacity = '0';
    toast.style.transform = 'translateY(10px)';
    setTimeout(() => toast.remove(), 300);
  }, 3000);
}
