# Savitara Infotel Application Service

A production-style Node.js microservice designed to validate end-to-end cloud infrastructure flow:
`Internet` ➔ `ALB (HTTPS / 443)` ➔ `EC2 ASG (Private Subnets)` ➔ `RDS MySQL 8.0 (Private Subnets)`.

## Features
- **Liveness & Readiness Endpoint (`/health`)**: Responds with HTTP 200 within milliseconds for AWS ALB Target Group health checks.
- **End-to-End Overview (`/`)**: Returns operational status, runtime infrastructure metadata, and database connection state.
- **Dedicated Database Query (`/db-check`)**: Executes live MySQL queries (`SELECT NOW(), VERSION()`) to prove database connectivity.
- **EC2 IMDSv2 Integration (`/info`)**: Securely queries AWS Instance Metadata Service version 2 (IMDSv2) to display the instance ID, Availability Zone, and private IP.
- **AWS Secrets Manager Integration**: Retrieves RDS credentials securely at startup or runtime using AWS SDK v3 / instance profile, without hardcoding passwords.
- **Graceful Shutdown**: Intercepts `SIGTERM` and `SIGINT` to drain HTTP traffic and close database connection pools cleanly during Auto Scaling termination events.

## Endpoints

| Method | Path | Description | Expected Status |
|---|---|---|---|
| `GET` | `/health` | Target Group health check endpoint | `200 OK` |
| `GET` | `/` | Application dashboard with architecture and DB status | `200 OK` |
| `GET` | `/db-check` | Live MySQL connection and query test | `200 OK` (or `503` if DB unreachable) |
| `GET` | `/info` | EC2 metadata and system diagnostics | `200 OK` |

## Local Development & Testing

```bash
# Install dependencies
npm install

# Run unit tests
npm test

# Run locally in development mode
PORT=8080 npm start
```

## Environment Variables

| Variable | Description | Default |
|---|---|---|
| `PORT` | Listening HTTP port | `8080` |
| `NODE_ENV` | Environment mode | `production` |
| `DB_SECRET_NAME` | AWS Secrets Manager secret name | *(optional)* |
| `AWS_REGION` | AWS Region for Secrets Manager | `us-east-1` |
| `DB_HOST` | Database host (fallback/local override) | `127.0.0.1` |
| `DB_USER` | Database username | `root` |
| `DB_PASSWORD` | Database password | `password` |
| `DB_NAME` | Database schema name | `appdb` |
| `DB_PORT` | Database port | `3306` |
