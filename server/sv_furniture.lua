local Settings = lib.load('shared.settings')

RegisterNetEvent('LNS_Housing:server:buyFurniture', function(propertyId, items, totalPrice, paymentMethod)
    local src = source
    debugPrint('info', 'LNS_Housing:server:buyFurniture received', {src = src, propertyId = propertyId, totalPrice = totalPrice, paymentMethod = paymentMethod})
    local p = Properties[propertyId]
    if not p then return end

    local identifier = Bridge.Server.GetIdentifier(src)
    local payType = paymentMethod == 'cash' and 'cash' or 'bank'
    local money = Bridge.Server.GetMoney(src, payType)

    if money < totalPrice then
        local targetAccountName = payType == 'cash' and 'cash' or 'bank account'
        Bridge.Server.Notify(src, 'Not enough money in your ' .. targetAccountName .. '!', 'error')
        return
    end

    local hasAccess = CheckPermission(src, 'house', propertyId, 'furniture')
    if not hasAccess then return end

    Bridge.Server.RemoveMoney(src, payType, totalPrice, "Bought furniture for house #" .. propertyId)

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
end)

RegisterNetEvent('LNS_Housing:server:saveFurniture', function(propertyId, furnitureData)
    local src = source
    debugPrint('info', 'LNS_Housing:server:saveFurniture received', {src = src, propertyId = propertyId, itemsCount = furnitureData and #furnitureData or 0})
    local p = Properties[propertyId]
    if not p then return end

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