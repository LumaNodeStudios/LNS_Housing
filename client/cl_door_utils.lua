local Settings = lib.load('shared.settings')

local function ToVec3(coords)
    if not coords then return nil end
    return vec3(coords.x, coords.y, coords.z)
end

function GetOxDoorlockDoor(doorId)
    if not doorId or doorId == 0 or GetResourceState('ox_doorlock') ~= 'started' then
        return nil
    end

    local ok, door = pcall(function()
        return exports.ox_doorlock:getDoor(doorId)
    end)
    if ok and door then return door end

    ok, door = pcall(function()
        return exports.ox_doorlock:getDoorData(doorId)
    end)
    if ok and door then return door end

    return nil
end

function GetDoorInteractionPoint(model, coords, heading)
    coords = ToVec3(coords)
    if not model or not coords then
        return coords, heading or 0.0
    end

    local hash = tonumber(model) or GetHashKey(model)

    local loadedModel = false
    if not HasModelLoaded(hash) then
        local ok = pcall(function()
            lib.requestModel(hash, 3000)
        end)
        if ok and HasModelLoaded(hash) then
            loadedModel = true
        else
            return coords, heading or 0.0
        end
    end

    local min, max = GetModelDimensions(hash)
    local centerX = (min.x + max.x) * 0.5
    local centerY = (min.y + max.y) * 0.5
    local centerZ = (min.z + max.z) * 0.5

    local entity = GetClosestObjectOfType(coords.x, coords.y, coords.z, 3.0, hash, false, false, false)
    if entity ~= 0 then
        local resCoords = GetOffsetFromEntityInWorldCoords(entity, centerX, centerY, centerZ)
        local resHeading = GetEntityHeading(entity)
        if loadedModel then
            SetModelAsNoLongerNeeded(hash)
        end
        return resCoords, resHeading
    end

    local rad = math.rad(-(heading or 0.0))
    local cosRad = math.cos(rad)
    local sinRad = math.sin(rad)
    local rx = centerX * cosRad - centerY * sinRad
    local ry = centerX * sinRad + centerY * cosRad
    local interactionPoint = vec3(coords.x + rx, coords.y + ry, coords.z + centerZ)

    if loadedModel then
        SetModelAsNoLongerNeeded(hash)
    end

    return interactionPoint, heading or 0.0
end

function ResolveDoorTargetPlacement(model, coords, heading, door)
    if door and door.doors and door.doors[1] and door.doors[2] then
        local c1 = ToVec3(door.doors[1].coords)
        local c2 = ToVec3(door.doors[2].coords)
        if c1 and c2 then
            return (c1 + c2) / 2, door.heading or heading or 0.0
        end
    end

    local resolvedModel = (door and door.model) or model
    local resolvedCoords = (door and door.coords and ToVec3(door.coords)) or ToVec3(coords)
    local resolvedHeading = (door and door.heading) or heading or 0.0

    if resolvedModel and resolvedCoords then
        return GetDoorInteractionPoint(resolvedModel, resolvedCoords, resolvedHeading)
    end

    return resolvedCoords, resolvedHeading
end

function GetDoorCenter(door, model, coords, heading)
    return ResolveDoorTargetPlacement(model, coords, heading, door)
end