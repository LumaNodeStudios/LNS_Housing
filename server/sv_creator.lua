local Settings = lib.load('shared.settings')
local SvSettings = lib.load('shared.sv_settings')
SQFT_PER_SQM = 10.7639

exports('GetSvSettings', function()
    return SvSettings
end)

function GetRealEstatePermission(source)
    return CheckPermission(source, 'realestate')
end

function calculateZoneArea(points)
    if not points or #points < 3 then return 0 end
    local area = 0
    local n = #points
    for i = 1, n do
        local p1 = points[i]
        local p2 = points[(i % n) + 1]
        area = area + (p1.x * p2.y - p2.x * p1.y)
    end
    return math.abs(area) / 2
end

function calculateSquareFootage(zoneData)
    if not zoneData or not zoneData.points then return 0 end
    local areaSqMeters = calculateZoneArea(zoneData.points)
    return math.floor(areaSqMeters * SQFT_PER_SQM)
end

lib.callback.register('LNS_Housing:server:uploadPhoto', function(source, base64Data)
    debugPrint('info', 'LNS_Housing:server:uploadPhoto called', {source = source})
    local promise = promise.new()
    
    TriggerEvent('LNS_Housing:server:uploadPropertyPhotoJS', base64Data, function(url)
        promise:resolve(url)
    end)
    
    return Citizen.Await(promise)
end)

lib.callback.register('LNS_Housing:server:createHouse', function(source, data)
    debugPrint('info', 'LNS_Housing:server:createHouse called', {source = source, label = data and data.label})
    local playerJob = Bridge.Server.GetPlayerJob(source)
    local citizenid = Bridge.Server.GetIdentifier(source)

    if playerJob then
        data.agency = playerJob.name
        data.agent_cid = citizenid
        local agencyConfig = Settings.RealEstate.Agencies and Settings.RealEstate.Agencies[playerJob.name]
        data.commission_rate = agencyConfig and agencyConfig.defaultCommission or 10
    end

    local spawnCoords = nil
    if data.entranceType == 'coords' and data.entranceCoords then
        data.doors = {}
        data.entrance = data.entranceCoords
        spawnCoords = vector4(data.entranceCoords.x, data.entranceCoords.y, data.entranceCoords.z, data.entranceCoords.h or 0.0)
    elseif data.doors and #data.doors > 0 then
        local doorIds = {}
        for i, door in ipairs(data.doors) do
            if type(door) == 'table' and door.isDouble then
                local doorPanels = {}
                for j, panel in ipairs(door.doors) do
                    if type(panel) == 'table' and panel.isNew then
                        doorPanels[j] = {
                            model = panel.model,
                            coords = vector3(panel.coords.x, panel.coords.y, panel.coords.z),
                            heading = panel.heading
                        }
                    elseif type(panel) == 'number' then
                        local panelData = nil
                        if exports.ox_doorlock and exports.ox_doorlock.getDoor then
                            pcall(function() panelData = exports.ox_doorlock:getDoor(panel) end)
                        end
                        if panelData and panelData.coords then
                            doorPanels[j] = {
                                model = panelData.model,
                                coords = vector3(panelData.coords.x, panelData.coords.y, panelData.coords.z),
                                heading = panelData.heading
                            }
                        end
                    end
                end
                local newDoorId = exports.ox_doorlock:createDoor({
                    name = (data.name or data.label or 'Property') .. ' Double Door ' .. i,
                    doors = doorPanels,
                    state = 1,
                    maxDistance = 2.0
                })
                doorIds[#doorIds+1] = newDoorId
                if i == 1 and door.doors and door.doors[1] and door.doors[1].coords then
                    local c = door.doors[1].coords
                    spawnCoords = vector4(c.x, c.y, c.z, door.doors[1].heading or 0.0)
                end
            elseif type(door) == 'table' and door.isNew then
                local newDoorId = exports.ox_doorlock:createDoor({
                    name = (data.name or data.label or 'Property') .. ' Door ' .. i,
                    model = door.model,
                    coords = door.coords,
                    heading = door.heading,
                    state = 1,
                    maxDistance = 2.0
                })
                doorIds[#doorIds+1] = newDoorId
                if i == 1 then
                    spawnCoords = vector4(door.coords.x, door.coords.y, door.coords.z, door.heading or 0.0)
                end
            else
                doorIds[#doorIds+1] = door
                if i == 1 then
                    local doorData = nil
                    if exports.ox_doorlock and exports.ox_doorlock.getDoor then
                        pcall(function() doorData = exports.ox_doorlock:getDoor(door) end)
                    elseif exports.ox_doorlock and exports.ox_doorlock.getDoorData then
                        pcall(function() doorData = exports.ox_doorlock:getDoorData(door) end)
                    end
                    if doorData and doorData.coords then
                        spawnCoords = vector4(doorData.coords.x, doorData.coords.y, doorData.coords.z, doorData.heading or 0.0)
                    end
                end
            end
        end
        data.doors = doorIds
    end

    if not spawnCoords and data.zone_data and data.zone_data.points and #data.zone_data.points > 0 then
        local sumX, sumY, sumZ = 0, 0, 0
        local count = #data.zone_data.points
        for _, pt in ipairs(data.zone_data.points) do
            sumX = sumX + pt.x
            sumY = sumY + pt.y
            sumZ = sumZ + pt.z
        end
        spawnCoords = vector4(sumX / count, sumY / count, sumZ / count, 0.0)
    end

    data.spawn_coords = spawnCoords

    if data.garageCoords then
        local spawn = data.garageSpawnCoords or data.garageCoords
        data.garage_data = {
            x = data.garageCoords.x,
            y = data.garageCoords.y,
            z = data.garageCoords.z,
            h = data.garageCoords.h or 0.0,
            spawn = {
                x = spawn.x,
                y = spawn.y,
                z = spawn.z,
                h = spawn.h or 0.0
            }
        }
    end

    if data.zone_data then
        data.size = calculateSquareFootage(data.zone_data)
    end

    if data.cameraPosition then
        data.camera_coords = {
            x = data.cameraPosition.x,
            y = data.cameraPosition.y,
            z = data.cameraPosition.z
        }
    end

    if data.cameraAim then
        data.camera_aim = {
            x = data.cameraAim.x,
            y = data.cameraAim.y,
            z = data.cameraAim.z
        }
    end

    if data.cameraHeading ~= nil then
        data.camera_heading = data.cameraHeading
    end

    if data.cameraModel then
        data.camera_model = data.cameraModel
    end

    if data.cameraFov ~= nil then
        data.camera_fov = data.cameraFov
    end

    local newHouse = CreateProperty(data)
    if newHouse then
        if newHouse.metadata and newHouse.metadata.garage_data then
            Bridge.Server.RegisterGarage(newHouse.id, newHouse.label, newHouse.metadata.garage_data)
        end
        TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
        return newHouse
    end
    return nil
end)