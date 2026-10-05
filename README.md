# M18 Residences — tenant app

The tenant page of M18 Residences (https://my.m18-residences.workers.dev): a tenant logs in with their account ID
(their name) and sees the latest bill, the bill history with an electricity consumption chart, their receipts, and
how to pay. Flutter web, hosted as a static-assets Cloudflare Worker (`my`).

A tenant's link is `https://my.m18-residences.workers.dev/NAME`: it prefills the account ID (uppercased on
submit). Old links of the form `…/#/NAME` still work.

## Getting started

1. **API URL:** copy `.env.example` to `.env` (repo root). `API_URL` (including `/api`) is compiled in with
   `--dart-define-from-file=.env`; without it the app stops at startup with a clear `API_URL is not set` error.
   Locally the API runs on `http://localhost:50000/api` (see `m18-residences-server`), which only allows this app
   on port 50002.
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
  (`development-api`, synthetic data) and behind Cloudflare Access (log in with an allowed email); production is
  untouched:
  - pushes to `development` → https://development-my.m18-residences.workers.dev
  - pull requests from this repo → `https://pr-<number>-my.m18-residences.workers.dev`, linked in a PR comment
- `deploy.yml`: pushes to `main` → the same checks → the browser e2e suite (`shared-e2e`) with this commit and
  the server and admin app as they are live → build with the repo variable `API_URL` → `wrangler deploy` → moves
  the `live` tag.

Browser e2e builds use `--dart-define=E2E=true`, which keeps Flutter's accessibility tree on; tests find widgets by
semantics ids such as `tenant-account-id`, `tenant-login-submit`, `tenant-latest-total` and `tenant-receipt-link`.
