local Settings = lib.load('shared.settings')
local Furniture = lib.load('shared.furniture')
local _furniturePrevBucket = {}

local function FindCatalogItemServer(model, itemId)
    if itemId then
        for _, category in ipairs(Furniture) do
            for _, item in ipairs(category.items) do
                if item.id == itemId then
                    return item, category.id
                end
            end
        end
    end
    if not model then return nil end
    local targetHash = tonumber(model) or GetHashKey(model)
    for _, category in ipairs(Furniture) do
        for _, item in ipairs(category.items) do
            local itemHash = tonumber(item.model) or GetHashKey(item.model)
            if itemHash == targetHash then
                return item, category.id
            end
            if item.variants then
                for _, variant in ipairs(item.variants) do
                    local varHash = tonumber(variant.model or item.model) or GetHashKey(variant.model or item.model)
                    if varHash == targetHash then
                        return item, category.id, variant
                    end
                end
            end
        end
    end
end

local function DoesItemMatchCatalogServer(placedItem, catalogItem)
    if not placedItem or not catalogItem then return false end
    if placedItem.itemId and catalogItem.id and placedItem.itemId == catalogItem.id then
        return true
    end
    if placedItem.id and catalogItem.id and placedItem.id == catalogItem.id then
        return true
    end
    if placedItem.model and catalogItem.model then
        local placedHash = tonumber(placedItem.model) or GetHashKey(placedItem.model)
        local catHash = tonumber(catalogItem.model) or GetHashKey(catalogItem.model)
        if placedHash == catHash then
            return true
        end
        if catalogItem.variants then
            for _, variant in ipairs(catalogItem.variants) do
                local varHash = tonumber(variant.model or catalogItem.model) or GetHashKey(variant.model or catalogItem.model)
                if placedHash == varHash then
                    return true
                end
            end
        end
    end
    return false
end

local function ProcessBuyFurniture(src, propertyId, items, totalPrice, paymentMethod)
    debugPrint('info', 'LNS_Housing:server:buyFurniture received', {src = src, propertyId = propertyId, totalPrice = totalPrice, paymentMethod = paymentMethod})
    local p = Properties[propertyId]
    if not p then return false, 'Property not found' end

    local identifier = Bridge.Server.GetIdentifier(src)
    local payType = paymentMethod == 'cash' and 'cash' or 'bank'
    local money = Bridge.Server.GetMoney(src, payType)

    if money < totalPrice then
        local targetAccountName = payType == 'cash' and 'cash' or 'bank account'
        Bridge.Server.Notify(src, locale('notify.not_enough_money_furniture', targetAccountName), 'error')
        return false, 'Not enough money'
    end

    local hasAccess = CheckPermission(src, 'house', propertyId, 'furniture')
    if not hasAccess then
        Bridge.Server.Notify(src, locale('notify.no_perm_buy_furniture'), 'error')
        return false, 'No permission'
    end

    if not p.furniture then p.furniture = {} end

    -- Check furniture item max limits
    for _, item in ipairs(items) do
        local catalogItem = FindCatalogItemServer(item.model, item.itemId or item.id)
        if catalogItem and catalogItem.max and catalogItem.max > 0 then
            local currentCount = 0
            for _, existing in ipairs(p.furniture) do
                if DoesItemMatchCatalogServer(existing, catalogItem) then
                    currentCount = currentCount + 1
                end
            end
            local inBatchCount = 0
            for _, batchItem in ipairs(items) do
                if DoesItemMatchCatalogServer(batchItem, catalogItem) then
                    inBatchCount = inBatchCount + 1
                end
            end
            if currentCount + inBatchCount > catalogItem.max then
                local itemName = catalogItem.label or item.label or item.model
                Bridge.Server.Notify(src, locale('notify.furniture_limit_reached', catalogItem.max, itemName), 'error')
                return false, 'Furniture limit reached'
            end
        end
    end

    local removed = Bridge.Server.RemoveMoney(src, payType, totalPrice, "Bought furniture for house #" .. propertyId)
    if not removed and totalPrice > 0 then
        Bridge.Server.Notify(src, locale('notify.could_not_process_payment'), 'error')
        return false, 'Payment failed'
    end

    if not p.furniture then p.furniture = {} end
    for _, item in ipairs(items) do
        table.insert(p.furniture, item)
    end

    SaveProperty(propertyId)
    if CalculatePropertyPowerAndTemp then CalculatePropertyPowerAndTemp(propertyId) end
    if Bridge and Bridge.Server and Bridge.Server.RegisterPropertyStashes then
        Bridge.Server.RegisterPropertyStashes(propertyId, p.furniture)
    end
    TriggerClientEvent('LNS_Housing:client:updateFurniture', -1, propertyId, p.furniture)
    Bridge.Server.Notify(src, locale('notify.furniture_purchased'), 'success')
    return true
end

lib.callback.register('LNS_Housing:server:buyFurniture', function(source, propertyId, items, totalPrice, paymentMethod)
    return ProcessBuyFurniture(source, propertyId, items, totalPrice, paymentMethod)
end)

