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
      allowedFeatures: [
        "OFFLINE_POS",
        "CAPTAIN_LAN_SYNC",
        "DUAL_PRINTER_QUEUE",
        "AUDIT_REPRINTS"
      ],
      // Simulated Asymmetric Digital Signature (Ed25519)
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
    window.HinoptData.auditLogs.unshift({
      id: "aud-" + Date.now(),
      action: "LICENSE_DOWNLOADED",
      restaurantName: restaurant.name,
      operator: "Hinopt Operator (admin@hinopt.com)",
      timestamp: new Date().toLocaleString(),
      details: `Downloaded signed license token for hardware ID: ${restaurant.hwid}`
    });
  },

  renewLicense: function(restaurantId, years = 1) {
    const restaurant = window.HinoptData.restaurants.find(r => r.id === restaurantId);
    if (!restaurant) return false;

    const currentExpiry = new Date(restaurant.expiresAt);
    const newExpiry = new Date(currentExpiry.setFullYear(currentExpiry.getFullYear() + years));
    const newExpiryStr = newExpiry.toISOString().split('T')[0];

    restaurant.expiresAt = newExpiryStr;
    restaurant.status = "ACTIVE";

    window.HinoptData.auditLogs.unshift({
      id: "aud-" + Date.now(),
      action: "LICENSE_RENEWED",
      restaurantName: restaurant.name,
      operator: "Hinopt Operator (admin@hinopt.com)",
      timestamp: new Date().toLocaleString(),
      details: `Renewed license for ${years} Year(s). New expiry date: ${newExpiryStr}`
    });

    if (window.SupabaseClient) {
      window.SupabaseClient.updateLicenseStatus(restaurant.licenseKey, "ACTIVE", newExpiry.toISOString());
    }
    return true;
  },

  toggleSuspension: function(restaurantId, reason) {
    const restaurant = window.HinoptData.restaurants.find(r => r.id === restaurantId);
    if (!restaurant) return false;

    const isSuspending = restaurant.status !== "SUSPENDED";
    restaurant.status = isSuspending ? "SUSPENDED" : "ACTIVE";

    window.HinoptData.auditLogs.unshift({
      id: "aud-" + Date.now(),
      action: isSuspending ? "LICENSE_SUSPENDED" : "LICENSE_REACTIVATED",
      restaurantName: restaurant.name,
      operator: "Hinopt Operator (admin@hinopt.com)",
      timestamp: new Date().toLocaleString(),
      details: `${isSuspending ? 'Suspended' : 'Reactivated'} license. Reason: ${reason}`
    });

    if (window.SupabaseClient) {
      window.SupabaseClient.updateLicenseStatus(restaurant.licenseKey, "ACTIVE", newExpiry.toISOString());
    }
    if (window.SupabaseClient) {
      window.SupabaseClient.updateLicenseStatus(restaurant.licenseKey, restaurant.status);
    }
    return true;
  },

  registerRestaurant: function(data) {
    const id = "rest-00" + (window.HinoptData.restaurants.length + 1);
    const newRest = {
      id: id,
      name: data.name,
      city: data.city,
      contactName: data.contactName,
      phone: data.phone,
      hwid: data.hwid || "WIN-HWID-" + Math.random().toString(36).substring(2, 10).toUpperCase(),
      licenseKey: "HINOPT-" + new Date().getFullYear() + "-" + Math.random().toString(36).substring(2, 6).toUpperCase() + "-" + Math.floor(1000 + Math.random() * 9000),
      status: "ACTIVE",
      issuedAt: new Date().toISOString().split('T')[0],
      expiresAt: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
      notes: data.notes || "Standard branch installation."
    };

    window.HinoptData.restaurants.unshift(newRest);

    window.HinoptData.auditLogs.unshift({
      id: "aud-" + Date.now(),
      action: "RESTAURANT_REGISTERED",
      restaurantName: newRest.name,
      operator: "Hinopt Operator (admin@hinopt.com)",
      timestamp: new Date().toLocaleString(),
      details: `New restaurant onboarding complete. Issued key: ${newRest.licenseKey}`
    });

    return newRest;
  }
};
