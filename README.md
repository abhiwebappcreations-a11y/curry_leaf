# Hinopt Restaurant POS

**Hinopt Restaurant POS** is an individually installed, offline-first restaurant point-of-sale system with central license and subscription management by Hinopt.

Each restaurant runs its operational POS locally. Hinopt manages restaurant registrations and licenses through a separate cloud admin panel.

> **Project status:** Architecture and scope specification. Update this README as implementation details, environment variables, API routes, and deployment procedures become finalized.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Applications and Roles](#applications-and-roles)
- [Core Workflows](#core-workflows)
- [Offline Operation](#offline-operation)
- [License Management](#license-management)
- [Security Requirements](#security-requirements)
- [Technology Stack](#technology-stack)
- [Repository Structure](#repository-structure)
- [Development Setup](#development-setup)
- [Deployment Overview](#deployment-overview)
- [Backup and Recovery](#backup-and-recovery)
- [Important Design Rules](#important-design-rules)
- [Planned Features](#planned-features)
- [License](#license)

## Overview

The first version is designed for **one independent restaurant per installation**.

Each restaurant installation includes:

- One Windows Counter PC that hosts the local backend and database.
- Captain Android devices that connect over the restaurant's local Wi-Fi/LAN.
- A counter bill printer.
- A separate kitchen KOT (Kitchen Order Ticket) printer.
- A cloud-managed license issued and maintained by Hinopt.

Restaurant orders, bills, payments, and operational records remain in the restaurant's local database. Supabase is used for Hinopt's cloud-side license management—not as the live database for restaurant orders.

## Architecture

```text
                    HINOPT CLOUD
             +-------------------------+
             | Hinopt Admin Dashboard  |
             | Supabase Auth / Database|
             | License management     |
             +------------+------------+
                          |
                 License verification
                 and renewal updates
                          |
                          v
+-----------------------------------------------------+
|              INDIVIDUAL RESTAURANT                  |
|                                                     |
|  Captain Android devices                            |
|  +-----------+ +-----------+ +-----------+          |
|  | Captain 1 | | Captain 2 | | Captain 3 |   ...    |
|  +-----+-----+ +-----+-----+ +-----+-----+          |
|        |             |             |                |
|        +-------------+-------------+                |
|                      | Restaurant Wi-Fi/LAN         |
|                      v                              |
|  +-----------------------------------------------+  |
|  | Windows Counter PC                            |  |
|  |                                               |  |
|  | Flutter Counter Desktop App                   |  |
|  | Node.js + TypeScript Local API                 |  |
|  | PostgreSQL Local Database                      |  |
|  | Local Print Service                            |  |
|  +--------------------+--------------------------+  |
|                       |                             |
|             +---------+---------+                   |
|             v                   v                   |
|      Counter Bill Printer   Kitchen KOT Printer     |
+-----------------------------------------------------+
```

### Main design principle

**Cloud for license control; local network for restaurant operations.**

The restaurant should not need an active internet connection for normal local order taking, billing, and printing, provided its counter PC, local server, local network, database, and printers are operational.

## Applications and Roles

### 1. Captain Android App

**Platform:** Android APK  
**Technology:** Flutter

Captain devices are for order-taking—not administration.

Planned capabilities:

- Display restaurant tables as clear, easy-to-use cards.
- Show table/order status and current order amount.
- Browse and search menu categories and items.
- Add items, adjust quantities, select configured variants/add-ons, and enter item notes.
- Submit orders to the local server.
- Send Kitchen Order Tickets (KOTs).
- View order details and bill previews.
- Show useful connection and submission status.
- Restrict access to authorized, registered devices.

Captain devices must not have counter administration or payment-settlement permissions by default.

### 2. Counter Windows Desktop App

**Platform:** Windows desktop application  
**Technology:** Flutter

The Counter app is a native desktop application, **not a web app**.

Planned capabilities:

- View and manage incoming orders.
- Generate and finalize bills.
- Record supported payment methods.
- Manage menu items, categories, tables, and operational settings.
- Configure counter and kitchen printers independently.
- View bill history and sales reports.
- Manage registered devices and local operational settings.
- Perform and verify backups.

Final permissions, payment methods, tax settings, discount rules, and receipt formats will be configured as product requirements are finalized.

### 3. Kitchen Printing

**First-version approach:** A kitchen screen is not required. KOTs are printed on the configured kitchen thermal printer.

Requirements:

- Keep kitchen printing separate from counter bill printing.
- Save an order or KOT record before attempting to print it.
- Maintain a durable print queue and report print failures.
- Provide controlled reprinting with a clear `REPRINT` label.
- Avoid creating duplicate orders or sales when a print job is retried.
- Allow printer connection settings and test printing.

Supported configuration choices should be visible for each printer: **USB, Ethernet/LAN, Wi-Fi, and Bluetooth**. Actual availability depends on the selected printer, operating system, drivers, and connection hardware.

## Core Workflows

### Order to KOT

1. A captain selects a table and adds menu items.
2. The Captain app submits the order to the local API.
3. The local server validates permissions and saves the order in PostgreSQL.
4. A KOT/print job is created and queued.
5. The print service sends the KOT to the configured kitchen printer.
6. The app displays the resulting order and connection status.

### Billing and payment

1. The Counter app retrieves the latest order from the local server.
2. Authorized counter staff review and finalize the bill.
3. The server records the bill and payment using a database transaction.
4. A bill print job is queued for the counter printer.
5. The bill and payment history remain available locally.

Retries must not create duplicate orders, payments, bills, or sales. Use unique identifiers and idempotency controls for operations that may be repeated after a timeout or lost connection.

### Order changes and cancellations

Items that have already been sent to the kitchen must not be silently removed. Changes should create an auditable modification/cancellation workflow, with a reason and counter approval where required by the final business rules.

## Offline Operation

The local POS is designed to continue working during an internet outage.

**Expected to work without internet, when local components are healthy:**

- Captain-to-counter communication over the restaurant LAN.
- Local order storage and retrieval.
- Billing and payment recording.
- Local KOT and bill printing.

**Still depends on local infrastructure:**

- The counter PC and local server must be running.
- Captain devices must be able to reach the counter PC over the local network.
- PostgreSQL and the print service must be healthy.
- Printers and their connections must be operational.

The counter PC is the local system's central point of failure. If it shuts down or fails, connected Captain devices will not be able to use the local service until it is restored. Reliable backups and a documented recovery procedure are therefore required.

Offline license-verification allowance and post-expiry renewal grace are separate policies and must be configured explicitly before release.

## License Management

Hinopt centrally manages restaurant licenses through its cloud admin dashboard.

Planned Hinopt Admin capabilities:

- Register a restaurant and issue its license.
- Set license start and expiry dates.
- Renew an annual license.
- Suspend or reactivate a license.
- View registered installations/devices.
- Review license events and renewal history.

### License validation design

- Supabase stores authoritative cloud-side license status and expiry.
- A trusted server-side component issues digitally signed license data.
- The local server verifies signed license data using a public verification key.
- The private signing key and Supabase service-role key must remain on trusted server-side infrastructure.
- Do not embed privileged keys in Android APKs, Flutter desktop clients, or other client-distributed files.
- Local license checks must not require a cloud request for every order or bill.
- On expiry, the application should apply the configured policy to new operational activity while preserving historical bills and records and allowing safe handling of orders already in progress.
- Renewal requires authorized action in Hinopt Admin and successful verification of the updated license by the local installation.

Remote suspension cannot be enforced immediately while an installation is offline. It takes effect when the installation next receives and verifies an applicable license update. No software-only mechanism can make a license perfectly tamper-proof on a customer-controlled computer.

## Security Requirements

- Use registered device credentials; do not trust a Wi-Fi network name or password alone.
- Enforce permissions on the local API, not only by hiding buttons in the UI.
- Restrict Captain devices to order-taking functions.
- Restrict billing, payment settlement, configuration, and administration to authorized counter users.
- Use authenticated communication and protect stored credentials.
- Keep secrets and signing keys out of source control and client applications.
- Validate and authorize all requests on the server.
- Record important actions such as bill voids, payment changes, order cancellations, reprints, and license changes in audit logs.
- Use a dedicated restaurant network where practical, separate from customer Wi-Fi.
- Store backups separately from the main database.
- Test restore procedures before relying on backups.

## Technology Stack

| Component | Planned technology | Responsibility |
|---|---|---|
| Captain app | Flutter for Android | Table view and order taking |
| Counter app | Flutter for Windows | Billing and counter administration |
| Local API/server | Node.js + TypeScript | Business rules, permissions, local API |
| Local database | PostgreSQL | Orders, bills, payments, menu, and operational records |
| Printing | Local print service | Bill and KOT print queues |
| Hinopt Admin | Web dashboard (implementation to be finalized) | Restaurant and license administration |
| Cloud license data | Supabase | Cloud-side license records and admin authentication |
| License signing | Asymmetric digital signatures (e.g. Ed25519) | Signed license issuance and local verification |

This table records the intended architecture; it does not claim that all components have already been implemented.

## Repository Structure

A possible monorepo layout is:

```text
hinopt-restaurant-pos/
├── apps/
│   ├── captain-android/       # Flutter Android app
│   ├── counter-windows/       # Flutter Windows desktop app
│   └── hinopt-admin/          # Hinopt cloud admin dashboard
├── services/
│   ├── local-api/             # Node.js + TypeScript API
│   ├── print-service/         # Local printer service and queues
│   └── license-service/       # Trusted cloud-side license issuance
├── database/
│   ├── local-migrations/      # PostgreSQL schema and migrations
│   └── cloud-migrations/      # Supabase schema and migrations
├── docs/
│   ├── architecture.md
│   ├── api.md
│   ├── deployment.md
│   ├── backup-and-recovery.md
│   └── printer-setup.md
├── .env.example
├── .gitignore
└── README.md
```

Adjust this layout to match the actual repository as implementation begins. Do not create placeholder folders solely to match the diagram.

## Development Setup

Exact commands depend on the repository and installed tool versions. The following are prerequisites, not a complete runnable setup.

### Prerequisites

- Git
- Flutter SDK with Android and Windows desktop support enabled
- Android Studio or the Android SDK toolchain
- Visual Studio with the required C++ desktop development components for Flutter Windows builds
- Node.js LTS and npm
- PostgreSQL
- A Supabase project for cloud-side admin and licensing
- Compatible thermal printers and their required drivers or connection hardware

### Suggested setup sequence

1. Clone the repository.
2. Install Flutter dependencies separately for each Flutter application.
3. Install Node.js dependencies for the local API and print service.
4. Configure the local PostgreSQL instance and apply database migrations.
5. Configure the Supabase project and apply cloud schema migrations.
6. Copy `.env.example` to a local environment file and supply development-only values.
7. Start the local API and print service.
8. Run the Captain app on an Android device connected to the same test LAN.
9. Run the Counter app on Windows.
10. Test order submission, KOT printing, billing, payment retries, internet loss, and database recovery before pilot use.

> Do not add real credentials, database passwords, Supabase service-role keys, or license-signing private keys to this README or commit them to Git.

## Deployment Overview

For each restaurant:

1. Install the local PostgreSQL database on the designated Counter PC.
2. Install and configure the local API and print service.
3. Install the Counter Windows desktop application.
4. Assign a stable local IP address or DHCP reservation to the Counter PC.
5. Configure a dedicated restaurant Wi-Fi/LAN network.
6. Register and authorize each Captain device.
7. Configure the counter bill printer and kitchen KOT printer separately.
8. Test printing, order updates, billing, and payment recording.
9. Configure automated backups and verify a test restore.
10. Register the installation with Hinopt and activate its license.
11. Run a supervised pilot before production use.

The exact installer, update mechanism, service startup, firewall rules, and recovery process must be documented once they are implemented.

## Backup and Recovery

- Back up the local PostgreSQL database on a scheduled basis.
- Keep at least one backup on a separate drive or storage location.
- Consider an encrypted off-site copy when internet access is available.
- Protect backup files because they contain sensitive business records.
- Document how to restore the database and verify data integrity.
- Test restoration periodically.
- Define how to recover the local server if the Counter PC fails.

A backup is not considered reliable until a restore has been tested.

## Important Design Rules

1. **Local operations first:** routine orders and bills must not depend on a live cloud connection.
2. **One installation per restaurant:** no multi-branch or shared live-order database in the first version.
3. **One source of truth:** all Captain devices use the local server and PostgreSQL database; do not maintain separate independent order databases on each device.
4. **Persist before printing:** save business records before attempting physical printing.
5. **Safe retries:** prevent duplicate orders, bills, payments, and sales.
6. **Separate printers:** maintain independent configuration and queues for counter bills and kitchen KOTs.
7. **Server-side authorization:** enforce permissions in the API.
8. **Secure license issuance:** never distribute private signing keys or privileged Supabase keys.
9. **Audit important actions:** retain traceable records for sensitive operational changes.
10. **Back up and test recovery:** protect against Counter PC or database failure.

## Planned Features

These are possible future additions, not commitments for the first release:

- Remote owner sales reports.
- Multi-branch management.
- Cloud synchronization of selected reports.
- Inventory and recipe-cost management.
- Supplier management.
- Swiggy/Zomato integration, subject to approved API/partner access.
- Online ordering.
- Automated subscription payment collection.

The first release should prioritize stable local ordering, billing, printing, licensing, and recovery before adding these features.

## License

The software's distribution and usage license has not yet been specified. Add the applicable legal license before publishing or distributing the source code.



## Project Workflow & Coordination

- Every time immediately push changes to GitHub and check GitHub regularly to stay connected to other agents' work.
- If it is Agent 1, strictly perform Agent 1 backend and operational foundation work.
