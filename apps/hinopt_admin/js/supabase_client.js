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

  updateLicenseStatus: async function(licenseKey, status, validUntil) {
    try {
      const body = { status };
      if (validUntil) body.valid_until = validUntil;
      const res = await fetch(`${this.url}/rest/v1/licenses?license_key=eq.${licenseKey}`, {
        method: 'PATCH',
        headers: this.getHeaders(),
        body: JSON.stringify(body)
      });
      return res.ok;
    } catch (e) {
      console.error('[Supabase] updateLicenseStatus failed:', e);
      return false;
    }
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
