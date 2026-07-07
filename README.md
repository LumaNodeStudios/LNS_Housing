<div align="center">
  <h1>LNS Housing</h1>

  [![Version](https://img.shields.io/badge/Version-1.0.0-6fd2f3?style=for-the-badge)](https://github.com/LumaNodeStudios/LNS_Housing)
  [![Frameworks](https://img.shields.io/badge/Frameworks-ESX%20%7C%20Qbox-6fd2f3?style=for-the-badge)](#-framework-compatibility)
  [![Documentation](https://img.shields.io/badge/Documentation-Read%20Here-6fd2f3?style=for-the-badge)](https://lumanodestudios.vercel.app/docs/lns_housing)
  [![Author](https://img.shields.io/badge/Author-LumaNode%20Studios-6fd2f3?style=for-the-badge)](https://github.com/LumaNodeStudios)
  [![License](https://img.shields.io/badge/License-GPL--3.0-6fd2f3?style=for-the-badge)](LICENSE)
</div>

---

## Preview

<img src="https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/lns_housing_thumbnail_1781600469826.png" alt="LNS Housing Thumbnail" width="100%" style="border-radius: 12px; margin-top: 20px; margin-bottom: 20px; box-shadow: 0 4px 20px rgba(0,0,0,0.4);"/>

---

## Overview

**LNS Housing** by **LumaNode Studios** is a state-of-the-art, feature-complete housing and real estate system designed for FiveM servers. It completely replaces legacy, unoptimized housing resources with a modern, database-backed solution.

Rather than just a simple spawn-and-teleport script, **LNS Housing** introduces deep, immersive mechanics: **interactive furniture shop and placement**, a **dynamic lawn growth and mowing system**, **real estate agency job flows** with contracts and employee permissions, and a highly optimized **starter apartments framework** with seamless spawn integrations.

---

## Features

### Advanced Property Management & Editing
* **In-Game House Creator:** Admin commands (`/createhouse`) to quickly define shell locations, entrance/exit coordinates, pricing, and allowed agencies.
* **MLO & Shell support:** Built-in tools for both MLO-based houses and traditional teleporting shell interiors.
* **Wall Colors & Customization:** Real-time interior wall painting/color selection, allowing players to truly personalize their houses.

### Interactive Furniture & Shop
* **Rich Furniture Catalog:** Dozens of pre-configured furniture props across sofas, chairs, beds, tables, storage containers, lights, and decor.
* **Dynamic Placement UI:** Smooth translation, rotation, and height adjustment tools to position props precisely in-game.
* **Stashes & Wardrobes:** Place storage crates, lockers, wardrobes, or safes anywhere. Placing storage furniture automatically registers the containers with the inventory system.

### Dynamic Lawn Mower & Yard System
* **Grass Growth:** Grass props spawn dynamically in designated yard zones, growing in height over time.
* **Lawn Maintenance:** Players must mow their yard using a lawnmower item or drivable mower vehicles to maintain their properties.
* **Yard Customization:** Define specific lawn zone boundaries for any property using the built-in zone editor.

### Real Estate & Contracts
* **Agent Dashboard:** Real estate agents access a custom panel (`/properties`) to manage listings, adjust pricing, and hire employees.
* **Draft Purchase Contracts:** Draft legal agreements specifying commission rates, deposit requirements, and buyer parameters.
* **Agency Permissions:** Granular agent grades control access to creating listings, editing details, managing employees, or drafting contracts.

### Security & Raids
* **Lockpicking:** Immersive minigame to lockpick house and apartment doors.
* **Police Breaches:** Authorize law enforcement agents to raid properties, bypass door locks, and search stashes under active warrants.

---

## 📖 Documentation

For detailed installation and setup instructions, refer to the guides below:

### ⚙️ Dependencies
* **ox_lib** (Required)
* **oxmysql** (Required)
* **screencapture** (Required)
* A supported Inventory resource (e.g., **ox_inventory**)
* A supported Garage resource (e.g., **qbx_garages**, **jg-advancedgarages**, **cd_garage**, or **op-garages**)

### 🚀 Installation
1. Download **LNS Housing** and place it into your server's `resources` directory.
2. Ensure you have all the required dependencies listed above installed and running.
3. Import the default SQL schema/tables into your database if required.
4. Configure framework-specific details and systems inside [shared/settings.lua](file:///d:/FiveM/Scripting/%5BLumaNode%5D/%5BHousing%5D/LNS_Housing/shared/settings.lua) and [bridge/shared.lua](file:///d:/FiveM/Scripting/%5BLumaNode%5D/%5BHousing%5D/LNS_Housing/bridge/shared.lua).
5. Add `ensure LNS_Housing` to your `server.cfg` configuration.

### ⌨️ Commands
* **`/createhouse`** - Initiates the in-game property creation wizard (Admin command).
* **`/createapartment`** - Opens the starter apartment creation tool (Admin command).
* **`/properties`** - Opens the real estate agency dashboard for managing listings and contracts (Realtor command).
* **`/contracts`** - View and review pending lease or sale contracts.
* **`/checkfurniture`** - Debug/check placed furniture props.
* **`/takeshots`** - Automatically capture furniture screenshots for the catalog UI.

---

## Credits & Acknowledgements

**LNS Housing** is developed and distributed by **[LumaNode Studios](https://github.com/LumaNodeStudios)**. 

Special thanks to **[Project Sloth](https://github.com/Project-Sloth)** for their work on **[ps-housing](https://github.com/Project-Sloth/ps-housing)** and **[ps-realtor](https://github.com/Project-Sloth/ps-realtor)**, which served as reference and inspiration for some of the codebase's logic.

We also thank the wider FiveM developer community and the creators of **ox_lib** and **ox_doorlock** for providing key integration libraries that make this script lightweight and performant.

---

<div align="center">
  <p><i>A premium resource developed by <a href="https://github.com/LumaNodeStudios">LumaNode Studios</a></i></p>
</div>