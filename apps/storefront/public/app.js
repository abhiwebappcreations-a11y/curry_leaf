// ==============================================================================
// Hinopt Universal Cloud Storefront — Dynamic Cloud Client
// Resolves restaurant by URL path (/curryleaf) or subdomain (delivery.curryleaf.com)
// Connects directly to Supabase Cloud so it works on Vercel anywhere in the world!
// ==============================================================================

const SUPABASE_URL = 'https://ybalhfhqaduqsbjotbni.supabase.co';
const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InliYWxoZmhxYWR1cXNiam90Ym5pIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MjM5MzM4NCwiZXhwIjoyMTA3OTY5Mzg0fQ.Sw_edT0eB7HdN4jQ5vIfk9oGM_LSsCCJMw16Pv5MJH0';

// Global State
let currentRestaurant = null;
let allMenuItems = [];
let categories = [];
let activeCategory = 'All';
let searchQuery = '';
let cart = {}; // { [menuItemId]: quantity }
let customerProfile = null;
let deliveryLocation = null;

// Determine Restaurant Identifier from Hostname or Pathname
function resolveRestaurantIdentifier() {
  const host = window.location.hostname.toLowerCase();
  const path = window.location.pathname.replace(/^\/+/g, '').replace(/\/+$/g, '').toLowerCase();

  // 1. If path has slug: e.g. orders.hinopt.com/curryleaf or myapp.vercel.app/curryleaf
  if (path && path !== 'orders' && path !== 'delivery' && !path.includes('.')) {
    return { type: 'slug', value: path };
  }

  // 2. If subdomain: e.g. curryleaf.orders.hinopt.com
  const subParts = host.split('.');
  if (subParts.length > 2 && subParts[0] !== 'www' && subParts[0] !== 'orders' && !host.includes('vercel.app')) {
    return { type: 'subdomain', value: host };
  }

  // 3. Fallback default to 'curryleaf'
  return { type: 'slug', value: 'curryleaf' };
}

// Initial Boot
document.addEventListener('DOMContentLoaded', async () => {
  loadLocalStoredData();
  await loadRestaurantAndMenu();
});

// Load Profile and Location from LocalStorage
function loadLocalStoredData() {
  try {
    const savedProfile = localStorage.getItem('hinopt_customer_profile');
    if (savedProfile) {
      customerProfile = JSON.parse(savedProfile);
      updateAuthUI();
    }

    const savedLocation = localStorage.getItem('hinopt_delivery_location');
    if (savedLocation) {
      deliveryLocation = JSON.parse(savedLocation);
      updateLocationUI();
    } else {
      updateLocationUI();
    }
  } catch (e) {
    console.error('Failed to parse local stored session:', e);
  }
}

