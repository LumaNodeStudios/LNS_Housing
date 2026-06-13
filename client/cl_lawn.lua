local Settings = lib.load('shared.settings')
Settings.Housing.Lawn.GrowthTime = Settings.Debug.LawnGrowth and 300 or 604800

local ServerTimeOffset = 0
local LastGrassUpdate = {}

CreateThread(function()
    local serverTime = lib.callback.await('LNS_Housing:server:getServerTime', false)
    if serverTime then
        ServerTimeOffset = serverTime - GetCloudTimeAsInt()
    end
end)

local function GetServerTime()
    return GetCloudTimeAsInt() + ServerTimeOffset
end

local YardZones = {}
ActiveYardPropertyId = nil
SpawnedGrassProps = {}
local YardCoords = {}
local MowingActive = false
local MowerPropHandle = nil
local GrassLoadedFor = {}
local YardCenters = {}

local function isPointInPolygon(point, polygonPoints)
    local x, y = point.x, point.y
    local inside = false
    local j = #polygonPoints
    for i = 1, #polygonPoints do
        local xi, yi = polygonPoints[i].x, polygonPoints[i].y
        local xj, yj = polygonPoints[j].x, polygonPoints[j].y
        local intersect = ((yi > y) ~= (yj > y))
            and (x < (xj - xi) * (y - yi) / (yj - yi) + xi)
        if intersect then inside = not inside end
        j = i
    end
    return inside
end

local function deterministicRandom(x, y)
    local val = math.sin(x * 12.9898 + y * 78.233) * 43758.5453
    return val - math.floor(val)
end

