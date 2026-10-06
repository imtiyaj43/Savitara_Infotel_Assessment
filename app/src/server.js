const app = require('./app');
const { closePool } = require('./db');

const PORT = parseInt(process.env.PORT || '8080', 10);
const HOST = '0.0.0.0';

const server = app.listen(PORT, HOST, () => {
  console.log(`=======================================================`);
  console.log(` Savitara Infotel Application Service Started`);
  console.log(` Listening on: http://${HOST}:${PORT}`);
  console.log(` Health check: http://${HOST}:${PORT}/health`);
  console.log(` DB check:     http://${HOST}:${PORT}/db-check`);
  console.log(` Environment:  ${process.env.NODE_ENV || 'production'}`);
  console.log(` Process PID:  ${process.pid}`);
  console.log(`=======================================================`);
});

// Graceful shutdown handling (systemd / ASG termination)
const shutdown = async (signal) => {
  console.log(`[SHUTDOWN] Received ${signal}. Starting graceful shutdown...`);
  server.close(async () => {
    console.log('[SHUTDOWN] HTTP server closed to new requests.');
    try {
      await closePool();
      console.log('[SHUTDOWN] Database connections closed.');
      process.exit(0);
    } catch (err) {
      console.error('[SHUTDOWN] Error closing database pool:', err);
      process.exit(1);
    }
  });

  // Force exit after 10 seconds if graceful shutdown takes too long
  setTimeout(() => {
    console.error('[SHUTDOWN] Forced termination after timeout.');
    process.exit(1);
  }, 10000);
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

process.on('unhandledRejection', (reason, promise) => {
  console.error('[FATAL] Unhandled Rejection at:', promise, 'reason:', reason);
});

process.on('uncaughtException', (error) => {
  console.error('[FATAL] Uncaught Exception:', error);
  process.exit(1);
});
