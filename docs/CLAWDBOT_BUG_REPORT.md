# Bug Report: Custom Provider Configuration Not Inherited in resolveModel()

## Summary
Custom provider configuration (baseUrl, apiKey, headers) is not propagated to inline model matches in `resolveModel()` function, breaking custom providers like Nvidia, custom OpenAI endpoints, and other non-standard providers.

## Affected File
`src/agents/pi-embedded-runner/model.ts` (source)
`dist/agents/pi-embedded-runner/model.js` (compiled)

## Affected Function
`resolveModel()`

## Bug Description

When a model is specified in the format `provider/model` (e.g., `nvidia/moonshotai/kimi-k2.5`), the function correctly finds an `inlineMatch` but then normalizes it WITHOUT merging the provider configuration from `config.models.providers[provider]`.

This means that even if you configure:

```json
{
  "models": {
    "providers": {
      "nvidia": {
        "baseUrl": "https://integrate.api.nvidia.com/v1",
        "apiKey": "nvapi-XXXX"
      }
    }
  }
}
```

And use model `nvidia/moonshotai/kimi-k2.5`, the model will try to use default configuration instead of the Nvidia baseUrl and apiKey.

## Current Code (Buggy)

```typescript
if (inlineMatch) {
    const normalized = normalizeModelCompat(inlineMatch);
    return {
        model: normalized,
        authStorage,
        modelRegistry,
    };
}
```

## Expected Code (Fixed)

```typescript
if (inlineMatch) {
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
}
```

## Impact

- **High**: Custom providers cannot be used with inline model format
- Affects: Nvidia NIM, custom OpenAI endpoints, custom LLM providers
- Workaround: Requires runtime patching of compiled code

## Steps to Reproduce

1. Configure a custom provider in `clawdbot.json`:
```json
{
  "models": {
    "providers": {
      "nvidia": {
        "baseUrl": "https://integrate.api.nvidia.com/v1",
        "apiKey": "nvapi-XXX"
      }
    }
  },
  "agents": {
    "defaults": {
      "models": {
        "nvidia/moonshotai/kimi-k2.5": { "alias": "kimi" }
      }
    }
  }
}
```

2. Try to use the model: `/kimi test message`

3. Observe error: Model tries to connect to wrong endpoint or with wrong credentials

## Expected Behavior

The model should inherit `baseUrl`, `apiKey`, and `headers` from the `nvidia` provider configuration.

## Actual Behavior

The model uses default configuration, ignoring the custom provider settings.

## Environment

- Clawdbot version: Latest (as of 2025-02)
- Node.js: 22.x
- Platform: Cloudflare Sandbox / Docker

## Proposed Solution

Merge provider configuration into inline matches before normalization, as shown in the "Expected Code" section above.

## Workaround

Runtime patching of the compiled JavaScript file. See PlaterWorker's `scripts/patch-clawdbot-nvidia.sh` for implementation.

## Related

- Custom providers feature
- Model resolution logic
- Provider configuration inheritance
