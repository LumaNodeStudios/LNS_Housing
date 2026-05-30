if Bridge.Framework == 'qbx' then
    Bridge.Server.GetIdentifier = function(source)
        local player = exports.qbx_core:GetPlayer(source)
        return player and player.PlayerData.citizenid
    end

    Bridge.Server.GetPlayerName = function(source)
        local player = exports.qbx_core:GetPlayer(source)
        if player and player.PlayerData.charinfo then
            return player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname
        end
        return 'Unknown'
    end

    Bridge.Server.GetPlayerJob = function(source)
        local player = exports.qbx_core:GetPlayer(source)
        if player and player.PlayerData.job then
            return {
                name = player.PlayerData.job.name,
                label = player.PlayerData.job.label,
                grade = player.PlayerData.job.grade.level,
                grade_name = player.PlayerData.job.grade.name
            }
        end
        return nil
    end

    Bridge.Server.IsPlayerOnline = function(identifier)
        return exports.qbx_core:GetPlayerByCitizenId(identifier)
    end

    Bridge.Server.CreateUseableItem = function(name, callback)
        exports.qbx_core:CreateUseableItem(name, function(source, item)
            callback(source)
        end)
    end
elseif Bridge.Framework == 'esx' then
    local ESX = exports['es_extended']:getSharedObject()

    Bridge.Server.GetIdentifier = function(source)
        local player = ESX.GetPlayerFromId(source)
        return player and player.identifier
    end

    Bridge.Server.GetPlayerName = function(source)
        local player = ESX.GetPlayerFromId(source)
        return player and player.getName() or 'Unknown'
    end

    Bridge.Server.GetPlayerJob = function(source)
        local player = ESX.GetPlayerFromId(source)
        if player and player.job then
            return {
                name = player.job.name,
                label = player.job.label,
                grade = player.job.grade,
                grade_name = player.job.grade_label
            }
        end
        return nil
    end

    Bridge.Server.IsPlayerOnline = function(identifier)
        local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
        if not xPlayer then return nil end
        return {
            PlayerData = {
                source = xPlayer.source
            },
            Functions = {
                RemoveMoney = function(account, amount, reason)
                    xPlayer.removeAccountMoney('bank', amount)
                end
            }
        }
    end

    Bridge.Server.CreateUseableItem = function(name, callback)
        ESX.RegisterUsableItem(name, function(source)
            callback(source)
        end)
    end
end