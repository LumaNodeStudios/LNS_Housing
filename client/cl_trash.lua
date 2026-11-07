local Settings = lib.load('shared.settings')
SpawnedTrashProps = SpawnedTrashProps or {}
SpawnedDroppedBags = SpawnedDroppedBags or {}
CurrentPropertyTrash = nil
IsCarryingTrash = false
CarriedBagEntity = nil
CurrentCarriedTrash = nil
local isCleaningTrash = false
local isThrowingTrash = false
local FliesParticleHandle = nil
local isRefreshingTrash = false
local CachedTrashCoords = {}

local TrashItemConfig = Settings.Trash and Settings.Trash.Item
local IsTrashItem = TrashItemConfig and TrashItemConfig.Enabled == true
local TrashItemName = TrashItemConfig and (TrashItemConfig.Name or TrashItemConfig.ItemName) or 'trashbag'

local function isPointInPoly2D(px, py, corners)
    if not corners or #corners < 3 then return false end
    local inside = false
    local j = #corners
    for i = 1, #corners do
        local c1 = corners[i]
        local c2 = corners[j]
        local x1, y1 = c1.x, c1.y
        local x2, y2 = c2.x, c2.y
        if ((y1 > py) ~= (y2 > py)) and (px < (x2 - x1) * (py - y1) / (y2 - y1) + x1) then
            inside = not inside
        end
        j = i
    end
    return inside
end

