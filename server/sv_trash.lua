local Settings = lib.load('shared.settings')
local TrashStashes = {}

function RegisterTrashStash(stashId, propertyId, furnitureId)
    if not stashId then return end
    local strId = tostring(stashId)
    TrashStashes[strId] = {
        propertyId = propertyId,
        furnitureId = furnitureId,
        registeredAt = os.time()
    }
    debugPrint('info', '[LNS_Housing:Trash] Registered trash stash:', strId, 'property:', propertyId)

    if Bridge and Bridge.Server and Bridge.Server.ClearInventory then
        Bridge.Server.ClearInventory(strId)
    end
end

function IsTrashStash(stashId)
    if not stashId then return false, nil end
    local strId = tostring(stashId)
    if TrashStashes[strId] then
        return true, TrashStashes[strId]
    end

    local propId, furnId = strId:match('housing_([^_]+)_(.+)')
    if propId and furnId then
        local furnitureList = nil
        local p = Properties and (Properties[propId] or (tonumber(propId) and Properties[tonumber(propId)]))
        if p and p.furniture then
            furnitureList = p.furniture
        else
            local row = MySQL.single.await('SELECT furniture FROM apartments WHERE room_id = ? OR room_id = ?', { propId, tostring(propId) })
            if row and row.furniture then
                local ok, decoded = pcall(json.decode, row.furniture)
                if ok and type(decoded) == 'table' then
                    furnitureList = decoded
                end
            end
        end

        if furnitureList then
            for _, f in ipairs(furnitureList) do
                if tostring(f.id) == tostring(furnId) then
                    local itemData = nil
                    for _, cat in ipairs(Furniture) do
                        for _, item in ipairs(cat.items) do
                            if (tonumber(item.model) or GetHashKey(item.model)) == (tonumber(f.model) or GetHashKey(f.model)) then
                                itemData = item
                                break
                            end
                        end
                        if itemData then break end
                    end
                    if itemData and (itemData.isTrash or itemData.type == 'trash' or itemData.isDisposal or itemData.type == 'disposal') then
                        TrashStashes[strId] = {
                            propertyId = propId,
                            furnitureId = furnId,
                            registeredAt = os.time()
                        }
                        return true, TrashStashes[strId]
                    end
                end
            end
        end
    end

    local lower = strId:lower()
    if lower:find('trash') or lower:find('dumpster') then
        return true, nil
    end

    return false, nil
end

local function DestroyTrashItems(stashId, playerId)
    if not Settings.TrashCan or Settings.TrashCan.Enabled == false then return 0 end
    local strId = tostring(stashId)

    if not Bridge or not Bridge.Server then return 0 end

    local items = Bridge.Server.GetInventoryItems(strId)
    local itemCount = 0
    for _, item in pairs(items) do
        if item then
            itemCount = itemCount + 1
        end
    end

    if itemCount > 0 then
        Bridge.Server.ClearInventory(strId)
        debugPrint('info', ('[LNS_Housing:Trash] Stash %s emptied (%d items permanently destroyed)'):format(strId, itemCount))

        if playerId and playerId > 0 then
            if Settings.TrashCan.NotifyOnDestroy ~= false then
                Bridge.Server.Notify(playerId, 'Items placed in the trash can were permanently destroyed.', 'inform')
            end
        end
        return itemCount
    end

    return 0
end

if Bridge and Bridge.Server and Bridge.Server.OnClosedInventory then
    Bridge.Server.OnClosedInventory(function(playerId, invId)
        if not invId then return end
        local isTrash = IsTrashStash(invId)
        if not isTrash then return end

        if Settings.TrashCan and Settings.TrashCan.DestroyOnClose == false then return end

        SetTimeout(50, function()
            DestroyTrashItems(invId, playerId)
        end)
    end)
end

local trashHookInitialized = false
local function InitTrashHooks()
    if trashHookInitialized then return end
    if not Bridge or not Bridge.Server or not Bridge.Server.RegisterInventoryHook then return end

    Bridge.Server.RegisterInventoryHook('openInventory', function(payload)
        if not payload or not payload.inventoryId then return true end
        local invId = tostring(payload.inventoryId)
        if IsTrashStash(invId) then
            Bridge.Server.ClearInventory(invId)
        end
        return true
    end)

    trashHookInitialized = true
    debugPrint('info', '[LNS_Housing] Trash disposal hooks successfully initialized via bridge.')
end

InitTrashHooks()