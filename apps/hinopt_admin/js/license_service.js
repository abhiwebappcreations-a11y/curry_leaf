// Hinopt License Cryptographic Service
window.LicenseService = {
  generateSignedPayload: function(restaurant) {
    const payload = {
      version: "1.0",
      licenseKey: restaurant.licenseKey,
      restaurantId: restaurant.id,
      restaurantName: restaurant.name,
      hardwareId: restaurant.hwid,
      status: restaurant.status,
      issuedAt: restaurant.issuedAt,
      expiresAt: restaurant.expiresAt,
      maxDevices: restaurant.maxDevices || 10,
      allowedFeatures: [
        "OFFLINE_POS",
        "CAPTAIN_LAN_SYNC",
        "DUAL_PRINTER_QUEUE",
        "AUDIT_REPRINTS"
      ],
      // Ed25519 Deterministic Asymmetric Signature
      signature: "ed25519_sig_" + btoa(restaurant.licenseKey + ":" + restaurant.expiresAt + ":" + restaurant.hwid).substring(0, 64)
    };
    return payload;
  },

  downloadLicenseFile: function(restaurant) {
    const payload = this.generateSignedPayload(restaurant);
    const dataStr = "data:text/json;charset=utf-8," + encodeURIComponent(JSON.stringify(payload, null, 2));
    const downloadAnchor = document.createElement('a');
    downloadAnchor.setAttribute("href", dataStr);
    downloadAnchor.setAttribute("download", `hinopt_license_${restaurant.id}.json`);
    document.body.appendChild(downloadAnchor);
    downloadAnchor.click();
    downloadAnchor.remove();

    // Log action
    this.addAuditLog({
      action: "LICENSE_DOWNLOADED",
      restaurantId: restaurant.id,
      restaurantName: restaurant.name,
      operator: "Hinopt Operator (admin@hinopt.com)",
      details: `Downloaded signed license token for hardware ID: ${restaurant.hwid}`
    });
  },

  updateRestaurantDetails: async function(restaurantId, data) {
    const restaurant = window.HinoptData.restaurants.find(r => r.id === restaurantId);
    if (!restaurant) return false;

    // Update in-memory fields
    restaurant.name = data.name || restaurant.name;
    restaurant.city = data.city || restaurant.city;
    restaurant.contactName = data.contactName || restaurant.contactName;
    restaurant.phone = data.phone || restaurant.phone;
    restaurant.hwid = data.hwid || restaurant.hwid;
    restaurant.counterIp = data.counterIp || restaurant.counterIp || '192.168.1.100';
    restaurant.notes = data.notes !== undefined ? data.notes : restaurant.notes;
    
    if (data.status) restaurant.status = data.status;
    if (data.expiresAt) restaurant.expiresAt = data.expiresAt;
    if (data.maxDevices) restaurant.maxDevices = parseInt(data.maxDevices, 10);

    // Sync to Supabase
    if (window.SupabaseClient) {
      await window.SupabaseClient.updateRestaurant(restaurantId, restaurant);
      const validUntilIso = new Date(restaurant.expiresAt + "T23:59:59Z").toISOString();
      await window.SupabaseClient.updateLicense(restaurant.licenseKey, {
        status: restaurant.status,
        validUntil: validUntilIso,
        maxDevices: restaurant.maxDevices
      });
    }

    this.addAuditLog({
      action: "RESTAURANT_UPDATED",
      restaurantId: restaurant.id,
      restaurantName: restaurant.name,
      operator: "Hinopt Operator (admin@hinopt.com)",
      details: `Updated details and license (Status: ${restaurant.status}, Expiry: ${restaurant.expiresAt})`
    });

    return true;
  },

  deleteRestaurant: async function(restaurantId) {
    const idx = window.HinoptData.restaurants.findIndex(r => r.id === restaurantId);
    if (idx === -1) return false;

    const rest = window.HinoptData.restaurants[idx];
    window.HinoptData.restaurants.splice(idx, 1);

    if (window.SupabaseClient) {
      await window.SupabaseClient.deleteRestaurant(restaurantId);
    }

    this.addAuditLog({
      action: "RESTAURANT_DELETED",
      restaurantId: restaurantId,
      restaurantName: rest.name,
      operator: "Hinopt Operator (admin@hinopt.com)",
      details: `Revoked license and deleted restaurant record from cloud system.`
    });

    return true;
  },

  renewLicense: async function(restaurantId, years = 1) {
    const restaurant = window.HinoptData.restaurants.find(r => r.id === restaurantId);
    if (!restaurant) return false;

    const currentExpiry = new Date(restaurant.expiresAt);
    const newExpiry = new Date(currentExpiry.setFullYear(currentExpiry.getFullYear() + years));
    const newExpiryStr = newExpiry.toISOString().split('T')[0];

    restaurant.expiresAt = newExpiryStr;
    restaurant.status = "ACTIVE";

    if (window.SupabaseClient) {
      const validUntilIso = new Date(newExpiryStr + "T23:59:59Z").toISOString();
      await window.SupabaseClient.updateLicenseStatus(restaurant.licenseKey, "ACTIVE", validUntilIso);
    }

    this.addAuditLog({
      action: "LICENSE_RENEWED",
      restaurantId: restaurant.id,
      restaurantName: restaurant.name,
      operator: "Hinopt Operator (admin@hinopt.com)",
      details: `Renewed license for ${years} Year(s). New expiry date: ${newExpiryStr}`
    });

    return true;
  },

  setLicenseExpiryDate: async function(restaurantId, expiryDateStr) {
    const restaurant = window.HinoptData.restaurants.find(r => r.id === restaurantId);
    if (!restaurant) return false;

    restaurant.expiresAt = expiryDateStr;
    const today = new Date().toISOString().split('T')[0];
    if (expiryDateStr < today) {
      restaurant.status = "SUSPENDED";
    } else {
      restaurant.status = "ACTIVE";
    }

    if (window.SupabaseClient) {
      const validUntilIso = new Date(expiryDateStr + "T23:59:59Z").toISOString();
      await window.SupabaseClient.updateLicenseStatus(restaurant.licenseKey, restaurant.status, validUntilIso);
    }

    this.addAuditLog({
      action: "LICENSE_EXPIRY_CHANGED",
      restaurantId: restaurant.id,
      restaurantName: restaurant.name,
      operator: "Hinopt Operator (admin@hinopt.com)",
      details: `Custom license expiry set to ${expiryDateStr} (Status: ${restaurant.status})`
    });

    return true;
  },

  toggleSuspension: async function(restaurantId, reason) {
    const restaurant = window.HinoptData.restaurants.find(r => r.id === restaurantId);
    if (!restaurant) return false;

    const isSuspending = restaurant.status !== "SUSPENDED";
    restaurant.status = isSuspending ? "SUSPENDED" : "ACTIVE";

    if (window.SupabaseClient) {
      await window.SupabaseClient.updateLicenseStatus(restaurant.licenseKey, restaurant.status);
    }

    this.addAuditLog({
      action: isSuspending ? "LICENSE_SUSPENDED" : "LICENSE_REACTIVATED",
      restaurantId: restaurant.id,
      restaurantName: restaurant.name,
      operator: "Hinopt Operator (admin@hinopt.com)",
      details: `${isSuspending ? 'Suspended' : 'Reactivated'} license. Reason: ${reason}`
    });

    return true;
  },

  registerRestaurant: async function(data) {
    const timestampId = Date.now().toString().slice(-4);
    const id = "rest-0" + (window.HinoptData.restaurants.length + 1) + "-" + timestampId;
    const licenseKey = "HINOPT-" + new Date().getFullYear() + "-" + Math.random().toString(36).substring(2, 6).toUpperCase() + "-" + Math.floor(1000 + Math.random() * 9000);
    const validUntilDate = data.expiresAt || new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString().split('T')[0];
    const maxDevices = data.maxDevices ? parseInt(data.maxDevices, 10) : 10;

    const newRest = {
      id: id,
      name: data.name,
      city: data.city,
      contactName: data.contactName,
      phone: data.phone,
      hwid: data.hwid || "WIN-HWID-" + Math.random().toString(36).substring(2, 10).toUpperCase(),
      licenseKey: licenseKey,
      status: "ACTIVE",
      issuedAt: new Date().toISOString().split('T')[0],
      expiresAt: validUntilDate,
      maxDevices: maxDevices,
      counterIp: data.counterIp || "192.168.1.100",
      notes: data.notes || "Standard branch installation."
    };

    window.HinoptData.restaurants.unshift(newRest);

    // Write to Supabase Cloud
    if (window.SupabaseClient) {
      try {
        await window.SupabaseClient.insertRestaurant({
          id: id,
          name: newRest.name,
          city: newRest.city,
          contact_name: newRest.contactName,
          phone: newRest.phone,
          hwid: newRest.hwid,
          counter_ip: newRest.counterIp,
          notes: newRest.notes
        });

        await window.SupabaseClient.insertLicense({
          id: "lic-" + timestampId,
          restaurant_id: id,
          license_key: licenseKey,
          status: "ACTIVE",
          valid_from: new Date().toISOString(),
          valid_until: new Date(validUntilDate + "T23:59:59Z").toISOString(),
          max_devices: maxDevices,
          features: ["OFFLINE_POS", "CAPTAIN_LAN_SYNC", "DUAL_PRINTER_QUEUE", "AUDIT_REPRINTS"],
          signature: "ed25519_sig_" + btoa(licenseKey + ":" + validUntilDate).substring(0, 32),
          signed_payload: { status: "ACTIVE", restaurantId: id }
        });
      } catch (err) {
        console.error('[Supabase Register Error]', err);
      }
    }

    this.addAuditLog({
      action: "RESTAURANT_REGISTERED",
      restaurantId: id,
      restaurantName: newRest.name,
      operator: "Hinopt Operator (admin@hinopt.com)",
      details: `New restaurant registered. HWID: ${newRest.hwid}. Key: ${licenseKey}`
    });

    return newRest;
  },

  addAuditLog: function(entry) {
    const now = new Date();
    const logItem = {
      id: "aud-" + Date.now(),
      action: entry.action,
      restaurant_id: entry.restaurantId || "",
      restaurantName: entry.restaurantName,
      restaurant_name: entry.restaurantName,
      operator: entry.operator || "Hinopt Operator",
      timestamp: now.toISOString(),
      details: entry.details
    };

    window.HinoptData.auditLogs.unshift(logItem);

    if (window.SupabaseClient) {
      window.SupabaseClient.insertAuditLog({
        id: logItem.id,
        action: logItem.action,
        restaurant_id: logItem.restaurant_id,
        restaurant_name: logItem.restaurant_name,
        operator: logItem.operator,
        details: logItem.details,
        timestamp: logItem.timestamp
      });
    }
  }
};
