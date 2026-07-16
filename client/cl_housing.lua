local Settings = lib.load('shared.settings')
local Furniture = lib.load('shared.furniture')
local CurrentProperty = nil
local CurrentInterior = 0
local PropertyBlips = {}
local ClearPropertyBlips, UpdatePropertyBlips
local PropertyZones = {}
local activeAlarmsCount = 0
Properties = {}
EntranceTargets = {}
LoadedFurniture = {}

RegisterCommand(Settings.Housing.Creator.Command, function(source, args, rawCommand)
    local hasPermission = lib.callback.await('LNS_Housing:server:checkPermission', false, 'realestate')
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
    local isApartment = false
    
    if not p then
        if ApartmentRooms then
            for _, room in ipairs(ApartmentRooms) do
                if room.id == propertyId then
                    isApartment = true
                    break
                end
            end
        end
    else
        isApartment = p.isApartment
    end

    if not p and not isApartment then return end

    local permType = isApartment and 'apartment' or 'house'
    if not lib.callback.await('LNS_Housing:server:checkPermission', false, permType, propertyId, 'lockpick') then
        Bridge.Client.Notify('You cannot lockpick this property (either you already have access or it is unowned).', 'error')
        return
    end

    local securityLevel = 0
    if p and p.metadata then
        securityLevel = p.metadata.security_level or 0
    end
    local config = Settings.Security.Difficulty[securityLevel] or Settings.Security.Difficulty[0]

    lib.requestAnimDict('anim@amb@clubhouse@tutorial@bkr_tut_ig3@')
    TaskPlayAnim(cache.ped, 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', 'ig_3_con_loop', 8.0, -8.0, -1, 49, 0, false, false, false)

    local rounds = {}
    for i = 1, config.rounds do
        rounds[i] = { areaSize = config.area, speedMultiplier = config.speed }
    end
    local success = lib.skillCheck(rounds, { 'w', 'a', 's', 'd' })
    
    ClearPedTasks(cache.ped)

    if success then
        TriggerServerEvent('LNS_Housing:server:lockpickSuccess', propertyId, 'door')
        Bridge.Client.Notify('You successfully picked the lock!', 'success')
    else
        TriggerServerEvent('LNS_Housing:server:lockpickFailed', propertyId)
        Bridge.Client.Notify('You failed to pick the lock.', 'error')
    end
end

function OpenBelongingsRetrieval(propertyId)
    local p = Properties[propertyId]
    if not p or not p.furniture then return end

    local options = {}
    for _, f in ipairs(p.furniture) do
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
            table.insert(options, {
                title = f.label or itemData.label or 'Storage Unit',
                description = 'Retrieve items from this storage unit',
                icon = 'box',
                arrow = true,
                onSelect = function()
                    Bridge.Client.OpenStash(propertyId, f.id)
                end
            })
        end
    end

    if #options == 0 then
        Bridge.Client.Notify('No stashes found in this property.', 'error')
        return
    end

    lib.registerContext({
        id = 'housing_belongings_retrieval',
        title = 'Retrieve Belongings - ' .. p.label,
        options = options
    })
    lib.showContext('housing_belongings_retrieval')
end

function LockpickStash(propertyId, stashId)
    local p = Properties[propertyId]
    local isApartment = false
    
    if not p then
        if ApartmentRooms then
            for _, room in ipairs(ApartmentRooms) do
                if room.id == propertyId then
                    isApartment = true
                    break
                end
            end
        end
    else
        isApartment = p.isApartment
    end

    if not p and not isApartment then return end

    local permType = isApartment and 'apartment' or 'house'
    if not lib.callback.await('LNS_Housing:server:checkPermission', false, permType, propertyId, 'lockpickStash') then
        Bridge.Client.Notify('You cannot lockpick this storage (either you already have access or it is unowned).', 'error')
        return
    end

    local securityLevel = 0
    if p and p.metadata then
        securityLevel = p.metadata.security_level or 0
    end
    local config = Settings.Security.Difficulty[securityLevel] or Settings.Security.Difficulty[0]

    lib.requestAnimDict('anim@amb@prop_human_atm@interior@male@enter')
    TaskPlayAnim(cache.ped, 'anim@amb@prop_human_atm@interior@male@enter', 'enter', 8.0, -8.0, -1, 49, 0, false, false, false)

    local rounds = {}
    local totalRounds = config.rounds + 1
    for i = 1, totalRounds do
        rounds[i] = { areaSize = config.area, speedMultiplier = config.speed }
    end
    local success = lib.skillCheck(rounds, { 'w', 'a', 's', 'd' })
    
    ClearPedTasks(cache.ped)

    if success then
        TriggerServerEvent('LNS_Housing:server:lockpickSuccess', propertyId, 'stash', stashId)
        Bridge.Client.Notify('You successfully picked the stash lock!', 'success')
        exports.ox_inventory:openInventory('stash', stashId)
    else
        Bridge.Client.Notify('You failed to pick the stash lock.', 'error')
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

function IsCoordsInsidePropertyZone(propertyId, coords)
    if not propertyId then return true end
    local zone = PropertyZones[propertyId]
    if not zone then return true end

    if zone.contains then
        return zone:contains(coords)
    end

    return true
end

local function ParseVector3(data)
    if not data then return vec3(0.0, 0.0, 0.0) end
    if type(data) == 'vector3' then return data end
    return vec3(
        tonumber(data.x or data[1] or 0.0),
        tonumber(data.y or data[2] or 0.0),
        tonumber(data.z or data[3] or 0.0)
    )
end

function LoadFurnitures(propertyId)
    local p = Properties[propertyId]
    if not p or not p.furniture then return end
    
    if LoadedFurniture[propertyId] then return end
    LoadedFurniture[propertyId] = {}
    for _, f in ipairs(p.furniture) do
        local hash = tonumber(f.model) or GetHashKey(f.model)
        lib.requestModel(hash)
        
        if not LoadedFurniture[propertyId] then
            break
        end
        
        local pos = ParseVector3(f.position)
        local rot = ParseVector3(f.rotation)
        local obj = CreateObjectNoOffset(hash, pos.x, pos.y, pos.z, false, false, false)
        SetEntityRotation(obj, rot.x, rot.y, rot.z, 2, true)
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
                        local isLocked = lib.callback.await('LNS_Housing:server:isStashLocked', false, stashId)
                        if not isLocked then return true end
                        return lib.callback.await('LNS_Housing:server:checkPermission', false, p.isApartment and 'apartment' or 'house', propertyId, 'storage')
                    end
                },
                {
                    label = 'Lock/Unlock Storage',
                    icon = 'fas fa-key',
                    debug = Settings.Debug.Zones,
                    onSelect = function()
                        TriggerServerEvent('LNS_Housing:server:toggleStashLock', propertyId, stashId)
                    end,
                    canInteract = function()
                        return lib.callback.await('LNS_Housing:server:checkPermission', false, p.isApartment and 'apartment' or 'house', propertyId, 'storage')
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
                        if itemData.canLockpick == false or itemData.canlockpick == false then return false end
                        if p.isApartment and not Settings.Apartments.CanBreakIn then return false end

                        local isLocked = lib.callback.await('LNS_Housing:server:isStashLocked', false, stashId)
                        if not isLocked then return false end

                        return lib.callback.await('LNS_Housing:server:checkPermission', false, p.isApartment and 'apartment' or 'house', propertyId, 'lockpickStash')
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
                        
                        local hasAccess = lib.callback.await('LNS_Housing:server:checkPermission', false, p.isApartment and 'apartment' or 'house', propertyId, 'storage')
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
                        return lib.callback.await('LNS_Housing:server:checkPermission', false, p.isApartment and 'apartment' or 'house', propertyId, 'wardrobe')
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
                        return lib.callback.await('LNS_Housing:server:checkPermission', false, p.isApartment and 'apartment' or 'house', propertyId, 'entry')
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
                        return Properties[propertyId] and Properties[propertyId].owner and 
                            lib.callback.await('LNS_Housing:server:checkPermission', false, p.isApartment and 'apartment' or 'house', propertyId, 'manage')
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

function RegisterPropertyZones(p, forceShell)
    if RegisterYardZone then
        RegisterYardZone(p)
    end
    if PropertyZones[p.id] then return end
    
    if p.metadata and p.metadata.shell and p.metadata.shell ~= 'mlo' then
        local shellName = p.metadata.shell or 'Standard Motel'
        local shellData = (Settings.IPLs and Settings.IPLs[shellName]) or Settings.Shells[shellName]
        local isIpl = shellData and shellData.ipls ~= nil

        local doorCoords = GetEntranceCoords(p)
        if doorCoords or isIpl then
            local shellCoords
            if isIpl then
                shellCoords = vec3(shellData.coords.x, shellData.coords.y, shellData.coords.z)
            else
                shellCoords = vec3(doorCoords.x, doorCoords.y, Settings.ShellSpawningZ or -100.0)
            end

            local shouldRegister = forceShell
            if not shouldRegister then
                local playerCoords = GetEntityCoords(cache.ped)
                if #(playerCoords - shellCoords) < (isIpl and 100.0 or 35.0) then
                    shouldRegister = true
                end
            end

            if shouldRegister then
                local zoneSize = isIpl and (shellData.zoneSize or vec3(150.0, 150.0, 80.0)) or vec3(25.0, 25.0, 10.0)
                PropertyZones[p.id] = lib.zones.box({
                    coords = shellCoords,
                    size = zoneSize,
                    debug = Settings.Debug.Zones,
                    onEnter = function()
                        local shellName = p.metadata.shell or 'Standard Motel'
                        SpawnShellForProperty(p.id, shellName, shellCoords)

                        LoadFurnitures(p.id)
                        TriggerServerEvent('LNS_Housing:server:enterPropertyBucket', p.id)

                        if lib.callback.await('LNS_Housing:server:checkPermission', false, 'house', p.id, 'manage') then
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
                        
                        SetTimeout(0, function()
                            if PropertyZones[p.id] then
                                local zone = PropertyZones[p.id]
                                PropertyZones[p.id] = nil
                                pcall(function()
                                    zone:remove()
                                end)
                            end
                        end)
                    end
                })
            end
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
                if lib.callback.await('LNS_Housing:server:checkPermission', false, 'house', p.id, 'manage') then
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
                    if lib.callback.await('LNS_Housing:server:checkPermission', false, 'house', p.id, 'manage') then
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
                                    return lib.callback.await('LNS_Housing:server:checkPermission', false, 'house', id, 'entry')
                                end,
                                onSelect = function()
                                    EnterShellProperty(id)
                                end
                            },
                            --[[ Idk what i should do ... {
                                label = 'Pay Rent / Debt',
                                icon = 'fas fa-dollar-sign',
                                canInteract = function()
                                    local prop = Properties[id]
                                    if not prop or prop.sale_type ~= 'rent' or prop.owner ~= Bridge.Client.GetIdentifier() then return false end
                                    local hasDebt = (prop.metadata.rent_debt and prop.metadata.rent_debt > 0) or (prop.metadata.last_rent_paid and (GetCloudTimeAsInt() - prop.metadata.last_rent_paid > (Settings.Rent and Settings.Rent.RentPeriod or 604800)))
                                    return hasDebt
                                end,
                                onSelect = function()
                                    local prop = Properties[id]
                                    prop.focusTab = 'rent'
                                    TriggerEvent('LNS_Housing:client:openPanel', prop)
                                end
                            },]]
                            {
                                label = 'Retrieve Belongings',
                                icon = 'fas fa-box-open',
                                canInteract = function()
                                    local prop = Properties[id]
                                    if not prop or prop.sale_type ~= 'rent' or prop.owner ~= Bridge.Client.GetIdentifier() then return false end
                                    local isOverdue = prop.metadata and prop.metadata.due_by and (GetCloudTimeAsInt() > prop.metadata.due_by)
                                    return isOverdue
                                end,
                                onSelect = function()
                                    OpenBelongingsRetrieval(id)
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
                                    return lib.callback.await('LNS_Housing:server:checkPermission', false, 'house', id, 'lockpick')
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
                            return lib.callback.await('LNS_Housing:server:checkPermission', false, 'house', id, 'entry')
                        end,
                        onSelect = function()
                            EnterShellProperty(id)
                        end
                    },
                    {
                        label = 'Pay Rent / Debt',
                        icon = 'fas fa-dollar-sign',
                        canInteract = function()
                            local prop = Properties[id]
                            if not prop or prop.sale_type ~= 'rent' or prop.owner ~= Bridge.Client.GetIdentifier() then return false end
                            local hasDebt = (prop.metadata.rent_debt and prop.metadata.rent_debt > 0) or (prop.metadata.last_rent_paid and (GetCloudTimeAsInt() - prop.metadata.last_rent_paid > (Settings.Rent and Settings.Rent.RentPeriod or 604800)))
                            return hasDebt
                        end,
                        onSelect = function()
                            local prop = Properties[id]
                            prop.focusTab = 'rent'
                            TriggerEvent('LNS_Housing:client:openPanel', prop)
                        end
                    },
                    {
                        label = 'Retrieve Belongings',
                        icon = 'fas fa-box-open',
                        canInteract = function()
                            local prop = Properties[id]
                            if not prop or prop.sale_type ~= 'rent' or prop.owner ~= Bridge.Client.GetIdentifier() then return false end
                            local isOverdue = prop.metadata and prop.metadata.due_by and (GetCloudTimeAsInt() > prop.metadata.due_by)
                            return isOverdue
                        end,
                        onSelect = function()
                            OpenBelongingsRetrieval(id)
                        end
                    },
                    {
                        label = 'Lock/Unlock ' .. p.label,
                        icon = 'fas fa-key',
                        canInteract = function()
                            return lib.callback.await('LNS_Housing:server:checkPermission', false, 'house', id, 'entry') or lib.callback.await('LNS_Housing:server:checkPermission', false, 'house', id, 'manage')
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
                            return lib.callback.await('LNS_Housing:server:checkPermission', false, 'house', id, 'lockpick')
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
                Freecam:SetActive(false)
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

    if Properties then
        for id, p in pairs(Properties) do
            Bridge.Client.UnregisterGarage(id)
        end
    end

    Properties = {}
    CurrentProperty = nil
    CurrentInterior = 0
end

function InitializeHousing()
    CleanUpHousingSession()

    local ped = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)
    local isSpawningInShell = playerCoords.z < -70.0
    if not isSpawningInShell then
        for _, shellData in pairs(Settings.Shells) do
            if shellData.ipls and shellData.coords then
                if #(playerCoords - vec3(shellData.coords.x, shellData.coords.y, shellData.coords.z)) < 35.0 then
                    isSpawningInShell = true
                    break
                end
            end
        end
        if not isSpawningInShell and Settings.IPLs then
            for _, iplData in pairs(Settings.IPLs) do
                if iplData.coords then
                    if #(playerCoords - vec3(iplData.coords.x, iplData.coords.y, iplData.coords.z)) < 85.0 then
                        isSpawningInShell = true
                        break
                    end
                end
            end
        end
    end

    if isSpawningInShell then
        DoScreenFadeOut(0)
        FreezeEntityPosition(ped, true)
    end

    Properties = lib.callback.await('LNS_Housing:server:getProperties', false)
    
    if Properties then
        UpdatePropertyBlips()

        for id, p in pairs(Properties) do
            RegisterPropertyZones(p)
            if p.metadata and p.metadata.garage_data then
                Bridge.Client.RegisterGarage(p.id, p.label, p.metadata.garage_data)
            end
        end

        CreateThread(function()
            Wait(1500) 
            for id, p in pairs(Properties) do
                RegisterPropertyEntranceTargets(p)
            end
        end)
    end

    if isSpawningInShell then
        local currentPropId = nil
        local foundShellCoords = nil
        if Properties then
            for id, p in pairs(Properties) do
                if p.metadata and p.metadata.shell and p.metadata.shell ~= 'mlo' then
                    local shellName = p.metadata.shell or 'Standard Motel'
                    local shellData = (Settings.IPLs and Settings.IPLs[shellName]) or Settings.Shells[shellName]
                    if shellData then
                        local shellCoords
                        if shellData.ipls then
                            shellCoords = vec3(shellData.coords.x, shellData.coords.y, shellData.coords.z)
                        else
                            local doorCoords = GetEntranceCoords(p)
                            if doorCoords then
                                shellCoords = vec3(doorCoords.x, doorCoords.y, Settings.ShellSpawningZ or -100.0)
                            end
                        end

                        local isIpl = shellData.ipls ~= nil
                        if shellCoords and #(playerCoords - shellCoords) < (isIpl and 85.0 or 35.0) then
                            currentPropId = p.id
                            foundShellCoords = shellCoords
                            break
                        end
                    end
                end
            end
        end

        if currentPropId then
            local p = Properties[currentPropId]
            local shellName = p.metadata.shell or 'Standard Motel'
            local shellEntity, spawnCoords, heading = SpawnShellForProperty(currentPropId, shellName, foundShellCoords)
            
            TriggerServerEvent('LNS_Housing:server:enterPropertyBucket', currentPropId)
            LoadFurnitures(currentPropId)

            local currentPed = PlayerPedId()
            RequestCollisionAtCoord(playerCoords.x, playerCoords.y, playerCoords.z)
            local startColl = GetGameTimer()
            while not HasCollisionLoadedAroundEntity(currentPed) and (GetGameTimer() - startColl) < 2000 do
                Wait(50)
                currentPed = PlayerPedId()
                RequestCollisionAtCoord(playerCoords.x, playerCoords.y, playerCoords.z)
            end
            Wait(150)
            SetEntityCoords(currentPed, playerCoords.x, playerCoords.y, playerCoords.z, false, false, false, false)
        end
        FreezeEntityPosition(PlayerPedId(), false)
        DoScreenFadeIn(1000)
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

        if v.metadata and v.metadata.garage_data then
            Bridge.Client.RegisterGarage(v.id, v.label, v.metadata.garage_data)
        else
            Bridge.Client.UnregisterGarage(v.id)
        end
    end
    
    for k, v in pairs(Properties) do
        if not allProperties[k] then
            if EntranceTargets[k] then
                exports.ox_target:removeZone(EntranceTargets[k])
                EntranceTargets[k] = nil
            end
            Bridge.Client.UnregisterGarage(k)
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
    local shellData = (Settings.IPLs and Settings.IPLs[shellName]) or Settings.Shells[shellName]
    if not shellData then return nil end

    if shellData.ipls then
        if type(shellData.ipls) == 'table' then
            for _, iplName in ipairs(shellData.ipls) do
                if not IsIplActive(iplName) then
                    RequestIpl(iplName)
                end
            end
        elseif type(shellData.ipls) == 'string' then
            if not IsIplActive(shellData.ipls) then
                RequestIpl(shellData.ipls)
            end
        end

        local spawnCoords = vec3(shellData.coords.x, shellData.coords.y, shellData.coords.z)
        local heading = shellData.coords.w or 0.0

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
                        return lib.callback.await('LNS_Housing:server:checkPermission', false, 'house', propertyId, 'entry') or lib.callback.await('LNS_Housing:server:checkPermission', false, 'house', propertyId, 'manage')
                    end,
                    onSelect = function()
                        TriggerServerEvent('LNS_Housing:server:toggleLock', propertyId)
                    end
                })
            end

            local exitCoords = spawnCoords
            if shellData.exitCoords then
                exitCoords = vec3(shellData.exitCoords.x, shellData.exitCoords.y, shellData.exitCoords.z)
            end

            ExitTargets[propertyId] = exports.ox_target:addBoxZone({
                coords = exitCoords,
                size = vec3(1.5, 1.5, 2.0),
                rotation = heading,
                debug = Settings.Debug.Zones,
                options = options
            })
        end

        return nil, spawnCoords, heading
    end

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
                    return lib.callback.await('LNS_Housing:server:checkPermission', false, 'house', propertyId, 'entry') or lib.callback.await('LNS_Housing:server:checkPermission', false, 'house', propertyId, 'manage')
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

    local shellCoords = vec3(doorCoords.x, doorCoords.y, Settings.ShellSpawningZ or -100.0)

    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(0) end

    RegisterPropertyZones(p, true)

    local shellEntity, spawnCoords, heading = SpawnShellForProperty(propertyId, shellName, shellCoords)

    if spawnCoords then
        local ped = PlayerPedId()
        FreezeEntityPosition(ped, true)
        SetEntityCoords(ped, spawnCoords.x, spawnCoords.y, spawnCoords.z, false, false, false, false)
        SetEntityHeading(ped, heading)

        -- Temp fix for 50/50 chance to fall thru
        RequestCollisionAtCoord(spawnCoords.x, spawnCoords.y, spawnCoords.z)
        local start = GetGameTimer()
        while not HasCollisionLoadedAroundEntity(PlayerPedId()) and (GetGameTimer() - start) < 2000 do
            Wait(50)
            RequestCollisionAtCoord(spawnCoords.x, spawnCoords.y, spawnCoords.z)
        end
        Wait(150)

        SetEntityCoords(PlayerPedId(), spawnCoords.x, spawnCoords.y, spawnCoords.z, false, false, false, false)
        FreezeEntityPosition(PlayerPedId(), false)
    end

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

    local shellName = p.metadata.shell or 'Standard Motel'
    local shellData = (Settings.IPLs and Settings.IPLs[shellName]) or Settings.Shells[shellName]
    if shellData and shellData.ipls then
        if type(shellData.ipls) == 'table' then
            for _, iplName in ipairs(shellData.ipls) do
                if IsIplActive(iplName) then
                    RemoveIpl(iplName)
                end
            end
        elseif type(shellData.ipls) == 'string' then
            if IsIplActive(shellData.ipls) then
                RemoveIpl(shellData.ipls)
            end
        end
    end

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityCoords(ped, doorCoords.x, doorCoords.y, doorCoords.z, false, false, false, false)

    -- Temp fix for 50/50 chance to fall thru
    RequestCollisionAtCoord(doorCoords.x, doorCoords.y, doorCoords.z)
    local start = GetGameTimer()
    while not HasCollisionLoadedAroundEntity(PlayerPedId()) and (GetGameTimer() - start) < 2000 do
        Wait(50)
        RequestCollisionAtCoord(doorCoords.x, doorCoords.y, doorCoords.z)
    end
    Wait(150)

    SetEntityCoords(PlayerPedId(), doorCoords.x, doorCoords.y, doorCoords.z, false, false, false, false)
    FreezeEntityPosition(PlayerPedId(), false)

    DoScreenFadeIn(1000)
