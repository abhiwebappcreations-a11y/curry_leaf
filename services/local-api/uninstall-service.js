/**
 * Hinopt POS - Windows Service Uninstaller
 * =========================================
 * Stops and removes the HinoptPosApi Windows Service.
 *
 * USAGE: Run as Administrator:
 *   node uninstall-service.js
 */

const path = require('path');
const { Service } = require('node-windows');

const svc = new Service({
  name:   'HinoptPosApi',
  script: path.resolve(__dirname, 'dist', 'index.js'),
});

svc.on('uninstall', () => {
  console.log('');
  console.log('✅  HinoptPosApi service uninstalled successfully.');
  console.log('    The service will no longer start automatically on boot.');
  console.log('');
  console.log('    To reinstall: node install-service.js');
  console.log('');
});

svc.on('error', (err) => {
  console.error('❌  Error during uninstall:', err);
});

svc.on('notinstalled', () => {
  console.log('ℹ️   Service is not installed. Nothing to remove.');
});

console.log('');
console.log('🔧  Stopping and uninstalling Hinopt POS API Windows Service...');
svc.uninstall();
