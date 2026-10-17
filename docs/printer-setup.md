# Hinopt Restaurant POS — Thermal Printer Setup & Hardware Guide

This document describes how to configure, connect, and operate the two independent thermal receipt printers required for Hinopt Restaurant POS.

## 1. Dual Independent Printer Architecture

Hinopt Restaurant POS requires two physically separate thermal printers:

| Printer | Purpose | Location | Standard Paper | Connection Options |
|---|---|---|---|---|
| **Counter Bill Printer** | Final guest receipts, payment receipts, reprints | Front cashier counter | 80mm or 58mm | USB, Ethernet/LAN, Bluetooth |
| **Kitchen KOT Printer** | Kitchen Order Tickets, cancel slips, chef alerts | Food preparation line | 80mm | Ethernet/LAN (Recommended) or Wi-Fi |

> **Critical Rule:** Kitchen KOT and Counter Bill printers must maintain completely independent queues, print settings, and error states. A failure in kitchen printing must never block cashier billing, and vice-versa.

---

## 2. Supported Connection Methods

### 2.1 Ethernet / LAN (Strongly Recommended for Kitchen)
- Connect printer via standard RJ45 Cat5e/Cat6 cable to the restaurant Wi-Fi router / switch.
- Assign a static IP or DHCP reservation (e.g., `192.168.1.201`).
- The local API on the Counter PC communicates directly via raw TCP socket on port `9100`.

### 2.2 USB (Standard for Counter PC)
- Connect printer directly to the Windows Counter PC via USB cable.
- Install manufacturer ESC/POS receipt printer driver.
- Share or map printer to raw Windows print port (`USB001` / `LPT1`).

### 2.3 Wi-Fi
- Suitable for areas where pulling Ethernet cables is difficult.
- Ensure printer is connected to the dedicated, hidden restaurant staff Wi-Fi (5 GHz or clean 2.4 GHz).

---

## 3. Configuration in `.env` / Settings

Printers are configured independently via environment variables or Counter Settings:

```env
# Counter Bill Printer
BILL_PRINTER_TYPE=network
BILL_PRINTER_TARGET=192.168.1.200:9100
BILL_PRINTER_PAPER_WIDTH=80mm

# Kitchen KOT Printer
KOT_PRINTER_TYPE=network
KOT_PRINTER_TARGET=192.168.1.201:9100
KOT_PRINTER_PAPER_WIDTH=80mm
```

---

## 4. Ticket Layouts & Formats

### 4.1 Kitchen Order Ticket (KOT) Format (80mm)
```text
================================================
           *** KITCHEN ORDER TICKET ***
================================================
KOT No: KOT-261017-2001       Table: T1 (Main)
Order:  ORD-261017-1001       Time:  20:45:10
Captain: Captain Tablet 1
------------------------------------------------
QTY   ITEM                            DETAILS
------------------------------------------------
 2    Curry Leaf Paneer 65            Full Portion
      [Note: Extra Crispy, Extra Chilli Dip]
 3    Butter Garlic Naan
------------------------------------------------
Chef Special Notes:
Diner requested less spicy.
================================================
```

### 4.2 Item Cancellation Slip (Sent to Kitchen)
```text
************************************************
            *** ITEM CANCELLED ***
************************************************
Table: T1 (Main)              Time: 20:48:22
Order: ORD-261017-1001
------------------------------------------------
CANCELLED:
 1 x Spiced Buttermilk (Neer Moru)
REASON: Guest changed mind to lime soda
AUTHOR: Counter Cashier (dev_counter_01)
************************************************
```

### 4.3 Guest Bill Receipt Format (80mm)
```text
================================================
            CURRY LEAF FINE DINING
       123 Spice Garden Road, Indiranagar
           Bengaluru, Karnataka 560038
              GSTIN: 29AABCU9603R1ZM
================================================
Bill No: BILL-261017-3001      Table: T1
Date:    17/10/2026 21:05      Diners: 2
------------------------------------------------
ITEM                 QTY    PRICE(₹)   AMOUNT(₹)
------------------------------------------------
Paneer 65 (Full)      2      240.00      480.00
Butter Garlic Naan    3       70.00      210.00
------------------------------------------------
Subtotal:                               ₹690.00
CGST (2.5%):                             ₹17.25
SGST (2.5%):                             ₹17.25
------------------------------------------------
TOTAL AMOUNT DUE:                       ₹724.50
------------------------------------------------
Payment Method: UPI (Paid via PhonePe QR)
Reference: UPI/1234567890/test
Status: PAID IN FULL
================================================
        Thank you for dining with us!
================================================
```

### 4.4 Reprint Handling & Watermarking
If a duplicate copy is requested from the Counter app (`POST /api/billing/bills/:id/reprint`):
- The duplicate ticket **MUST** print in bold double-height font at the top and bottom:
  ```text
  ************************************************
                 *** REPRINT ***
  ************************************************
  ```
- Reprints are audited in the database and increment the bill's `print_count`.
- Retrying a print job **NEVER** creates a duplicate bill, payment, or sale.
