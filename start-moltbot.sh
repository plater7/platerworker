#!/bin/bash
# Startup script for Moltbot in Cloudflare Sandbox
# This script:
# 1. Restores config from R2 backup if available
# 2. Configures moltbot from environment variables
# 3. Starts a background sync to backup config to R2
# 4. Starts the gateway

set -e

# Check if clawdbot gateway is already running - bail early if so
# Note: CLI is still named "clawdbot" until upstream renames it
if pgrep -f "clawdbot gateway" > /dev/null 2>&1; then
    echo "Moltbot gateway is already running, exiting."
    exit 0
fi

# Paths (clawdbot paths are used internally - upstream hasn't renamed yet)
CONFIG_DIR="/root/.clawdbot"
CONFIG_FILE="$CONFIG_DIR/clawdbot.json"
TEMPLATE_DIR="/root/.clawdbot-templates"
TEMPLATE_FILE="$TEMPLATE_DIR/moltbot.json.template"
BACKUP_DIR="/data/moltbot"

echo "Config directory: $CONFIG_DIR"
echo "Backup directory: $BACKUP_DIR"

# Create config directory
mkdir -p "$CONFIG_DIR"

# ============================================================
# RESTORE FROM R2 BACKUP
# ============================================================
# Check if R2 backup exists by looking for clawdbot.json
# The BACKUP_DIR may exist but be empty if R2 was just mounted
# Note: backup structure is $BACKUP_DIR/clawdbot/ and $BACKUP_DIR/skills/

# Helper function to check if R2 backup is newer than local
should_restore_from_r2() {
    local R2_SYNC_FILE="$BACKUP_DIR/.last-sync"
    local LOCAL_SYNC_FILE="$CONFIG_DIR/.last-sync"
    
    # If no R2 sync timestamp, don't restore
    if [ ! -f "$R2_SYNC_FILE" ]; then
        echo "No R2 sync timestamp found, skipping restore"
        return 1
    fi
    
    # If no local sync timestamp, restore from R2
    if [ ! -f "$LOCAL_SYNC_FILE" ]; then
        echo "No local sync timestamp, will restore from R2"
        return 0
    fi
    
    # Compare timestamps
    R2_TIME=$(cat "$R2_SYNC_FILE" 2>/dev/null)
    LOCAL_TIME=$(cat "$LOCAL_SYNC_FILE" 2>/dev/null)
    
    echo "R2 last sync: $R2_TIME"
    echo "Local last sync: $LOCAL_TIME"
    
    # Convert to epoch seconds for comparison
    R2_EPOCH=$(date -d "$R2_TIME" +%s 2>/dev/null || echo "0")
    LOCAL_EPOCH=$(date -d "$LOCAL_TIME" +%s 2>/dev/null || echo "0")
    
    if [ "$R2_EPOCH" -gt "$LOCAL_EPOCH" ]; then
        echo "R2 backup is newer, will restore"
        return 0
    else
        echo "Local data is newer or same, skipping restore"
        return 1
    fi
}

if [ -f "$BACKUP_DIR/clawdbot/clawdbot.json" ]; then
    if should_restore_from_r2; then
        echo "Restoring from R2 backup at $BACKUP_DIR/clawdbot..."
        cp -a "$BACKUP_DIR/clawdbot/." "$CONFIG_DIR/"
        # Copy the sync timestamp to local so we know what version we have
        cp -f "$BACKUP_DIR/.last-sync" "$CONFIG_DIR/.last-sync" 2>/dev/null || true
        echo "Restored config from R2 backup"
    fi
elif [ -f "$BACKUP_DIR/clawdbot.json" ]; then
    # Legacy backup format (flat structure)
    if should_restore_from_r2; then
        echo "Restoring from legacy R2 backup at $BACKUP_DIR..."
        cp -a "$BACKUP_DIR/." "$CONFIG_DIR/"
        cp -f "$BACKUP_DIR/.last-sync" "$CONFIG_DIR/.last-sync" 2>/dev/null || true
        echo "Restored config from legacy R2 backup"
    fi
