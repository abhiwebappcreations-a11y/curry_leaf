# Hinopt Restaurant POS — Local API Contract & Documentation

This document defines the REST API contract exposed by the local Node.js + TypeScript service running on the Windows Counter PC.

> **Base URL:** `http://<COUNTER_PC_LAN_IP>:4000`  
> **Currency Rule:** All monetary amounts are strictly integers in **PAISE** (₹1.00 = 100 paise).  
> **Network Scope:** Local restaurant Wi-Fi/LAN. Requires no internet connection for operational endpoints.

---

## 1. Authentication & Device Authorization

Every request from Captain Android tablets or Counter desktop clients must authenticate using:
- Header `Authorization: Bearer <JWT_TOKEN>` (obtained via `POST /api/auth/token`), OR
- Headers `X-Device-Id: <DEVICE_ID>` and `X-Api-Key: <DEVICE_API_KEY>`

### Roles & Access Matrix

| Endpoint Group | Captain Role | Counter Role | Admin Role |
|---|---|---|---|
| Health (`/api/health`) | Read | Read | Read |
| Tables (`/api/tables`) | Read | Read / Status Update | Read / Full Update |
| Menu (`/api/menu`) | Read | Read / 86 Availability Toggle | Read / Write |
| Orders (`/api/orders`) | Create / Append / KOT | Full Management | Full Management |
| Item Cancellation | No (Request only) | Approve & Cancel | Approve & Cancel |
| Billing (`/api/billing`) | No | Finalize / Reprint / Void | Full Management |
| Payments (`/api/bills/:id/payments`) | No | Settle (Idempotent) | Settle (Idempotent) |
| Printers (`/api/printers`) | No | Test / Queue / Retry | Full Management |
| License (`/api/license`) | Status | Status | Status / Apply Signature |
| Reports (`/api/reports`) | No | Daily Sales Summary | Full Financial Audit |

---

## 2. API Response Formats

### Standard Success Response
```json
{
  "success": true,
  "data": { ... }
}
```

### Standard Error Response
```json
{
  "success": false,
  "error": {
    "code": "STRING_ERROR_CODE",
    "message": "Human readable explanation",
    "details": {}
  }
}
```

Common Error Codes:
- `UNAUTHORIZED` (401): Missing or invalid device token.
- `FORBIDDEN` (403): Role not permitted for this action (e.g., Captain attempting to settle a bill).
- `NOT_FOUND` (404): Resource ID does not exist.
- `BAD_REQUEST` (400): Schema validation failure or invalid state transition.
- `TABLE_ALREADY_OCCUPIED` (409): Table already has an open active order.
- `ORDER_ALREADY_BILLED` (400): Cannot modify order after bill is generated.
- `ORDER_ALREADY_SETTLED` (409): Order already closed.
- `BILL_ALREADY_SETTLED` (409): Bill is already paid in full.

---

## 3. Endpoints Specification

### 3.1 Health Check
- **`GET /api/health`**
  - **Auth:** None (Public LAN)
  - **Response:**
    ```json
    {
      "success": true,
      "data": {
        "status": "healthy",
        "service": "hinopt-local-api",
        "version": "1.0.0",
        "uptimeSeconds": 1420,
        "restaurant": {
          "id": "rest_curry_leaf_01",
          "name": "Curry Leaf Fine Dining"
        },
        "components": {
          "apiServer": { "status": "online", "port": 4000 },
          "database": { "type": "postgresql", "status": "connected" },
          "printers": {
            "counterBill": { "target": "192.168.1.200:9100", "configured": true },
            "kitchenKot": { "target": "192.168.1.201:9100", "configured": true },
            "queue": { "pendingJobs": 0, "failedJobs": 0 }
          },
          "license": {
            "isValid": true,
            "status": "active",
            "daysRemaining": 335,
            "isOfflineGraceActive": false
          }
        }
      }
    }
    ```

---

### 3.2 Authentication (`/api/auth`)
- **`POST /api/auth/token`**
  - Exchange registered device credentials for JWT.
  - **Body:** `{ "deviceId": "dev_captain_01", "apiKey": "captain_dev_token_01" }`
  - **Response:** `{ "token": "jwt...", "device": { "id": "...", "name": "...", "role": "captain" } }`

- **`GET /api/auth/me`**
  - Verify device identity and role.

---

### 3.3 Tables (`/api/tables`)
- **`GET /api/tables`**
  - Returns list of tables with capacity, section, and live active order total.
  - **Response:**
    ```json
    {
      "success": true,
      "data": {
        "tables": [
          {
            "id": "tab_t1",
            "tableNumber": "T1",
            "displayName": "Table 1",
            "section": "Main Dining",
            "capacity": 4,
            "status": "available",
            "activeOrder": null
          }
        ]
      }
    }
    ```

