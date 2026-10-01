Bridge.Client = {}

local Settings = lib.load('shared.settings')
local ESX = Bridge.Framework == 'esx' and exports['es_extended']:getSharedObject() or nil
local clientGarageZones = {}
local cachedIdentifier = nil
local cachedPlayerName = nil
local cachedJob = nil

if Bridge.Framework == 'qbx' then
    AddEventHandler('QBCore:Client:OnPlayerLoaded',function()
        cachedIdentifier = nil
        cachedPlayerName = nil
        cachedJob = nil
    end)

    RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
        cachedIdentifier = nil
        cachedPlayerName = nil
        cachedJob = nil
    end)

    RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
        if job then
            cachedJob = {
                name = job.name,
                label = job.label,
                grade = job.grade and job.grade.level or job.grade,
                grade_name = job.grade and job.grade.name or job.grade_name
            }
        else
            cachedJob = nil
        end
    end)
elseif Bridge.Framework == 'esx' then
    RegisterNetEvent('esx:playerLoaded', function()
        cachedIdentifier = nil
        cachedPlayerName = nil
        cachedJob = nil
    end)

    RegisterNetEvent('esx:setJob', function(job)
        if job then
            cachedJob = {
                name = job.name,
                label = job.label,
                grade = job.grade,
                grade_name = job.grade_label
            }
        else
            cachedJob = nil
        end
    end)
end

-- Player Data Getters
function Bridge.Client.GetIdentifier()
    if cachedIdentifier then return cachedIdentifier end
    if Bridge.Framework == 'qbx' then
        local data = exports.qbx_core:GetPlayerData()
        if data and data.citizenid then
            cachedIdentifier = data.citizenid
            return cachedIdentifier
        end
    elseif Bridge.Framework == 'esx' then
        local data = ESX.GetPlayerData()
        if data and data.identifier then
            cachedIdentifier = data.identifier
            return cachedIdentifier
        end
    end
    return nil
end

function Bridge.Client.GetPlayerName()
    if cachedPlayerName then return cachedPlayerName end
    if Bridge.Framework == 'qbx' then
        local data = exports.qbx_core:GetPlayerData()
        if data and data.charinfo then
            cachedPlayerName = data.charinfo.firstname .. ' ' .. data.charinfo.lastname
            return cachedPlayerName
        end
        return 'Unknown'
    elseif Bridge.Framework == 'esx' then
        local data = ESX.GetPlayerData()
        if data then
            if data.firstName and data.lastName then
                cachedPlayerName = data.firstName .. ' ' .. data.lastName
                return cachedPlayerName
            elseif data.name then
                cachedPlayerName = data.name
                return cachedPlayerName
            end
        end
        return 'Unknown'
    end
    return 'Unknown'
end

function Bridge.Client.GetPlayerJob()
    if cachedJob then return cachedJob end
    if Bridge.Framework == 'qbx' then
        local data = exports.qbx_core:GetPlayerData()
        if data and data.job then
            cachedJob = {
                name = data.job.name,
                label = data.job.label,
                grade = data.job.grade and data.job.grade.level or 0,
                grade_name = data.job.grade and data.job.grade.name or ''
            }
            return cachedJob
        end
    elseif Bridge.Framework == 'esx' then
        local data = ESX.GetPlayerData()
        if data and data.job then
            cachedJob = {
                name = data.job.name,
                label = data.job.label,
                grade = data.job.grade,
                grade_name = data.job.grade_label
            }
            return cachedJob
        end
    end
    return nil
end

-- Integrations & Utility Wrappers
function Bridge.Client.OpenWardrobe(propertyId, furnitureId)
    debugPrint('info', 'Opening wardrobe', {propertyId = propertyId, furnitureId = furnitureId})
    if GetResourceState('illenium-appearance') == 'started' then
        TriggerEvent('illenium-appearance:client:openOutfitMenu')
    else
        debugPrint('error', 'No clothing/appearance menu found!')
    end
end