elif [ -d "$BACKUP_DIR" ]; then
    echo "R2 mounted at $BACKUP_DIR but no backup data found yet"
else
    echo "R2 not mounted, starting fresh"
fi

# Restore skills from R2 backup if available (only if R2 is newer)
SKILLS_DIR="/root/clawd/skills"
if [ -d "$BACKUP_DIR/skills" ] && [ "$(ls -A $BACKUP_DIR/skills 2>/dev/null)" ]; then
    if should_restore_from_r2; then
        echo "Restoring skills from $BACKUP_DIR/skills..."
        mkdir -p "$SKILLS_DIR"
        cp -a "$BACKUP_DIR/skills/." "$SKILLS_DIR/"
        echo "Restored skills from R2 backup"
    fi
fi

# Ensure workspace directory exists (even after restore)
mkdir -p "/root/.clawdbot/workspace"

# If config file still doesn't exist, create from template
if [ ! -f "$CONFIG_FILE" ]; then
    echo "No existing config found, initializing from template..."
    if [ -f "$TEMPLATE_FILE" ]; then
        cp "$TEMPLATE_FILE" "$CONFIG_FILE"
    else
        # Create minimal config if template doesn't exist
        cat > "$CONFIG_FILE" << 'EOFCONFIG'
{
  "agents": {
    "defaults": {
      "workspace": "/root/.clawdbot/workspace"
    }
  },
  "gateway": {
    "port": 18789,
    "mode": "local"
  }
}
EOFCONFIG
    fi
else
    echo "Using existing config"
fi

# ============================================================
# UPDATE CONFIG FROM ENVIRONMENT VARIABLES
# ============================================================
node << EOFNODE
const fs = require('fs');

const configPath = '/root/.clawdbot/clawdbot.json';
console.log('Updating config at:', configPath);
let config = {};

try {
    config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
} catch (e) {
    console.log('Starting with empty config');
}

// Ensure nested objects exist
config.agents = config.agents || {};
config.agents.defaults = config.agents.defaults || {};
config.agents.defaults.model = config.agents.defaults.model || {};
config.gateway = config.gateway || {};
config.channels = config.channels || {};

// Helper function to configure OpenRouter models
function configureOpenRouterModels() {
    console.log('Configuring OpenRouter with multiple models...');

    // Add all model aliases (description not supported by clawdbot schema)
    config.agents.defaults.models = config.agents.defaults.models || {};

    // Auto-routing / Free-routing
    config.agents.defaults.models['openrouter/auto'] = { alias: 'auto' };
    config.agents.defaults.models['openrouter/free'] = { alias: 'free' };

    // General purpose
    config.agents.defaults.models['openrouter/deepseek/deepseek-chat-v3-0324'] = { alias: 'deep' };

    // Coding specialists
    config.agents.defaults.models['openrouter/qwen/qwen-2.5-coder-32b-instruct'] = { alias: 'qwen' };
    config.agents.defaults.models['openrouter/qwen/qwen-2.5-coder-32b-instruct:free'] = { alias: 'qwenfree' };
    config.agents.defaults.models['openrouter/mistralai/devstral-small:free'] = { alias: 'devstral' };
    config.agents.defaults.models['openrouter/xiaomi/mimo-vl-7b:free'] = { alias: 'mimofree' };
    config.agents.defaults.models['openrouter/x-ai/grok-code-fast-1'] = { alias: 'grokcode' };

    // Agentic / Tools
    config.agents.defaults.models['openrouter/x-ai/grok-4.1-fast'] = { alias: 'grok' };
    //config.agents.defaults.models['openrouter/moonshotai/kimi-k2.5'] = { alias: 'kimi' };

    // Speed / Fast
    config.agents.defaults.models['openrouter/google/gemini-2.0-flash-001'] = { alias: 'flash' };

    // Claude models
    config.agents.defaults.models['openrouter/anthropic/claude-3.5-haiku'] = { alias: 'haiku' };
    config.agents.defaults.models['openrouter/anthropic/claude-sonnet-4'] = { alias: 'sonnet' };

    // OpenAI models
    config.agents.defaults.models['openrouter/openai/gpt-4o-mini'] = { alias: 'mini' };
    config.agents.defaults.models['openrouter/openai/gpt-4o'] = { alias: 'gpt' };

    // Reasoning models
    config.agents.defaults.models['openrouter/deepseek/deepseek-reasoner'] = { alias: 'think' };
    config.agents.defaults.models['openrouter/qwen/qwq-32b-preview'] = { alias: 'qwq' };

    // GLM
    config.agents.defaults.models['openrouter/z-ai/glm-4.7'] = { alias: 'glm-4.7' };
    config.agents.defaults.models['openrouter/z-ai/glm-4.5-air:free'] = { alias: 'glmfree' };

}


