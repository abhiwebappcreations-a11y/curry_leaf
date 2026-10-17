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
- [ ] Review `README.md` and `UI_UX.md`.
- [ ] Agree with Agent 2 on routes, payloads, status enums, errors, and permissions before integration.
- [ ] Create Node.js + TypeScript service structure, lint/format setup, test runner, structured logging, and configuration.
- [ ] Add `.env.example` with placeholders only.
- [ ] Implement `GET /api/health`.
- [ ] Document startup instructions and create `docs/api.md` (OpenAPI preferred).

**Deliverable:** runnable service skeleton, health endpoint, API contract.

### Phase 2 — Database
Design migrations for:
- [ ] Tables.
- [ ] Menu categories and items.
- [ ] Orders and order items.
- [ ] KOT tickets and item snapshots.
- [ ] Bills and immutable bill line-item snapshots.
- [ ] Payments.
- [ ] Registered devices and role assignments.
- [ ] Print jobs.
- [ ] Audit events.
- [ ] Local license cache/verification metadata (no private keys).
- [ ] Settings and backup metadata where useful.

Data rules:
- [ ] Store money in integer paise, not floating-point values.
- [ ] Snapshot item names, prices, applicable tax and options on transaction records.
- [ ] Add appropriate foreign keys, constraints, indexes and timestamps.
- [ ] Use version-controlled migrations; avoid manual production schema edits.
- [ ] Define order, KOT, bill and payment state transitions.
- [ ] Avoid hard-deleting financially significant history.

**Deliverable:** repeatable migrations, development seed data, schema documentation.

### Phase 3 — Local API and permissions
Implement and document routes. These are proposed examples; finalize schemas with Agent 2:
- [ ] `GET /api/health`
- [ ] `GET /api/tables`
- [ ] `GET /api/menu`
- [ ] `POST /api/orders`
- [ ] `GET /api/orders/:id`
- [ ] `PATCH /api/orders/:id` (allowed draft updates only)
- [ ] `POST /api/orders/:id/kot`
- [ ] A documented cancellation/modification request route.
- [ ] `POST /api/orders/:id/bill`
- [ ] `POST /api/bills/:id/payments`
- [ ] Bill history/detail routes.
- [ ] Printer list, test-print, job-status and controlled-reprint routes.
- [ ] Menu, table and settings routes for authorized counter users.

For every route:
- [ ] Validate payloads server-side.
- [ ] Authenticate devices/users and enforce permissions on the server.
- [ ] Return consistent success/error shapes.
- [ ] Use idempotency keys/unique operation IDs for retriable mutations.
- [ ] Ensure retries cannot duplicate orders, bills, payments or sales.
- [ ] Do not leak secrets in logs or error responses.

**Deliverable:** tested local API with stable contracts for Agent 2.

### Phase 4 — Orders, KOT, billing and payments
- [ ] Implement transaction-safe order creation and retrieval.
- [ ] Define draft vs submitted item behavior.
- [ ] Never silently delete an item already sent to the kitchen.
- [ ] Implement auditable KOT modification/cancellation workflow; confirm approval rules before hard-coding.
- [ ] Generate stable order and KOT identifiers.
- [ ] Create bills transactionally using price snapshots.
- [ ] Prevent duplicate payment settlement after retries/timeouts.
- [ ] Define auditable void/refund/correction behavior before implementing it.
- [ ] Do not assume tax, discount, split-payment, or payment-method rules without approval.
- [ ] Keep sales reporting distinct from profit calculations.

**Deliverable:** tested order → KOT → bill → payment workflow.

### Phase 5 — Printing
- [ ] Implement a local print service appropriate to Windows deployment.
- [ ] Keep counter bill and kitchen KOT settings/queues separate.
- [ ] Provide USB, Ethernet/LAN, Wi-Fi and Bluetooth configuration options only where actual printer/driver hardware supports them.
- [ ] Add discovery/manual setup where technically supported.
- [ ] Add test printing and useful diagnostics.
- [ ] Persist print jobs and status transitions.
- [ ] Save orders/KOTs/bills before dispatching jobs.
- [ ] Use unique job/ticket IDs and retry-safe processing.
- [ ] Make controlled reprints visibly say `REPRINT`.
- [ ] Handle lost acknowledgements carefully; retrying a print must not create a new sale.
- [ ] Test actual target printer models, drivers, paper widths and connections.

**Deliverable:** printer setup docs, durable queue, test print, failure status and safe reprint.

### Phase 6 — Offline operation, security and recovery
- [ ] Verify internet loss does not block local operations when LAN and local services remain healthy.
- [ ] Distinguish local-server health from internet/cloud health.
- [ ] Document stable IP/DHCP reservation and Windows firewall requirements.
- [ ] Use registered device credentials; Wi-Fi membership alone is not authentication.
- [ ] Protect credentials and avoid logging tokens.
- [ ] Keep secrets out of Git and client bundles.
- [ ] Create scheduled PostgreSQL backup and restore procedures.
- [ ] Perform a test restore and document Counter PC failure recovery.
- [ ] Add audit events for consequential actions.

**Deliverable:** offline test results, security checklist, tested backup/restore procedure.

### Phase 7 — License integration
- [ ] Agree with the Hinopt Admin developer on a versioned license contract.
- [ ] Issue signed license payloads from a trusted server-side component.
- [ ] Verify license signatures locally using a public key.
- [ ] Never embed private signing keys or Supabase service-role keys in Flutter apps or distributed client code.
- [ ] Keep offline verification allowance separate from post-expiry renewal grace.
- [ ] Implement expiry behavior only after the product owner approves the policy.
- [ ] Preserve historical bills and safely handle in-progress orders after expiry.
- [ ] Verify updated licenses after authorized renewal and reconnection.
- [ ] Document that remote suspension cannot immediately reach an offline installation.
- [ ] Document limitations of clock rollback detection and local tampering.

**Deliverable:** license protocol, local verification tests, renewal flow and policy documentation.

## Agent 2 coordination
- Publish API schemas early, with stable IDs and status enums.
- Provide success/error examples, development fixtures and seed data.
- Notify Agent 2 before changing shared contracts.
- Record undecided business rules instead of guessing.

## Definition of done
- [ ] Behavior and API contract documented.
- [ ] Validation, permissions and failure paths implemented.
- [ ] Relevant automated tests pass.
- [ ] Retry/duplicate behavior tested for orders and payments.
- [ ] Logs are useful and contain no secrets.
- [ ] Agent 2 can test against a stable development environment.
- [ ] Unresolved business rules are explicitly recorded.

## Required handoff artifacts
- `docs/api.md` or `docs/openapi.yaml`
- `docs/database-schema.md`
- `docs/printer-setup.md`
- `docs/backup-and-recovery.md`
- `docs/license-protocol.md`
- `.env.example`
- Migrations and automated tests

## Out of scope until separately approved
Multi-branch synchronization, cloud storage of live orders/bills, remote owner reports, inventory, supplier/recipe costing, Swiggy/Zomato integration, online ordering, and automated subscription payments.

**Priority:** build a correct, reliable local order-to-payment workflow first.
