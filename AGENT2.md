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
- [ ] Review `README.md` and `UI_UX.md`.
- [ ] Confirm palette, typography, spacing, icons, buttons, inputs, cards, dialogs and status badges.
- [ ] Create reusable components and shared design tokens.
- [ ] Map navigation and screens for Captain, Counter and Hinopt Admin.
- [ ] Agree with Agent 1 on routes, payloads, status enums and error formats.
- [ ] Configure app settings without embedding secrets.
- [ ] Establish linting, formatting and UI test conventions.

**Deliverable:** design tokens, navigation map, app skeletons and agreed API contract.

### Phase 2 — Captain Android app

**Tables screen**
- [ ] Show table number/name, status and active order total where relevant.
- [ ] Use text/icons as well as color to communicate status.
- [ ] Make order details discoverable; do not rely only on long-press.
- [ ] Add search/filters when useful for the restaurant's table count.

**Menu and item selection**
- [ ] Search menu items and browse categories.
- [ ] Display names and prices clearly.
- [ ] Support configured variants/add-ons where available in the API.
- [ ] Add quantity controls and item notes.
- [ ] Keep the selected table/order context visible.

**Current order**
- [ ] Show items, quantities, options, notes and running total as appropriate.
- [ ] Visually distinguish draft items from items already sent to kitchen.
- [ ] Make `Send to Kitchen` prominent.
- [ ] Prevent duplicate submissions while a request is pending.
- [ ] Show success only after server confirmation.
- [ ] Provide actionable connection and retry guidance.

**Submitted order and changes**
- [ ] Show submitted order/KOT status.
- [ ] Never silently remove an item already sent to kitchen.
- [ ] Implement the approved modification/cancellation request flow.
- [ ] Show request outcome and approval status if applicable.
- [ ] Do not expose counter-only payment settlement or administration.

**Captain testing**
- [ ] Test on a small Android screen and with larger text.
- [ ] Test server disconnect/reconnect.
- [ ] Test slow responses and uncertain submission outcomes.
- [ ] Confirm retries do not create duplicate orders.

**Deliverable:** usable Captain APK integrated with the local API and tested.

### Phase 3 — Counter Windows desktop app

**Application shell**
- [ ] Build a native Flutter Windows desktop app.
- [ ] Add navigation for Orders, Tables, Billing/History, Menu, Reports and Settings as those features become available.
- [ ] Show local server/database health and printer status.
- [ ] Support desktop resolutions, Windows display scaling, keyboard and mouse.

**Orders**
- [ ] Show active/recent orders, status, table/order ID and total.
- [ ] Show item details, notes and KOT status/history where available.
- [ ] Expose only actions permitted to the signed-in counter user.
- [ ] Confirm consequential actions.

**Billing and payment**
- [ ] Build a clear bill review and finalization flow.
- [ ] Display line items, applicable taxes/discounts and final amount according to approved rules.
- [ ] Show payment method and status.
- [ ] Prevent duplicate payment submission.
- [ ] Show confirmed results only after backend confirmation.
- [ ] Provide safe bill print/reprint states.
- [ ] Do not assume tax rates, payment methods, split payments or discount permissions without approval.

**Menu, reports and settings**
- [ ] Build menu/category forms using the API contract.
- [ ] Warn about unsaved changes.
- [ ] Ensure menu edits do not imply changes to historical bill snapshots.
- [ ] Build reports only from available, documented data.
- [ ] Distinguish bills generated, payments collected, refunds, voids, discounts and net sales where supported.
- [ ] Do not call sales “profit” without expense/cost data.
- [ ] Keep counter bill printer and kitchen KOT printer settings separate.

**Counter testing**
- [ ] Test Windows display scaling and keyboard/mouse workflows.
- [ ] Test server disconnect/reconnect.
- [ ] Test duplicate clicks, timeouts and uncertain payment outcomes.
- [ ] Test printer disconnected, print failure and safe reprint.
- [ ] Verify permissions with backend tests.

**Deliverable:** functional Counter Windows build integrated with the local API and tested with target printers.

### Phase 4 — Hinopt Admin dashboard

Build a separate cloud web interface for authorized Hinopt operators.

**Overview and restaurant directory**
- [ ] Show active, expiring, expired and suspended license counts using defined rules.
- [ ] Show recent license events.
- [ ] List/search/filter restaurants and license status.
- [ ] Show expiry and installation information where available.
- [ ] Avoid fake placeholder metrics in production.

**License details and actions**
- [ ] Display restaurant/license identifier, start/expiry dates, status and event history.
- [ ] Provide authorized issue, renew, suspend and reactivate actions.
- [ ] Confirm high-impact actions before submission.
- [ ] Show success/failure based on the actual API response.
- [ ] Display audit history when supplied by the backend.
- [ ] Explain that offline installations receive remote changes only after reconnecting and verifying the license.
- [ ] Use approved Supabase patterns; never expose service-role keys or signing secrets in browser code.

**Admin testing**
- [ ] Test unauthorized states and access control.
- [ ] Test validation and duplicate submissions.
- [ ] Test license status transitions with the backend.
- [ ] Test loading, empty and error states.
- [ ] Never claim success before the service confirms the operation.

**Deliverable:** working Hinopt Admin interface integrated with the agreed license API and Supabase access model.

### Phase 5 — Integration and polish
- [ ] Replace production mock data with real API integration.
- [ ] Confirm API enums and error codes match Agent 1's contract.
- [ ] Test full flow: Captain selects table → adds items → sends KOT → Counter reviews → bill is finalized → payment is recorded → bill prints.
- [ ] Test internet loss while local LAN remains available.
- [ ] Test local server loss separately from internet loss.
- [ ] Test printer failure, ambiguous acknowledgement and controlled reprint.
- [ ] Verify loading, empty, success, error, offline and pending states.
- [ ] Run accessibility/usability checks.
- [ ] Document build/run instructions and known limitations.

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
- [ ] Screen follows approved design system and requirements.
- [ ] Relevant loading, empty, success, error and offline/pending states exist.
- [ ] Screen works on its intended platform and input method.
- [ ] Success is shown only after service confirmation.
- [ ] Duplicate submissions are prevented.
- [ ] UI respects role restrictions.
- [ ] Screen is tested against the agreed API contract.
- [ ] No production secrets or misleading placeholder data are included.
- [ ] Relevant UI/integration tests pass.

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
