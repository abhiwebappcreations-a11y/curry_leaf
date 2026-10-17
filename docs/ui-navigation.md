# Hinopt Restaurant POS — UI Navigation & Architecture Map

## Overview
This document specifies the navigation flow, routing structure, state management, and shared interaction patterns across all three user interfaces developed by **Agent 2**:

1. **Captain Android App** (`apps/captain_android`): Mobile handheld experience for waiters/captains.
2. **Counter Windows App** (`apps/counter_windows`): Desktop touch/mouse POS terminal for cashiers.
3. **Hinopt Admin Dashboard** (`apps/hinopt_admin`): Cloud web dashboard for Hinopt operators and license management.

---

## 1. Design System & Shared Tokens

### 1.1 Color Palette
* **Primary (Deep Pine):** `#163B3A`
* **Primary Container / Dark:** `#0E2726`
* **Accent (Vibrant Mint):** `#4CC9B0`
* **App Background:** `#F5F7F7`
* **Surface (Card/Dialog):** `#FFFFFF`
* **Surface Elevated:** `#FAFCFC`
* **Main Text:** `#172322`
* **Secondary Text:** `#657371`
* **Border & Dividers:** `#DCE5E3`
* **Status Badges & Semantics:**
  * **Success / Ready / Available:** `#218653` (BG: `#E8F5EE`)
  * **Warning / Preparing / Pending:** `#A96508` (BG: `#FEF7EC`)
  * **Error / Cancelled / Voided:** `#B42318` (BG: `#FEECEB`)
  * **Info / Occupied / Active:** `#245DB5` (BG: `#EBF2FC`)

### 1.2 Typography & Spacing
* Font Family: **Inter** / Clean Modern Sans-Serif
* Tabular figures for all financial amounts (INR ₹ / paise display)
* Spacing Grid: 4px baseline (`xs: 4px`, `sm: 8px`, `md: 16px`, `lg: 24px`, `xl: 32px`)
* Corner Radii: 8px (small), 12px (cards/dialogs), 24px (pills)

---

## 2. Captain Android App Navigation

### 2.1 Route Map
```
[App Entry]
   │
   ├── /connection-setup (Set Counter PC Local IP / Port, Device Registration)
   │
   └── /tables (Primary Landing Screen)
         ├── [Filter: All, Ground Floor, AC Section, Rooftop, Takeaway]
         ├── [Table Card Tap] ───────────────┐
         │                                   ▼
         │                            /order/:tableId
         │                               ├── Left/Top: Active Table & Order Summary
         │                               ├── Center: Menu Browser (Categories, Search, Item Grid)
         │                               ├── Item Tap: Variant / Addon / Note Modal
         │                               └── Right/Bottom Drawer: Draft Cart Sheet
         │                                     ├── Draft Items (editable / removable)
         │                                     ├── Previously Sent Items (immutable snapshot with status)
         │                                     └── [Action: "Send to Kitchen" (KOT)]
         │                                           ▼
         │                                     (Queues KOT to Local API -> prints ticket)
         │
         ├── /order/:tableId/history (KOT History & Item status)
         └── /connection-status (Network diagnostics, Local Server latency, Cloud status)
```

### 2.2 Security & Guardrails
* Captain app CANNOT access bill settlement, discounts over limit, voiding, or system configuration.
* Items already sent to kitchen cannot be deleted without an auditable cancellation request.
* Double-tap debounce on `Send to Kitchen` with immediate optimistic visual pending state.

---

## 3. Counter Windows App Navigation

### 3.1 Layout Shell
* **Persistent Left Sidebar:**
  * `Active Orders` (Badge with count of active orders)
  * `Tables View` (Floor plan / grid)
  * `Billing & Settlement` (Active bill editor & cashier till)
  * `Menu Management` (Categories, Items, Addons, Out-of-Stock toggles)
  * `Reports & Day End` (Sales breakdown, payment modes, Z-report)
  * `Settings & Printers` (Independent Bill vs KOT thermal printer config, network IP, license)
* **Header Bar:**
  * Local Server Health indicator (🟢 Online | 🔴 Offline)
  * Cloud Verification status (🟢 Verified | 🟡 Offline Grace | 🔴 Expired)
  * Bill Printer status (🟢 Ready | 🔴 Error)
  * KOT Printer status (🟢 Ready | 🔴 Error)
  * Current Cashier Shift & Clock
* **Context Workspace:** Dynamic multi-column layout for fast counter operations.

### 3.2 Order & Billing Flow
1. **Order Selection:** Click active order or occupied table.
2. **Review:** Shows line items, item prices (snapshotted), subtotal, GST (5%), discount options.
3. **Bill Generation:** Action `Finalize Bill` -> commits bill in local database -> queues bill print.
4. **Settlement:** Select Payment Method (Cash, UPI/QR, Card, Split) -> Enter amount tendered -> Action `Settle Payment` -> Prints receipt & marks table available.
5. **Reprint:** Controlled reprint action with explicit `*** REPRINT ***` header to prevent fraud.

---

## 4. Hinopt Admin Cloud Dashboard Navigation

### 4.1 Route Map
```
[Hinopt Admin Auth (Supabase Auth)]
   │
   ├── /dashboard (Overview metrics: Total Restaurants, Active Licenses, Expiring in 30d, Suspended)
   │
   ├── /restaurants (Directory of registered restaurant clients)
   │     ├── [New Restaurant Registration]
   │     └── [Restaurant Detail: Profile, Contacts, Installation HW ID]
   │
   ├── /licenses (License issuance, verification tokens, Ed25519 signatures)
   │     ├── [Issue New License]
   │     ├── [Renew 1 Year]
   │     ├── [Suspend / Reactivate]
   │     └── [Download Signed License Payload (`license.json`)]
   │
   ├── /audit-logs (Immutable log of all license events, renewals, and admin actions)
   └── /admin-settings (Key pair status, Supabase cloud configuration)
```
