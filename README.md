# Motor B / motorbreif Vehicle Reports

React (Vite) front end + Express API. Needs Node 20.19+ or 22.12+.

## Run locally
```bash
npm run install:all
cp server/.env.example server/.env
npm run dev:server     # terminal 1, API on :3000
npm run dev:client     # terminal 2, site on http://localhost:5173
```

## Production
```bash
npm run build          # builds client/dist
npm start              # Express serves the API and the built site on PORT
```
Put it behind HTTPS (Caddy or nginx) and keep it alive with pm2.

## Structure
- `server/index.js`: API routes (`/api/stats`, `/api/vehicle`, `/api/checkout`) and static hosting
- `server/data.js`: Q2 2026 used car stats (edit or replace with a database)
- `client/src/components`: Hero (reg lookup), Motion (animated checks), Stats, Pricing, Terms
- `client/src/styles.css`: all styling, light and dark mode

## Going live
- **Vehicle lookup:** set `UKVD_API_KEY` in the server runtime. When it is missing or UKVD cannot return valid data, the API returns a safe error rather than sample vehicle information. A valid quick lookup may consume UKVD account credits; confirm the production package and cost before enabling public lookups.
- **Standard reports:** Preview/development accepts Stripe test keys only; production accepts live keys only. Standard Checkout has a £9.99 GBP base line item; enabled promotion codes may reduce the final amount. The report route re-verifies the paid Stripe session before UKVD report generation.
- **EV comparison:** the Essential two-vehicle comparison is shown at **£4.99 GBP** as a one-off with no subscription. Its Checkout remains Preview/test-only; it does not take a live payment, query UKVD or generate an EV report. The £7.99 Intelligence and £12.99 Premium tiers remain non-purchasable previews.
- **Legal details:** the Terms page intentionally does not invent an office address, company number or VAT status. Confirm and add the official details before public launch.

## Paid reports: Stripe webhook and email
The managed Stripe integration connects the subscribed webhook events to `/api/stripe/webhook`; do not add a duplicate endpoint. Its dedicated handler is `server/vehicle-report-webhook.js`. It verifies the signature over the raw request body, checks that the Stripe event mode matches the runtime, skips marked EV test events and records other subscribed event IDs idempotently. A paid vehicle-report completion is classified and recorded, but the webhook does **not** generate reports or trigger UKVD lookups.

After Checkout, the customer returns to `/report?session_id=...`. That page calls `/api/report`, which retrieves the Stripe session again and validates paid status, GBP/payment mode, registration and the exact vehicle-report line item/base price before loading UKVD data. Current fulfillment is on this return route, not in the webhook; if the customer never returns, the webhook alone will not generate the report. Optional `SMTP_*` settings enable report email after the paid report is successfully loaded.

For local webhook testing, `stripe listen --forward-to localhost:3000/api/stripe/webhook` (Stripe CLI) prints a temporary signing secret; use a test key and test signing secret only.

Not included yet: finance, stolen and write-off checks. Add a UKVD package for those and a new section in `server/report.js`.

## Customer report page
After payment, Stripe sends customers to `/report?session_id=...`, a standalone designed page (plate, summary tiles, mileage chart, MOT timeline, print/PDF). The email also links to it. Preview the design without paying at `/report?demo=1`. Set `BASE_URL` to your live https address so the Stripe return link and email link are correct.

## SEO and Google Search Console
The Vite production build prerenders the public routes with route-specific titles, descriptions, canonicals, Open Graph/Twitter metadata and structured data. It generates `/sitemap.xml`, `/robots.txt` and the Manus route manifest from `client/src/seo/routes.mjs`. Report, EV-result and API routes are excluded from the sitemap; private report/result responses are marked noindex and no-store. The build defaults to `https://motorbreif.co.uk`; confirm that the production host serves this domain over HTTPS before release, or set the public build variable `VITE_PUBLIC_ORIGIN` to the real HTTPS domain.

After the owner connects the domain and HTTPS works, add a **Domain property** in Google Search Console and verify ownership with the DNS TXT record Google supplies. Alternatively, a URL-prefix property can use the Google verification value as the public build variable `VITE_GOOGLE_SITE_VERIFICATION`; no token is currently stored in this project. Then submit `https://motorbreif.co.uk/sitemap.xml` and check `https://motorbreif.co.uk/robots.txt`. Submitting a sitemap does not guarantee indexing. Do not submit customer-specific report URLs.

## GoDaddy Node.js Hosting
This is an Express application with a React build and MySQL-backed paid-report storage; it cannot be deployed as static files alone. See [GODADDY_DEPLOYMENT.md](GODADDY_DEPLOYMENT.md) for the ZIP upload, build/start commands, environment-secret names, database, Stripe webhook and DNS prerequisites. Never upload a `.env` file or use the Manus database credentials on GoDaddy.
