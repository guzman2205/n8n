# Stage 1: Build
FROM node:22-alpine AS builder

# Install system dependencies for node-gyp and pnpm/turbo
RUN apk add --no-cache python3 make g++ git

# Install pnpm and turbo
RUN npm install -g pnpm@10.22.0 turbo@2.7.3

WORKDIR /app

# Copy root config files
COPY pnpm-lock.yaml pnpm-workspace.yaml package.json ./

# Copy packages structure (excluding what's in .dockerignore)
COPY packages ./packages

# Install dependencies
RUN pnpm install --frozen-lockfile

# Copy everything else (if any root scripts are needed)
COPY . .

# Build the project
RUN pnpm build

# Stage 2: Production
FROM node:22-alpine

RUN apk add --no-cache tini python3 make g++

WORKDIR /home/node

# Copy built files and production node_modules
# Note: We copy n8n cli and its dependencies
COPY --from=builder /app/packages/cli /home/node/packages/cli
COPY --from=builder /app/node_modules /home/node/node_modules
COPY --from=builder /app/packages/core /home/node/packages/core
COPY --from=builder /app/packages/workflow /home/node/packages/workflow
COPY --from=builder /app/packages/nodes-base /home/node/packages/nodes-base
# Copy frontend if needed for the UI
COPY --from=builder /app/packages/frontend /home/node/packages/frontend

# Setup environment
ENV NODE_ENV=production
ENV N8N_PORT=5678
EXPOSE 5678

# Use tini as entrypoint
ENTRYPOINT ["/sbin/tini", "--"]

# Set binary path
ENV PATH="/home/node/packages/cli/bin:${PATH}"

# Start n8n
CMD ["n8n"]
