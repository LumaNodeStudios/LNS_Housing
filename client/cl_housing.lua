local Settings = lib.load('shared.settings')
local Furniture = lib.load('shared.furniture')
Properties = {}
EntranceTargets = {}
local CurrentProperty = nil
local CurrentInterior = 0
local PropertyBlips = {}
local ClearPropertyBlips, UpdatePropertyBlips


RegisterCommand(Settings.Housing.Creator.Command, function(source, args, rawCommand)
    local hasPermission = lib.callback.await('LNS_Housing:server:getRealEstatePermission', false)
    if not hasPermission then
        Bridge.Client.Notify('You do not have permission to use this command.', 'error')
        return
    end

    local properties = lib.callback.await('LNS_Housing:server:getProperties', false)
    SendNUIMessage({
        action = 'openRealEstate',
        data = {
            properties = properties,
            hasPermission = true,
            activeTab = 'creator',
            onlyBuyViaContracts = Settings.RealEstate.OnlyBuyViaContracts
        }
    })
    SetNuiFocus(true, true)
end, false)


RegisterNUICallback('createHouse', function(data, cb)
    SetNuiFocus(false, false)
    local success = lib.callback.await('LNS_Housing:server:createHouse', false, data)
    if success then
        Bridge.Client.Notify('House created successfully!', 'success')
    else
        Bridge.Client.Notify('Failed to create house.', 'error')
    end
    SendNUIMessage({ action = 'closeUI' })
    cb('ok')
end)

RegisterNUICallback('closeUI', function(_, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeUI' })
    cb('ok')
end)


RegisterNUICallback('placeBid', function(data, cb)
    TriggerServerEvent('LNS_Housing:server:placeBid', data)
    cb('ok')
end)

RegisterNUICallback('controlAuction', function(data, cb)
    TriggerServerEvent('LNS_Housing:server:controlAuction', data)
    cb('ok')
end)

RegisterNUICallback('getNearbyPlayers', function(_, cb)
    local players = GetActivePlayers()
    local playerIds = {}
    for _, player in ipairs(players) do
        table.insert(playerIds, GetPlayerServerId(player))
    end
    
    local resolved = lib.callback.await('LNS_Housing:server:resolvePlayerNames', false, playerIds)
    cb(resolved or {})
end)

RegisterNUICallback('createContract', function(data, cb)
    SetNuiFocus(false, false)
    TriggerServerEvent('LNS_Housing:server:createContract', data)
    SendNUIMessage({ action = 'closeUI' })
    cb('ok')
end)

RegisterNUICallback('getPendingContracts', function(_, cb)
    local results = lib.callback.await('LNS_Housing:server:getPendingContracts', false)
    cb(results or {})
end)

RegisterNUICallback('getAgencyContracts', function(data, cb)
    local results = lib.callback.await('LNS_Housing:server:getAgencyContracts', false, data.agency)
    cb(results or {})
end)

RegisterNUICallback('respondToContract', function(data, cb)
    SetNuiFocus(false, false)
    local success = lib.callback.await('LNS_Housing:server:respondToContract', false, data.id, data.action)
    SendNUIMessage({ action = 'closeUI' })
    cb(success)
end)

function LockpickDoor(propertyId)
    local p = Properties[propertyId]
    if not p then return end

    local securityLevel = p.metadata and p.metadata.security_level or 0
    local config = Settings.Security.Difficulty[securityLevel] or Settings.Security.Difficulty[0]

    if lib.progressBar({
        duration = 5000,
        label = 'Attempting to pick lock...',
        useWhileDead = false,
        canCancel = true,
        disable = { car = true, move = true },
        anim = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'ig_3_con_loop' }
    }) then
        local success = lib.skillCheck(table.create(config.rounds, 0), { 'w', 'a', 's', 'd' })
        
        if success then
            TriggerServerEvent('LNS_Housing:server:lockpickSuccess', propertyId, 'door')
            Bridge.Client.Notify('You successfully picked the lock!', 'success')
        else
            Bridge.Client.Notify('You failed to pick the lock.', 'error')
            
        end
    end
end

