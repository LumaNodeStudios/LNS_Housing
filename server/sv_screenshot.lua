lib.callback.register('LNS_Housing:server:getScreenshotPermission', function(source)
    if Bridge.Framework == 'esx' then
        local ESX = exports['es_extended']:getSharedObject()
        local player = ESX.GetPlayerFromId(source)
        if player then
            local group = player.getGroup()
            return group == 'admin' or group == 'god' or group == 'superadmin'
        end
    else
        return IsPlayerAceAllowed(source, 'admin')
    end
    return false
end)