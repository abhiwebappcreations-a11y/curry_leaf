import net from 'net';
import fs from 'fs';
import os from 'os';
import path from 'path';
import { exec } from 'child_process';
import { inMemoryStore, PrintJobRecord } from '../db/inMemoryStore.js';
import { config } from '../config/index.js';
import { logger } from '../utils/logger.js';

let jobCounter = 5000;

export class PrintService {
  public static async enqueueJob(
    targetPrinter: 'counter_bill' | 'kitchen_kot',
    jobType: 'bill' | 'kot' | 'reprint_bill' | 'reprint_kot' | 'test_print' | 'report',
    referenceId: string | undefined,
    payload: Record<string, unknown>,
    isReprint = false
  ): Promise<PrintJobRecord> {
    jobCounter += 1;
    const jobId = `job_${Date.now()}_${jobCounter}`;
    const now = new Date().toISOString();

    const job: PrintJobRecord = {
      id: jobId,
      targetPrinter,
      jobType,
      referenceId,
      payload: {
        ...payload,
        isReprint,
        printedAt: now,
      },
      status: 'queued',
      retryCount: 0,
      maxRetries: 3,
      isReprint,
      createdAt: now,
      updatedAt: now,
    };

    inMemoryStore.printJobs.set(job.id, job);

    logger.info(
      { jobId: job.id, target: targetPrinter, type: jobType, isReprint },
      'Print job enqueued successfully'
    );

    // Asynchronously dispatch physical print over Ethernet TCP socket
    this.processJob(job.id).catch((err) => {
      logger.error({ err, jobId }, 'Failed processing print job');
    });

    return job;
  }

  public static async processJob(jobId: string): Promise<void> {
    const job = inMemoryStore.printJobs.get(jobId);
    if (!job) return;

    job.status = 'processing';
    job.updatedAt = new Date().toISOString();

    try {
      const printerConfig = job.targetPrinter === 'kitchen_kot'
        ? config.printers.kitchenKot
        : config.printers.counterBill;

      // 1. Build ESC/POS binary buffer
      const escposBuffer = this.buildEscPosPayload(job);

      // 2. Auto-detect connection type:
      //    - If target contains ':' → treat as 'host:port' (Ethernet TCP / Port 9100)
      //    - Otherwise            → treat as Windows printer name (USB via print spooler)
      const isEthernet = printerConfig.target.includes(':');

      let didSend: boolean;
      if (isEthernet) {
        const targetParts = printerConfig.target.split(':');
        const host = targetParts[0] || '127.0.0.1';
        const port = parseInt(targetParts[1] || '9100', 10);
        didSend = await this.sendRawTcp(host, port, escposBuffer, 2500);

        if (didSend) {
          logger.info(
            { jobId: job.id, target: printerConfig.target, bytes: escposBuffer.length },
            `[ETHERNET] Dispatched to thermal printer at ${printerConfig.target}`
          );
        } else {
          logger.warn(
            { jobId: job.id, target: printerConfig.target },
            `[ETHERNET] TCP send failed — printer unreachable at ${printerConfig.target}`
          );
        }
      } else {
        // USB / Windows print spooler path
        didSend = await this.sendRawUsb(printerConfig.target, escposBuffer);

        if (didSend) {
          logger.info(
            { jobId: job.id, printerName: printerConfig.target, bytes: escposBuffer.length },
            `[USB] Dispatched to Windows printer "${printerConfig.target}"`
          );
        } else {
          logger.warn(
            { jobId: job.id, printerName: printerConfig.target },
            `[USB] Failed to send to Windows printer "${printerConfig.target}". Verify the printer name matches exactly in Windows Devices & Printers.`
          );
        }
      }

      if (didSend) {
        job.status = 'completed';
        job.updatedAt = new Date().toISOString();
      } else {
        job.retryCount += 1;
        const method = isEthernet ? 'Ethernet TCP (port 9100)' : 'USB Windows spooler';
        job.errorMessage = `Print failed via ${method} to "${printerConfig.target}". Check connection and printer name.`;
        job.status = job.retryCount >= job.maxRetries ? 'failed' : 'queued';
        job.updatedAt = new Date().toISOString();
      }
    } catch (err: any) {
      job.retryCount += 1;
      job.errorMessage = err.message || 'Thermal printer communication failed';
      job.status = job.retryCount >= job.maxRetries ? 'failed' : 'queued';
      job.updatedAt = new Date().toISOString();
      logger.warn({ jobId, err: err.message }, 'Print job processing notice');
    }
  }

