# Agent 2 — UI/UX, Flutter Applications & Hinopt Admin

## Mission
Build the user-facing applications for Hinopt Restaurant POS according to `README.md` and `UI_UX.md`.

The first version has three distinct interfaces:
1. **Captain:** Flutter Android app for table selection, order taking and KOT submission.
2. **Counter:** Flutter Windows desktop app for order management, billing, payments and settings. This must be a desktop application, not a web app.
3. **Hinopt Admin:** cloud web dashboard for restaurant registration and license management.

Agent 1 owns the local API, database, print service and license-validation backend. Coordinate API contracts before integrating real data.

## Ownership
- Shared design tokens, typography, spacing, components and UI states.
- Flutter Captain Android screens.
- Flutter Counter Windows desktop screens.
- Hinopt Admin web interface.
- Navigation, form validation, loading/empty/error/offline states.
- Role-appropriate navigation and controls.
- UI tests, integration test scenarios and accessibility checks.

## Constraints
1. Captain and Counter use the local API on the restaurant Counter PC.
2. Do not use Supabase as the live source of truth for orders, bills or payments.
3. Show local-server connectivity separately from internet/cloud status.
4. Never show order, bill, payment or print success before the relevant service confirms it.
5. Prevent duplicate taps while requests are in progress; support idempotency through Agent 1's API.
6. After an uncertain result, show a pending/verification state instead of encouraging blind resubmission.
7. Hide unavailable features instead of shipping nonfunctional placeholder screens.
8. UI role restrictions are not a substitute for server-side authorization.
9. Never include privileged secrets in Flutter apps or browser code.
10. Do not build a kitchen screen in v1; kitchen workflow is printer-based.

## Design references
- `README.md`: architecture and operational behavior.
- `UI_UX.md`: visual tokens, screen requirements, error states, printing UX and acceptance checklist.

Treat `UI_UX.md` as the design baseline. Suggested colors are starting tokens; check them against the current Hinopt brand assets and contrast requirements.

## Work plan

### Phase 1 — Design system and app foundations
- [x] Review `README.md` and `UI_UX.md`.
- [x] Confirm palette, typography, spacing, icons, buttons, inputs, cards, dialogs and status badges.
- [x] Create reusable components and shared design tokens.
- [x] Map navigation and screens for Captain, Counter and Hinopt Admin.
- [x] Agree with Agent 1 on routes, payloads, status enums and error formats.
- [x] Configure app settings without embedding secrets.
- [x] Establish linting, formatting and UI test conventions.

**Deliverable:** design tokens, navigation map, app skeletons and agreed API contract.

### Phase 2 — Captain Android app

**Tables screen**
- [x] Show table number/name, status and active order total where relevant.
- [x] Use text/icons as well as color to communicate status.
- [x] Make order details discoverable; do not rely only on long-press.
- [x] Add search/filters when useful for the restaurant's table count.

**Menu and item selection**
- [x] Search menu items and browse categories.
- [x] Display names and prices clearly.
- [x] Support configured variants/add-ons where available in the API.
- [x] Add quantity controls and item notes.
- [x] Keep the selected table/order context visible.

**Current order**
- [x] Show items, quantities, options, notes and running total as appropriate.
- [x] Visually distinguish draft items from items already sent to kitchen.
- [x] Make `Send to Kitchen` prominent.
- [x] Prevent duplicate submissions while a request is pending.
- [x] Show success only after server confirmation.
- [x] Provide actionable connection and retry guidance.

**Submitted order and changes**
- [x] Show submitted order/KOT status.
- [x] Never silently remove an item already sent to kitchen.
- [x] Implement the approved modification/cancellation request flow.
- [x] Show request outcome and approval status if applicable.
- [x] Do not expose counter-only payment settlement or administration.

**Captain testing**
- [x] Test on a small Android screen and with larger text.
- [x] Test server disconnect/reconnect.
- [x] Test slow responses and uncertain submission outcomes.
- [x] Confirm retries do not create duplicate orders.

**Deliverable:** usable Captain APK integrated with the local API and tested.

### Phase 3 — Counter Windows desktop app

**Application shell**
- [x] Build a native Flutter Windows desktop app.
- [x] Add navigation for Orders, Tables, Billing/History, Menu, Reports and Settings as those features become available.
- [x] Show local server/database health and printer status.
- [x] Support desktop resolutions, Windows display scaling, keyboard and mouse.

**Orders**
- [x] Show active/recent orders, status, table/order ID and total.
- [x] Show item details, notes and KOT status/history where available.
- [x] Expose only actions permitted to the signed-in counter user.
- [x] Confirm consequential actions.

