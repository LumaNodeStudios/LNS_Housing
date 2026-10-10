<div align="center">
  <h1>LNS Housing</h1>

  [![Version](https://img.shields.io/badge/Version-0.1.7-6fd2f3?style=for-the-badge)](https://github.com/LumaNodeStudios/LNS_Housing)
  [![Frameworks](https://img.shields.io/badge/Frameworks-ESX%20%7C%20Qbox-6fd2f3?style=for-the-badge)](#-framework-compatibility)
  [![Author](https://img.shields.io/badge/Author-LumaNode%20Studios-6fd2f3?style=for-the-badge)](https://github.com/LumaNodeStudios)
  [![License](https://img.shields.io/badge/License-GPL--3.0-6fd2f3?style=for-the-badge)](LICENSE)
</div>

---

## Preview

<img src="https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/lns_housing_thumbnail_1781600469826.png" alt="LNS Housing Thumbnail" width="100%" style="border-radius: 12px; margin-top: 20px; margin-bottom: 20px; box-shadow: 0 4px 20px rgba(0,0,0,0.4);"/>

---

## Overview

**LNS Housing** by **LumaNode Studios** is a state-of-the-art, feature-complete housing and real estate ecosystem engineered for modern FiveM servers. Designed to replace outdated, unoptimized housing resources, LNS Housing combines a database-backed foundation with high-performance bridging and an ultra-modern React 19 UI suite.

Going far beyond standard teleport-and-stash scripts, **LNS Housing** introduces deep, immersive living mechanics: an **interactive electricity and power grid** with circuit breaker trips, **interior climate & temperature control**, a **real-time lawn growth and mowing simulation**, **timed auctions and rental contracts with legal paper signing**, **interactive 3D battering ram police breaches**, **live doorbell camera feeds**, an **NPC locksmith with physical key support**, and an **automated green-screen prop thumbnail pipeline** with CDN upload integration.

---

## Key Features

### 🏢 Real Estate Agency & Market Economy
* **Interactive Tablet UI (`/housing`):** Full-featured dashboard for browsing listings, managing properties, and checking agency balances.
* **Versatile Sales Models:**
  * **Direct Sale:** Standard bank purchase with instant ownership transfer.
  * **Timed Auctions:** Live real-time bidding system with configurable starting bids and timers.
  * **Rental Leases:** Recurring weekly lease payments with automatic database billing (even for offline players).
* **Legal Paper Contract System:** Agents draft official purchase or rental contracts specifying deposits and commissions. Clients review and sign authentic, physical-style paper contract documents (`ContractPaper`).
* **Tenant & Lease Management:** Automated grace periods, late fees, lockout modes, temporary retrieval periods, and realtor eviction controls.
* **Renter Blacklist:** Real estate agencies can blacklist delinquent renters with Citizen ID, name, and reason tracking.
* **In-Game 3-Step Property Wizard:** Complete in-game creator tool with door picking, garage coordinates, vehicle spawn points, breaker box locations, doorbell camera placement, and camera screenshot capture.

### ⚡ Electricity, Power Grid & Climate Simulation
* **Dynamic Electrical Load:** Configurable kWh consumption per placed appliance (lamps, TVs, refrigerators, heating units).
* **Circuit Breakers & Overload:** Exceeding maximum circuit capacity trips the breaker, plunging the house into darkness until reset via an interactive skill-check minigame.
* **Electrical Upgrades:** Upgradable grid tiers from Standard Circuit (5.0 kWh) up to Industrial Power Grid (50.0 kWh).
* **Ambient Climate & Temperature:** Furniture items impact room heating and cooling (°C or °F), visible in real time on the property dashboard.

### 🛡️ Security, Raids & Locksmith
* **Upgradable Locks (Tiers 0–5):** Upgradable security tiers featuring scaled lockpicking minigame difficulty (rotational angles, speed, and rounds).
* **Burglar Alarm System:** Configurable failed-attempt thresholds trigger audible burglar sirens backed by custom audio packs (`lns_sounds.dat54.rel` / `lns_bank.awc`).
* **Interactive 3D Battering Ram Breach:** Police use physical mouse drag-and-strike mechanics to repeatedly ram doors open with custom animations, models, and impact audio.
* **Police Stash Raids:** Authorized officers can force open locked storage containers using dedicated breach tools.
* **Physical Key System & NPC Locksmith:** Metadata-bound key items (`house_key`) cut from blank keys at an NPC locksmith, featuring support for stolen key burglary RP and per-property key limits.
* **Doorbell Camera & Live Feed:** Physical CCTV camera prop mounted at entrance, offering live security camera viewing and interactive 3D camera repositioning.

### 🛋️ Furniture Studio & Automated Thumbnail Pipeline
* **Massive Catalog:** Over 5,000+ lines of pre-configured furniture props across seating, tables, beds, lighting, decor, and storage.
* **Precision 3D Modeler:** Freecam mode, translation/rotation gizmos, snapping controls, alpha transparency previews, and real-time shopping cart.
* **Functional Props:** Place interactive storage stashes (`ox_inventory`), wardrobes (`illenium-appearance`), property control tablets, and character logout points.
* **Automated Green-Screen Prop Pipeline (`/takeshots`):** Built-in studio isolation that spawns props in a private routing bucket, frames them, captures screenshots, strips chroma-key green in Node.js, sharpens/crops thumbnails, and uploads directly to **Qbox CDN**, **Fivemanage**, **Cloudflare R2**, or local storage.

### 🌱 Dynamic Lawn Mower & Yard Simulation
* **Real-Time Grass Growth:** Deterministic, server-synced grass growth simulation across polygon yard zones defined via in-game zone tools.
* **Interactive Mowing:** Push lawnmowers with custom prop handling and walking animations, or ride-on mower vehicles (`mower`).
* **Dynamic Culling:** Grass props dynamically sink, disappear when cut, and render efficiently based on player proximity.

### 🏠 Starter Apartments
* **Turnkey Multi-Unit Housing:** Complete starter apartment system with pre-configured WIWANG Apartments SQL data.
* **Concierge & Shared Services:** Lobby receptionist NPC, shared breaker boxes, and routing bucket isolation.
* **In-Game Apartment Creator:** Create and edit multi-room apartment complexes on the fly (`/createapartment`, `/editapartment`).

---

## 🛠️ Dependencies & Compatibility

### Frameworks
* **Qbox** (`qbx_core`)
* **ESX** (`es_extended`)

### Required Resources
* **[ox_lib](https://github.com/overextended/ox_lib)**
* **[oxmysql](https://github.com/overextended/oxmysql)**
* **[ox_target](https://github.com/overextended/ox_target)**
* **[ox_doorlock](https://github.com/overextended/ox_doorlock)**
* **[ox_inventory](https://github.com/overextended/ox_inventory)**
* **[screencapture](https://github.com/overextended/screencapture)** *(Required for prop and property screenshot features)*

### Optional Integrations (Auto-Detected)
* **Garages:** `qbx_garages`, `jg-advancedgarages`, `cd_garage`, `op-garages`
* **Phones:** `sd-phone`, `lb-phone`, `roadphone`, `yseries`
* **Dispatch:** `ps-dispatch`, `qs-dispatch`, `cd_dispatch`, `linden_dispatch`
* **Banking:** `Renewed-Banking`, `oneclub_banking`, `esx_addonaccount`
* **Wardrobe:** `illenium-appearance`

---

## 📖 Documentation

Full documentation, installation guides, and configuration breakdowns are available at:
https://www.lumanodestudios.com/docs/lns_housing

---

## Credits & Acknowledgements

**LNS Housing** is developed and distributed by **[LumaNode Studios](https://github.com/LumaNodeStudios)**.

Special thanks to:
* **[Project Sloth](https://github.com/Project-Sloth)** (ps-housing & ps-realtor), where some logic and code was referenced and adapted.
* The **[Overextended](https://github.com/overextended)** team for **ox_lib**, **ox_doorlock**, **ox_inventory**, and **screencapture**.
* **K4MB1 Maps** for interior shell designs.

---

<div align="center">
  <p><i>A premium open-source resource developed by <a href="https://github.com/LumaNodeStudios">LumaNode Studios</a></i></p>
</div>