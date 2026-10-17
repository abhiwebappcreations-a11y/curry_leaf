import { inMemoryStore, PrintJobRecord } from '../db/inMemoryStore.js';
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

    // Asynchronously dispatch / simulate physical print
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
      // In production, this connects to network thermal printer on raw socket 9100 or USB
      // Here we simulate successful output and log ESC/POS ticket preview
      logger.info(
        { jobId: job.id, printer: job.targetPrinter, isReprint: job.isReprint },
        `[THERMAL PRINTER] Dispatched to ${job.targetPrinter.toUpperCase()}`
      );

      job.status = 'completed';
      job.updatedAt = new Date().toISOString();
    } catch (err: any) {
      job.retryCount += 1;
      job.errorMessage = err.message || 'Thermal printer communication failed';
      job.status = job.retryCount >= job.maxRetries ? 'failed' : 'queued';
      job.updatedAt = new Date().toISOString();
    }
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
