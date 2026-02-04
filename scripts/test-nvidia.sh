#!/bin/bash
# Test Nvidia API configuration

echo "Testing Nvidia API setup..."

# Check if API key is set
if [ -z "$NVIDIA_API_KEY" ]; then
    echo "❌ NVIDIA_API_KEY not set"
    echo "Run: export NVIDIA_API_KEY=nvapi-XXXX"
    exit 1
fi

echo "✓ API key is set"

# Test API call
echo "Testing Kimi 2.5 model..."
curl -s "https://integrate.api.nvidia.com/v1/chat/completions" \
  -H "Authorization: Bearer $NVIDIA_API_KEY" \
  -H "Accept: application/json" \
  -d '{
    "model": "moonshotai/kimi-k2.5",
    "messages": [{"role":"user","content":"Say hello"}],
    "max_tokens": 100,
    "temperature": 0.7,
    "stream": false
  }' | jq .

echo "✓ Test complete"