function LockpickStash(propertyId, stashId)
    local p = Properties[propertyId]
    if not p then return end

    local securityLevel = p.metadata and p.metadata.security_level or 0
    local config = Settings.Security.Difficulty[securityLevel] or Settings.Security.Difficulty[0]

    if lib.progressBar({
        duration = 8000,
        label = 'Attempting to pick stash lock...',
        useWhileDead = false,
        canCancel = true,
        disable = { car = true, move = true },
        anim = { dict = 'anim@amb@prop_human_atm@interior@male@enter', clip = 'enter' }
    }) then
        local success = lib.skillCheck(table.create(config.rounds + 1, 0), { 'w', 'a', 's', 'd' })
        
        if success then
            TriggerServerEvent('LNS_Housing:server:lockpickSuccess', propertyId, 'stash', stashId)
            Bridge.Client.Notify('You successfully picked the stash lock!', 'success')
            exports.ox_inventory:openInventory('stash', stashId)
        else
            Bridge.Client.Notify('You failed to pick the stash lock.', 'error')
        end
    end
end

function ApplyWallColor(interiorId, color)
    if not interiorId or interiorId == 0 then return end
    
    ActivateInteriorEntitySet(interiorId, "wall_tint")
    SetInteriorEntitySetColor(interiorId, "wall_tint", color)
    RefreshInterior(interiorId)
    
    pcall(function()
        SetInteriorProbeLength(50.0)
    end)
end

LoadedFurniture = {}
local PropertyZones = {}

function IsCoordsInsidePropertyZone(propertyId, coords)
    if not propertyId then return true end
    local zone = PropertyZones[propertyId]
    if not zone then return true end

    if zone.contains then
        return zone:contains(coords)
    end

    return true
end

