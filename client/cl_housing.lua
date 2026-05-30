local Settings = lib.load('shared.settings')
Properties = {}
local CurrentProperty = nil
local CurrentInterior = 0

-- Sync properties from server
CreateThread(function()
    Properties = lib.callback.await('LNS_Housing:server:getProperties', false)
end)

-- Open Creator UI
RegisterCommand(Settings.Creator.Command, function(source, args, rawCommand)
    local hasPermission = lib.callback.await('LNS_Housing:server:getRealEstatePermission', false)
    if not hasPermission then
        Settings.Notify('You do not have permission to use this command.', 'error')
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

-- NUI Callbacks
RegisterNUICallback('createHouse', function(data, cb)
    SetNuiFocus(false, false)
    local success = lib.callback.await('LNS_Housing:server:createHouse', false, data)
    if success then
        Settings.Notify('House created successfully!', 'success')
    else
        Settings.Notify('Failed to create house.', 'error')
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

-- Target integration for houses
CreateThread(function()
    if not Settings.Debug or not Settings.Debug.BuyHouses then return end

    -- Wait for properties to be synced
    while not next(Properties) do Wait(1000) end

    for id, p in pairs(Properties) do
        local doorId = p.door_id
        if (not doorId or doorId == 0) and p.doors and #p.doors > 0 then
            doorId = p.doors[1]
        end

        if doorId and doorId ~= 0 then
            local door = nil
            if exports.ox_doorlock.getDoor then
                door = exports.ox_doorlock:getDoor(doorId)
            elseif exports.ox_doorlock.getDoorData then
                door = exports.ox_doorlock:getDoorData(doorId)
            end

            if door then
                exports.ox_target:addSphereZone({
                    coords = door.coords,
                    radius = 1.2,
                    debug = true,
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
        end
    end
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
            Settings.Notify('You successfully picked the lock!', 'success')
        else
            Settings.Notify('You failed to pick the lock.', 'error')
            -- Optional: break lockpick item logic here
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
            Settings.Notify('You successfully picked the stash lock!', 'success')
            exports.ox_inventory:openInventory('stash', stashId)
        else
            Settings.Notify('You failed to pick the stash lock.', 'error')
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
    elseif zone.coords and zone.distance then
        return #(coords - zone.coords) <= zone.distance
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
        
        local obj = CreateObject(hash, f.position.x, f.position.y, f.position.z, false, false, false)
        SetEntityRotation(obj, f.rotation.x, f.rotation.y, f.rotation.z, 2, true)
        FreezeEntityPosition(obj, true)

        if f.textureVariation then
            SetObjectTextureVariation(obj, tonumber(f.textureVariation))
        end
        -- Add target for storage items
        local itemData = nil
        for _, cat in ipairs(Settings.Furniture) do
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
                }
            })
        end

        if itemData and itemData.isWardrobe then
            exports.ox_target:addLocalEntity(obj, {
                {
                    label = 'Open Wardrobe',
                    icon = 'fas fa-shirt',
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

        -- Add target for housing panel (third-eye to open house panel)
        if itemData and itemData.id == 'lns_housing_panel' then
            exports.ox_target:addLocalEntity(obj, {
                {
                    label = 'Open House Panel',
                    icon = 'fas fa-house-user',
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
    
    -- If zone_data exists (Polyzone), use lib.zones
    if p.zone_data and p.zone_data.points and #p.zone_data.points >= 3 then
        local points = {}
        for i = 1, #p.zone_data.points do
            local pt = p.zone_data.points[i]
            points[i] = vector3(pt.x, pt.y, pt.z)
        end

        PropertyZones[p.id] = lib.zones.poly({
            points = points,
            thickness = p.zone_data.thickness or 10.0,
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
        -- Fallback to distance-based loading using lib.points
        local door = p.door_id and exports.ox_doorlock:getDoor(p.door_id)
        if door then
            PropertyZones[p.id] = lib.points.new({
                coords = door.coords,
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

-- Sync properties from server and register zones
CreateThread(function()
    Properties = lib.callback.await('LNS_Housing:server:getProperties', false)
    
    for id, p in pairs(Properties) do
        RegisterPropertyZones(p)
    end
end)

-- Monitor interior changes only for wall colors now
CreateThread(function()
    while true do
        local ped = cache.ped
        local interiorId = GetInteriorFromEntity(ped)
        
        if interiorId ~= CurrentInterior then
            CurrentInterior = interiorId
            
            if interiorId ~= 0 then
                -- Check if this interior belongs to a property (for wall color)
                for id, p in pairs(Properties) do
                    local door = p.door_id and exports.ox_doorlock:getDoor(p.door_id)
                    if door and #(GetEntityCoords(ped) - door.coords) < 30.0 then
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
        
        -- If the furniture is currently loaded (meaning we are inside/near the property), refresh it
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
    -- Update in-place to keep references for closures
    for k, v in pairs(allProperties) do
        local isNew = Properties[k] == nil
        Properties[k] = v
        if isNew then
            RegisterPropertyZones(v)
        else
            if ActiveYardPropertyId == k and RefreshYardGrass then
                RefreshYardGrass(k)
            end
        end
    end
    -- Remove deleted properties if any
    for k, v in pairs(Properties) do
        if not allProperties[k] then
            Properties[k] = nil
        end
    end

    SendNUIMessage({
        action = 'updateProperties',
        data = Properties
    })
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    -- Hide any active TextUI
    lib.hideTextUI()

    -- Remove radial menu item
    lib.removeRadialItem('housing_furniture')

    -- Reset NUI Focus
    SetNuiFocus(false, false)

    -- Clean up active Modeler objects (if Modeler is loaded)
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

    -- Clean up all spawned housing furniture
    if LoadedFurniture then
        for propertyId, _ in pairs(LoadedFurniture) do
            UnloadFurnitures(propertyId)
        end
    end

    -- Clean up property zones/points
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

    -- Restore wall color/tint of current interior if set
    if CurrentInterior and CurrentInterior ~= 0 then
        DeactivateInteriorEntitySet(CurrentInterior, "wall_tint")
        RefreshInterior(CurrentInterior)
    end

    if CleanUpLawn then
        CleanUpLawn()
    end
end)
