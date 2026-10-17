# Hinopt Restaurant POS — Shared API & Data Contracts

This document formalizes the API contract between **Agent 1** (Local Backend, PostgreSQL & Printing) and **Agent 2** (Captain Android, Counter Windows & Hinopt Admin).

---

## 1. Core Conventions

* **Base URL (Local API):** `http://<counter-pc-ip>:4000/api`
* **Financial Representation:** All monetary amounts are communicated as **integers in Paise** (₹ 1.00 = 100 paise) to prevent floating point inaccuracies.
* **Idempotency:** All mutating requests (`POST /orders`, `POST /orders/:id/kot`, `POST /orders/:id/bill`, `POST /bills/:id/payments`) support an `Idempotency-Key: <uuid>` header to prevent accidental duplicate actions from network retries.
* **Authentication Header:**
  * Captain: `Authorization: Bearer <device-token>`
  * Counter: `Authorization: Bearer <session-token>`
  * Device Header: `X-Device-Id: <uuid>`, `X-Device-Role: captain | counter`

---

## 2. Status Enums

### Table Status
* `AVAILABLE` — Free for seating
* `OCCUPIED` — Seated with active open order
* `BILLED` — Bill finalized, pending payment settlement
* `RESERVED` — Reserved

### Order Status
* `DRAFT` — Order started, items being added by Captain
* `IN_KITCHEN` — At least one KOT has been dispatched to kitchen
* `SERVED` — Food served to table
* `BILLED` — Bill locked and printed
* `COMPLETED` — Payment settled, table released
* `CANCELLED` — Order cancelled before preparation

### KOT Status
* `QUEUED` — Saved in DB, waiting for printer
* `PRINTING` — Dispatched to thermal printer
* `PRINTED` — Physical print confirmed
* `FAILED` — Printer disconnected or out of paper

### Payment Method
* `CASH` — Cash currency
* `UPI` — Direct UPI / QR Code scan
* `CARD` — POS Card terminal
* `SPLIT` — Multi-mode split payment

---

## 3. Endpoints Specification

### 3.1 Health & Connectivity
* `GET /api/health`
  * Response:
    ```json
    {
      "status": "healthy",
      "serverTime": "2026-10-17T14:00:00Z",
      "database": "connected",
      "printers": {
        "billPrinter": "connected",
        "kotPrinter": "connected"
      },
      "license": {
        "status": "active",
        "restaurantName": "Curry Leaf Fine Dine",
        "expiryDate": "2027-10-17T00:00:00Z",
        "daysRemaining": 365
      }
    }
    ```

### 3.2 Tables
* `GET /api/tables`
  * Returns array of tables with current status, occupied time, active order total, and seated guests.

### 3.3 Menu
* `GET /api/menu`
  * Returns categories and items (with id, name, pricePaise, categoryId, isVeg, isAvailable, variants, addons).

### 3.4 Orders & KOT
* `POST /api/orders`
  * Creates or retrieves active order for table.
* `POST /api/orders/:id/kot`
  * Dispatches items to kitchen.
  * Body: `{ "items": [ { "menuItemId": "...", "quantity": 2, "notes": "Less spicy" } ] }`
  * Creates KOT record, triggers Kitchen printer, snapshots item prices.
* `POST /api/orders/:id/cancel-item`
  * Body: `{ "orderItemId": "...", "reason": "...", "authorizedBy": "..." }`

### 3.5 Billing & Payments
* `POST /api/orders/:id/bill`
  * Finalizes bill, computes GST (5%) and discount, locks prices, triggers Counter Bill Printer.
* `POST /api/bills/:id/payments`
  * Body: `{ "method": "UPI", "amountPaise": 154000, "reference": "UPI12345" }`
  * Closes bill, marks table `AVAILABLE`.
* `POST /api/bills/:id/reprint`
  * Body: `{ "reason": "Customer duplicate receipt" }`
  * Sends print job with `*** REPRINT ***` watermark.

### 3.6 Printer Management
* `GET /api/printers` — List configured printers and their status.
* `POST /api/printers/test` — Trigger a test print receipt on Bill or KOT printer.
