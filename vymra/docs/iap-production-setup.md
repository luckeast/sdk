# iOS IAP Production Setup

This project now ships with a production-oriented purchase flow:

- Flutter only grants coins after server verification.
- Each App Store transaction is delivered idempotently.
- Restore flows are verified but do not duplicate consumable delivery.

## 1. Start the verification service

The template server lives at [server/iap_verifier.mjs](/Users/a1234/Desktop/toA-6/vymra/server/iap_verifier.mjs:1).

Required environment variables:

- `PORT`: HTTP port, for example `8787`
- `APPLE_SHARED_SECRET`: App-specific shared secret if you later add subscriptions
- `IAP_VERIFICATION_TOKEN`: bearer token expected from the app
- `IAP_LEDGER_PATH`: path for the transaction delivery ledger JSON file

Example:

```bash
cd /Users/a1234/Desktop/toA-6/vymra
PORT=8787 \
IAP_VERIFICATION_TOKEN=replace-me \
IAP_LEDGER_PATH=/Users/a1234/Desktop/toA-6/vymra/iap-ledger.json \
node server/iap_verifier.mjs
```

## 2. Configure the Flutter app

Pass runtime values with `--dart-define`:

```bash
flutter run \
  --dart-define=IAP_VERIFICATION_URL=https://your-domain.example/verify \
  --dart-define=IAP_VERIFICATION_TOKEN=replace-me
```

The app will block release purchases if `IAP_VERIFICATION_URL` is not set.

## 3. App Store Connect requirements

- Create the exact product IDs used in [lib/services/iap_service.dart](/Users/a1234/Desktop/toA-6/vymra/lib/services/iap_service.dart:27)
- Submit localized display names and screenshots for each IAP product
- Test with Sandbox accounts before TestFlight
- Confirm the bundle ID and IAP product IDs match exactly

## 4. Production note

The included verifier template is deployable for a single-instance server. If you plan to run multiple instances, replace the JSON ledger with a shared database table keyed by:

- `appAccountToken`
- `transactionId`

That change preserves the same API contract already used by the app.
