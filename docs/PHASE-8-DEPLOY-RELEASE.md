# Phase 8 — Backend-Deployment & App Store / Google Play Release

Stand: September 2026. **Additiv** — bestehender Render-Go-Live bleibt der Standardpfad.

## Überblick

| Baustein | Status | Ort |
|----------|--------|-----|
| Backend auf **Render** (SSL, Env, Disk) | ✅ produktiv dokumentiert | `render.yaml`, `docs/RENDER-GO-LIVE.md` |
| Domain + Let’s Encrypt via Render/Strato | ✅ | `docs/STRATO-SICHTBARKEIT.md` |
| Docker-Image für **AWS / GCP / DigitalOcean** | ✅ Dockerfile vorhanden | `backend/Dockerfile` |
| Multi-Cloud-Anleitung | ✅ diese Datei + `scripts/deploy-docker-cloud.sh` | |
| App-Store-Metadaten + Review Notes (Hintergrund-GPS) | ✅ | `docs/APP-STORE-METADATA.md` |
| Google Play (PWA + künftig Native) | ✅ | Abschnitt in `APP-STORE-METADATA.md` |

## 1. Backend-Deployment

### 1.1 Empfohlen: Render (unverändert)

```bash
# Blueprint aus Repo
# Dashboard → New → Blueprint → render.yaml

bash scripts/render-go-live.sh https://luckystaxiapp.de
# oder Fallback:
bash scripts/render-live-check.sh https://taxiapp-api.onrender.com
```

| Thema | Umsetzung |
|-------|-----------|
| SSL/TLS | Render Custom Domain → automatisches Zertifikat |
| Env | Dashboard Environment + `render.yaml` `envVars` (`sync: false` = Secrets) |
| Persistenz | Disk `/var/data` → `DATA_DIR=/var/data` |
| Health | `GET /health` |
| Webhook | Stripe → `https://<domain>/api/billing/webhook` |

Pflicht-Env Live: `ADMIN_PIN`, `PUBLIC_BASE_URL`. Details: `docs/RENDER-GO-LIVE.md`.

### 1.2 Alternativ: Docker (AWS / GCP / DigitalOcean / Railway / Fly)

Gleiches Image, andere Orchestrierung — **kein** Umbau des Node-Codes.

```bash
# Image bauen (aus Repo-Root oder backend/)
bash scripts/deploy-docker-cloud.sh build

# Lokal smoke-testen
bash scripts/deploy-docker-cloud.sh run-local
curl -sf http://127.0.0.1:4242/health
```

| Plattform | Kurz |
|-----------|------|
| **DigitalOcean** App Platform / Droplet | Image pushen → HTTPS Load Balancer oder Caddy; Volume für `/data` |
| **AWS** | ECS/Fargate oder App Runner; ALB + ACM-Zertifikat; EFS/EBS → `DATA_DIR` |
| **Google Cloud** | Cloud Run; Managed SSL; Volume oder Cloud Storage Sync für JSON-Daten |
| **Fly.io / Railway** | `backend/Dockerfile`; Volume mount auf `/data` |

**Gemeinsame Regeln**

1. `HOST=0.0.0.0`, `PORT=4242` (oder Plattform-`PORT`)
2. `DATA_DIR` auf persistentes Volume (`/data` im Dockerfile-Default; Render: `/var/data`)
3. `PUBLIC_BASE_URL=https://…` (ohne Slash am Ende)
4. TLS terminiert am Load Balancer / Reverse Proxy — App spricht HTTP intern
5. Secrets nur über Plattform-Env (nie ins Image)

Vollständige Env-Liste: `backend/.env.example` + Abschnitt unten.

### 1.3 Umgebungsvariablen (Produktion)

| Variable | Pflicht | Zweck |
|----------|---------|--------|
| `ADMIN_PIN` | ja | Leitstelle / Schreib-APIs |
| `PUBLIC_BASE_URL` | ja (Live) | Pay-Links, E-Mails, Webhooks |
| `DATA_DIR` | ja | Persistente JSON/PDFs |
| `STRIPE_SECRET_KEY` | wenn Karte/Abo | Zahlungen |
| `STRIPE_WEBHOOK_SECRET` | wenn Stripe | Signaturprüfung |
| `STRIPE_PUBLISHABLE_KEY` | wenn pay.html | Client |
| `RESEND_API_KEY` / `RESEND_FROM` | für Quittungs-Mail | Phase 7 |
| `LOCATION_STREAM_INTERVAL_MS` | optional | Default 2500 |
| `RECEIPT_VAT_PERCENT` | optional | Default 7 |
| `DRIVER_API_KEY` | empfohlen | Fahrer-API |

### 1.4 SSL-Checkliste

- [ ] Custom Domain auf DNS (A/CNAME) → Hosting
- [ ] Zertifikat aktiv (Render/ACM/Let’s Encrypt)
- [ ] `https://…/health` → 200
- [ ] `PUBLIC_BASE_URL` = kanonische HTTPS-URL
- [ ] Stripe Webhook auf HTTPS-Endpunkt

## 2. App Store / Google Play

Metadaten, Screenshots-Checkliste und **paste-fertige App Review Notes** zur Hintergrund-Standortverfolgung (Fahrer: Sicherheit & Live-Navigation):

→ **`docs/APP-STORE-METADATA.md`**

TestFlight-Ablauf bleibt: `docs/TESTFLIGHT.md`.

## 3. Verifikation

```bash
bash scripts/test-phase8-deploy-check.sh
# Optional gegen Live:
PUBLIC_BASE_URL=https://luckystaxiapp.de bash scripts/test-phase8-deploy-check.sh
```

## 4. Bewusst unverändert

- `render.yaml` Service-Name/`rootDir`/Disk-Pfad
- Native SwiftUI-Screens und Bundle-IDs
- Offizielle Store-Xcode-Projekte unter CollectionApp (dieses Repo liefert Snippets + Docs)