end

RegisterNetEvent('LNS_Housing:client:triggerHouseAlarm', function(coords, durationMs)
    local playerCoords = GetEntityCoords(PlayerPedId())
    local alarmCoords = vec3(coords.x, coords.y, coords.z)
    local shellCoords = vec3(coords.x, coords.y, Settings.ShellSpawningZ or -100.0)
    local isNearEntrance = #(playerCoords - alarmCoords) < 35.0
    local isNearShell = #(playerCoords - shellCoords) < 35.0
    if not isNearShell and Settings.IPLs then
        for _, iplData in pairs(Settings.IPLs) do
            if iplData.coords then
                local iplCoords = vec3(iplData.coords.x, iplData.coords.y, iplData.coords.z)
                if #(playerCoords - iplCoords) < 85.0 then
                    isNearShell = true
                    break
                end
            end
        end
    end

    if isNearEntrance or isNearShell then
        activeAlarmsCount = activeAlarmsCount + 1

        local attempts = 0
        while not RequestScriptAudioBank("sound/audiodirectory/lns_bank", false) and attempts < 100 do
            Wait(100)
            attempts = attempts + 1
        end

        local outsideSoundId = GetSoundId()
        PlaySoundFromCoord(outsideSoundId, "house_alarm", alarmCoords.x, alarmCoords.y, alarmCoords.z, "lns_soundset", false, 15.0, false)

        local insideSoundId = GetSoundId()
        PlaySoundFromCoord(insideSoundId, "house_alarm", shellCoords.x, shellCoords.y, shellCoords.z, "lns_soundset", false, 15.0, false)

        Wait(durationMs or 30000)

        StopSound(outsideSoundId)
        ReleaseSoundId(outsideSoundId)
        StopSound(insideSoundId)
        ReleaseSoundId(insideSoundId)

        activeAlarmsCount = activeAlarmsCount - 1
        if activeAlarmsCount == 0 then
            ReleaseNamedScriptAudioBank("sound/audiodirectory/lns_bank")
        end
    end
end)