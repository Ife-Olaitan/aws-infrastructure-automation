# Using Node.js 18 Alpine (lightweight Linux distribution)
FROM node:18-alpine

# Set working directory inside container
WORKDIR /app

# Copy package.json and package-lock.json for dependency installation
COPY package*.json ./

# Install production dependencies using npm ci (clean install)
RUN npm ci --only=production

# Copy application source code
COPY . .

# Expose port 3000 to allow external connections
EXPOSE 3000

# Health check - runs every 30 seconds to verify container is healthy
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node healthcheck.js || exit 1

# Start the Node.js application
CMD ["node", "server.js"]
