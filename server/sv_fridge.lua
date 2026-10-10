local Settings = lib.load('shared.settings')
local FridgeStashes = {}

function RegisterFridgeStash(stashId, propertyId, furnitureId)
    if not stashId then return end
    FridgeStashes[tostring(stashId)] = {
        propertyId = propertyId,
        furnitureId = furnitureId,
        registeredAt = os.time()
    }
    debugPrint('info', '[LNS_Housing] Registered fridge stash:', stashId, 'property:', propertyId)
end

function IsFridgeStash(stashId)
    if not stashId then return false end
    local strId = tostring(stashId)
    if FridgeStashes[strId] then
        return true, FridgeStashes[strId]
    end
    local lower = strId:lower()
    if lower:find('fridge') or lower:find('chiller') then
        return true, nil
    end
    return false, nil
end

local function IsFridgeActive(stashId)
    if not Settings.Fridge or Settings.Fridge.Enabled == false then
        return false
    end

    if Settings.Fridge.RequirePower and Settings.Electricity and Settings.Electricity.Enabled ~= false then
        local _, info = IsFridgeStash(stashId)
        local propertyId = info and info.propertyId
        if not propertyId and type(stashId) == 'string' then
            propertyId = stashId:match('housing_(%d+)')
        end
        if propertyId then
            local numId = tonumber(propertyId)
            local p = Properties and (Properties[propertyId] or (numId and Properties[numId]))
            if p and p.metadata and p.metadata.breaker_tripped then
                return false
            end
        end
    end

    return true
end

local function GetFridgeMultiplier(stashId)
    if not IsFridgeActive(stashId) then return 1.0 end
    local mult = Settings.Fridge and tonumber(Settings.Fridge.DecayMultiplier) or 10.0
    return (mult and mult > 1.0) and mult or 1.0
end