function LoadFurnitures(propertyId)
    local p = Properties[propertyId]
    if not p or not p.furniture then return end
    
    if LoadedFurniture[propertyId] then return end
    LoadedFurniture[propertyId] = {}
    for _, f in ipairs(p.furniture) do
        local hash = tonumber(f.model) or GetHashKey(f.model)
        lib.requestModel(hash)
        
        local obj = CreateObjectNoOffset(hash, f.position.x, f.position.y, f.position.z, false, false, false)
        SetEntityRotation(obj, f.rotation.x, f.rotation.y, f.rotation.z, 2, true)
        FreezeEntityPosition(obj, true)

        if f.textureVariation then
            SetObjectTextureVariation(obj, tonumber(f.textureVariation))
        end
        
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

        if itemData and itemData.isStorage then
            local stashId = string.format('housing_%d_%s', propertyId, f.id)
            exports.ox_target:addLocalEntity(obj, {
                {
                    label = 'Open Storage',
                    icon = 'fas fa-box-open',
                    debug = Settings.Debug.Zones,
                    onSelect = function()
                        Bridge.Client.OpenStash(propertyId, f.id)
                    end,
                    canInteract = function()
                        if p.isApartment then
                            return lib.callback.await('LNS_Housing:server:hasApartmentAccess', false, propertyId, 'storage')
                        else
                            return lib.callback.await('LNS_Housing:server:hasAccess', false, propertyId, 'storage')
                        end
                    end
                },
                {
                    label = 'Lockpick Storage',
                    icon = 'fas fa-mask',
                    items = Settings.Security.LockpickItem,
                    onSelect = function()
                        LockpickStash(propertyId, stashId)
                    end,
                    canInteract = function()
                        if p.isApartment then return false end
                        return Properties[propertyId].owner and not lib.callback.await('LNS_Housing:server:hasAccess', false, propertyId, 'storage')
                    end
                },
                {
                    label = 'Raid Storage',
                    icon = 'fas fa-shield-halved',
                    items = Settings.Security.RaidItem,
                    onSelect = function()
                        StartPoliceStashRaid(propertyId, f.id)
                    end,
                    canInteract = function()
                        local job = Bridge.Client.GetPlayerJob()
                        if not job or job.name ~= 'police' then return false end
                        
                        
                        local isDoorBreached = lib.callback.await('LNS_Housing:server:isDoorBreached', false, propertyId)
                        if not isDoorBreached then return false end
                        
                        local hasAccess
                        if p.isApartment then
                            hasAccess = lib.callback.await('LNS_Housing:server:hasApartmentAccess', false, propertyId, 'storage')
                        else
                            hasAccess = lib.callback.await('LNS_Housing:server:hasAccess', false, propertyId, 'storage')
                        end
                        return not hasAccess
                    end
                }
            })
        end

        if itemData and itemData.isWardrobe then
            exports.ox_target:addLocalEntity(obj, {
                {
                    label = 'Open Wardrobe',
                    icon = 'fas fa-shirt',
                    debug = Settings.Debug.Zones,
                    onSelect = function()
                        Bridge.Client.OpenWardrobe(propertyId, f.id)
                    end,
                    canInteract = function()
                        if p.isApartment then
                            return lib.callback.await('LNS_Housing:server:hasApartmentAccess', false, propertyId, 'wardrobe')
                        else
                            return lib.callback.await('LNS_Housing:server:hasAccess', false, propertyId, 'wardrobe')
                        end
                    end
                }
            })
        end

        if itemData and itemData.isLogout then
            exports.ox_target:addLocalEntity(obj, {
                {
                    label = 'Logout',
                    icon = 'fas fa-right-from-bracket',
                    debug = Settings.Debug.Zones,
                    onSelect = function()
                        local alert = lib.alertDialog({
                            header = 'Confirm Logout',
                            content = 'Are you sure you want to log out of your character?',
                            centered = true,
                            cancel = true,
                            labels = {
                                confirm = 'Log out',
                                cancel = 'Cancel'
                            }
                        })
                        if alert == 'confirm' then
                            TriggerServerEvent('LNS_Housing:server:logoutPlayer')
                        end
                    end,
                    canInteract = function()
                        if p.isApartment then
                            return lib.callback.await('LNS_Housing:server:hasApartmentAccess', false, propertyId, 'entry')
                        else
                            return lib.callback.await('LNS_Housing:server:hasAccess', false, propertyId, 'entry')
                        end
                    end
                }
            })
        end

        if itemData and itemData.id == 'lns_housing_panel' then
            exports.ox_target:addLocalEntity(obj, {
                {
                    label = p.isApartment and 'Open Apartment Panel' or 'Open House Panel',
                    icon = p.isApartment and 'fas fa-building' or 'fas fa-house-user',
                    debug = Settings.Debug.Zones,
                    onSelect = function()
                        local propData = Properties[propertyId]
                        if propData then
                            TriggerEvent('LNS_Housing:client:openPanel', propData)
                        end
                    end,
                    canInteract = function()
                        if p.isApartment then
                            return Properties[propertyId] and Properties[propertyId].owner and 
                                lib.callback.await('LNS_Housing:server:hasApartmentAccess', false, propertyId, 'manage')
                        else
                            return Properties[propertyId] and Properties[propertyId].owner and 
                                lib.callback.await('LNS_Housing:server:hasAccess', false, propertyId, 'manage')
                        end
                    end
                }
            })
        end

        LoadedFurniture[propertyId][f.id] = obj
    end
end

function UnloadFurnitures(propertyId)
    if not LoadedFurniture[propertyId] then return end
    
    for _, obj in pairs(LoadedFurniture[propertyId]) do
        if DoesEntityExist(obj) then
            DeleteEntity(obj)
        end
    end
    
    LoadedFurniture[propertyId] = nil
end

