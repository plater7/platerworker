#!/bin/bash
# Patch Clawdbot to fix Nvidia provider configuration inheritance
# This fixes a bug in resolveModel() that doesn't propagate provider config to inline matches

set -e

CLAWDBOT_MODEL_FILE="/usr/local/lib/node_modules/clawdbot/dist/agents/pi-embedded-runner/model.js"
BACKUP_FILE="${CLAWDBOT_MODEL_FILE}.backup"

echo "🔧 Patching Clawdbot for custom provider support..."

# Check if file exists
if [ ! -f "$CLAWDBOT_MODEL_FILE" ]; then
    echo "❌ Error: Clawdbot model.js not found at $CLAWDBOT_MODEL_FILE"
    exit 1
fi

# Create backup if not exists
if [ ! -f "$BACKUP_FILE" ]; then
    echo "💾 Creating backup at $BACKUP_FILE"
    cp "$CLAWDBOT_MODEL_FILE" "$BACKUP_FILE"
fi

# Check if already patched
if grep -q "providerCfg?.baseUrl" "$CLAWDBOT_MODEL_FILE"; then
    echo "✅ Clawdbot already patched, skipping"
    exit 0
fi

echo "🔨 Applying patch..."

# Use Node.js to do a more reliable replace
node << 'NODE_SCRIPT'
const fs = require('fs');
const filePath = '/usr/local/lib/node_modules/clawdbot/dist/agents/pi-embedded-runner/model.js';

let content = fs.readFileSync(filePath, 'utf8');

// Find and replace the buggy pattern
const buggyPattern = /if \(inlineMatch\) \{\s*const normalized = normalizeModelCompat\(inlineMatch\);\s*return \{\s*model: normalized,\s*authStorage,\s*modelRegistry,\s*\};\s*\}/;

const fixedCode = `if (inlineMatch) {
            const providerCfg = providers[provider];
            const normalized = normalizeModelCompat({
                ...inlineMatch,
                baseUrl: providerCfg?.baseUrl ?? inlineMatch.baseUrl,
                api: providerCfg?.api ?? inlineMatch.api,
                apiKey: providerCfg?.apiKey ?? inlineMatch.apiKey,
                headers: providerCfg?.headers ? { ...providerCfg.headers, ...inlineMatch.headers } : inlineMatch.headers,
            });
            return {
                model: normalized,
                authStorage,
                modelRegistry,
            };
        }`;

if (buggyPattern.test(content)) {
    content = content.replace(buggyPattern, fixedCode);
    fs.writeFileSync(filePath, content, 'utf8');
    console.log('✅ Patch applied successfully');
    process.exit(0);
} else {
    console.error('❌ Could not find pattern to patch. File may have been updated.');
    process.exit(1);
}
NODE_SCRIPT

if [ $? -eq 0 ]; then
    echo "✅ Clawdbot patched successfully"
    echo "📝 Backup saved at: $BACKUP_FILE"
else
    echo "❌ Patch failed"
    exit 1
fi
