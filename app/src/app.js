const express = require('express');
const http = require('http');
const { checkDatabase } = require('./db');

const app = express();
app.use(express.json());

// Request logging middleware
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    console.log(`[HTTP] ${req.method} ${req.originalUrl} ${res.statusCode} ${duration}ms - Client: ${req.ip}`);
  });
  next();
});

// Cache for EC2 IMDSv2 metadata
let ec2MetadataCache = null;

/**
 * Fetch EC2 metadata using secure IMDSv2 (Session token required)
 */
async function getEc2Metadata() {
  if (ec2MetadataCache) {
    return ec2MetadataCache;
  }

  const fetchWithTimeout = (url, options = {}, timeoutMs = 1500) => {
    return new Promise((resolve, reject) => {
      const u = new URL(url);
      const req = http.request(
        {
          hostname: u.hostname,
          port: u.port || 80,
          path: u.pathname,
          method: options.method || 'GET',
          headers: options.headers || {},
          timeout: timeoutMs,
        },
        (res) => {
          let data = '';
          res.on('data', (chunk) => (data += chunk));
          res.on('end', () => resolve({ status: res.statusCode, data }));
        }
      );
      req.on('error', reject);
      req.on('timeout', () => {
        req.destroy();
        reject(new Error('IMDS request timeout'));
      });
      if (options.body) req.write(options.body);
      req.end();
    });
  };

  try {
    // 1. Get IMDSv2 token (TTL: 60s)
    const tokenRes = await fetchWithTimeout(
      'http://169.254.169.254/latest/api/token',
      {
        method: 'PUT',
        headers: { 'X-aws-ec2-metadata-token-ttl-seconds': '60' },
      },
      1000
    );

    if (tokenRes.status !== 200) {
      throw new Error(`IMDSv2 token rejected: ${tokenRes.status}`);
    }

    const token = tokenRes.data;
    const imdsHeaders = { 'X-aws-ec2-metadata-token': token };

    // 2. Fetch instance-id, az, and private ip
    const [instanceIdRes, azRes, localIpRes] = await Promise.all([
      fetchWithTimeout('http://169.254.169.254/latest/meta-data/instance-id', { headers: imdsHeaders }, 1000),
      fetchWithTimeout('http://169.254.169.254/latest/meta-data/placement/availability-zone', { headers: imdsHeaders }, 1000),
      fetchWithTimeout('http://169.254.169.254/latest/meta-data/local-ipv4', { headers: imdsHeaders }, 1000),
    ]);

    ec2MetadataCache = {
      is_ec2: true,
      instance_id: instanceIdRes.data.trim(),
      availability_zone: azRes.data.trim(),
      private_ip: localIpRes.data.trim(),
      imds_version: 'IMDSv2',
    };
    return ec2MetadataCache;
  } catch (_err) {
    // Not running on EC2 or IMDS disabled
    return {
      is_ec2: false,
      instance_id: process.env.HOSTNAME || 'local-dev',
      availability_zone: process.env.AWS_REGION || 'local-zone',
      private_ip: '127.0.0.1',
      imds_version: 'N/A (Local / Non-EC2)',
    };
  }
}

/**
 * Health check endpoint for ALB Target Group
 * Must return HTTP 200 fast without blocking on downstream dependencies.
 */
app.get('/health', (_req, res) => {
  res.status(200).json({
    status: 'healthy',
    service: 'savitara-infotel-api',
    uptime_seconds: Math.floor(process.uptime()),
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV || 'production',
  });
});

/**
 * Root endpoint - High-level overview of system status, EC2 identity, and RDS connection
 */
app.get('/', async (_req, res) => {
  const metadata = await getEc2Metadata();
  const dbStatus = await checkDatabase();

  res.status(200).json({
    project: 'Savitara Infotel - DevOps Practical Task',
    description: 'Production AWS Infrastructure & CI/CD Pipeline',
    status: 'OPERATIONAL',
    timestamp: new Date().toISOString(),
    architecture: {
      client: 'Internet',
      ingress: 'AWS Application Load Balancer (HTTPS / ACM)',
      compute: 'EC2 Auto Scaling Group (Amazon Linux 2023, IMDSv2)',
      database: 'Amazon RDS MySQL 8.0 (Private Subnet)',
      secrets: 'AWS Secrets Manager',
      security: 'Least-Privilege Security Groups & IAM Roles',
    },
    runtime: metadata,
    database: dbStatus,
  });
});

/**
 * Dedicated database check endpoint
 */
app.get('/db-check', async (_req, res) => {
  const dbStatus = await checkDatabase();
  const statusCode = dbStatus.connected ? 200 : 503;
  res.status(statusCode).json({
    service: 'savitara-infotel-api',
    database_check: dbStatus,
    timestamp: new Date().toISOString(),
  });
});

/**
 * Infrastructure & Network Topology metadata endpoint
 */
app.get('/info', async (_req, res) => {
  const metadata = await getEc2Metadata();
  res.status(200).json({
    system: {
      node_version: process.version,
      platform: process.platform,
      arch: process.arch,
      memory_usage_mb: Math.round(process.memoryUsage().rss / 1024 / 1024),
      uptime_seconds: Math.floor(process.uptime()),
    },
    aws_compute: metadata,
    configuration: {
      port: process.env.PORT || 8080,
      region: process.env.AWS_REGION || 'us-east-1',
      secret_configured: !!process.env.DB_SECRET_NAME,
      db_host_configured: !!process.env.DB_HOST,
    },
  });
});

module.exports = app;