  private static sendRawTcp(host: string, port: number, data: Buffer, timeoutMs = 2500): Promise<boolean> {
    return new Promise((resolve) => {
      const socket = new net.Socket();
      let resolved = false;

      socket.setTimeout(timeoutMs);

      socket.connect(port, host, () => {
        socket.write(data, () => {
          socket.end();
        });
      });

      socket.on('close', () => {
        if (!resolved) {
          resolved = true;
          resolve(true);
        }
      });

      socket.on('error', () => {
        if (!resolved) {
          resolved = true;
          socket.destroy();
          resolve(false);
        }
      });

      socket.on('timeout', () => {
        if (!resolved) {
          resolved = true;
          socket.destroy();
          resolve(false);
        }
      });
    });
  }

  /**
   * Sends raw ESC/POS bytes to a USB/Windows printer via the Windows print spooler.
   *
   * Strategy: Write the buffer to a temp .bin file, then use PowerShell to open a
   * RawPrintStream to the named Windows printer (exactly as shown in Devices & Printers).
   * This works for any Windows-shared or locally-attached USB printer without extra npm packages.
   *
   * @param printerName - Exact Windows printer name, e.g. "EPSON TM-T82X Receipt"
   * @param data        - Raw ESC/POS binary buffer
   */
  private static getRawPrinterExe(): string {
    const candidates = [
      path.resolve(process.cwd(), 'bin/RawPrinter.exe'),
      path.resolve(process.cwd(), 'services/local-api/bin/RawPrinter.exe'),
      path.resolve(__dirname, '../../bin/RawPrinter.exe'),
      'D:\\curry_leaf\\services\\local-api\\bin\\RawPrinter.exe',
    ];
    for (const p of candidates) {
      if (fs.existsSync(p)) return p;
    }
    return 'D:\\curry_leaf\\services\\local-api\\bin\\RawPrinter.exe';
  }

  private static sendRawUsb(printerName: string, data: Buffer): Promise<boolean> {
    return new Promise((resolve) => {
      const tmpFile = path.join(os.tmpdir(), `escpos_${Date.now()}.bin`);

      try {
        fs.writeFileSync(tmpFile, data);
      } catch (writeErr) {
        logger.error({ writeErr }, '[USB] Failed to write temp ESC/POS file');
        resolve(false);
        return;
      }

      const rawPrinterExe = this.getRawPrinterExe();
      const cmd = `"${rawPrinterExe}" "${printerName}" "${tmpFile}"`;

      exec(cmd, { timeout: 10000 }, (err, stdout, stderr) => {
        try { fs.rmSync(tmpFile, { force: true }); } catch (_) {}

        if (err) {
          logger.warn(
            { printerName, exitCode: err.code, stderr: stderr?.trim(), stdout: stdout?.trim() },
            '[USB] RawPrinter execution failed'
          );
          resolve(false);
        } else {
          logger.info(
            { printerName, stdout: stdout?.trim() },
            '[USB] RawPrinter successfully sent print job to Windows spooler'
          );
          resolve(true);
        }
      });
    });
  }

