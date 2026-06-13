local Settings = lib.load('shared.settings')

RegisterNetEvent('LNS_Housing:server:finishMowing', function(propertyId, mowedIndices, isFullMow)
    local src = source
    local p = Properties[propertyId]
    if not p then return end

    local now = os.time()
    if not p.lawn_data then p.lawn_data = {} end

    if mowedIndices and #mowedIndices > 0 then
        for _, idx in ipairs(mowedIndices) do
            p.lawn_data[tostring(idx)] = now
        end
        TriggerClientEvent('LNS_Housing:client:syncCutGrass', -1, propertyId, mowedIndices)
    end

    if isFullMow then
        p.last_mowed = now
    end

    SaveProperty(propertyId)
    TriggerClientEvent('LNS_Housing:client:syncLawnUpdate', -1, propertyId, p.lawn_data, p.last_mowed)
end)

RegisterNetEvent('LNS_Housing:server:saveMowedBlades', function(propertyId, mowedIndices, isEnd)
    local src = source
    local p = Properties[propertyId]
    if not p or not mowedIndices or #mowedIndices == 0 then return end

    local now = os.time()
    if not p.lawn_data then p.lawn_data = {} end

    for _, idx in ipairs(mowedIndices) do
        p.lawn_data[tostring(idx)] = now
    end

    TriggerClientEvent('LNS_Housing:client:syncCutGrass', -1, propertyId, mowedIndices)

    if isEnd then
        SaveProperty(propertyId)
    end
end)

lib.callback.register('LNS_Housing:server:getServerTime', function(source)
    return os.time()
end)

Bridge.Server.CreateUseableItem(Settings.Housing.Lawn.RequireItem, function(source)
    TriggerClientEvent('LNS_Housing:client:useMower', source)
end)