// Helper function to configure Nvidia NIM models
function configureNvidiaModels() {
    console.log('Configuring Nvidia API with NIM models...');

    // Add all Nvidia NIM model aliases
    config.agents.defaults.models = config.agents.defaults.models || {};

    // Moonshot AI - Kimi models
    config.agents.defaults.models['nvidia/moonshotai/kimi-k2.5'] = { alias: 'kimi' };
    config.agents.defaults.models['nvidia/moonshotai/moonshot-v1-8k'] = { alias: 'moonshot8k' };
    config.agents.defaults.models['nvidia/moonshotai/moonshot-v1-32k'] = { alias: 'moonshot32k' };
    config.agents.defaults.models['nvidia/moonshotai/moonshot-v1-128k'] = { alias: 'moonshot128k' };

    // Meta Llama models
    config.agents.defaults.models['nvidia/meta/llama-3.3-70b-instruct'] = { alias: 'llama70b' };
    config.agents.defaults.models['nvidia/meta/llama-3.1-405b-instruct'] = { alias: 'llama405b' };

    // Mistral models
    config.agents.defaults.models['nvidia/mistralai/mistral-large-2-instruct'] = { alias: 'mistral' };
    config.agents.defaults.models['nvidia/mistralai/mixtral-8x7b-instruct'] = { alias: 'mixtral' };

    // Google models
    config.agents.defaults.models['nvidia/google/gemma-2-27b-it'] = { alias: 'gemma27b' };

    // Nvidia proprietary
    config.agents.defaults.models['nvidia/nvidia/llama-3.1-nemotron-70b-instruct'] = { alias: 'nemotron' };

    // IBM Granite
    config.agents.defaults.models['nvidia/ibm/granite-3.1-8b-instruct'] = { alias: 'granite' };

    // DeepSeek
    config.agents.defaults.models['nvidia/deepseek-ai/deepseek-r1'] = { alias: 'deepseek-r1' };

}

// Clean up any broken anthropic provider config from previous runs
// (older versions didn't include required 'name' field)
if (config.models?.providers?.anthropic?.models) {
    const hasInvalidModels = config.models.providers.anthropic.models.some(m => !m.name);
    if (hasInvalidModels) {
        console.log('Removing broken anthropic provider config (missing model names)');
        delete config.models.providers.anthropic;
    }
}

// Clean up invalid openrouter provider config (OpenRouter uses built-in support, no providers config needed)
if (config.models?.providers?.openrouter) {
    console.log('Removing invalid models.providers.openrouter block');
    delete config.models.providers.openrouter;
    if (config.models.providers && Object.keys(config.models.providers).length === 0) {
        delete config.models.providers;
    }
    if (config.models && Object.keys(config.models).length === 0) {
        delete config.models;
    }
}



// Gateway configuration
config.gateway.port = 18789;
config.gateway.mode = 'local';
config.gateway.trustedProxies = ['10.1.0.0'];

