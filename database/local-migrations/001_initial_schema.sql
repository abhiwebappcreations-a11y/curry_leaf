-- ==============================================================================
-- Hinopt Restaurant POS - Local PostgreSQL Initial Database Schema (001)
-- All monetary amounts stored as INTEGER PAISE (100 paise = 1 INR)
-- ==============================================================================

-- Enable UUID extension if available
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ------------------------------------------------------------------------------
-- 1. Restaurant Settings & Configuration
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS settings (
    key VARCHAR(100) PRIMARY KEY,
    value JSONB NOT NULL,
    description TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------------------------
-- 2. Registered Devices & Permissions (LAN Authentication)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS devices (
    id VARCHAR(50) PRIMARY KEY, -- e.g. dev_captain_01, dev_counter_01
    device_name VARCHAR(100) NOT NULL,
    role VARCHAR(20) NOT NULL CHECK (role IN ('captain', 'counter', 'admin')),
    device_fingerprint VARCHAR(255) NOT NULL UNIQUE,
    api_key_hash VARCHAR(255) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    last_seen_at TIMESTAMPTZ,
    registered_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------------------------
-- 3. Restaurant Tables
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS restaurant_tables (
    id VARCHAR(50) PRIMARY KEY,
    table_number VARCHAR(20) NOT NULL UNIQUE,
    display_name VARCHAR(50) NOT NULL,
    section VARCHAR(50) NOT NULL DEFAULT 'Main Dining',
    capacity INTEGER NOT NULL DEFAULT 4,
    status VARCHAR(20) NOT NULL DEFAULT 'available' CHECK (status IN ('available', 'occupied', 'billed', 'reserved', 'maintenance')),
    active_order_id VARCHAR(50),
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------------------------
-- 4. Menu Categories
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS menu_categories (
    id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------------------------
-- 5. Menu Items (with Variants & Add-ons)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS menu_items (
    id VARCHAR(50) PRIMARY KEY,
    category_id VARCHAR(50) NOT NULL REFERENCES menu_categories(id) ON DELETE RESTRICT,
    name VARCHAR(150) NOT NULL,
    short_code VARCHAR(20),
    description TEXT,
    price_paise INTEGER NOT NULL CHECK (price_paise >= 0), -- e.g. 25000 = ₹250.00
    tax_rate_percent NUMERIC(5, 2) NOT NULL DEFAULT 5.00, -- e.g. 5.00% GST
    is_available BOOLEAN NOT NULL DEFAULT TRUE,
    is_veg BOOLEAN NOT NULL DEFAULT TRUE,
    variants JSONB NOT NULL DEFAULT '[]'::jsonb, -- e.g. [{"id": "half", "name": "Half", "price_paise": 14000}]
    add_ons JSONB NOT NULL DEFAULT '[]'::jsonb,  -- e.g. [{"id": "extra_cheese", "name": "Extra Cheese", "price_paise": 4000}]
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_menu_items_category ON menu_items(category_id);
CREATE INDEX IF NOT EXISTS idx_menu_items_available ON menu_items(is_available);

-- ------------------------------------------------------------------------------
-- 6. Orders
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS orders (
    id VARCHAR(50) PRIMARY KEY,
    order_number VARCHAR(30) NOT NULL UNIQUE,
    table_id VARCHAR(50) NOT NULL REFERENCES restaurant_tables(id) ON DELETE RESTRICT,
    captain_device_id VARCHAR(50) REFERENCES devices(id) ON DELETE SET NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('draft', 'active', 'preparing', 'ready', 'billed', 'settled', 'cancelled')),
    customer_notes TEXT,
    guest_count INTEGER DEFAULT 1,
    subtotal_paise INTEGER NOT NULL DEFAULT 0 CHECK (subtotal_paise >= 0),
    tax_paise INTEGER NOT NULL DEFAULT 0 CHECK (tax_paise >= 0),
    discount_paise INTEGER NOT NULL DEFAULT 0 CHECK (discount_paise >= 0),
    total_paise INTEGER NOT NULL DEFAULT 0 CHECK (total_paise >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_orders_table ON orders(table_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_created ON orders(created_at);

-- ------------------------------------------------------------------------------
-- 7. KOTs (Kitchen Order Tickets)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS kots (
    id VARCHAR(50) PRIMARY KEY,
    kot_number VARCHAR(30) NOT NULL UNIQUE,
    order_id VARCHAR(50) NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    table_id VARCHAR(50) NOT NULL REFERENCES restaurant_tables(id) ON DELETE RESTRICT,
    status VARCHAR(20) NOT NULL DEFAULT 'queued' CHECK (status IN ('queued', 'printing', 'printed', 'failed', 'cancelled')),
    print_count INTEGER NOT NULL DEFAULT 0,
    printed_at TIMESTAMPTZ,
    cancellation_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_kots_order ON kots(order_id);
CREATE INDEX IF NOT EXISTS idx_kots_status ON kots(status);

-- ------------------------------------------------------------------------------
-- 8. Order Items (Snapshotting name & price; draft vs submitted)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS order_items (
    id VARCHAR(50) PRIMARY KEY,
    order_id VARCHAR(50) NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    menu_item_id VARCHAR(50) NOT NULL REFERENCES menu_items(id) ON DELETE RESTRICT,
    name_snapshot VARCHAR(150) NOT NULL,
    price_paise_snapshot INTEGER NOT NULL CHECK (price_paise_snapshot >= 0),
    tax_rate_snapshot NUMERIC(5, 2) NOT NULL DEFAULT 5.00,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    item_notes TEXT,
    selected_variants JSONB NOT NULL DEFAULT '[]'::jsonb,
    selected_addons JSONB NOT NULL DEFAULT '[]'::jsonb,
    status VARCHAR(25) NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'sent_to_kitchen', 'preparing', 'served', 'cancelled')),
    kot_id VARCHAR(50) REFERENCES kots(id) ON DELETE SET NULL,
    cancellation_reason TEXT,
    cancelled_by_device_id VARCHAR(50) REFERENCES devices(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_kot ON order_items(kot_id);
CREATE INDEX IF NOT EXISTS idx_order_items_status ON order_items(status);

-- ------------------------------------------------------------------------------
-- 9. Bills (Finalized snapshots of billing)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bills (
    id VARCHAR(50) PRIMARY KEY,
    bill_number VARCHAR(30) NOT NULL UNIQUE,
    order_id VARCHAR(50) NOT NULL REFERENCES orders(id) ON DELETE RESTRICT,
    table_id VARCHAR(50) NOT NULL REFERENCES restaurant_tables(id) ON DELETE RESTRICT,
    subtotal_paise INTEGER NOT NULL CHECK (subtotal_paise >= 0),
    tax_paise INTEGER NOT NULL CHECK (tax_paise >= 0),
    discount_paise INTEGER NOT NULL DEFAULT 0 CHECK (discount_paise >= 0),
    total_paise INTEGER NOT NULL CHECK (total_paise >= 0),
    status VARCHAR(20) NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'finalized', 'settled', 'voided')),
    print_status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (print_status IN ('pending', 'printed', 'failed')),
    print_count INTEGER NOT NULL DEFAULT 0,
    void_reason TEXT,
    created_by_device_id VARCHAR(50) REFERENCES devices(id) ON DELETE SET NULL,
    finalized_at TIMESTAMPTZ,
    settled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_bills_order ON bills(order_id);
CREATE INDEX IF NOT EXISTS idx_bills_status ON bills(status);
CREATE INDEX IF NOT EXISTS idx_bills_created ON bills(created_at);

-- ------------------------------------------------------------------------------
-- 10. Bill Line Items (Immutable transaction snapshots)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bill_items (
    id VARCHAR(50) PRIMARY KEY,
    bill_id VARCHAR(50) NOT NULL REFERENCES bills(id) ON DELETE CASCADE,
    menu_item_id VARCHAR(50) NOT NULL,
    name_snapshot VARCHAR(150) NOT NULL,
    unit_price_paise INTEGER NOT NULL CHECK (unit_price_paise >= 0),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    total_paise INTEGER NOT NULL CHECK (total_paise >= 0),
    tax_paise INTEGER NOT NULL DEFAULT 0 CHECK (tax_paise >= 0),
    options_snapshot JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_bill_items_bill ON bill_items(bill_id);

-- ------------------------------------------------------------------------------
-- 11. Payments (Idempotent settlement records)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS payments (
    id VARCHAR(50) PRIMARY KEY,
    bill_id VARCHAR(50) NOT NULL REFERENCES bills(id) ON DELETE RESTRICT,
    amount_paise INTEGER NOT NULL CHECK (amount_paise > 0),
    payment_method VARCHAR(20) NOT NULL CHECK (payment_method IN ('cash', 'upi', 'card', 'split', 'other')),
    reference_number VARCHAR(100),
    status VARCHAR(20) NOT NULL DEFAULT 'completed' CHECK (status IN ('pending', 'completed', 'failed', 'refunded')),
    idempotency_key VARCHAR(100) NOT NULL UNIQUE,
    settled_by_device_id VARCHAR(50) REFERENCES devices(id) ON DELETE SET NULL,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_payments_bill ON payments(bill_id);
CREATE INDEX IF NOT EXISTS idx_payments_idempotency ON payments(idempotency_key);
CREATE INDEX IF NOT EXISTS idx_payments_created ON payments(created_at);

-- ------------------------------------------------------------------------------
-- 12. Local Print Service Durable Queue
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS print_jobs (
    id VARCHAR(50) PRIMARY KEY,
    target_printer VARCHAR(20) NOT NULL CHECK (target_printer IN ('counter_bill', 'kitchen_kot')),
    job_type VARCHAR(20) NOT NULL CHECK (job_type IN ('bill', 'kot', 'reprint_bill', 'reprint_kot', 'test_print', 'report')),
    reference_id VARCHAR(50), -- bill_id or kot_id
    payload JSONB NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'queued' CHECK (status IN ('queued', 'processing', 'completed', 'failed')),
    retry_count INTEGER NOT NULL DEFAULT 0,
    max_retries INTEGER NOT NULL DEFAULT 3,
    error_message TEXT,
    is_reprint BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_print_jobs_status ON print_jobs(status);
CREATE INDEX IF NOT EXISTS idx_print_jobs_target ON print_jobs(target_printer, status);

-- ------------------------------------------------------------------------------
-- 13. Audit Log (Financial & Operational accountability)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS audit_logs (
    id VARCHAR(50) PRIMARY KEY,
    event_type VARCHAR(50) NOT NULL, -- e.g. 'order_cancelled', 'bill_voided', 'kot_reprinted', 'license_updated'
    entity_type VARCHAR(50) NOT NULL, -- e.g. 'order', 'bill', 'payment', 'kot', 'license'
    entity_id VARCHAR(50) NOT NULL,
    actor_device_id VARCHAR(50) REFERENCES devices(id) ON DELETE SET NULL,
    reason TEXT,
    details JSONB NOT NULL DEFAULT '{}'::jsonb,
    ip_address VARCHAR(45),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_event ON audit_logs(event_type);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON audit_logs(created_at);

-- ------------------------------------------------------------------------------
-- 14. License Cache (Locally verified Hinopt Cloud License)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS license_cache (
    id VARCHAR(50) PRIMARY KEY DEFAULT 'current_license',
    restaurant_id VARCHAR(50) NOT NULL,
    restaurant_name VARCHAR(150) NOT NULL,
    license_key VARCHAR(100) NOT NULL,
    status VARCHAR(20) NOT NULL CHECK (status IN ('active', 'grace', 'expired', 'suspended')),
    valid_from TIMESTAMPTZ NOT NULL,
    valid_until TIMESTAMPTZ NOT NULL,
    last_verified_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    signature TEXT NOT NULL,
    signed_payload JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
