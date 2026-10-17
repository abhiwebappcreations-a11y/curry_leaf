// Hinopt Admin Cloud Data Store
window.HinoptData = {
  restaurants: [
    {
      id: "rest-001",
      name: "Curry Leaf Fine Dine",
      city: "Hyderabad, Telangana",
      contactName: "Deepa",
      phone: "+91 98490 12345",
      hwid: "WIN-HWID-9842A190",
      licenseKey: "HINOPT-2026-CLFD-9842-8819",
      status: "ACTIVE",
      issuedAt: "2026-10-17",
      expiresAt: "2027-10-17",
      counterIp: "192.168.1.100",
      notes: "Main pilot branch. 1 Counter PC, 3 Android Captains."
    },
    {
      id: "rest-002",
      name: "Spice Route Bistro",
      city: "Bengaluru, Karnataka",
      contactName: "Kiran Kumar",
      phone: "+91 98765 43210",
      hwid: "WIN-HWID-4318C211",
      licenseKey: "HINOPT-2025-SRBT-4318-7721",
      status: "EXPIRING_SOON",
      issuedAt: "2025-10-31",
      expiresAt: "2026-10-31",
      counterIp: "192.168.0.105",
      notes: "Annual renewal invoice dispatched."
    },
    {
      id: "rest-003",
      name: "Coastal Bay Seafood",
      city: "Panaji, Goa",
      contactName: "Sunil Naik",
      phone: "+91 94220 55112",
      hwid: "WIN-HWID-7729F408",
      licenseKey: "HINOPT-2026-CBSF-7729-3390",
      status: "ACTIVE",
      issuedAt: "2026-06-15",
      expiresAt: "2027-06-15",
      counterIp: "10.0.0.45",
      notes: "Beachfront dining, 2 KOT thermal printers."
    },
    {
      id: "rest-004",
      name: "The Royal Tandoor",
      city: "New Delhi",
      contactName: "Vikram Sethi",
      phone: "+91 98110 77889",
      hwid: "WIN-HWID-1184D955",
      licenseKey: "HINOPT-2026-RYTD-1184-9912",
      status: "SUSPENDED",
      issuedAt: "2026-01-20",
      expiresAt: "2027-01-20",
      counterIp: "192.168.1.50",
      notes: "Account temporarily suspended for payment reconciliation."
    }
  ],

  auditLogs: [
    {
      id: "aud-901",
      action: "LICENSE_ISSUED",
      restaurantName: "Curry Leaf Fine Dine",
      operator: "Hinopt Operator (admin@hinopt.com)",
      timestamp: "2026-10-17 10:30 AM",
      details: "Issued 1-Year Production License token (Expires: 2027-10-17)"
    },
    {
      id: "aud-902",
      action: "RESTAURANT_REGISTERED",
      restaurantName: "Curry Leaf Fine Dine",
      operator: "Hinopt Operator (admin@hinopt.com)",
      timestamp: "2026-10-17 10:15 AM",
      details: "Client registered with Hardware ID: WIN-HWID-9842A190"
    },
    {
      id: "aud-903",
      action: "EXPIRY_WARNING_SENT",
      restaurantName: "Spice Route Bistro",
      operator: "System Cron",
      timestamp: "2026-10-16 08:00 AM",
      details: "Automated 15-day renewal reminder dispatched via WhatsApp & Email"
    },
    {
      id: "aud-904",
      action: "LICENSE_SUSPENDED",
      restaurantName: "The Royal Tandoor",
      operator: "Accounts (accounts@hinopt.com)",
      timestamp: "2026-10-10 03:45 PM",
      details: "Suspension token generated. Note: local POS is notified on next reconnection."
    }
  ]
};
