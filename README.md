# M18 Residences — tenant app

The tenant page of M18 Residences (https://my.m18-residences.workers.dev): a tenant logs in with their account ID
(their name) and sees the latest bill, the bill history with an electricity consumption chart, their receipts, and
how to pay. Flutter web, hosted as a static-assets Cloudflare Worker (`my`).

A tenant's link is `https://my.m18-residences.workers.dev/NAME`: it prefills the account ID (uppercased on
submit). Old links of the form `…/#/NAME` still work. "Remember me on this device" (off by default; ticked when
an ID was remembered before) keeps the account ID in the browser's storage to prefill the next visit; a link's name
wins over it. The × in the Account ID box clears the field and forgets the remembered ID. Enter submits.

The latest bill shows its status: **Unpaid**, **For verification** (the tenant uploaded a payment image) or **Paid**
(the owner attached a receipt). Until it is paid, the tenant can upload a screenshot or photo of their payment
(optional; "Upload payment" / "Change payment"), converted in the browser like the admin's receipts
(`prepareReceipt` from the shared package: ≤ 1600 px WebP, HEIC included, PDFs as-is).

After login, `lib/features/shell/tenant_shell.dart` shows **Home**, **History** and **Pay** (a bottom bar on
phones, a rail on wider screens); the bills are fetched once and shared by all three. **Home** leads with the
latest bill (amount, status; tap for the statement), the next step (pay and upload proof, waiting for
confirmation, or paid with the receipt), this month's electricity against last month's, and the recent bills.
**History** has a year's consumption chart and that year's bills; **Pay** the steps and the QR codes. Light and
dark follow the system.

Receipts, payment images and payment QR codes open in a dialog with Save (View buttons, never links or file names):
WebP files are saved as JPEG, the QR codes as PNG.
Every text can be selected and copied.

**Logo and icons:** the roofline M (white mark on the brand teal). `web/icons/logo.svg` and `logo-maskable.svg` are the masters; `web/favicon.svg` is a copy, and the PNGs (`favicon.png`, `icons/Icon-*.png`, `icons/apple-touch-icon.png`) are rendered from them at their sizes in Chrome. In the app, `BrandMark` from `m18_residences_shared` draws the same mark.

## Getting started

1. **API URL:** copy `.env.example` to `.env` (repo root). `API_URL` (including `/api`) is compiled in with
   `--dart-define-from-file=.env`; without it the app stops at startup with a clear `API_URL is not set` error.
   Locally the API runs on `http://localhost:50000/api` (see `m18-residences-server`), which only allows this app
   on port 50002. `TURNSTILE_SITE_KEY` (also in `.env`) is the login page's Cloudflare Turnstile widget; locally
   Cloudflare's always-pass test key `1x00000000000000000000AA` (the local API has the matching test secret).
   Missing, the app stops at startup with a clear error.
2. **Shared package:** models, the API client and common widgets come from `m18_residences_shared`
   ([shared-packages](https://github.com/whatever413y/shared-packages), pinned by tag in `pubspec.yaml`). To work
   against a local checkout next to this repo, add a gitignored `pubspec_overrides.yaml`:

   ```yaml
   dependency_overrides:
     m18_residences_shared:
       path: ../shared-packages/packages/m18_residences_shared
   ```

3. **Run or build:**

   ```sh
   flutter pub get
   flutter run -d chrome --web-port 50002 --dart-define-from-file=.env
   flutter build web --release --dart-define-from-file=.env
   ```

   To serve a build the way production does (unknown paths fall back to `index.html`):
   `npx wrangler@4.145.0 dev --port 50002`.

## Checks and deploys

- `flutter analyze` must report no issues; `dart format lib` (150 columns).
- `test.yml`: PRs to `main` → format, analyze, release build.
- `preview.yml`: the same checks, then a **preview** on this app's Worker, built against the development API
  (`development-api`, synthetic data; open, no Access); production is untouched:
  - pushes to `development` → https://development-my.m18-residences.workers.dev
  - pull requests from this repo → `https://pr-<number>-my.m18-residences.workers.dev`, linked in a PR comment
- `deploy.yml`: pushes to `main` → the same checks → the browser e2e suite (`shared-e2e`) with this commit and
  the server and admin app as they are live → build with the repo variables `API_URL` and `TURNSTILE_SITE_KEY` → `wrangler deploy` → moves
  the `live` tag.

Browser e2e builds use `--dart-define=E2E=true`, which keeps Flutter's accessibility tree on; tests find widgets by
semantics ids such as `tenant-account-id`, `tenant-login-submit`, `tenant-latest-total`, `tenant-bill-status`,
`tenant-upload-payment`, `tenant-payment-link` and `tenant-receipt-link`.