function RegisterPropertyZones(p)
    if RegisterYardZone then
        RegisterYardZone(p)
    end
    if PropertyZones[p.id] then return end
    
    if p.metadata and p.metadata.shell and p.metadata.shell ~= 'mlo' then
        
        local doorCoords = GetEntranceCoords(p)
        if doorCoords then
            local shellCoords = vec3(doorCoords.x, doorCoords.y, doorCoords.z - 35.0)
            PropertyZones[p.id] = lib.zones.box({
                coords = shellCoords,
                size = vec3(25.0, 25.0, 10.0),
                debug = Settings.Debug.Zones,
                onEnter = function()
                    
                    local shellName = p.metadata.shell or 'Standard Motel'
                    SpawnShellForProperty(p.id, shellName, shellCoords)

                    LoadFurnitures(p.id)
                    TriggerServerEvent('LNS_Housing:server:enterPropertyBucket', p.id)

                    if lib.callback.await('LNS_Housing:server:hasAccess', false, p.id, 'manage') then
                        lib.addRadialItem({
                            id = 'housing_furniture',
                            icon = 'couch',
                            label = 'Furniture Menu',
                            onSelect = function()
                                TriggerEvent('LNS_Housing:client:openFurnitureMenu', p.id)
                            end
                        })
                    end
                end,
                onExit = function()
                    UnloadFurnitures(p.id)
                    lib.removeRadialItem('housing_furniture')
                    TriggerServerEvent('LNS_Housing:server:leavePropertyBucket')
                end
            })
        end
    
    elseif p.zone_data and p.zone_data.points and #p.zone_data.points >= 3 then
        local thickness = p.zone_data.thickness or 10.0
        local points = {}
        for i = 1, #p.zone_data.points do
            local pt = p.zone_data.points[i]
            points[i] = vector3(pt.x, pt.y, pt.z + (thickness / 2))
        end

        PropertyZones[p.id] = lib.zones.poly({
            points = points,
            thickness = thickness,
            debug = Settings.Debug.Zones,
            onEnter = function()
                LoadFurnitures(p.id)
                if lib.callback.await('LNS_Housing:server:hasAccess', false, p.id, 'manage') then
                    lib.addRadialItem({
                        id = 'housing_furniture',
                        icon = 'couch',
                        label = 'Furniture Menu',
                        onSelect = function()
                            TriggerEvent('LNS_Housing:client:openFurnitureMenu', p.id)
                        end
                    })
                end
            end,
            onExit = function()
                UnloadFurnitures(p.id)
                lib.removeRadialItem('housing_furniture')
            end
        })
    else
        
        local door = p.door_id and GetOxDoorlockDoor(p.door_id)
        if door and door.coords then
            local doorCoords = vec3(door.coords.x, door.coords.y, door.coords.z)
            PropertyZones[p.id] = lib.points.new({
                coords = doorCoords,
                distance = 40,
                onEnter = function()
                    LoadFurnitures(p.id)
                    if lib.callback.await('LNS_Housing:server:hasAccess', false, p.id, 'manage') then
                        lib.addRadialItem({
                            id = 'housing_furniture',
                            icon = 'couch',
                            label = 'Furniture Menu',
                            onSelect = function()
                                TriggerEvent('LNS_Housing:client:openFurnitureMenu', p.id)
                            end
                        })
                    end
                end,
                onExit = function()
                    UnloadFurnitures(p.id)
                    lib.removeRadialItem('housing_furniture')
                end
            })
        end
    end
end