  private static buildEscPosPayload(job: PrintJobRecord): Buffer {
    const chunks: Buffer[] = [];

    // ESC @ (Initialize printer)
    chunks.push(Buffer.from([0x1B, 0x40]));
    // Character code table standard PC437
    chunks.push(Buffer.from([0x1B, 0x74, 0x00]));

    const profile = (inMemoryStore.settings.get('restaurant_profile') as any) || {
      name: config.restaurantName,
      address: 'Main Branch',
      phone: '',
      gstin: '',
    };

    const printerConf = job.targetPrinter === 'kitchen_kot'
      ? config.printers.kitchenKot
      : config.printers.counterBill;
    const isEthernet = (printerConf.target || '').includes(':');

    if (job.jobType === 'test_print') {
      // Center
      chunks.push(Buffer.from([0x1B, 0x61, 0x01]));
      // Double height + width
      chunks.push(Buffer.from([0x1D, 0x21, 0x11]));
      chunks.push(Buffer.from(`${profile.name || 'HINOPT POS'}\n`, 'utf-8'));
      // Normal size
      chunks.push(Buffer.from([0x1D, 0x21, 0x00]));
      chunks.push(Buffer.from('--------------------------------\n', 'utf-8'));
      chunks.push(Buffer.from(`*** ${isEthernet ? 'ETHERNET LAN' : 'USB DRIVER'} TEST SLIP ***\n`, 'utf-8'));
      chunks.push(Buffer.from([0x1B, 0x61, 0x00])); // Left
      chunks.push(Buffer.from(`Printer   : ${job.targetPrinter.toUpperCase()}\n`, 'utf-8'));
      chunks.push(Buffer.from(`Connection: ${isEthernet ? 'Ethernet LAN (Port 9100)' : 'USB Windows Print Spooler'}\n`, 'utf-8'));
      chunks.push(Buffer.from(`Target    : ${printerConf.target}\n`, 'utf-8'));
      chunks.push(Buffer.from(`Time      : ${new Date().toLocaleTimeString()}\n`, 'utf-8'));
      chunks.push(Buffer.from('Status    : HARDWARE OPERATIONAL\n', 'utf-8'));
      chunks.push(Buffer.from('--------------------------------\n\n\n', 'utf-8'));
    } else if (job.jobType === 'kot' || job.jobType === 'reprint_kot') {
      chunks.push(Buffer.from([0x1B, 0x61, 0x01]));
      chunks.push(Buffer.from([0x1D, 0x21, 0x11]));
      chunks.push(Buffer.from('KITCHEN ORDER TICKET\n', 'utf-8'));
      chunks.push(Buffer.from([0x1D, 0x21, 0x00]));
      if (job.isReprint) {
        chunks.push(Buffer.from('*** DUPLICATE REPRINT ***\n', 'utf-8'));
      }
      chunks.push(Buffer.from('================================\n', 'utf-8'));
      chunks.push(Buffer.from([0x1B, 0x61, 0x00]));
      chunks.push(Buffer.from(`KOT No: ${job.payload.kotNumber || job.referenceId || 'KOT'}\n`, 'utf-8'));
      chunks.push(Buffer.from(`Table : ${job.payload.tableName || job.payload.tableNumber || 'Table'}\n`, 'utf-8'));
      chunks.push(Buffer.from(`Time  : ${new Date().toLocaleTimeString()}\n`, 'utf-8'));
      chunks.push(Buffer.from('--------------------------------\n', 'utf-8'));
      chunks.push(Buffer.from('QTY  ITEM NAME\n', 'utf-8'));
      chunks.push(Buffer.from('--------------------------------\n', 'utf-8'));

      const items = (job.payload.items as any[]) || [];
      for (const item of items) {
        const qty = String(item.quantity || 1).padEnd(4, ' ');
        const name = String(item.name || item.nameSnapshot || 'Item');
        chunks.push(Buffer.from(`${qty} ${name}\n`, 'utf-8'));
        if (item.itemNotes) {
          chunks.push(Buffer.from(`     * Note: ${item.itemNotes}\n`, 'utf-8'));
        }
      }
      chunks.push(Buffer.from('--------------------------------\n\n\n', 'utf-8'));
    } else {
      // Bill receipt
      chunks.push(Buffer.from([0x1B, 0x61, 0x01])); // Center
      chunks.push(Buffer.from([0x1D, 0x21, 0x11])); // Double size
      chunks.push(Buffer.from(`${profile.name || 'HINOPT POS'}\n`, 'utf-8'));
      chunks.push(Buffer.from([0x1D, 0x21, 0x00])); // Normal size
      if (profile.address) chunks.push(Buffer.from(`${profile.address}\n`, 'utf-8'));
      if (profile.phone) chunks.push(Buffer.from(`Ph: ${profile.phone}\n`, 'utf-8'));
      if (profile.gstin) chunks.push(Buffer.from(`GSTIN: ${profile.gstin}\n`, 'utf-8'));
      if (job.isReprint) chunks.push(Buffer.from('*** DUPLICATE TAX INVOICE ***\n', 'utf-8'));
      chunks.push(Buffer.from('--------------------------------\n', 'utf-8'));
      chunks.push(Buffer.from([0x1B, 0x61, 0x00])); // Left
      chunks.push(Buffer.from(`Bill No: ${job.payload.billNumber || job.referenceId || 'BILL'}\n`, 'utf-8'));
      if (job.payload.tableNumber) chunks.push(Buffer.from(`Table  : ${job.payload.tableNumber}\n`, 'utf-8'));
      chunks.push(Buffer.from(`Date   : ${new Date().toLocaleDateString()} ${new Date().toLocaleTimeString()}\n`, 'utf-8'));
      chunks.push(Buffer.from('--------------------------------\n', 'utf-8'));
      chunks.push(Buffer.from('ITEM NAME            QTY  AMOUNT\n', 'utf-8'));
      chunks.push(Buffer.from('--------------------------------\n', 'utf-8'));

      const items = (job.payload.items as any[]) || [];
      for (const item of items) {
        const rawName = String(item.name || item.nameSnapshot || 'Item');
        const qty = Number(item.quantity || 1);
        
        // Compute correct price in paise
        let lineTotalPaise = 0;
        if (item.total !== undefined && item.total !== null && Number(item.total) > 0) {
          lineTotalPaise = Number(item.total);
        } else if (item.totalPaise !== undefined && item.totalPaise !== null && Number(item.totalPaise) > 0) {
          lineTotalPaise = Number(item.totalPaise);
        } else if (item.totalPaiseSnapshot !== undefined && Number(item.totalPaiseSnapshot) > 0) {
          lineTotalPaise = Number(item.totalPaiseSnapshot);
        } else {
          const unitP = Number(item.unitPrice || item.unitPricePaise || item.pricePaise || 0);
          lineTotalPaise = unitP * qty;
        }

        const amtStr = (lineTotalPaise / 100).toFixed(2).padStart(8, ' ');
        const qtyStr = String(qty).padStart(3, ' ');
        
        if (rawName.length <= 19) {
          const namePadded = rawName.padEnd(19, ' ');
          chunks.push(Buffer.from(`${namePadded} ${qtyStr} ${amtStr}\n`, 'utf-8'));
        } else {
          chunks.push(Buffer.from(`${rawName}\n`, 'utf-8'));
          const emptyPad = ''.padEnd(19, ' ');
          chunks.push(Buffer.from(`${emptyPad} ${qtyStr} ${amtStr}\n`, 'utf-8'));
        }
      }
      chunks.push(Buffer.from('--------------------------------\n', 'utf-8'));
      
      const subtotalPaise = Number(job.payload.subtotalPaise);
      if (!isNaN(subtotalPaise) && subtotalPaise > 0) {
        const subStr = (subtotalPaise / 100).toFixed(2).padStart(10, ' ');
        chunks.push(Buffer.from(`Subtotal:             ${subStr}\n`, 'utf-8'));
      }

      const taxPaise = Number(job.payload.taxPaise);
      if (!isNaN(taxPaise) && taxPaise > 0) {
        const taxStr = (taxPaise / 100).toFixed(2).padStart(10, ' ');
        chunks.push(Buffer.from(`GST Tax (5%):         ${taxStr}\n`, 'utf-8'));
      }

      const discountPaise = Number(job.payload.discountPaise);
      if (!isNaN(discountPaise) && discountPaise > 0) {
        const discStr = (discountPaise / 100).toFixed(2).padStart(10, ' ');
        chunks.push(Buffer.from(`Discount:            -${discStr}\n`, 'utf-8'));
      }

      const totalPaise = Number(job.payload.totalPaise) || 0;
      const totalStr = (totalPaise / 100).toFixed(2);
      chunks.push(Buffer.from('--------------------------------\n', 'utf-8'));
      // Emphasize Total
      chunks.push(Buffer.from([0x1B, 0x45, 0x01])); // Bold ON
      chunks.push(Buffer.from(`GRAND TOTAL:      INR ${totalStr}\n`, 'utf-8'));
      chunks.push(Buffer.from([0x1B, 0x45, 0x00])); // Bold OFF
      chunks.push(Buffer.from('--------------------------------\n', 'utf-8'));
      chunks.push(Buffer.from([0x1B, 0x61, 0x01])); // Center
      chunks.push(Buffer.from(`Thank you for visiting ${profile.name || 'us'}!\n\n\n`, 'utf-8'));
    }

    // GS V A 3 (Feed 3 lines and cut paper)
    chunks.push(Buffer.from([0x1D, 0x56, 0x41, 0x03]));

    return Buffer.concat(chunks);
  }

  public static async listJobs(status?: string): Promise<PrintJobRecord[]> {
    let jobs = Array.from(inMemoryStore.printJobs.values());
    if (status) {
      jobs = jobs.filter((j) => j.status === status);
    }
    return jobs.sort(
      (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
    );
  }

  public static async retryJob(jobId: string): Promise<PrintJobRecord> {
    const job = inMemoryStore.printJobs.get(jobId);
    if (!job) {
      throw new Error(`Print job '${jobId}' not found`);
    }

    job.status = 'queued';
    job.retryCount = 0;
    job.errorMessage = undefined;
    job.updatedAt = new Date().toISOString();

    await this.processJob(job.id);
    return job;
  }
}
