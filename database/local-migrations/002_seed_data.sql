-- ==============================================================================
-- Hinopt Restaurant POS - Development Seed Data (002)
-- Realistic Restaurant Data for Tables, Menu, Categories, Devices & Settings
-- Money in Integer Paise (e.g., ₹250.00 = 25000 paise)
-- ==============================================================================

-- 1. Initial Settings
INSERT INTO settings (key, value, description) VALUES
('restaurant_profile', '{
    "restaurant_id": "rest_curry_leaf_01",
    "name": "Curry Leaf Fine Dining",
    "tagline": "Authentic Coastal & South Indian Cuisine",
    "address": "123 Spice Garden Road, Indiranagar, Bengaluru, Karnataka 560038",
    "phone": "+91 80 4123 4567",
    "email": "contact@curryleafdining.com",
    "gstin": "29AABCU9603R1ZM",
    "fssai_licence": "11223344556677",
    "currency_symbol": "₹",
    "currency_code": "INR"
}'::jsonb, 'General restaurant profile and tax details'),
('tax_and_billing', '{
    "default_tax_rate": 5.0,
    "tax_inclusive_pricing": false,
    "service_charge_percent": 0.0,
    "allow_discounts": true,
    "max_captain_discount_percent": 0.0,
    "max_counter_discount_percent": 20.0
}'::jsonb, 'Tax and cashier billing rules'),
('printers', '{
    "counter_bill": {
        "name": "Counter Thermal 80mm",
        "connection_type": "network",
        "ip": "192.168.1.200",
        "port": 9100,
        "paper_width": "80mm",
        "enabled": true
    },
    "kitchen_kot": {
        "name": "Kitchen KOT Thermal 80mm",
        "connection_type": "network",
        "ip": "192.168.1.201",
        "port": 9100,
        "paper_width": "80mm",
        "enabled": true
    }
}'::jsonb, 'Configured thermal printers')
ON CONFLICT (key) DO NOTHING;

-- 2. Registered Devices
-- API key hashes below represent development tokens (e.g., 'captain_secret_01', 'counter_secret_01')
INSERT INTO devices (id, device_name, role, device_fingerprint, api_key_hash, is_active) VALUES
('dev_counter_01', 'Counter Main PC', 'counter', 'fp_win_counter_master_01', 'hash_dev_counter_key_01', true),
('dev_captain_01', 'Captain Tablet 1 - Ground Floor', 'captain', 'fp_tab_android_capt_01', 'hash_dev_captain_key_01', true),
('dev_captain_02', 'Captain Tablet 2 - Outdoor Patio', 'captain', 'fp_tab_android_capt_02', 'hash_dev_captain_key_02', true),
('dev_admin_01', 'Restaurant Manager Laptop', 'admin', 'fp_win_manager_admin_01', 'hash_dev_admin_key_01', true)
ON CONFLICT (id) DO NOTHING;

-- 3. Restaurant Tables
INSERT INTO restaurant_tables (id, table_number, display_name, section, capacity, status, sort_order) VALUES
('tab_t1', 'T1', 'Table 1', 'Main Dining', 4, 'available', 1),
('tab_t2', 'T2', 'Table 2', 'Main Dining', 2, 'available', 2),
('tab_t3', 'T3', 'Table 3', 'Main Dining', 4, 'available', 3),
('tab_t4', 'T4', 'Table 4', 'Main Dining', 6, 'available', 4),
('tab_t5', 'T5', 'Table 5', 'Main Dining', 8, 'available', 5),
('tab_p1', 'P1', 'Patio 1', 'Outdoor Patio', 2, 'available', 6),
('tab_p2', 'P2', 'Patio 2', 'Outdoor Patio', 4, 'available', 7),
('tab_p3', 'P3', 'Patio 3', 'Outdoor Patio', 4, 'available', 8),
('tab_ac1', 'AC1', 'VIP AC 1', 'AC Family Section', 6, 'available', 9),
('tab_ac2', 'AC2', 'VIP AC 2', 'AC Family Section', 10, 'available', 10)
ON CONFLICT (id) DO NOTHING;

-- 4. Menu Categories
INSERT INTO menu_categories (id, name, description, sort_order, is_active) VALUES
('cat_starters', 'Starters & Quick Bites', 'Crispy appetizers, fried specialties, and warm bites', 1, true),
('cat_tandoor', 'Tandoori & Grills', 'Slow-cooked kebabs and clay oven delicacies', 2, true),
('cat_mains', 'Main Course Curries', 'Signature South & North Indian rich gravies', 3, true),
('cat_biryani', 'Biryani & Rice', 'Fragrant dum biryanis and seasoned rice pots', 4, true),
('cat_breads', 'Breads & Accompaniments', 'Fresh rotis, naans, and parottas', 5, true),
('cat_beverages', 'Beverages & Mocktails', 'Coolers, fresh lime sodas, and buttermilk', 6, true),
('cat_desserts', 'Desserts', 'Traditional Indian sweets and ice creams', 7, true)
ON CONFLICT (id) DO NOTHING;

-- 5. Menu Items (All prices in paise: ₹280 = 28000)
INSERT INTO menu_items (id, category_id, name, short_code, description, price_paise, tax_rate_percent, is_available, is_veg, variants, add_ons, sort_order) VALUES
-- Starters
('item_paneer_65', 'cat_starters', 'Curry Leaf Paneer 65', 'P65', 'Crisp cottage cheese cubes tossed in spicy tempering with fresh curry leaves', 24000, 5.0, true, true, 
 '[{"id": "half", "name": "Half", "price_paise": 14000}, {"id": "full", "name": "Full", "price_paise": 24000}]'::jsonb, 
 '[{"id": "extra_chilli_dip", "name": "Extra Chilli Dip", "price_paise": 3000}]'::jsonb, 1),

