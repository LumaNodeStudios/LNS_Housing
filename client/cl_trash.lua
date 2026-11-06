local Settings = lib.load('shared.settings')
SpawnedTrashProps = SpawnedTrashProps or {}
CurrentPropertyTrash = nil
IsCarryingTrash = false
CarriedBagEntity = nil
CurrentCarriedTrash = nil
local isCleaningTrash = false
local isThrowingTrash = false
local FliesParticleHandle = nil
local isRefreshingTrash = false
local CachedTrashCoords = {}

--------------------------------------------------------------------------------
-- 2D Polygon Geometry & Physical MLO Wall Clearance Utilities
--------------------------------------------------------------------------------

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
        17, -- 1 (world) | 16 (objects/MLO walls)
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

-- Checks physical collision distance to MLO walls, doors, and static architecture
local function getWallDistanceInDir(origin, dir2D, maxDist)
    maxDist = maxDist or 6.0
    local startZ = origin.z + 0.45
    local targetX = origin.x + dir2D.x * maxDist
    local targetY = origin.y + dir2D.y * maxDist
    local ray = StartExpensiveSynchronousShapeTestLosProbe(
        origin.x, origin.y, startZ,
        targetX, targetY, startZ,
        17, -- 1 (world map) | 16 (objects/MLO interior walls)
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

-- Verifies that pos has at least minClearance meters of clearance to any MLO wall in 12 radial directions
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
            17, -- 1 (world map) | 16 (objects/MLO interior walls)
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
        -- Native interior check near portal boundaries can return 0, do not falsely reject
        return true
    end
    return intAt == expectedInteriorId
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

--------------------------------------------------------------------------------
-- Coordinates Calculation: Room-Wide Spread with Direct MinWallMargin Enforcement
--------------------------------------------------------------------------------

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

        local floorZ = (spawnCoords and spawnCoords.z)
            or (interiorCoords and interiorCoords.z)
            or (room and room.corners and #room.corners >= 1 and (room.corners[1].z + (room.zOffset or 0.0)))
            or (doorCoords and doorCoords.z)
            or GetEntityCoords(cache.ped).z

        -- ========================================================
        -- 1. APARTMENT WITH POLY ZONE
        -- ========================================================
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

                        -- Raymarch outward to find furthest point inside poly with margin
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
                    coords[#coords + 1] = vec3(acceptedPos.x, acceptedPos.y, floorZ + 0.03)
                end
            end

            return coords

        -- ========================================================
        -- 2. APARTMENT WITH INTERIOR DETECTION (NO POLY ZONE)
        -- ========================================================
        else
            -- 1. Calculate inward unit vector pointing strictly away from doorway
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

            -- 2. Determine safeCenter inside the room, well away from the door
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

            -- Ensure safeCenter is at least minDoorDist + 0.6 away from the entrance door
            if doorCoords then
                local distFromDoor = #(vec2(safeCenter.x, safeCenter.y) - vec2(doorCoords.x, doorCoords.y))
                local targetMinDist = minDoorDist + 0.6
                if distFromDoor < targetMinDist then
                    local pushDist = targetMinDist - distFromDoor
                    safeCenter = vec3(safeCenter.x + dirIn.x * pushDist, safeCenter.y + dirIn.y * pushDist, floorZ)
                end
            end

            -- If interior center is available and nearby, bias slightly towards it
            if interiorCenter and #(interiorCenter - safeCenter) < 7.0 then
                if not isDoorTooClose(interiorCenter, doorCoords, minDoorDist + 0.5) then
                    safeCenter = (safeCenter * 0.7) + (interiorCenter * 0.3)
                end
            end

            local baseAngle0 = math.atan2(dirIn.y, dirIn.x)

            -- Generate distinct sector angles across the forward 170-degree arc inside the room
            local sectors = {}
            for s = 1, maxPiles do
                local frac = (maxPiles > 1) and ((s - 1) / (maxPiles - 1)) or 0.5
                local ang = baseAngle0 + (-1.4 + frac * 2.8) -- arc from -80 deg to +80 deg
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

                        -- Probe distance to actual MLO wall in this direction
                        local wallDist = getWallDistanceInDir(safeCenter, dir, 6.0)

                        -- Setback directly using minWallMargin from the detected MLO wall
                        local maxR = math.max(0.4, wallDist - minWallMargin)
                        local depthFractions = { 1.0, 0.8, 0.6, 0.4 }

                        for _, df in ipairs(depthFractions) do
                            local r = math.max(0.4, maxR * df)
                            local testPos = vec3(safeCenter.x + dir.x * r, safeCenter.y + dir.y * r, floorZ)

                            local valid = not isDoorTooClose(testPos, doorCoords, minDoorDist)
                                and isInteriorValid(testPos, expectedInteriorId)
                                and isLineOfSightClear(safeCenter, testPos)
                                and isPointClearOfWalls(testPos, math.min(minWallMargin * 0.85, 0.95))

                            -- Guard against backwards direction towards doorway
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

                -- Safe room-center search fallback if corners were tight, strictly maintaining >= 0.85m spread and wall clearance
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
                    coords[#coords + 1] = vec3(acceptedPos.x, acceptedPos.y, floorZ + 0.03)
                end
            end

            return coords
        end
    end

    -- ========================================================
    -- 3. HOUSES / PROPERTIES
    -- ========================================================
    local p = getRoomOrPropertyData(propertyId, false)
    if not p then return coords end

    if p.zone_data and p.zone_data.points and #p.zone_data.points >= 3 then
        local corners = p.zone_data.points
        local doorCoords = GetEntranceCoords and GetEntranceCoords(p)
        local floorZ = corners[1].z
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
                coords[#coords + 1] = vec3(acceptedPos.x, acceptedPos.y, floorZ + 0.03)
            end
        end
        return coords
    end

    local shellName = p.metadata and p.metadata.shell
    local shellData = (shellName and Settings.Shells and Settings.Shells[shellName]) or (shellName and Settings.IPLs and Settings.IPLs[shellName])

    local shellOrigin = nil
    if SpawnedShells and SpawnedShells[propertyId] and DoesEntityExist(SpawnedShells[propertyId]) then
        shellOrigin = GetEntityCoords(SpawnedShells[propertyId])
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
            local off = configuredOffsets[i] or configuredOffsets[1]
            coords[i] = shellOrigin + off
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
        coords[i] = shellOrigin + off
    end

    return coords
end

--------------------------------------------------------------------------------
-- Lifecycle & Dynamic Refresh
--------------------------------------------------------------------------------

local function StopFliesEffect()
    if FliesParticleHandle then
        StopParticleFxLooped(FliesParticleHandle, false)
        FliesParticleHandle = nil
    end
end

function UnloadPropertyTrash(propertyId)
    propertyId = propertyId or (CurrentPropertyTrash and CurrentPropertyTrash.propertyId)
    if not propertyId then return end

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

    local trashData = lib.callback.await('LNS_Housing:server:getPropertyTrash', false, propertyId, isApartment)

    if not CurrentPropertyTrash or (tostring(CurrentPropertyTrash.propertyId) ~= tostring(propertyId)) then
        isRefreshingTrash = false
        return
    end

    if not trashData or not trashData.activePiles then
        isRefreshingTrash = false
        return
    end

    local maxTrash = (Settings.Trash and Settings.Trash.MaxTrash) or 5
    local pileCoords = CachedTrashCoords[propertyId]
    if not pileCoords or #pileCoords < maxTrash then
        pileCoords = GetTrashCoordinates(propertyId, isApartment, maxTrash)
        CachedTrashCoords[propertyId] = pileCoords
    end

    SpawnedTrashProps[propertyId] = SpawnedTrashProps[propertyId] or {}

    local modelsList = Settings.Trash.TrashModels or { 'prop_rub_litter_01', 'prop_rub_box_02', 'prop_rub_binbag_01' }
    local firstActiveCoords = nil

    local room = isApartment and getRoomOrPropertyData(propertyId, true)
    local doorCoords = room and room.doorCoords and vec3(room.doorCoords.x, room.doorCoords.y, room.doorCoords.z)
    local corners = room and room.corners
    local expectedInteriorId = room and tonumber(room.interior_id or room.interiorId)
    if (not expectedInteriorId or expectedInteriorId == 0) and room and room.spawn then
        expectedInteriorId = GetInteriorAtCoords(room.spawn.x, room.spawn.y, room.spawn.z + 1.0)
    end
    if (not expectedInteriorId or expectedInteriorId == 0) then
        expectedInteriorId = GetInteriorFromEntity(cache.ped)
    end

    local floorZ = (room and room.spawn and room.spawn.z)
        or (room and room.interior_coords and room.interior_coords.z)
        or (corners and #corners >= 1 and (corners[1].z + (room.zOffset or 0.0)))
        or GetEntityCoords(cache.ped).z

    local minDoorDist = (Settings.Trash and Settings.Trash.MinDoorDistance) or 2.0
    local minWallMargin = (Settings.Trash and Settings.Trash.MinWallMargin) or 1.0

    for idx = 1, maxTrash do
        local shouldBeActive = trashData.activePiles[idx] == true
        local existingObj = SpawnedTrashProps[propertyId][idx]

        if shouldBeActive then
            if not existingObj or not DoesEntityExist(existingObj) then
                local pos = pileCoords[idx]
                if pos then
                    -- Strict check: ensure this pile coordinate does not overlap any currently spawned prop
                    local overlapsSpawned = false
                    for _, otherObj in pairs(SpawnedTrashProps[propertyId]) do
                        if DoesEntityExist(otherObj) then
                            local oc = GetEntityCoords(otherObj)
                            if #(vec2(pos.x, pos.y) - vec2(oc.x, oc.y)) < 0.85 then
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
                        local obj = CreateObjectNoOffset(modelHash, pos.x, pos.y, pos.z, false, false, false)
                        if DoesEntityExist(obj) then
                            SetEntityRotation(obj, 0.0, 0.0, (idx * 73.0) % 360.0, 2, true)
                            FreezeEntityPosition(obj, true)
                            PlaceObjectOnGroundProperly(obj)

                            local actualCoords = GetEntityCoords(obj)
                            local isPosValid = true

                            if doorCoords and #(vec2(actualCoords.x, actualCoords.y) - vec2(doorCoords.x, doorCoords.y)) < (minDoorDist * 0.75) then
                                isPosValid = false
                            end

                            if isPosValid and corners and #corners >= 3 then
                                if not isPointInPoly2D(actualCoords.x, actualCoords.y, corners) then
                                    isPosValid = false
                                elseif getDistanceToPolyBoundary(actualCoords.x, actualCoords.y, corners) < (minWallMargin * 0.75) then
                                    isPosValid = false
                                end
                            end

                            if isPosValid and not isPointClearOfWalls(actualCoords, math.min(minWallMargin * 0.65, 0.65)) then
                                isPosValid = false
                            end

                            if isPosValid and expectedInteriorId and expectedInteriorId ~= 0 then
                                local entInt = GetInteriorAtCoords(actualCoords.x, actualCoords.y, actualCoords.z + 1.0)
                                if entInt ~= 0 and entInt ~= expectedInteriorId then
                                    isPosValid = false
                                end
                            end

                            if isPosValid and math.abs(actualCoords.z - floorZ) > 2.0 then
                                isPosValid = false
                            end

                            if not isPosValid then
                                DeleteEntity(obj)
                                obj = nil
                            else
                                firstActiveCoords = firstActiveCoords or actualCoords

                                exports.ox_target:addLocalEntity(obj, {
                                    {
                                        name = 'lns_trash_pickup_' .. idx,
                                        icon = 'fas fa-broom',
                                        label = 'Clean Up Trash',
                                        distance = 2.0,
                                        canInteract = function()
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
                end
            else
                firstActiveCoords = firstActiveCoords or GetEntityCoords(existingObj)
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
end

-- Periodic background ticker to detect trash buildup dynamically while inside
CreateThread(function()
    while true do
        Wait(5000)
        if CurrentPropertyTrash and CurrentPropertyTrash.propertyId and Settings.Trash and Settings.Trash.Enabled ~= false then
            RefreshPropertyTrash(CurrentPropertyTrash.propertyId, CurrentPropertyTrash.isApartment)
        end
    end
end)

--------------------------------------------------------------------------------
-- Trash Cleaning, Carrying, and Disposal
--------------------------------------------------------------------------------

function CleanTrashPile(propertyId, index, isApartment)
    if IsCarryingTrash then
        Bridge.Client.Notify('You are already carrying a bag of trash! Dispose of it in a dumpster first.', 'error')
        return
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
            Bridge.Client.Notify('You picked up a bag of trash. Take it outside to a street dumpster!', 'inform')
        else
            Bridge.Client.Notify(res and res.message or 'Failed to pick up trash.', 'error')
        end
    else
        Bridge.Client.Notify('Cleaning cancelled.', 'inform')
    end
end

function AttachCarriedTrashBag(propertyId, isApartment)
    if CarriedBagEntity and DoesEntityExist(CarriedBagEntity) then
        DeleteEntity(CarriedBagEntity)
        CarriedBagEntity = nil
    end

    local ped = cache.ped or PlayerPedId()
    local carryConfig = Settings.Trash and Settings.Trash.CarryProp or {}
    local propModel = joaat(carryConfig.model or 'prop_cs_street_binbag_01')

    lib.requestModel(propModel)
    local bagObj = CreateObject(propModel, 0.0, 0.0, 0.0, true, true, false)
    SetEntityCollision(bagObj, false, false)

    local boneIdx = GetPedBoneIndex(ped, carryConfig.bone or 57005)
    local off = carryConfig.offset or vec3(0.12, 0.0, 0.0)
    local rot = carryConfig.rotation or vec3(-80.0, 0.0, 0.0)

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

    CreateThread(function()
        lib.requestAnimDict('anim@heists@narcotics@trash')
        while IsCarryingTrash do
            local currentPed = cache.ped or PlayerPedId()

            if IsEntityDead(currentPed) then
                DropTrashBag(false)
                break
            end

            if not IsEntityPlayingAnim(currentPed, 'anim@heists@narcotics@trash', 'idle', 3) then
                TaskPlayAnim(currentPed, 'anim@heists@narcotics@trash', 'idle', 8.0, 8.0, -1, 49, 0, false, false, false)
            end

            Wait(250)
        end
    end)
end

function DropTrashBag(notify)
    if not IsCarryingTrash then return end

    local ped = cache.ped or PlayerPedId()

    if CarriedBagEntity and DoesEntityExist(CarriedBagEntity) then
        DetachEntity(CarriedBagEntity, true, true)
        DeleteEntity(CarriedBagEntity)
        CarriedBagEntity = nil
    end

    ClearPedTasks(ped)
    IsCarryingTrash = false
    CurrentCarriedTrash = nil

    TriggerServerEvent('LNS_Housing:server:dropTrash')

    if notify ~= false then
        Bridge.Client.Notify('You dropped the trash bag.', 'inform')
    end
end

function ThrowTrashInDumpster(dumpsterEntity)
    if not IsCarryingTrash then
        Bridge.Client.Notify('You are not carrying any trash to throw away!', 'error')
        return
    end

    if isThrowingTrash then return end
    isThrowingTrash = true

    local ped = cache.ped or PlayerPedId()
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
        if CarriedBagEntity and DoesEntityExist(CarriedBagEntity) then
            DetachEntity(CarriedBagEntity, true, true)
            DeleteEntity(CarriedBagEntity)
            CarriedBagEntity = nil
        end

        ClearPedTasks(ped)
        IsCarryingTrash = false

        local propId = CurrentCarriedTrash and CurrentCarriedTrash.propertyId
        local isApt = CurrentCarriedTrash and CurrentCarriedTrash.isApartment
        CurrentCarriedTrash = nil

        TriggerServerEvent('LNS_Housing:server:disposeTrash', propId, isApt)
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
                return IsCarryingTrash == true and not isThrowingTrash
            end,
            onSelect = function(data)
                ThrowTrashInDumpster(data.entity)
            end
        }
    })
    debugPrint('info', ('[LNS_Housing:Trash] Registered %d street dumpster models with ox_target.'):format(#Settings.Trash.DumpsterModels))
end

CreateThread(function()
    RegisterDumpsterModels()
end)

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
    if CurrentPropertyTrash and (CurrentPropertyTrash.propertyId == propertyId or tostring(CurrentPropertyTrash.propertyId) == tostring(propertyId)) and CurrentPropertyTrash.isApartment == (isApartment and true or false) then
        RefreshPropertyTrash(propertyId, isApartment)
    end
end)

RegisterCommand('droptrash', function()
    if IsCarryingTrash then
        DropTrashBag(true)
    else
        Bridge.Client.Notify('You are not carrying any trash bag.', 'inform')
    end
end, false)

exports('LoadPropertyTrash', LoadPropertyTrash)
exports('UnloadPropertyTrash', UnloadPropertyTrash)
exports('RefreshPropertyTrash', RefreshPropertyTrash)
exports('IsCarryingTrash', function() return IsCarryingTrash end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    if CarriedBagEntity and DoesEntityExist(CarriedBagEntity) then
        DeleteEntity(CarriedBagEntity)
    end
    for propId, piles in pairs(SpawnedTrashProps) do
        for idx, obj in pairs(piles) do
            if DoesEntityExist(obj) then
                DeleteEntity(obj)
            end
        end
    end
    StopFliesEffect()
end)
