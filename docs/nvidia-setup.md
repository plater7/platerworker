# Nvidia API Setup Guide

## Quick Start

1. Get API key from https://build.nvidia.com
2. Configure in Cloudflare:
```bash
npx wrangler secret put NVIDIA_API_KEY
```
3. Deploy:
```bash
npm run deploy
```

## Available Models

### Kimi 2.5 (Recommended)
- Model: `nvidia/moonshotai/kimi-k2.5`
- Alias: `/kimi`
- Context: 200K+ tokens
- Best for: Long documents, complex reasoning
- Special: Supports thinking mode

Example:
```
/kimi Summarize this 100-page document: [paste content]
```

### Moonshot Series
- `moonshot-v1-8k` - Fast, 8K context
- `moonshot-v1-32k` - Balanced, 32K context
- `moonshot-v1-128k` - Large, 128K context

### Meta Llama
- `llama-3.3-70b-instruct` - High quality general
- `llama-3.1-405b-instruct` - Largest, best reasoning

### Others
- Mistral Large 2
- Mixtral 8x7B MoE
- Nvidia Nemotron 70B
- DeepSeek R1

## Using with AI Gateway

Route through Cloudflare for caching/analytics:

```bash
# Set both secrets
npx wrangler secret put NVIDIA_API_KEY
npx wrangler secret put AI_GATEWAY_BASE_URL
# Value: https://gateway.ai.cloudflare.com/v1/{account_id}/{gateway_id}/nvidia
```

## Thinking Mode

Kimi 2.5 supports explicit reasoning:

```javascript
// API call includes:
{
  "chat_template_kwargs": {"thinking": true}
}
```

Chat usage:
```
/kimi --think Step-by-step solve: [problem]
```

## Rate Limits

Check Nvidia's rate limits at build.nvidia.com:
- Free tier: Limited requests/minute
- Paid tier: Higher limits

## Troubleshooting

**401 Unauthorized**: Check API key is correct
**429 Rate Limit**: Wait or upgrade tier
**Model not found**: Check model name matches Nvidia catalog

Verify deployment:
```bash
npx wrangler tail
```

Check configured models in Admin UI at `/_admin/`
