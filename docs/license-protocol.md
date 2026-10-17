# Hinopt Restaurant POS — Licensing & Cryptographic Protocol

This document defines the asymmetric cryptographic licensing protocol used between **Hinopt Cloud (Admin)** and the **Local Restaurant Counter PC**.

---

## 1. Threat Model & Security Boundaries

1. **Local Operational Independence**:
   - The restaurant POS operates offline during internet outages.
   - The local API must not make live cloud requests for routine orders or bill printing.

2. **Asymmetric Key Security**:
   - **Private Signing Key (Ed25519)**: Held strictly on Hinopt Cloud server infrastructure. It is **NEVER** distributed to customer computers, Android APKs, Flutter Windows clients, or Git repositories.
   - **Public Verification Key (Ed25519)**: Stored on the local Counter PC in `.env` (`LICENSE_PUBLIC_KEY_PEM`). Used only to verify the authenticity of signed license payloads.
   - **Supabase Service-Role Key**: Strictly server-side on Hinopt Cloud. Never embedded in client software.

3. **Tamper Resistance Realities**:
   - On customer-controlled PC hardware, no software solution is 100% immune to clock manipulation or binary patching.
   - Monotonic time tracking, heartbeat verification when online, and digital signature checks provide robust operational compliance without interfering with restaurant dinner rush.

---

## 2. License Payload Structure

When a license is issued or renewed in Hinopt Admin, Hinopt Cloud generates a canonical JSON payload:

```json
{
  "restaurantId": "rest_curry_leaf_01",
  "restaurantName": "Curry Leaf Fine Dining",
  "licenseKey": "HINOPT-LIC-CL-2026-ACTIVE",
  "status": "active",
  "validFrom": "2026-01-01T00:00:00.000Z",
  "validUntil": "2026-12-31T23:59:59.000Z",
  "maxDevices": 10,
  "features": ["pos", "kot", "billing", "reports", "thermal_printing"],
  "issuedAt": "2026-01-01T10:00:00.000Z"
}
```

This payload is Base64-encoded (`signedPayloadBase64`) and signed using the Cloud Ed25519/SHA256 Private Key, yielding `signatureHex`.

---

## 3. Verification Protocol on Local Counter PC

When applying an updated license via `POST /api/license/verify` or inspecting boot status:

```text
       [ Hinopt Cloud ]
              |
     Issues Signed License (Base64 + SignatureHex)
              |
              v
     [ Counter PC API ]
              |
    1. Base64 Decode Payload
    2. Verify Signature with LICENSE_PUBLIC_KEY_PEM
    3. Check restaurantId matches local configuration
    4. Validate validFrom <= CurrentTime <= validUntil
              |
              +---> [ Valid ] ---> Cache in `license_cache` table
              |
              +---> [ Expired within 7 Days ] ---> State: `grace`
              |                                    (POS operates with warning)
              |
              +---> [ Expired beyond 7 Days ] ---> State: `expired`
                                                   (New orders blocked; records preserved)
```

---

## 4. Operational Behavior on License Expiry

| License State | Captain Order Taking | KOT Printing | Cashier Settlement | Historical Reports |
|---|---|---|---|---|
| **Active** | Enabled | Enabled | Enabled | Enabled |
| **Grace Period (1–7 days)** | Enabled (Warning badge shown) | Enabled | Enabled | Enabled |
| **Expired (> 7 days)** | Blocked with warning | Blocked | Settle in-progress orders only | **Always Enabled (Read-Only)** |
| **Suspended** | Blocked | Blocked | Blocked | Enabled |

> **Audit Protection:** An expired or suspended license **NEVER** deletes or locks past bills, tax invoices, or operational records. Cashiers and accountants retain complete access to financial reports.

---

## 5. License Renewal Workflow

1. Restaurant operator renews annual subscription with Hinopt.
2. Hinopt Admin generates updated signed payload with new `validUntil` date (e.g., +1 year).
3. If Counter PC is online, it auto-refreshes via cloud heartbeat.
4. If Counter PC is air-gapped / offline, operator pastes the signed key into Counter Settings -> License.
5. Local API verifies signature and updates `license_cache`.
