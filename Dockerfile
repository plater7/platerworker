FROM docker.io/cloudflare/sandbox:0.7.0

# Install Node.js 22 (required by clawdbot) and rsync (for R2 backup sync)
# The base image has Node 20, we need to replace it with Node 22
# Using direct binary download for reliability
ENV NODE_VERSION=22.13.1
# Build cache bust: 033-multi-provider-support
RUN ARCH="$(dpkg --print-architecture)" \
    && case "${ARCH}" in \
         amd64) NODE_ARCH="x64" ;; \
         arm64) NODE_ARCH="arm64" ;; \
         *) echo "Unsupported architecture: ${ARCH}" >&2; exit 1 ;; \
       esac \
    && apt-get update && apt-get install -y xz-utils ca-certificates rsync \
    && curl -fsSLk https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz -o /tmp/node.tar.xz \
    && tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 \
    && rm /tmp/node.tar.xz \
    && node --version \
    && npm --version 

# Install pnpm globally
# Build cache bust: 036
RUN npm cache clean --force
RUN npm install -g pnpm --strict-ssl=false

# Install moltbot (CLI is still named clawdbot until upstream renames)
# Pin to specific version for reproducible builds
# Build cache bust: 036
RUN npm install -g clawdbot@2026.1.24-3 --strict-ssl=false \
    && clawdbot --version

# Create moltbot directories (paths still use clawdbot until upstream renames)
# Templates are stored in /root/.clawdbot-templates for initialization
RUN mkdir -p /root/.clawdbot \
    && mkdir -p /root/.clawdbot-templates \
    && mkdir -p /root/clawd \
    && mkdir -p /root/clawd/skills

# Copy startup script
# Build cache bust: 027-nvidia-patch
COPY start-moltbot.sh /usr/local/bin/start-moltbot.sh
RUN chmod +x /usr/local/bin/start-moltbot.sh

# Copy Clawdbot patch script
# Build cache bust: 036
COPY scripts/patch-clawdbot-nvidia.sh /usr/local/bin/patch-clawdbot-nvidia.sh
RUN chmod +x /usr/local/bin/patch-clawdbot-nvidia.sh

# Copy default configuration template
# Build cache bust: 027-nvidia-patch
COPY moltbot.json.template /root/.clawdbot-templates/moltbot.json.template

# Copy custom skills
COPY skills/ /root/clawd/skills/

# Set working directory
WORKDIR /root/clawd

# Expose the gateway port
EXPOSE 18789
# 036
