const mysql = require('mysql2/promise');
const { SecretsManagerClient, GetSecretValueCommand } = require('@aws-sdk/client-secrets-manager');

let pool = null;
let cachedCredentials = null;

/**
 * Retrieve database credentials either from environment variables
 * or dynamically from AWS Secrets Manager if DB_SECRET_NAME is provided.
 */
async function getDbCredentials() {
  if (cachedCredentials) {
    return cachedCredentials;
  }

  // 1. Direct environment variables (highest priority or local override)
  if (process.env.DB_HOST && process.env.DB_USER && process.env.DB_PASSWORD) {
    cachedCredentials = {
      host: process.env.DB_HOST,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      database: process.env.DB_NAME || 'appdb',
      port: parseInt(process.env.DB_PORT || '3306', 10),
    };
    return cachedCredentials;
  }

  // 2. Fetch from AWS Secrets Manager if DB_SECRET_NAME is provided
  const secretName = process.env.DB_SECRET_NAME;
  const region = process.env.AWS_REGION || process.env.AWS_DEFAULT_REGION || 'us-east-1';

  if (secretName) {
    try {
      console.log(`[DB] Fetching database credentials from AWS Secrets Manager: ${secretName} (Region: ${region})`);
      const client = new SecretsManagerClient({ region });
      const command = new GetSecretValueCommand({ SecretId: secretName });
      const response = await client.send(command);

      if (response.SecretString) {
        const secret = JSON.parse(response.SecretString);
        cachedCredentials = {
          host: secret.host || process.env.DB_HOST,
          user: secret.username || secret.user || process.env.DB_USER,
          password: secret.password,
          database: secret.dbname || secret.database || process.env.DB_NAME || 'appdb',
          port: parseInt(secret.port || process.env.DB_PORT || '3306', 10),
        };
        console.log(`[DB] Successfully loaded credentials for host: ${cachedCredentials.host}`);
        return cachedCredentials;
      }
    } catch (err) {
      console.error(`[DB] Failed to load credentials from AWS Secrets Manager: ${err.message}`);
    }
  }

  // Fallback defaults for dev/mock mode
  return {
    host: process.env.DB_HOST || '127.0.0.1',
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || 'password',
    database: process.env.DB_NAME || 'appdb',
    port: parseInt(process.env.DB_PORT || '3306', 10),
  };
}

/**
 * Initialize or get MySQL connection pool
 */
async function getPool() {
  if (!pool) {
    const creds = await getDbCredentials();
    pool = mysql.createPool({
      host: creds.host,
      user: creds.user,
      password: creds.password,
      database: creds.database,
      port: creds.port,
      waitForConnections: true,
      connectionLimit: 10,
      queueLimit: 0,
      connectTimeout: 5000,
      enableKeepAlive: true,
      keepAliveInitialDelay: 10000,
    });
  }
  return pool;
}

/**
 * Execute a lightweight database health check
 */
async function checkDatabase() {
  try {
    const p = await getPool();
    const startTime = Date.now();
    const [rows] = await p.query('SELECT NOW() AS current_time, VERSION() AS mysql_version, 1 AS healthy');
    const latencyMs = Date.now() - startTime;

    return {
      connected: true,
      latency_ms: latencyMs,
      server_time: rows[0]?.current_time,
      engine_version: rows[0]?.mysql_version,
      database_name: (await getDbCredentials()).database,
    };
  } catch (error) {
    return {
      connected: false,
      error: error.message,
      code: error.code || 'UNKNOWN_ERROR',
    };
  }
}

/**
 * Close pool gracefully
 */
async function closePool() {
  if (pool) {
    await pool.end();
    pool = null;
  }
}

module.exports = {
  getDbCredentials,
  getPool,
  checkDatabase,
  closePool,
};