RegisterNetEvent('LNS_Housing:server:buyFurniture', function(propertyId, items, totalPrice, paymentMethod)
    ProcessBuyFurniture(source, propertyId, items, totalPrice, paymentMethod)
end)

RegisterNetEvent('LNS_Housing:server:saveFurniture', function(propertyId, furnitureData)
    local src = source
    debugPrint('info', 'LNS_Housing:server:saveFurniture received', {src = src, propertyId = propertyId, itemsCount = furnitureData and #furnitureData or 0})
    local p = Properties[propertyId]
    if p then
        local identifier = Bridge.Server.GetIdentifier(src)
        local hasAccess = CheckPermission(src, 'house', propertyId, 'furniture')
        if not hasAccess then return end

        -- Check that no furniture item exceeds catalog max
        local counts = {}
        for _, f in ipairs(furnitureData or {}) do
            local catalogItem = FindCatalogItemServer(f.model, f.itemId or f.id)
            if catalogItem and catalogItem.max and catalogItem.max > 0 then
                counts[catalogItem.id] = (counts[catalogItem.id] or 0) + 1
                if counts[catalogItem.id] > catalogItem.max then
                    local itemName = catalogItem.label or f.label or f.model
                    Bridge.Server.Notify(src, locale('notify.furniture_limit_reached', catalogItem.max, itemName), 'error')
                    return
                end
            end
        end

        p.furniture = furnitureData
        SaveProperty(propertyId)
        if CalculatePropertyPowerAndTemp then CalculatePropertyPowerAndTemp(propertyId) end
        if Bridge and Bridge.Server and Bridge.Server.RegisterPropertyStashes then
            Bridge.Server.RegisterPropertyStashes(propertyId, p.furniture)
        end
        TriggerClientEvent('LNS_Housing:client:updateFurniture', -1, propertyId, p.furniture)
        return
    end

    local hasAptAccess = CheckPermission(src, 'apartment', propertyId, 'furniture')
    if hasAptAccess then
        local citizenid = Bridge.Server.GetIdentifier(src)
        if citizenid then
            MySQL.update.await('UPDATE apartments SET furniture = ? WHERE (room_id = ? OR room_id = ?)', {
                json.encode(furnitureData or {}),
                propertyId,
                tostring(propertyId)
            })

            if Bridge and Bridge.Server and Bridge.Server.RegisterPropertyStashes then
                Bridge.Server.RegisterPropertyStashes(propertyId, furnitureData)
            end

            TriggerClientEvent('LNS_Housing:client:updateApartmentFurniture', -1, propertyId, furnitureData)
        end
    end
end)

function RegisterStash(propertyId, furnitureId, config)
    Bridge.Server.RegisterStash(propertyId, furnitureId, config)
end

RegisterNetEvent('LNS_Housing:server:logoutPlayer', function()
    local src = source
    debugPrint('info', 'LNS_Housing:server:logoutPlayer received', {src = src})
    SetPlayerRoutingBucket(src, 0)
    Bridge.Server.Logout(src)
end)

RegisterNetEvent('LNS_Housing:server:enterFurnitureBucket', function(propertyId)
    local src = source
    debugPrint('info', 'LNS_Housing:server:enterFurnitureBucket received', {src = src, propertyId = propertyId})
    _furniturePrevBucket[src] = GetPlayerRoutingBucket(src)
    local furnitureBucket = 50000 + tonumber(propertyId)
    SetPlayerRoutingBucket(src, furnitureBucket)
end)

RegisterNetEvent('LNS_Housing:server:leaveFurnitureBucket', function()
    local src = source
    debugPrint('info', 'LNS_Housing:server:leaveFurnitureBucket received', {src = src})
    local prevBucket = _furniturePrevBucket[src] or 0
    _furniturePrevBucket[src] = nil
    SetPlayerRoutingBucket(src, prevBucket)
end)

AddEventHandler('playerDropped', function()
    _furniturePrevBucket[source] = nil
end)

lib.callback.register('LNS_Housing:server:getFurnitureImages', function(source)
    debugPrint('info', 'LNS_Housing:server:getFurnitureImages called', {source = source})
    local success, mappings = pcall(function()
        return exports.LNS_Housing:GetImageMappings()
    end)
    if success and mappings then
        return mappings
    end
    return {}
end)

lib.addCommand('checkfurniture', {
    help = 'Audit all furniture prop models to verify valid assets (Admin only)',
    params = {
        {
            name = 'category',
            type = 'string',
            help = 'Specific category or model name to audit (optional, defaults to all)',
            optional = true,
        },
    },
}, function(source, args, raw)
    debugPrint('info', 'Command /checkfurniture executed', {source = source})
    if not CheckPermission(source, 'admin') then
        Bridge.Server.Notify(source, locale('notify.no_perm_command'), 'error')
        return
    end

    TriggerClientEvent('LNS_Housing:client:checkFurniture', source)
end)