function Bridge.Client.OpenStash(propertyId, furnitureId)
    debugPrint('info', 'Opening stash', {propertyId = propertyId, furnitureId = furnitureId})
    if GetResourceState('ox_inventory') == 'started' then
        local stashId = string.format('housing_%d_%s', propertyId, furnitureId)
        exports.ox_inventory:openInventory('stash', stashId)
    else
        debugPrint('error', 'No inventory found!')
    end
end

function Bridge.Client.Notify(msg, type)
    debugPrint('info', 'Client notification', {msg = msg, type = type})
    lib.notify({
        description = msg,
        type = type or 'inform'
    })
end

--- Skill Check / Minigame
function Bridge.Client.SkillCheck(difficulty, inputs)
    debugPrint('info', 'SkillCheck minigame started', {difficulty = difficulty, inputs = inputs})
    local keys = inputs or { 'w', 'a', 's', 'd' }
    return lib.skillCheck(difficulty, keys)
end

-- Dispatch Alerts
function Bridge.Client.Dispatch(coords, title, message)
    debugPrint('info', 'Dispatch alert triggered', {coords = coords, title = title, message = message})
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
    debugPrint('debug', 'LNS_Housing:client:triggerDispatch event received', {coords = coords, title = title, message = message})
    Bridge.Client.Dispatch(coords, title, message)
end)

-- Garage Zone Management
function Bridge.Client.RegisterGarage(propertyId, label, garageData)
    debugPrint('info', 'Registering garage', {propertyId = propertyId, label = label, garageData = garageData})
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
                debugPrint('debug', 'Garage zone onEnter', {propertyId = propertyId})
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
                    debugPrint('debug', 'Garage zone interaction triggered', {propertyId = propertyId})
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
                debugPrint('debug', 'Garage zone onExit', {propertyId = propertyId})
                hasAccess = false
                lib.hideTextUI()
            end
        })
    end
end

function Bridge.Client.UnregisterGarage(propertyId)
    debugPrint('info', 'Unregistering garage', {propertyId = propertyId})
    if clientGarageZones[propertyId] then
        clientGarageZones[propertyId]:remove()
        clientGarageZones[propertyId] = nil
    end
end

-- Phone Scripts
function Bridge.Client.PhoneNotification(data)
    debugPrint('info', 'Sending phone notification', data)
    if Bridge.PhoneScript == 'sd-phone' then
        exports['sd-phone']:showNotification({
            title = data.title,
            body = data.body,
        })
        return true
    elseif Bridge.PhoneScript == 'lb-phone' then
        exports['lb-phone']:SendNotification({
            title = data.title,
            content = data.body
        })
        return true
    elseif Bridge.PhoneScript == 'roadphone' then
        exports['roadphone']:sendNotification({
            title = data.title,
            message = data.body
        })
        return true
    elseif Bridge.PhoneScript == 'yseries' then
        return false
    end

    return false
end

function Bridge.Client.LoadAudioBank(bankName, timeoutMs)
    debugPrint('info', 'Bridge.Client.LoadAudioBank', {bankName = bankName, framework = Bridge.Framework})
    if Bridge.Framework == 'qbx' then
        return qbx.loadAudioBank(bankName, timeoutMs)
    else
        local loaded = RequestScriptAudioBank(bankName, false, -1)
        if loaded then return true end
        local deadline = GetGameTimer() + (timeoutMs or 5000)
        while not loaded and GetGameTimer() < deadline do
            Wait(100)
            loaded = RequestScriptAudioBank(bankName, false, -1)
        end
        return loaded
    end
end

function Bridge.Client.PlayAudio(opts)
    debugPrint('info', 'Bridge.Client.PlayAudio', {audioName = opts.audioName, framework = Bridge.Framework})
    if Bridge.Framework == 'qbx' then
        return qbx.playAudio(opts)
    else
        local src = opts.audioSource
        local soundId = GetSoundId()
        PlaySoundFromCoord(soundId, opts.audioName, src.x, src.y, src.z, opts.audioRef, false, opts.range or 10.0, false)
        if opts.returnSoundId then
            return soundId
        else
            CreateThread(function()
                Wait(10000)
                StopSound(soundId)
                ReleaseSoundId(soundId)
            end)
            return nil
        end
    end
end