local function GetYardGridCoords(propertyId, points, spacing)
    if YardCoords[propertyId] then
        return YardCoords[propertyId]
    end
    local minX, maxX = 99999.0, -99999.0
    local minY, maxY = 99999.0, -99999.0
    local minZ = 99999.0
    for _, p in ipairs(points) do
        if p.x < minX then minX = p.x end
        if p.x > maxX then maxX = p.x end
        if p.y < minY then minY = p.y end
        if p.y > maxY then maxY = p.y end
        if p.z < minZ then minZ = p.z end
    end
    local coords = {}
    local step = spacing or 1.5
    for x = minX, maxX, step do
        for y = minY, maxY, step do
            local pt = vector3(x, y, minZ)
            if isPointInPolygon(pt, points) then
                coords[#coords + 1] = {x = x, y = y, z = minZ}
            end
        end
    end
    YardCoords[propertyId] = coords
    return coords
end

local function SpawnYardGrass(propertyId)
    local p = Properties[propertyId]
    if not p or not p.yard_zone_data or not p.yard_zone_data.points or #p.yard_zone_data.points < 3 then return end

    local now = GetServerTime()
    
    
    local lawnData = p.lawn_data or {}

    local coords = GetYardGridCoords(propertyId, p.yard_zone_data.points, Settings.Housing.Lawn.Spacing)

    local maxProps = 100
    local step = 1
    if #coords > maxProps then
        step = math.ceil(#coords / maxProps)
    end

    CreateThread(function()
        for i = 1, #coords, step do
            
            
            local keyStr = tostring(i)
            local bladeMowedAt = lawnData[keyStr] or lawnData[i] or p.last_mowed or 0

            local timePassed = now - bladeMowedAt
            local growth = math.min(1.0, timePassed / Settings.Housing.Lawn.GrowthTime)

            
            local grassObj = nil
            for j = 1, #SpawnedGrassProps do
                local grass = SpawnedGrassProps[j]
                if grass.propertyId == propertyId and grass.coordIndex == i then
                    grassObj = grass
                    break
                end
            end

            if growth < 0.1 then
                
                if grassObj and DoesEntityExist(grassObj.entity) then
                    DeleteEntity(grassObj.entity)
                    
                    for j = #SpawnedGrassProps, 1, -1 do
                        if SpawnedGrassProps[j].propertyId == propertyId and SpawnedGrassProps[j].coordIndex == i then
                            table.remove(SpawnedGrassProps, j)
                            break
                        end
                    end
                end
                goto continue
            end

            local coord = coords[i]
            local randVal = deterministicRandom(coord.x, coord.y)

            if grassObj then
                
                if DoesEntityExist(grassObj.entity) then
                    local range = 1.0 - randVal
                    if range < 0.05 then range = 0.05 end
                    local propGrowth = math.min(1.0, (growth - randVal) / range)
                    local modelCount = #Settings.Housing.Lawn.Models
                    local modelIndex = (math.floor(randVal * modelCount) % modelCount) + 1
                    local modelData = Settings.Housing.Lawn.Models[modelIndex]
                    local zOffset = modelData.zOffset or 0.0
                    local maxSink = Settings.Housing.Lawn.MaxSink or 0.25
                    local currentZOffset = zOffset - (1.0 - propGrowth) * maxSink
                    local currentCoords = GetEntityCoords(grassObj.entity)
                    local baseGroundZ = grassObj.groundZ or currentCoords.z
                    local targetZ = baseGroundZ + currentZOffset
                    if math.abs(currentCoords.z - targetZ) > 0.005 then
                        SetEntityCoords(grassObj.entity, currentCoords.x, currentCoords.y, targetZ, false, false, false, false)
                        grassObj.coord = vector3(currentCoords.x, currentCoords.y, targetZ)
                    end
                end
                goto continue
            end

            
            if randVal <= growth then
                local modelCount = #Settings.Housing.Lawn.Models
                local modelIndex = (math.floor(randVal * modelCount) % modelCount) + 1
                local modelData = Settings.Housing.Lawn.Models[modelIndex]
                local modelName = modelData.model
                local zOffset = modelData.zOffset or 0.0
                if not modelName then goto continue end

                local hash = type(modelName) == 'string' and GetHashKey(modelName) or modelName
                if not IsModelValid(hash) then goto continue end

                lib.requestModel(hash)

                local groundZ = coord.z
                for attempt = 1, 10 do
                    local found, gz = GetGroundZFor_3dCoord(coord.x, coord.y, coord.z + 5.0, false)
                    if found then
                        groundZ = gz
                        break
                    end
                    Wait(100)
                end

                local obj = CreateObject(hash, coord.x, coord.y, groundZ, false, false, false)
                SetEntityCollision(obj, false, false)

                local attempts = 0
                repeat
                    Wait(0)
                    attempts = attempts + 1
                until DoesEntityExist(obj) or attempts > 20

                local placed = false
                for t = 1, 5 do
                    if PlaceObjectOnGroundProperly(obj) then
                        placed = true
                        break
                    end
                    Wait(50)
                end

                local baseGroundZ = groundZ
                if not placed then
                    local found, gz = GetGroundZFor_3dCoord(coord.x, coord.y, groundZ + 5.0, false)
                    if found then baseGroundZ = gz end
                else
                    local finalCoords = GetEntityCoords(obj)
                    baseGroundZ = finalCoords.z
                end

                local range = 1.0 - randVal
                if range < 0.05 then range = 0.05 end
                local propGrowth = math.min(1.0, (growth - randVal) / range)
                local maxSink = Settings.Housing.Lawn.MaxSink or 0.25
                local currentZOffset = zOffset - (1.0 - propGrowth) * maxSink

                SetEntityCoords(obj, coord.x, coord.y, baseGroundZ + currentZOffset, false, false, false, false)
                FreezeEntityPosition(obj, true)

                table.insert(SpawnedGrassProps, {
                    entity = obj,
                    coord = GetEntityCoords(obj),
                    groundZ = baseGroundZ,
                    propertyId = propertyId,
                    coordIndex = i,
                    mowed = false
                })
            end
            ::continue::
        end
    end)
end

function StopMowing()
    if not MowingActive then return end
    MowingActive = false

    if MowerPropHandle and DoesEntityExist(MowerPropHandle) then
        DeleteEntity(MowerPropHandle)
        MowerPropHandle = nil
    end

    local ped = cache.ped
    local animDict = 'anim@heists@box_carry@'
    StopAnimTask(ped, animDict, 'walk', 1.0)
    ClearPedTasks(ped)
    lib.hideTextUI()
end

function StartMowing(propertyId, isAuto)
    if MowingActive then
        if not isAuto then
            Bridge.Client.Notify('You are already mowing!', 'error')
        end
        return
    end

    local p = Properties[propertyId]
    if not p then
        if not isAuto then
            Bridge.Client.Notify('No property found here.', 'error')
        end
        return
    end

    
    local now = GetServerTime()
    local lawnData = p.lawn_data or {}
    local coords = GetYardGridCoords(propertyId, p.yard_zone_data.points, Settings.Housing.Lawn.Spacing)
    local hasGrowth = false
    for i = 1, #coords do
        local keyStr = tostring(i)
        local bladeMowedAt = lawnData[keyStr] or lawnData[i] or p.last_mowed or 0
        local growth = math.min(1.0, (now - bladeMowedAt) / Settings.Housing.Lawn.GrowthTime)
        if growth >= 0.1 then
            hasGrowth = true
            break
        end
    end

    if not hasGrowth then
        if not isAuto then
            Bridge.Client.Notify('The lawn is already clean and short!', 'inform')
        end
        return
    end

    local ped = cache.ped
    local currentVehicle = GetVehiclePedIsIn(ped, false)
    local isVehicleMower = false
    if currentVehicle ~= 0 then
        local model = GetEntityModel(currentVehicle)
        local mowerVehs = Settings.Housing.Lawn.MowerVehicles or { 'mower' }
        for _, name in ipairs(mowerVehs) do
            if model == GetHashKey(name) then
                isVehicleMower = true
                break
            end
        end
    end

    MowingActive = true

    if not isAuto then
        Wait(500) 
    end

    if isVehicleMower then
        lib.showTextUI('Mowing Lawn - Drive over long grass', { position = 'right-center' })
    else
        local modelHash = GetHashKey(Settings.Housing.Lawn.MowerProp)
        lib.requestModel(modelHash)

        local coords2 = GetEntityCoords(ped)
        local mowerProp = CreateObject(modelHash, coords2.x, coords2.y, coords2.z, true, false, false)
        SetEntityCollision(mowerProp, false, false)
        AttachEntityToEntity(mowerProp, ped, 0, 0.0, 1.0, -0.9, 0.0, 0.0, 180.0, false, false, false, false, 2, true)
        MowerPropHandle = mowerProp

        lib.showTextUI('[E] Put Away Mower', { position = 'right-center' })

        local animDict = 'anim@heists@box_carry@'
        lib.requestAnimDict(animDict)
        TaskPlayAnim(ped, animDict, 'walk', 8.0, -8.0, -1, 49, 0, false, false, false)
        RemoveAnimDict(animDict)
    end

    
    local newlyMowedIndices = {}

    CreateThread(function()
        local lastCheckTime = 0
        local animDict = 'anim@heists@box_carry@'
        while MowingActive do
            Wait(0)
            local playerPed = cache.ped

            if isVehicleMower then
                
                local veh = GetVehiclePedIsIn(playerPed, false)
                if veh ~= currentVehicle then
                    StopMowing()
                    if #newlyMowedIndices > 0 then
                        TriggerServerEvent('LNS_Housing:server:saveMowedBlades', propertyId, newlyMowedIndices, true)
                    end
                    break
                end

                
                if ActiveYardPropertyId ~= propertyId then
                    StopMowing()
                    if #newlyMowedIndices > 0 then
                        TriggerServerEvent('LNS_Housing:server:saveMowedBlades', propertyId, newlyMowedIndices, true)
                    end
                    break
                end
            else
                if not IsEntityPlayingAnim(playerPed, animDict, 'walk', 3) then
                    lib.requestAnimDict(animDict)
                    TaskPlayAnim(playerPed, animDict, 'walk', 8.0, -8.0, -1, 49, 0, false, false, false)
                    RemoveAnimDict(animDict)
                end

                DisableControlAction(0, 21, true)
                DisableControlAction(0, 22, true)
                DisableControlAction(0, 38, true)

                if IsDisabledControlJustPressed(0, 38) then
                    StopMowing()
                    
                    if #newlyMowedIndices > 0 then
                        TriggerServerEvent('LNS_Housing:server:saveMowedBlades', propertyId, newlyMowedIndices, true)
                    end
                    Bridge.Client.Notify('You put away the mower.', 'inform')
                    break
                end
            end

            local currentTime = GetGameTimer()
            if currentTime - lastCheckTime > 150 then
                lastCheckTime = currentTime

                local mowerCoords
                local cutDistance = Settings.Housing.Lawn.CutDistance or 1.0

                if isVehicleMower then
                    mowerCoords = GetEntityCoords(currentVehicle)
                    cutDistance = Settings.Housing.Lawn.VehicleCutDistance or 3.0
                else
                    if not MowerPropHandle or not DoesEntityExist(MowerPropHandle) then
                        local modelHash = GetHashKey(Settings.Housing.Lawn.MowerProp)
                        local newCoords = GetEntityCoords(playerPed)
                        local newProp = CreateObject(modelHash, newCoords.x, newCoords.y, newCoords.z, true, false, false)
                        SetEntityCollision(newProp, false, false)
                        AttachEntityToEntity(newProp, playerPed, 0, 0.0, 1.0, -0.9, 0.0, 0.0, 180.0, false, false, false, false, 2, true)
                        MowerPropHandle = newProp
                    end
                    mowerCoords = GetEntityCoords(MowerPropHandle)
                end

                local cutAny = false

                for i = 1, #SpawnedGrassProps do
                    local grass = SpawnedGrassProps[i]
                    if grass.propertyId == propertyId and not grass.mowed then
                        local dist = #(mowerCoords - grass.coord)
                        if dist < cutDistance then
                            if not grass.nearSince then
                                grass.nearSince = GetGameTimer()
                            elseif GetGameTimer() - grass.nearSince > (isVehicleMower and 0 or 600) then
                                grass.mowed = true
                                cutAny = true
                                
                                newlyMowedIndices[#newlyMowedIndices + 1] = grass.coordIndex

                                if DoesEntityExist(grass.entity) then
                                    DeleteEntity(grass.entity)
                                end

                                RequestNamedPtfxAsset('core')
                                if HasNamedPtfxAssetLoaded('core') then
                                    UseParticleFxAssetNextCall('core')
                                    StartParticleFxNonLoopedAtCoord('wheel_fric_grass', grass.coord.x, grass.coord.y, grass.coord.z + 0.1, 0.0, 0.0, 0.0, 1.2, false, false, false)
                                end
                            end
                        else
                            grass.nearSince = nil
                        end
                    end
                end

                if cutAny then
                    
                    if #newlyMowedIndices >= 10 then
                        TriggerServerEvent('LNS_Housing:server:saveMowedBlades', propertyId, newlyMowedIndices, false)
                        newlyMowedIndices = {}
                    end

                    
                    local total = 0
                    local cut = 0
                    for i = 1, #SpawnedGrassProps do
                        if SpawnedGrassProps[i].propertyId == propertyId then
                            total = total + 1
                            if SpawnedGrassProps[i].mowed then cut = cut + 1 end
                        end
                    end

                    if total > 0 and (cut / total) >= 0.90 then
                        
                        TriggerServerEvent('LNS_Housing:server:finishMowing', propertyId, newlyMowedIndices, true)
                        newlyMowedIndices = {}
                        Bridge.Client.Notify('Lawn successfully mowed! It will grow back over time.', 'success')
                        StopMowing()
                    end
                end
            end
        end
    end)
end

RegisterNetEvent('LNS_Housing:client:useMower', function()
    if MowingActive then
        StopMowing()
        Bridge.Client.Notify('You put away the mower.', 'inform')
        return
    end

    if not ActiveYardPropertyId then
        Bridge.Client.Notify('You must be in a yard to use the mower!', 'error')
        return
    end

    StartMowing(ActiveYardPropertyId)
end)

function OpenYardMenu(propertyId)
    local p = Properties[propertyId]
    if not p then return end

    local now = GetServerTime()
    local lawnData = p.lawn_data or {}
    local coords = GetYardGridCoords(propertyId, p.yard_zone_data and p.yard_zone_data.points or {}, Settings.Housing.Lawn.Spacing)

    
    local totalGrowth = 0
    local count = math.max(1, #coords)
    for i = 1, #coords do
        local keyStr = tostring(i)
        local bladeMowedAt = lawnData[keyStr] or lawnData[i] or p.last_mowed or 0
        totalGrowth = totalGrowth + math.min(1.0, (now - bladeMowedAt) / Settings.Housing.Lawn.GrowthTime)
    end
    local growth = math.min(100, math.floor((totalGrowth / count) * 100))

    local options = {
        {
            title = 'Grass Growth',
            description = 'Current growth: ' .. growth .. '%',
            progress = growth,
            colorScheme = 'green',
            readOnly = true
        }
    }

    lib.registerContext({
        id = 'housing_yard_menu',
        title = 'Yard Management - ' .. p.label,
        options = options
    })
    lib.showContext('housing_yard_menu')
end

local function GetYardCenter(propertyId, points)
    if YardCenters[propertyId] then return YardCenters[propertyId] end
    local cx, cy, cz = 0, 0, 0
    for _, pt in ipairs(points) do
        cx = cx + pt.x
        cy = cy + pt.y
        cz = cz + pt.z
    end
    local n = #points
    YardCenters[propertyId] = vector3(cx / n, cy / n, cz / n)
    return YardCenters[propertyId]
end

local function LoadGrassForProperty(propertyId)
    local currentTime = GetGameTimer()
    if GrassLoadedFor[propertyId] then
        if not MowingActive and (not LastGrassUpdate[propertyId] or currentTime - LastGrassUpdate[propertyId] > 15000) then
            LastGrassUpdate[propertyId] = currentTime
            SpawnYardGrass(propertyId)
        end
        return
    end
    GrassLoadedFor[propertyId] = true
    LastGrassUpdate[propertyId] = currentTime
    SpawnYardGrass(propertyId)
end

local function UnloadGrassForProperty(propertyId)
    if not GrassLoadedFor[propertyId] then return end
    GrassLoadedFor[propertyId] = nil
    LastGrassUpdate[propertyId] = nil
    local remaining = {}
    for i = 1, #SpawnedGrassProps do
        local grass = SpawnedGrassProps[i]
        if grass.propertyId == propertyId then
            if DoesEntityExist(grass.entity) then DeleteEntity(grass.entity) end
        else
            remaining[#remaining + 1] = grass
        end
    end
    SpawnedGrassProps = remaining
end

function RegisterYardZone(p)
    if not Settings.Housing.Lawn or not Settings.Housing.Lawn.Enabled then return end
    if YardZones[p.id] then return end
    if not p.yard_zone_data or not p.yard_zone_data.points or #p.yard_zone_data.points < 3 then return end

    local thickness = p.yard_zone_data.thickness or 10.0
    local points = {}
    for i = 1, #p.yard_zone_data.points do
        local pt = p.yard_zone_data.points[i]
        points[i] = vector3(pt.x, pt.y, pt.z + (thickness / 2))
    end

    GetYardCenter(p.id, p.yard_zone_data.points)

    YardZones[p.id] = lib.zones.poly({
        points = points,
        thickness = thickness,
        debug = Settings.Debug.Zones,
        onEnter = function()
            ActiveYardPropertyId = p.id
        end,
        onExit = function()
            if ActiveYardPropertyId == p.id then
                ActiveYardPropertyId = nil
            end
        end
    })
end

CreateThread(function()
    while true do
        Wait(2000)
        if not Settings.Housing.Lawn or not Settings.Housing.Lawn.Enabled then goto skip end

        local playerCoords = GetEntityCoords(cache.ped)
        local renderDist = Settings.Housing.Lawn.RenderDistance or 80.0

        for propertyId, center in pairs(YardCenters) do
            local dist = #(playerCoords - center)
            if dist <= renderDist then
                LoadGrassForProperty(propertyId)
            else
                UnloadGrassForProperty(propertyId)
            end
        end

        ::skip::
    end
end)

function RefreshYardGrass(propertyId)
    if not GrassLoadedFor[propertyId] then return end
    local remaining = {}
    for i = 1, #SpawnedGrassProps do
        local grass = SpawnedGrassProps[i]
        if grass.propertyId == propertyId then
            if DoesEntityExist(grass.entity) then DeleteEntity(grass.entity) end
        else
            remaining[#remaining + 1] = grass
        end
    end
    SpawnedGrassProps = remaining
    GrassLoadedFor[propertyId] = nil
    LastGrassUpdate[propertyId] = nil
    LoadGrassForProperty(propertyId)
end

function CleanUpLawn()
    StopMowing()
    for i = 1, #SpawnedGrassProps do
        if DoesEntityExist(SpawnedGrassProps[i].entity) then
            DeleteEntity(SpawnedGrassProps[i].entity)
        end
    end
    SpawnedGrassProps = {}
    GrassLoadedFor = {}
    YardCenters = {}
    LastGrassUpdate = {}
    for id, zone in pairs(YardZones) do
        if zone and zone.remove then
            pcall(function() zone:remove() end)
        end
    end
    YardZones = {}
end

CreateThread(function()
    while true do
        Wait(1000)
        if Settings.Housing.Lawn and Settings.Housing.Lawn.Enabled and ActiveYardPropertyId and not MowingActive then
            local ped = cache.ped
            local vehicle = GetVehiclePedIsIn(ped, false)
            if vehicle ~= 0 then
                local model = GetEntityModel(vehicle)
                local isVehicleMower = false
                local mowerVehs = Settings.Housing.Lawn.MowerVehicles or { 'mower' }
                for _, name in ipairs(mowerVehs) do
                    if model == GetHashKey(name) then
                        isVehicleMower = true
                        break
                    end
                end
                
                if isVehicleMower then
                    StartMowing(ActiveYardPropertyId, true)
                end
            end
        end
    end
end)

RegisterNetEvent('LNS_Housing:client:syncCutGrass', function(propertyId, indices)
    local p = Properties[propertyId]
    if p then
        if not p.lawn_data then p.lawn_data = {} end
        local now = GetServerTime()
        for _, idx in ipairs(indices) do
            p.lawn_data[tostring(idx)] = now
        end
    end

    for _, idx in ipairs(indices) do
        for i = 1, #SpawnedGrassProps do
            local grass = SpawnedGrassProps[i]
            if grass.propertyId == propertyId and grass.coordIndex == idx and not grass.mowed then
                grass.mowed = true
                if DoesEntityExist(grass.entity) then
                    DeleteEntity(grass.entity)
                end
            end
        end
    end
end)

RegisterNetEvent('LNS_Housing:client:syncLawnUpdate', function(propertyId, lawnData, lastMowed)
    local p = Properties[propertyId]
    if p then
        p.lawn_data = lawnData
        p.last_mowed = lastMowed
        if ActiveYardPropertyId == propertyId and RefreshYardGrass then
            RefreshYardGrass(propertyId)
        end
    end
end)