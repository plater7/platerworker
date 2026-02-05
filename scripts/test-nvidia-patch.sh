#!/bin/bash
# Test if the Nvidia patch was applied correctly

set -e

CLAWDBOT_MODEL_FILE="/usr/local/lib/node_modules/clawdbot/dist/agents/pi-embedded-runner/model.js"

echo "🧪 Testing Nvidia patch..."

if [ ! -f "$CLAWDBOT_MODEL_FILE" ]; then
    echo "❌ Clawdbot not installed"
    exit 1
fi

if grep -q "providerCfg?.baseUrl" "$CLAWDBOT_MODEL_FILE"; then
    echo "✅ Patch is applied correctly"
    echo ""
    echo "📋 Patched code snippet:"
    grep -A 8 "const providerCfg = providers\[provider\]" "$CLAWDBOT_MODEL_FILE" | head -9
    exit 0
else
    echo "❌ Patch is NOT applied"
    echo ""
    echo "🔍 Current code:"
    grep -A 5 "if (inlineMatch)" "$CLAWDBOT_MODEL_FILE" | head -7
    exit 1
fi
#037
