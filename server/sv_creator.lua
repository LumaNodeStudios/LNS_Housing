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

    local storage = SvSettings and SvSettings.FurnitureImageStorage or { Type = 'qbox' }
    local storageType = string.lower(storage.Type or 'qbox')

    if GetResourceState('screencapture') == 'started' then
        local p = promise.new()
        local resolved = false

        local function resolvePromise(value)
            if not resolved then
                resolved = true
                p:resolve(value)
            end
        end

        if storageType == 'qbox' then
            local config = storage.Qbox or {}
            if not config.ApiKey or config.ApiKey == '' then
                debugPrint('error', 'Qbox CDN ApiKey missing in sv_settings.lua')
                return nil
            end

            exports.screencapture:remoteUpload(source, 'https://api.qbox.re/v1/file', {
                encoding = 'webp',
                maxWidth = 1280,
                maxHeight = 720,
                headers = { ['Authorization'] = config.ApiKey }
            }, function(response)
                local url = response and (response.url or (response.data and response.data.url) or (type(response) == 'string' and response))
                resolvePromise(url)
            end, 'blob')

        elseif storageType == 'fivemanage' then
            local config = storage.Fivemanage or {}
            if not config.Token or config.Token == '' then
                debugPrint('error', 'Fivemanage Token missing in sv_settings.lua')
                return nil
            end

            local uploadUrl = (config.Url and config.Url ~= '') and config.Url or 'https://api.fivemanage.com/api/v3/file'
            exports.screencapture:remoteUpload(source, uploadUrl, {
                encoding = 'webp',
                maxWidth = 1280,
                maxHeight = 720,
                headers = { ['Authorization'] = config.Token }
            }, function(response)
                local url = response and (response.url or (response.data and response.data.url) or (type(response) == 'string' and response))
                resolvePromise(url)
            end, 'blob')

        else
            -- 'r2', 'local', or custom: use serverCapture then pass to UploadPropertyPhotoJS
            exports.screencapture:serverCapture(source, {
                encoding = 'webp',
                maxWidth = 1280,
                maxHeight = 720
            }, function(data)
                if data and data ~= '' then
                    local ok, url = pcall(function()
                        return exports.LNS_Housing:UploadPropertyPhotoJS(data)
                    end)
                    resolvePromise(ok and url or nil)
                else
                    resolvePromise(nil)
                end
            end)
        end

        SetTimeout(15000, function()
            if not resolved then
                debugPrint('error', 'Photo upload timed out on server')
                resolvePromise(nil)
            end
        end)

        return Citizen.Await(p)
    end

    -- Fallback if client sent base64 and screencapture server export is not running
    if base64Data and base64Data ~= '' then
        local ok, url = pcall(function()
            return exports.LNS_Housing:UploadPropertyPhotoJS(base64Data)
        end)
        return ok and url or nil
    end

    return nil
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
        local doorIds, processedSpawn = ProcessPropertyDoors(data.doors, data.name or data.label)
        data.doors = doorIds
        if processedSpawn then
            spawnCoords = processedSpawn
        end
    end

    if not spawnCoords and data.interiorCoords then
        local ic = data.interiorCoords
        spawnCoords = vector4(ic.x, ic.y, ic.z, ic.h or 0.0)
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

    data.interior_id = tonumber(data.interiorId or data.interior_id) or nil
    data.interior_coords = data.interiorCoords or data.interior_coords or nil
    data.interior_center = data.interiorCenter or data.interior_center or nil
    data.room_count = tonumber(data.roomCount or data.room_count) or nil

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

    if data.zone_data and data.zone_data.points and #data.zone_data.points >= 3 then
        data.size = calculateSquareFootage(data.zone_data)
    elseif data.room_count and data.room_count > 0 then
        data.size = math.max(600, data.room_count * 250)
    elseif not data.size or data.size == 0 then
        data.size = 1200
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