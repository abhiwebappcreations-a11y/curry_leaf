# Hinopt Restaurant POS — Local Database Schema Specification

This document details the local PostgreSQL operational database architecture for the Hinopt Restaurant POS installation.

## Core Design Principles

1. **Strict Integer Paise Rule**:
   - All financial and monetary amounts (`price_paise`, `subtotal_paise`, `tax_paise`, `discount_paise`, `total_paise`, `amount_paise`) are stored as 64-bit/32-bit **INTEGERS in PAISE**.
   - Example: ₹250.00 is stored as `25000`. ₹1,499.50 is stored as `149950`.
   - Floating-point representations (`FLOAT`, `DOUBLE`, `REAL`) are strictly forbidden.

2. **Immutable Transaction Snapshots**:
   - Menu items and prices change over time. When an order item or bill is created, the system copies `name_snapshot`, `price_paise_snapshot`, and `tax_rate_snapshot`.
   - Modifying a menu item in settings will **never** alter historical bills or reporting records.

3. **Persist Before Print**:
   - Orders, KOTs, and bills must be committed to the database in a transaction before queuing physical print jobs.

4. **Durable Print Queue & Reprints**:
   - Physical printer jobs are persisted in the `print_jobs` table.
   - Ambiguous print results or retries do not duplicate orders or payments. Reprints are explicitly tracked with `is_reprint = true` and watermarked with `*** REPRINT ***`.

---

## Entity Relationship Overview

```text
restaurant_tables (1) <--- (M) orders (1) <--- (M) order_items
                                  |
                                  +--- (1) kots (1) <--- (M) order_items
                                  |
                                  +--- (1) bills (1) <--- (M) bill_items
                                             |
                                             +--- (M) payments
```

---

## State Transition Lifecycles

### 1. Restaurant Table Lifecycle
```text
[available]  ---> (Create Order) ---> [occupied]
     ^                                    |
     |                                    v
(Settle Payment) <--- [billed] <--- (Finalize Bill)
```

### 2. Order Item Lifecycle
```text
[draft]  ---> (Send to Kitchen) ---> [sent_to_kitchen] ---> [preparing] ---> [served]
   |                                       |
(Delete)                              (Auditable Cancel with Slip)
   |                                       |
   v                                       v
[deleted]                             [cancelled]
```

### 3. Order Lifecycle
```text
[active] ---> (KOT Sent) ---> [preparing] ---> (Bill Finalized) ---> [billed] ---> (Payment Settled) ---> [settled]
   |
   +---> (Order Cancelled) ---> [cancelled]
```

### 4. Bill Lifecycle
```text
[draft] ---> (Finalize Bill) ---> [finalized] ---> (Payment Settled) ---> [settled]
                                      |
                                      +---> (Void with Reason) ---> [voided]
```

---

## Table Definitions

### 1. `restaurant_tables`
| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | VARCHAR(50) | PRIMARY KEY | Table identifier (`tab_t1`) |
| `table_number` | VARCHAR(20) | UNIQUE, NOT NULL | Display code (`T1`, `P2`) |
| `display_name` | VARCHAR(50) | NOT NULL | Friendly label (`Table 1`) |
| `section` | VARCHAR(50) | NOT NULL | Floor / Section (`Main Dining`) |
| `capacity` | INTEGER | NOT NULL DEFAULT 4 | Seating capacity |
| `status` | VARCHAR(20) | CHECK enum | `available`, `occupied`, `billed`, `reserved`, `maintenance` |
| `active_order_id` | VARCHAR(50) | NULLABLE | Currently open order |
| `sort_order` | INTEGER | DEFAULT 0 | Layout order |

### 2. `menu_categories`
| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | VARCHAR(50) | PRIMARY KEY | Category ID (`cat_starters`) |
| `name` | VARCHAR(100) | NOT NULL | Category name |
| `sort_order` | INTEGER | DEFAULT 0 | Display sequence |
| `is_active` | BOOLEAN | DEFAULT TRUE | Visibility toggle |

