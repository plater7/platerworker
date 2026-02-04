# PlaterWorker - OpenClaw con soporte OpenRouter

PlaterWorker es un fork de [moltworker](https://github.com/cloudflare/moltworker) que añade soporte nativo para [OpenRouter](https://openrouter.ai) como proveedor de modelos AI. Permite ejecutar [OpenClaw](https://github.com/openclaw/openclaw) (anteriormente Moltbot/Clawdbot) en [Cloudflare Sandbox](https://developers.cloudflare.com/sandbox/) con acceso a múltiples modelos de IA a través de OpenRouter.

![PlaterWorker](./assets/logo.png)

> **⚠️ ADVERTENCIA IMPORTANTE**: Las modificaciones para soportar OpenRouter fueron realizadas principalmente mediante IA y pueden contener errores. Este proyecto es experimental y debe usarse con precaución. Se recomienda revisar el código antes de usar en producción.

> **Experimental:** Este es un concepto de prueba que demuestra que OpenClaw puede correr en Cloudflare Sandbox. No está oficialmente soportado y puede dejar de funcionar sin previo aviso. Úselo bajo su propio riesgo.

## ⭐ Cambios principales respecto a moltworker

### Soporte OpenRouter
- **Configuración simplificada**: OpenRouter se configura automáticamente como proveedor por defecto
- **Múltiples modelos disponibles**: Acceso a modelos de Anthropic, OpenAI, DeepSeek, Qwen, Google, X.AI y más
- **Auto-routing inteligente**: Usa `openrouter/auto` o `openrouter/free` para routing automático
- **Aliases cortos**: Comandos simples como `/qwen`, `/deep`, `/haiku`, `/grok`

### Modelos preconfigurados
- **Auto-routing**: `auto`, `free`
- **Código**: `qwen`, `qwenfree`, `devstral`, `mimofree`, `grokcode`
- **General**: `deep`, `kimi`, `flash`
- **Claude**: `haiku`, `sonnet`
- **OpenAI**: `mini`, `gpt`
- **Razonamiento**: `think`, `qwq`
- **GLM**: `glm-4.7`, `glmfree`

### Workspace modificado
- Workspace movido a `/root/.clawdbot/workspace` para mejor organización
- Backup completo a R2 incluye workspace y configuraciones

## 📋 Requisitos

- [Workers Paid plan](https://www.cloudflare.com/plans/developer-platform/) ($5 USD/mes) — requerido para Cloudflare Sandbox
- [Cuenta OpenRouter](https://openrouter.ai/) — para acceso a modelos IA
- O [Anthropic API key](https://console.anthropic.com/) — como alternativa

Las siguientes funcionalidades de Cloudflare tienen tiers gratuitos:
- Cloudflare Access (autenticación)
- Browser Rendering (navegación en navegador)
- AI Gateway (opcional, para routing/analytics)
- R2 Storage (opcional, para persistencia)

## 🚀 Instalación rápida

### Opción 1: Usar OpenRouter (Recomendado)

```bash
# Instalar dependencias
npm install

# Configurar OpenRouter API Key
npx wrangler secret put OPENROUTER_API_KEY

# Configurar base URL para OpenRouter
npx wrangler secret put AI_GATEWAY_BASE_URL
# Ingresar: https://openrouter.ai/api/v1

# Generar token de gateway
export MOLTBOT_GATEWAY_TOKEN=$(openssl rand -hex 32)
echo "Token del gateway: $MOLTBOT_GATEWAY_TOKEN"
echo "$MOLTBOT_GATEWAY_TOKEN" | npx wrangler secret put MOLTBOT_GATEWAY_TOKEN

# Desplegar
npm run deploy
```

### Opción 2: Usar Anthropic API directa

```bash
# Instalar dependencias
npm install

# Configurar Anthropic API Key
npx wrangler secret put ANTHROPIC_API_KEY

# Generar token de gateway
export MOLTBOT_GATEWAY_TOKEN=$(openssl rand -hex 32)
echo "Token del gateway: $MOLTBOT_GATEWAY_TOKEN"
echo "$MOLTBOT_GATEWAY_TOKEN" | npx wrangler secret put MOLTBOT_GATEWAY_TOKEN

# Desplegar
npm run deploy
```

### Opción 3: Usar Nvidia API (Kimi 2.5 y NIM models)

```bash
# Instalar dependencias
npm install

# Configurar Nvidia API Key (obtener en https://build.nvidia.com)
npx wrangler secret put NVIDIA_API_KEY

# Opcional: Configurar base URL personalizada
npx wrangler secret put AI_GATEWAY_BASE_URL
# Ingresar: https://integrate.api.nvidia.com/v1

# Generar token de gateway
export MOLTBOT_GATEWAY_TOKEN=$(openssl rand -hex 32)
echo "Token del gateway: $MOLTBOT_GATEWAY_TOKEN"
echo "$MOLTBOT_GATEWAY_TOKEN" | npx wrangler secret put MOLTBOT_GATEWAY_TOKEN

# Desplegar
npm run deploy
```

### Opción 4: Usar AI Gateway de Cloudflare

```bash
# Instalar dependencias
npm install

# Configurar AI Gateway
npx wrangler secret put AI_GATEWAY_API_KEY
npx wrangler secret put AI_GATEWAY_BASE_URL
# Ingresar: https://gateway.ai.cloudflare.com/v1/{account_id}/{gateway_id}/anthropic
# O para OpenRouter: https://gateway.ai.cloudflare.com/v1/{account_id}/{gateway_id}/openrouter

# Generar token de gateway
export MOLTBOT_GATEWAY_TOKEN=$(openssl rand -hex 32)
echo "Token del gateway: $MOLTBOT_GATEWAY_TOKEN"
echo "$MOLTBOT_GATEWAY_TOKEN" | npx wrangler secret put MOLTBOT_GATEWAY_TOKEN

# Desplegar
npm run deploy
```

Después de desplegar, abre el Control UI con tu token:

```
https://your-worker.workers.dev/?token=YOUR_GATEWAY_TOKEN
```

Reemplaza `your-worker` con tu subdominio de worker y `YOUR_GATEWAY_TOKEN` con el token que generaste.

**Nota:** La primera petición puede tomar 1-2 minutos mientras el contenedor se inicia.

## 🔐 Configuración de seguridad

> **Importante:** No podrás usar el Control UI hasta completar estos pasos:
> 1. [Configurar Cloudflare Access](#configurar-cloudflare-access) para proteger el admin UI
> 2. [Emparejar tu dispositivo](#emparejamiento-de-dispositivos) vía admin UI en `/_admin/`

También se recomienda [habilitar almacenamiento R2](#almacenamiento-persistente-r2) para que los dispositivos emparejados y el historial persistan entre reinicios del contenedor.

### Configurar Cloudflare Access

Ver sección completa en la [documentación original de moltworker](https://github.com/cloudflare/moltworker#setting-up-the-admin-ui).

Resumen:
1. Habilitar Cloudflare Access en tu worker
2. Configurar dominio y audiencia (AUD)
3. Establecer secretos:
```bash
npx wrangler secret put CF_ACCESS_TEAM_DOMAIN
npx wrangler secret put CF_ACCESS_AUD
```
4. Redesplegar

### Emparejamiento de dispositivos

Por defecto, cada nuevo dispositivo debe ser aprobado en `/_admin/` antes de poder usar el asistente. Esto aplica para:
- Navegadores web
- CLI clients
- Bots de Telegram/Discord/Slack (DMs)

## 💾 Almacenamiento persistente (R2)

Por defecto, los datos de moltbot (configs, dispositivos emparejados, historial de conversaciones) se pierden cuando el contenedor se reinicia. Para habilitar persistencia:

### 1. Crear token de API R2

1. Ir a **R2** > **Overview** en el [Dashboard de Cloudflare](https://dash.cloudflare.com/)
2. Click en **Manage R2 API Tokens**
3. Crear nuevo token con permisos **Object Read & Write**
4. Seleccionar el bucket `moltbot-data` (se crea automáticamente)
5. Copiar **Access Key ID** y **Secret Access Key**

### 2. Configurar secretos

```bash
npx wrangler secret put R2_ACCESS_KEY_ID
npx wrangler secret put R2_SECRET_ACCESS_KEY
npx wrangler secret put CF_ACCOUNT_ID
```

### Cómo funciona

El almacenamiento R2 usa un enfoque de backup/restore:

**Al iniciar el contenedor:**
- Si R2 está montado y contiene datos de backup, se restaura a `/root/.clawdbot`
- Incluye workspace completo en `/root/.clawdbot/workspace`

**Durante operación:**
- Un cron job corre cada 5 minutos para sincronizar a R2
- También puedes hacer backup manual desde el admin UI

**En el admin UI:**
- Verás "Last backup: [timestamp]"
- Click en "Backup Now" para sincronización inmediata

## 🎮 Usar modelos de OpenRouter

### Cambiar modelo en el chat

Usa comandos con `/` seguido del alias del modelo:

```
/qwen ¿Cómo optimizo este código Python?
/deep Explica arquitectura de microservicios
/haiku Responde brevemente
/think Resuelve este problema complejo (razonamiento)
```

### Modelos disponibles

| Alias | Modelo | Descripción |
|-------|--------|-------------|
| `auto` | openrouter/auto | Auto-routing inteligente |
| `free` | openrouter/free | Free-routing |
| `qwen` | qwen-2.5-coder-32b | Especialista en código |
| `qwenfree` | qwen-2.5-coder-32b:free | Versión gratuita |
| `deep` | deepseek-chat-v3 | Propósito general |
| `devstral` | mistralai/devstral-small:free | Código (free) |
| `grok` | x-ai/grok-4.1-fast | Agentic/Tools |
| `haiku` | claude-3.5-haiku | Claude rápido |
| `sonnet` | claude-sonnet-4 | Claude avanzado |
| `mini` | gpt-4o-mini | OpenAI económico |
| `gpt` | gpt-4o | OpenAI estándar |
| `think` | deepseek-reasoner | Razonamiento profundo |
| `flash` | gemini-2.0-flash | Google rápido |

### Modelos Nvidia NIM disponibles

Con Nvidia API, tienes acceso a modelos adicionales optimizados:

| Alias | Modelo | Descripción |
|-------|--------|-------------|
| `kimi` | moonshotai/kimi-k2.5 | Kimi 2.5 - Excelente contexto largo |
| `moonshot8k` | moonshot-v1-8k | Moonshot 8K context |
| `moonshot32k` | moonshot-v1-32k | Moonshot 32K context |
| `moonshot128k` | moonshot-v1-128k | Moonshot 128K context |
| `llama70b` | llama-3.3-70b | Meta Llama 70B |
| `llama405b` | llama-3.1-405b | Meta Llama 405B |
| `mistral` | mistral-large-2 | Mistral Large 2 |
| `mixtral` | mixtral-8x7b | Mixtral MoE |
| `nemotron` | llama-nemotron-70b | Nvidia Nemotron |
| `deepseek-r1` | deepseek-r1 | DeepSeek R1 reasoning |

**Uso**:
```
/kimi Explica este concepto en detalle
/llama405b Analiza este código complejo
/deepseek-r1 Resuelve este problema (con razonamiento)
```

### Configurar modelo por defecto

El modelo por defecto es `openrouter/free` (free-routing automático). Para cambiarlo:

1. Editar `moltbot.json.template` antes de desplegar
2. O modificar `/root/.clawdbot/clawdbot.json` en el contenedor después del primer inicio
3. O usar variable de entorno `MOLTBOT_DEFAULT_MODEL`

## 🚀 Nvidia NIM - Configuración avanzada

Nvidia NIM (Nvidia Inference Microservices) proporciona acceso a modelos optimizados de múltiples proveedores, incluyendo Kimi 2.5 de Moonshot AI.

### Obtener API Key

1. Visita [build.nvidia.com](https://build.nvidia.com)
2. Crea una cuenta o inicia sesión
3. Navega a la sección de API Keys
4. Genera una nueva API key
5. Copia la key (formato: `nvapi-XXXXXXXXXXXX`)

### Configuración básica

```bash
# Configurar API key
npx wrangler secret put NVIDIA_API_KEY
# Pegar tu key: nvapi-XXXXXXXXXXXX

# Redesplegar
npm run deploy
```

### Usar con AI Gateway de Cloudflare

Para routing, caching y analytics:

```bash
# Configurar ambas variables
npx wrangler secret put NVIDIA_API_KEY
npx wrangler secret put AI_GATEWAY_BASE_URL
# Ingresar: https://gateway.ai.cloudflare.com/v1/{account_id}/{gateway_id}/nvidia
```

### Características especiales de Kimi 2.5

El modelo Kimi 2.5 soporta el parámetro `thinking` para razonamiento explícito:

```javascript
// En el código, esto se configura automáticamente
{
  "chat_template_kwargs": {"thinking": true}
}
```

Para usar thinking mode en el chat:
```
/kimi --think Analiza este problema paso a paso
```

### Modelos recomendados según uso

- **Contexto largo**: `/kimi`, `/moonshot128k` - Hasta 128K tokens
- **Código**: `/nemotron`, `/llama70b` - Optimizados para programación
- **Razonamiento**: `/deepseek-r1` - Chain-of-thought explícito
- **General**: `/mistral`, `/llama405b` - Mejor calidad general
- **Rápido**: `/moonshot8k`, `/mixtral` - Respuestas más rápidas

## 📚 Documentación adicional

La mayoría de la funcionalidad es idéntica a moltworker original. Consulta la [documentación completa de moltworker](https://github.com/cloudflare/moltworker) para:

- Admin UI y gestión de dispositivos
- Canales de chat (Telegram, Discord, Slack)
- Browser automation (CDP)
- Skills personalizados
- Debug endpoints
- Cloudflare AI Gateway
- Troubleshooting

## 🔧 Diferencias técnicas vs moltworker

### Archivos modificados
- `start-moltbot.sh`: Lógica de configuración de OpenRouter
- `moltbot.json.template`: Workspace y modelo por defecto
- `src/types.ts`: Tipo `OPENROUTER_API_KEY`
- `src/gateway/env.ts`: Propagación de `OPENROUTER_API_KEY`
- `Dockerfile`: Build cache bust actualizado

### Cambios en configuración
- Workspace: `/root/clawd` → `/root/.clawdbot/workspace`
- Modelo por defecto: `anthropic/claude-opus-4-5` → `openrouter/free`
- Provider por defecto: Anthropic → OpenRouter

## ⚠️ Problemas conocidos

### Debido a modificaciones por IA
- La configuración de modelos en `start-moltbot.sh` puede tener redundancias
- Algunos nombres de modelos pueden quedar desactualizados
- La lógica de detección de provider puede fallar en casos edge

### Recomendaciones
1. **Probar en desarrollo primero** con `wrangler dev`
2. **Revisar logs** con `npx wrangler tail` después de desplegar
3. **Verificar configuración** en el admin UI después del primer inicio
4. **Backup manual** desde admin UI antes de hacer cambios grandes

### Si algo falla
1. Revisar logs: `npx wrangler tail`
2. Verificar secretos: `npx wrangler secret list`
3. Limpiar cache de build: Editar comentario `# Build cache bust` en Dockerfile
4. Redesplegar: `npm run deploy`

## 🐛 Reportar problemas

Este es un proyecto experimental y no oficial. Los problemas deben reportarse en el fork, no en el repositorio original de moltworker.

## 📄 Licencia

Este proyecto mantiene la misma licencia que moltworker (MIT). Ver [LICENSE](LICENSE) para detalles.

## 🙏 Créditos

- Proyecto base: [moltworker](https://github.com/cloudflare/moltworker) por Cloudflare
- OpenClaw: [openclaw/openclaw](https://github.com/openclaw/openclaw)
- Modificaciones OpenRouter: Realizadas principalmente con asistencia de IA

---

**⚠️ Recordatorio**: Las modificaciones fueron hechas con IA y pueden contener errores. Usa bajo tu propio riesgo y revisa el código antes de producción.
