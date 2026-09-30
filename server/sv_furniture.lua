local Settings = lib.load('shared.settings')
local _furniturePrevBucket = {}

local function ProcessBuyFurniture(src, propertyId, items, totalPrice, paymentMethod)
    debugPrint('info', 'LNS_Housing:server:buyFurniture received', {src = src, propertyId = propertyId, totalPrice = totalPrice, paymentMethod = paymentMethod})
    local p = Properties[propertyId]
    if not p then return false, 'Property not found' end

    local identifier = Bridge.Server.GetIdentifier(src)
    local payType = paymentMethod == 'cash' and 'cash' or 'bank'
    local money = Bridge.Server.GetMoney(src, payType)

    if money < totalPrice then
        local targetAccountName = payType == 'cash' and 'cash' or 'bank account'
        Bridge.Server.Notify(src, 'Not enough money in your ' .. targetAccountName .. '!', 'error')
        return false, 'Not enough money'
    end

    local hasAccess = CheckPermission(src, 'house', propertyId, 'furniture')
    if not hasAccess then
        Bridge.Server.Notify(src, 'You do not have permission to buy furniture here.', 'error')
        return false, 'No permission'
    end

    local removed = Bridge.Server.RemoveMoney(src, payType, totalPrice, "Bought furniture for house #" .. propertyId)
    if not removed and totalPrice > 0 then
        Bridge.Server.Notify(src, 'Could not process payment.', 'error')
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
    Bridge.Server.Notify(src, 'Furniture purchased successfully!', 'success')
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
    local stashId = string.format('housing_%d_%s', propertyId, furnitureId)
    exports.ox_inventory:RegisterStash(stashId, Settings.Stash.label, Settings.Stash.slots, Settings.Stash.weight)
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