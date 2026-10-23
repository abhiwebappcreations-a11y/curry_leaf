// Hinopt Admin Live Supabase Client
const SUPABASE_URL = "https://ybalhfhqaduqsbjotbni.supabase.co";
const SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InliYWxoZmhxYWR1cXNiam90Ym5pIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MjM5MzM4NCwiZXhwIjoyMTA3OTY5Mzg0fQ.Sw_edT0eB7HdN4jQ5vIfk9oGM_LSsCCJMw16Pv5MJH0";

window.SupabaseClient = {
  url: SUPABASE_URL,
  key: SUPABASE_KEY,
  isLive: true,

  getHeaders: function() {
    return {
      'apikey': this.key,
      'Authorization': `Bearer ${this.key}`,
      'Content-Type': 'application/json',
      'Prefer': 'return=representation'
    };
  },

  fetchRestaurants: async function() {
    try {
      const res = await fetch(`${this.url}/rest/v1/restaurants?select=*&order=created_at.asc`, {
        headers: this.getHeaders()
      });
      if (res.ok) {
        return await res.json();
      }
    } catch (e) {
      console.warn('[Supabase] fetchRestaurants error, using cache:', e);
    }
    return null;
  },

  fetchLicenses: async function() {
    try {
      const res = await fetch(`${this.url}/rest/v1/licenses?select=*&order=created_at.asc`, {
        headers: this.getHeaders()
      });
      if (res.ok) {
        return await res.json();
      }
    } catch (e) {
      console.warn('[Supabase] fetchLicenses error, using cache:', e);
    }
    return null;
  },

  fetchAuditLogs: async function() {
    try {
      const res = await fetch(`${this.url}/rest/v1/audit_logs?select=*&order=created_at.desc&limit=50`, {
        headers: this.getHeaders()
      });
      if (res.ok) {
        return await res.json();
      }
    } catch (e) {
      console.warn('[Supabase] fetchAuditLogs error:', e);
    }
    return null;
  },

  updateRestaurant: async function(id, data) {
    try {
      const body = {
        name: data.name,
        city: data.city,
        contact_name: data.contactName,
        phone: data.phone,
        hwid: data.hwid,
        counter_ip: data.counterIp || '192.168.1.100',
        notes: data.notes || '',
        updated_at: new Date().toISOString()
      };
      const res = await fetch(`${this.url}/rest/v1/restaurants?id=eq.${id}`, {
        method: 'PATCH',
        headers: this.getHeaders(),
        body: JSON.stringify(body)
      });
      return res.ok;
    } catch (e) {
      console.error('[Supabase] updateRestaurant failed:', e);
      return false;
    }
  },

  updateLicense: async function(licenseKey, data) {
    try {
      const body = {
        updated_at: new Date().toISOString()
      };
      if (data.status) body.status = data.status;
      if (data.validUntil) body.valid_until = data.validUntil;
      if (data.maxDevices) body.max_devices = parseInt(data.maxDevices, 10);
      if (data.signedPayload) body.signed_payload = data.signedPayload;
      if (data.signature) body.signature = data.signature;

      const res = await fetch(`${this.url}/rest/v1/licenses?license_key=eq.${licenseKey}`, {
        method: 'PATCH',
        headers: this.getHeaders(),
        body: JSON.stringify(body)
      });
      return res.ok;
    } catch (e) {
      console.error('[Supabase] updateLicense failed:', e);
      return false;
    }
  },

  updateLicenseStatus: async function(licenseKey, status, validUntil) {
    return this.updateLicense(licenseKey, { status, validUntil });
  },

  insertRestaurant: async function(restaurant) {
    try {
      const res = await fetch(`${this.url}/rest/v1/restaurants`, {
        method: 'POST',
        headers: this.getHeaders(),
        body: JSON.stringify(restaurant)
      });
      return res.ok;
    } catch (e) {
      console.error('[Supabase] insertRestaurant failed:', e);
      return false;
    }
  },

  insertLicense: async function(license) {
    try {
      const res = await fetch(`${this.url}/rest/v1/licenses`, {
        method: 'POST',
        headers: this.getHeaders(),
        body: JSON.stringify(license)
      });
      return res.ok;
    } catch (e) {
      console.error('[Supabase] insertLicense failed:', e);
      return false;
    }
  },

  deleteRestaurant: async function(restaurantId) {
    try {
      // 1. Delete licenses first (foreign key reference)
      await fetch(`${this.url}/rest/v1/licenses?restaurant_id=eq.${restaurantId}`, {
        method: 'DELETE',
        headers: this.getHeaders()
      });
      // 2. Delete restaurant
      const res = await fetch(`${this.url}/rest/v1/restaurants?id=eq.${restaurantId}`, {
        method: 'DELETE',
        headers: this.getHeaders()
      });
      return res.ok;
    } catch (e) {
      console.error('[Supabase] deleteRestaurant failed:', e);
      return false;
    }
  },

  insertAuditLog: async function(logEntry) {
    try {
      await fetch(`${this.url}/rest/v1/audit_logs`, {
        method: 'POST',
        headers: this.getHeaders(),
        body: JSON.stringify(logEntry)
      });
    } catch (_) {}
  }
};