function RegisterPropertyEntranceTargets(p)
    if not p then return end
    local id = p.id
    
    
    if EntranceTargets[id] then
        exports.ox_target:removeZone(EntranceTargets[id])
        EntranceTargets[id] = nil
    end

    local doorId = p.door_id
    if (not doorId or doorId == 0) and p.doors and #p.doors > 0 then
        doorId = p.doors[1]
    end

    if doorId and doorId ~= 0 then
        local door = GetOxDoorlockDoor(doorId)

        if door and door.coords then
            local targetCoords, targetHeading = ResolveDoorTargetPlacement(door.model, door.coords, door.heading, door)

            if targetCoords then
                local isShell = p.metadata and p.metadata.shell and p.metadata.shell ~= 'mlo'
                if isShell then
                    EntranceTargets[id] = exports.ox_target:addBoxZone({
                        coords = targetCoords,
                        size = vec3(1.2, 1.5, 2.0),
                        rotation = targetHeading,
                        debug = Settings.Debug.Zones,
                        options = {
                            {
                                label = 'Enter ' .. p.label,
                                icon = 'fas fa-door-open',
                                canInteract = function()
                                    local doorState = exports.ox_doorlock:getDoor(doorId).state
                                    local isUnlocked = doorState == 0
                                    if isUnlocked then return true end
                                    return lib.callback.await('LNS_Housing:server:hasAccess', false, id, 'entry')
                                end,
                                onSelect = function()
                                    EnterShellProperty(id)
                                end
                            }
                        }
                    })
                end

                
                if Settings.Debug and Settings.Debug.BuyHouses then
                    exports.ox_target:addSphereZone({
                        coords = targetCoords,
                        radius = 1.2,
                        debug = Settings.Debug.Zones,
                        options = {
                            {
                                label = 'Lockpick ' .. p.label,
                                icon = 'fas fa-mask',
                                items = Settings.Security.LockpickItem,
                                canInteract = function()
                                    return Properties[id].owner and Properties[id].owner ~= Bridge.Client.GetIdentifier()
                                end,
                                onSelect = function()
                                    LockpickDoor(id)
                                end
                            }
                        }
                    })
                end

                
                exports.ox_target:addBoxZone({
                    coords = targetCoords,
                    size = vec3(1.0, 1.5, 2.0),
                    rotation = targetHeading,
                    debug = Settings.Debug.Zones,
                    options = {
                        {
                            label = 'Raid House',
                            icon = 'fas fa-shield-halved',
                            items = Settings.Security.RaidItem,
                            canInteract = function()
                                local job = Bridge.Client.GetPlayerJob()
                                return job and job.name == 'police'
                            end,
                            onSelect = function()
                                StartPoliceRaid(id, 'house', doorId)
                            end
                        }
                    }
                })
            end
        end
    else
        
        local isShell = p.metadata and p.metadata.shell and p.metadata.shell ~= 'mlo'
        local entranceCoords = p.metadata and p.metadata.entrance
        if isShell and entranceCoords then
            local targetCoords = vec3(entranceCoords.x, entranceCoords.y, entranceCoords.z)
            local targetHeading = entranceCoords.h or 0.0

            EntranceTargets[id] = exports.ox_target:addBoxZone({
                coords = targetCoords,
                size = vec3(1.5, 1.5, 2.0),
                rotation = targetHeading,
                debug = Settings.Debug.Zones,
                options = {
                    {
                        label = 'Enter ' .. p.label,
                        icon = 'fas fa-door-open',
                        canInteract = function()
                            local isLocked = p.metadata.locked ~= false
                            if not isLocked then return true end
                            return lib.callback.await('LNS_Housing:server:hasAccess', false, id, 'entry')
                        end,
                        onSelect = function()
                            EnterShellProperty(id)
                        end
                    },
                    {
                        label = 'Lock/Unlock ' .. p.label,
                        icon = 'fas fa-key',
                        canInteract = function()
                            return lib.callback.await('LNS_Housing:server:hasAccess', false, id, 'manage')
                        end,
                        onSelect = function()
                            TriggerServerEvent('LNS_Housing:server:toggleLock', id)
                        end
                    },
                    {
                        label = 'Lockpick ' .. p.label,
                        icon = 'fas fa-mask',
                        items = Settings.Security.LockpickItem,
                        canInteract = function()
                            local isLocked = p.metadata.locked ~= false
                            if not isLocked then return false end
                            return Properties[id].owner and Properties[id].owner ~= Bridge.Client.GetIdentifier()
                        end,
                        onSelect = function()
                            LockpickDoor(id)
                        end
                    },
                    {
                        label = 'Raid House',
                        icon = 'fas fa-shield-halved',
                        items = Settings.Security.RaidItem,
                        canInteract = function()
                            local job = Bridge.Client.GetPlayerJob()
                            return job and job.name == 'police'
                        end,
                        onSelect = function()
                            StartPoliceRaid(id, 'house', nil)
                        end
                    }
                }
            })
        end
    end
end

