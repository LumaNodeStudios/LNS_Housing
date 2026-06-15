Bridge.Client = {}

local ESX = Bridge.Framework == 'esx' and exports['es_extended']:getSharedObject() or nil

function Bridge.Client.GetIdentifier()
    if Bridge.Framework == 'qbx' then
        local data = exports.qbx_core:GetPlayerData()
        return data and data.citizenid
    elseif Bridge.Framework == 'esx' then
        local data = ESX.GetPlayerData()
        return data and data.identifier
    end
end

function Bridge.Client.GetPlayerName()
    if Bridge.Framework == 'qbx' then
        local data = exports.qbx_core:GetPlayerData()
        if data and data.charinfo then
            return data.charinfo.firstname .. ' ' .. data.charinfo.lastname
        end
        return 'Unknown'
    elseif Bridge.Framework == 'esx' then
        local data = ESX.GetPlayerData()
        if data then
            if data.firstName and data.lastName then
                return data.firstName .. ' ' .. data.lastName
            elseif data.name then
                return data.name
            end
        end
        return 'Unknown'
    end
end

function Bridge.Client.GetPlayerJob()
    if Bridge.Framework == 'qbx' then
        local data = exports.qbx_core:GetPlayerData()
        if data and data.job then
            return {
                name = data.job.name,
                label = data.job.label,
                grade = data.job.grade.level,
                grade_name = data.job.grade.name
            }
        end
    elseif Bridge.Framework == 'esx' then
        local data = ESX.GetPlayerData()
        if data and data.job then
            return {
                name = data.job.name,
                label = data.job.label,
                grade = data.job.grade,
                grade_name = data.job.grade_label
            }
        end
    end
    return nil
end

function Bridge.Client.OpenWardrobe(propertyId, furnitureId)
    if GetResourceState('illenium-appearance') == 'started' then
        TriggerEvent('illenium-appearance:client:openOutfitMenu')
    else
        print('No clothing/appearance menu found!')
    end
end

function Bridge.Client.OpenStash(propertyId, furnitureId)
    if GetResourceState('ox_inventory') == 'started' then
        local stashId = string.format('housing_%d_%s', propertyId, furnitureId)
        exports.ox_inventory:openInventory('stash', stashId)
    else
        print('No inventory found!')
    end
end

function Bridge.Client.Notify(msg, type)
    lib.notify({
        description = msg,
        type = type or 'inform'
    })
end

function Bridge.Client.Dispatch(coords, title, message)
    if GetResourceState('ps-dispatch') == 'started' then
        exports['ps-dispatch']:CustomAlert({
            coords = coords,
            message = message,
            dispatchCode = "10-31A",
            description = title,
            gender = nil,
            playAlertSound = true,
            priority = 1,
            recipientList = { police = true },
            info = { { icon = "fas fa-house", label = title } }
        })
        return true
    elseif GetResourceState('qs-dispatch') == 'started' then
        exports['qs-dispatch']:GetDispatchAlert({
            job = { 'police' },
            callSign = '10-31',
            message = message,
            flashingBlip = true,
            uniqueId = tostring(math.random(10000, 99999)),
            targetCoords = coords,
            description = title,
            sprite = 40,
            color = 1,
            scale = 1.0
        })
        return true
    elseif GetResourceState('cd_dispatch') == 'started' then
        local data = {
            message = message,
            coords = coords,
            job = 'police',
            title = title,
            code = '10-31',
            priority = 1,
            flash = true,
            sprite = 40,
            color = 1,
            scale = 1.0
        }
        TriggerEvent('cd_dispatch:AddNotification', data)
        return true
    elseif GetResourceState('linden_dispatch') == 'started' then
        local data = {
            code = '10-31',
            title = title,
            coords = coords,
            message = message,
            priority = 1,
            recipient = 'police'
        }
        TriggerEvent('linden_dispatch:addAlert', data)
        return true
    end

    -- Fallback to server side notify
    TriggerServerEvent('LNS_Housing:server:notifyPoliceFallback', message)
    return false
end

RegisterNetEvent('LNS_Housing:client:triggerDispatch', function(coords, title, message)
    Bridge.Client.Dispatch(coords, title, message)
end)