- **`PATCH /api/tables/:id/status`**
  - Update table state (`available`, `occupied`, `billed`, `reserved`, `maintenance`).

---

### 3.4 Menu (`/api/menu`)
- **`GET /api/menu`**
  - Returns hierarchical category tree with items, variants, and addons. Prices in paise.
  - **Example Item:**
    ```json
    {
      "id": "item_paneer_65",
      "categoryId": "cat_starters",
      "name": "Curry Leaf Paneer 65",
      "shortCode": "P65",
      "pricePaise": 24000,
      "taxRatePercent": 5.0,
      "isAvailable": true,
      "isVeg": true,
      "variants": [
        { "id": "half", "name": "Half", "pricePaise": 14000 },
        { "id": "full", "name": "Full", "pricePaise": 24000 }
      ],
      "addOns": [
        { "id": "extra_chilli_dip", "name": "Extra Chilli Dip", "pricePaise": 3000 }
      ]
    }
    ```

- **`PATCH /api/menu/items/:id/availability`**
  - Toggle item availability (`isAvailable: false` marks item 86 / Out of Stock).

---

### 3.5 Orders (`/api/orders`)
- **`POST /api/orders`**
  - Create a new order for a table.
  - **Body:**
    ```json
    {
      "tableId": "tab_t1",
      "customerNotes": "No spicy",
      "guestCount": 2,
      "items": [
        {
          "menuItemId": "item_paneer_65",
          "quantity": 1,
          "itemNotes": "Crispy",
          "selectedVariants": [{ "id": "full", "name": "Full", "pricePaise": 24000 }]
        }
      ]
    }
    ```

- **`POST /api/orders/:id/items`**
  - Append new items to an active order.

- **`PATCH /api/orders/:id/items/:itemId`**
  - Modify quantity or notes for items still in `draft` status. (Setting quantity `0` deletes draft).

- **`POST /api/orders/:id/kot`**
  - **Send to Kitchen Action.**
  - Converts all `draft` items to `sent_to_kitchen`.
  - Creates a KOT ticket (`KOT-YYMMDD-XXXX`).
  - Persists database records, then enqueues print job to the Kitchen Thermal Printer.

- **`POST /api/orders/:id/items/:itemId/cancel`**
  - **Auditable cancellation workflow.**
  - Items already sent to kitchen cannot be silently removed.
  - Collects reason, marks item `cancelled`, adjusts order total, logs audit record, and prints cancellation slip in kitchen.

---

### 3.6 Billing & Settlement (`/api/billing`)
- **`POST /api/billing/orders/:id/bill`**
  - Finalizes bill.
  - Snapshots line item names and unit prices immutably into `bill_items`.
  - Calculates subtotal, tax (5%), discount, total in integer paise.
  - Dispatches print job to Counter Bill Printer.
  - Sets table and order status to `billed`.

- **`POST /api/billing/bills/:id/payments`**
  - **Idempotent settlement.**
  - **Body:**
    ```json
    {
      "amountPaise": 28350,
      "paymentMethod": "upi",
      "idempotencyKey": "unique-client-guid-or-uuid",
      "referenceNumber": "UPI/12345678",
      "notes": "Paid by QR"
    }
    ```
  - Records payment, marks bill and order as `settled`.
  - **Frees table:** sets table status to `available` and clears `activeOrderId`.

- **`POST /api/billing/bills/:id/reprint`**
  - Dispatches reprint to Counter Bill Printer clearly watermarked with `*** REPRINT ***`.
  - Increments bill `printCount`.
  - Logs audit record.

- **`POST /api/billing/bills/:id/void`**
  - Voids a finalized bill with reason. Reopens order for correction.

---

### 3.7 Printing (`/api/printers`)
- **`GET /api/printers`**
  - Lists configured Counter Bill & Kitchen KOT printers.
- **`POST /api/printers/test-print`**
  - Triggers test slip on selected printer.
- **`GET /api/printers/jobs`**
  - Inspects durable print queue status.
- **`POST /api/printers/jobs/:id/retry`**
  - Retries a failed thermal print job.

---

### 3.8 Licensing (`/api/license`)
- **`GET /api/license/status`**
  - Inspects active license state, expiry date, days remaining, and offline grace status.
- **`POST /api/license/verify`**
  - Accepts base64 signed payload and cryptographic signature from Hinopt Cloud, verifies signature with public key, and refreshes local license cache.
