local glm = require 'glm'
local Freecam = Freecam

local DEBUG_COLOUR = {r = 255, g = 0, b = 0, a = 150}
local DEFAULT_HEIGHT = 5
local CURSOR_COLOUR = {r = 0, g = 255, b = 0, a = 255}
local CURSOR_DELETE_COLOUR = {r = 255, g = 0, b = 0, a = 255}
local MAX_CURSOR_DISTANCE = 10
local POINTS_PADDING = 0.25

local zoneCreator = {
    active = false,
    polygon = {},
    height = DEFAULT_HEIGHT,

    deleteIndex = nil,
    cursor = nil,
    camPosition = nil,
    camRotation = nil,

    highestPoint = nil,
    lowestPoint = nil
}

local polyText = '[C] - Add/Remove point  \n [H] Finish  \n [Scroll] Change height \n [K] Edit Point'

local function RotationToDirection(rotation)
	local adjustedRotation =
	{
		x = (math.pi / 180) * rotation.x,
		y = (math.pi / 180) * rotation.y,
		z = (math.pi / 180) * rotation.z
	}
	local direction =
	{
		x = -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
		y = math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
		z = math.sin(adjustedRotation.x)
	}
	return direction
end

local function rayCastGamePlayCamera(distance, camPos, camRot)
	local cameraRotation = camRot
	local cameraCoord = camPos
	local direction = RotationToDirection(cameraRotation)
	local destination =
	{
		x = cameraCoord.x + direction.x * distance,
		y = cameraCoord.y + direction.y * distance,
		z = cameraCoord.z + direction.z * distance
	}
	local _, hit, endCoords, _, _ = GetShapeTestResult(StartShapeTestRay(cameraCoord.x, cameraCoord.y, cameraCoord.z, destination.x, destination.y, destination.z, -1,  0))
	return hit, endCoords
end

local function tooCloseToExistingPoint(point)
    local points = zoneCreator.polygon
    for i = 1, #points do
        local checkPoint = points[i]
        if glm.distance(point, checkPoint) < POINTS_PADDING then
            return true, i
        end
    end
    return false, nil
end

function zoneCreator.drawCursor()
    zoneCreator.camPosition = Freecam:GetPosition()
    zoneCreator.camRotation = Freecam:GetRotation()
    local hit, coords = rayCastGamePlayCamera(MAX_CURSOR_DISTANCE, zoneCreator.camPosition, zoneCreator.camRotation)

    if hit then
        local color = CURSOR_COLOUR

        local tooClose, existingIndex = tooCloseToExistingPoint(coords)
        if tooClose then
            zoneCreator.cursor = coords
            zoneCreator.deleteIndex = existingIndex
            color = CURSOR_DELETE_COLOUR
        else
            zoneCreator.deleteIndex = nil
        end

        local position = zoneCreator.camPosition

        DrawLine(position.x, position.y, position.z, coords.x, coords.y, coords.z, color.r, color.g, color.b, color.a)
        DrawMarker(28, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0, 0.1, 0.1, 0.1, color.r, color.g, color.b, color.a, false, true, 2, nil, nil, false)
    end

    return hit and coords or nil
end

function zoneCreator.freecamMode(bool)
    if bool then
        Freecam:SetActive(true)
        Freecam:SetFrozen(false)
        Freecam:SetKeyboardSetting('BASE_MOVE_MULTIPLIER', 0.1)
        Freecam:SetKeyboardSetting('FAST_MOVE_MULTIPLIER', 2)
        Freecam:SetKeyboardSetting('SLOW_MOVE_MULTIPLIER', 2)
        Freecam:SetFov(45.0)
    else
        Freecam:SetActive(false)
        Freecam:SetFrozen(false)
        Freecam:SetKeyboardSetting('BASE_MOVE_MULTIPLIER', 5)
        Freecam:SetKeyboardSetting('FAST_MOVE_MULTIPLIER', 10)
        Freecam:SetKeyboardSetting('SLOW_MOVE_MULTIPLIER', 10)
    end
end

function zoneCreator.addPoint(point)
    if zoneCreator.editIndex then
        zoneCreator.polygon[zoneCreator.editIndex] = point
    else
        table.insert(zoneCreator.polygon, point)
    end

    if not zoneCreator.lowestPoint or not zoneCreator.highestPoint then
        zoneCreator.lowestPoint = point
        zoneCreator.highestPoint = point
        return
    end

    zoneCreator.lowestPoint = point.z < zoneCreator.lowestPoint.z and point or zoneCreator.lowestPoint
    zoneCreator.highestPoint = point.z > zoneCreator.highestPoint.z and point or zoneCreator.highestPoint
end

