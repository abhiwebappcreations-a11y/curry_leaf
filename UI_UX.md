# Hinopt Restaurant POS — UI/UX Specification

This document defines the user experience and visual direction for the first version of Hinopt Restaurant POS. It complements [`README.md`](./README.md), which documents the system architecture and operational design.

> **Status:** Design specification. These guidelines describe intended behavior and appearance; they do not imply that screens have already been implemented. Final workflows and any undecided business rules should be confirmed before they are hard-coded.

## Contents

- [Product Design Goals](#product-design-goals)
- [Applications and Users](#applications-and-users)
- [Shared Visual Design System](#shared-visual-design-system)
- [Captain Android App](#captain-android-app)
- [Counter Windows Desktop App](#counter-windows-desktop-app)
- [Hinopt Admin Dashboard](#hinopt-admin-dashboard)
- [Shared Interaction and Status Patterns](#shared-interaction-and-status-patterns)
- [Accessibility and Usability](#accessibility-and-usability)
- [Error and Offline UX](#error-and-offline-ux)
- [Printing UX](#printing-ux)
- [UI/UX Acceptance Checklist](#uiux-acceptance-checklist)

## Product Design Goals

The interface should feel professional, dependable, and fast during a busy restaurant service.

Priorities, in order:

1. **Operational clarity:** users can immediately tell what needs attention.
2. **Speed:** frequent actions require minimal steps.
3. **Error prevention:** protect orders, payments, and bills from accidental changes.
4. **Reliable feedback:** clearly distinguish saved, pending, failed, and printed states.
5. **Role separation:** each user sees only the functions needed for their role.
6. **Consistency:** all Hinopt applications share a recognizable visual language.
7. **Practicality:** optimize for real restaurant lighting, touch use, keyboard use, and thermal printers.

Avoid decorative animation, excessive gradients, tiny controls, unnecessary dashboards, and hidden actions that slow down service.

## Applications and Users

| Application | Primary user | Platform | Primary goal |
|---|---|---|---|
| Captain | Waiter/captain | Android APK | Select tables, take orders, send KOTs |
| Counter | Cashier/counter staff | Windows desktop app | Manage orders, bill, settle payment, configure operations |
| Hinopt Admin | Hinopt operator | Cloud web dashboard | Manage restaurant registrations and licenses |

The Counter application is a **native Flutter Windows desktop application, not a web application**. The Captain application is optimized for Android. The Hinopt Admin dashboard is a separate cloud-based web interface.

## Shared Visual Design System

### Brand direction

Use a clean, modern, professional restaurant-software identity. Keep the Hinopt logo and brand assets consistent across all applications.

Suggested starting palette:

| Token | Suggested value | Usage |
|---|---|---|
| Primary | `#163B3A` | Main brand actions and selected navigation |
| Accent | `#4CC9B0` | Positive emphasis and selected controls |
| App background | `#F5F7F7` | Main light-mode background |
| Surface | `#FFFFFF` | Cards, dialogs, and panels |
| Main text | `#172322` | Headings and primary content |
| Secondary text | `#657371` | Hints, metadata, and supporting labels |
| Border | `#DCE5E3` | Dividers and control outlines |
| Success | `#218653` | Confirmed/successful states |
| Warning | `#A96508` | Caution and pending attention |
| Error | `#B42318` | Errors and destructive-action warnings |
| Information | `#245DB5` | Informational messages |

These are starting tokens, not final approved brand colors. Verify contrast and refine the palette against the current Hinopt logo before implementation. Do not communicate status using color alone; always include text or an icon.

### Typography

- Use **Inter** or another highly legible sans-serif.
- Use clear hierarchy: page title, section title, body, label, and helper text.
- Prefer readable text over fitting more data on screen.
- Use tabular numerals for amounts, totals, and quantities where supported.
- Avoid all-caps labels for long text. Reserve uppercase for short statuses or ticket identifiers when useful.

Suggested starting type scale:

| Style | Suggested size |
|---|---:|
| Page title | 24–28 px |
| Section title | 18–20 px |
| Body | 14–16 px |
| Labels and metadata | 12–14 px |
| Large amount | 24–32 px |

These are design references; platform scaling and accessibility settings take precedence.

### Layout and components

- Use consistent spacing based on a 4 px grid.
- Prefer clear alignment, restrained borders, and modest corner radii.
- Keep primary actions visually distinct from secondary actions.
- Use icons with labels for important actions; avoid icon-only controls unless the icon is universally recognizable and accessible.
- Maintain consistent button heights and input behavior.
- Use dialogs for consequential actions and inline feedback for routine status updates.
- Avoid unnecessary page transitions and long blocking animations.

### Status colors and labels

Define statuses centrally and reuse them across applications. Example semantic mapping:

- **Available:** neutral or success treatment.
- **Occupied / Active:** primary or information treatment.
- **Preparing:** warning or information treatment.
- **Ready:** success treatment.
- **Cancelled / Failed:** error treatment.
- **Pending:** warning treatment.

The final table and order lifecycle must be defined by the product's business rules. Never show a table, order, or payment as completed before the server confirms the change.

## Captain Android App

### Experience principles

- Design for one-handed and touch-first operation where practical.
- Make tables, menu items, quantities, and the send-to-kitchen action easy to reach.
- Minimize typing during service.
- Keep the current table/order context visible while editing.
- Make connection state and submission results obvious.

### Recommended navigation

Use a simple navigation structure rather than a large administrative menu:

- **Tables:** primary landing screen.
- **Menu / Add items:** opened from a selected table or order.
- **Current order:** items, quantities, notes, and submission action.
- **Order details:** previously submitted items and current status.
- **Account / Connection:** device identity and connection diagnostics, as needed.

Avoid giving Captain users access to license management, database configuration, global printer administration, or counter-only settlement functions.

### Screen specifications

#### 1. Tables screen

Each table card should show:

- Table number or name.
- Clear state label.
- Current order total, if an active order exists.
- A concise indication that attention is required, where relevant.

Interactions:

- Tapping a table opens its current order or starts a new order according to the configured workflow.
- Use a visible action for opening order details; do not rely only on long-press.
- Provide search or filters if the restaurant has enough tables to make them useful.
- Do not use color as the only indicator of table state.

#### 2. Menu and item selection

Include:

- Search field.
- Clear category navigation.
- Readable item names and prices.
- Configured variants and add-ons.
- Quantity controls with generous tap targets.
- Item notes when needed.
- Clear feedback when an item is added.

Keep item selection fast. Images are optional and should not delay menu loading or crowd the screen.

#### 3. Current order screen

Show:

- Table/order identifier.
- Ordered items, quantity, selected options, and notes.
- Running total, where appropriate.
- Controls to change quantities or remove unsent draft items.
- A prominent **Send to Kitchen** action.

After submission, show a confirmed result only after the local server acknowledges that the order was saved. If the response is uncertain, show a pending/verification state and prevent a blind repeat submission.

#### 4. Submitted order and modifications

- Clearly distinguish draft items from items already sent to the kitchen.
- Never silently delete an item that has already been sent.
- Use a modification/cancellation workflow for submitted items.
- Collect a reason and require counter approval if the final business rules specify it.
- Show the status of the request and any resulting KOT.

#### 5. Connection and error states

Display a compact but readable connection indicator. Tapping it can reveal helpful details, such as whether the counter server is reachable.

Messages should say what happened and what the user can do next. For example:

- “Order saved and KOT queued.”
- “Could not reach the counter server. Check restaurant Wi-Fi.”
- “Submission status is being checked. Do not submit again yet.”

Do not claim an order was saved merely because the user tapped a button.

## Counter Windows Desktop App

### Experience principles

- Optimize for a desktop screen, mouse, and keyboard.
- Keep critical order and billing information visible.
- Use predictable navigation and consistent page layouts.
- Support efficient cashier workflows without hiding important safeguards.
- Provide clear print, network, and database health indicators.

### Recommended application shell

A practical starting layout:

- **Sidebar:** Orders, Tables, Billing/History, Menu, Reports, Settings.
- **Main workspace:** selected page or active order list.
- **Context panel:** order details or bill summary where useful.
- **Status area:** local server/database state, network state, and printer status.

Adjust the navigation to the actual implemented features; do not display nonfunctional placeholder pages.

### Screen specifications

#### 1. Counter home / active orders

Prioritize:

- New or recently updated orders.
- Table/order identifier and status.
- Time or age of order when useful.
- Total amount.
- A clear way to open the order.

Avoid filling the first screen with vanity metrics that do not help staff serve customers.

#### 2. Order details

Show:

- Table/order ID.
- Items, quantities, notes, and applicable modifications.
- KOT history or status where useful.
- Current order total.
- Available actions based on permissions.

Use clear confirmation steps for cancellation and other consequential changes.

#### 3. Billing and payment

Make the bill easy to review before settlement. Show applicable line items, discounts, tax, and final total according to the restaurant's configured rules.

Requirements:

- Make the amount due visually prominent.
- Show the selected payment method and payment status.
- Prevent duplicate settlement on repeated clicks or network timeouts.
- Make voids/refunds and corrections permission-controlled and auditable.
- Confirm a bill/payment only after the server reports a committed result.
- Provide a clear bill print status and safe reprint action.

Payment methods, tax behavior, discount permissions, split payments, and receipt format must follow the finalized business requirements rather than being assumed by the UI.

#### 4. Menu management

Provide simple forms for the configured menu fields, such as item name, category, price, availability, and supported variants/add-ons.

- Validate required fields.
- Show clear save/cancel actions.
- Warn before leaving with unsaved changes.
- Make unavailable items visibly unavailable to Captains.
- Do not let an ordinary menu edit silently alter historical bills; preserve the item price/name snapshot used by each transaction.

#### 5. Reports and history

Use readable tables with search, filters, and date ranges when those features are implemented.

Distinguish:

- Bills generated.
- Payments collected.
- Voids and refunds.
- Discounts.
- Net sales as defined by the reporting rules.

Do not label sales as profit unless expense and cost data are included in the calculation.

#### 6. Settings and device management

Group settings into clear sections:

- Restaurant and table setup.
- Menu configuration.
- Captain/device access.
- Counter bill printer.
- Kitchen KOT printer.
- Backup and recovery.
- License and installation status.

Printer settings must be independent for the counter bill printer and kitchen KOT printer.

## Hinopt Admin Dashboard

### Experience principles

This is an administrative tool for Hinopt, not a restaurant cashier screen. Optimize for accurate license operations, search, auditability, and clear status.

### Recommended navigation

- **Overview:** license and renewal summary.
- **Restaurants:** registered restaurant records.
- **Licenses:** issue, renew, suspend, reactivate, and inspect licenses.
- **Installations / Devices:** registered installation details.
- **Audit history:** important license and admin actions.
- **Admin settings:** authorized administrative configuration.

### Screen specifications

#### 1. Overview

Show useful operational indicators such as:

- Active licenses.
- Licenses nearing expiry.
- Expired licenses.
- Suspended licenses.
- Recent license events.

Counts must be derived from actual records and use clear definitions.

#### 2. Restaurant directory

Provide:

- Search by restaurant name or internal identifier.
- License status and expiry.
- Installation status where available.
- A clear path to view the restaurant record.

Do not expose restaurant operational data such as detailed orders or customer information unless a separate, explicit feature and access policy is introduced.

#### 3. License details

Display:

- Restaurant/license identifier.
- Start and expiry dates.
- Current status.
- Registered installation information.
- Renewal and event history.

Use confirmation dialogs for suspension and other consequential actions. Explain the effect before confirming.

#### 4. Renew or reactivate

- Show the target restaurant and license before committing the action.
- Validate dates and status transitions.
- Report whether the change was saved successfully.
- Record the acting admin and event time in the audit history.
- Make it clear that an offline installation may not receive a suspension or renewal update until it reconnects and verifies its license.

Do not claim that a remote command instantly changes an offline Counter PC.

## Shared Interaction and Status Patterns

### Buttons

Use action labels that describe the outcome:

- `Send to Kitchen`
- `Save Changes`
- `Finalize Bill`
- `Print Test`
- `Reprint KOT`
- `Renew License`

Avoid vague labels such as `OK` or `Proceed` for high-impact actions.

### Loading and submission

- Disable duplicate submissions while a request is in progress.
- Show progress for operations that take noticeable time.
- Distinguish local validation errors from server/network failures.
- After a timeout, verify the existing operation's status before offering a repeat action where possible.

### Confirmation and undo

Use confirmation for destructive or financially significant actions. Where safe, prefer a reversible workflow or an explicit correction record over deleting historical data.

### Empty states

Empty screens should explain why there is no data and what action is available, for example:

- “No active orders.”
- “No menu items yet. Add an item to begin.”
- “No printer configured. Open printer settings to configure one.”

### Notifications

Use short, specific messages. Do not rely on a toast alone for critical failures; persistent status should remain visible until the issue is resolved or acknowledged.

## Accessibility and Usability

- Maintain sufficient text/background contrast.
- Support platform text scaling where possible.
- Use clear focus indicators for keyboard navigation.
- Ensure buttons and touch targets are large enough for practical use.
- Provide accessible labels for icon buttons and form controls.
- Do not communicate status using color alone.
- Use explicit currency formatting and consistent decimal precision.
- Avoid relying on hover-only interactions.
- Test on the smallest supported Android screen and common Windows display scaling settings.
- Test with realistic restaurant lighting and during a busy service simulation.

## Error and Offline UX

The UI must reflect the actual state reported by the local service.

| Condition | Expected UI behavior |
|---|---|
| Server reachable | Show connected/ready state |
| Internet unavailable, local server reachable | Show internet/cloud unavailable separately; local POS can remain usable |
| Counter server unreachable | Show local server unavailable and provide connection guidance |
| Order saved, print queued | Show order saved and printing pending/queued |
| Print failed | Show failure and a safe retry/reprint option |
| Request outcome uncertain | Show verification/pending state; avoid blind duplicate submission |
| License needs verification | Explain the current license state and next step |
| License expired | Apply the configured policy while preserving historical data and safely handling in-progress orders |

Never show “Offline” as a single ambiguous status if the UI can distinguish local network availability from internet availability.

## Printing UX

Each printer must have its own settings and status.

### Printer settings

Provide:

- Printer purpose: counter bill or kitchen KOT.
- Connection type selector: USB, Ethernet/LAN, Wi-Fi, Bluetooth.
- Connection-specific configuration fields.
- Discovery or manual configuration where supported by the printer and platform.
- Test print action.
- Connection/ready status.
- Save and reconnect actions.
- Clear diagnostics for common failures.

Connection choices must not imply that every printer supports every connection type. Show only configurations that can actually be used with the selected printer and drivers, or explain the required adapter/hardware.

### Print queue and reprint

- Save the business record before creating or dispatching a print job.
- Show queued, printing, successful, and failed states when the print service can determine them.
- Use unique order/ticket IDs.
- Make reprints explicit and print `REPRINT` clearly on the duplicate copy.
- Do not silently create a new bill or sale just because a print job is retried.
- Explain that a printer may physically print even if an acknowledgement is lost; ambiguous cases require careful verification before retrying.

## UI/UX Acceptance Checklist

### Captain Android

- [ ] Tables and their statuses are easy to scan.
- [ ] Menu search, categories, quantity controls, and item notes are usable on a phone.
- [ ] Current table/order context stays clear.
- [ ] `Send to Kitchen` is prominent.
- [ ] Draft items and already-submitted items are visually distinct.
- [ ] Success is shown only after server confirmation.
- [ ] Network and submission failures are actionable.
- [ ] Captain cannot access counter-only administration or settlement controls.

### Counter Windows

- [ ] Application behaves as a Windows desktop app.
- [ ] Active orders and order details are easy to navigate.
- [ ] Bill totals and payment status are prominent.
- [ ] Duplicate payment/settlement is prevented.
- [ ] Important corrections are permission-controlled and auditable.
- [ ] Counter and kitchen printer settings are separate.
- [ ] Printer failures and reprints are clearly handled.
- [ ] Reports distinguish sales, collections, refunds, voids, and discounts as applicable.

### Hinopt Admin

- [ ] Restaurant and license statuses are searchable and clear.
- [ ] Renewal, suspension, and reactivation require appropriate authorization.
- [ ] High-impact actions are confirmed and audited.
- [ ] Offline installation limitations are explained accurately.
- [ ] Privileged credentials are never exposed in the browser or client code.

### Cross-application

- [ ] Visual tokens and components are consistent.
- [ ] Important status messages include text, not color alone.
- [ ] Keyboard, touch, and text scaling are tested on relevant platforms.
- [ ] Loading, empty, success, error, and offline states are designed.
- [ ] Interfaces are tested with realistic orders, printers, and network failures.

---

**Implementation note:** Treat this document as the UI/UX baseline. Before implementation, finalize the unresolved business rules—such as table/order lifecycle, payment methods, tax and discount behavior, cancellation approvals, supported printer models, and license grace policy—and reflect the decisions consistently across the screens.
