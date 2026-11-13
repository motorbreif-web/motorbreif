# GoDaddy Node.js Hosting handoff — Motor B / motorbreif

## Current status

The source export is prepared for a GoDaddy Node.js application, but it has **not** been tested in GoDaddy's private preview or published to a custom domain. GoDaddy Node.js Hosting is currently documented as a beta product; first confirm availability for the owner's plan and account. Use the Node.js Hosting app flow rather than uploading only the React `client/dist` folder: the Express API, Stripe webhook and MySQL-backed paid-report storage are required. [1] [2]

**Confirm the exact final domain before deployment.** The current SEO origin and older handoff configuration say `motorbreif.co.uk`, while the owner's latest Search Console instructions say `motorbrief.co.uk`. Confirm which domain is registered and intended as canonical; do not change canonical tags, redirect rules, webhook URLs or DNS by guesswork. Search Console setup is deferred until the chosen domain is connected over HTTPS.

The Essential EV comparison is **£4.99 GBP**, one-off with no subscription. Its Checkout remains test-only and does not take a live payment, query UKVD or generate a report. The standard vehicle report remains **£9.99 GBP**. Do not turn on public EV sales or lookups until data access, provider costs and fulfillment have been confirmed and approved.

## Upload and run the application

1. In GoDaddy, open **Node.js Hosting** and create an application in the account's eligible plan. Select Node.js 22 where available (the project supports Node 20.19+ or Node 22.12+). The ZIP has `package.json` at its root; upload/extract it so the app root is the directory containing that file. GoDaddy's handoff documentation describes ZIP upload and Node.js deployment. [2] [3]
2. GoDaddy's Node.js app flow runs the root package build and start scripts: `npm run build` and `npm start`. The root manifest and lockfile include the app's production dependencies; the nested `install:all` script is available for local setup, not required as a replacement for the host's build contract. Keep the application on the `PORT` supplied by GoDaddy; do not hard-code a public port. The Express server exposes `GET /api/health` for a basic readiness check.
3. Create or attach a **GoDaddy-side MySQL database** and a database user with permission to create and update the report and Stripe-event tables. Set `DATABASE_URL` to the GoDaddy connection URL in the app's encrypted environment settings. On startup, the server creates its required tables if absent. The Manus-managed development database is separate: do not copy its credentials to GoDaddy or assume its saved reports move with the ZIP. If existing paid-report records need to be retained, arrange a separate secure database export/import before cutover. [4] [5] [6]

## Environment settings

Set secrets in GoDaddy's protected application environment, not in source files or the ZIP. Use `server/.env.example` as the variable-name reference. Required for the production report service:

- `NODE_ENV=production`
- `DATABASE_URL` — the GoDaddy MySQL connection string
- `UKVD_API_KEY` — the approved production UKVD key, server-side only
- `STRIPE_SECRET_KEY` — a valid live secret key (`sk_live_...`) or restricted key (`rk_live_...`) with the Checkout Session permissions the application needs
- `STRIPE_WEBHOOK_SECRET` — the signing secret (`whsec_...`) for the **same live webhook endpoint** described below
- `BASE_URL=https://motorbreif.co.uk` — set this only when that HTTPS domain is correctly routed to the app

Let GoDaddy provide `PORT`. `SMTP_HOST`, `SMTP_PORT`, `SMTP_SECURE`, `SMTP_USER`, `SMTP_PASS` and `FROM_EMAIL` are optional and are only needed if report email is deliberately configured. Do not use a publishable `pk_...` key as the server secret, do not put a key in a `VITE_` variable, and do not reuse an `mk_...` value as `STRIPE_SECRET_KEY`. Never send keys through chat or commit a `.env` file.

Use test Stripe credentials only in a non-production runtime. This app rejects test keys when `NODE_ENV=production`; do not temporarily weaken that guard to test a live site. Complete test-mode Checkout validation in Manus Preview/local development before adding live credentials to GoDaddy.

## Stripe webhook

After the app is reachable over HTTPS, add a webhook in the **correct Stripe account and mode** with this endpoint:

