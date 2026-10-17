import { Command } from 'commander';
import fs from 'fs';
import path from 'path';
import { generateEd25519KeyPair, signLicense, verifyLicense } from './crypto.js';

const program = new Command();

program
  .name('hinopt-license')
  .description('Hinopt Cloud — License Issuance & Verification CLI')
  .version('1.0.0');

// 1. Generate Ed25519 keypair
program
  .command('generate-keys')
  .description('Generate Ed25519 asymmetric key pair in PEM format')
  .option('-o, --out-dir <directory>', 'Directory to save keys', '.')
  .action((options) => {
    const { publicKeyPem, privateKeyPem } = generateEd25519KeyPair();
    const outDir = path.resolve(process.cwd(), options.outDir);

    if (!fs.existsSync(outDir)) {
      fs.mkdirSync(outDir, { recursive: true });
    }

    const pubPath = path.join(outDir, 'hinopt_ed25519_public.pem');
    const privPath = path.join(outDir, 'hinopt_ed25519_private.pem');

    fs.writeFileSync(pubPath, publicKeyPem, 'utf-8');
    fs.writeFileSync(privPath, privateKeyPem, 'utf-8');

    console.log('✅ Ed25519 key pair generated successfully:');
    console.log(`   Public Key (Deploy to Restaurant PC .env): ${pubPath}`);
    console.log(`   Private Key (STRICTLY SECURE ON HINOPT CLOUD): ${privPath}`);
  });

// 2. Issue a signed license
program
  .command('issue')
  .description('Issue and cryptographically sign a restaurant license token')
  .requiredOption('--restaurant-id <id>', 'Unique restaurant ID (e.g. rest_curry_leaf_01)')
  .requiredOption('--name <name>', 'Restaurant business name')
  .option('--license-key <key>', 'License key identifier', `HINOPT-LIC-${Date.now()}`)
  .option('--days <number>', 'License validity in days', '365')
  .option('--max-devices <number>', 'Maximum registered devices', '10')
  .option('--private-key <path>', 'Path to private key PEM', 'hinopt_ed25519_private.pem')
  .option('--out <path>', 'Optional output file path to write the JSON token')
  .action((options) => {
    const privKeyPath = path.resolve(process.cwd(), options.privateKey);
    if (!fs.existsSync(privKeyPath)) {
      console.error(`❌ Error: Private key file not found at: ${privKeyPath}`);
      console.error('   Run "hinopt-license generate-keys" first to create keypair.');
      process.exit(1);
    }

    const privateKeyPem = fs.readFileSync(privKeyPath, 'utf-8');
    const validFrom = new Date().toISOString();
    const validUntil = new Date(
      Date.now() + parseInt(options.days, 10) * 24 * 60 * 60 * 1000
    ).toISOString();

    const signedToken = signLicense(
      {
        restaurantId: options.restaurantId,
        restaurantName: options.name,
        licenseKey: options.licenseKey,
        validFrom,
        validUntil,
        maxDevices: parseInt(options.maxDevices, 10),
        status: 'active',
        features: ['pos', 'kot', 'billing', 'reports', 'thermal_printing'],
      },
      privateKeyPem
    );

    const outputJson = JSON.stringify(signedToken, null, 2);

    if (options.out) {
      fs.writeFileSync(path.resolve(process.cwd(), options.out), outputJson, 'utf-8');
      console.log(`✅ Signed license written to: ${options.out}`);
    } else {
      console.log('\n======================================================');
      console.log('  HINOPT RESTAURANT POS — SIGNED LICENSE TOKEN');
      console.log('======================================================');
      console.log(outputJson);
      console.log('======================================================');
      console.log('Use this payload for POST /api/license/verify or in Counter PC setup.\n');
    }
  });

// 3. Verify a license
program
  .command('verify')
  .description('Verify a signed license token using the public key')
  .requiredOption('--payload <base64>', 'Base64 encoded license payload')
  .requiredOption('--signature <hex>', 'Hexadecimal digital signature')
  .option('--public-key <path>', 'Path to public key PEM', 'hinopt_ed25519_public.pem')
  .action((options) => {
    const pubKeyPath = path.resolve(process.cwd(), options.publicKey);
    if (!fs.existsSync(pubKeyPath)) {
      console.error(`❌ Error: Public key file not found at: ${pubKeyPath}`);
      process.exit(1);
    }

    const publicKeyPem = fs.readFileSync(pubKeyPath, 'utf-8');
    const result = verifyLicense(options.payload, options.signature, publicKeyPem);

    if (result.isValid) {
      console.log('✅ License verification SUCCESSFUL:');
      console.log(JSON.stringify(result.payload, null, 2));
    } else {
      console.error('❌ License verification FAILED:');
      console.error(result.error);
      process.exit(1);
    }
  });

program.parse(process.argv);
