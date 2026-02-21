# Stage 1: Build
FROM node:22-bookworm AS builder

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    make \
    g++ \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install pnpm and turbo
RUN npm install -g pnpm@10.22.0 turbo@2.7.3

WORKDIR /app

# Copy root config files
COPY pnpm-lock.yaml pnpm-workspace.yaml package.json ./

# Copy packages structure
COPY packages ./packages

# Extreme memory optimizations
ENV NODE_OPTIONS="--max-old-space-size=8192"

# Install dependencies with no optional and ignore engines fallback
RUN pnpm install --frozen-lockfile --no-optional --ignore-engines --aggregate-output

# Copy the rest
COPY . .

# Build the project
RUN pnpm build

# Stage 2: Production
FROM node:22-bookworm-slim

RUN apt-get update && apt-get install -y \
    tini \
    python3 \
    make \
    g++ \
    sqlite3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /home/node

# Copy built files
COPY --from=builder /app/packages/cli /home/node/packages/cli
COPY --from=builder /app/node_modules /home/node/node_modules
COPY --from=builder /app/packages/core /home/node/packages/core
COPY --from=builder /app/packages/workflow /home/node/packages/workflow
COPY --from=builder /app/packages/nodes-base /home/node/packages/nodes-base
COPY --from=builder /app/packages/frontend /home/node/packages/frontend

# Setup environment
ENV NODE_ENV=production
ENV N8N_PORT=5678
EXPOSE 5678

# Use tini
ENTRYPOINT ["/usr/bin/tini", "--"]

# Set binary path
ENV PATH="/home/node/packages/cli/bin:${PATH}"

# Start n8n
CMD ["n8n"]
