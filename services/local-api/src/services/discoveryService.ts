import os from 'os';
import dgram from 'dgram';
import { logger } from '../utils/logger.js';
import { config } from '../config/index.js';

export function getLanIpv4Address(): string {
  const ifaces = os.networkInterfaces();
  let candidate = '127.0.0.1';

  // Priority: Wi-Fi, WLAN, Ethernet, then other non-internal IPv4
  for (const name in ifaces) {
    for (const iface of ifaces[name] || []) {
      if (iface.family === 'IPv4' && !iface.internal) {
        if (/wi-fi|wlan|wireless|ethernet|eth|en/i.test(name)) {
          return iface.address;
        }
        candidate = iface.address;
      }
    }
  }
  return candidate;
}

export class DiscoveryService {
  private static socket: dgram.Socket | null = null;
  private static timer: NodeJS.Timeout | null = null;
  public static readonly DISCOVERY_PORT = 41234;

  public static start(): void {
    if (this.socket) return;

    try {
      this.socket = dgram.createSocket({ type: 'udp4', reuseAddr: true });

      this.socket.on('error', (err) => {
        logger.warn({ err: err.message }, 'UDP Discovery socket error');
      });

      this.socket.on('message', (msg, rinfo) => {
        try {
          const payload = JSON.parse(msg.toString());
          if (payload.query === 'find_hinopt_pos' || payload.action === 'discover') {
            const reply = Buffer.from(JSON.stringify(this.getBeaconPayload()));
            this.socket?.send(reply, 0, reply.length, rinfo.port, rinfo.address);
          }
        } catch (_) {}
      });

      this.socket.bind(this.DISCOVERY_PORT, () => {
        try {
          this.socket?.setBroadcast(true);
        } catch (_) {}

        logger.info(
          { port: this.DISCOVERY_PORT, lanIp: getLanIpv4Address() },
          'Wi-Fi Auto-Discovery Beacon service started'
        );

        // Broadcast beacon every 2.5 seconds
        this.timer = setInterval(() => {
          this.broadcastBeacon();
        }, 2500);

        this.broadcastBeacon();
      });
    } catch (err: any) {
      logger.warn({ err: err.message }, 'Failed to start UDP Discovery Beacon');
    }
  }

  public static getBeaconPayload(): object {
    return {
      service: 'hinopt_counter_pos',
      restaurantName: config.restaurantName || 'Curry Leaf Fine Dining',
      host: getLanIpv4Address(),
      port: config.port || 4000,
      protocol: 'http',
      version: '1.0.0',
      timestamp: Date.now(),
    };
  }

  private static broadcastBeacon(): void {
    if (!this.socket) return;
    try {
      const data = Buffer.from(JSON.stringify(this.getBeaconPayload()));
      this.socket.send(data, 0, data.length, this.DISCOVERY_PORT, '255.255.255.255');
    } catch (_) {}
  }

  public static stop(): void {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
    if (this.socket) {
      try {
        this.socket.close();
      } catch (_) {}
      this.socket = null;
    }
  }
}