```text
https://motorbreif.co.uk/api/stripe/webhook
```

Subscribe at minimum to `checkout.session.completed`. If matching the existing managed integration's full event selection, also subscribe to `payment_intent.succeeded`, `payment_intent.payment_failed`, `customer.subscription.created`, `customer.subscription.updated` and `customer.subscription.deleted`; the website currently has no subscription product. Copy the endpoint's signing secret into GoDaddy's encrypted `STRIPE_WEBHOOK_SECRET` setting. A test-mode signing secret will not verify live events, and a live secret will not verify test events.

The handler verifies Stripe's signature against the raw request body and records signed event IDs idempotently. It does **not** generate the report or initiate a UKVD lookup. The customer return page re-verifies the paid Checkout session and then loads the report; webhook receipt alone is not proof of fulfillment.

## SEO and Google Search Console

The production build prerenders the public pages and generates `/sitemap.xml` and `/robots.txt`. Before building for GoDaddy, set the public build variable `VITE_PUBLIC_ORIGIN=https://motorbreif.co.uk` only if that domain is routed to this application and HTTPS is active; otherwise use the exact public HTTPS origin that will serve the site. `VITE_PUBLIC_ORIGIN` is a public URL, not a secret. An optional `VITE_GOOGLE_SITE_VERIFICATION` value is also included in public HTML and is only needed for Google URL-prefix meta-tag verification; for a Domain property, verify ownership with Google's DNS TXT record instead.

After HTTPS and DNS are confirmed, request `/robots.txt` and `/sitemap.xml` on the selected canonical domain and submit that sitemap in Search Console. Do not submit report URLs, payment-session URLs or registration-specific results. A sitemap submission does not guarantee indexing.

## Pre-launch checks and outstanding approvals

Before directing customers to the domain, confirm all of the following:

- The live UKVD account includes the exact packages used by the website, its production API key works, and the owner has approved the per-lookup credit cost. Homepage registration checks are free to the customer but may consume provider credits.
- Stripe production credentials are valid, restricted-key permissions are correct, the production webhook is signed and tested, and the published checkout amount/return flow is reviewed.
- The registered office address, company number and VAT status are confirmed and added to the Terms page. Do not invent these details.
- The GoDaddy MySQL connection succeeds and paid-report persistence survives an application restart.
- `GET /api/health` returns success; the site serves over HTTPS; DNS and certificate status are verified.

Do not change DNS until the application, database, secrets, legal text and payment configuration are ready. If the domain is managed outside the GoDaddy account, use only the DNS records shown in the GoDaddy app and add them at the active DNS host; do not guess A/CNAME values or alter mail-related records. DNS updates can take time to propagate. [7] [8]

## Official GoDaddy references

[1]: https://www.godaddy.com/hosting/nodejs "GoDaddy Node.js Hosting"
[2]: https://www.godaddy.com/help/godaddy-nodejs-hosting-faq-42915 "GoDaddy Node.js Hosting FAQ"
[3]: https://www.godaddy.com/help/upload-my-ai-generated-app-to-godaddy-nodejs-hosting-42987 "Upload an app to GoDaddy Node.js Hosting"
[4]: https://www.godaddy.com/help/create-a-mysql-database-in-my-web-hosting-cpanel-16016 "Create a MySQL database in GoDaddy hosting"
[5]: https://www.godaddy.com/help/connect-remotely-to-a-mysql-database-in-my-web-hosting-cpanel-account-16103 "Connect remotely to GoDaddy MySQL"
[6]: https://www.godaddy.com/help/deploy-my-cursor-or-claude-app-with-godaddy-nodejs-hosting-42908 "Deploy an app with GoDaddy Node.js Hosting"
[7]: https://www.godaddy.com/help/configuring-dns-for-your-web-hosting-cpanel-domain-8852 "Configure DNS for GoDaddy hosting"
[8]: https://www.godaddy.com/help/activate-an-integrated-ssl-32040 "Activate SSL in GoDaddy"