// Set gateway token if provided
if (process.env.CLAWDBOT_GATEWAY_TOKEN) {
    config.gateway.auth = config.gateway.auth || {};
    config.gateway.auth.token = process.env.CLAWDBOT_GATEWAY_TOKEN;
}

// Allow insecure auth for dev mode
if (process.env.CLAWDBOT_DEV_MODE === 'true') {
    config.gateway.controlUi = config.gateway.controlUi || {};
    config.gateway.controlUi.allowInsecureAuth = true;
}

// Telegram configuration
if (process.env.TELEGRAM_BOT_TOKEN) {
    config.channels.telegram = config.channels.telegram || {};
    config.channels.telegram.botToken = process.env.TELEGRAM_BOT_TOKEN;
    config.channels.telegram.enabled = true;
    const telegramDmPolicy = process.env.TELEGRAM_DM_POLICY || 'pairing';
    config.channels.telegram.dmPolicy = telegramDmPolicy;
    if (process.env.TELEGRAM_DM_ALLOW_FROM) {
        // Explicit allowlist: "123,456,789" → ['123', '456', '789']
        config.channels.telegram.allowFrom = process.env.TELEGRAM_DM_ALLOW_FROM.split(',');
    } else if (telegramDmPolicy === 'open') {
        // "open" policy requires allowFrom: ["*"]
        config.channels.telegram.allowFrom = ['*'];
    }
}

// Discord configuration
// Note: Discord uses nested dm.policy, not flat dmPolicy like Telegram
// See: https://github.com/moltbot/moltbot/blob/v2026.1.24-1/src/config/zod-schema.providers-core.ts#L147-L155
if (process.env.DISCORD_BOT_TOKEN) {
    config.channels.discord = config.channels.discord || {};
    config.channels.discord.token = process.env.DISCORD_BOT_TOKEN;
    config.channels.discord.enabled = true;
    const discordDmPolicy = process.env.DISCORD_DM_POLICY || 'pairing';
    config.channels.discord.dm = config.channels.discord.dm || {};
    config.channels.discord.dm.policy = discordDmPolicy;
    // "open" policy requires allowFrom: ["*"]
    if (discordDmPolicy === 'open') {
        config.channels.discord.dm.allowFrom = ['*'];
    }
}

// Slack configuration
if (process.env.SLACK_BOT_TOKEN && process.env.SLACK_APP_TOKEN) {
    config.channels.slack = config.channels.slack || {};
    config.channels.slack.botToken = process.env.SLACK_BOT_TOKEN;
    config.channels.slack.appToken = process.env.SLACK_APP_TOKEN;
    config.channels.slack.enabled = true;
}

// ============================================================
// MULTI-PROVIDER CONFIGURATION
// ============================================================
// Configure all available providers independently.
// This allows switching between providers using model prefixes:
// - /openrouter/qwen
// - /nvidia/kimi
// - /anthropic/claude-opus-4-5
// ============================================================

console.log('Configuring AI providers...');

// Initialize models object
config.models = config.models || {};
config.models.providers = config.models.providers || {};
config.agents.defaults.models = config.agents.defaults.models || {};

let primaryModelSet = false;

// Detect base URL type from AI_GATEWAY_BASE_URL or ANTHROPIC_BASE_URL
const baseUrl = (process.env.AI_GATEWAY_BASE_URL || process.env.ANTHROPIC_BASE_URL || '').replace(/\/+$/, '');
const isOpenAIGateway = baseUrl.endsWith('/openai');
const isOpenRouterGateway = baseUrl.endsWith('openrouter.ai/api/v1');
const isNvidiaGateway = baseUrl.includes('api.nvidia.com') || baseUrl.includes('integrate.api.nvidia.com');
const isAnthropicGateway = baseUrl && !isOpenAIGateway && !isOpenRouterGateway && !isNvidiaGateway;