function zoneCreator.removePoint()
    if not zoneCreator.deleteIndex then return end

    local deletedPoint = zoneCreator.polygon[zoneCreator.deleteIndex]
    
    local function updateExtremePoint(comparator, currentExtreme)
        if not currentExtreme or deletedPoint.z == currentExtreme.z then
            local newExtreme = nil
            for i = 1, #zoneCreator.polygon do
                if i ~= zoneCreator.deleteIndex then
                    if not newExtreme or comparator(zoneCreator.polygon[i].z, newExtreme.z) then
                        newExtreme = zoneCreator.polygon[i]
                    end
                end
            end
            return newExtreme
        end
        return currentExtreme
    end

    zoneCreator.highestPoint = updateExtremePoint(function(a, b) return a > b end, zoneCreator.highestPoint)
    zoneCreator.lowestPoint = updateExtremePoint(function(a, b) return a < b end, zoneCreator.lowestPoint)

    table.remove(zoneCreator.polygon, zoneCreator.deleteIndex)

    if #zoneCreator.polygon == 0 then
        zoneCreator.highestPoint = nil
        zoneCreator.lowestPoint = nil
    end
end

function zoneCreator.editPoint()
    if zoneCreator.editIndex and zoneCreator.cursor then
        zoneCreator.addPoint(zoneCreator.cursor)
        zoneCreator.editIndex = nil
        lib.hideTextUI()
        lib.showTextUI(polyText)
        return
    end

    if zoneCreator.deleteIndex then
        zoneCreator.editIndex = zoneCreator.deleteIndex

        lib.hideTextUI()
        lib.showTextUI('[K] - Set Point \n [N] - Cancel Set')
    else
        Bridge.Client.Notify('Need to be close to a point', 'error')
    end
end

local function render()
    local points = zoneCreator.polygon
    local DrawLine, IsDisabledControlJustPressed, vec3 = DrawLine, IsDisabledControlJustPressed, vec3

    while zoneCreator.active do
        Wait(0)
        DisableControlAction(0, 14, true)
        DisableControlAction(0, 15, true)
        DisableControlAction(0, 104, true)
        DisableControlAction(0, 306, true)

        zoneCreator.cursor = zoneCreator.drawCursor()
        local height =  #points > 0 and points[1].z + zoneCreator.height or 0

        if zoneCreator.highestPoint and #points > 0 then
            height = zoneCreator.highestPoint.z + zoneCreator.height
        end

        for i = 1, #points do
            local point = points[i]
            local thickness = vec3(0, 0, zoneCreator.height / 2)
            local a = point + thickness
            local b = point
            local c = (points[i + 1] or points[1]) + thickness
            local d = (points[i + 1] or points[1])
            local isYellow = zoneCreator.editIndex == i
            DrawLine(a.x, a.y, height, b.x, b.y, b.z, DEBUG_COLOUR.r,  isYellow and 255 or DEBUG_COLOUR.g,  DEBUG_COLOUR.b,  255)
            DrawLine(a.x, a.y, height, c.x, c.y, height, DEBUG_COLOUR.r,  isYellow and 255 or DEBUG_COLOUR.g,  DEBUG_COLOUR.b,  255)
            DrawLine(b.x, b.y, b.z, d.x, d.y, d.z, DEBUG_COLOUR.r,  isYellow and 255 or DEBUG_COLOUR.g,  DEBUG_COLOUR.b,  255)
            DrawPoly(a.x, a.y, height, b.x, b.y, b.z, c.x, c.y, height, DEBUG_COLOUR.r,  DEBUG_COLOUR.g,  DEBUG_COLOUR.b,  DEBUG_COLOUR.a)
            DrawPoly(c.x, c.y, height, b.x, b.y, b.z, a.x, a.y, height, DEBUG_COLOUR.r,  DEBUG_COLOUR.g,  DEBUG_COLOUR.b,  DEBUG_COLOUR.a)
            DrawPoly(b.x, b.y, b.z, c.x, c.y, height, d.x, d.y, d.z, DEBUG_COLOUR.r,  DEBUG_COLOUR.g,  DEBUG_COLOUR.b,  DEBUG_COLOUR.a)
            DrawPoly(d.x, d.y, d.z, c.x, c.y, height, b.x, b.y, b.z, DEBUG_COLOUR.r,  DEBUG_COLOUR.g,  DEBUG_COLOUR.b,  DEBUG_COLOUR.a)
        end

        if IsDisabledControlJustPressed(0, 14) then 
            zoneCreator.height = math.max(0.5, zoneCreator.height - 0.5)
        end

        if IsDisabledControlJustPressed(0, 15) then 
            zoneCreator.height = zoneCreator.height + 0.5
        end

        if IsDisabledControlJustPressed(0, 104) then 
            zoneCreator.active = false
            zoneCreator.freecamMode(false)
            return {points = points, thickness = zoneCreator.height}
        end

        if IsDisabledControlJustPressed(0, 306) and zoneCreator.editIndex then 
            zoneCreator.editIndex = nil
            lib.hideTextUI()
            lib.showTextUI(polyText)
        end
    end
end

RegisterCommand('+usePoint', function()
    debugPrint('info', 'Command: +usePoint triggered')
    if not zoneCreator.active then return end
    if not zoneCreator.cursor then return end

    if zoneCreator.deleteIndex then
        zoneCreator.removePoint()
    else
        zoneCreator.addPoint(zoneCreator.cursor)
    end
end, false)