('item_gobi_manchurian', 'cat_starters', 'Crispy Gobi Manchurian', 'GBM', 'Crisp cauliflower florets tossed in garlic, spring onion, and soy reduction', 21000, 5.0, true, true, '[]'::jsonb, '[]'::jsonb, 2),

('item_chicken_ghee_roast', 'cat_starters', 'Kundapura Chicken Ghee Roast', 'CGR', 'Tender chicken braised in clarified butter and fiery Byadgi red chilli paste', 34000, 5.0, true, false, 
 '[{"id": "half", "name": "Half", "price_paise": 20000}, {"id": "full", "name": "Full", "price_paise": 34000}]'::jsonb, 
 '[]'::jsonb, 3),

('item_kallumakkaya_fry', 'cat_starters', 'Mangalore Fish Rava Fry', 'MFR', 'Fresh catch fillets coated in spiced semolina crust and shallow pan-fried', 38000, 5.0, true, false, '[]'::jsonb, '[]'::jsonb, 4),

-- Tandoor
('item_paneer_tikka', 'cat_tandoor', 'Achari Paneer Tikka', 'APT', 'Smoked cottage cheese marinated with pickling spices and char-grilled', 29000, 5.0, true, true, '[]'::jsonb, '[]'::jsonb, 5),
('item_chicken_tikka', 'cat_tandoor', 'Murgh Malai Tikka', 'MMT', 'Chicken morsels infused with cheese, cardamom, and roasted cream marinade', 36000, 5.0, true, false, '[]'::jsonb, '[]'::jsonb, 6),

-- Mains
('item_paneer_butter_masala', 'cat_mains', 'Paneer Butter Masala', 'PBM', 'Fresh paneer cubes simmered in velvety tomato cream gravy', 28000, 5.0, true, true, '[]'::jsonb, 
 '[{"id": "extra_butter", "name": "Extra Butter Dollop", "price_paise": 2500}]'::jsonb, 7),

('item_dal_makhani', 'cat_mains', 'Dal Makhani Slow Simmered', 'DLM', 'Black lentils and kidney beans slow-cooked overnight with fresh cream', 25000, 5.0, true, true, '[]'::jsonb, '[]'::jsonb, 8),

('item_curry_leaf_chicken_curry', 'cat_mains', 'Curry Leaf Country Chicken Curry', 'CCC', 'Homestyle chicken simmered with ground spices, shallots, and fresh curry leaves', 35000, 5.0, true, false, 
 '[{"id": "half", "name": "Half", "price_paise": 21000}, {"id": "full", "name": "Full", "price_paise": 35000}]'::jsonb, 
 '[]'::jsonb, 9),

('item_mutton_sukka', 'cat_mains', 'Nati Mutton Sukka', 'MTS', 'Tender goat meat roasted dry with grated coconut, pepper, and coastal spices', 42000, 5.0, true, false, '[]'::jsonb, '[]'::jsonb, 10),

-- Biryani
('item_hyderabadi_veg_biryani', 'cat_biryani', 'Subz Dum Biryani', 'VBY', 'Layers of basmati rice, vegetables, saffron, and fresh mint sealed in handi', 26000, 5.0, true, true, '[]'::jsonb, 
 '[{"id": "extra_salan", "name": "Extra Mirchi Ka Salan", "price_paise": 2000}, {"id": "extra_raita", "name": "Extra Raita", "price_paise": 2000}]'::jsonb, 11),

('item_chicken_dum_biryani', 'cat_biryani', 'Ambur Chicken Dum Biryani', 'ACBY', 'Short-grain seeraga samba rice cooked with tender chicken and whole spices', 32000, 5.0, true, false, 
 '[{"id": "single", "name": "Single Portion", "price_paise": 22000}, {"id": "regular", "name": "Regular Portion", "price_paise": 32000}]'::jsonb, 
 '[{"id": "boiled_egg", "name": "Extra Boiled Egg", "price_paise": 2500}]'::jsonb, 12),

-- Breads
('item_butter_naan', 'cat_breads', 'Butter Garlic Naan', 'BGN', 'Tandoor leavened flatbread brushed with garlic butter', 7000, 5.0, true, true, '[]'::jsonb, '[]'::jsonb, 13),
('item_malabar_parotta', 'cat_breads', 'Kerala Malabar Parotta', 'MPR', 'Flaky multi-layered grilled flatbread', 5000, 5.0, true, true, '[]'::jsonb, '[]'::jsonb, 14),

-- Beverages
('item_masala_chaas', 'cat_beverages', 'Spiced Buttermilk (Neer Moru)', 'NMR', 'Refreshing churned yogurt tempered with ginger, green chilli, and curry leaves', 6000, 5.0, true, true, '[]'::jsonb, '[]'::jsonb, 15),
('item_fresh_lime_soda', 'cat_beverages', 'Fresh Lime Soda Sweet & Salt', 'FLS', 'Freshly squeezed lemon juice topped with sparkling chilled soda', 9000, 5.0, true, true, '[]'::jsonb, '[]'::jsonb, 16),

-- Desserts
('item_elaneer_payasam', 'cat_desserts', 'Tender Coconut Elaneer Payasam', 'ENP', 'Chilled dessert crafted with tender coconut pulp, condensed milk, and cardamom', 16000, 5.0, true, true, '[]'::jsonb, '[]'::jsonb, 17),
('item_gulab_jamun', 'cat_desserts', 'Hot Gulab Jamun with Ice Cream', 'GJI', 'Warm mawa dumplings soaked in saffron syrup served with vanilla scoop', 14000, 5.0, true, true, '[]'::jsonb, '[]'::jsonb, 18)
ON CONFLICT (id) DO NOTHING;
