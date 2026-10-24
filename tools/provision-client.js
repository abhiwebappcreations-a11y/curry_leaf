import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { execSync } from 'child_process';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const ROOT_DIR = path.resolve(__dirname, '..');

// Parse CLI Arguments or use defaults
function parseArgs() {
  const args = process.argv.slice(2);
  const params = {};
  for (let i = 0; i < args.length; i++) {
    if (args[i].startsWith('--')) {
      const key = args[i].replace(/^--/, '');
      const value = args[i + 1] && !args[i + 1].startsWith('--') ? args[++i] : true;
      params[key] = value;
    }
  }
  return params;
}

const params = parseArgs();
const restaurantName = params.name || params.restaurant || 'Royal Spice Restro';
const ownerName = params.owner || params.contact || 'Restaurant Owner';
const phone = params.phone || '+91 98765 43210';
const city = params.city || 'Hyderabad';
const days = parseInt(params.days || '365', 10);
const gstin = params.gstin || '36AABCU9603R1ZM';

const slug = restaurantName.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');
const restId = `rest_${slug}_${crypto.randomBytes(3).toString('hex')}`;
const licenseKey = `HINOPT-LIC-${slug.toUpperCase()}-${Date.now().toString(36).toUpperCase()}`;

const now = new Date();
const expiresAt = new Date(now.getTime() + days * 24 * 3600 * 1000).toISOString();

console.log('=====================================================================');
console.log('       HINOPT RESTAURANT POS — DYNAMIC CLIENT ONBOARDING GENERATOR     ');
console.log('=====================================================================');
console.log(`Restaurant Name : ${restaurantName}`);
console.log(`Owner / Contact : ${ownerName}`);
console.log(`Phone           : ${phone}`);
console.log(`City / Branch   : ${city}`);
console.log(`GSTIN           : ${gstin}`);
console.log(`Validity        : ${days} days (Expires: ${expiresAt.split('T')[0]})`);
console.log(`Generated Key   : ${licenseKey}`);
console.log('---------------------------------------------------------------------');

// 1. Generate Signed License Payload
const secret = process.env.JWT_SECRET || 'hinopt_cloud_master_secret';
const payload = {
  version: '1.0',
  licenseKey: licenseKey,
  restaurantId: restId,
  restaurantName: restaurantName,
  ownerName: ownerName,
  phone: phone,
  city: city,
  gstin: gstin,
  status: 'active',
  issuedAt: now.toISOString(),
  validFrom: now.toISOString(),
  expiresAt: expiresAt,
  validUntil: expiresAt,
  maxDevices: 15,
  allowedFeatures: [
    'OFFLINE_POS',
    'CAPTAIN_LAN_SYNC',
    'DUAL_PRINTER_QUEUE',
    'AUDIT_REPRINTS',
    'GOOGLE_DRIVE_CLOUD_BACKUP',
  ],
};

const base64Payload = Buffer.from(JSON.stringify(payload)).toString('base64');
const signature = crypto.createHmac('sha256', secret).update(base64Payload).digest('hex');

const licenseDocument = {
  signedPayload: payload,
  signature: signature,
  token: `${base64Payload}.${signature}`,
  generatedAt: now.toISOString(),
  issuer: 'Hinopt Cloud SaaS (admin@hinopt.com)',
};

// 2. Prepare Client Distribution Folder
const clientPackDirName = `Client_Pack_${slug}`;
const targetDir = path.resolve(ROOT_DIR, 'dist', clientPackDirName);
const basePackDir = path.resolve(ROOT_DIR, 'Restaurant_Client_Pack');

if (!fs.existsSync(basePackDir)) {
  console.error(`Base pack not found at ${basePackDir}. Build base pack first.`);
  process.exit(1);
}

fs.mkdirSync(path.resolve(ROOT_DIR, 'dist'), { recursive: true });
if (fs.existsSync(targetDir)) {
  fs.rmSync(targetDir, { recursive: true, force: true });
}

console.log(`[1/3] Cloning base pack into ${targetDir}...`);
fs.cpSync(basePackDir, targetDir, { recursive: true });

// 3. Inject Personalized license.json into Local_POS_Server and root
console.log(`[2/3] Injecting personalized license.json for "${restaurantName}"...`);
const licJsonContent = JSON.stringify(licenseDocument, null, 2);
fs.writeFileSync(path.join(targetDir, 'license.json'), licJsonContent, 'utf-8');
fs.writeFileSync(path.join(targetDir, 'Local_POS_Server', 'license.json'), licJsonContent, 'utf-8');

// Also update initial pos_store.json settings if present
const storePath = path.join(targetDir, 'Local_POS_Server', 'data', 'pos_store.json');
let initialStore = {
  tables: [],
  categories: [
    { id: 'cat_starters', name: 'Starters', sortOrder: 1, isActive: true },
    { id: 'cat_mains', name: 'Main Course', sortOrder: 2, isActive: true },
    { id: 'cat_biryani', name: 'Biryani & Rice', sortOrder: 3, isActive: true },
    { id: 'cat_beverages', name: 'Beverages', sortOrder: 4, isActive: true },
  ],
  menuItems: [],
  orders: [],
  bills: [],
  payments: [],
  devices: [],
};

if (fs.existsSync(storePath)) {
  try {
    const raw = JSON.parse(fs.readFileSync(storePath, 'utf-8'));
    initialStore = { ...initialStore, ...raw, orders: [], bills: [], payments: [] };
  } catch (_) {}
}

fs.writeFileSync(storePath, JSON.stringify(initialStore, null, 2), 'utf-8');

// 4. Create Personalized README
const clientReadme = `=====================================================================
            HINOPT RESTAURANT POS — LICENSED TO:
            ${restaurantName.toUpperCase()}
=====================================================================
Licensed Owner   : ${ownerName}
Contact Phone    : ${phone}
City / Branch    : ${city}
Subscription Key : ${licenseKey}
Valid Until      : ${expiresAt.split('T')[0]} (${days} days)

QUICK START:
1. Connect Counter PC and Waiter Phones to the SAME restaurant Wi-Fi.
2. Double-click "START_RESTAURANT_POS.bat" on this PC.
3. Install "Hinopt_Captain_v1.0.apk" on waiter Android phones.
4. When waiter phone connects, click "Approve & Activate" on the Counter PC.

Enjoy seamless, ultra-fast table ordering & thermal billing!
=====================================================================
`;
fs.writeFileSync(path.join(targetDir, 'README.txt'), clientReadme, 'utf-8');

// 5. Compress to ZIP
const zipPath = path.resolve(ROOT_DIR, 'dist', `${slug}_POS_Pack.zip`);
if (fs.existsSync(zipPath)) fs.unlinkSync(zipPath);

console.log(`[3/3] Creating distribution ZIP: ${path.basename(zipPath)}...`);
try {
  execSync(`powershell -NoProfile -Command "Compress-Archive -Path '${targetDir}\\*' -DestinationPath '${zipPath}' -Force"`);
  const zipSizeMb = (fs.statSync(zipPath).size / (1024 * 1024)).toFixed(2);
  console.log(`SUCCESS! Zip Package Ready: ${zipSizeMb} MB`);
} catch (err) {
  console.warn('Could not create ZIP archive automatically, folder is ready:', err.message);
}

console.log('---------------------------------------------------------------------');
console.log(`Client Distribution Folder : ${targetDir}`);
console.log(`Client Distribution ZIP    : ${zipPath}`);
console.log('=====================================================================');
