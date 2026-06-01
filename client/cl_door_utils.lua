---@param coords vector3|table|nil
---@return vector3|nil
local function ToVec3(coords)
    if not coords then return nil end
    return vec3(coords.x, coords.y, coords.z)
end

---@param doorId number
---@return table|nil
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

---@param model number|string
---@param coords vector3|table
---@param heading number
---@return vector3 coords, number heading
function GetDoorInteractionPoint(model, coords, heading)
    coords = ToVec3(coords)
    if not model or not coords then
        return coords, heading or 0.0
    end

    local hash = tonumber(model) or GetHashKey(model)
    if not IsModelInCdimage(hash) then
        return coords, heading or 0.0
    end

    local min, max = GetModelDimensions(hash)
    local centerX = (min.x + max.x) * 0.5
    local centerY = (min.y + max.y) * 0.5
    local centerZ = (min.z + max.z) * 0.5

    local entity = GetClosestObjectOfType(coords.x, coords.y, coords.z, 3.0, hash, false, false, false)
    if entity ~= 0 then
        return GetOffsetFromEntityInWorldCoords(entity, centerX, centerY, centerZ), GetEntityHeading(entity)
    end

    local ok, point, probeHeading = pcall(function()
        lib.requestModel(hash)
        local probe = CreateObjectNoOffset(hash, coords.x, coords.y, coords.z, false, false, false)
        if probe == 0 then
            return coords, heading or 0.0
        end

        SetEntityHeading(probe, heading or 0.0)
        FreezeEntityPosition(probe, true)

        local interactionPoint = GetOffsetFromEntityInWorldCoords(probe, centerX, centerY, centerZ)
        local resolvedHeading = GetEntityHeading(probe)

        DeleteEntity(probe)
        SetModelAsNoLongerNeeded(hash)

        return interactionPoint, resolvedHeading
    end)

    if ok and point then
        return point, probeHeading or heading or 0.0
    end

    return coords, heading or 0.0
end

---@param model number|string|nil
---@param coords vector3|table|nil
---@param heading number|nil
---@param door table|nil ox_doorlock door data
---@return vector3|nil coords, number heading
function ResolveDoorTargetPlacement(model, coords, heading, door)
    if door and door.doors and door.doors[1] and door.doors[2] then
        local c1 = ToVec3(door.doors[1].coords)
        local c2 = ToVec3(door.doors[2].coords)
        if c1 and c2 then
            return (c1 + c2) / 2, door.heading or heading or 0.0
        end
    end

    local resolvedModel = model or (door and door.model)
    local resolvedCoords = ToVec3(coords) or (door and ToVec3(door.coords))
    local resolvedHeading = heading or (door and door.heading) or 0.0

    if resolvedModel and resolvedCoords then
        return GetDoorInteractionPoint(resolvedModel, resolvedCoords, resolvedHeading)
    end

    return resolvedCoords, resolvedHeading
end

---@param door table|nil
---@param model number|string|nil
---@param coords vector3|nil
---@param heading number|nil
---@return vector3|nil coords, number heading
function GetDoorCenter(door, model, coords, heading)
    return ResolveDoorTargetPlacement(model, coords, heading, door)
end