### 3. `menu_items`
| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | VARCHAR(50) | PRIMARY KEY | Item ID (`item_paneer_65`) |
| `category_id` | VARCHAR(50) | REFERENCES `menu_categories` | Foreign key |
| `name` | VARCHAR(150) | NOT NULL | Dish name |
| `short_code` | VARCHAR(20) | NULLABLE | Quick code (`P65`) |
| `price_paise` | INTEGER | CHECK (>= 0) | Base price in paise (`24000` = ₹240.00) |
| `tax_rate_percent` | NUMERIC(5,2)| DEFAULT 5.00 | GST percentage |
| `is_available` | BOOLEAN | DEFAULT TRUE | 86 / In stock status |
| `is_veg` | BOOLEAN | DEFAULT TRUE | Dietary indicator |
| `variants` | JSONB | NOT NULL DEFAULT '[]' | Size variations (`half`, `full`) |
| `add_ons` | JSONB | NOT NULL DEFAULT '[]' | Extra sides/options |

### 4. `orders`
| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | VARCHAR(50) | PRIMARY KEY | Order ID (`ord_...`) |
| `order_number` | VARCHAR(30) | UNIQUE, NOT NULL | Display number (`ORD-261017-1001`) |
| `table_id` | VARCHAR(50) | REFERENCES `restaurant_tables` | Assigned table |
| `captain_device_id` | VARCHAR(50) | REFERENCES `devices` | Waiter tablet |
| `status` | VARCHAR(20) | CHECK enum | `draft`, `active`, `preparing`, `ready`, `billed`, `settled`, `cancelled` |
| `subtotal_paise` | INTEGER | DEFAULT 0 | Pre-tax sum in paise |
| `tax_paise` | INTEGER | DEFAULT 0 | Calculated tax in paise |
| `discount_paise` | INTEGER | DEFAULT 0 | Applied discount in paise |
| `total_paise` | INTEGER | DEFAULT 0 | Net payable in paise |

### 5. `order_items`
| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | VARCHAR(50) | PRIMARY KEY | Item row ID |
| `order_id` | VARCHAR(50) | REFERENCES `orders` ON DELETE CASCADE | Parent order |
| `menu_item_id` | VARCHAR(50) | REFERENCES `menu_items` | Original menu item |
| `name_snapshot` | VARCHAR(150) | NOT NULL | Immutably captured dish name |
| `price_paise_snapshot` | INTEGER | NOT NULL | Immutably captured unit price in paise |
| `quantity` | INTEGER | CHECK (> 0) | Order count |
| `status` | VARCHAR(25) | CHECK enum | `draft`, `sent_to_kitchen`, `preparing`, `served`, `cancelled` |
| `kot_id` | VARCHAR(50) | REFERENCES `kots` | Associated kitchen ticket |
| `cancellation_reason` | TEXT | NULLABLE | Reason if cancelled |

### 6. `kots`
| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | VARCHAR(50) | PRIMARY KEY | KOT ID (`kot_...`) |
| `kot_number` | VARCHAR(30) | UNIQUE, NOT NULL | Display code (`KOT-261017-2001`) |
| `order_id` | VARCHAR(50) | REFERENCES `orders` | Linked order |
| `status` | VARCHAR(20) | CHECK enum | `queued`, `printing`, `printed`, `failed`, `cancelled` |
| `print_count` | INTEGER | DEFAULT 0 | Ticket printing count |

### 7. `bills` & `bill_items`
- `bills`: Snapshots the final payment request with `bill_number` (`BILL-261017-3001`), `subtotal_paise`, `tax_paise`, `discount_paise`, and `total_paise`.
- `bill_items`: Immutable line items with unit price and tax snapshots.

### 8. `payments`
| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | VARCHAR(50) | PRIMARY KEY | Payment ID |
| `bill_id` | VARCHAR(50) | REFERENCES `bills` | Settled bill |
| `amount_paise` | INTEGER | CHECK (> 0) | Amount paid in paise |
| `payment_method` | VARCHAR(20) | CHECK enum | `cash`, `upi`, `card`, `split`, `other` |
| `idempotency_key` | VARCHAR(100)| UNIQUE, NOT NULL | Prevents duplicate settlements |
| `status` | VARCHAR(20) | CHECK enum | `completed`, `pending`, `failed`, `refunded` |

### 9. `print_jobs`
- Durable queue targeting `counter_bill` or `kitchen_kot`. Supports status tracking (`queued`, `processing`, `completed`, `failed`), retry counting, and reprint watermarking.

### 10. `audit_logs`
- Traceable audit record for every consequential operational action: cancellations, bill voids, payment settlements, reprints, and license updates.
