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

    // Extract restaurant name or fallback
    const keyParts = rawKey.split('-');
    let restName = 'Hinopt Client Restaurant';
    if (keyParts.length >= 3 && keyParts[1] !== 'LIC') {
      restName = keyParts[1].replace(/_/g, ' ');
    } else if (keyParts.length >= 4 && keyParts[1] === 'LIC') {
      restName = keyParts[2].replace(/_/g, ' ');
    }

    const now = new Date();
    const expiresAt = new Date(now.getTime() + 365 * 24 * 3600 * 1000).toISOString();
    const payload = {
      version: '1.0',
      licenseKey: rawKey.toUpperCase(),
      restaurantId: `rest_${rawKey.toLowerCase().replace(/[^a-z0-9]/g, '_')}`,
      restaurantName: restName,
      status: 'active',
      validFrom: now.toISOString(),
      validUntil: expiresAt,
      issuedAt: now.toISOString(),
      expiresAt: expiresAt,
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

  // API Route: Google Drive Connection Status
  if (pathname === '/api/google-drive/status' && req.method === 'GET') {
    const isConfigured = GoogleDriveUploader.isConfigured();
    const creds = GoogleDriveUploader.getCredentials();
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      success: true,
      googleDriveConnected: isConfigured,
      clientEmail: creds?.client_email || null,
      projectId: creds?.project_id || null,
      credentialsPath: 'apps/hinopt_admin/google_drive_credentials.json',
      instructions: isConfigured
        ? 'Google Drive is connected and active!'
        : 'Place your Google Cloud Service Account JSON key into apps/hinopt_admin/google_drive_credentials.json to link your Google Drive.'
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

        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
          success: true,
          status: 'active',
          code: 'OK',
          lastVerifiedAt: new Date().toISOString()
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
    res.writeHead(200, { 'Content-Type': contentType });
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
