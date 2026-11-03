-- ==============================================================================
-- Hinopt POS — Central Cloud Supabase Schema (Up to Date)
-- Execute this script in your Supabase SQL Editor:
-- https://supabase.com/dashboard/project/ybalhfhqaduqsbjotbni/sql
-- ==============================================================================

-- 1. Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Restaurants Table
CREATE TABLE IF NOT EXISTS restaurants (
    id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    city VARCHAR(100),
    contact_name VARCHAR(100),
    phone VARCHAR(20),
    hwid VARCHAR(150),
    counter_ip VARCHAR(50) DEFAULT '192.168.1.100',
    status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'EXPIRING', 'EXPIRED', 'SUSPENDED')),
    license_key VARCHAR(100),
    valid_until TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 3. Licenses Table (Cryptographically Signed Tokens)
CREATE TABLE IF NOT EXISTS licenses (
    id VARCHAR(50) PRIMARY KEY,
    restaurant_id VARCHAR(50) REFERENCES restaurants(id) ON DELETE CASCADE,
    restaurant_name VARCHAR(150) NOT NULL,
    license_key VARCHAR(100) NOT NULL UNIQUE,
    status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'GRACE', 'EXPIRED', 'SUSPENDED')),
    valid_from TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    valid_until TIMESTAMPTZ NOT NULL,
    max_devices INTEGER NOT NULL DEFAULT 10,
    hwid VARCHAR(150),
    signed_token TEXT,
    signature TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 4. Audit Logs (Immutable Security Log)
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    action VARCHAR(100) NOT NULL,
    actor VARCHAR(100) NOT NULL DEFAULT 'admin',
    details JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 5. Cloud Backups Table (Tracks AES-256-GCM Google Drive Snapshots)
CREATE TABLE IF NOT EXISTS cloud_backups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    restaurant_id VARCHAR(50) NOT NULL,
    restaurant_name VARCHAR(150) NOT NULL,
    file_name VARCHAR(150) NOT NULL,
    size_bytes BIGINT NOT NULL,
    encryption_cipher VARCHAR(50) DEFAULT 'AES-256-GCM',
    drive_file_id VARCHAR(255),
    drive_link TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 6. Revoked HWIDs Table (Prevents fake 'Burnt PC' hardware duplication)
CREATE TABLE IF NOT EXISTS revoked_hwids (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    hwid VARCHAR(150) NOT NULL,
    license_key VARCHAR(100),
    reason TEXT,
    transferred_to_hwid VARCHAR(150),
    revoked_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 7. License Upgrade Requests Table (Syncs upgrade requests from POS clients to Cloud Admin)
CREATE TABLE IF NOT EXISTS upgrade_requests (
    id VARCHAR(100) PRIMARY KEY,
    restaurant_id VARCHAR(50),
    restaurant_name VARCHAR(150) NOT NULL,
    license_key VARCHAR(100),
    current_limits JSONB DEFAULT '{}'::jsonb,
    requested_limits JSONB DEFAULT '{}'::jsonb,
    contact_phone VARCHAR(50),
    notes TEXT,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 8. Online Orders Queue Table (Syncs Customer Web Orders to Local Counter POS)
CREATE TABLE IF NOT EXISTS online_orders (
    id VARCHAR(100) PRIMARY KEY,
    restaurant_id VARCHAR(50) NOT NULL REFERENCES restaurants(id) ON DELETE CASCADE,
    order_number VARCHAR(100) NOT NULL,
    customer_name VARCHAR(150) NOT NULL,
    customer_phone VARCHAR(20) NOT NULL,
    delivery_address TEXT NOT NULL,
    delivery_coordinates JSONB,
    customer_notes TEXT,
    items JSONB NOT NULL,
    subtotal_paise INTEGER NOT NULL,
    tax_paise INTEGER NOT NULL DEFAULT 0,
    total_paise INTEGER NOT NULL,
    status VARCHAR(30) DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'preparing', 'out_for_delivery', 'delivered', 'cancelled')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Alter restaurants to add online delivery attributes if missing
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='restaurants' AND column_name='store_slug') THEN
        ALTER TABLE restaurants ADD COLUMN store_slug VARCHAR(100) UNIQUE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='restaurants' AND column_name='custom_domain') THEN
        ALTER TABLE restaurants ADD COLUMN custom_domain VARCHAR(150);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='restaurants' AND column_name='online_ordering_enabled') THEN
        ALTER TABLE restaurants ADD COLUMN online_ordering_enabled BOOLEAN DEFAULT FALSE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='restaurants' AND column_name='online_menu') THEN
        ALTER TABLE restaurants ADD COLUMN online_menu JSONB DEFAULT '[]'::jsonb;
    END IF;
END $$;

-- Enable RLS and Permissive Policies for Hinopt Admin Service Role
ALTER TABLE restaurants ENABLE ROW LEVEL SECURITY;
ALTER TABLE licenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE cloud_backups ENABLE ROW LEVEL SECURITY;
ALTER TABLE revoked_hwids ENABLE ROW LEVEL SECURITY;
ALTER TABLE upgrade_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE online_orders ENABLE ROW LEVEL SECURITY;

-- Allow full access with service_role / apikey
DROP POLICY IF EXISTS "Allow full access for service role" ON restaurants;
CREATE POLICY "Allow full access for service role" ON restaurants FOR ALL USING (true);

DROP POLICY IF EXISTS "Allow full access for service role" ON licenses;
CREATE POLICY "Allow full access for service role" ON licenses FOR ALL USING (true);

DROP POLICY IF EXISTS "Allow full access for service role" ON audit_logs;
CREATE POLICY "Allow full access for service role" ON audit_logs FOR ALL USING (true);

DROP POLICY IF EXISTS "Allow full access for service role" ON cloud_backups;
CREATE POLICY "Allow full access for service role" ON cloud_backups FOR ALL USING (true);

DROP POLICY IF EXISTS "Allow full access for service role" ON revoked_hwids;
CREATE POLICY "Allow full access for service role" ON revoked_hwids FOR ALL USING (true);

DROP POLICY IF EXISTS "Allow full access for service role" ON upgrade_requests;
CREATE POLICY "Allow full access for service role" ON upgrade_requests FOR ALL USING (true);

DROP POLICY IF EXISTS "Allow full access for service role" ON online_orders;
CREATE POLICY "Allow full access for service role" ON online_orders FOR ALL USING (true);