// Fetch Restaurant & Deliverable Menu directly from Supabase Cloud
async function loadRestaurantAndMenu() {
  const container = document.getElementById('menuContainer');
  const target = resolveRestaurantIdentifier();

  try {
    let queryUrl = '';
    if (target.type === 'subdomain') {
      queryUrl = `${SUPABASE_URL}/rest/v1/restaurants?custom_domain=eq.${encodeURIComponent(target.value)}&select=*`;
    } else {
      queryUrl = `${SUPABASE_URL}/rest/v1/restaurants?or=(store_slug.eq.${encodeURIComponent(target.value)},id.eq.${encodeURIComponent(target.value)})&select=*`;
    }

    let res = await fetch(queryUrl, {
      headers: { apikey: SUPABASE_KEY, Authorization: `Bearer ${SUPABASE_KEY}` },
    });
    let list = await res.json();

    // Fallback if not found by specific slug, load primary restaurant
    if (!list || list.length === 0) {
      const fbRes = await fetch(`${SUPABASE_URL}/rest/v1/restaurants?select=*&limit=1`, {
        headers: { apikey: SUPABASE_KEY, Authorization: `Bearer ${SUPABASE_KEY}` },
      });
      list = await fbRes.json();
    }

    if (!list || list.length === 0) {
      container.innerHTML = `
        <div class="loading-state">
          <p style="color: #dc2626; font-weight: 700;">⚠️ Restaurant storefront not found.</p>
        </div>
      `;
      return;
    }

    currentRestaurant = list[0];

    // Update Header Brand Details
    if (currentRestaurant.name) {
      document.getElementById('restaurantName').textContent = currentRestaurant.name.toUpperCase();
      document.title = `${currentRestaurant.name} - Direct Online Delivery`;
    }
    if (currentRestaurant.city) {
      document.getElementById('restaurantCity').textContent = `${currentRestaurant.city} • Direct Delivery`;
    }

    // Check if Online Delivery is active for this restaurant
    if (!currentRestaurant.online_ordering_enabled) {
      container.innerHTML = `
        <div class="loading-state">
          <p style="color: #b45309; font-weight: 700;">🛵 Online delivery is currently closed for this restaurant.</p>
          <p style="font-size: 12px; color: #64748b; margin-top: 4px;">Please check back during restaurant operating hours.</p>
        </div>
      `;
      return;
    }

    // Load Dishes from online_menu snapshot
    allMenuItems = currentRestaurant.online_menu || [];

    if (allMenuItems.length === 0) {
      container.innerHTML = `
        <div class="loading-state">
          <p style="font-weight: 700;">No dishes currently available for delivery.</p>
          <p style="font-size: 12px; color: #64748b; margin-top: 4px;">The kitchen has not enabled any deliverable items yet.</p>
        </div>
      `;
      return;
    }

    // Extract unique categories
    const catSet = new Set(allMenuItems.map(i => i.category || 'General'));
    categories = Array.from(catSet);

    renderCategoryTabs();
    renderMenuDishes();
  } catch (err) {
    console.error('Failed to load restaurant data:', err);
    container.innerHTML = `
      <div class="loading-state">
        <p style="color: #dc2626; font-weight: 700;">Unable to connect to cloud service. Please check your internet connection.</p>
      </div>
    `;
  }
}

// Render Horizontal Category Navigation Tabs
function renderCategoryTabs() {
  const tabsContainer = document.getElementById('categoryTabs');
  const catNames = ['All', ...categories];

  tabsContainer.innerHTML = catNames.map(name => {
    const isActive = activeCategory === name;
    return `
      <button class="cat-pill ${isActive ? 'active' : ''}" onclick="filterCategory('${escapeHtml(name)}')">
        ${escapeHtml(name)}
      </button>
    `;
  }).join('');
}

function filterCategory(cat) {
  activeCategory = cat;
  renderCategoryTabs();
  renderMenuDishes();
}

function handleSearch() {
  searchQuery = document.getElementById('searchInput').value.trim().toLowerCase();
  renderMenuDishes();
}

// Render Menu Dishes List (No Bulky Images - Fast & Lightweight)
function renderMenuDishes() {
  const container = document.getElementById('menuContainer');

  let filtered = allMenuItems;
  if (activeCategory !== 'All') {
    filtered = filtered.filter(i => (i.category || 'General') === activeCategory);
  }
  if (searchQuery) {
    filtered = filtered.filter(i =>
      i.name.toLowerCase().includes(searchQuery) ||
      (i.description && i.description.toLowerCase().includes(searchQuery))
    );
  }

  if (filtered.length === 0) {
    container.innerHTML = `
      <div class="loading-state">
        <p>No dishes found matching your selection.</p>
      </div>
    `;
    return;
  }

  // Group by category
  const groups = {};
  filtered.forEach(item => {
    const c = item.category || 'General';
    if (!groups[c]) groups[c] = [];
    groups[c].push(item);
  });

  const html = Object.keys(groups).map(catName => {
    const items = groups[catName];
    const itemsHtml = items.map(item => {
      const qty = cart[item.id] || 0;
      return `
        <div class="dish-row" id="dish-row-${item.id}">
          <div class="dish-details">
            <div class="dish-type-row">
              <span class="diet-badge ${item.isVeg ? 'veg' : 'nonveg'}"></span>
              <span class="dish-name">${escapeHtml(item.name)}</span>
            </div>
            ${item.description ? `<p class="dish-desc">${escapeHtml(item.description)}</p>` : ''}
            <div class="dish-price">₹${item.priceRupees}</div>
          </div>
          <div class="dish-action-col">
            ${qty > 0 ? `
              <div class="qty-stepper">
                <button class="stepper-btn" onclick="updateItemQty('${item.id}', -1)">−</button>
                <span class="stepper-qty">${qty}</span>
                <button class="stepper-btn" onclick="updateItemQty('${item.id}', 1)">+</button>
              </div>
            ` : `
              <button class="btn-add-item" onclick="updateItemQty('${item.id}', 1)">+ ADD</button>
            `}
          </div>
        </div>
      `;
    }).join('');

    return `
      <div class="category-group">
        <div class="category-header">
          <span>${escapeHtml(catName)}</span>
          <span class="cat-item-count">${items.length} dishes</span>
        </div>
        <div class="dishes-list">
          ${itemsHtml}
        </div>
      </div>
    `;
  }).join('');

  container.innerHTML = html;
}

