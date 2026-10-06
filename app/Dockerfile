# Production-grade multi-stage Dockerfile
FROM node:20-alpine AS builder

WORKDIR /usr/src/app

COPY package*.json ./
RUN npm ci --omit=dev

# Final runtime image
FROM node:20-alpine

# Set secure environment variables
ENV NODE_ENV=production \
    PORT=8080

WORKDIR /usr/src/app

# Run as non-privileged user for security
USER node

# Copy dependencies and source code
COPY --chown=node:node --from=builder /usr/src/app/node_modules ./node_modules
COPY --chown=node:node package*.json ./
COPY --chown=node:node src ./src

# Expose the application port
EXPOSE 8080

# Health check matching ALB target group
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

CMD ["node", "src/server.js"]