RegisterCommand('+editPoint', function()
    debugPrint('info', 'Command: +editPoint triggered')
    if not zoneCreator.active then return end
    if not zoneCreator.cursor then return end
    zoneCreator.editPoint()
end, false)

RegisterKeyMapping('+editPoint', 'Edit Point', 'keyboard', 'k')
RegisterKeyMapping('+usePoint', 'Add/Remove Point', 'keyboard', 'c')

local function polyCreator()
    debugPrint('info', 'PolyCreator export called')
    zoneCreator.freecamMode(false)
    Wait(100)

    zoneCreator.active = true
    zoneCreator.polygon = {}
    zoneCreator.height = DEFAULT_HEIGHT
    zoneCreator.freecamMode(true)

    Wait(500) 
    lib.showTextUI(polyText)
    
    local result = render()
    lib.hideTextUI()
    
    if result and #result.points > 2 then
        debugPrint('info', 'PolyCreator finished', {pointsCount = #result.points})
        return result
    end
    debugPrint('info', 'PolyCreator cancelled or too few points')
    return nil
end

local function mloDoor()
    debugPrint('info', 'DoorPicker export called')
    local selectedDoors = {}
    local lastEntity = 0

    Wait(500)
    lib.showTextUI('[E] - Pick Single | [G] - Pick Double (1/2) | [H] - Cancel')

    while true do
        Wait(0)
        DisableControlAction(0, 38, true) -- E
        DisableControlAction(0, 47, true) -- G
        DisableControlAction(0, 74, true) -- H

        local cameraRotation = GetGameplayCamRot(2)
        local cameraCoord = GetGameplayCamCoord()
        local direction = RotationToDirection(cameraRotation)
        local destination = {
            x = cameraCoord.x + direction.x * 15.0,
            y = cameraCoord.y + direction.y * 15.0,
            z = cameraCoord.z + direction.z * 15.0
        }

        local rayHandle = StartShapeTestRay(
            cameraCoord.x, cameraCoord.y, cameraCoord.z,
            destination.x, destination.y, destination.z,
            1 | 16,
            cache.ped,
            4
        )
        local _, hit, coords, _, entity = GetShapeTestResult(rayHandle)
        local isHit = (hit == 1 or hit == true)
        local changedEntity = lastEntity ~= entity
        local door1Entity = selectedDoors[1] and selectedDoors[1]._entity or nil

        if lastEntity ~= 0 and changedEntity and lastEntity ~= door1Entity then
            SetEntityDrawOutline(lastEntity, false)
        end
        lastEntity = entity

        if isHit and entity and entity > 0 and GetEntityType(entity) == 3 then
            DrawMarker(28, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.2, 0.2, 0.2, 255, 42, 24, 100, false, false, 0, true, false, false, false)
            if changedEntity then SetEntityDrawOutline(entity, true) end

            local function getDoorData(ent)
                local existingId = exports.ox_doorlock:getDoorIdFromEntity(ent)
                if existingId then
                    return { _existingId = existingId, _entity = ent }
                end
                local c = GetEntityCoords(ent)
                return {
                    isNew = true,
                    model = GetEntityModel(ent),
                    coords = { x = c.x, y = c.y, z = c.z },
                    heading = GetEntityHeading(ent),
                    _entity = ent
                }
            end

            if IsDisabledControlJustPressed(0, 38) and #selectedDoors == 0 then
                if lastEntity and lastEntity > 0 then SetEntityDrawOutline(lastEntity, false) end
                lib.hideTextUI()
                local data = getDoorData(entity)
                if data._existingId then return data._existingId end
                data._entity = nil
                return data
            end

            if IsDisabledControlJustPressed(0, 47) then
                local alreadyPicked = door1Entity == entity
                if not alreadyPicked then
                    local data = getDoorData(entity)
                    table.insert(selectedDoors, data)

                    if #selectedDoors == 1 then
                        lib.hideTextUI()
                        lib.showTextUI('[G] - Pick 2nd Door (2/2) | [H] - Cancel')
                    elseif #selectedDoors == 2 then
                        if lastEntity and lastEntity > 0 then SetEntityDrawOutline(lastEntity, false) end
                        if door1Entity and door1Entity > 0 then SetEntityDrawOutline(door1Entity, false) end
                        lib.hideTextUI()

                        local function resolveDoor(d)
                            if d._existingId then return d._existingId end
                            d._entity = nil
                            return d
                        end

                        return {
                            isDouble = true,
                            doors = { resolveDoor(selectedDoors[1]), resolveDoor(selectedDoors[2]) }
                        }
                    end
                end
            end
        end

        if IsDisabledControlJustPressed(0, 74) then
            if lastEntity and lastEntity > 0 then SetEntityDrawOutline(lastEntity, false) end
            if door1Entity and door1Entity > 0 then SetEntityDrawOutline(door1Entity, false) end
            break
        end
    end
    lib.hideTextUI()
    return nil
end

exports('PolyCreator', polyCreator)
exports('DoorPicker', mloDoor)