# V2ET Configuration Strategy

## 1) Build-time Fixed (must change before packaging)

These values are treated as release constants and are not intended to be changed by end users after packaging:

1. Bootstrap OSS config URL
2. Package ID / app name
3. Brand assets (logo/icon/splash)
4. Public key for remote config signature verification

Current bootstrap URL source file:

- `lib/v2et/config/v2et_bootstrap_config.dart`

## 2) Runtime Remote Config (can change after packaging)

These values should come from OSS JSON and can be updated without repackaging:

- `api_base_urls` (multi API and failover)
- `theme` (primary/accent/semantic colors)
- `crisp.website_id`
- `banners`
- `builtin_proxy`
- `ports` and custom port settings
- feature flags

Current runtime keys tracked in app:

- `features.show_notice_popup` (公告弹窗开关)
- `theme.primary` / `theme.surface` (软件主色/背景色)
- `crisp.website_id` (客服系统 ID)
- `banners[]` (轮播图数据)
- `builtin_proxy.enabled` (内置代理开关)
- `ports.allow_custom` / `ports.default` (端口自定义策略)
- `links.official_site` / `links.join_group` / `links.invite_manage` / `links.gift_card_help` (我的页外链配置)

Template file:

- `docs/v2et/config.template.json`

## 3) Security Baseline

Important: bootstrap URL cannot be fully hidden from a determined reverse engineer.

Recommended baseline for production:

1. HTTPS only
2. Signed config envelope (asymmetric signature)
3. Public-key verify in client before applying config
4. Optional certificate pinning
5. Obfuscation release builds

## 4) Proposed Config Envelope

```json
{
  "version": 1,
  "issued_at": 1760000000,
  "payload": {
    "api_base_urls": [
      "https://api1.example.com",
      "https://api2.example.com"
    ],
    "theme": {
      "primary": "#5B3F88",
      "surface": "#F3F1F8"
    },
    "crisp": {
      "website_id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    },
    "banners": [],
    "builtin_proxy": {
      "enabled": false
    },
    "ports": {
      "allow_custom": true,
      "default": 10808
    }
  },
  "signature": "BASE64_SIGNATURE"
}
```

## 5) Delivery Plan

1. Add config schema and parser for the envelope
2. Add signature verifier and reject invalid config
3. Add API failover/rotation policy
4. Add runtime theme + crisp + banner application
5. Add operations guide for key rotation
