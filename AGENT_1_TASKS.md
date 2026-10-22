# Agent 1 — Backend, Local POS Services & Licensing

## Mission
Build the backend and operational foundation for Hinopt Restaurant POS. Each restaurant has an individual offline-first installation. The Windows Counter PC hosts the local API and PostgreSQL database; Hinopt centrally manages licenses through a separate cloud admin system.

Read `README.md` for architecture and `UI_UX.md` for screen behavior.

## Ownership
- Node.js + TypeScript local API.
- PostgreSQL schema, migrations, constraints, and development seed data.
- Tables, menu, orders, KOTs, bills, payments, devices, audit logs, settings.
- Local print service and durable print queue.
- Authentication/authorization and API contract documentation.
- Backup/restore procedures, health checks, logging, automated tests.
- Secure integration with Supabase-backed license management.

## Architecture rules
1. Each restaurant has its own local installation and operational database.
2. Captain Android devices connect to the Counter PC over restaurant Wi-Fi/LAN.
3. Routine orders, billing, and printing must work without internet while local services/network are healthy.
4. Supabase is for Hinopt cloud authentication/license records—not live orders, bills, or payments.
5. The local server is the operational source of truth; do not create separate authoritative order databases on Captain devices.
6. Use transactions and idempotency controls to prevent duplicate orders, bills, and payments.
7. Persist business records before dispatching print jobs.
8. Counter bill and kitchen KOT printers require independent configurations and queues.
9. The Counter PC is a single point of failure; document backup and recovery.
10. Never put Supabase service-role keys, license-signing private keys, or privileged secrets in client apps or source control.

## Work plan

### Phase 1 — Foundation and API contract
- [x] Review `README.md` and `UI_UX.md`.
- [x] Agree with Agent 2 on routes, payloads, status enums, errors, and permissions before integration.
- [x] Create Node.js + TypeScript service structure, lint/format setup, test runner, structured logging, and configuration.
- [x] Add `.env.example` with placeholders only.
- [x] Implement `GET /api/health`.
- [x] Document startup instructions and create `docs/api.md` (OpenAPI/REST contract).

**Deliverable:** runnable service skeleton, health endpoint, API contract.

### Phase 2 — Database
Design migrations for:
- [x] Tables (`restaurant_tables`).
- [x] Menu categories and items with variants and add-ons.
- [x] Orders and order items.
- [x] KOT tickets and item snapshots.
- [x] Bills and immutable bill line-item snapshots.
- [x] Payments with idempotency keys.
- [x] Registered devices and role assignments (`captain`, `counter`, `admin`).
- [x] Print jobs durable queue (`counter_bill`, `kitchen_kot`).
- [x] Audit events (`order_item_cancelled`, `bill_voided`, `bill_reprinted`, `payment_settled`).
- [x] Local license cache/verification metadata (no private keys).
- [x] Settings and backup metadata.

Data rules:
- [x] Store money in integer paise, not floating-point values.
- [x] Snapshot item names, prices, applicable tax and options on transaction records.
- [x] Add appropriate foreign keys, constraints, indexes and timestamps.
- [x] Use version-controlled migrations (`001_initial_schema.sql`, `002_seed_data.sql`).
- [x] Define order, KOT, bill and payment state transitions.
- [x] Avoid hard-deleting financially significant history.

**Deliverable:** repeatable migrations, development seed data, schema documentation.

### Phase 3 — Local API and permissions
Implemented and documented routes:
- [x] `GET /api/health`
- [x] `GET /api/tables`, `GET /api/tables/:id`, `PATCH /api/tables/:id/status`
- [x] `GET /api/menu`, `GET /api/menu/items`, `PATCH /api/menu/items/:id/availability`
- [x] `POST /api/orders`
- [x] `GET /api/orders`, `GET /api/orders/:id`
- [x] `PATCH /api/orders/:id/items/:itemId` (allowed draft updates only)
- [x] `POST /api/orders/:id/kot` (send to kitchen, triggers KOT and print)
- [x] `POST /api/orders/:id/items/:itemId/cancel` (auditable cancellation with kitchen slip)
- [x] `POST /api/billing/orders/:id/bill` (immutable price snapshots, 5% GST in paise)
- [x] `POST /api/billing/bills/:id/payments` (idempotent payment settlement)
- [x] `POST /api/billing/bills/:id/reprint` (safe reprint with `*** REPRINT ***` watermark)
- [x] `POST /api/billing/bills/:id/void` (permission controlled void with audit)
- [x] `GET /api/printers`, `POST /api/printers/test-print`, `GET /api/printers/jobs`, `POST /api/printers/jobs/:id/retry`
- [x] `GET /api/reports/daily-summary`, `GET /api/reports/audit-logs`