// Cart Management
function updateItemQty(itemId, delta) {
  const current = cart[itemId] || 0;
  const updated = Math.max(0, current + delta);

  if (updated === 0) {
    delete cart[itemId];
  } else {
    cart[itemId] = updated;
  }

  renderMenuDishes();
  updateCartBar();
}

function updateCartBar() {
  const bar = document.getElementById('bottomCartBar');
  const countBadge = document.getElementById('cartCountBadge');
  const totalBadge = document.getElementById('cartTotalBadge');

  let totalCount = 0;
  let totalPrice = 0;

  for (const [id, qty] of Object.entries(cart)) {
    const item = allMenuItems.find(i => i.id === id);
    if (item && qty > 0) {
      totalCount += qty;
      totalPrice += item.priceRupees * qty;
    }
  }

  if (totalCount > 0) {
    bar.style.display = 'block';
    countBadge.textContent = `${totalCount} ${totalCount === 1 ? 'ITEM' : 'ITEMS'}`;
    totalBadge.textContent = `₹${totalPrice}`;
  } else {
    bar.style.display = 'none';
  }
}

// Location Management (Swiggy-style)
function updateLocationUI() {
  const addressDisplay = document.getElementById('activeAddressDisplay');
  if (deliveryLocation && deliveryLocation.fullAddress) {
    addressDisplay.textContent = deliveryLocation.fullAddress;
    addressDisplay.style.color = '#0f172a';
  } else {
    addressDisplay.textContent = 'Set delivery location to start ordering...';
    addressDisplay.style.color = '#64748b';
  }
}

function openLocationModal() {
  if (deliveryLocation) {
    document.getElementById('locHouseInput').value = deliveryLocation.house || '';
    document.getElementById('locAreaInput').value = deliveryLocation.area || '';
    document.getElementById('locLandmarkInput').value = deliveryLocation.landmark || '';
    document.getElementById('locPincodeInput').value = deliveryLocation.pincode || '';
  }
  document.getElementById('locationModal').style.display = 'flex';
}

function closeLocationModal() {
  document.getElementById('locationModal').style.display = 'none';
}

function detectGpsLocation() {
  if (!navigator.geolocation) {
    alert('Geolocation is not supported by your browser.');
    return;
  }

  const btn = document.querySelector('.btn-use-gps');
  const origText = btn.innerHTML;
  btn.innerHTML = '<span>⏳ Detecting GPS coordinates...</span>';

  navigator.geolocation.getCurrentPosition(
    (position) => {
      btn.innerHTML = origText;
      const lat = position.coords.latitude.toFixed(5);
      const lng = position.coords.longitude.toFixed(5);

      if (!document.getElementById('locAreaInput').value) {
        document.getElementById('locAreaInput').value = `GPS: ${lat}, ${lng}`;
      }

      if (deliveryLocation) {
        deliveryLocation.lat = position.coords.latitude;
        deliveryLocation.lng = position.coords.longitude;
      }
      alert(`GPS location detected: ${lat}, ${lng}\nPlease confirm your Flat / House number.`);
    },
    (err) => {
      btn.innerHTML = origText;
      alert(`GPS detection error: ${err.message || 'Permission denied'}. Please enter your address manually.`);
    },
    { enableHighAccuracy: true, timeout: 10000 }
  );
}

