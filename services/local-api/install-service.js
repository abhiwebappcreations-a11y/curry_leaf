/**
 * Hinopt POS - Windows Service Installer
 * =======================================
 * Registers the Local API as a native Windows Service that:
 *   - Starts automatically on PC boot (no login required)
 *   - Runs silently in the background
 *   - Auto-restarts on crash (up to 3 times)
 *   - Is manageable via services.msc or sc.exe
 *
 * USAGE: Run this script ONCE as Administrator:
 *   node install-service.js
 *
 * Or double-click:  install-windows-service.bat
 */

const path = require('path');
const { Service } = require('node-windows');

// ── Config ──────────────────────────────────────────────────────────────────
const SERVICE_NAME        = 'HinoptPosApi';
const SERVICE_DESCRIPTION = 'Hinopt Restaurant POS - Local API backend (port 4000). Serves Counter, Captain tablets, and KOT/Bill thermal printers.';

// Point to the compiled JS entry. Run `npm run build` before installing if not built yet.
const SCRIPT_PATH = path.resolve(__dirname, 'dist', 'index.js');

// Working directory = this folder (so relative paths in config resolve correctly)
const WORK_DIR = __dirname;
// ─────────────────────────────────────────────────────────────────────────────

const svc = new Service({
  name:        SERVICE_NAME,
  description: SERVICE_DESCRIPTION,
  script:      SCRIPT_PATH,
  workingDirectory: WORK_DIR,
  nodeOptions: [],

  // Auto-restart policy: restart up to 3 times, wait 3 s between attempts
  maxRetries: 3,
  wait:       3,
  grow:       0.25,

  // Environment variables passed to the service process.
  // Add any overrides needed for production here.
  env: [
    { name: 'NODE_ENV',  value: 'production' },
    // If your .env file is somewhere specific, add:
    // { name: 'DOTENV_CONFIG_PATH', value: path.resolve(__dirname, '../../.env') },
  ],
});

svc.on('install', () => {
  console.log('\n✅  Hinopt POS API service installed successfully!');
  console.log('▶   Starting service now...');
  svc.start();
});

svc.on('start', () => {
  console.log('🟢  Service started! The API is running on http://localhost:4000');
  console.log('');
  console.log('   You can manage it anytime:');
  console.log('   • Open:  services.msc  → look for "HinoptPosApi"');
  console.log('   • Or:    sc start HinoptPosApi  /  sc stop HinoptPosApi');
  console.log('');
  console.log('   To uninstall:  node uninstall-service.js');
  console.log('');
});

svc.on('alreadyinstalled', () => {
  console.log('ℹ️   Service is already installed.');
  console.log('    To reinstall, run:  node uninstall-service.js   then re-run this script.');
});

svc.on('invalidinstallation', () => {
  console.error('❌  Invalid installation. The service files may be missing or corrupt.');
  console.error('    Run: npm run build   to rebuild, then try again.');
});

svc.on('error', (err) => {
  console.error('❌  Service error:', err);
});

// ── Pre-flight checks ────────────────────────────────────────────────────────
const fs = require('fs');

if (!fs.existsSync(SCRIPT_PATH)) {
  console.error('');
  console.error('❌  Built file not found at:', SCRIPT_PATH);
  console.error('');
  console.error('   Please build the project first:');
  console.error('   > npm run build');
  console.error('');
  console.error('   Then re-run this installer.');
  process.exit(1);
}

console.log('');
console.log('🔧  Installing Hinopt POS API as a Windows Service...');
console.log('    Script:', SCRIPT_PATH);
console.log('    Name:  ', SERVICE_NAME);
console.log('');

svc.install();
