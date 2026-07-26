# Algo Trading — Auto-Pilot app (Flutter)

Standalone cross-platform client for the AI **auto-pilot paper-trading** platform.
Talks to the backend (`stock_app_backend`) over its JWT.

## Configure

Backend URLs are injected at build time:

```bash
flutter pub get
flutter run -d chrome \
  --dart-define=DATA_BASE_URL=https://<your-backend>.onrender.com \
  --dart-define=TRADING_BASE_URL=https://<your-backend>.onrender.com
```

(The one backend serves both the data APIs and the trading APIs, so both URLs
are usually the same.)

## What it does

- **Login / register** (shared JWT with the backend)
- **Accounts** — create a paper account
- **Auto-Pilot** — scan the market for today's momentum picks, run the built-in
  strategy across them, and see the P&L report (paper money, real market data)
- **Account detail** — trade journal, equity curve, kill switch
- **Strategies / Backtest / Broker** — manual tools

## Deploy (Netlify)

`netlify.toml` + `netlify_build.sh` install Flutter in Netlify's build and
compile the web app. Set `DATA_BASE_URL` / `TRADING_BASE_URL` in the Netlify
site environment.

## CI

`.github/workflows/ci.yml` runs `flutter analyze` on every push.

> Live real-money trading is not enabled; the app is paper-first.
