#!/bin/bash
# Test multi-provider configuration

echo "Testing multi-provider setup..."
echo ""

# Check environment variables
echo "Checking API keys..."
PROVIDERS=()

if [ -n "$NVIDIA_API_KEY" ]; then
    echo "  NVIDIA_API_KEY is set"
    PROVIDERS+=("nvidia")
else
    echo "  NVIDIA_API_KEY not set"
fi

if [ -n "$OPENROUTER_API_KEY" ]; then
    echo "  OPENROUTER_API_KEY is set"
    PROVIDERS+=("openrouter")
else
    echo "  OPENROUTER_API_KEY not set"
fi

if [ -n "$ANTHROPIC_API_KEY" ]; then
    echo "  ANTHROPIC_API_KEY is set"
    PROVIDERS+=("anthropic")
else
    echo "  ANTHROPIC_API_KEY not set"
fi

if [ -n "$OPENAI_API_KEY" ]; then
    echo "  OPENAI_API_KEY is set"
    PROVIDERS+=("openai")
else
    echo "  OPENAI_API_KEY not set"
fi

echo ""
echo "Configured providers: ${PROVIDERS[*]}"
echo ""

if [ ${#PROVIDERS[@]} -eq 0 ]; then
    echo "ERROR: No providers configured!"
    echo "Configure at least one API key:"
    echo "  export NVIDIA_API_KEY=nvapi-xxx"
    echo "  export OPENROUTER_API_KEY=sk-or-xxx"
    exit 1
fi

if [ ${#PROVIDERS[@]} -eq 1 ]; then
    echo "WARNING: Only one provider configured"
    echo "For multi-provider support, configure additional API keys"
fi

if [ ${#PROVIDERS[@]} -ge 2 ]; then
    echo "OK: Multiple providers configured!"
    echo "You can switch between providers using:"
    for provider in "${PROVIDERS[@]}"; do
        echo "  /$provider/model-name"
    done
fi

echo ""
echo "Deploy with: npm run deploy"
echo "Check logs:  npx wrangler tail"
