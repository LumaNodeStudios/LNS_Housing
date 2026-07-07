Bridge.Client = {}

local Settings = lib.load('shared.settings')
local ESX = Bridge.Framework == 'esx' and exports['es_extended']:getSharedObject() or nil
local clientGarageZones = {}

-- Player Data Getters
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

-- Integrations & Utility Wrappers
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

-- Dispatch Alerts
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

    TriggerServerEvent('LNS_Housing:server:notifyPoliceFallback', message)
    return false
end

RegisterNetEvent('LNS_Housing:client:triggerDispatch', function(coords, title, message)
    Bridge.Client.Dispatch(coords, title, message)
end)

-- Garage Zone Management
function Bridge.Client.RegisterGarage(propertyId, label, garageData)
    if Bridge.GarageScript == 'jg-advancedgarages' or Bridge.GarageScript == 'cd_garage' or Bridge.GarageScript == 'op-garages' then
        local garageName = string.format("property-%s-garage", propertyId)
        if clientGarageZones[propertyId] then
            clientGarageZones[propertyId]:remove()
            clientGarageZones[propertyId] = nil
        end
        
        local hasAccess = false
        clientGarageZones[propertyId] = lib.zones.box({
            coords = vector3(garageData.x, garageData.y, garageData.z),
            size = vector3(5.0, 5.0, 4.0),
            rotation = garageData.h or 0.0,
            debug = Settings.Debug.Zones,
            onEnter = function()
                hasAccess = lib.callback.await('LNS_Housing:server:checkPermission', false, 'house', propertyId, 'entry')
                if not hasAccess then return end
                
                if cache.ped and IsPedInAnyVehicle(cache.ped, true) then
                    lib.showTextUI('Press [E] to store vehicle')
                else
                    lib.showTextUI('Press [E] to open garage')
                end
            end,
            inside = function()
                if not hasAccess then return end
                if IsControlJustReleased(0, 38) then
                    Wait(100)
                    if Bridge.GarageScript == 'op-garages' then
                        local spawn = garageData.spawn or garageData
                        local spawnCoords = vector4(spawn.x, spawn.y, spawn.z, spawn.h or 0.0)
                        exports['op-garages']:OpenGarageHere(spawnCoords, true)
                    else
                        if cache.ped and IsPedInAnyVehicle(cache.ped, true) then
                            if Bridge.GarageScript == 'jg-advancedgarages' then
                                TriggerEvent('jg-advancedgarages:client:store-vehicle', garageName, "car")
                            elseif Bridge.GarageScript == 'cd_garage' then
                                TriggerEvent('cd_garage:StoreVehicle_Main', 1, false, false)
                            end
                        else
                            if Bridge.GarageScript == 'jg-advancedgarages' then
                                local spawn = garageData.spawn or garageData
                                local spawnCoords = vector4(spawn.x, spawn.y, spawn.z, spawn.h or 0.0)
                                TriggerEvent('jg-advancedgarages:client:open-garage', garageName, "car", spawnCoords)
                            elseif Bridge.GarageScript == 'cd_garage' then
                                TriggerEvent('cd_garage:PropertyGarage', 'quick', nil)
                            end
                        end
                    end
                end
            end,
            onExit = function()
                hasAccess = false
                lib.hideTextUI()
            end
        })
    end
end

function Bridge.Client.UnregisterGarage(propertyId)
    if clientGarageZones[propertyId] then
        clientGarageZones[propertyId]:remove()
        clientGarageZones[propertyId] = nil
    end
end