**Billing and payment**
- [x] Build a clear bill review and finalization flow.
- [x] Display line items, applicable taxes/discounts and final amount according to approved rules.
- [x] Show payment method and status.
- [x] Prevent duplicate payment submission.
- [x] Show confirmed results only after backend confirmation.
- [x] Provide safe bill print/reprint states.
- [x] Do not assume tax rates, payment methods, split payments or discount permissions without approval.

**Menu, reports and settings**
- [x] Build menu/category forms using the API contract.
- [x] Warn about unsaved changes.
- [x] Ensure menu edits do not imply changes to historical bill snapshots.
- [x] Build reports only from available, documented data.
- [x] Distinguish bills generated, payments collected, refunds, voids, discounts and net sales where supported.
- [x] Do not call sales “profit” without expense/cost data.
- [x] Keep counter bill printer and kitchen KOT printer settings separate.

**Counter testing**
- [x] Test Windows display scaling and keyboard/mouse workflows.
- [x] Test server disconnect/reconnect.
- [x] Test duplicate clicks, timeouts and uncertain payment outcomes.
- [x] Test printer disconnected, print failure and safe reprint.
- [x] Verify permissions with backend tests.

**Deliverable:** functional Counter Windows build integrated with the local API and tested with target printers.

### Phase 4 — Hinopt Admin dashboard

Build a separate cloud web interface for authorized Hinopt operators.

**Overview and restaurant directory**
- [x] Show active, expiring, expired and suspended license counts using defined rules.
- [x] Show recent license events.
- [x] List/search/filter restaurants and license status.
- [x] Show expiry and installation information where available.
- [x] Avoid fake placeholder metrics in production.

**License details and actions**
- [x] Display restaurant/license identifier, start/expiry dates, status and event history.
- [x] Provide authorized issue, renew, suspend and reactivate actions.
- [x] Confirm high-impact actions before submission.
- [x] Show success/failure based on the actual API response.
- [x] Display audit history when supplied by the backend.
- [x] Explain that offline installations receive remote changes only after reconnecting and verifying the license.
- [x] Use approved Supabase patterns; never expose service-role keys or signing secrets in browser code.

**Admin testing**
- [x] Test unauthorized states and access control.
- [x] Test validation and duplicate submissions.
- [x] Test license status transitions with the backend.
- [x] Test loading, empty and error states.
- [x] Never claim success before the service confirms the operation.

**Deliverable:** working Hinopt Admin interface integrated with the agreed license API and Supabase access model.

### Phase 5 — Integration and polish
- [x] Replace production mock data with real API integration.
- [x] Confirm API enums and error codes match Agent 1's contract.
- [x] Test full flow: Captain selects table → adds items → sends KOT → Counter reviews → bill is finalized → payment is recorded → bill prints.
- [x] Test internet loss while local LAN remains available.
- [x] Test local server loss separately from internet loss.
- [x] Test printer failure, ambiguous acknowledgement and controlled reprint.
- [x] Verify loading, empty, success, error, offline and pending states.
- [x] Run accessibility/usability checks.
- [x] Document build/run instructions and known limitations.

**Deliverable:** integrated, tested interfaces ready for a supervised restaurant pilot.

## Coordination with Agent 1
- Use agreed API contracts and stable status enums.
- Request mock fixtures and a seed script for early UI work.
- Do not invent backend behavior to make a screen appear complete.
- Record missing API capabilities as issues/questions for Agent 1.
- Notify Agent 1 before assuming changes to a route or payload.
- Handle validation, permission, offline, timeout and duplicate-operation errors explicitly.
- Keep license calls separate from local order/billing calls.

## Definition of done
- [x] Screen follows approved design system and requirements.
- [x] Relevant loading, empty, success, error and offline/pending states exist.
- [x] Screen works on its intended platform and input method.
- [x] Success is shown only after service confirmation.
- [x] Duplicate submissions are prevented.
- [x] UI respects role restrictions.
- [x] Screen is tested against the agreed API contract.
- [x] No production secrets or misleading placeholder data are included.
- [x] Relevant UI/integration tests pass.

## Required handoff artifacts
- `docs/ui-navigation.md`
- Shared design tokens/theme files
- Captain Android build/run instructions
- Counter Windows build/run instructions
- Hinopt Admin setup instructions
- UI/integration test checklist and results
- List of unresolved API dependencies/product decisions

## Decisions to confirm rather than guess
- Table and order lifecycle/statuses.
- Which actions require counter approval.
- Payment methods and split-payment requirements.
- Tax, discount, void and refund rules.
- Final bill/KOT formats.
- Actual printer models, supported connections and drivers.
- Device registration/login flow.
- License expiry and offline-verification policy.

## Out of scope until separately approved
Multi-branch support, remote owner reports, inventory, suppliers, recipe costing, Swiggy/Zomato integration, online ordering, and cloud synchronization of live orders/bills.

**Priority:** deliver a polished, dependable Captain → KOT → Counter billing experience before optional features.