function saveLocationForm() {
  const house = document.getElementById('locHouseInput').value.trim();
  const area = document.getElementById('locAreaInput').value.trim();
  const landmark = document.getElementById('locLandmarkInput').value.trim();
  const pincode = document.getElementById('locPincodeInput').value.trim();

  if (!house || !area || !pincode) {
    alert('Please enter your House/Flat number, Area, and Pincode.');
    return;
  }

  const fullParts = [house, area];
  if (landmark) fullParts.push(`Near ${landmark}`);
  fullParts.push(pincode);
  const fullAddress = fullParts.join(', ');

  deliveryLocation = {
    house,
    area,
    landmark,
    pincode,
    fullAddress,
    savedAt: new Date().toISOString(),
  };

  localStorage.setItem('hinopt_delivery_location', JSON.stringify(deliveryLocation));
  updateLocationUI();
  closeLocationModal();
}

// Customer Auth / Sign In
function updateAuthUI() {
  const authBtnText = document.getElementById('authBtnText');
  if (customerProfile && customerProfile.name) {
    authBtnText.textContent = customerProfile.name.split(' ')[0];
  } else {
    authBtnText.textContent = 'Sign In';
  }
}

function openAuthModal() {
  if (customerProfile) {
    document.getElementById('custNameInput').value = customerProfile.name || '';
    document.getElementById('custPhoneInput').value = customerProfile.phone || '';
  }
  document.getElementById('authModal').style.display = 'flex';
}

function closeAuthModal() {
  document.getElementById('authModal').style.display = 'none';
}

function saveCustomerProfile() {
  const name = document.getElementById('custNameInput').value.trim();
  const phone = document.getElementById('custPhoneInput').value.trim();

  if (!name || phone.length < 10) {
    alert('Please enter your full name and a valid 10-digit mobile number.');
    return;
  }

  customerProfile = { name, phone, savedAt: new Date().toISOString() };
  localStorage.setItem('hinopt_customer_profile', JSON.stringify(customerProfile));
  updateAuthUI();
  closeAuthModal();
}

// Checkout Modal
function openCheckoutModal() {
  if (!deliveryLocation || !deliveryLocation.fullAddress) {
    openLocationModal();
    return;
  }
  if (!customerProfile || !customerProfile.phone) {
    openAuthModal();
    return;
  }

  document.getElementById('checkoutAddressText').textContent = deliveryLocation.fullAddress;
  document.getElementById('checkoutContactText').textContent = `${customerProfile.name} • +91 ${customerProfile.phone}`;

  let subtotal = 0;
  const itemsContainer = document.getElementById('checkoutItemsListContainer');

  const rows = [];
  for (const [id, qty] of Object.entries(cart)) {
    const item = allMenuItems.find(i => i.id === id);
    if (item && qty > 0) {
      const lineTotal = item.priceRupees * qty;
      subtotal += lineTotal;
      rows.push(`
        <div class="checkout-item-row">
          <div class="item-left">
            <span class="diet-badge ${item.isVeg ? 'veg' : 'nonveg'}"></span>
            <span>${escapeHtml(item.name)}</span>
          </div>
          <div class="item-right">
            <span class="item-qty-badge">x ${qty}</span>
            <span class="item-price">₹${lineTotal}</span>
          </div>
        </div>
      `);
    }
  }

  itemsContainer.innerHTML = rows.join('');
  document.getElementById('billSubtotal').textContent = `₹${subtotal}`;
  document.getElementById('billGrandTotal').textContent = `₹${subtotal}`;
  document.getElementById('btnPlaceOrderTotal').textContent = `₹${subtotal}`;

  document.getElementById('checkoutModal').style.display = 'flex';
}

function closeCheckoutModal() {
  document.getElementById('checkoutModal').style.display = 'none';
}

