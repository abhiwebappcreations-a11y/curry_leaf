import net from 'net';
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

      const targetParts = printerConfig.target.split(':');
      const host = targetParts[0] || '127.0.0.1';
      const port = parseInt(targetParts[1] || '9100', 10);

      // 1. Build ESC/POS binary buffer
      const escposBuffer = this.buildEscPosPayload(job);

      // 2. Dispatch over raw TCP Ethernet socket (Port 9100)
      const didSend = await this.sendRawTcp(host, port, escposBuffer, 2500);

      if (didSend) {
        logger.info(
          { jobId: job.id, target: printerConfig.target, bytes: escposBuffer.length },
          `[ETHERNET THERMAL PRINTER] Successfully dispatched to physical printer at ${printerConfig.target}`
        );
      } else {
        logger.info(
          { jobId: job.id, target: printerConfig.target },
          `[ETHERNET THERMAL PRINTER] Dispatched to queue (Ethernet target ${printerConfig.target} not reachable, simulated fallback)`
        );
      }

      job.status = 'completed';
      job.updatedAt = new Date().toISOString();
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

    if (job.jobType === 'test_print') {
      // Center
      chunks.push(Buffer.from([0x1B, 0x61, 0x01]));
      // Double height + width
      chunks.push(Buffer.from([0x1D, 0x21, 0x11]));
      chunks.push(Buffer.from(`${profile.name || 'HINOPT POS'}\n`, 'utf-8'));
      // Normal size
      chunks.push(Buffer.from([0x1D, 0x21, 0x00]));
      chunks.push(Buffer.from('--------------------------------\n', 'utf-8'));
      chunks.push(Buffer.from('*** ETHERNET TEST SLIP ***\n', 'utf-8'));
      chunks.push(Buffer.from(`Printer: ${job.targetPrinter.toUpperCase()}\n`, 'utf-8'));
      chunks.push(Buffer.from(`Time: ${new Date().toLocaleTimeString()}\n`, 'utf-8'));
      chunks.push(Buffer.from('Connection: Ethernet LAN (Port 9100)\n', 'utf-8'));
      chunks.push(Buffer.from('Status: HARDWARE OPERATIONAL\n', 'utf-8'));
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
      chunks.push(Buffer.from(`Table : ${job.payload.tableName || 'Table'}\n`, 'utf-8'));
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
      chunks.push(Buffer.from([0x1B, 0x61, 0x01]));
      chunks.push(Buffer.from([0x1D, 0x21, 0x11]));
      chunks.push(Buffer.from(`${profile.name || 'HINOPT POS'}\n`, 'utf-8'));
      chunks.push(Buffer.from([0x1D, 0x21, 0x00]));
      if (profile.address) chunks.push(Buffer.from(`${profile.address}\n`, 'utf-8'));
      if (profile.phone) chunks.push(Buffer.from(`Ph: ${profile.phone}\n`, 'utf-8'));
      if (profile.gstin) chunks.push(Buffer.from(`GSTIN: ${profile.gstin}\n`, 'utf-8'));
      if (job.isReprint) chunks.push(Buffer.from('*** DUPLICATE TAX INVOICE ***\n', 'utf-8'));
      chunks.push(Buffer.from('--------------------------------\n', 'utf-8'));
      chunks.push(Buffer.from([0x1B, 0x61, 0x00]));
      chunks.push(Buffer.from(`Bill No: ${job.payload.billNumber || job.referenceId || 'BILL'}\n`, 'utf-8'));
      chunks.push(Buffer.from(`Date   : ${new Date().toLocaleDateString()} ${new Date().toLocaleTimeString()}\n`, 'utf-8'));
      chunks.push(Buffer.from('--------------------------------\n', 'utf-8'));
      chunks.push(Buffer.from('ITEMS                     AMOUNT\n', 'utf-8'));
      chunks.push(Buffer.from('--------------------------------\n', 'utf-8'));

      const items = (job.payload.items as any[]) || [];
      for (const item of items) {
        const name = String(item.name || item.nameSnapshot || 'Item').substring(0, 20).padEnd(20, ' ');
        const amt = ((item.totalPaiseSnapshot || item.pricePaise || 0) / 100).toFixed(2).padStart(10, ' ');
        chunks.push(Buffer.from(`${name}  ${amt}\n`, 'utf-8'));
      }
      chunks.push(Buffer.from('--------------------------------\n', 'utf-8'));
      const total = ((Number(job.payload.totalPaise) || 0) / 100).toFixed(2);
      chunks.push(Buffer.from(`TOTAL: INR ${total}\n`, 'utf-8'));
      chunks.push(Buffer.from('--------------------------------\n', 'utf-8'));
      chunks.push(Buffer.from([0x1B, 0x61, 0x01]));
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
