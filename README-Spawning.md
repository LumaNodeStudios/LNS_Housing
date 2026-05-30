# Starter Apartment Spawning Integration

This file explains the custom changes made to **LNS_Housing** to automatically support player spawning in their newly assigned starter apartments on character creation.

---

## 🛠️ Summary of Changes

To achieve clean integration without modifying any external framework scripts (such as `qbx_core` or `qbx_spawn`), the following modifications were made:

### 1. Server-Side: Robust New Character Detection (`server/sv_apartments.lua`)
- **Issue:** By default, Qbox does not populate the legacy QBCore `charinfo.new` flag on the player object when a new character is saved. This caused `LNS_Housing` to write `is_new = 0` (marking the character as already spawned) upon creation.
- **Solution:** We updated `getPlayerRoom` to query the `playerskins` database table using `MySQL.single.await`. If no appearance record exists for the player's `citizenid`, the script correctly recognizes the character is brand new and inserts the database row with `is_new = 1`.

### 2. Client-Side: Foolproof Spawning Teleport (`client/cl_apartments.lua`)
- **Issue:** Normally, teleporting a player into their apartment depends exclusively on appearance creator saving events (such as `illenium-appearance:client:onAppearanceSaved`).
- **Solution:** We added `checkNewCharacterSpawn()` directly into `initApartmentForPlayer()`. This ensures that when the player loads in, the script instantly verifies if `is_new == 1` and teleports them to their starter apartment, functioning as a foolproof double-safe check.

---

## 📦 Why External Script Changes Aren't Needed

Because of our clean modular approach inside `LNS_Housing`, **you do not need to modify any external core scripts** like `qbx_core` or `qbx_spawn`. 

### How the Flow Operates Under the Hood:
1. **Character Creation:** The new player creates a character in the multicharacter selector.
2. **First Spawn Trigger:** Since you have no spawn menu, `qbx_core` spawns the player at the default newbies coordinate (e.g. the airport).
3. **Event Catching:** Immediately upon spawn, the client fires the loaded events, triggering `initApartmentForPlayer()`.
4. **Instant Teleport:** `LNS_Housing` catches this, queries the server, finds `is_new == 1`, teleports the player inside their starter apartment, and updates `is_new` to `0` in the database so it never runs again.
5. **Wardrobe Customization:** The player's clothing script (`illenium-appearance`) will open, letting them customize their appearance inside their new home.
6. **Persistence:** When they quit and rejoin, they spawn at their last saved location, completely bypassing any starter apartment teleports.

*Your Qbox core resources remain entirely clean and unmodified, preventing future framework updates from overwriting your custom setup!*