// Place Order directly into Supabase Cloud online_orders queue!
async function placeOrder() {
  if (!deliveryLocation || !deliveryLocation.fullAddress) {
    alert('Please set your delivery address.');
    openLocationModal();
    return;
  }
  if (!customerProfile || !customerProfile.phone) {
    alert('Please sign in with your mobile number to confirm order.');
    openAuthModal();
    return;
  }
  if (!currentRestaurant) {
    alert('Restaurant data is not loaded yet.');
    return;
  }

  const items = [];
  let subtotalPaise = 0;
  for (const [id, qty] of Object.entries(cart)) {
    if (qty > 0) {
      const item = allMenuItems.find(i => i.id === id);
      const pricePaise = item ? item.pricePaise || (item.priceRupees * 100) : 0;
      subtotalPaise += pricePaise * qty;
      items.push({
        id,
        menuItemId: id,
        name: item ? item.name : 'Dish',
        quantity: qty,
        priceRupees: item ? item.priceRupees : 0,
        pricePaise,
      });
    }
  }

  if (items.length === 0) {
    alert('Your cart is empty.');
    return;
  }

  const btn = document.getElementById('btnPlaceOrder');
  btn.disabled = true;
  btn.innerHTML = '<span>⏳ Sending to Kitchen...</span>';

  const notes = document.getElementById('orderNotesInput').value.trim();
  const orderId = `ord_cloud_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`;
  const orderNumber = `ORD-${new Date().toISOString().slice(2, 10).replace(/-/g, '')}-${Date.now().toString().slice(-4)}`;

  try {
    const payload = {
      id: orderId,
      restaurant_id: currentRestaurant.id,
      order_number: orderNumber,
      customer_name: customerProfile.name,
      customer_phone: customerProfile.phone,
      delivery_address: deliveryLocation.fullAddress,
      delivery_coordinates: (deliveryLocation.lat && deliveryLocation.lng) ? {
        lat: deliveryLocation.lat,
        lng: deliveryLocation.lng,
      } : null,
      customer_notes: notes || null,
      items: items,
      subtotal_paise: subtotalPaise,
      tax_paise: 0,
      total_paise: subtotalPaise,
      status: 'pending',
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    const res = await fetch(`${SUPABASE_URL}/rest/v1/online_orders`, {
      method: 'POST',
      headers: {
        apikey: SUPABASE_KEY,
        Authorization: `Bearer ${SUPABASE_KEY}`,
        'Content-Type': 'application/json',
        Prefer: 'return=minimal',
      },
      body: JSON.stringify(payload),
    });

    btn.disabled = false;
    btn.innerHTML = `<span>Place Delivery Order</span> <span>₹${document.getElementById('billGrandTotal').textContent}</span>`;

    if (res.ok) {
      closeCheckoutModal();
      showSuccessModal({
        orderNumber,
        deliveryAddress: deliveryLocation.fullAddress,
        customerPhone: customerProfile.phone,
        totalRupees: subtotalPaise / 100,
      });
      // Clear cart
      cart = {};
      renderMenuDishes();
      updateCartBar();
    } else {
      const errText = await res.text();
      alert(`Could not place order: ${errText}`);
    }
  } catch (err) {
    btn.disabled = false;
    btn.innerHTML = `<span>Place Delivery Order</span> <span>₹${document.getElementById('billGrandTotal').textContent}</span>`;
    alert('Network error placing order. Please check your connection.');
  }
}

// Order Success Modal
function showSuccessModal(orderData) {
  document.getElementById('successOrderNumber').textContent = orderData.orderNumber;
  document.getElementById('successAddress').textContent = orderData.deliveryAddress;
  document.getElementById('successPhone').textContent = `+91 ${orderData.customerPhone}`;
  document.getElementById('successTotal').textContent = `₹${orderData.totalRupees}`;
  document.getElementById('orderSuccessModal').style.display = 'flex';
}

function closeSuccessAndReset() {
  document.getElementById('orderSuccessModal').style.display = 'none';
}

// Utility escape HTML
function escapeHtml(text) {
  if (!text) return '';
  return text.replace(/[&<>"']/g, function(m) {
    return {
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      '"': '&quot;',
      "'": '&#039;'
    }[m];
  });
}
