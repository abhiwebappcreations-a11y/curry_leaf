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

      if (liveRests !== null && Array.isArray(liveRests)) {
        const merged = liveRests.map(r => {
          const lic = (liveLics || []).find(l => l.restaurant_id === r.id);
          const payload = (lic && lic.signed_payload) ? lic.signed_payload : {};
          const limits = payload.limits || {};
          const menuLimit = limits.menuItems !== undefined ? parseInt(limits.menuItems, 10) : 100;
          const captainLimit = limits.captainDevices !== undefined ? parseInt(limits.captainDevices, 10) : (lic && lic.max_devices ? parseInt(lic.max_devices, 10) : 5);
          const counterLimit = limits.counterPcs !== undefined ? parseInt(limits.counterPcs, 10) : 1;

          const isOnlineOrdering = Boolean(
            payload.onlineOrderingEnabled ||
            payload.online_ordering_enabled ||
            (lic && lic.features && lic.features.includes('ONLINE_ORDERING'))
          );
          const storeSlug = payload.storeSlug || (r.name ? r.name.toLowerCase().replace(/[^a-z0-9]/g, '') : 'store');
          const customDomain = payload.customDomain || '';
          const storeUrl = payload.storeUrl || (customDomain ? `https://${customDomain}` : `https://orders.hinopt.com/${storeSlug}`);

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
            maxDevices: captainLimit,
            menuItemsLimit: menuLimit,
            captainDevicesLimit: captainLimit,
            counterPcsLimit: counterLimit,
            limits: {
              menuItems: menuLimit,
              captainDevices: captainLimit,
              counterPcs: counterLimit,
            },
            onlineOrderingEnabled: isOnlineOrdering,
            storeSlug: storeSlug,
            customDomain: customDomain,
            storeUrl: storeUrl,
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
    upgrades: 'Client License Limits Upgrade Requests',
    backups: 'Restaurant Cloud Backups (Partitioned by Restaurant ID)',
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
      const menuItemsLimit = document.getElementById('reg-limit-menu') ? parseInt(document.getElementById('reg-limit-menu').value, 10) : 100;
      const captainDevicesLimit = document.getElementById('reg-limit-captains') ? parseInt(document.getElementById('reg-limit-captains').value, 10) : 5;
      const counterPcsLimit = document.getElementById('reg-limit-counters') ? parseInt(document.getElementById('reg-limit-counters').value, 10) : 1;
      const maxDevices = captainDevicesLimit;
      const notes = document.getElementById('reg-notes').value.trim();
      const onlineOrderingEnabled = document.getElementById('reg-plan-delivery') ? document.getElementById('reg-plan-delivery').checked : false;
      const customDomain = document.getElementById('reg-custom-domain') ? document.getElementById('reg-custom-domain').value.trim() : '';
      const storeSlug = name.toLowerCase().replace(/[^a-z0-9]/g, '') || 'store';
      const storeUrl = customDomain ? `https://${customDomain}` : `https://orders.hinopt.com/${storeSlug}`;

      if (name) {
        showToast(`Registering "${name}" in Supabase...`);
        const newRest = await window.LicenseService.registerRestaurant({
          name, city, contactName, phone, hwid, counterIp, expiresAt, maxDevices, menuItemsLimit, captainDevicesLimit, counterPcsLimit, notes,
          onlineOrderingEnabled, customDomain, storeSlug, storeUrl
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
      const menuItemsLimit = document.getElementById('edit-limit-menu') ? parseInt(document.getElementById('edit-limit-menu').value, 10) : 100;
      const captainDevicesLimit = document.getElementById('edit-limit-captains') ? parseInt(document.getElementById('edit-limit-captains').value, 10) : 5;
      const counterPcsLimit = document.getElementById('edit-limit-counters') ? parseInt(document.getElementById('edit-limit-counters').value, 10) : 1;
      const maxDevices = captainDevicesLimit;
      const notes = document.getElementById('edit-notes').value.trim();
      const onlineOrderingEnabled = document.getElementById('edit-plan-delivery') ? document.getElementById('edit-plan-delivery').checked : false;
      const customDomain = document.getElementById('edit-custom-domain') ? document.getElementById('edit-custom-domain').value.trim() : '';
      const storeSlug = name.toLowerCase().replace(/[^a-z0-9]/g, '') || 'store';
      const storeUrl = customDomain ? `https://${customDomain}` : `https://orders.hinopt.com/${storeSlug}`;

      showToast(`Saving changes for "${name}" to Supabase...`);
      await window.LicenseService.updateRestaurantDetails(id, {
        name, city, contactName, phone, hwid, counterIp, status, expiresAt, maxDevices, menuItemsLimit, captainDevicesLimit, counterPcsLimit, notes,
        onlineOrderingEnabled, customDomain, storeSlug, storeUrl
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
  fetchUpgradeRequests();
  fetchCloudBackups();
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
            ${r.onlineOrderingEnabled ? `
              <div style="margin-top: 4px; display: flex; flex-direction: column; gap: 2px;">
                <span style="display: inline-flex; align-items: center; gap: 4px; font-size: 10px; background: #ecfdf5; color: #047857; border: 1px solid #a7f3d0; padding: 1px 6px; border-radius: 10px; font-weight: 700; width: fit-content;">
                  🛵 Online Delivery Active
                </span>
                <span style="font-size: 10px; color: #0284c7; font-family: monospace;">
                  ${r.customDomain ? `🌐 ${r.customDomain}` : (r.storeSlug ? `🌐 orders.hinopt.com/${r.storeSlug}` : '')}
                </span>
              </div>
            ` : `
              <div style="margin-top: 3px;">
                <span style="font-size: 10px; background: #f1f5f9; color: #64748b; padding: 1px 6px; border-radius: 10px; font-weight: 600;">
                  Billing Only
                </span>
              </div>
            `}
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
            ${r.onlineOrderingEnabled ? `
              <div style="margin-top: 4px; display: flex; flex-direction: column; gap: 2px;">
                <span style="display: inline-flex; align-items: center; gap: 4px; font-size: 10px; background: #ecfdf5; color: #047857; border: 1px solid #a7f3d0; padding: 1px 6px; border-radius: 10px; font-weight: 700; width: fit-content;">
                  🛵 Online Delivery Active
                </span>
                <span style="font-size: 10px; color: #0284c7; font-family: monospace;">
                  ${r.customDomain ? `🌐 ${r.customDomain}` : (r.storeSlug ? `🌐 orders.hinopt.com/${r.storeSlug}` : '')}
                </span>
              </div>
            ` : `
              <div style="margin-top: 3px;">
                <span style="font-size: 10px; background: #f1f5f9; color: #64748b; padding: 1px 6px; border-radius: 10px; font-weight: 600;">
                  Billing Only
                </span>
              </div>
            `}
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
          <div style="font-size: 11px; color: var(--text-secondary);">Limits: ${r.menuItemsLimit || r.limits?.menuItems || 100} dishes &bull; ${r.captainDevicesLimit || r.limits?.captainDevices || r.maxDevices || 5} captains &bull; ${r.counterPcsLimit || r.limits?.counterPcs || 1} counter</div>
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

// Plan & Delivery Module Helpers
window.toggleDeliveryOptions = function(prefix) {
  const checkbox = document.getElementById(`${prefix}-plan-delivery`);
  if (!checkbox) return;
  const isChecked = checkbox.checked;
  const settingsDiv = document.getElementById(`${prefix}-delivery-settings`);
  const storeUrlInput = document.getElementById(`${prefix}-store-url`);
  const nameInput = document.getElementById(`${prefix}-name`);

  if (settingsDiv) {
    settingsDiv.style.display = isChecked ? 'block' : 'none';
  }

  if (isChecked && storeUrlInput) {
    const rawName = nameInput ? nameInput.value.trim() : 'store';
    const slug = rawName.toLowerCase().replace(/[^a-z0-9]/g, '') || 'store';
    storeUrlInput.value = `https://orders.hinopt.com/${slug}`;
  }
  window.updateDnsHelper(prefix);
};

window.updateDnsHelper = function(prefix) {
  const customDomainInput = document.getElementById(`${prefix}-custom-domain`);
  const helperBox = document.getElementById(`${prefix}-dns-helper`);
  const hostSpan = document.getElementById(`${prefix}-dns-host`);

  if (!customDomainInput || !helperBox || !hostSpan) return;

  const val = customDomainInput.value.trim().toLowerCase();
  if (val && val.includes('.')) {
    const parts = val.split('.');
    const host = parts.length > 2 ? parts[0] : val;
    hostSpan.textContent = host;
    helperBox.style.display = 'block';
  } else {
    helperBox.style.display = 'none';
  }
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
  if (document.getElementById('edit-limit-menu')) document.getElementById('edit-limit-menu').value = r.menuItemsLimit || r.limits?.menuItems || 100;
  if (document.getElementById('edit-limit-captains')) document.getElementById('edit-limit-captains').value = r.captainDevicesLimit || r.limits?.captainDevices || r.maxDevices || 5;
  if (document.getElementById('edit-limit-counters')) document.getElementById('edit-limit-counters').value = r.counterPcsLimit || r.limits?.counterPcs || 1;
  if (document.getElementById('edit-devices')) document.getElementById('edit-devices').value = r.captainDevicesLimit || r.maxDevices || 5;
  document.getElementById('edit-notes').value = r.notes || '';

  const isOnline = Boolean(r.onlineOrderingEnabled);
  const editDeliveryCheckbox = document.getElementById('edit-plan-delivery');
  if (editDeliveryCheckbox) {
    editDeliveryCheckbox.checked = isOnline;
  }
  const editDomainInput = document.getElementById('edit-custom-domain');
  if (editDomainInput) {
    editDomainInput.value = r.customDomain || '';
  }
  const editStoreUrl = document.getElementById('edit-store-url');
  if (editStoreUrl) {
    const slug = r.storeSlug || (r.name ? r.name.toLowerCase().replace(/[^a-z0-9]/g, '') : 'store');
    editStoreUrl.value = `https://orders.hinopt.com/${slug}`;
  }
  const badge = document.getElementById('edit-plan-badge');
  if (badge) {
    badge.textContent = isOnline ? 'POS + Online Delivery Plan' : 'Standard POS Only';
    badge.style.background = isOnline ? '#ecfdf5' : '#f1f5f9';
    badge.style.color = isOnline ? '#047857' : '#64748b';
  }
  window.toggleDeliveryOptions('edit');

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

// Upgrade Requests Management
async function fetchUpgradeRequests() {
  const tbody = document.getElementById('table-upgrades-body');
  const badge = document.getElementById('badge-upgrades-count');
  try {
    let requests = [];

    // 1. Try Supabase cloud first
    if (window.SupabaseClient) {
      try {
        const sbData = await window.SupabaseClient.fetchUpgradeRequests();
        if (Array.isArray(sbData)) {
          requests = sbData.map(r => ({
            id: r.id,
            restaurantId: r.restaurant_id || r.restaurantId,
            restaurantName: r.restaurant_name || r.restaurantName,
            licenseKey: r.license_key || r.licenseKey,
            currentLimits: r.current_limits || r.currentLimits || {},
            requestedLimits: r.requested_limits || r.requestedLimits || {},
            contactPhone: r.contact_phone || r.contactPhone || '',
            notes: r.notes || '',
            status: r.status || 'pending',
            createdAt: r.created_at || r.createdAt
          }));
        }
      } catch (sbErr) {
        console.warn('Supabase fetchUpgradeRequests failed, fallback to local API:', sbErr);
      }
    }

    // 2. Fetch local API requests and merge
    try {
      const res = await fetch('/api/upgrade-requests');
      const data = await res.json();
      if (data.success && Array.isArray(data.requests)) {
        for (const loc of data.requests) {
          const idx = requests.findIndex(r => r.id === loc.id);
          if (idx === -1) {
            requests.push(loc);
          }
        }
      }
    } catch (_) {}

    const pendingCount = requests.filter(r => r.status === 'pending').length;
    if (badge) {
      badge.textContent = pendingCount;
      badge.style.display = pendingCount > 0 ? 'inline-block' : 'none';
    }

    if (!tbody) return;
    if (requests.length === 0) {
      tbody.innerHTML = `<tr><td colspan="8" style="text-align: center; color: var(--text-secondary); padding: 24px;">No upgrade requests received yet.</td></tr>`;
      return;
    }

    tbody.innerHTML = requests.map(r => {
      const cur = r.currentLimits || {};
      const req = r.requestedLimits || {};
      const isPending = r.status === 'pending';
      const isApproved = r.status === 'approved';
      const badgeClass = isApproved ? 'badge-success' : (isPending ? 'badge-warning' : 'badge-danger');
      
      return `
        <tr>
          <td>
            <div style="font-weight: 800; font-size: 13px;">${r.restaurantName || r.restaurantId}</div>
            <div style="font-size: 11px; color: var(--text-secondary);">Key: ${r.licenseKey || '-'}</div>
          </td>
          <td>
            <div style="font-weight: 600; font-size: 12px;">${r.contactPhone || '-'}</div>
            ${r.contactPhone ? `<a href="https://wa.me/${r.contactPhone.replace(/[^0-9]/g, '')}?text=Hello%2C%20regarding%20your%20Hinopt%20POS%20upgrade%20request..." target="_blank" style="font-size: 11px; color: #25D366; text-decoration: none; font-weight: 600;">Chat on WhatsApp &rarr;</a>` : ''}
          </td>
          <td>
            <div style="font-size: 11px; line-height: 1.4;">
              Dishes: <strong>${cur.menuItems || 100}</strong><br>
              Captains: <strong>${cur.captainDevices || 5}</strong><br>
              Counters: <strong>${cur.counterPcs || 1}</strong>
            </div>
          </td>
          <td>
            <div style="font-size: 11px; line-height: 1.4; color: #1565C0;">
              ${req.menuItems ? `Dishes: <strong>${req.menuItems}</strong> (${req.menuItems > (cur.menuItems || 0) ? '+' + (req.menuItems - (cur.menuItems || 0)) : ''})<br>` : ''}
              ${req.captainDevices ? `Captains: <strong>${req.captainDevices}</strong> (${req.captainDevices > (cur.captainDevices || 0) ? '+' + (req.captainDevices - (cur.captainDevices || 0)) : ''})<br>` : ''}
              ${req.counterPcs ? `Counters: <strong>${req.counterPcs}</strong><br>` : ''}
            </div>
          </td>
          <td style="max-width: 180px;">
            <div style="font-size: 11px; color: var(--text-secondary); word-break: break-word;">${r.notes || 'None'}</div>
          </td>
          <td>
            <div style="font-size: 11px;">${r.createdAt ? new Date(r.createdAt).toLocaleDateString() : '-'}</div>
          </td>
          <td>
            <span class="badge ${badgeClass}">${(r.status || 'pending').toUpperCase()}</span>
          </td>
          <td>
            ${isPending ? `
              <div style="display: flex; gap: 6px;">
                <button class="btn btn-primary btn-sm" onclick="approveUpgradeRequest('${r.id}')" title="Approve & Increase Limits">Approve</button>
                <button class="btn btn-danger btn-sm" onclick="rejectUpgradeRequest('${r.id}')" title="Reject Request">Reject</button>
              </div>
            ` : `
              <span style="font-size: 11px; color: var(--text-secondary); font-weight: 600;">Processed</span>
            `}
          </td>
        </tr>
      `;
    }).join('');
  } catch (err) {
    console.error('Failed to fetch upgrade requests:', err);
  }
}

async function approveUpgradeRequest(reqId) {
  try {
    // 1. Update in Supabase Cloud
    if (window.SupabaseClient) {
      await window.SupabaseClient.updateUpgradeRequestStatus(reqId, 'approved');
    }

    // 2. Update via Local API
    const res = await fetch(`/api/upgrade-requests/${reqId}/approve`, { method: 'POST' });
    const data = await res.json();
    if (data.success) {
      const reqItem = data.request;
      const requested = reqItem.requestedLimits || {};

      // Find or create restaurant in HinoptData
      let rest = window.HinoptData.restaurants.find(r => r.id === reqItem.restaurantId || r.licenseKey === reqItem.licenseKey);
      if (!rest) {
        rest = {
          id: reqItem.restaurantId || 'rest_curry_leaf',
          name: reqItem.restaurantName || 'curry leaf restaurant',
          licenseKey: reqItem.licenseKey,
          status: 'ACTIVE',
          issuedAt: new Date().toISOString().split('T')[0],
          expiresAt: new Date(Date.now() + 365 * 86400000).toISOString().split('T')[0],
          counterIp: '192.168.1.100',
          notes: 'Auto-registered from approved upgrade request'
        };
        window.HinoptData.restaurants.unshift(rest);
      }

      if (requested.menuItems) rest.menuItemsLimit = parseInt(requested.menuItems, 10);
      if (requested.captainDevices) rest.captainDevicesLimit = parseInt(requested.captainDevices, 10);
      if (requested.counterPcs) rest.counterPcsLimit = parseInt(requested.counterPcs, 10);
      rest.limits = {
        menuItems: rest.menuItemsLimit || 300,
        captainDevices: rest.captainDevicesLimit || 6,
        counterPcs: rest.counterPcsLimit || 1
      };

      if (window.LicenseService) {
        window.LicenseService.updateRestaurantDetails(rest.id, {
          menuItemsLimit: rest.menuItemsLimit,
          captainDevicesLimit: rest.captainDevicesLimit,
          counterPcsLimit: rest.counterPcsLimit
        });
      }

      // Update Supabase license limits and signed_payload
      if (window.SupabaseClient && (rest.licenseKey || reqItem.licenseKey)) {
        const targetKey = rest.licenseKey || reqItem.licenseKey;
        await window.SupabaseClient.updateLicense(targetKey, {
          maxDevices: rest.captainDevicesLimit,
          signedPayload: {
            status: 'ACTIVE',
            restaurantId: rest.id,
            limits: rest.limits
          }
        });
      }

      showToast('Upgrade request approved! Restaurant limits updated to: ' + JSON.stringify(rest.limits));
      fetchUpgradeRequests();
      renderAll();
    } else {
      showToast('Failed to approve request: ' + (data.error || 'Unknown error'));
    }
  } catch (e) {
    showToast('Network error: ' + e.message);
  }
}

async function rejectUpgradeRequest(reqId) {
  try {
    // 1. Update in Supabase Cloud
    if (window.SupabaseClient) {
      await window.SupabaseClient.updateUpgradeRequestStatus(reqId, 'rejected');
    }

    // 2. Update via Local API
    const res = await fetch(`/api/upgrade-requests/${reqId}/reject`, { method: 'POST' });
    const data = await res.json();
    if (data.success) {
      showToast('Upgrade request marked as rejected.');
      fetchUpgradeRequests();
    }
  } catch (e) {
    showToast('Network error: ' + e.message);
  }
}

window.fetchUpgradeRequests = fetchUpgradeRequests;
window.approveUpgradeRequest = approveUpgradeRequest;
window.rejectUpgradeRequest = rejectUpgradeRequest;

async function fetchCloudBackups() {
  const tbody = document.getElementById('table-backups-body');
  if (!tbody) return;

  try {
    let backups = [];
    if (window.SupabaseClient && typeof window.SupabaseClient.fetchCloudBackups === 'function') {
      const live = await window.SupabaseClient.fetchCloudBackups();
      if (Array.isArray(live)) {
        backups = live;
      }
    }

    // Also fetch local cloud backups from server if available
    try {
      const localRes = await fetch('/api/cloud-backups/list');
      if (localRes.ok) {
        const localData = await localRes.json();
        if (localData.success && Array.isArray(localData.backups)) {
          const existingFiles = new Set(backups.map(b => b.file_name));
          for (const lb of localData.backups) {
            if (!existingFiles.has(lb.file_name)) {
              backups.push(lb);
            }
          }
        }
      }
    } catch (_) {}

    const badge = document.getElementById('badge-backups-count');
    if (badge) {
      badge.textContent = backups.length;
      badge.style.display = backups.length > 0 ? 'inline-block' : 'none';
    }

    if (!backups || backups.length === 0) {
      tbody.innerHTML = `<tr><td colspan="7" style="text-align: center; color: var(--text-secondary); padding: 24px;">No backups found yet. When a client POS syncs, backups will automatically appear partitioned here.</td></tr>`;
      return;
    }

    tbody.innerHTML = backups.map(b => {
      const sizeStr = b.size_bytes ? `${Math.round(b.size_bytes / 1024)} KB` : 'N/A';
      const createdStr = b.created_at ? new Date(b.created_at).toLocaleString() : 'N/A';
      return `
        <tr>
          <td>
            <div style="font-weight: 700; font-size: 13px; color: var(--text-primary);">${b.restaurant_name || b.restaurant_id || 'Unknown'}</div>
          </td>
          <td>
            <code style="background: var(--surface-muted); padding: 2px 6px; border-radius: 4px; font-size: 11px; color: var(--primary); font-weight: 700;">${b.restaurant_id || 'default'}</code>
          </td>
          <td>
            <span style="font-family: monospace; font-size: 12px;">${b.file_name || 'backup.enc'}</span>
          </td>
          <td>
            <span style="font-size: 12px; font-weight: 600;">${sizeStr}</span>
          </td>
          <td>
            <span class="badge badge-success" style="font-size: 10px;">${b.encryption_cipher || 'AES-256-GCM'}</span>
          </td>
          <td>
            <div style="font-size: 12px; color: var(--text-secondary);">${createdStr}</div>
          </td>
          <td>
            <span style="display: inline-flex; align-items: center; gap: 4px; color: #2e7d32; font-size: 12px; font-weight: 700;">
              <span style="width: 6px; height: 6px; border-radius: 50%; background: #2e7d32;"></span> Saved
            </span>
          </td>
        </tr>
      `;
    }).join('');
  } catch (err) {
    console.error('Failed to fetch cloud backups:', err);
  }
}

window.fetchCloudBackups = fetchCloudBackups;