function CleanUpHousingSession()
    
    lib.hideTextUI()

    
    lib.removeRadialItem('housing_furniture')

    
    SetNuiFocus(false, false)

    
    if Modeler then
        if Modeler.CurrentObject and DoesEntityExist(Modeler.CurrentObject) then
            DeleteEntity(Modeler.CurrentObject)
        end
        if Modeler.HoverObject and DoesEntityExist(Modeler.HoverObject) then
            DeleteEntity(Modeler.HoverObject)
        end
        if Modeler.Cart then
            for _, item in pairs(Modeler.Cart) do
                if item.entity and DoesEntityExist(item.entity) then
                    DeleteEntity(item.entity)
                end
            end
        end
        if Modeler.IsFreecamMode then
            pcall(function()
                exports['fivem-freecam']:SetActive(false)
            end)
        end
    end

    
    if LoadedFurniture then
        for propertyId, _ in pairs(LoadedFurniture) do
            UnloadFurnitures(propertyId)
        end
    end

    
    if PropertyZones then
        for id, zone in pairs(PropertyZones) do
            if zone and zone.remove then
                pcall(function()
                    zone:remove()
                end)
            end
        end
        PropertyZones = {}
    end

    
    if CurrentInterior and CurrentInterior ~= 0 then
        DeactivateInteriorEntitySet(CurrentInterior, "wall_tint")
        RefreshInterior(CurrentInterior)
    end

    if CleanUpLawn then
        CleanUpLawn()
    end

    
    for propertyId, entity in pairs(SpawnedShells) do
        if DoesEntityExist(entity) then
            DeleteEntity(entity)
        end
    end
    SpawnedShells = {}

    for propertyId, targetId in pairs(ExitTargets) do
        exports.ox_target:removeZone(targetId)
    end
    ExitTargets = {}

    for propertyId, targetId in pairs(EntranceTargets) do
        exports.ox_target:removeZone(targetId)
    end
    EntranceTargets = {}

    ClearPropertyBlips()

    Properties = {}
    CurrentProperty = nil
    CurrentInterior = 0
end

function InitializeHousing()
    
    CleanUpHousingSession()

    Properties = lib.callback.await('LNS_Housing:server:getProperties', false)
    
    if Properties then
        UpdatePropertyBlips()

        
        for id, p in pairs(Properties) do
            RegisterPropertyZones(p)
        end

        
        Wait(1500) 
        for id, p in pairs(Properties) do
            RegisterPropertyEntranceTargets(p)
        end
    end
end


CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do
        Wait(100)
    end
    Wait(1000)

    local hasIdentifier = Bridge.Client.GetIdentifier()
    if hasIdentifier then
        InitializeHousing()
    end
end)


RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    InitializeHousing()
end)

RegisterNetEvent('esx:playerLoaded', function(xPlayer)
    InitializeHousing()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    CleanUpHousingSession()
end)

RegisterNetEvent('esx:onPlayerLogout', function()
    CleanUpHousingSession()
end)


CreateThread(function()
    while true do
        local ped = cache.ped
        local interiorId = GetInteriorFromEntity(ped)
        
        if interiorId ~= CurrentInterior then
            CurrentInterior = interiorId
            
            if interiorId ~= 0 then
                
                for id, p in pairs(Properties) do
                    local door = p.door_id and GetOxDoorlockDoor(p.door_id)
                    if door and door.coords and #(GetEntityCoords(ped) - vec3(door.coords.x, door.coords.y, door.coords.z)) < 30.0 then
                        if p.metadata and p.metadata.wall_color and p.metadata.allow_wall_colors then
                            ApplyWallColor(interiorId, p.metadata.wall_color)
                        end
                        break
                    end
                end
            end
        end
        Wait(2000)
    end
end)

RegisterNetEvent('LNS_Housing:client:updateFurniture', function(propertyId, furniture)
    if Properties[propertyId] then
        Properties[propertyId].furniture = furniture
        
        
        if LoadedFurniture[propertyId] then
            UnloadFurnitures(propertyId)
            LoadFurnitures(propertyId)
            
            if Modeler and Modeler.IsMenuActive and Modeler.property_id == propertyId then
                Modeler:UpdateOwnedItems()
            end
        end
    end
end)