local function distToSegmentSquared(px, py, x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    local l2 = dx * dx + dy * dy
    if l2 == 0 then
        local sx = px - x1
        local sy = py - y1
        return sx * sx + sy * sy
    end
    local t = ((px - x1) * dx + (py - y1) * dy) / l2
    t = math.max(0.0, math.min(1.0, t))
    local projX = x1 + t * dx
    local projY = y1 + t * dy
    local ex = px - projX
    local ey = py - projY
    return ex * ex + ey * ey
end

local function getDistanceToPolyBoundary(px, py, corners)
    if not corners or #corners < 3 then return 0.0 end
    local minD2 = 99999999.0
    local j = #corners
    for i = 1, #corners do
        local c1 = corners[i]
        local c2 = corners[j]
        local d2 = distToSegmentSquared(px, py, c1.x, c1.y, c2.x, c2.y)
        if d2 < minD2 then minD2 = d2 end
        j = i
    end
    return math.sqrt(minD2)
end

local function findPolyPoleOfInaccessibility(corners, minMargin, doorCoords, minDoorDist)
    if not corners or #corners < 3 then return nil, 0.0 end
    local minX, maxX = corners[1].x, corners[1].x
    local minY, maxY = corners[1].y, corners[1].y
    for i = 2, #corners do
        local c = corners[i]
        if c.x < minX then minX = c.x end
        if c.x > maxX then maxX = c.x end
        if c.y < minY then minY = c.y end
        if c.y > maxY then maxY = c.y end
    end

    local bestPoint = nil
    local maxScore = -999999.0
    local bestClearance = 0.0
    local gridSteps = 12
    local stepX = (maxX - minX) / (gridSteps + 1)
    local stepY = (maxY - minY) / (gridSteps + 1)

    for gx = 1, gridSteps do
        for gy = 1, gridSteps do
            local px = minX + gx * stepX
            local py = minY + gy * stepY
            if isPointInPoly2D(px, py, corners) then
                local clearance = getDistanceToPolyBoundary(px, py, corners)
                local score = clearance
                if doorCoords and minDoorDist then
                    local doorDist = #(vec2(px, py) - vec2(doorCoords.x, doorCoords.y))
                    if doorDist < minDoorDist then
                        score = score - (minDoorDist - doorDist) * 3.0
                    else
                        score = score + math.min(doorDist, 5.0) * 0.2
                    end
                end
                if score > maxScore then
                    maxScore = score
                    bestClearance = clearance
                    bestPoint = vec2(px, py)
                end
            end
        end
    end

    return bestPoint, bestClearance
end

local function isLineOfSightClear(fromCoords, toCoords)
    if not fromCoords or not toCoords then return true end
    local startZ = fromCoords.z + 0.45
    local endZ = toCoords.z + 0.45
    local ray = StartExpensiveSynchronousShapeTestLosProbe(
        fromCoords.x, fromCoords.y, startZ,
        toCoords.x, toCoords.y, endZ,
        17,
        cache.ped,
        7
    )
    local _, hit, hitCoords, _, _ = GetShapeTestResult(ray)
    if hit == 1 or hit == true then
        local distToTarget = #(hitCoords - vec3(toCoords.x, toCoords.y, endZ))
        if distToTarget > 0.45 then
            return false
        end
    end
    return true
end

local function getWallDistanceInDir(origin, dir2D, maxDist)
    maxDist = maxDist or 6.0
    local startZ = origin.z + 0.45
    local targetX = origin.x + dir2D.x * maxDist
    local targetY = origin.y + dir2D.y * maxDist
    local ray = StartExpensiveSynchronousShapeTestLosProbe(
        origin.x, origin.y, startZ,
        targetX, targetY, startZ,
        17,
        cache.ped,
        7
    )
    local _, hit, hitCoords, _, entityHit = GetShapeTestResult(ray)
    if hit == 1 or hit == true then
        local isIgnored = false
        if entityHit and entityHit ~= 0 then
            if entityHit == cache.ped then
                isIgnored = true
            elseif CurrentPropertyTrash and SpawnedTrashProps[CurrentPropertyTrash.propertyId] then
                for _, propObj in pairs(SpawnedTrashProps[CurrentPropertyTrash.propertyId]) do
                    if propObj == entityHit then
                        isIgnored = true
                        break
                    end
                end
            end
        end

        if not isIgnored then
            local dist2D = #(vec2(hitCoords.x, hitCoords.y) - vec2(origin.x, origin.y))
            return dist2D, hitCoords
        end
    end
    return maxDist, vec3(targetX, targetY, startZ)
end

local function isPointClearOfWalls(pos, minClearance)
    if not minClearance or minClearance <= 0.1 then return true end
    local testZ = pos.z + 0.40
    local stepAng = (2 * math.pi) / 12
    for a = 1, 12 do
        local ang = (a - 1) * stepAng
        local targetX = pos.x + math.cos(ang) * minClearance
        local targetY = pos.y + math.sin(ang) * minClearance
        local ray = StartExpensiveSynchronousShapeTestLosProbe(
            pos.x, pos.y, testZ,
            targetX, targetY, testZ,
            17,
            cache.ped,
            7
        )
        local _, hit, hitCoords, _, entityHit = GetShapeTestResult(ray)
        if hit == 1 or hit == true then
            local isIgnored = false
            if entityHit and entityHit ~= 0 then
                if entityHit == cache.ped then
                    isIgnored = true
                elseif CurrentPropertyTrash and SpawnedTrashProps[CurrentPropertyTrash.propertyId] then
                    for _, propObj in pairs(SpawnedTrashProps[CurrentPropertyTrash.propertyId]) do
                        if propObj == entityHit then
                            isIgnored = true
                            break
                        end
                    end
                end
            end

            if not isIgnored then
                local dist = #(vec2(hitCoords.x, hitCoords.y) - vec2(pos.x, pos.y))
                if dist < minClearance then
                    return false, dist
                end
            end
        end
    end
    return true, minClearance
end

local function isDoorTooClose(pos, doorCoords, minDoorDist)
    if not doorCoords or not minDoorDist or minDoorDist <= 0 then return false end
    local dist2D = #(vec2(pos.x, pos.y) - vec2(doorCoords.x, doorCoords.y))
    return dist2D < minDoorDist
end

local function isInteriorValid(pos, expectedInteriorId)
    if not expectedInteriorId or expectedInteriorId == 0 then return true end
    local intAt = GetInteriorAtCoords(pos.x, pos.y, (pos.z or 0.0) + 1.0)
    if intAt == 0 then
        return true
    end
    return intAt == expectedInteriorId
end

local function GetFloorZAtCoord(x, y, approxZ, ignoreEntity)
    local testZ = approxZ or (GetEntityCoords(cache.ped).z)
    local startZ = testZ + 0.6
    local minZ = testZ - 4.5

    for _ = 1, 5 do
        local ray = StartShapeTestRay(x, y, startZ, x, y, minZ, -1, ignoreEntity or cache.ped, 7)
        local retval, hit, endCoordsResult, surfaceNormal, entityHit = GetShapeTestResult(ray)

        if hit ~= 0 and hit ~= false then
            if surfaceNormal and surfaceNormal.z > 0.25 then
                return endCoordsResult.z
            elseif endCoordsResult and endCoordsResult.z then
                startZ = endCoordsResult.z - 0.05
                if startZ <= minZ then break end
            else
                break
            end
        else
            break
        end
    end

    local success, groundZ = GetGroundZFor_3dCoord(x, y, testZ, false)
    if success and math.abs(groundZ - testZ) < 3.5 then
        return groundZ
    end

    return nil
end

local function getRoomOrPropertyData(propertyId, isApartment)
    if isApartment then
        for _, r in ipairs(Settings.Rooms or {}) do
            if r.id == propertyId or tostring(r.id) == tostring(propertyId) or tonumber(r.id) == tonumber(propertyId) then
                return {
                    id = propertyId,
                    corners = r.corners,
                    zOffset = r.zOffset,
                    thickness = r.thickness,
                    doorCoords = r.doorCoords and vec3(r.doorCoords.x, r.doorCoords.y, r.doorCoords.z),
                    spawn = r.spawn and vec4(r.spawn.x, r.spawn.y, r.spawn.z, r.spawn.w or 0.0),
                    interior_id = r.interior_id or r.interiorId,
                    interior_coords = (r.interior_coords and vec3(r.interior_coords.x, r.interior_coords.y, r.interior_coords.z))
                        or (r.interiorCoords and vec3(r.interiorCoords.x, r.interiorCoords.y, r.interiorCoords.z)),
                    interior_center = (r.interior_center and vec3(r.interior_center.x, r.interior_center.y, r.interior_center.z))
                        or (r.interiorCenter and vec3(r.interiorCenter.x, r.interiorCenter.y, r.interiorCenter.z)),
                    isApartment = true
                }
            end
        end
        if Properties and (Properties[propertyId] or (tonumber(propertyId) and Properties[tonumber(propertyId)])) then
            local p = Properties[propertyId] or Properties[tonumber(propertyId)]
            return {
                id = propertyId,
                corners = (p.zone_data and p.zone_data.points) or p.corners or (p.metadata and p.metadata.corners),
                zOffset = p.zOffset,
                thickness = p.thickness,
                doorCoords = p.metadata and p.metadata.entrance and vec3(p.metadata.entrance.x, p.metadata.entrance.y, p.metadata.entrance.z),
                spawn = p.metadata and p.metadata.spawn and vec4(p.metadata.spawn.x, p.metadata.spawn.y, p.metadata.spawn.z, p.metadata.spawn.w or 0.0),
                interior_id = p.metadata and p.metadata.interior_id,
                interior_coords = p.metadata and p.metadata.interior_coords and vec3(p.metadata.interior_coords.x, p.metadata.interior_coords.y, p.metadata.interior_coords.z),
                interior_center = p.metadata and p.metadata.interior_center and vec3(p.metadata.interior_center.x, p.metadata.interior_center.y, p.metadata.interior_center.z),
                isApartment = true
            }
        end
        return nil
    end

    local p = Properties and (Properties[propertyId] or (tonumber(propertyId) and Properties[tonumber(propertyId)]))
    return p
end

function GetTrashCoordinates(propertyId, isApartment, maxPiles)
    maxPiles = maxPiles or (Settings.Trash and Settings.Trash.MaxTrash) or 5
    local coords = {}
    local minDoorDist = (Settings.Trash and Settings.Trash.MinDoorDistance) or 2.0
    local minWallMargin = (Settings.Trash and Settings.Trash.MinWallMargin) or 1.0
    local minSpread = (Settings.Trash and Settings.Trash.MinPileSpread) or 1.6

    if isApartment then
        local room = getRoomOrPropertyData(propertyId, true)
        local doorCoords = room and room.doorCoords and vec3(room.doorCoords.x, room.doorCoords.y, room.doorCoords.z)
        local spawnCoords = room and room.spawn and vec4(room.spawn.x, room.spawn.y, room.spawn.z, room.spawn.w or 0.0)
        local interiorCoords = room and room.interior_coords and vec3(room.interior_coords.x, room.interior_coords.y, room.interior_coords.z)
        local interiorCenter = room and room.interior_center and vec3(room.interior_center.x, room.interior_center.y, room.interior_center.z)
        local expectedInteriorId = room and tonumber(room.interior_id or room.interiorId)
        if (not expectedInteriorId or expectedInteriorId == 0) and spawnCoords then
            expectedInteriorId = GetInteriorAtCoords(spawnCoords.x, spawnCoords.y, spawnCoords.z + 1.0)
        end
        if (not expectedInteriorId or expectedInteriorId == 0) then
            expectedInteriorId = GetInteriorFromEntity(cache.ped)
        end

        local pedCoords = GetEntityCoords(cache.ped)
        local approxAnchor = (spawnCoords and vec3(spawnCoords.x, spawnCoords.y, spawnCoords.z))
            or (interiorCoords and vec3(interiorCoords.x, interiorCoords.y, interiorCoords.z))
            or (doorCoords and vec3(doorCoords.x, doorCoords.y, doorCoords.z))
            or pedCoords

        local detectedFloor = GetFloorZAtCoord(approxAnchor.x, approxAnchor.y, approxAnchor.z)
        local floorZ = detectedFloor
            or (spawnCoords and (spawnCoords.z - 0.98))
            or (doorCoords and (doorCoords.z - 0.98))
            or (pedCoords.z - 0.98)
            or ((room and room.corners and #room.corners >= 1) and (room.corners[1].z + (room.zOffset or 0.0) - 0.98))
            or approxAnchor.z

        if room and room.corners and #room.corners >= 3 then
            local corners = room.corners
            local bestPole, clearance = findPolyPoleOfInaccessibility(corners, minWallMargin, doorCoords, minDoorDist)
            local effectiveMargin = minWallMargin
            if clearance > 0 and clearance < minWallMargin then
                effectiveMargin = math.max(0.60, clearance * 0.85)
            end

            local safeCenter2D = bestPole
            if not safeCenter2D then
                if spawnCoords and isPointInPoly2D(spawnCoords.x, spawnCoords.y, corners) then
                    safeCenter2D = vec2(spawnCoords.x, spawnCoords.y)
                else
                    local cx, cy = 0.0, 0.0
                    for _, c in ipairs(corners) do cx = cx + c.x; cy = cy + c.y end
                    safeCenter2D = vec2(cx / #corners, cy / #corners)
                end
            end
            local safeCenter = vec3(safeCenter2D.x, safeCenter2D.y, floorZ)
            local numPropId = tonumber(propertyId) or 1

            local sectors = {}
            for s = 1, maxPiles do
                local ang = ((s - 1) * (2 * math.pi / maxPiles)) + ((numPropId * 0.43) % (2 * math.pi))
                sectors[s] = ang
            end

            for i = 1, maxPiles do
                local acceptedPos = nil
                local primaryAngle = sectors[i]
                local angleOffsets = { 0.0, 0.15, -0.15, 0.3, -0.3, 0.5, -0.5, 0.7, -0.7 }
                local spreadLevels = { minSpread, 1.3, 1.0, 0.85 }

                for _, testSpread in ipairs(spreadLevels) do
                    for _, aOff in ipairs(angleOffsets) do
                        local ang = primaryAngle + aOff
                        local dir = vec2(math.cos(ang), math.sin(ang))

                        local maxR = 0.0
                        for r = 0.5, 7.0, 0.15 do
                            local tx = safeCenter.x + dir.x * r
                            local ty = safeCenter.y + dir.y * r
                            if isPointInPoly2D(tx, ty, corners) and getDistanceToPolyBoundary(tx, ty, corners) >= effectiveMargin then
                                if not isDoorTooClose(vec3(tx, ty, floorZ), doorCoords, minDoorDist) then
                                    maxR = r
                                end
                            else
                                break
                            end
                        end

                        if maxR >= 0.5 then
                            local testDistances = {
                                maxR,
                                maxR * 0.85,
                                maxR * 0.7,
                                math.max(0.5, maxR * 0.5)
                            }

                            for _, r in ipairs(testDistances) do
                                local testPos = vec3(safeCenter.x + dir.x * r, safeCenter.y + dir.y * r, floorZ)
                                local valid = isPointInPoly2D(testPos.x, testPos.y, corners)
                                    and (getDistanceToPolyBoundary(testPos.x, testPos.y, corners) >= effectiveMargin)
                                    and not isDoorTooClose(testPos, doorCoords, minDoorDist)
                                    and isInteriorValid(testPos, expectedInteriorId)
                                    and isLineOfSightClear(safeCenter, testPos)
                                    and isPointClearOfWalls(testPos, math.min(effectiveMargin * 0.85, 0.95))

                                if valid then
                                    local tooClose = false
                                    for j = 1, #coords do
                                        if coords[j] and #(vec2(testPos.x, testPos.y) - vec2(coords[j].x, coords[j].y)) < testSpread then
                                            tooClose = true
                                            break
                                        end
                                    end
                                    if not tooClose then
                                        acceptedPos = testPos
                                        break
                                    end
                                end
                            end
                        end
                        if acceptedPos then break end
                    end
                    if acceptedPos then break end
                end

                if acceptedPos then
                    local pileFloor = GetFloorZAtCoord(acceptedPos.x, acceptedPos.y, floorZ) or floorZ
                    coords[#coords + 1] = vec3(acceptedPos.x, acceptedPos.y, pileFloor + 0.015)
                end
            end

            if #coords < maxPiles then
                local basePos = safeCenter or (doorCoords and (doorCoords + vec3(1.0, 1.0, 0.0))) or GetEntityCoords(cache.ped)
                for i = #coords + 1, maxPiles do
                    local a = (i * 0.785)
                    local r = 0.8 + ((i % 4) * 0.4)
                    local px = basePos.x + math.cos(a) * r
                    local py = basePos.y + math.sin(a) * r
                    local pileFloor = GetFloorZAtCoord(px, py, floorZ) or floorZ
                    coords[#coords + 1] = vec3(px, py, pileFloor + 0.015)
                end
            end

            return coords
        else
            local dirIn = nil
            if spawnCoords and doorCoords then
                local toSpawn = vec2(spawnCoords.x - doorCoords.x, spawnCoords.y - doorCoords.y)
                local distDoor = math.sqrt(toSpawn.x^2 + toSpawn.y^2)
                if distDoor > 0.4 then
                    dirIn = toSpawn / distDoor
                end
            end

            if not dirIn and spawnCoords and spawnCoords.w then
                local rad = math.rad(spawnCoords.w)
                dirIn = vec2(-math.sin(rad), math.cos(rad))
            end

            if not dirIn then
                dirIn = vec2(0.0, 1.0)
            end

            local safeCenter = nil
            if spawnCoords then
                safeCenter = vec3(spawnCoords.x, spawnCoords.y, floorZ)
            elseif interiorCoords then
                safeCenter = vec3(interiorCoords.x, interiorCoords.y, floorZ)
            elseif doorCoords then
                safeCenter = vec3(doorCoords.x + dirIn.x * 2.5, doorCoords.y + dirIn.y * 2.5, floorZ)
            else
                local pedCoords = GetEntityCoords(cache.ped)
                safeCenter = vec3(pedCoords.x, pedCoords.y, floorZ)
            end

            if doorCoords then
                local distFromDoor = #(vec2(safeCenter.x, safeCenter.y) - vec2(doorCoords.x, doorCoords.y))
                local targetMinDist = minDoorDist + 0.6
                if distFromDoor < targetMinDist then
                    local pushDist = targetMinDist - distFromDoor
                    safeCenter = vec3(safeCenter.x + dirIn.x * pushDist, safeCenter.y + dirIn.y * pushDist, floorZ)
                end
            end

            if interiorCenter and #(interiorCenter - safeCenter) < 7.0 then
                if not isDoorTooClose(interiorCenter, doorCoords, minDoorDist + 0.5) then
                    safeCenter = (safeCenter * 0.7) + (interiorCenter * 0.3)
                end
            end

            local baseAngle0 = math.atan2(dirIn.y, dirIn.x)

            local sectors = {}
            for s = 1, maxPiles do
                local frac = (maxPiles > 1) and ((s - 1) / (maxPiles - 1)) or 0.5
                local ang = baseAngle0 + (-1.4 + frac * 2.8)
                sectors[s] = ang
            end

            for i = 1, maxPiles do
                local acceptedPos = nil
                local targetSector = sectors[i]
                local angleOffsets = { 0.0, 0.15, -0.15, 0.3, -0.3, 0.5, -0.5 }
                local spreadLevels = { minSpread, 1.3, 1.0, 0.85 }

                for _, testSpread in ipairs(spreadLevels) do
                    for _, aOff in ipairs(angleOffsets) do
                        local ang = targetSector + aOff
                        local dir = vec2(math.cos(ang), math.sin(ang))
                        local wallDist = getWallDistanceInDir(safeCenter, dir, 6.0)
                        local maxR = math.max(0.4, wallDist - minWallMargin)
                        local depthFractions = { 1.0, 0.8, 0.6, 0.4 }

                        for _, df in ipairs(depthFractions) do
                            local r = math.max(0.4, maxR * df)
                            local testPos = vec3(safeCenter.x + dir.x * r, safeCenter.y + dir.y * r, floorZ)

                            local valid = not isDoorTooClose(testPos, doorCoords, minDoorDist)
                                and isInteriorValid(testPos, expectedInteriorId)
                                and isLineOfSightClear(safeCenter, testPos)
                                and isPointClearOfWalls(testPos, math.min(minWallMargin * 0.85, 0.95))

                            if valid and doorCoords then
                                local toCandidate = vec2(testPos.x - doorCoords.x, testPos.y - doorCoords.y)
                                local dot = toCandidate.x * dirIn.x + toCandidate.y * dirIn.y
                                if dot < (minDoorDist * 0.75) then
                                    valid = false
                                end
                            end

                            if valid then
                                local tooClose = false
                                for j = 1, #coords do
                                    if coords[j] and #(vec2(testPos.x, testPos.y) - vec2(coords[j].x, coords[j].y)) < testSpread then
                                        tooClose = true
                                        break
                                    end
                                end
                                if not tooClose then
                                    acceptedPos = testPos
                                    break
                                end
                            end
                        end

                        if acceptedPos then break end
                    end
                    if acceptedPos then break end
                end

                if not acceptedPos then
                    for r = 0.5, 2.5, 0.35 do
                        for a = -1.2, 1.2, 0.3 do
                            local ang = baseAngle0 + a
                            local testPos = vec3(safeCenter.x + math.cos(ang) * r, safeCenter.y + math.sin(ang) * r, floorZ)
                            if not isDoorTooClose(testPos, doorCoords, minDoorDist)
                                and isInteriorValid(testPos, expectedInteriorId)
                                and isPointClearOfWalls(testPos, math.min(minWallMargin * 0.75, 0.85)) then
                                local tooClose = false
                                for j = 1, #coords do
                                    if coords[j] and #(vec2(testPos.x, testPos.y) - vec2(coords[j].x, coords[j].y)) < 0.85 then
                                        tooClose = true
                                        break
                                    end
                                end
                                if not tooClose then
                                    acceptedPos = testPos
                                    break
                                end
                            end
                        end
                        if acceptedPos then break end
                    end
                end

                if acceptedPos then
                    local pileFloor = GetFloorZAtCoord(acceptedPos.x, acceptedPos.y, floorZ) or floorZ
                    coords[#coords + 1] = vec3(acceptedPos.x, acceptedPos.y, pileFloor + 0.015)
                end
            end

            if #coords < maxPiles then
                local basePos = safeCenter or (doorCoords and (doorCoords + dirIn * 2.0)) or GetEntityCoords(cache.ped)
                for i = #coords + 1, maxPiles do
                    local a = (i * 0.785)
                    local r = 0.8 + ((i % 4) * 0.4)
                    local px = basePos.x + math.cos(a) * r
                    local py = basePos.y + math.sin(a) * r
                    local pileFloor = GetFloorZAtCoord(px, py, floorZ) or floorZ
                    coords[#coords + 1] = vec3(px, py, pileFloor + 0.015)
                end
            end

            return coords
        end
    end

    local p = getRoomOrPropertyData(propertyId, false)
    if not p then return coords end

    if p.zone_data and p.zone_data.points and #p.zone_data.points >= 3 then
        local corners = p.zone_data.points
        local doorCoords = GetEntranceCoords and GetEntranceCoords(p)
        local refPos = (doorCoords and vec3(doorCoords.x, doorCoords.y, doorCoords.z)) or vec3(corners[1].x, corners[1].y, corners[1].z)
        local detectedFloor = GetFloorZAtCoord(refPos.x, refPos.y, refPos.z)
        local floorZ = detectedFloor or (corners[1].z - 0.98) or (GetEntityCoords(cache.ped).z - 0.98)
        local bestPole, clearance = findPolyPoleOfInaccessibility(corners, minWallMargin, doorCoords, minDoorDist)
        local effectiveMargin = minWallMargin
        if clearance > 0 and clearance < minWallMargin then
            effectiveMargin = math.max(0.60, clearance * 0.85)
        end

        local safeCenter2D = bestPole
        if not safeCenter2D then
            local cx, cy = 0.0, 0.0
            for _, c in ipairs(corners) do cx = cx + c.x; cy = cy + c.y end
            safeCenter2D = vec2(cx / #corners, cy / #corners)
        end
        local safeCenter = vec3(safeCenter2D.x, safeCenter2D.y, floorZ)
        local numPropId = tonumber(propertyId) or 1

        local sectors = {}
        for s = 1, maxPiles do
            sectors[s] = ((s - 1) * (2 * math.pi / maxPiles)) + ((numPropId * 0.37) % (2 * math.pi))
        end

        for i = 1, maxPiles do
            local acceptedPos = nil
            local primaryAngle = sectors[i]
            local angleOffsets = { 0.0, 0.2, -0.2, 0.4, -0.4, 0.6, -0.6 }
            local spreadLevels = { minSpread, 1.3, 1.0, 0.85 }

            for _, testSpread in ipairs(spreadLevels) do
                for _, aOff in ipairs(angleOffsets) do
                    local ang = primaryAngle + aOff
                    local dir = vec2(math.cos(ang), math.sin(ang))

                    local maxR = 0.0
                    for r = 0.5, 7.0, 0.2 do
                        local tx = safeCenter.x + dir.x * r
                        local ty = safeCenter.y + dir.y * r
                        if isPointInPoly2D(tx, ty, corners) and getDistanceToPolyBoundary(tx, ty, corners) >= effectiveMargin then
                            if not isDoorTooClose(vec3(tx, ty, floorZ), doorCoords, minDoorDist) then
                                maxR = r
                            end
                        else
                            break
                        end
                    end

                    if maxR >= 0.5 then
                        local testDistances = {
                            maxR,
                            maxR * 0.85,
                            maxR * 0.7,
                            math.max(0.5, maxR * 0.5)
                        }

                        for _, r in ipairs(testDistances) do
                            local testPos = vec3(safeCenter.x + dir.x * r, safeCenter.y + dir.y * r, floorZ)
                            local valid = isPointInPoly2D(testPos.x, testPos.y, corners)
                                and (getDistanceToPolyBoundary(testPos.x, testPos.y, corners) >= effectiveMargin)
                                and not isDoorTooClose(testPos, doorCoords, minDoorDist)
                                and isLineOfSightClear(safeCenter, testPos)
                                and isPointClearOfWalls(testPos, math.min(effectiveMargin * 0.85, 0.95))

                            if valid then
                                local tooClose = false
                                for j = 1, #coords do
                                    if coords[j] and #(vec2(testPos.x, testPos.y) - vec2(coords[j].x, coords[j].y)) < testSpread then
                                        tooClose = true
                                        break
                                    end
                                end
                                if not tooClose then
                                    acceptedPos = testPos
                                    break
                                end
                            end
                        end
                    end
                    if acceptedPos then break end
                end
                if acceptedPos then break end
            end

            if acceptedPos then
                local pileFloor = GetFloorZAtCoord(acceptedPos.x, acceptedPos.y, floorZ) or floorZ
                coords[#coords + 1] = vec3(acceptedPos.x, acceptedPos.y, pileFloor + 0.015)
            end
        end

        if #coords < maxPiles then
            local basePos = safeCenter or (doorCoords and (doorCoords + vec3(1.5, 1.5, 0.0))) or GetEntityCoords(cache.ped)
            for i = #coords + 1, maxPiles do
                local a = (i * 0.785)
                local r = 0.8 + ((i % 4) * 0.4)
                local px = basePos.x + math.cos(a) * r
                local py = basePos.y + math.sin(a) * r
                local pileFloor = GetFloorZAtCoord(px, py, floorZ) or floorZ
                coords[#coords + 1] = vec3(px, py, pileFloor + 0.015)
            end
        end

        return coords
    end

    local shellName = p.metadata and p.metadata.shell
    local shellData = (shellName and Settings.Shells and Settings.Shells[shellName]) or (shellName and Settings.IPLs and Settings.IPLs[shellName])

    local shellOrigin = nil
    local shellEnt = SpawnedShells and (SpawnedShells[propertyId] or (tonumber(propertyId) and SpawnedShells[tonumber(propertyId)]) or (tostring(propertyId) and SpawnedShells[tostring(propertyId)]))
    if shellEnt and DoesEntityExist(shellEnt) then
        shellOrigin = GetEntityCoords(shellEnt)
    elseif shellData and shellData.coords then
        shellOrigin = vec3(shellData.coords.x, shellData.coords.y, shellData.coords.z)
    else
        local doorCoords = GetEntranceCoords and GetEntranceCoords(p)
        if doorCoords then
            shellOrigin = vec3(doorCoords.x, doorCoords.y, Settings.ShellSpawningZ or -100.0)
        else
            shellOrigin = GetEntityCoords(cache.ped)
        end
    end

    if shellName and Settings.Trash and Settings.Trash.ShellOffsets and Settings.Trash.ShellOffsets[shellName] then
        local configuredOffsets = Settings.Trash.ShellOffsets[shellName]
        for i = 1, maxPiles do
            local basePos = nil
            if configuredOffsets[i] then
                basePos = shellOrigin + configuredOffsets[i]
            else
                local baseOff = configuredOffsets[((i - 1) % #configuredOffsets) + 1]
                local cycle = math.floor((i - 1) / #configuredOffsets)
                local angle = cycle * (math.pi / 3) + (i * 0.5)
                local spreadR = 0.85 * cycle
                local extraOff = vec3(math.cos(angle) * spreadR, math.sin(angle) * spreadR, 0.0)
                basePos = shellOrigin + baseOff + extraOff
            end
            local shellFloor = GetFloorZAtCoord(basePos.x, basePos.y, basePos.z)
            coords[i] = shellFloor and vec3(basePos.x, basePos.y, shellFloor + 0.015) or basePos
        end
        return coords
    end

    local doorZ = (shellData and shellData.doorOffset and shellData.doorOffset.z) or 0.0
    local defaultOffsets = {
        vec3(1.5, 2.3, doorZ + 0.03),
        vec3(-1.6, 2.6, doorZ + 0.03),
        vec3(2.2, 3.8, doorZ + 0.03),
        vec3(-2.0, 4.0, doorZ + 0.03),
        vec3(0.3, 4.8, doorZ + 0.03),
        vec3(1.8, 5.5, doorZ + 0.03),
        vec3(-1.4, 5.8, doorZ + 0.03),
        vec3(0.0, 3.2, doorZ + 0.03),
    }

    for i = 1, maxPiles do
        local off = defaultOffsets[((i - 1) % #defaultOffsets) + 1]
        local cycle = math.floor((i - 1) / #defaultOffsets)
        local extra = cycle > 0 and vec3(0.35 * cycle, -0.35 * cycle, 0.0) or vec3(0.0, 0.0, 0.0)
        local basePos = shellOrigin + off + extra
        local shellFloor = GetFloorZAtCoord(basePos.x, basePos.y, basePos.z)
        coords[i] = shellFloor and vec3(basePos.x, basePos.y, shellFloor + 0.015) or basePos
    end

    return coords
end

local function StopFliesEffect()
    if FliesParticleHandle then
        StopParticleFxLooped(FliesParticleHandle, false)
        FliesParticleHandle = nil
    end
end

function UnloadPropertyTrash(propertyId)
    propertyId = propertyId or (CurrentPropertyTrash and CurrentPropertyTrash.propertyId)
    if not propertyId then return end

    if OnUnloadPropertyRobot then
        OnUnloadPropertyRobot(propertyId, CurrentPropertyTrash and CurrentPropertyTrash.isApartment)
    end

    CachedTrashCoords[propertyId] = nil

    if SpawnedTrashProps[propertyId] then
        for idx, obj in pairs(SpawnedTrashProps[propertyId]) do
            if DoesEntityExist(obj) then
                exports.ox_target:removeLocalEntity(obj, 'lns_trash_pickup_' .. idx)
                DeleteEntity(obj)
            end
        end
        SpawnedTrashProps[propertyId] = nil
    end

    if SpawnedDroppedBags then
        for bagId, item in pairs(SpawnedDroppedBags) do
            if item.data and (item.data.propertyId == propertyId or tostring(item.data.propertyId) == tostring(propertyId)) then
                RemoveDroppedBagObject(bagId)
            end
        end
    end

    StopFliesEffect()

    if CurrentPropertyTrash and (CurrentPropertyTrash.propertyId == propertyId or tostring(CurrentPropertyTrash.propertyId) == tostring(propertyId)) then
        CurrentPropertyTrash = nil
    end
end

function RefreshPropertyTrash(propertyId, isApartment)
    if isRefreshingTrash then return end
    if not Settings.Trash or Settings.Trash.Enabled == false then return end
    if not propertyId then return end
    if not CurrentPropertyTrash or (tostring(CurrentPropertyTrash.propertyId) ~= tostring(propertyId)) then return end

    isRefreshingTrash = true

    local ok, err = pcall(function()
        local trashData = lib.callback.await('LNS_Housing:server:getPropertyTrash', false, propertyId, isApartment)

        if not CurrentPropertyTrash or (tostring(CurrentPropertyTrash.propertyId) ~= tostring(propertyId)) then
            return
        end

        if not trashData or not trashData.activePiles then
            return
        end

        local maxTrash = (Settings.Trash and Settings.Trash.MaxTrash) or 8
        local pileCoords = CachedTrashCoords[propertyId]
        if not pileCoords or #pileCoords < maxTrash then
            pileCoords = GetTrashCoordinates(propertyId, isApartment, maxTrash)
            CachedTrashCoords[propertyId] = pileCoords
        end

        SpawnedTrashProps[propertyId] = SpawnedTrashProps[propertyId] or {}

        local modelsList = Settings.Trash.TrashModels or { 'prop_rub_litter_01', 'prop_rub_box_02', 'prop_rub_binbag_01' }
        local firstActiveCoords = nil

        for idx = 1, maxTrash do
            local shouldBeActive = trashData.activePiles[idx] == true
            local existingObj = SpawnedTrashProps[propertyId][idx]

            if shouldBeActive then
                if not existingObj or not DoesEntityExist(existingObj) then
                    local pos = pileCoords[idx]
                    if pos then
                        local floorZ = GetFloorZAtCoord(pos.x, pos.y, pos.z, existingObj)
                        local spawnZ = (floorZ and (floorZ + 0.015)) or (pos.z - 0.98)
                        local finalPos = vec3(pos.x, pos.y, spawnZ)
                        pileCoords[idx] = finalPos

                        local overlapsSpawned = false
                        for oIdx, otherObj in pairs(SpawnedTrashProps[propertyId]) do
                            if oIdx ~= idx and DoesEntityExist(otherObj) then
                                local oc = GetEntityCoords(otherObj)
                                if #(vec2(finalPos.x, finalPos.y) - vec2(oc.x, oc.y)) < 0.40 then
                                    overlapsSpawned = true
                                    break
                                end
                            end
                        end

                        if not overlapsSpawned then
                            local numPropId = tonumber(propertyId) or 1
                            local modelIdx = ((numPropId + idx * 3) % #modelsList) + 1
                            local modelName = modelsList[modelIdx]
                            local modelHash = joaat(modelName)

                            lib.requestModel(modelHash)
                            local obj = CreateObjectNoOffset(modelHash, finalPos.x, finalPos.y, finalPos.z, false, false, false)
                            if DoesEntityExist(obj) then
                                SetEntityRotation(obj, 0.0, 0.0, (idx * 73.0) % 360.0, 2, true)
                                FreezeEntityPosition(obj, true)

                                local verifiedFloor = GetFloorZAtCoord(finalPos.x, finalPos.y, finalPos.z, obj)
                                if verifiedFloor and math.abs(verifiedFloor - finalPos.z) > 0.04 then
                                    finalPos = vec3(finalPos.x, finalPos.y, verifiedFloor + 0.015)
                                    SetEntityCoords(obj, finalPos.x, finalPos.y, finalPos.z, false, false, false, false)
                                end

                                firstActiveCoords = firstActiveCoords or finalPos

                                exports.ox_target:addLocalEntity(obj, {
                                    {
                                        name = 'lns_trash_pickup_' .. idx,
                                        icon = 'fas fa-broom',
                                        label = 'Clean Up Trash',
                                        distance = 2.0,
                                        canInteract = function()
                                            if IsTrashItem then
                                                return not isCleaningTrash
                                            end
                                            return not IsCarryingTrash and not isCleaningTrash
                                        end,
                                        onSelect = function()
                                            CleanTrashPile(propertyId, idx, isApartment)
                                        end
                                    }
                                })

                                SpawnedTrashProps[propertyId][idx] = obj
                            end
                        end
                    end
                else
                    if DoesEntityExist(existingObj) then
                        local curCoords = GetEntityCoords(existingObj)
                        local correctFloor = GetFloorZAtCoord(curCoords.x, curCoords.y, curCoords.z, existingObj)
                        if correctFloor and (curCoords.z - correctFloor > 0.10 or correctFloor - curCoords.z > 0.10) then
                            SetEntityCoords(existingObj, curCoords.x, curCoords.y, correctFloor + 0.015, false, false, false, false)
                        end
                        firstActiveCoords = firstActiveCoords or GetEntityCoords(existingObj)
                    end
                end
            else
                if existingObj and DoesEntityExist(existingObj) then
                    exports.ox_target:removeLocalEntity(existingObj, 'lns_trash_pickup_' .. idx)
                    DeleteEntity(existingObj)
                end
                SpawnedTrashProps[propertyId][idx] = nil
            end
        end

        if Settings.Trash.FliesEffect and trashData.trashCount and trashData.trashCount >= maxTrash and firstActiveCoords and not FliesParticleHandle then
            lib.requestNamedPtfxAsset('core')
            UseParticleFxAssetNextCall('core')
            FliesParticleHandle = StartParticleFxLoopedAtCoord(
                'ent_amb_fly_swarm',
                firstActiveCoords.x, firstActiveCoords.y, firstActiveCoords.z + 0.35,
                0.0, 0.0, 0.0,
                1.0, false, false, false, false
            )
        elseif (not trashData.trashCount or trashData.trashCount < maxTrash) and FliesParticleHandle then
            StopFliesEffect()
        end
    end)

    isRefreshingTrash = false
    if not ok then
        debugPrint('error', '[LNS_Housing:Trash] Error refreshing trash:', err)
    end

    isRefreshingTrash = false
end

function LoadPropertyTrash(propertyId, isApartment, forceReload)
    if not Settings.Trash or Settings.Trash.Enabled == false then return end
    if not propertyId then return end

    if forceReload then
        CachedTrashCoords[propertyId] = nil
    end

    if not forceReload and CurrentPropertyTrash and (tostring(CurrentPropertyTrash.propertyId) == tostring(propertyId)) and CurrentPropertyTrash.isApartment == (isApartment and true or false) then
        return
    end

    if CurrentPropertyTrash and tostring(CurrentPropertyTrash.propertyId) ~= tostring(propertyId) then
        UnloadPropertyTrash(CurrentPropertyTrash.propertyId)
    end

    CurrentPropertyTrash = { propertyId = propertyId, isApartment = isApartment and true or false }
    RefreshPropertyTrash(propertyId, isApartment)

    CreateThread(function()
        local dropped = lib.callback.await('LNS_Housing:server:getDroppedBags', false)
        if dropped and #dropped > 0 then
            for _, bagData in ipairs(dropped) do
                SpawnDroppedBagObject(bagData)
            end
        end
    end)
end

CreateThread(function()
    while true do
        Wait(5000)
        if CurrentPropertyTrash and CurrentPropertyTrash.propertyId and Settings.Trash and Settings.Trash.Enabled ~= false then
            RefreshPropertyTrash(CurrentPropertyTrash.propertyId, CurrentPropertyTrash.isApartment)
        end
    end
end)

function DetachCarriedTrashBag()
    if CarriedBagEntity and DoesEntityExist(CarriedBagEntity) then
        DetachEntity(CarriedBagEntity, true, true)
        DeleteEntity(CarriedBagEntity)
        CarriedBagEntity = nil
    end

    local ped = cache.ped or PlayerPedId()
    local carryConfig = Settings.Trash and Settings.Trash.CarryProp or {}
    local animDict = carryConfig.animDict or 'missfbi4prepp1'
    local animClip = carryConfig.animClip or '_bag_walk_garbage_man'
    StopAnimTask(ped, animDict, animClip, 1.0)
    ClearPedTasks(ped)

    IsCarryingTrash = false
    CurrentCarriedTrash = nil
end

function CleanTrashPile(propertyId, index, isApartment)
    if not IsTrashItem then
        if IsCarryingTrash then
            Bridge.Client.Notify('You are already carrying a bag of trash! Dispose of it in a dumpster first.', 'error')
            return
        end
    end

    if isCleaningTrash then return end

    if Settings.Trash and Settings.Trash.RequireKeyAccess then
        local targetType = isApartment and 'apartment' or 'house'
        local hasAccess = lib.callback.await('LNS_Housing:server:checkPermission', false, targetType, propertyId, 'entry')
        if not hasAccess then
            Bridge.Client.Notify('You do not have permission to clean trash in this property.', 'error')
            return
        end
    end

    isCleaningTrash = true

    lib.requestAnimDict('anim@mp_snowball')
    local success = lib.progressBar({
        duration = Settings.Trash.CleanDuration or 4000,
        label = 'Cleaning up trash...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true,
        },
        anim = {
            dict = 'anim@mp_snowball',
            clip = 'pickup_snowball'
        }
    })
    isCleaningTrash = false

    if success then
        local res = lib.callback.await('LNS_Housing:server:pickupTrashPile', false, propertyId, index, isApartment)
        if res and res.success then
            if SpawnedTrashProps[propertyId] and SpawnedTrashProps[propertyId][index] then
                local obj = SpawnedTrashProps[propertyId][index]
                if DoesEntityExist(obj) then
                    exports.ox_target:removeLocalEntity(obj, 'lns_trash_pickup_' .. index)
                    DeleteEntity(obj)
                end
                SpawnedTrashProps[propertyId][index] = nil
            end

            local remainingSpawned = 0
            if SpawnedTrashProps[propertyId] then
                for _, o in pairs(SpawnedTrashProps[propertyId]) do
                    if DoesEntityExist(o) then remainingSpawned = remainingSpawned + 1 end
                end
            end

            if (res.remainingCount and res.remainingCount < ((Settings.Trash and Settings.Trash.MaxTrash) or 5)) or remainingSpawned == 0 then
                StopFliesEffect()
            end

            AttachCarriedTrashBag(propertyId, isApartment)
            if IsTrashItem then
                Bridge.Client.Notify('You cleaned the trash and placed a trash bag in your inventory.', 'inform')
            else
                Bridge.Client.Notify('You picked up a bag of trash. Take it outside to a street dumpster!', 'inform')
            end
        else
            Bridge.Client.Notify(res and res.message or 'Failed to pick up trash.', 'error')
        end
    else
        Bridge.Client.Notify('Cleaning cancelled.', 'inform')
    end
end

function SpawnDroppedBagObject(bagData)
    if not bagData or not bagData.id then return end
    if SpawnedDroppedBags[bagData.id] and DoesEntityExist(SpawnedDroppedBags[bagData.id].entity) then
        return
    end

    local carryConfig = Settings.Trash and Settings.Trash.CarryProp or {}
    local propModel = joaat(carryConfig.model or 'prop_cs_rub_binbag_01')
    lib.requestModel(propModel)

    local coords = bagData.coords
    local floorZ = GetFloorZAtCoord(coords.x, coords.y, coords.z)
    local spawnZ = (floorZ and (floorZ + 0.03)) or coords.z

    local obj = CreateObjectNoOffset(propModel, coords.x, coords.y, spawnZ, false, false, false)
    if DoesEntityExist(obj) then
        PlaceObjectOnGroundProperly(obj)
        FreezeEntityPosition(obj, true)
        SetEntityCollision(obj, true, true)

        local targetName = 'lns_dropped_bag_' .. bagData.id
        exports.ox_target:addLocalEntity(obj, {
            {
                name = targetName,
                icon = 'fas fa-hand-holding',
                label = 'Pick Up Trash Bag',
                distance = 2.0,
                canInteract = function()
                    if IsTrashItem then
                        return not isCleaningTrash
                    end
                    return not IsCarryingTrash and not isCleaningTrash
                end,
                onSelect = function()
                    PickupDroppedTrashBag(bagData.id)
                end
            }
        })

        SpawnedDroppedBags[bagData.id] = { entity = obj, data = bagData, targetName = targetName }
    end
end

function RemoveDroppedBagObject(bagId)
    local item = SpawnedDroppedBags[bagId]
    if item then
        if item.entity and DoesEntityExist(item.entity) then
            if item.targetName then
                exports.ox_target:removeLocalEntity(item.entity, item.targetName)
            end
            DeleteEntity(item.entity)
        end
        SpawnedDroppedBags[bagId] = nil
    end
end

function PickupDroppedTrashBag(bagId)
    if not IsTrashItem and IsCarryingTrash then
        Bridge.Client.Notify('You are already carrying a trash bag! Dispose of it first.', 'error')
        return
    end

    local ped = cache.ped or PlayerPedId()
    local item = SpawnedDroppedBags[bagId]
    if item and item.entity and DoesEntityExist(item.entity) then
        TaskTurnPedToFaceEntity(ped, item.entity, 800)
        Wait(400)
    end

    lib.requestAnimDict('anim@mp_snowball')
    TaskPlayAnim(ped, 'anim@mp_snowball', 'pickup_snowball', 8.0, -8.0, 1500, 49, 0, false, false, false)
    Wait(900)

    local res = lib.callback.await('LNS_Housing:server:pickupDroppedBag', false, bagId)
    if res and res.success then
        AttachCarriedTrashBag(res.propertyId, res.isApartment)
        if IsTrashItem then
            Bridge.Client.Notify('You picked up the trash bag and put it in your inventory.', 'inform')
        else
            Bridge.Client.Notify('You picked up the trash bag. Take it outside to a street dumpster!', 'inform')
        end
    else
        Bridge.Client.Notify(res and res.message or 'Failed to pick up trash bag.', 'error')
    end
end

RegisterNetEvent('LNS_Housing:client:syncDroppedBag', function(bagData)
    SpawnDroppedBagObject(bagData)
end)

RegisterNetEvent('LNS_Housing:client:syncRemoveDroppedBag', function(bagId)
    RemoveDroppedBagObject(bagId)
end)

function AttachCarriedTrashBag(propertyId, isApartment)
    if CarriedBagEntity and DoesEntityExist(CarriedBagEntity) then
        DeleteEntity(CarriedBagEntity)
        CarriedBagEntity = nil
    end

    local ped = cache.ped or PlayerPedId()
    local carryConfig = Settings.Trash and Settings.Trash.CarryProp or {}
    local propModel = joaat(carryConfig.model or 'prop_cs_rub_binbag_01')

    lib.requestModel(propModel)
    local bagObj = CreateObject(propModel, 0.0, 0.0, 0.0, true, true, false)
    SetEntityCollision(bagObj, false, false)

    local boneIdx = GetPedBoneIndex(ped, carryConfig.bone or 57005)
    local off = carryConfig.offset or vec3(0.12, 0.0, -0.05)
    local rot = carryConfig.rotation or vec3(220.0, 120.0, 0.0)

    AttachEntityToEntity(
        bagObj,
        ped,
        boneIdx,
        off.x, off.y, off.z,
        rot.x, rot.y, rot.z,
        true, true, false, true, 1, true
    )

    CarriedBagEntity = bagObj
    IsCarryingTrash = true
    CurrentCarriedTrash = { propertyId = propertyId, isApartment = isApartment and true or false }

    local animDict = carryConfig.animDict or 'missfbi4prepp1'
    local animClip = carryConfig.animClip or '_bag_walk_garbage_man'

    CreateThread(function()
        lib.requestAnimDict(animDict)
        while IsCarryingTrash do
            local currentPed = cache.ped or PlayerPedId()

            if IsEntityDead(currentPed) then
                DropTrashBag(false)
                break
            end

            if IsPedInAnyVehicle(currentPed, false) then
                if IsTrashItem then
                    DetachCarriedTrashBag()
                else
                    DropTrashBag(false)
                end
                break
            end

            if not isThrowingTrash and not isCleaningTrash and not IsEntityPlayingAnim(currentPed, animDict, animClip, 3) then
                TaskPlayAnim(currentPed, animDict, animClip, 6.0, -6.0, -1, 49, 0, false, false, false)
            end

            Wait(250)
        end
    end)
end

function DropTrashBag(notify)
    local hasItem = IsTrashItem and (Bridge.Client.Search('count', TrashItemName) or 0) > 0
    if not IsCarryingTrash and not hasItem then
        return
    end

    local ped = cache.ped or PlayerPedId()
    local pCoords = GetEntityCoords(ped)
    local fwd = GetEntityForwardVector(ped)
    local dropPos = pCoords + fwd * 0.70
    local floorZ = GetFloorZAtCoord(dropPos.x, dropPos.y, dropPos.z)
    if floorZ then
        dropPos = vec3(dropPos.x, dropPos.y, floorZ + 0.03)
    end

    local propId = CurrentCarriedTrash and CurrentCarriedTrash.propertyId
    local isApt = CurrentCarriedTrash and CurrentCarriedTrash.isApartment

    DetachCarriedTrashBag()

    TriggerServerEvent('LNS_Housing:server:dropTrashBag', propId, isApt, dropPos)

    if notify ~= false then
        Bridge.Client.Notify('You dropped the trash bag on the ground.', 'inform')
    end
end

function ThrowTrashInDumpster(dumpsterEntity)
    if IsTrashItem then
        local count = Bridge.Client.Search('count', TrashItemName) or 0
        if count <= 0 and not IsCarryingTrash then
            Bridge.Client.Notify('You do not have any trash bags in your inventory!', 'error')
            return
        end
    else
        if not IsCarryingTrash then
            Bridge.Client.Notify('You are not carrying any trash to throw away!', 'error')
            return
        end
    end

    if isThrowingTrash then return end
    isThrowingTrash = true

    local ped = cache.ped or PlayerPedId()
    local dumpsterCoords = (dumpsterEntity and DoesEntityExist(dumpsterEntity)) and GetEntityCoords(dumpsterEntity) or nil

    if dumpsterEntity and DoesEntityExist(dumpsterEntity) then
        TaskTurnPedToFaceEntity(ped, dumpsterEntity, 1000)
        Wait(800)
    end

    lib.requestAnimDict('anim@heists@narcotics@trash')
    local success = lib.progressBar({
        duration = Settings.Trash.ThrowDuration or 2500,
        label = 'Tossing trash into dumpster...',
        useWhileDead = false,
        canCancel = false,
        disable = {
            move = true,
            car = true,
            combat = true,
        },
        anim = {
            dict = 'anim@heists@narcotics@trash',
            clip = 'throw_b'
        }
    })
    isThrowingTrash = false

    if success then
        local propId = CurrentCarriedTrash and CurrentCarriedTrash.propertyId
        local isApt = CurrentCarriedTrash and CurrentCarriedTrash.isApartment

        DetachCarriedTrashBag()

        TriggerServerEvent('LNS_Housing:server:disposeTrash', propId, isApt, dumpsterCoords)
    end
end

local function RegisterDumpsterModels()
    if not Settings.Trash or not Settings.Trash.DumpsterModels then return end

    exports.ox_target:addModel(Settings.Trash.DumpsterModels, {
        {
            name = 'lns_dumpster_throw_trash',
            icon = 'fas fa-dumpster',
            label = 'Throw Away Trash',
            distance = 2.5,
            canInteract = function(entity, distance, coords, name)
                if isThrowingTrash then return false end
                if IsCarryingTrash then return true end
                if IsTrashItem then
                    local count = Bridge.Client.Search('count', TrashItemName) or 0
                    return count > 0
                end
                return false
            end,
            onSelect = function(data)
                ThrowTrashInDumpster(data.entity)
            end
        }
    })
    debugPrint('info', ('[LNS_Housing:Trash] Registered %d street dumpster models with ox_target.'):format(#Settings.Trash.DumpsterModels))
end

RegisterDumpsterModels()

RegisterNetEvent('LNS_Housing:client:syncTrashRemoved', function(propertyId, index, isApartment)
    if SpawnedTrashProps[propertyId] and SpawnedTrashProps[propertyId][index] then
        local obj = SpawnedTrashProps[propertyId][index]
        if DoesEntityExist(obj) then
            exports.ox_target:removeLocalEntity(obj, 'lns_trash_pickup_' .. index)
            DeleteEntity(obj)
        end
        SpawnedTrashProps[propertyId][index] = nil
    end

    local remaining = 0
    if SpawnedTrashProps[propertyId] then
        for _, o in pairs(SpawnedTrashProps[propertyId]) do
            if DoesEntityExist(o) then remaining = remaining + 1 end
        end
    end
    if remaining == 0 then
        StopFliesEffect()
    end
end)

RegisterNetEvent('LNS_Housing:client:syncTrashReset', function(propertyId, isApartment)
    CachedTrashCoords[propertyId] = nil
    if tonumber(propertyId) then CachedTrashCoords[tonumber(propertyId)] = nil end
    if tostring(propertyId) then CachedTrashCoords[tostring(propertyId)] = nil end
    if CurrentPropertyTrash and (CurrentPropertyTrash.propertyId == propertyId or tostring(CurrentPropertyTrash.propertyId) == tostring(propertyId)) then
        RefreshPropertyTrash(CurrentPropertyTrash.propertyId, CurrentPropertyTrash.isApartment)
    end
end)

RegisterNetEvent('LNS_Housing:client:toggleCarryTrashItem', function()
    local count = IsTrashItem and (Bridge.Client.Search('count', TrashItemName) or 0) or 0
    if count <= 0 then
        if IsCarryingTrash then
            DetachCarriedTrashBag()
        end
        return
    end

    if IsCarryingTrash then
        DetachCarriedTrashBag()
        Bridge.Client.Notify('You put the trash bag away.', 'inform')
    else
        AttachCarriedTrashBag(nil, false)
        Bridge.Client.Notify('You are now holding a trash bag.', 'inform')
    end
end)

RegisterCommand('droptrash', function()
    local itemCount = IsTrashItem and (Bridge.Client.Search('count', TrashItemName) or 0) or 0

    if IsCarryingTrash or itemCount > 0 then
        DropTrashBag(true)
    else
        Bridge.Client.Notify('You are not carrying any trash bag.', 'inform')
    end
end, false)

exports('LoadPropertyTrash', LoadPropertyTrash)
exports('UnloadPropertyTrash', UnloadPropertyTrash)
exports('RefreshPropertyTrash', RefreshPropertyTrash)
exports('IsCarryingTrash', function() return IsCarryingTrash end)

local DockModels = {
    [joaat('mula_prop_cleandock_small_occupied')] = {
        type = 'small',
        occupied = 'mula_prop_cleandock_small_occupied',
        empty = 'mula_prop_cleandock',
        robot = 'mula_prop_cleanrobot_small',
        label = 'Small Cleaning Robot',
        forwardOffset = 0.70,
    },
    [joaat('mula_prop_cleandock')] = {
        type = 'small',
        occupied = 'mula_prop_cleandock_small_occupied',
        empty = 'mula_prop_cleandock',
        robot = 'mula_prop_cleanrobot_small',
        label = 'Small Cleaning Robot',
        forwardOffset = 0.70,
    },
    [joaat('mula_prop_cleandock_tall_occupied')] = {
        type = 'tall',
        occupied = 'mula_prop_cleandock_tall_occupied',
        empty = 'mula_prop_cleandock_tall',
        robot = 'mula_prop_cleanrobot',
        label = 'Large Cleaning Robot',
        forwardOffset = 0.80,
    },
    [joaat('mula_prop_cleandock_tall')] = {
        type = 'tall',
        occupied = 'mula_prop_cleandock_tall_occupied',
        empty = 'mula_prop_cleandock_tall',
        robot = 'mula_prop_cleanrobot',
        label = 'Large Cleaning Robot',
        forwardOffset = 0.80,
    },
}

local ActiveCleaningRobots = {}
local RegisteredDocks = {}
local IsRecordingPath = false
local RecordedWaypoints = {}
local IsPreviewingPath = false

local function FormatTimerText(seconds)
    seconds = tonumber(seconds) or 0
    if seconds >= 86400 then
        local days = math.floor(seconds / 86400)
        return days == 1 and 'Every 1 Day' or ('Every %d Days'):format(days)
    elseif seconds >= 3600 then
        local hrs = seconds / 3600
        return hrs == 1 and 'Every 1 Hour' or ('Every %g Hours'):format(hrs)
    elseif seconds >= 60 then
        return ('Every %d Minutes'):format(math.floor(seconds / 60))
    else
        return ('Every %d Seconds'):format(seconds)
    end
end

local function FormatDurationAgo(seconds)
    seconds = tonumber(seconds) or 0
    if seconds >= 86400 then
        return ('%dd'):format(math.floor(seconds / 86400))
    elseif seconds >= 3600 then
        return ('%dh'):format(math.floor(seconds / 3600))
    elseif seconds >= 60 then
        return ('%dm'):format(math.floor(seconds / 60))
    else
        return ('%ds'):format(seconds)
    end
end

local function EnsureModelLoaded(modelInput)
    local hash = tonumber(modelInput) or GetHashKey(modelInput)
    if not hash or hash == 0 then return nil end
    if HasModelLoaded(hash) then return hash end

    local ok = pcall(lib.requestModel, hash, 5000)
    if ok and HasModelLoaded(hash) then return hash end

    RequestModel(hash)
    local endTimer = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < endTimer do
        Wait(50)
    end
    return HasModelLoaded(hash) and hash or nil
end

function IsRobotCleaning(propertyId, isApartment)
    local key = (isApartment and 'apartment_' or 'house_') .. tostring(propertyId)
    return ActiveCleaningRobots[key] ~= nil and ActiveCleaningRobots[key].isRunning == true
end

function SetupCleanRobotDockTarget(propertyId, furnitureId, entity, furnData, itemData, isApartment)
    if not entity or not DoesEntityExist(entity) then return end
    local key = (isApartment and 'apartment_' or 'house_') .. tostring(propertyId)
    RegisteredDocks[key] = RegisteredDocks[key] or {}
    RegisteredDocks[key][tostring(furnitureId)] = {
        entity = entity,
        furnitureId = furnitureId,
        propertyId = propertyId,
        isApartment = isApartment and true or false,
        model = furnData and furnData.model or GetEntityModel(entity),
        position = furnData and furnData.position or GetEntityCoords(entity),
        rotation = furnData and furnData.rotation or GetEntityRotation(entity, 2)
    }

    local targetPrefix = 'lns_dock_' .. tostring(furnitureId)
    exports.ox_target:removeLocalEntity(entity, {
        targetPrefix .. '_clean',
        targetPrefix .. '_stop',
        targetPrefix .. '_timer',
        targetPrefix .. '_path'
    })

    exports.ox_target:addLocalEntity(entity, {
        {
            name = targetPrefix .. '_clean',
            icon = 'fas fa-broom',
            label = 'Start Cleaning Cycle',
            distance = 2.0,
            canInteract = function()
                return not IsRobotCleaning(propertyId, isApartment) and not IsRecordingPath
            end,
            onSelect = function()
                RequestStartRobotCleaning(propertyId, isApartment, furnitureId)
            end
        },
        {
            name = targetPrefix .. '_stop',
            icon = 'fas fa-circle-stop',
            label = 'Return to Dock',
            distance = 2.0,
            canInteract = function()
                return IsRobotCleaning(propertyId, isApartment)
            end,
            onSelect = function()
                StopRobotCleaning(propertyId, isApartment)
            end
        },
        {
            name = targetPrefix .. '_timer',
            icon = 'fas fa-clock',
            label = 'Cleaning Schedule Timer',
            distance = 2.0,
            canInteract = function()
                return not IsRecordingPath
            end,
            onSelect = function()
                OpenRobotTimerMenu(propertyId, isApartment, furnitureId)
            end
        },
        {
            name = targetPrefix .. '_path',
            icon = 'fas fa-route',
            label = 'Manage Cleaning Path',
            distance = 2.0,
            canInteract = function()
                return not IsRobotCleaning(propertyId, isApartment) and not IsRecordingPath
            end,
            onSelect = function()
                OpenRobotPathMenu(propertyId, isApartment, furnitureId)
            end
        }
    })
end

function RequestStartRobotCleaning(propertyId, isApartment, furnitureId)
    if IsRobotCleaning(propertyId, isApartment) then
        Bridge.Client.Notify('Cleaning robot is already in progress!', 'inform')
        return
    end

    if Settings.Trash and Settings.Trash.RequireKeyAccess then
        local targetType = isApartment and 'apartment' or 'house'
        local hasAccess = lib.callback.await('LNS_Housing:server:checkPermission', false, targetType, propertyId, 'entry')
        if not hasAccess then
            Bridge.Client.Notify('You do not have permission to operate the cleaning robot.', 'error')
            return
        end
    end

    TriggerServerEvent('LNS_Housing:server:requestRobotStartClean', propertyId, isApartment, furnitureId)
end

function StopRobotCleaning(propertyId, isApartment)
    local key = (isApartment and 'apartment_' or 'house_') .. tostring(propertyId)
    if ActiveCleaningRobots[key] then
        if ActiveCleaningRobots[key].cancelRef then
            ActiveCleaningRobots[key].cancelRef.cancelRequested = true
        end
        Bridge.Client.Notify('Recalling cleaning robot back to dock...', 'inform')
    end
end

local function SetRobotTimerChoice(propertyId, isApartment, seconds, label)
    local res = lib.callback.await('LNS_Housing:server:setRobotTimer', false, propertyId, isApartment, seconds)
    if res and res.success then
        Bridge.Client.Notify(('Cleaning timer set to: %s'):format(label), 'success')
    else
        Bridge.Client.Notify((res and res.message) or 'Failed to set timer.', 'error')
    end
end

function OpenRobotTimerMenu(propertyId, isApartment, furnitureId)
    local data = lib.callback.await('LNS_Housing:server:getRobotData', false, propertyId, isApartment)
    local currentTimer = (data and data.timerInterval) or 3600

    local timerDesc = 'Current: ' .. (currentTimer == 0 and 'Disabled (Manual Clean Only)' or FormatTimerText(currentTimer))
    if data and data.lastClean and data.lastClean > 0 then
        local diff = (data.serverTime or os.time()) - data.lastClean
        if diff > 0 then
            timerDesc = timerDesc .. ' | Last clean: ' .. FormatDurationAgo(diff) .. ' ago'
        end
    end

    local timerOptions = {
        {
            title = 'Current Schedule Status',
            description = timerDesc,
            icon = 'fas fa-circle-info',
            readOnly = true,
        }
    }

    local available = (Settings.Trash and Settings.Trash.Robot and Settings.Trash.Robot.AvailableTimers)
    if available and #available > 0 then
        for _, opt in ipairs(available) do
            local icon = 'fas fa-clock'
            if opt.value == 0 then
                icon = 'fas fa-ban'
            elseif opt.value < 3600 then
                icon = 'fas fa-stopwatch'
            elseif opt.value >= 86400 then
                icon = 'fas fa-calendar-day'
            end
            local desc = opt.value == 0 and 'Robot stays in dock until you click Start.' or ('Cleans automatically %s.'):format(opt.label:lower())

            timerOptions[#timerOptions + 1] = {
                title = opt.label,
                description = desc,
                icon = icon,
                arrow = true,
                onSelect = function()
                    SetRobotTimerChoice(propertyId, isApartment, opt.value, opt.label)
                end
            }
        end
    else
        local defaultPresets = {
            { label = 'Disabled (Manual Clean Only)', value = 0, icon = 'fas fa-ban', desc = 'Robot stays in dock until you click Start.' },
            { label = 'Every 15 Minutes', value = 900, icon = 'fas fa-stopwatch', desc = 'Cleans automatically every 15 minutes.' },
            { label = 'Every 30 Minutes', value = 1800, icon = 'fas fa-stopwatch', desc = 'Cleans automatically every 30 minutes.' },
            { label = 'Every 1 Hour', value = 3600, icon = 'fas fa-clock', desc = 'Cleans automatically every hour.' },
            { label = 'Every 2 Hours', value = 7200, icon = 'fas fa-clock', desc = 'Cleans automatically every 2 hours.' },
            { label = 'Every 4 Hours', value = 14400, icon = 'fas fa-clock', desc = 'Cleans automatically every 4 hours.' },
            { label = 'Every 8 Hours', value = 28800, icon = 'fas fa-clock', desc = 'Cleans automatically every 8 hours.' },
            { label = 'Every 24 Hours', value = 86400, icon = 'fas fa-calendar-day', desc = 'Cleans automatically once per day.' },
        }
        for _, opt in ipairs(defaultPresets) do
            timerOptions[#timerOptions + 1] = {
                title = opt.label,
                description = opt.desc,
                icon = opt.icon,
                arrow = true,
                onSelect = function()
                    SetRobotTimerChoice(propertyId, isApartment, opt.value, opt.label)
                end
            }
        end
    end

    timerOptions[#timerOptions + 1] = {
        title = 'Custom Minutes...',
        description = 'Set a custom minute interval for cleaning.',
        icon = 'fas fa-pen-to-square',
        arrow = true,
        onSelect = function()
            local input = lib.inputDialog('Custom Robot Cleaning Schedule', {
                {
                    type = 'number',
                    label = 'Timer Interval (Minutes)',
                    description = 'e.g. 45 for every 45 minutes',
                    min = 5,
                    max = 1440,
                    default = math.max(5, math.floor(currentTimer / 60))
                }
            })
            if input and input[1] then
                local mins = tonumber(input[1])
                if mins and mins >= 5 then
                    SetRobotTimerChoice(propertyId, isApartment, mins * 60, ('Every %d Minutes'):format(mins))
                end
            end
        end
    }

    lib.registerContext({
        id = 'lns_robot_timer_menu',
        title = 'Cleaning Schedule Timer',
        options = timerOptions
    })
    lib.showContext('lns_robot_timer_menu')
end

function OpenRobotPathMenu(propertyId, isApartment, furnitureId)
    local data = lib.callback.await('LNS_Housing:server:getRobotData', false, propertyId, isApartment)
    local hasPath = data and data.customPath and #data.customPath > 0
    local pathCount = hasPath and #data.customPath or 0

    local pathOptions = {
        {
            title = 'Path Configuration',
            description = hasPath and ('Custom Path Active (%d waypoints)'):format(pathCount) or 'No custom route set (Robot dynamically cleans trash piles)',
            icon = 'fas fa-circle-info',
            readOnly = true,
        },
        {
            title = 'Record New Route (Walk Mode)',
            description = 'Walk around your room to drop waypoints for the robot to follow.',
            icon = 'fas fa-person-walking',
            arrow = true,
            onSelect = function()
                StartRecordingRobotPath(propertyId, isApartment, furnitureId)
            end
        },
        {
            title = 'Preview Current Route',
            description = 'Displays glowing ground markers showing the robot route for 15s.',
            icon = 'fas fa-eye',
            disabled = not hasPath,
            arrow = true,
            onSelect = function()
                PreviewRobotPath(data.customPath)
            end
        },
        {
            title = 'Delete Saved Route',
            description = 'Clear custom path. Robot will auto-navigate directly between trash piles.',
            icon = 'fas fa-trash-can',
            disabled = not hasPath,
            arrow = true,
            onSelect = function()
                local confirm = lib.alertDialog({
                    header = 'Delete Cleaning Route?',
                    content = 'Are you sure you want to delete the custom route? The robot will revert to navigating directly to trash piles.',
                    centered = true,
                    cancel = true
                })
                if confirm == 'confirm' then
                    local res = lib.callback.await('LNS_Housing:server:clearRobotPath', false, propertyId, isApartment)
                    if res and res.success then
                        Bridge.Client.Notify('Cleaning route deleted.', 'success')
                    end
                end
            end
        }
    }

    lib.registerContext({
        id = 'lns_robot_path_menu',
        title = 'Manage Cleaning Path',
        options = pathOptions
    })
    lib.showContext('lns_robot_path_menu')
end

function StartRecordingRobotPath(propertyId, isApartment, furnitureId)
    if IsRecordingPath then return end

    local key = (isApartment and 'apartment_' or 'house_') .. tostring(propertyId)
    local dockObj = (LoadedFurniture[propertyId] and LoadedFurniture[propertyId][furnitureId])
        or (RegisteredDocks[key] and RegisteredDocks[key][tostring(furnitureId)] and RegisteredDocks[key][tostring(furnitureId)].entity)

    if not dockObj or not DoesEntityExist(dockObj) then
        Bridge.Client.Notify('Dock entity not found.', 'error')
        return
    end

    local dockCoords = GetEntityCoords(dockObj)
    local dockModel = GetEntityModel(dockObj)
    local dockCfg = DockModels[dockModel] or DockModels[joaat('mula_prop_cleandock_small_occupied')]
    local dockOffset = dockCfg.forwardOffset or 0.70
    local dockHeadingOffset = (Settings.Trash and Settings.Trash.Robot and Settings.Trash.Robot.DockHeadingOffset) or 180.0
    local localY = (dockHeadingOffset == 180.0) and -dockOffset or dockOffset
    local frontOfDock = GetOffsetFromEntityInWorldCoords(dockObj, 0.0, localY, 0.0)

    local ped = cache.ped or PlayerPedId()
    local pedCoords = GetEntityCoords(ped)

    if #(pedCoords - dockCoords) > 10.0 then
        Bridge.Client.Notify('Please stand near the cleaning robot dock before starting to record.', 'error')
        return
    end

    IsRecordingPath = true
    RecordedWaypoints = {}

    Bridge.Client.Notify('Route recording active! Walk around to place waypoints.', 'inform')
    lib.showTextUI('[E] Add Point  |  [BACKSPACE] Undo  |  [ENTER] Save Route  |  [ESC] Cancel\nRoute Waypoints: 0 / 60', { position = 'top-center' })

    CreateThread(function()
        local maxWaypoints = (Settings.Trash and Settings.Trash.Robot and Settings.Trash.Robot.MaxWaypoints) or 60

        while IsRecordingPath do
            local currentPed = cache.ped or PlayerPedId()
            local pos = GetEntityCoords(currentPed)
            local lastPt = #RecordedWaypoints > 0 and RecordedWaypoints[#RecordedWaypoints] or frontOfDock

            local distFromLast = #(vec2(pos.x, pos.y) - vec2(lastPt.x, lastPt.y))
            if distFromLast >= 1.5 and #RecordedWaypoints < maxWaypoints then
                local foundGround, groundZ = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z, false)
                local wpZ = foundGround and groundZ + 0.05 or pos.z - 0.95
                RecordedWaypoints[#RecordedWaypoints + 1] = vec3(pos.x, pos.y, wpZ)
                lib.showTextUI(('[E] Add Point  |  [BACKSPACE] Undo  |  [ENTER] Save Route  |  [ESC] Cancel\nRoute Waypoints: %d / %d'):format(#RecordedWaypoints, maxWaypoints), { position = 'top-center' })
            end

            if IsControlJustPressed(0, 38) then
                if #RecordedWaypoints < maxWaypoints then
                    local foundGround, groundZ = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z, false)
                    local wpZ = foundGround and groundZ + 0.05 or pos.z - 0.95
                    RecordedWaypoints[#RecordedWaypoints + 1] = vec3(pos.x, pos.y, wpZ)
                    lib.showTextUI(('[E] Add Point  |  [BACKSPACE] Undo  |  [ENTER] Save Route  |  [ESC] Cancel\nRoute Waypoints: %d / %d'):format(#RecordedWaypoints, maxWaypoints), { position = 'top-center' })
                else
                    Bridge.Client.Notify('Maximum waypoint limit reached (60)!', 'error')
                end
            end

            if IsControlJustPressed(0, 177) or IsControlJustPressed(0, 194) then
                if #RecordedWaypoints > 0 then
                    table.remove(RecordedWaypoints)
                    lib.showTextUI(('[E] Add Point  |  [BACKSPACE] Undo  |  [ENTER] Save Route  |  [ESC] Cancel\nRoute Waypoints: %d / %d'):format(#RecordedWaypoints, maxWaypoints), { position = 'top-center' })
                end
            end

            if IsControlJustPressed(0, 18) or IsControlJustPressed(0, 201) then
                if #RecordedWaypoints < 2 then
                    Bridge.Client.Notify('Please record at least 2 waypoints before saving!', 'error')
                else
                    IsRecordingPath = false
                    lib.hideTextUI()

                    local pointsToSave = {}
                    for _, pt in ipairs(RecordedWaypoints) do
                        pointsToSave[#pointsToSave + 1] = { x = pt.x, y = pt.y, z = pt.z }
                    end

                    local res = lib.callback.await('LNS_Housing:server:saveRobotPath', false, propertyId, isApartment, pointsToSave)
                    if res and res.success then
                        Bridge.Client.Notify(('Cleaning path saved with %d waypoints!'):format(res.count), 'success')
                    else
                        Bridge.Client.Notify((res and res.message) or 'Failed to save cleaning path.', 'error')
                    end
                    break
                end
            end

            if IsControlJustPressed(0, 200) or IsControlJustPressed(0, 322) then
                IsRecordingPath = false
                lib.hideTextUI()
                Bridge.Client.Notify('Path recording cancelled.', 'inform')
                break
            end

            DrawMarker(1, pos.x, pos.y, pos.z - 0.98, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.5, 0.1, 0, 220, 255, 150, false, false, 2, nil, nil, false)

            if #RecordedWaypoints > 0 then
                DrawLine(frontOfDock.x, frontOfDock.y, frontOfDock.z + 0.05, RecordedWaypoints[1].x, RecordedWaypoints[1].y, RecordedWaypoints[1].z + 0.05, 0, 255, 180, 200)
            end

            for idx = 1, #RecordedWaypoints do
                local pt = RecordedWaypoints[idx]
                DrawMarker(28, pt.x, pt.y, pt.z + 0.05, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.2, 0.2, 0.2, 0, 220, 255, 200, false, false, 2, nil, nil, false)
                if idx < #RecordedWaypoints then
                    local nextPt = RecordedWaypoints[idx + 1]
                    DrawLine(pt.x, pt.y, pt.z + 0.05, nextPt.x, nextPt.y, nextPt.z + 0.05, 0, 220, 255, 200)
                end
            end

            Wait(0)
        end

        lib.hideTextUI()
    end)
end

function PreviewRobotPath(customPath)
    if not customPath or #customPath < 2 then return end
    if IsPreviewingPath then return end
    IsPreviewingPath = true

    Bridge.Client.Notify('Showing saved cleaning route for 15 seconds (Press [ESC] to hide)...', 'inform')
    lib.showTextUI('[ESC] Hide Cleaning Route Preview', { position = 'top-center' })

    CreateThread(function()
        local endTimer = GetGameTimer() + 15000
        while IsPreviewingPath and GetGameTimer() < endTimer do
            if IsControlJustPressed(0, 200) or IsControlJustPressed(0, 322) then
                break
            end

            for idx = 1, #customPath do
                local pt = customPath[idx]
                DrawMarker(28, pt.x, pt.y, pt.z + 0.05, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.22, 0.22, 0.22, 0, 255, 200, 220, false, false, 2, nil, nil, false)
                if idx < #customPath then
                    local nextPt = customPath[idx + 1]
                    DrawLine(pt.x, pt.y, pt.z + 0.05, nextPt.x, nextPt.y, nextPt.z + 0.05, 0, 255, 200, 220)
                end
            end
            Wait(0)
        end
        IsPreviewingPath = false
        lib.hideTextUI()
    end)
end

local function MoveRobotToCoord(robotObj, targetCoord, speed, stopDist, cancelRef)
    stopDist = stopDist or 0.25
    speed = speed or 1.1
    local turnSpeed = 180.0
    local robotHeadingOffset = (Settings.Trash and Settings.Trash.Robot and Settings.Trash.Robot.RobotHeadingOffset) or 0.0

    if not DoesEntityExist(robotObj) then return end
    local curPos = GetEntityCoords(robotObj)
    local curHeading = GetEntityHeading(robotObj)
    local targetZ = targetCoord.z or curPos.z
    local lastTick = GetGameTimer()

    while DoesEntityExist(robotObj) and (not cancelRef or not cancelRef.cancelRequested) do
        local dx = targetCoord.x - curPos.x
        local dy = targetCoord.y - curPos.y
        local dist2D = math.sqrt(dx * dx + dy * dy)

        if dist2D <= stopDist then
            break
        end

        local now = GetGameTimer()
        local dt = (now - lastTick) / 1000.0
        lastTick = now
        if dt <= 0.0 or dt > 0.08 then dt = 0.016 end

        local baseAngle = (math.deg(math.atan2(-dx, dy)) + 360.0) % 360.0
        local targetHeading = (baseAngle + robotHeadingOffset) % 360.0
        local diff = (targetHeading - curHeading + 180.0) % 360.0 - 180.0
        local maxTurn = turnSpeed * dt
        local turn = math.max(-maxTurn, math.min(maxTurn, diff))
        curHeading = (curHeading + turn) % 360.0
        SetEntityHeading(robotObj, curHeading)

        if math.abs(diff) < 70.0 then
            local step = math.min(dist2D, speed * dt)
            local dirX = dx / dist2D
            local dirY = dy / dist2D

            local zDiff = targetZ - curPos.z
            local newZ = targetZ
            if math.abs(zDiff) > 0.02 then
                local zStep = math.max(-speed * dt, math.min(speed * dt, zDiff))
                newZ = curPos.z + zStep
            end

            curPos = vec3(curPos.x + dirX * step, curPos.y + dirY * step, newZ)
            SetEntityCoords(robotObj, curPos.x, curPos.y, curPos.z, false, false, false, false)
        end

        Wait(10)
    end
end

local function CleanSingleTrashPile(robotObj, propertyId, isApartment, idx, pileObj, cancelRef)
    if not DoesEntityExist(pileObj) then return end
    local pPos = GetEntityCoords(pileObj)
    MoveRobotToCoord(robotObj, pPos, 0.7, 0.25, cancelRef)
    if cancelRef and cancelRef.cancelRequested then return end

    local baseHeading = GetEntityHeading(robotObj)
    local cleanDuration = (Settings.Trash and Settings.Trash.Robot and Settings.Trash.Robot.CleanDuration) or 2500
    local endTime = GetGameTimer() + cleanDuration
    while GetGameTimer() < endTime and DoesEntityExist(robotObj) and (not cancelRef or not cancelRef.cancelRequested) do
        local wiggle = math.sin((GetGameTimer() / 150.0)) * 20.0
        SetEntityHeading(robotObj, (baseHeading + wiggle) % 360.0)
        Wait(50)
    end
    if DoesEntityExist(robotObj) then
        SetEntityHeading(robotObj, baseHeading)
    end

    TriggerServerEvent('LNS_Housing:server:robotCleanPile', propertyId, idx, isApartment)
    Wait(250)
end

local function CheckAndCleanNearbyTrash(robotObj, propertyId, isApartment, cleanDist, cancelRef)
    cleanDist = cleanDist or 1.4
    if not SpawnedTrashProps[propertyId] then return false end
    local rPos = GetEntityCoords(robotObj)

    for idx, pileObj in pairs(SpawnedTrashProps[propertyId]) do
        if DoesEntityExist(pileObj) then
            local pPos = GetEntityCoords(pileObj)
            local dist = #(vec2(rPos.x, rPos.y) - vec2(pPos.x, pPos.y))
            if dist <= cleanDist then
                CleanSingleTrashPile(robotObj, propertyId, isApartment, idx, pileObj, cancelRef)
                return true
            end
        end
    end
    return false
end

function StartRobotCleanSimulation(propertyId, isApartment, dockFurnitureId)
    local key = (isApartment and 'apartment_' or 'house_') .. tostring(propertyId)
    if ActiveCleaningRobots[key] and ActiveCleaningRobots[key].isRunning then
        return
    end

    local dockObj = (LoadedFurniture[propertyId] and LoadedFurniture[propertyId][dockFurnitureId])
        or (RegisteredDocks[key] and RegisteredDocks[key][tostring(dockFurnitureId)] and RegisteredDocks[key][tostring(dockFurnitureId)].entity)

    if not dockObj or not DoesEntityExist(dockObj) then
        if RegisteredDocks[key] then
            for fId, dData in pairs(RegisteredDocks[key]) do
                if dData.entity and DoesEntityExist(dData.entity) then
                    dockObj = dData.entity
                    dockFurnitureId = fId
                    break
                end
            end
        end
    end

    if not dockObj or not DoesEntityExist(dockObj) then
        debugPrint('warn', '[LNS_Housing:Trash] Cannot start clean simulation: dock entity not found.')
        return
    end

    local dockModel = GetEntityModel(dockObj)
    local dockCfg = DockModels[dockModel] or DockModels[joaat('mula_prop_cleandock_small_occupied')]
    local dockCoords = GetEntityCoords(dockObj)
    local dockRot = GetEntityRotation(dockObj, 2)
    local dockHeading = dockRot.z
    local dockOffset = dockCfg.forwardOffset or 0.70
    local dockHeadingOffset = (Settings.Trash and Settings.Trash.Robot and Settings.Trash.Robot.DockHeadingOffset) or 180.0
    local localY = (dockHeadingOffset == 180.0) and -dockOffset or dockOffset
    local frontOfDock = GetOffsetFromEntityInWorldCoords(dockObj, 0.0, localY, 0.0)

    local foundGround, groundZ = GetGroundZFor_3dCoord(frontOfDock.x, frontOfDock.y, frontOfDock.z + 0.35, false)
    if foundGround and math.abs(groundZ - dockCoords.z) < 0.65 then
        frontOfDock = vec3(frontOfDock.x, frontOfDock.y, groundZ + 0.02)
    end

    local outDir = vec3(frontOfDock.x - dockCoords.x, frontOfDock.y - dockCoords.y, 0.0)
    local outDist = math.sqrt(outDir.x * outDir.x + outDir.y * outDir.y)
    local outHeading = (dockHeading + 180.0) % 360.0
    if outDist > 0.05 then
        outHeading = (math.deg(math.atan2(-outDir.x, outDir.y)) + 360.0) % 360.0
    end

    local targetPrefix = 'lns_dock_' .. tostring(dockFurnitureId)
    exports.ox_target:removeLocalEntity(dockObj, {
        targetPrefix .. '_clean',
        targetPrefix .. '_stop',
        targetPrefix .. '_timer',
        targetPrefix .. '_path'
    })
    DeleteEntity(dockObj)

    local emptyHash = EnsureModelLoaded(dockCfg.empty)
    local emptyDockObj = CreateObjectNoOffset(emptyHash, dockCoords.x, dockCoords.y, dockCoords.z, false, false, false)
    SetEntityRotation(emptyDockObj, dockRot.x, dockRot.y, dockRot.z, 2, true)
    FreezeEntityPosition(emptyDockObj, true)
    if LoadedFurniture[propertyId] then
        LoadedFurniture[propertyId][dockFurnitureId] = emptyDockObj
    end

    exports.ox_target:addLocalEntity(emptyDockObj, {
        {
            name = targetPrefix .. '_stop',
            icon = 'fas fa-circle-stop',
            label = 'Recall to Dock',
            distance = 2.0,
            onSelect = function()
                StopRobotCleaning(propertyId, isApartment)
            end
        }
    })

    local robotHash = EnsureModelLoaded(dockCfg.robot)
    local robotObj = CreateObjectNoOffset(robotHash, dockCoords.x, dockCoords.y, dockCoords.z, false, false, false)
    SetEntityRotation(robotObj, dockRot.x, dockRot.y, dockRot.z, 2, true)
    SetEntityHeading(robotObj, outHeading)
    SetEntityCollision(robotObj, false, false)

    local robotTargetName = 'lns_robot_ent_' .. tostring(dockFurnitureId)
    exports.ox_target:addLocalEntity(robotObj, {
        {
            name = robotTargetName,
            icon = 'fas fa-house-chimney',
            label = 'Recall to Dock',
            distance = 2.0,
            onSelect = function()
                StopRobotCleaning(propertyId, isApartment)
            end
        }
    })

    local cancelRef = { cancelRequested = false }
    ActiveCleaningRobots[key] = {
        propertyId = propertyId,
        isApartment = isApartment,
        furnitureId = dockFurnitureId,
        dockCoords = dockCoords,
        dockRot = dockRot,
        dockCfg = dockCfg,
        robotObj = robotObj,
        emptyDockObj = emptyDockObj,
        isRunning = true,
        cancelRef = cancelRef
    }

    Bridge.Client.Notify('Cleaning robot deployed! Starting cleaning cycle...', 'inform')

    CreateThread(function()
        local moveSpeed = (Settings.Trash and Settings.Trash.Robot and Settings.Trash.Robot.Speed) or 1.0

        local undockDuration = 1000
        local undockStart = GetGameTimer()
        while (GetGameTimer() - undockStart < undockDuration) and DoesEntityExist(robotObj) and (not cancelRef.cancelRequested) do
            local progress = (GetGameTimer() - undockStart) / undockDuration
            if progress > 1.0 then progress = 1.0 end
            local curX = dockCoords.x + (frontOfDock.x - dockCoords.x) * progress
            local curY = dockCoords.y + (frontOfDock.y - dockCoords.y) * progress
            local curZ = dockCoords.z + (frontOfDock.z - dockCoords.z) * progress
            SetEntityCoords(robotObj, curX, curY, curZ, false, false, false, false)
            SetEntityHeading(robotObj, outHeading)
            Wait(12)
        end
        if DoesEntityExist(robotObj) then
            SetEntityCoords(robotObj, frontOfDock.x, frontOfDock.y, frontOfDock.z, false, false, false, false)
            SetEntityHeading(robotObj, outHeading)
        end

        local data = lib.callback.await('LNS_Housing:server:getRobotData', false, propertyId, isApartment)
        local route = {}

        if data and data.customPath and #data.customPath >= 2 then
            for _, pt in ipairs(data.customPath) do
                route[#route + 1] = vec3(pt.x, pt.y, pt.z)
            end
        else
            if SpawnedTrashProps[propertyId] then
                for idx, pileObj in pairs(SpawnedTrashProps[propertyId]) do
                    if DoesEntityExist(pileObj) then
                        route[#route + 1] = GetEntityCoords(pileObj)
                    end
                end
            end
            if #route == 0 then
                local outDir = vec3(frontOfDock.x - dockCoords.x, frontOfDock.y - dockCoords.y, 0.0)
                local outLen = math.sqrt(outDir.x * outDir.x + outDir.y * outDir.y)
                if outLen > 0.05 then
                    outDir = outDir / outLen
                else
                    local rad = math.rad(dockHeading)
                    outDir = vec3(-math.sin(rad), math.cos(rad), 0.0)
                end
                route[#route + 1] = frontOfDock + outDir * 1.5
                route[#route + 1] = frontOfDock + outDir * 0.5
            end
        end

        for _, wp in ipairs(route) do
            if cancelRef.cancelRequested then break end
            MoveRobotToCoord(robotObj, wp, moveSpeed, 0.3, cancelRef)
            CheckAndCleanNearbyTrash(robotObj, propertyId, isApartment, 1.4, cancelRef)
        end

        if not cancelRef.cancelRequested and SpawnedTrashProps[propertyId] then
            for idx, pileObj in pairs(SpawnedTrashProps[propertyId]) do
                if DoesEntityExist(pileObj) and not cancelRef.cancelRequested then
                    CleanSingleTrashPile(robotObj, propertyId, isApartment, idx, pileObj, cancelRef)
                end
            end
        end

        if DoesEntityExist(robotObj) then
            MoveRobotToCoord(robotObj, frontOfDock, moveSpeed, 0.18)
        end

        local alignStart = GetGameTimer()
        local alignMaxDuration = 1000
        local curH = DoesEntityExist(robotObj) and GetEntityHeading(robotObj) or outHeading
        local lastHTime = GetGameTimer()
        while (GetGameTimer() - alignStart < alignMaxDuration) and DoesEntityExist(robotObj) do
            local diff = (outHeading - curH + 180.0) % 360.0 - 180.0
            if math.abs(diff) < 1.0 then
                SetEntityHeading(robotObj, outHeading)
                break
            end
            local hNow = GetGameTimer()
            local dt = (hNow - lastHTime) / 1000.0
            lastHTime = hNow
            if dt <= 0.0 or dt > 0.08 then dt = 0.016 end
            local maxTurn = 180.0 * dt
            local turn = math.max(-maxTurn, math.min(maxTurn, diff))
            curH = (curH + turn) % 360.0
            SetEntityHeading(robotObj, curH)
            Wait(12)
        end
        if DoesEntityExist(robotObj) then
            SetEntityHeading(robotObj, outHeading)
        end

        local dockDuration = 1200
        local dockStart = GetGameTimer()
        local rPos = DoesEntityExist(robotObj) and GetEntityCoords(robotObj) or frontOfDock
        while (GetGameTimer() - dockStart < dockDuration) and DoesEntityExist(robotObj) do
            local progress = (GetGameTimer() - dockStart) / dockDuration
            if progress > 1.0 then progress = 1.0 end
            local curX = rPos.x + (dockCoords.x - rPos.x) * progress
            local curY = rPos.y + (dockCoords.y - rPos.y) * progress
            local curZ = rPos.z + (dockCoords.z - rPos.z) * progress
            SetEntityCoords(robotObj, curX, curY, curZ, false, false, false, false)
            SetEntityHeading(robotObj, outHeading)
            Wait(12)
        end

        if DoesEntityExist(robotObj) then
            exports.ox_target:removeLocalEntity(robotObj, robotTargetName)
            DeleteEntity(robotObj)
        end

        if DoesEntityExist(emptyDockObj) then
            exports.ox_target:removeLocalEntity(emptyDockObj, targetPrefix .. '_stop')
            DeleteEntity(emptyDockObj)
        end

        if not ActiveCleaningRobots[key] and not LoadedFurniture[propertyId] then
            return
        end

        local occHash = EnsureModelLoaded(dockCfg.occupied)
        local occupiedDockObj = CreateObjectNoOffset(occHash, dockCoords.x, dockCoords.y, dockCoords.z, false, false, false)
        SetEntityRotation(occupiedDockObj, dockRot.x, dockRot.y, dockRot.z, 2, true)
        FreezeEntityPosition(occupiedDockObj, true)
        if LoadedFurniture[propertyId] then
            LoadedFurniture[propertyId][dockFurnitureId] = occupiedDockObj
        end

        SetupCleanRobotDockTarget(propertyId, dockFurnitureId, occupiedDockObj, {
            model = dockCfg.occupied,
            position = dockCoords,
            rotation = dockRot
        }, nil, isApartment)

        ActiveCleaningRobots[key] = nil
        TriggerServerEvent('LNS_Housing:server:finishRobotClean', propertyId, isApartment)

        Bridge.Client.Notify('Cleaning robot has docked and completed its cleaning cycle.', 'success')
    end)
end

function OnUnloadPropertyRobot(propertyId, isApartment)
    local key = (isApartment and 'apartment_' or 'house_') .. tostring(propertyId)
    local robotData = ActiveCleaningRobots[key]
    if robotData then
        if robotData.cancelRef then
            robotData.cancelRef.cancelRequested = true
        end
        if robotData.robotObj and DoesEntityExist(robotData.robotObj) then
            exports.ox_target:removeLocalEntity(robotData.robotObj, 'lns_robot_ent_' .. tostring(robotData.furnitureId))
            DeleteEntity(robotData.robotObj)
        end
        if robotData.emptyDockObj and DoesEntityExist(robotData.emptyDockObj) then
            DeleteEntity(robotData.emptyDockObj)
        end
        ActiveCleaningRobots[key] = nil
    end

    if IsRecordingPath then
        IsRecordingPath = false
        lib.hideTextUI()
    end
    if IsPreviewingPath then
        IsPreviewingPath = false
        lib.hideTextUI()
    end
end

RegisterNetEvent('LNS_Housing:client:startRobotClean', function(propertyId, isApartment, dockFurnitureId)
    StartRobotCleanSimulation(propertyId, isApartment, dockFurnitureId)
end)

exports('IsRobotCleaning', IsRobotCleaning)
exports('StartRobotClean', StartRobotCleanSimulation)
exports('StopRobotClean', StopRobotCleaning)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    if CarriedBagEntity and DoesEntityExist(CarriedBagEntity) then
        DeleteEntity(CarriedBagEntity)
    end
    for bagId, _ in pairs(SpawnedDroppedBags) do
        RemoveDroppedBagObject(bagId)
    end
    for propId, piles in pairs(SpawnedTrashProps) do
        for idx, obj in pairs(piles) do
            if DoesEntityExist(obj) then
                DeleteEntity(obj)
            end
        end
    end
    for key, robotData in pairs(ActiveCleaningRobots) do
        if robotData.robotObj and DoesEntityExist(robotData.robotObj) then
            exports.ox_target:removeLocalEntity(robotData.robotObj, 'lns_robot_ent_' .. tostring(robotData.furnitureId))
            DeleteEntity(robotData.robotObj)
        end
        if robotData.emptyDockObj and DoesEntityExist(robotData.emptyDockObj) then
            DeleteEntity(robotData.emptyDockObj)
        end
    end
    if IsRecordingPath or IsPreviewingPath then
        lib.hideTextUI()
    end
    StopFliesEffect()
end)