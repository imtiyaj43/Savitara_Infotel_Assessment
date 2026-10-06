const test = require('node:test');
const assert = require('node:assert');
const http = require('node:http');
const app = require('../src/app');

let server;
let baseUrl;

test.before((t, done) => {
  server = app.listen(0, '127.0.0.1', () => {
    const address = server.address();
    baseUrl = `http://127.0.0.1:${address.port}`;
    done();
  });
});

test.after((t, done) => {
  server.close(done);
});

function makeRequest(path) {
  return new Promise((resolve, reject) => {
    http.get(`${baseUrl}${path}`, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        try {
          resolve({
            statusCode: res.statusCode,
            headers: res.headers,
            body: JSON.parse(data),
          });
        } catch (_err) {
          resolve({
            statusCode: res.statusCode,
            headers: res.headers,
            body: data,
          });
        }
      });
    }).on('error', reject);
  });
}

test('GET /health returns 200 and healthy status', async () => {
  const res = await makeRequest('/health');
  assert.strictEqual(res.statusCode, 200);
  assert.strictEqual(res.body.status, 'healthy');
  assert.strictEqual(res.body.service, 'savitara-infotel-api');
  assert.ok(typeof res.body.uptime_seconds === 'number');
  assert.ok(res.body.timestamp);
});

test('GET /info returns system and compute info', async () => {
  const res = await makeRequest('/info');
  assert.strictEqual(res.statusCode, 200);
  assert.ok(res.body.system);
  assert.ok(res.body.aws_compute);
  assert.strictEqual(res.body.aws_compute.is_ec2, false); // Local test environment
});

test('GET / returns 200 and operational architecture information', async () => {
  const res = await makeRequest('/');
  assert.strictEqual(res.statusCode, 200);
  assert.strictEqual(res.body.status, 'OPERATIONAL');
  assert.ok(res.body.architecture);
  assert.strictEqual(res.body.architecture.client, 'Internet');
  assert.ok(res.body.database);
});
