# Stage 1: Build the application
FROM --platform=$BUILDPLATFORM node:20-alpine AS builder

# Install build dependencies
RUN apk add --no-cache \
    git \
    zip \
    wget \
    curl \
    ca-certificates \
    python3 \
    make \
    g++

WORKDIR /app

# Copy package files
COPY package.json ./

# Install dependencies
RUN npm install

# Copy configuration files needed for lib building
COPY libs-config.json webpack.libs.config.js webpack-libs-plugin.js fonts.conf ./

# Create necessary directories for symlinks
RUN mkdir -p src public

# Build libraries (this step downloads WASM and clones repos)
# We do this before copying the rest of the source to leverage Docker cache
RUN npm run build:libs

# Copy the rest of the application source
COPY . .

# Build the application
RUN npm run build

# Stage 2: Serve the application with Nginx
FROM nginx:stable-alpine

# Copy custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy built assets from builder stage
COPY --from=builder /app/dist /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s \
  CMD wget --quiet --tries=1 --spider http://localhost:80/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