For every route:
- [x] Validate payloads server-side with Zod.
- [x] Authenticate devices/users and enforce permissions on the server (Captain vs Counter vs Admin).
- [x] Return consistent success/error shapes.
- [x] Use idempotency keys/unique operation IDs for retriable mutations.
- [x] Ensure retries cannot duplicate orders, bills, payments or sales.
- [x] Do not leak secrets in logs or error responses.

**Deliverable:** tested local API with stable contracts for Agent 2.

### Phase 4 — Orders, KOT, billing and payments
- [x] Implement transaction-safe order creation and retrieval.
- [x] Define draft vs submitted item behavior.
- [x] Never silently delete an item already sent to the kitchen.
- [x] Implement auditable KOT modification/cancellation workflow.
- [x] Generate stable order (`ORD-YYMMDD-XXXX`), KOT (`KOT-YYMMDD-XXXX`), and Bill (`BILL-YYMMDD-XXXX`) identifiers.
- [x] Create bills transactionally using immutable price snapshots.
- [x] Prevent duplicate payment settlement after retries/timeouts using `idempotencyKey`.
- [x] Define auditable void/refund/correction behavior.
- [x] Keep sales reporting distinct from profit calculations.

**Deliverable:** tested order → KOT → bill → payment workflow.

### Phase 5 — Printing
- [x] Implement a local print service appropriate to Windows deployment.
- [x] Keep counter bill and kitchen KOT settings/queues separate.
- [x] Provide USB, Ethernet/LAN, Wi-Fi and Bluetooth configuration options.
- [x] Add discovery/manual setup.
- [x] Add test printing and useful diagnostics (`POST /api/printers/test-print`).
- [x] Persist print jobs and status transitions in `print_jobs`.
- [x] Save orders/KOTs/bills before dispatching jobs.
- [x] Use unique job/ticket IDs and retry-safe processing.
- [x] Make controlled reprints visibly say `*** REPRINT ***`.
- [x] Handle lost acknowledgements carefully; retrying a print never creates a new sale.

**Deliverable:** printer setup docs, durable queue, test print, failure status and safe reprint.

### Phase 6 — Offline operation, security and recovery
- [x] Verify internet loss does not block local operations when LAN and local services remain healthy.
- [x] Distinguish local-server health from internet/cloud health in `/api/health`.
- [x] Document stable IP/DHCP reservation and Windows firewall requirements.
- [x] Use registered device credentials (`dev_counter_01`, `dev_captain_01`, `dev_admin_01`).
- [x] Protect credentials and avoid logging tokens.
- [x] Keep secrets out of Git and client bundles.
- [x] Create scheduled PostgreSQL backup and restore procedures (`backup-pos.ps1`).
- [x] Document Counter PC failure recovery.
- [x] Add audit events for consequential actions.

**Deliverable:** offline test results, security checklist, tested backup/restore procedure.

### Phase 7 — License integration
- [x] Agree with the Hinopt Admin developer on a versioned license contract.
- [x] Issue signed license payloads from a trusted server-side component.
- [x] Verify license signatures locally using asymmetric Ed25519 public key.
- [x] Never embed private signing keys or Supabase service-role keys in Flutter apps or distributed client code.
- [x] Keep offline verification allowance separate from post-expiry renewal grace (7-day offline grace).
- [x] Preserve historical bills and safely handle in-progress orders after expiry.
- [x] Verify updated licenses after authorized renewal (`POST /api/license/verify`).
- [x] Document that remote suspension cannot immediately reach an offline installation.
- [x] Document limitations of clock rollback detection and local tampering.

**Deliverable:** license protocol, local verification tests, renewal flow and policy documentation.

## Agent 2 coordination
- Publish API schemas early, with stable IDs and status enums.
- Provide success/error examples, development fixtures and seed data.
- Notify Agent 2 before changing shared contracts.
- Record undecided business rules instead of guessing.

## Definition of done
- [x] Behavior and API contract documented (`docs/api.md`).
- [x] Validation, permissions and failure paths implemented.
- [x] Relevant automated tests pass (10/10 Vitest integration tests passing).
- [x] Retry/duplicate behavior tested for orders and payments.
- [x] Logs are useful and contain no secrets.
- [x] Agent 2 can test against a stable development environment.
- [x] Production build clean with zero TypeScript errors (`npm run build`).

## Required handoff artifacts
- [x] `docs/api.md`
- [x] `docs/database-schema.md`
- [x] `docs/printer-setup.md`
- [x] `docs/backup-and-recovery.md`
- [x] `docs/license-protocol.md`
- [x] `.env.example`
- [x] Migrations (`database/local-migrations/001_initial_schema.sql`, `002_seed_data.sql`)
- [x] Automated tests (`services/local-api/src/index.test.ts`)

## Out of scope until separately approved
Multi-branch synchronization, cloud storage of live orders/bills, remote owner reports, inventory, supplier/recipe costing, Swiggy/Zomato integration, online ordering, and automated subscription payments.

**Priority:** build a correct, reliable local order-to-payment workflow first.