// ============================================================
// OPENAI PROVIDER
// ============================================================
if (isOpenAIGateway || process.env.OPENAI_API_KEY) {
    console.log('Configuring OpenAI provider...');
    const openaiBaseUrl = isOpenAIGateway ? baseUrl : undefined;

    config.models.providers.openai = {
        api: 'openai-responses',
        models: [
            { id: 'gpt-5.2', name: 'GPT-5.2', contextWindow: 200000 },
            { id: 'gpt-5', name: 'GPT-5', contextWindow: 200000 },
            { id: 'gpt-4.5-preview', name: 'GPT-4.5 Preview', contextWindow: 128000 },
            { id: 'gpt-4o', name: 'GPT-4o', contextWindow: 128000 },
        ]
    };

    if (openaiBaseUrl) {
        config.models.providers.openai.baseUrl = openaiBaseUrl;
        console.log('  - Using OpenAI via AI Gateway:', openaiBaseUrl);
    } else {
        console.log('  - Using OpenAI with default endpoint');
    }

    // Add model aliases
    config.agents.defaults.models['openai/gpt-5.2'] = { alias: 'GPT-5.2' };
    config.agents.defaults.models['openai/gpt-5'] = { alias: 'GPT-5' };
    config.agents.defaults.models['openai/gpt-4.5-preview'] = { alias: 'GPT-4.5' };
    config.agents.defaults.models['openai/gpt-4o'] = { alias: 'GPT-4o' };

    // Set as primary if not already set
    if (!primaryModelSet) {
        config.agents.defaults.model.primary = 'openai/gpt-5.2';
        primaryModelSet = true;
        console.log('  - Set as primary model: openai/gpt-5.2');
    }
}

// ============================================================
// OPENROUTER PROVIDER
// ============================================================
if (isOpenRouterGateway || process.env.OPENROUTER_API_KEY) {
    console.log('Configuring OpenRouter provider...');

    // OpenRouter uses built-in support, so we just configure models
    configureOpenRouterModels();

    if (isOpenRouterGateway) {
        console.log('  - Using OpenRouter via AI Gateway:', baseUrl);
    } else {
        console.log('  - Using OpenRouter with default endpoint');
    }

    // Set as primary if not already set
    if (!primaryModelSet) {
        config.agents.defaults.model.primary = 'openrouter/free';
        primaryModelSet = true;
        console.log('  - Set as primary model: openrouter/free');
    }
}

// ============================================================
// NVIDIA PROVIDER
// ============================================================
if (isNvidiaGateway || process.env.NVIDIA_API_KEY) {
    console.log('Configuring Nvidia provider...');

    const nvidiaBaseUrl = isNvidiaGateway ? baseUrl : 'https://integrate.api.nvidia.com/v1';
    const nvidiaApiKey = process.env.NVIDIA_API_KEY || process.env.AI_GATEWAY_API_KEY || '';

    config.models.providers.nvidia = {
        baseUrl: nvidiaBaseUrl,
        apiKey: nvidiaApiKey
    };

    console.log('  - Using Nvidia endpoint:', nvidiaBaseUrl);

    // Configure Nvidia models
    configureNvidiaModels();

    // Set as primary if not already set
    if (!primaryModelSet) {
        config.agents.defaults.model.primary = 'nvidia/moonshotai/kimi-k2.5';
        primaryModelSet = true;
        console.log('  - Set as primary model: nvidia/moonshotai/kimi-k2.5');
    }
}