RegisterNetEvent('LNS_Housing:client:updateProperties', function(allProperties)
    
    for k, v in pairs(allProperties) do
        local isNew = Properties[k] == nil
        Properties[k] = v
        if isNew then
            RegisterPropertyZones(v)
            RegisterPropertyEntranceTargets(v)
        else
            RegisterPropertyEntranceTargets(v)
            if ActiveYardPropertyId == k and RefreshYardGrass then
                RefreshYardGrass(k)
            end
        end
    end
    
    for k, v in pairs(Properties) do
        if not allProperties[k] then
            if EntranceTargets[k] then
                exports.ox_target:removeZone(EntranceTargets[k])
                EntranceTargets[k] = nil
            end
            Properties[k] = nil
        end
    end

    UpdatePropertyBlips()

    SendNUIMessage({
        action = 'updateProperties',
        data = Properties
    })
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    CleanUpHousingSession()
end)


function StartPoliceRaid(propertyId, propertyType, doorId)
    local duration = Settings.Security.RaidDuration or 5000

    if lib.progressBar({
        duration = duration,
        label = 'Breaching door lock...',
        useWhileDead = false,
        canCancel = true,
        disable = { car = true, move = true, combat = true },
        anim = {
            dict = 'missheistfbi3b_ig7',
            clip = 'lift_fibagent_loop',
            flags = 49,
        },
    }) then
        TriggerServerEvent('LNS_Housing:server:policeRaidDoor', propertyId, propertyType, doorId)
    else
        Bridge.Client.Notify('Breaching cancelled.', 'error')
    end
end

function StartPoliceStashRaid(propertyId, stashId)
    local duration = Settings.Security.RaidStorageDuration or 5000

    if lib.progressBar({
        duration = duration,
        label = 'Breaching storage lock...',
        useWhileDead = false,
        canCancel = true,
        disable = { car = true, move = true, combat = true },
        anim = {
            dict = 'missheistfbi3b_ig7',
            clip = 'lift_fibagent_loop',
            flags = 49,
        },
    }) then
        TriggerServerEvent('LNS_Housing:server:policeRaidStash', propertyId)
    else
        Bridge.Client.Notify('Breaching cancelled.', 'error')
    end
end


SpawnedShells = {}
ExitTargets = {}

function GetEntranceCoords(p)
    if not p then return nil end

    if p.metadata and p.metadata.entrance then
        local ent = p.metadata.entrance
        return vec3(ent.x, ent.y, ent.z)
    end

    local doorId = p.door_id
    if (not doorId or doorId == 0) and p.doors and #p.doors > 0 then
        doorId = p.doors[1]
    end

    if doorId and doorId ~= 0 then
        local door = GetOxDoorlockDoor(doorId)
        if door and door.coords then
            return vec3(door.coords.x, door.coords.y, door.coords.z)
        end
    end

    if p.zone_data and p.zone_data.points and #p.zone_data.points > 0 then
        local sumX, sumY, sumZ = 0, 0, 0
        local count = #p.zone_data.points
        for _, pt in ipairs(p.zone_data.points) do
            sumX = sumX + pt.x
            sumY = sumY + pt.y
            sumZ = sumZ + pt.z
        end
        return vec3(sumX / count, sumY / count, sumZ / count)
    end

    return nil
end