local function FormatDuration(seconds)
    if not seconds or seconds <= 0 then return "0s" end
    local d = math.floor(seconds / 86400)
    local h = math.floor((seconds % 86400) / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    local parts = {}
    if d > 0 then table.insert(parts, string.format("%dd", d)) end
    if h > 0 then table.insert(parts, string.format("%dh", h)) end
    if m > 0 then table.insert(parts, string.format("%dm", m)) end
    if s > 0 or #parts == 0 then table.insert(parts, string.format("%ds", s)) end
    return table.concat(parts, " ") .. string.format(" (%ds)", seconds)
end

local function FormatTimestamp(ts)
    if not ts or ts <= 0 then return "N/A" end
    return os.date('%Y-%m-%d %H:%M:%S', ts)
end

local function IsPerishableItem(slotData)
    if not slotData or not slotData.name or not slotData.metadata then return false end
    local durability = slotData.metadata.durability
    if not durability or type(durability) ~= 'number' or durability <= 100 then
        return false
    end
    local itemDef = exports.ox_inventory:Items(slotData.name)
    local degrade = slotData.metadata.originalDegrade or slotData.metadata.degrade or (itemDef and itemDef.degrade)
    return degrade and degrade > 0
end

local function ApplyFridgePreservation(invId, slotData, multiplier)
    if not slotData or not slotData.slot or not slotData.metadata then return end
    if slotData.metadata.inFridge then return end

    local now = os.time()
    local currentDurability = tonumber(slotData.metadata.durability)
    if not currentDurability or currentDurability <= now then
        debugPrint('info', ('[LNS_Housing:Fridge] Item: %s (Slot %d) in Fridge Stash: %s | Decay Slowed: NO (Item is already expired/spoiled)'):format(
            tostring(slotData.name), slotData.slot, tostring(invId)
        ))
        return
    end

    if not multiplier or multiplier <= 1.0 then
        debugPrint('info', ('[LNS_Housing:Fridge] Item: %s (Slot %d) in Fridge Stash: %s | Decay Slowed: NO (Multiplier is <= 1.0)'):format(
            tostring(slotData.name), slotData.slot, tostring(invId)
        ))
        return
    end

    local itemDef = exports.ox_inventory:Items(slotData.name)
    local baseDegrade = tonumber(slotData.metadata.originalDegrade) 
        or tonumber(slotData.metadata.degrade) 
        or (itemDef and tonumber(itemDef.degrade))
    if not baseDegrade or baseDegrade <= 0 then
        debugPrint('info', ('[LNS_Housing:Fridge] Item: %s (Slot %d) in Fridge Stash: %s | Decay Slowed: NO (No base degrade configured)'):format(
            tostring(slotData.name), slotData.slot, tostring(invId)
        ))
        return
    end

    local remainingSeconds = currentDurability - now
    local extendedSeconds = math.floor(remainingSeconds * multiplier)
    local newDurability = now + extendedSeconds
    local newDegrade = math.floor(baseDegrade * multiplier)

    local meta = table.clone(slotData.metadata)
    meta.inFridge = true
    meta.fridgeMultiplier = multiplier
    meta.originalDegrade = baseDegrade
    meta.durability = newDurability
    meta.degrade = newDegrade

    exports.ox_inventory:SetMetadata(invId, slotData.slot, meta)

    debugPrint('info', ('[LNS_Housing:Fridge] ---------------- Decay Analysis ----------------'))
    debugPrint('info', ('[LNS_Housing:Fridge] Item: %s (Slot %d) in Fridge Stash: %s'):format(slotData.name, slotData.slot, tostring(invId)))
    debugPrint('info', ('[LNS_Housing:Fridge] Decay Slowed: YES (Fridge Active | Multiplier: x%.1f)'):format(multiplier))
    debugPrint('info', ('[LNS_Housing:Fridge] Outside Decay Remaining: %s | Outside Expiry: %s'):format(FormatDuration(remainingSeconds), FormatTimestamp(currentDurability)))
    debugPrint('info', ('[LNS_Housing:Fridge] Inside Fridge Decay Remaining: %s | Inside Expiry: %s'):format(FormatDuration(extendedSeconds), FormatTimestamp(newDurability)))
    debugPrint('info', ('[LNS_Housing:Fridge] Lifespan Extended By: +%s (+%ds)'):format(FormatDuration(extendedSeconds - remainingSeconds), extendedSeconds - remainingSeconds))
    debugPrint('info', ('[LNS_Housing:Fridge] ------------------------------------------------'))
end

local function RemoveFridgePreservation(invId, slotData)
    if not slotData or not slotData.slot or not slotData.metadata then return end
    if not slotData.metadata.inFridge then return end

    local mult = tonumber(slotData.metadata.fridgeMultiplier) or 1.0
    local originalDegrade = tonumber(slotData.metadata.originalDegrade)
    if not originalDegrade then
        local itemDef = exports.ox_inventory:Items(slotData.name)
        originalDegrade = itemDef and tonumber(itemDef.degrade)
    end

    local now = os.time()
    local currentDurability = tonumber(slotData.metadata.durability) or now
    local remainingInFridge = currentDurability - now

    local newDurability
    local normalRemaining = 0
    if remainingInFridge <= 0 then
        newDurability = now - 1
        normalRemaining = 0
    elseif mult > 1.0 then
        normalRemaining = math.max(1, math.floor(remainingInFridge / mult))
        newDurability = now + normalRemaining
    else
        normalRemaining = math.max(0, currentDurability - now)
        newDurability = currentDurability
    end

    local meta = table.clone(slotData.metadata)
    meta.inFridge = nil
    meta.fridgeMultiplier = nil
    meta.originalDegrade = nil
    meta.durability = newDurability
    if originalDegrade then
        meta.degrade = originalDegrade
    end

    exports.ox_inventory:SetMetadata(invId, slotData.slot, meta)

    debugPrint('info', ('[LNS_Housing:Fridge] ---------------- Decay Analysis ----------------'))
    debugPrint('info', ('[LNS_Housing:Fridge] Item: %s (Slot %d) removed from Fridge / Stash: %s'):format(slotData.name, slotData.slot, tostring(invId)))
    debugPrint('info', ('[LNS_Housing:Fridge] Decay Slowed: NO (Removed from fridge stash - normal decay restored)'))
    debugPrint('info', ('[LNS_Housing:Fridge] Inside Fridge Remaining Was: %s'):format(FormatDuration(remainingInFridge)))
    debugPrint('info', ('[LNS_Housing:Fridge] Outside Decay Remaining Restored: %s | Expiry: %s'):format(FormatDuration(normalRemaining), FormatTimestamp(newDurability)))
    debugPrint('info', ('[LNS_Housing:Fridge] Normal decay rate restored (1.0x multiplier)'))
    debugPrint('info', ('[LNS_Housing:Fridge] ------------------------------------------------'))
end

local function SyncInventorySlot(invId, slotNumber, isFridge)
    if not invId or not slotNumber then return end
    local inv = exports.ox_inventory:GetInventory(invId)
    if not inv or not inv.items then return end
    local slotData = inv.items[slotNumber]
    if not slotData or not slotData.name or not slotData.metadata then return end

    if isFridge then
        local active = IsFridgeActive(invId)
        local mult = GetFridgeMultiplier(invId)
        if active and mult > 1.0 then
            if not slotData.metadata.inFridge then
                if IsPerishableItem(slotData) then
                    ApplyFridgePreservation(invId, slotData, mult)
                else
                    debugPrint('info', ('[LNS_Housing:Fridge] Item: %s (Slot %d) in Fridge Stash: %s | Decay Slowed: NO (Item is not perishable / no durability)'):format(
                        slotData.name, slotData.slot, tostring(invId)
                    ))
                end
            end
        else
            if slotData.metadata.inFridge then
                RemoveFridgePreservation(invId, slotData)
            else
                local reason = not active and "Fridge inactive (power off or disabled)" or ("Multiplier is x%.1f (must be > 1.0)"):format(mult)
                debugPrint('info', ('[LNS_Housing:Fridge] Item: %s (Slot %d) in Fridge Stash: %s | Decay Slowed: NO (%s)'):format(
                    slotData.name, slotData.slot, tostring(invId), reason
                ))
            end
        end
    else
        if slotData.metadata.inFridge then
            RemoveFridgePreservation(invId, slotData)
        end
    end
end

local function SyncFridgeInventory(invId)
    local inv = exports.ox_inventory:GetInventory(invId)
    if not inv or not inv.items then return end

    local isFridge = IsFridgeStash(invId)
    local active = isFridge and IsFridgeActive(invId)
    local mult = isFridge and GetFridgeMultiplier(invId) or 1.0

    for slotIdx, slotData in pairs(inv.items) do
        if slotData and slotData.metadata then
            if isFridge and active and mult > 1.0 then
                if IsPerishableItem(slotData) and not slotData.metadata.inFridge then
                    ApplyFridgePreservation(invId, slotData, mult)
                end
            else
                if slotData.metadata.inFridge then
                    RemoveFridgePreservation(invId, slotData)
                end
            end
        end
    end
end

local hooksInitialized = false

local function InitFridgeHooks()
    if hooksInitialized then return end
    if GetResourceState('ox_inventory') ~= 'started' then return end

    local swapHookId = exports.ox_inventory:registerHook('swapItems', function(payload)
        return true
    end)

    if swapHookId then
        AddEventHandler(swapHookId, function(success, payload)
            if not success or not payload then return end

            local fromInvId = payload.fromInventory and tostring(payload.fromInventory)
            local toInvId = payload.toInventory and tostring(payload.toInventory)
            if not fromInvId or not toInvId then return end

            local fromIsFridge = IsFridgeStash(fromInvId)
            local toIsFridge = IsFridgeStash(toInvId)

            if fromInvId == toInvId then
                if toIsFridge then
                    local toSlotNum = type(payload.toSlot) == 'table' and payload.toSlot.slot or tonumber(payload.toSlot)
                    if toSlotNum then
                        SyncInventorySlot(toInvId, toSlotNum, true)
                    end
                end
                return
            end

            if toIsFridge and not fromIsFridge then
                local toSlotNum = type(payload.toSlot) == 'table' and payload.toSlot.slot or tonumber(payload.toSlot)
                if toSlotNum then
                    SyncInventorySlot(toInvId, toSlotNum, true)
                end
            end

            if fromIsFridge and not toIsFridge then
                local toSlotNum = type(payload.toSlot) == 'table' and payload.toSlot.slot or tonumber(payload.toSlot)
                if toSlotNum then
                    SyncInventorySlot(toInvId, toSlotNum, false)
                end
            end

            if payload.action == 'swap' then
                local fromSlotNum = type(payload.fromSlot) == 'table' and payload.fromSlot.slot or tonumber(payload.fromSlot)
                if fromSlotNum then
                    SyncInventorySlot(fromInvId, fromSlotNum, fromIsFridge)
                end
            end
        end)
    end

    exports.ox_inventory:registerHook('openInventory', function(payload)
        if not payload then return true end
        local invId = payload.inventoryId and tostring(payload.inventoryId)
        if invId and IsFridgeStash(invId) then
            SyncFridgeInventory(invId)
        end
        return true
    end)

    hooksInitialized = true
    debugPrint('info', '[LNS_Housing] Refrigerator durability preservation hooks successfully initialized with ox_inventory.')
end

InitFridgeHooks()