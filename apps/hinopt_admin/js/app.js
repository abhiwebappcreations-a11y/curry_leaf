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
      const [liveRests, liveLics, liveAudits] = await Promise.all([
        window.SupabaseClient.fetchRestaurants(),
        window.SupabaseClient.fetchLicenses(),
        window.SupabaseClient.fetchAuditLogs()
      ]);

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
            licenseKey: lic ? lic.license_key : r.id,
            status: lic ? lic.status : 'ACTIVE',
            issuedAt: lic && lic.valid_from ? lic.valid_from.split('T')[0] : '2026-10-17',
            expiresAt: lic && lic.valid_until ? lic.valid_until.split('T')[0] : '2027-10-17',
            counterIp: r.counter_ip || '192.168.1.100',
            maxDevices: lic && lic.max_devices ? lic.max_devices : 10,
            notes: r.notes || ''
          };
        });
        window.HinoptData.restaurants = merged;
      }

      if (liveAudits && liveAudits.length > 0) {
        window.HinoptData.auditLogs = liveAudits.map(a => ({
          id: a.id,
          action: a.action,
          restaurantName: a.restaurant_name,
          operator: a.operator,
          timestamp: new Date(a.timestamp).toLocaleString(),
          details: a.details
        }));
      }

      renderAll();
      console.log('[Hinopt Admin] Live Supabase cloud sync complete');
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
    regForm.addEventListener('submit', async function (e) {
      e.preventDefault();
      const name = document.getElementById('reg-name').value.trim();
      const city = document.getElementById('reg-city').value.trim();
      const contactName = document.getElementById('reg-contact').value.trim();
      const phone = document.getElementById('reg-phone').value.trim();
      const hwid = document.getElementById('reg-hwid').value.trim();
      const counterIp = document.getElementById('reg-ip') ? document.getElementById('reg-ip').value.trim() : '192.168.1.100';
      const expiresAt = document.getElementById('reg-expiry') ? document.getElementById('reg-expiry').value : null;
      const maxDevices = document.getElementById('reg-devices') ? document.getElementById('reg-devices').value : 10;
      const notes = document.getElementById('reg-notes').value.trim();

      if (name) {
        showToast(`Registering "${name}" in Supabase...`);
        const newRest = await window.LicenseService.registerRestaurant({
          name, city, contactName, phone, hwid, counterIp, expiresAt, maxDevices, notes
        });
        closeModal('modal-register');
        regForm.reset();
        renderAll();
        showToast(`Restaurant "${name}" registered and saved to Supabase Cloud!`);
      }
    });
  }

  // Edit Form
  const editForm = document.getElementById('form-edit-restaurant');
  if (editForm) {
    editForm.addEventListener('submit', async function (e) {
      e.preventDefault();
      const id = document.getElementById('edit-id').value;
      const name = document.getElementById('edit-name').value.trim();
      const city = document.getElementById('edit-city').value.trim();
      const contactName = document.getElementById('edit-contact').value.trim();
      const phone = document.getElementById('edit-phone').value.trim();
      const hwid = document.getElementById('edit-hwid').value.trim();
      const counterIp = document.getElementById('edit-ip').value.trim();
      const status = document.getElementById('edit-status').value;
      const expiresAt = document.getElementById('edit-expiry').value;
      const maxDevices = document.getElementById('edit-devices').value;
      const notes = document.getElementById('edit-notes').value.trim();

      showToast(`Saving changes for "${name}" to Supabase...`);
      await window.LicenseService.updateRestaurantDetails(id, {
        name, city, contactName, phone, hwid, counterIp, status, expiresAt, maxDevices, notes
      });

      closeModal('modal-edit-restaurant');
      renderAll();
      showToast(`Restaurant "${name}" updated successfully (Cloud Synced)!`);
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

  const badgeRest = document.getElementById('badge-rest-count');
  if (badgeRest) badgeRest.textContent = totalCount;
  const badgeExp = document.getElementById('badge-expiring-count');
  if (badgeExp) badgeExp.textContent = expiringCount + suspendedCount;
}

function renderRestaurants() {
  const tbody = document.getElementById('table-restaurants-body');
  const fullTbody = document.getElementById('table-restaurants-full-body');

  const data = window.HinoptData.restaurants.filter(r => {
    if (!activeFilter) return true;
    return r.name.toLowerCase().includes(activeFilter) ||
           r.city.toLowerCase().includes(activeFilter) ||
           r.hwid.toLowerCase().includes(activeFilter);
  });

  // Overview table (Tab 1)
  if (tbody) {
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
            <div style="display: flex; gap: 6px;">
              <button class="btn btn-primary btn-sm" onclick="openEditModal('${r.id}')" title="Edit details, expiry, status">
                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M12 20h9"></path><path d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4L16.5 3.5z"></path></svg>
                <span>Edit</span>
              </button>
              <button class="btn btn-outline btn-sm" onclick="openLicenseModal('${r.id}')">License</button>
            </div>
          </td>
        </tr>
      `;
    }).join('');
  }

  // Full Directory table (Tab 2)
  if (fullTbody) {
    fullTbody.innerHTML = data.map(r => {
      const badgeClass = r.status === 'ACTIVE' ? 'badge-success' : (r.status === 'EXPIRING_SOON' ? 'badge-warning' : 'badge-danger');
      return `
        <tr>
          <td>
            <div style="font-weight: 800; font-size: 14px;">${r.name}</div>
            <div style="font-size: 11px; color: var(--text-secondary);">${r.city} &bull; IP: ${r.counterIp || '192.168.1.100'}</div>
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
            <div style="display: flex; gap: 6px; flex-wrap: wrap;">
              <button class="btn btn-primary btn-sm" onclick="openEditModal('${r.id}')">
                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M12 20h9"></path><path d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4L16.5 3.5z"></path></svg>
                <span>Edit / Manage</span>
              </button>
              <button class="btn ${r.status === 'SUSPENDED' ? 'btn-success' : 'btn-danger'} btn-sm" onclick="toggleRestaurantSuspension('${r.id}')">
                ${r.status === 'SUSPENDED' ? 'Reactivate' : 'Suspend'}
              </button>
              <button class="btn btn-outline btn-sm" onclick="openLicenseModal('${r.id}')">Token</button>
            </div>
          </td>
        </tr>
      `;
    }).join('');
  }
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
          <div style="font-size: 11px; color: var(--text-secondary);">ID: ${r.id} &bull; Max Devices: ${r.maxDevices || 10}</div>
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
          <div style="display: flex; gap: 6px; flex-wrap: wrap;">
            <button class="btn btn-primary btn-sm" onclick="openEditModal('${r.id}')" title="Edit custom expiry date or status">
              <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="4" width="18" height="18" rx="2" ry="2"></rect><line x1="16" y1="2" x2="16" y2="6"></line><line x1="8" y1="2" x2="8" y2="6"></line><line x1="3" y1="10" x2="21" y2="10"></line></svg>
              <span>Edit Expiry</span>
            </button>
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

// Open Edit Modal for a restaurant
window.openEditModal = function (restaurantId) {
  const r = window.HinoptData.restaurants.find(item => item.id === restaurantId);
  if (!r) return;

  document.getElementById('edit-id').value = r.id;
  document.getElementById('edit-header-name').textContent = r.name;
  document.getElementById('edit-name').value = r.name || '';
  document.getElementById('edit-city').value = r.city || '';
  document.getElementById('edit-contact').value = r.contactName || '';
  document.getElementById('edit-phone').value = r.phone || '';
  document.getElementById('edit-hwid').value = r.hwid || '';
  document.getElementById('edit-ip').value = r.counterIp || '192.168.1.100';
  document.getElementById('edit-status').value = r.status || 'ACTIVE';
  document.getElementById('edit-expiry').value = r.expiresAt || '';
  document.getElementById('edit-devices').value = r.maxDevices || 10;
  document.getElementById('edit-notes').value = r.notes || '';

  openModal('modal-edit-restaurant');
};

// Quick Expiry buttons inside Edit Modal
window.setQuickExpiry = function (days) {
  const expiryInput = document.getElementById('edit-expiry');
  const statusSelect = document.getElementById('edit-status');
  if (days === 0) {
    const today = new Date().toISOString().split('T')[0];
    expiryInput.value = today;
    statusSelect.value = 'SUSPENDED';
    showToast('Expiry set to TODAY & status set to SUSPENDED. POS will lock on next request.');
  } else {
    const future = new Date(Date.now() + days * 86400000).toISOString().split('T')[0];
    expiryInput.value = future;
    statusSelect.value = 'ACTIVE';
  }
};

// Delete Current Restaurant in Edit Modal
window.deleteCurrentRestaurant = async function () {
  const id = document.getElementById('edit-id').value;
  const r = window.HinoptData.restaurants.find(item => item.id === id);
  if (!r) return;

  const confirmed = confirm(`Are you sure you want to permanently delete "${r.name}"?\n\nThis will revoke their license immediately and erase their cloud record in Supabase.`);
  if (!confirmed) return;

  showToast(`Deleting "${r.name}" from Supabase...`);
  await window.LicenseService.deleteRestaurant(id);
  closeModal('modal-edit-restaurant');
  renderAll();
  showToast(`Restaurant "${r.name}" permanently deleted.`);
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

window.renewRestaurantLicense = async function (restaurantId) {
  const r = window.HinoptData.restaurants.find(item => item.id === restaurantId);
  if (!r) return;

  if (confirm(`Renew license for ${r.name} for 1 Year?`)) {
    showToast(`Renewing license for ${r.name}...`);
    await window.LicenseService.renewLicense(restaurantId, 1);
    renderAll();
    showToast(`License renewed for ${r.name} successfully! New expiry: ${r.expiresAt}`);
  }
};

window.toggleRestaurantSuspension = async function (restaurantId) {
  const r = window.HinoptData.restaurants.find(item => item.id === restaurantId);
  if (!r) return;

  const willSuspend = r.status !== 'SUSPENDED';
  const reason = prompt(`Enter reason for ${willSuspend ? 'suspension' : 'reactivation'}:`, willSuspend ? 'Non-payment of subscription' : 'Account cleared');

  if (reason) {
    showToast(`${willSuspend ? 'Suspending' : 'Reactivating'} in Supabase...`);
    await window.LicenseService.toggleSuspension(restaurantId, reason);
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

window.autoDetectHwid = async function (targetInputId) {
  try {
    showToast('Detecting machine hardware UUID...');
    const res = await fetch('/api/system-hwid');
    const data = await res.json();
    if (data.hwid) {
      document.getElementById(targetInputId).value = data.hwid;
      showToast(`Detected PC Hardware ID: ${data.hwid}`);
    }
  } catch (e) {
    showToast('Could not auto-detect. Please paste HWID from PowerShell.');
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
  toast.style.boxShadow = '0 6px 16px rgba(0,0,0,0.2)';
  toast.style.fontSize = '13px';
  toast.style.fontWeight = '700';
  toast.style.zIndex = '99999';
  toast.style.transition = 'all 0.3s ease';
  toast.textContent = message;

  document.body.appendChild(toast);
  setTimeout(() => {
    toast.style.opacity = '0';
    toast.style.transform = 'translateY(10px)';
    setTimeout(() => toast.remove(), 300);
  }, 3500);
}