function ClearPropertyBlips()
    for id, blip in pairs(PropertyBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    PropertyBlips = {}
end

function UpdatePropertyBlips()
    ClearPropertyBlips()

    if not Settings.Housing.Blips then return end

    local playerIdentifier = Bridge.Client.GetIdentifier()

    for id, p in pairs(Properties) do
        if not p.isApartment then
            local entranceCoords = GetEntranceCoords(p)
            if entranceCoords then
                local isOwned = p.owner ~= nil and p.owner ~= false and p.owner ~= ""
                local isMyOwned = isOwned and (p.owner == playerIdentifier)
                
                local blipConfig = nil
                if isOwned then
                    blipConfig = Settings.Housing.Blips.Owned
                else
                    blipConfig = Settings.Housing.Blips.ReadyToBuy
                end

                if blipConfig and blipConfig.Enabled then
                    if not isOwned or not blipConfig.ShowOnlyMyOwned or isMyOwned then
                        local blip = AddBlipForCoord(entranceCoords.x, entranceCoords.y, entranceCoords.z)
                        SetBlipSprite(blip, blipConfig.Sprite)
                        SetBlipDisplay(blip, 4)
                        SetBlipScale(blip, blipConfig.Scale)
                        SetBlipColour(blip, blipConfig.Color)
                        SetBlipAsShortRange(blip, true)
                        
                        local blipLabel = p.label
                        if blipConfig.Label and blipConfig.Label ~= "" then
                            blipLabel = string.format("%s - %s", blipConfig.Label, p.label)
                        end

                        BeginTextCommandSetBlipName("STRING")
                        AddTextComponentString(blipLabel)
                        EndTextCommandSetBlipName(blip)

                        PropertyBlips[id] = blip
                    end
                end
            end
        end
    end
end

function SpawnShellForProperty(propertyId, shellName, shellCoords)
    local shellData = Settings.Shells[shellName]
    if not shellData then return nil end

    local shellEntity = SpawnedShells[propertyId]
    if not shellEntity or not DoesEntityExist(shellEntity) then
        local shellHash = tonumber(shellData.hash) or GetHashKey(shellData.hash)
        lib.requestModel(shellHash)
        shellEntity = CreateObjectNoOffset(shellHash, shellCoords.x, shellCoords.y, shellCoords.z, false, false, false)
        FreezeEntityPosition(shellEntity, true)
        SetEntityRotation(shellEntity, 0.0, 0.0, 0.0, 2, true)
        SpawnedShells[propertyId] = shellEntity
    end

    local doorOffset = shellData.doorOffset
    local spawnCoords = GetOffsetFromEntityInWorldCoords(shellEntity, doorOffset.x, doorOffset.y, doorOffset.z)
    local heading = doorOffset.h or 0.0

    if not ExitTargets[propertyId] then
        local options = {
            {
                label = 'Exit Property',
                icon = 'fas fa-door-closed',
                onSelect = function()
                    LeaveShellProperty(propertyId)
                end
            }
        }

        local p = Properties[propertyId]
        if p and p.metadata and p.metadata.entrance then
            table.insert(options, {
                label = 'Lock/Unlock Property',
                icon = 'fas fa-key',
                canInteract = function()
                    return lib.callback.await('LNS_Housing:server:hasAccess', false, propertyId, 'manage')
                end,
                onSelect = function()
                    TriggerServerEvent('LNS_Housing:server:toggleLock', propertyId)
                end
            })
        end

        ExitTargets[propertyId] = exports.ox_target:addBoxZone({
            coords = spawnCoords,
            size = vec3(1.2, 1.5, 2.0),
            rotation = heading,
            debug = Settings.Debug.Zones,
            options = options
        })
    end

    return shellEntity, spawnCoords, heading
end

function EnterShellProperty(propertyId)
    local p = Properties[propertyId]
    if not p then return end

    local shellName = p.metadata.shell or 'Standard Motel'
    local doorCoords = GetEntranceCoords(p)
    if not doorCoords then
        Bridge.Client.Notify('Entrance coordinates not found!', 'error')
        return
    end

    local shellCoords = vec3(doorCoords.x, doorCoords.y, doorCoords.z - 35.0)

    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(0) end

    local shellEntity, spawnCoords, heading = SpawnShellForProperty(propertyId, shellName, shellCoords)

    if spawnCoords then
        local ped = cache.ped
        SetEntityCoords(ped, spawnCoords.x, spawnCoords.y, spawnCoords.z, false, false, false, false)
        SetEntityHeading(ped, heading)
    end

    Wait(500)
    DoScreenFadeIn(1000)
end

function LeaveShellProperty(propertyId)
    local p = Properties[propertyId]
    if not p then return end

    local doorCoords = GetEntranceCoords(p)
    if not doorCoords then return end

    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(0) end

    if ExitTargets[propertyId] then
        exports.ox_target:removeZone(ExitTargets[propertyId])
        ExitTargets[propertyId] = nil
    end

    if SpawnedShells[propertyId] and DoesEntityExist(SpawnedShells[propertyId]) then
        DeleteEntity(SpawnedShells[propertyId])
        SpawnedShells[propertyId] = nil
    end

    local ped = cache.ped
    SetEntityCoords(ped, doorCoords.x, doorCoords.y, doorCoords.z, false, false, false, false)

    Wait(500)
    DoScreenFadeIn(1000)
end