// ============================================================
// ANTHROPIC PROVIDER
// ============================================================
if (isAnthropicGateway || process.env.ANTHROPIC_API_KEY) {
    console.log('Configuring Anthropic provider...');

    const anthropicBaseUrl = isAnthropicGateway ? baseUrl : undefined;

    const providerConfig = {
        api: 'anthropic-messages',
        models: [
            { id: 'claude-opus-4-5-20251101', name: 'Claude Opus 4.5', contextWindow: 200000 },
            { id: 'claude-sonnet-4-5-20250929', name: 'Claude Sonnet 4.5', contextWindow: 200000 },
            { id: 'claude-haiku-4-5-20251001', name: 'Claude Haiku 4.5', contextWindow: 200000 },
        ]
    };

    if (anthropicBaseUrl) {
        providerConfig.baseUrl = anthropicBaseUrl;
        console.log('  - Using Anthropic via AI Gateway:', anthropicBaseUrl);
    } else {
        console.log('  - Using Anthropic with default endpoint');
    }

    // Include API key in provider config if set
    if (process.env.ANTHROPIC_API_KEY) {
        providerConfig.apiKey = process.env.ANTHROPIC_API_KEY;
    }

    config.models.providers.anthropic = providerConfig;

    // Add model aliases
    config.agents.defaults.models['anthropic/claude-opus-4-5-20251101'] = { alias: 'Opus 4.5' };
    config.agents.defaults.models['anthropic/claude-sonnet-4-5-20250929'] = { alias: 'Sonnet 4.5' };
    config.agents.defaults.models['anthropic/claude-haiku-4-5-20251001'] = { alias: 'Haiku 4.5' };

    // Set as primary if not already set
    if (!primaryModelSet) {
        config.agents.defaults.model.primary = 'anthropic/claude-opus-4-5-20251101';
        primaryModelSet = true;
        console.log('  - Set as primary model: anthropic/claude-opus-4-5-20251101');
    }
}

// ============================================================
// FALLBACK: If no provider configured, use OpenRouter
// ============================================================
if (!primaryModelSet) {
    console.log('No API keys configured, defaulting to OpenRouter...');
    configureOpenRouterModels();
    config.agents.defaults.model.primary = 'openrouter/free';
    console.log('  - Set as primary model: openrouter/free');
}

// Log detailed provider summary
console.log('');
console.log('='.repeat(60));
console.log('PROVIDER CONFIGURATION SUMMARY');
console.log('='.repeat(60));
console.log('Primary model:', config.agents.defaults.model.primary);
console.log('');

const providers = Object.keys(config.models.providers || {});
if (providers.length > 0) {
    console.log('Configured providers (' + providers.length + '):');
    providers.forEach(p => {
        console.log('  - ' + p);
        const providerConfig = config.models.providers[p];
        if (providerConfig.baseUrl) {
            console.log('    baseUrl: ' + providerConfig.baseUrl);
        }
        if (providerConfig.models) {
            console.log('    models: ' + providerConfig.models.length);
        }
    });
} else {
    console.log('No providers configured (using built-in OpenRouter)');
}

console.log('');
const modelCount = Object.keys(config.agents.defaults.models || {}).length;
console.log('Total models available: ' + modelCount);
console.log('='.repeat(60));
console.log('');

// Write updated config
fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
console.log('Configuration updated successfully');
console.log('Config:', JSON.stringify(config, null, 2));
EOFNODE

# ============================================================
# START GATEWAY
# ============================================================
# Note: R2 backup sync is handled by the Worker's cron trigger
echo "Starting Moltbot Gateway..."
echo "Gateway will be available on port 18789"

# Clean up stale lock files
rm -f /tmp/clawdbot-gateway.lock 2>/dev/null || true
rm -f "$CONFIG_DIR/gateway.lock" 2>/dev/null || true

BIND_MODE="lan"
echo "Dev mode: ${CLAWDBOT_DEV_MODE:-false}, Bind mode: $BIND_MODE"

if [ -n "$CLAWDBOT_GATEWAY_TOKEN" ]; then
    echo "Starting gateway with token auth..."
    exec clawdbot gateway --port 18789 --verbose --allow-unconfigured --bind "$BIND_MODE" --token "$CLAWDBOT_GATEWAY_TOKEN"
else
    echo "Starting gateway with device pairing (no token)..."
    exec clawdbot gateway --port 18789 --verbose --allow-unconfigured --bind "$BIND_MODE"
fi
# 033-multi-provider-support
