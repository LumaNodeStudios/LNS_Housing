local Settings = lib.load('shared.settings')
SpawnedTrashProps = SpawnedTrashProps or {}
CurrentPropertyTrash = nil
IsCarryingTrash = false
CarriedBagEntity = nil
CurrentCarriedTrash = nil
local isCleaningTrash = false
local isThrowingTrash = false
local FliesParticleHandle = nil

function GetTrashCoordinates(propertyId, isApartment, maxPiles)
    maxPiles = maxPiles or (Settings.Trash and Settings.Trash.MaxTrash) or 5
    local coords = {}

    if isApartment then
        local room = nil
        for _, r in ipairs(Settings.Rooms or {}) do
            if r.id == propertyId or tostring(r.id) == tostring(propertyId) or tonumber(r.id) == tonumber(propertyId) then
                room = r
                break
            end
        end

        if room and room.corners and #room.corners >= 3 then
            local cx, cy, cz = 0.0, 0.0, 0.0
            local count = #room.corners
            for _, c in ipairs(room.corners) do
                cx = cx + c.x
                cy = cy + c.y
                cz = cz + c.z
            end
            local zOff = room.zOffset or 0.0
            local floorZ = room.corners[1].z + zOff
            local center = vec3(cx / count, cy / count, floorZ)

            for i = 1, maxPiles do
                local targetCorner = room.corners[((i - 1) % count) + 1]
                local cornerPos = vec3(targetCorner.x, targetCorner.y, floorZ)
                local pos = center + (cornerPos - center) * 0.45
                coords[i] = vec3(pos.x, pos.y, floorZ + 0.03)
            end
            return coords
        else
            local refCoords = (room and room.interior_center and vec3(room.interior_center.x, room.interior_center.y, room.interior_center.z))
                or (room and room.doorCoords and vec3(room.doorCoords.x, room.doorCoords.y, room.doorCoords.z))
                or (room and room.spawn and vec3(room.spawn.x, room.spawn.y, room.spawn.z))
                or GetEntityCoords(cache.ped)

            for i = 1, maxPiles do
                local angle = (i - 1) * (2 * math.pi / maxPiles)
                coords[i] = refCoords + vec3(math.cos(angle) * 1.5, math.sin(angle) * 1.5, 0.03)
            end
            return coords
        end
    end

    local p = Properties[propertyId]
    if not p then return coords end

    if p.zone_data and p.zone_data.points and #p.zone_data.points >= 3 then
        local cx, cy, cz = 0.0, 0.0, 0.0
        local count = #p.zone_data.points
        for _, pt in ipairs(p.zone_data.points) do
            cx = cx + pt.x
            cy = cy + pt.y
            cz = cz + pt.z
        end
        local floorZ = p.zone_data.points[1].z
        local center = vec3(cx / count, cy / count, floorZ)

        for i = 1, maxPiles do
            local targetPt = p.zone_data.points[((i - 1) % count) + 1]
            local ptPos = vec3(targetPt.x, targetPt.y, floorZ)
            local pos = center + (ptPos - center) * 0.45
            coords[i] = vec3(pos.x, pos.y, floorZ + 0.03)
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
        vec3(1.2, 1.8, doorZ + 0.03),
        vec3(-1.4, 2.2, doorZ + 0.03),
        vec3(1.8, 3.2, doorZ + 0.03),
        vec3(-1.6, 3.5, doorZ + 0.03),
        vec3(0.2, 4.2, doorZ + 0.03),
    }

    for i = 1, maxPiles do
        local off = defaultOffsets[((i - 1) % #defaultOffsets) + 1]
        coords[i] = shellOrigin + off
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

function LoadPropertyTrash(propertyId, isApartment)
    if not Settings.Trash or Settings.Trash.Enabled == false then return end
    if not propertyId then return end

    if CurrentPropertyTrash and CurrentPropertyTrash.propertyId == propertyId and CurrentPropertyTrash.isApartment == isApartment then
        return
    end

    UnloadPropertyTrash(CurrentPropertyTrash and CurrentPropertyTrash.propertyId)
    CurrentPropertyTrash = { propertyId = propertyId, isApartment = isApartment and true or false }

    local trashData = lib.callback.await('LNS_Housing:server:getPropertyTrash', false, propertyId, isApartment)
    if not trashData or not trashData.activePiles then return end

    local maxTrash = (Settings.Trash and Settings.Trash.MaxTrash) or 5
    local pileCoords = GetTrashCoordinates(propertyId, isApartment, maxTrash)

    SpawnedTrashProps[propertyId] = SpawnedTrashProps[propertyId] or {}

    local modelsList = Settings.Trash.TrashModels or { 'prop_rub_litter_01', 'prop_rub_box_02', 'prop_rub_binbag_01' }
    local firstActiveCoords = nil

    for idx = 1, maxTrash do
        if trashData.activePiles[idx] and pileCoords[idx] then
            local pos = pileCoords[idx]
            firstActiveCoords = firstActiveCoords or pos

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

    if Settings.Trash.FliesEffect and trashData.trashCount and trashData.trashCount >= maxTrash and firstActiveCoords and not FliesParticleHandle then
        lib.requestNamedPtfxAsset('core')
        UseParticleFxAssetNextCall('core')
        FliesParticleHandle = StartParticleFxLoopedAtCoord(
            'ent_amb_fly_swarm',
            firstActiveCoords.x, firstActiveCoords.y, firstActiveCoords.z + 0.35,
            0.0, 0.0, 0.0,
            1.0, false, false, false, false
        )
    end
end

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

            if res.remainingCount and res.remainingCount < ((Settings.Trash and Settings.Trash.MaxTrash) or 5) then
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

            if IsPedInAnyVehicle(currentPed, true) then
                DropTrashBag(true)
                Bridge.Client.Notify('You dropped the trash bag because you entered a vehicle.', 'inform')
                break
            end

            if not isThrowingTrash and not IsEntityPlayingAnim(currentPed, 'anim@heists@narcotics@trash', 'idle', 3) then
                TaskPlayAnim(currentPed, 'anim@heists@narcotics@trash', 'idle', 3.0, -3.0, -1, 49, 0, false, false, false)
            end

            Wait(250)
        end
    end)
end

function DropTrashBag(notify)
    if CarriedBagEntity and DoesEntityExist(CarriedBagEntity) then
        DetachEntity(CarriedBagEntity, true, true)
        DeleteEntity(CarriedBagEntity)
        CarriedBagEntity = nil
    end

    local ped = cache.ped or PlayerPedId()
    StopAnimTask(ped, 'anim@heists@narcotics@trash', 'idle', 1.0)
    IsCarryingTrash = false
    CurrentCarriedTrash = nil

    TriggerServerEvent('LNS_Housing:server:dropTrash')
    if notify then
        Bridge.Client.Notify('You dropped the trash bag.', 'inform')
    end
end

local function ThrowTrashInDumpster(dumpsterEntity)
    if not IsCarryingTrash or isThrowingTrash then return end
    isThrowingTrash = true

    local ped = cache.ped or PlayerPedId()
    if dumpsterEntity and DoesEntityExist(dumpsterEntity) then
        TaskTurnPedToFaceEntity(ped, dumpsterEntity, 800)
        Wait(400)
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
end)

RegisterNetEvent('LNS_Housing:client:syncTrashReset', function(propertyId, isApartment)
    if CurrentPropertyTrash and CurrentPropertyTrash.propertyId == propertyId and CurrentPropertyTrash.isApartment == isApartment then
        LoadPropertyTrash(propertyId, isApartment)
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

