import http from 'http';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import crypto from 'crypto';
import { execSync } from 'child_process';
import { GoogleDriveUploader } from './google_drive_uploader.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const PORT = process.env.ADMIN_PORT || 5000;
const HOST = process.env.ADMIN_HOST || '0.0.0.0';

// Load .env if present
const rootEnvPath = path.resolve(__dirname, '../../.env');
if (fs.existsSync(rootEnvPath)) {
  const envContent = fs.readFileSync(rootEnvPath, 'utf8');
  envContent.split(/\r?\n/).forEach(line => {
    const trimmed = line.trim();
    if (trimmed && !trimmed.startsWith('#')) {
      const idx = trimmed.indexOf('=');
      if (idx > 0) {
        const key = trimmed.substring(0, idx).trim();
        const val = trimmed.substring(idx + 1).trim().replace(/^["']|["']$/g, '');
        if (!process.env[key]) {
          process.env[key] = val;
        }
      }
    }
  });
}

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
};

const server = http.createServer(async (req, res) => {
  const parsedUrl = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  const pathname = parsedUrl.pathname;

  // Set CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  // API Route: Detect Host PC Hardware ID (HWID)
  if (pathname === '/api/system-hwid' && req.method === 'GET') {
    let hwid = '';
    try {
      if (process.platform === 'win32') {
        const out = execSync('powershell -NoProfile -Command "(Get-CimInstance Win32_ComputerSystemProduct).UUID"').toString().trim();
        hwid = out || 'WIN-HWID-UNKNOWN';
      } else {
        hwid = 'DEV-HWID-' + crypto.randomBytes(4).toString('hex').toUpperCase();
      }
    } catch (_) {
      hwid = 'WIN-HWID-' + crypto.randomBytes(4).toString('hex').toUpperCase();
    }
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ success: true, hwid }));
    return;
  }

  // API Route: Sign license token cryptographically using Ed25519 or HMAC-SHA256
  if (pathname === '/api/sign-license' && req.method === 'POST') {
    let bodyStr = '';
    req.on('data', chunk => { bodyStr += chunk; });
    req.on('end', () => {
      try {
        const payload = JSON.parse(bodyStr);
        const serialized = JSON.stringify(payload);
        const base64Payload = Buffer.from(serialized).toString('base64');
        
        // Generate digital signature
        const secret = process.env.JWT_SECRET || 'hinopt_cloud_master_secret';
        const signature = crypto.createHmac('sha256', secret).update(base64Payload).digest('hex');

        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
          success: true,
          signedPayloadBase64: base64Payload,
          signatureHex: signature,
          payload
        }));
      } catch (err) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: false, error: err.message }));
      }
    });
    return;
  }

  // API Route: Lookup License Key for Instant Remote Online Activation
  if (pathname.startsWith('/api/license/lookup/') && req.method === 'GET') {
    const rawKey = decodeURIComponent(pathname.replace('/api/license/lookup/', '')).trim();
    if (!rawKey) {
      res.writeHead(400, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ success: false, error: 'License key is required' }));
      return;
    }

    const SUPABASE_URL = "https://ybalhfhqaduqsbjotbni.supabase.co";
    const SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InliYWxoZmhxYWR1cXNiam90Ym5pIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MjM5MzM4NCwiZXhwIjoyMTA3OTY5Mzg0fQ.Sw_edT0eB7HdN4jQ5vIfk9oGM_LSsCCJMw16Pv5MJH0";

    let restName = 'Hinopt Client Restaurant';
    let ownerName = '';
    let phone = '';
    let city = '';
    let restaurantId = `rest_${rawKey.toLowerCase().replace(/[^a-z0-9]/g, '_')}`;
    let limits = {
      menuItems: 200,
      captainDevices: 5,
      counterPcs: 1,
    };
    let validFrom = new Date().toISOString();
    let validUntil = new Date(Date.now() + 365 * 24 * 3600 * 1000).toISOString();
    let status = 'active';

    try {
      const licRes = await fetch(`${SUPABASE_URL}/rest/v1/licenses?license_key=eq.${encodeURIComponent(rawKey)}&select=*`, {
        headers: { apikey: SUPABASE_KEY, Authorization: `Bearer ${SUPABASE_KEY}` }
      });
      if (licRes.ok) {
        const licenses = await licRes.json();
        if (licenses && licenses.length > 0) {
          const lic = licenses[0];
          restaurantId = lic.restaurant_id || restaurantId;
          status = (lic.status || 'ACTIVE').toLowerCase();
          if (lic.valid_from) validFrom = lic.valid_from;
          if (lic.valid_until) validUntil = lic.valid_until;
          if (lic.max_devices) limits.captainDevices = lic.max_devices;
          if (lic.menu_items_limit) limits.menuItems = lic.menu_items_limit;
          if (lic.counter_pcs_limit) limits.counterPcs = lic.counter_pcs_limit;

          // Fetch Restaurant details (name, owner, phone, city)
          const restRes = await fetch(`${SUPABASE_URL}/rest/v1/restaurants?id=eq.${encodeURIComponent(restaurantId)}&select=*`, {
            headers: { apikey: SUPABASE_KEY, Authorization: `Bearer ${SUPABASE_KEY}` }
          });
          if (restRes.ok) {
            const restaurants = await restRes.json();
            if (restaurants && restaurants.length > 0) {
              const r = restaurants[0];
              restName = r.name || restName;
              ownerName = r.contact_name || '';
              phone = r.phone || '';
              city = r.city || '';
            }
          }
        }
      }
    } catch (err) {
      console.warn('[Hinopt Admin] Supabase lookup error:', err.message);
    }

    // Fallback parsing if key was not found in Supabase
    if (restName === 'Hinopt Client Restaurant') {
      const keyParts = rawKey.split('-');
      if (keyParts.length >= 3 && keyParts[1] !== 'LIC') {
        restName = keyParts[1].replace(/_/g, ' ');
      } else if (keyParts.length >= 4 && keyParts[1] === 'LIC') {
        restName = keyParts[2].replace(/_/g, ' ');
      }
    }

    // If client sent its hardware ID during lookup/activation, immediately persist it to Supabase!
    const clientHwid = parsedUrl.searchParams.get('hwid');
    if (clientHwid && restaurantId) {
      try {
        await fetch(`${SUPABASE_URL}/rest/v1/restaurants?id=eq.${encodeURIComponent(restaurantId)}`, {
          method: 'PATCH',
          headers: {
            apikey: SUPABASE_KEY,
            Authorization: `Bearer ${SUPABASE_KEY}`,
            'Content-Type': 'application/json',
            Prefer: 'return=minimal',
          },
          body: JSON.stringify({
            hwid: clientHwid,
            updated_at: new Date().toISOString(),
          }),
        });
        console.log(`[Hinopt Admin] Bound client Hardware ID "${clientHwid}" to restaurant "${restaurantId}" in Supabase Cloud`);
      } catch (err) {
        console.warn('[Hinopt Admin] Failed to patch HWID into Supabase:', err.message);
      }
    }

    const payload = {
      version: '1.0',
      licenseKey: rawKey.toUpperCase(),
      restaurantId: restaurantId,
      restaurantName: restName,
      ownerName: ownerName,
      contactName: ownerName,
      phone: phone,
      city: city,
      status: status,
      validFrom: validFrom,
      validUntil: validUntil,
      issuedAt: validFrom,
      expiresAt: validUntil,
      limits: limits,
      allowedFeatures: ['OFFLINE_POS', 'CAPTAIN_LAN_SYNC', 'DUAL_PRINTER_QUEUE', 'GOOGLE_DRIVE_CLOUD_BACKUP'],
    };

    const base64Payload = Buffer.from(JSON.stringify(payload)).toString('base64');
    const secret = process.env.JWT_SECRET || 'hinopt_cloud_master_secret';
    const signature = crypto.createHmac('sha256', secret).update(base64Payload).digest('hex');

    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      success: true,
      signedPayloadBase64: base64Payload,
      signatureHex: signature,
      payload,
    }));
    return;
  }

  // API Routes: License Upgrade Requests
  const UPGRADE_REQUESTS_FILE = path.join(__dirname, 'upgrade_requests.json');

  if (pathname === '/api/upgrade-requests' && req.method === 'GET') {
    let requests = [];
    try {
      if (fs.existsSync(UPGRADE_REQUESTS_FILE)) {
        requests = JSON.parse(fs.readFileSync(UPGRADE_REQUESTS_FILE, 'utf8'));
      }
    } catch (_) {}

    // Auto-discover any pending requests created by local POS servers
    const siblingPaths = [
      path.resolve(__dirname, '../../services/local-api/data/upgrade_requests.json'),
      path.resolve(__dirname, '../../Restaurant_Client_Pack/Local_POS_Server/data/upgrade_requests.json'),
      path.resolve(__dirname, '../hinopt_admin/upgrade_requests.json'),
    ];
    if (process.env.LOCALAPPDATA) {
      siblingPaths.push(
        path.join(process.env.LOCALAPPDATA, 'Programs/HinoptAdmin/apps/hinopt_admin/upgrade_requests.json')
      );
    }

    let modified = false;
    for (const p of siblingPaths) {
      try {
        if (fs.existsSync(p) && p !== UPGRADE_REQUESTS_FILE) {
          const list = JSON.parse(fs.readFileSync(p, 'utf8'));
          if (Array.isArray(list)) {
            for (const item of list) {
              const existingIdx = requests.findIndex(r => r.id === item.id);
              if (existingIdx === -1) {
                requests.unshift(item);
                modified = true;
              }
            }
          }
        }
      } catch (_) {}
    }

    // Also sync with Supabase Cloud if available
    const SUPABASE_URL = process.env.SUPABASE_URL || 'https://ybalhfhqaduqsbjotbni.supabase.co';
    const SUPABASE_KEY = process.env.SUPABASE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InliYWxoZmhxYWR1cXNiam90Ym5pIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MjM5MzM4NCwiZXhwIjoyMTA3OTY5Mzg0fQ.Sw_edT0eB7HdN4jQ5vIfk9oGM_LSsCCJMw16Pv5MJH0';

    try {
      const sbRes = await fetch(`${SUPABASE_URL}/rest/v1/upgrade_requests?select=*&order=created_at.desc`, {
        headers: {
          'apikey': SUPABASE_KEY,
          'Authorization': `Bearer ${SUPABASE_KEY}`
        }
      });
      if (sbRes.ok) {
        const cloudList = await sbRes.json();
        if (Array.isArray(cloudList)) {
          for (const item of cloudList) {
            const mapped = {
              id: item.id,
              restaurantId: item.restaurant_id || item.restaurantId,
              restaurantName: item.restaurant_name || item.restaurantName,
              licenseKey: item.license_key || item.licenseKey,
              currentLimits: item.current_limits || item.currentLimits || {},
              requestedLimits: item.requested_limits || item.requestedLimits || {},
              contactPhone: item.contact_phone || item.contactPhone || '',
              notes: item.notes || '',
              status: item.status || 'pending',
              createdAt: item.created_at || item.createdAt
            };
            const existingIdx = requests.findIndex(r => r.id === mapped.id);
            if (existingIdx === -1) {
              requests.unshift(mapped);
              modified = true;
            } else {
              // Update status from cloud if changed
              if (requests[existingIdx].status !== mapped.status) {
                requests[existingIdx].status = mapped.status;
                modified = true;
              }
            }
          }
        }
      }
    } catch (_) {}

    if (modified) {
      try {
        fs.writeFileSync(UPGRADE_REQUESTS_FILE, JSON.stringify(requests, null, 2), 'utf8');
      } catch (_) {}
    }

    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ success: true, requests }));
    return;
  }

  if (pathname === '/api/upgrade-requests' && req.method === 'POST') {
    let bodyStr = '';
    req.on('data', chunk => { bodyStr += chunk; });
    req.on('end', () => {
      try {
        const body = JSON.parse(bodyStr);
        let requests = [];
        try {
          if (fs.existsSync(UPGRADE_REQUESTS_FILE)) {
            requests = JSON.parse(fs.readFileSync(UPGRADE_REQUESTS_FILE, 'utf8'));
          }
        } catch (_) {}

        const newRequest = {
          id: body.id || `upg_${Date.now()}_${crypto.randomBytes(3).toString('hex')}`,
          restaurantId: body.restaurantId || 'rest_curry_leaf_01',
          restaurantName: body.restaurantName || 'Curry Leaf Fine Dining',
          licenseKey: body.licenseKey || 'HINOPT-LIC-CL-2026-ACTIVE',
          currentLimits: body.currentLimits || { menuItems: 100, captainDevices: 5, counterPcs: 1 },
          requestedLimits: body.requestedLimits || {},
          contactPhone: body.contactPhone || '',
          notes: body.notes || '',
          status: 'pending',
          createdAt: new Date().toISOString()
        };

        requests.unshift(newRequest);
        fs.writeFileSync(UPGRADE_REQUESTS_FILE, JSON.stringify(requests, null, 2), 'utf8');

        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: true, request: newRequest }));
      } catch (err) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: false, error: err.message }));
      }
    });
    return;
  }

  if (pathname.startsWith('/api/upgrade-requests/') && pathname.endsWith('/approve') && req.method === 'POST') {
    const reqId = pathname.replace('/api/upgrade-requests/', '').replace('/approve', '').trim();
    let requests = [];
    try {
      if (fs.existsSync(UPGRADE_REQUESTS_FILE)) {
        requests = JSON.parse(fs.readFileSync(UPGRADE_REQUESTS_FILE, 'utf8'));
      }
    } catch (_) {}

    const reqItem = requests.find(r => r.id === reqId);
    if (!reqItem) {
      res.writeHead(404, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ success: false, error: 'Upgrade request not found' }));
      return;
    }

    reqItem.status = 'approved';
    reqItem.approvedAt = new Date().toISOString();
    fs.writeFileSync(UPGRADE_REQUESTS_FILE, JSON.stringify(requests, null, 2), 'utf8');

    // Sync approval to Supabase Cloud
    try {
      await fetch(`${SUPABASE_URL}/rest/v1/upgrade_requests?id=eq.${encodeURIComponent(reqId)}`, {
        method: 'PATCH',
        headers: {
          'apikey': SUPABASE_KEY,
          'Authorization': `Bearer ${SUPABASE_KEY}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          status: 'approved',
          updated_at: new Date().toISOString()
        })
      });
    } catch (_) {}

    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ success: true, request: reqItem }));
    return;
  }

  if (pathname.startsWith('/api/upgrade-requests/') && pathname.endsWith('/reject') && req.method === 'POST') {
    const reqId = pathname.replace('/api/upgrade-requests/', '').replace('/reject', '').trim();
    let requests = [];
    try {
      if (fs.existsSync(UPGRADE_REQUESTS_FILE)) {
        requests = JSON.parse(fs.readFileSync(UPGRADE_REQUESTS_FILE, 'utf8'));
      }
    } catch (_) {}

    const reqItem = requests.find(r => r.id === reqId);
    if (!reqItem) {
      res.writeHead(404, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ success: false, error: 'Upgrade request not found' }));
      return;
    }

    reqItem.status = 'rejected';
    reqItem.rejectedAt = new Date().toISOString();
    fs.writeFileSync(UPGRADE_REQUESTS_FILE, JSON.stringify(requests, null, 2), 'utf8');

    // Sync rejection to Supabase Cloud
    try {
      await fetch(`${SUPABASE_URL}/rest/v1/upgrade_requests?id=eq.${encodeURIComponent(reqId)}`, {
        method: 'PATCH',
        headers: {
          'apikey': SUPABASE_KEY,
          'Authorization': `Bearer ${SUPABASE_KEY}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          status: 'rejected',
          updated_at: new Date().toISOString()
        })
      });
    } catch (_) {}

    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ success: true, request: reqItem }));
    return;
  }

  // API Route: Google Drive Connection Status
  if (pathname === '/api/google-drive/status' && req.method === 'GET') {
    const isConfigured = GoogleDriveUploader.isConfigured();
    const creds = GoogleDriveUploader.getCredentials();
    let folderFound = false;
    let folderId = null;
    let error = null;

    if (isConfigured && creds) {
      try {
        const token = await GoogleDriveUploader.getAccessToken(creds);
        folderId = await GoogleDriveUploader.findSharedFolderId(token);
        folderFound = !!folderId;
      } catch (e) {
        error = e.message;
      }
    }

    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      success: true,
      googleDriveConnected: isConfigured,
      serviceAccountEmail: creds?.client_email || null,
      hasSharedFolder: folderFound,
      folderId,
      error,
      instructions: !isConfigured
        ? 'Place your Google Cloud Service Account JSON key into apps/hinopt_admin/google_drive_credentials.json.'
        : (!folderFound
            ? `Please create a folder in your personal Google Drive (e.g. 'Hinopt_POS_Backups') and click Share -> grant Editor access to: ${creds.client_email}`
            : 'Google Drive is fully connected and ready to receive encrypted backups!')
    }));
    return;
  }

  // API Route: Server Status and Configuration
  if (pathname === '/api/config' && req.method === 'GET') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      appName: 'Hinopt Admin Cloud Console',
      supabaseConnected: !!process.env.SUPABASE_URL,
      supabaseUrl: process.env.SUPABASE_URL || 'https://ybalhfhqaduqsbjotbni.supabase.co',
      status: 'operational',
      timestamp: new Date().toISOString()
    }));
    return;
  }

  // API Route: Receive Encrypted Backup (Hinopt Google Drive Bridge)
  if (pathname === '/api/cloud-backups/upload' && req.method === 'POST') {
    let bodyStr = '';
    req.on('data', chunk => { bodyStr += chunk; });
    req.on('end', () => {
      try {
        const payload = JSON.parse(bodyStr);
        const restId = payload.restaurantId || 'default';
        const targetDir = path.join(__dirname, 'cloud_backups', restId);
        if (!fs.existsSync(targetDir)) {
          fs.mkdirSync(targetDir, { recursive: true });
        }
        const fileName = payload.fileName || `backup_${Date.now()}.enc`;
        const filePath = path.join(targetDir, fileName);
        fs.writeFileSync(filePath, JSON.stringify(payload, null, 2), 'utf-8');

        // Also update latest pointer
        fs.writeFileSync(path.join(targetDir, 'latest.json'), JSON.stringify(payload, null, 2), 'utf-8');

        // Sync metadata to Supabase cloud_backups table
        const supabaseUrl = process.env.SUPABASE_URL || 'https://ybalhfhqaduqsbjotbni.supabase.co';
        const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InliYWxoZmhxYWR1cXNiam90Ym5pIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MjM5MzM4NCwiZXhwIjoyMTA3OTY5Mzg0fQ.Sw_edT0eB7HdN4jQ5vIfk9oGM_LSsCCJMw16Pv5MJH0';
        fetch(`${supabaseUrl}/rest/v1/cloud_backups`, {
          method: 'POST',
          headers: {
            'apikey': supabaseKey,
            'Authorization': `Bearer ${supabaseKey}`,
            'Content-Type': 'application/json',
            'Prefer': 'return=minimal'
          },
          body: JSON.stringify({
            restaurant_id: restId,
            restaurant_name: payload.restaurantName || restId,
            file_name: fileName,
            size_bytes: fs.statSync(filePath).size,
            encryption_cipher: 'AES-256-GCM'
          })
        }).catch(() => {});

        // Dispatch upload to Google Drive if credentials exist
        if (GoogleDriveUploader.isConfigured()) {
          GoogleDriveUploader.uploadEncryptedBackup({
            fileName,
            fileContent: JSON.stringify(payload, null, 2)
          }).then(driveRes => {
            if (driveRes.success) {
              console.log('[Google Drive] Successfully saved to Google Drive folder:', driveRes.fileName, driveRes.link);
            }
          }).catch(err => {
            console.warn('[Google Drive] Background upload notice:', err.message);
          });
        }

        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
          success: true,
          message: 'Encrypted backup received and stored on Hinopt Google Drive storage bridge.',
          fileName,
          bytesStored: fs.statSync(filePath).size
        }));
      } catch (err) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: false, error: err.message }));
      }
    });
    return;
  }

  // API Route: Get Latest Encrypted Cloud Backup for a Restaurant
  if (pathname.startsWith('/api/cloud-backups/latest/') && req.method === 'GET') {
    const parts = pathname.split('/');
    const restId = parts[parts.length - 1] || 'default';
    const latestPath = path.join(__dirname, 'cloud_backups', restId, 'latest.json');

    if (fs.existsSync(latestPath)) {
      const data = JSON.parse(fs.readFileSync(latestPath, 'utf-8'));
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ success: true, data }));
    } else {
      res.writeHead(404, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ success: false, error: 'No cloud backup found for this restaurant' }));
    }
    return;
  }

  // API Route: List all local Cloud Backups across restaurants
  if (pathname === '/api/cloud-backups/list' && req.method === 'GET') {
    const baseDir = path.join(__dirname, 'cloud_backups');
    const backups = [];
    if (fs.existsSync(baseDir)) {
      const restDirs = fs.readdirSync(baseDir, { withFileTypes: true });
      for (const d of restDirs) {
        if (d.isDirectory()) {
          const restId = d.name;
          const rDir = path.join(baseDir, restId);
          const files = fs.readdirSync(rDir).filter(f => f.endsWith('.enc'));
          for (const f of files) {
            const st = fs.statSync(path.join(rDir, f));
            backups.push({
              restaurant_id: restId,
              restaurant_name: restId,
              file_name: f,
              size_bytes: st.size,
              encryption_cipher: 'AES-256-GCM',
              created_at: st.mtime.toISOString()
            });
          }
        }
      }
    }
    backups.sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ success: true, backups }));
    return;
  }

  // API Route: 30-Day Check-in / Heartbeat & Hardware Revocation Check
  if (pathname === '/api/license/heartbeat' && req.method === 'POST') {
    let bodyStr = '';
    req.on('data', chunk => { bodyStr += chunk; });
    req.on('end', () => {
      try {
        const payload = JSON.parse(bodyStr);
        const revokedDbPath = path.join(__dirname, 'revoked_hwids.json');
        let revokedList = [];
        if (fs.existsSync(revokedDbPath)) {
          revokedList = JSON.parse(fs.readFileSync(revokedDbPath, 'utf-8'));
        }

        const isRevoked = revokedList.some(r => r.hwid === payload.hwid || (payload.licenseKey && r.revokedKey === payload.licenseKey && r.hwid !== payload.hwid));

        if (isRevoked) {
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({
            success: true,
            status: 'revoked',
            code: 'HARDWARE_REASSIGNED',
            message: 'This license was transferred to another computer. Terminal is deactivated.'
          }));
          return;
        }

        let approvedLimits = null;
        if (fs.existsSync(UPGRADE_REQUESTS_FILE)) {
          try {
            const upgList = JSON.parse(fs.readFileSync(UPGRADE_REQUESTS_FILE, 'utf8'));
            const latestApproved = upgList.find(r => 
              (r.restaurantId === payload.restaurantId || r.licenseKey === payload.licenseKey || (payload.hwid && r.hwid === payload.hwid)) && 
              r.status === 'approved'
            );
            if (latestApproved && latestApproved.requestedLimits) {
              approvedLimits = latestApproved.requestedLimits;
            }
          } catch (_) {}
        }

        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
          success: true,
          status: 'active',
          code: 'OK',
          lastVerifiedAt: new Date().toISOString(),
          approvedLimits: approvedLimits || undefined
        }));
      } catch (err) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: false, error: err.message }));
      }
    });
    return;
  }

  // API Route: Transfer Hardware (Revokes Old PC, Binds New PC)
  if (pathname === '/api/licenses/transfer-hardware' && req.method === 'POST') {
    let bodyStr = '';
    req.on('data', chunk => { bodyStr += chunk; });
    req.on('end', () => {
      try {
        const { oldHwid, newHwid, licenseKey, reason } = JSON.parse(bodyStr);
        const revokedDbPath = path.join(__dirname, 'revoked_hwids.json');
        let revokedList = [];
        if (fs.existsSync(revokedDbPath)) {
          revokedList = JSON.parse(fs.readFileSync(revokedDbPath, 'utf-8'));
        }

        revokedList.push({
          hwid: oldHwid,
          revokedKey: licenseKey,
          revokedAt: new Date().toISOString(),
          transferredToHwid: newHwid,
          reason: reason || 'Client claimed hardware replacement (Burn/Crash)'
        });

        fs.writeFileSync(revokedDbPath, JSON.stringify(revokedList, null, 2), 'utf-8');

        // Sync to Supabase revoked_hwids table
        const supabaseUrl = process.env.SUPABASE_URL || 'https://ybalhfhqaduqsbjotbni.supabase.co';
        const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InliYWxoZmhxYWR1cXNiam90Ym5pIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MjM5MzM4NCwiZXhwIjoyMTA3OTY5Mzg0fQ.Sw_edT0eB7HdN4jQ5vIfk9oGM_LSsCCJMw16Pv5MJH0';
        fetch(`${supabaseUrl}/rest/v1/revoked_hwids`, {
          method: 'POST',
          headers: {
            'apikey': supabaseKey,
            'Authorization': `Bearer ${supabaseKey}`,
            'Content-Type': 'application/json',
            'Prefer': 'return=minimal'
          },
          body: JSON.stringify({
            hwid: oldHwid,
            license_key: licenseKey,
            reason: reason || 'Hardware replacement',
            transferred_to_hwid: newHwid
          })
        }).catch(() => {});

        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
          success: true,
          message: `Hardware transfer approved. Old PC (${oldHwid}) revoked immediately upon next heartbeat.`,
          transferFeeChargedPaise: 150000 // Rs 1,500 transfer fee
        }));
      } catch (err) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: false, error: err.message }));
      }
    });
    return;
  }

  // Static File Serving
  let filePath = path.join(__dirname, pathname === '/' ? 'index.html' : pathname);
  
  if (!fs.existsSync(filePath) || fs.statSync(filePath).isDirectory()) {
    filePath = path.join(__dirname, 'index.html');
  }

  const ext = path.extname(filePath).toLowerCase();
  const contentType = MIME_TYPES[ext] || 'application/octet-stream';

  try {
    const data = fs.readFileSync(filePath);
    res.writeHead(200, {
      'Content-Type': contentType,
      'Cache-Control': 'no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0',
      'Pragma': 'no-cache',
      'Expires': '0'
    });
    res.end(data);
  } catch (err) {
    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('404 Not Found');
  }
});

server.listen(PORT, HOST, () => {
  console.log(`\n========================================================`);
  console.log(`  Hinopt Cloud Admin Console is running!`);
  console.log(`  Local URL:   http://localhost:${PORT}`);
  console.log(`  Network URL: http://${HOST}:${PORT}`);
  console.log(`  Supabase:    ${process.env.SUPABASE_URL || 'Connected'}`);
  console.log(`========================================================\n`);
});
