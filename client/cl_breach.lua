local Settings = lib.load('shared.settings')
local AUDIO_BANK = "audiodirectory/lns_bank"
local AUDIO_REF = "lns_soundset"
local AUDIO_TIMEOUT = 10000
local activeBreachesCount = 0
local isBreaching = false
local currentCam = nil
local currentRamProp = nil
local activeBreachedDoors = {}
local isMonitoringBreachedDoors = false
local currentStartPos = nil
local currentImpactPos = nil
local currentDoorId = nil
local currentPropertyId = nil
local currentPropertyType = nil
local currentHitsCount = 0
local isModelerActive = false
local latestRamConfig = { pitch = 12.0, roll = 0.0, yawOffset = 90.0, pos = vec3(0.0, 0.35, -0.1) }

local function EnsureBreachingWeapon()
    local job = Bridge.Client.GetPlayerJob()
    if not job or job.name ~= 'police' then
        Bridge.Client.Notify('Only police officers are authorized to breach doors!', 'error')
        return false
    end

    local ped = cache.ped or PlayerPedId()
    local raidItem = Settings.Security.RaidItem or 'WEAPON_BATTERINGRAM'
    local weaponHash = joaat(raidItem)

    if GetSelectedPedWeapon(ped) ~= weaponHash then
        local count = Bridge.Client.Search('count', raidItem)
        if count and count > 0 then
            SetCurrentPedWeapon(ped, weaponHash, true)
            Wait(200)
        end
    end

    if GetSelectedPedWeapon(ped) ~= weaponHash then
        Bridge.Client.Notify('You must have the Battering Ram equipped in your hands to breach!', 'error')
        return false
    end

    return true
end

local function LoadRamPropModel(modelName)
    local modelsToTry = {
        modelName,
        'w_me_batteringram',
        'prop_ram_01',
        'v_ilev_ram',
        'batteringram'
    }

    for _, name in ipairs(modelsToTry) do
        if name then
            local hash = type(name) == 'number' and name or joaat(name)
            if IsModelInCdimage(hash) and IsModelValid(hash) then
                RequestModel(hash)
                local timeout = GetGameTimer() + 3000
                while not HasModelLoaded(hash) and GetGameTimer() < timeout do
                    Wait(10)
                end
                if HasModelLoaded(hash) then return hash end
            end
        end
    end
    return nil
end

function IsEntityBreached(ent)
    if not ent or ent == 0 then return false end
    for _, rec in ipairs(activeBreachedDoors) do
        if rec.originalEntity == ent then
            return true
        end
        if rec.entities then
            for _, sub in ipairs(rec.entities) do
                if sub.entity == ent then
                    return true
                end
            end
        end
    end
    return false
end

function IsPropertyBreached(propertyId, doorId)
    for _, rec in ipairs(activeBreachedDoors) do
        if propertyId and rec.propertyId and rec.propertyId == propertyId then
            return true
        end
        if doorId and doorId ~= 0 and rec.doorId and rec.doorId == doorId then
            return true
        end
    end
    return false
end

local function RestoreBreachedDoor(doorId, propertyId)
    local remaining = {}
    for _, record in ipairs(activeBreachedDoors) do
        local match = true
        if doorId and doorId ~= 0 and record.doorId and record.doorId ~= doorId then
            match = false
        end
        if propertyId and record.propertyId and record.propertyId ~= propertyId then
            match = false
        end

        if match then
            if record.entities and #record.entities > 0 then
                for _, sub in ipairs(record.entities) do
                    if sub.entity and DoesEntityExist(sub.entity) then
                        SetEntityCoords(sub.entity, sub.originalCoords.x, sub.originalCoords.y, sub.originalCoords.z, false, false, false, false)
                        SetEntityRotation(sub.entity, sub.originalRot.x, sub.originalRot.y, sub.originalRot.z, 2, true)
                        SetEntityHeading(sub.entity, sub.originalHeading)
                        SetEntityCollision(sub.entity, true, true)
                        FreezeEntityPosition(sub.entity, true)
                    end
                end
            elseif record.originalEntity and DoesEntityExist(record.originalEntity) then
                SetEntityCoords(record.originalEntity, record.originalCoords.x, record.originalCoords.y, record.originalCoords.z, false, false, false, false)
                SetEntityRotation(record.originalEntity, record.originalRot.x, record.originalRot.y, record.originalRot.z, 2, true)
                SetEntityHeading(record.originalEntity, record.originalHeading)
                SetEntityCollision(record.originalEntity, true, true)
                FreezeEntityPosition(record.originalEntity, true)
            end
            if record.propertyId and Properties and Properties[record.propertyId] and RegisterPropertyEntranceTargets then
                RegisterPropertyEntranceTargets(Properties[record.propertyId])
            end
        else
            table.insert(remaining, record)
        end
    end
    activeBreachedDoors = remaining

    if propertyId and Properties and Properties[propertyId] and RegisterPropertyEntranceTargets then
        RegisterPropertyEntranceTargets(Properties[propertyId])
    end
end

RegisterNetEvent('LNS_Housing:client:breachRestoreDoor', function(doorId, propertyId)
    RestoreBreachedDoor(doorId, propertyId)
end)

local function IsDoorDimension(ent)
    if not ent or ent == 0 or not DoesEntityExist(ent) or GetEntityType(ent) ~= 3 then
        return false
    end
    local model = GetEntityModel(ent)
    if model == 0 then return false end

    local min, max = GetModelDimensions(model)
    if min and max then
        local dx = math.abs(max.x - min.x)
        local dy = math.abs(max.y - min.y)
        local dz = math.abs(max.z - min.z)
        if dz >= 1.2 and dz <= 4.0 and ((dx >= 0.4 and dx <= 3.0 and dy <= 0.6) or (dy >= 0.4 and dy <= 3.0 and dx <= 0.6)) then
            return true
        end
    end
    return false
end

local function FindDoorEntities(doorId, propertyId, doorCoords, breacherCoords)
    local doorEntities = {}
    local seen = {}

    local function addEnt(ent)
        if ent and ent ~= 0 and DoesEntityExist(ent) and GetEntityType(ent) == 3 and not seen[ent] then
            seen[ent] = true
            table.insert(doorEntities, ent)
        end
    end

    if breacherCoords or doorCoords then
        local ped = cache.ped or PlayerPedId()
        local pedCoords = type(breacherCoords) == 'vector3' and breacherCoords or GetEntityCoords(ped)
        local target = type(doorCoords) == 'vector3' and doorCoords or (pedCoords + GetEntityForwardVector(ped) * 3.0)

        local raycast = StartExpensiveSynchronousShapeTestLosProbe(
            pedCoords.x, pedCoords.y, pedCoords.z + 0.3,
            target.x, target.y, target.z + 0.3,
            1 | 16 | 32,
            ped,
            7
        )
        local _, hit, _, _, entityHit = GetShapeTestResult(raycast)
        if hit == 1 and DoesEntityExist(entityHit) and GetEntityType(entityHit) == 3 then
            addEnt(entityHit)
        end
    end

    if propertyId and Properties and Properties[propertyId] then
        local p = Properties[propertyId]
        if p and p.doors and type(p.doors) == 'table' then
            for _, dId in ipairs(p.doors) do
                if dId and dId ~= 0 and GetResourceState('ox_doorlock') == 'started' then
                    local doorData = GetOxDoorlockDoor(dId)
                    if doorData then
                        local doorsList = doorData.doors or { doorData }
                        for _, d in ipairs(doorsList) do
                            local ent = d.object or d.entity
                            if (not ent or ent == 0 or not DoesEntityExist(ent)) and d.coords then
                                local modelHash = d.model and (tonumber(d.model) or joaat(d.model)) or 0
                                if modelHash ~= 0 then
                                    ent = GetClosestObjectOfType(d.coords.x, d.coords.y, d.coords.z, 4.0, modelHash, false, false, false)
                                end
                                if not ent or ent == 0 then
                                    ent = GetClosestObjectOfType(d.coords.x, d.coords.y, d.coords.z, 4.0, 0, false, false, false)
                                end
                            end
                            addEnt(ent)
                        end
                    end
                end
            end
        end
    end

    if doorId and doorId ~= 0 and GetResourceState('ox_doorlock') == 'started' then
        local doorData = GetOxDoorlockDoor(doorId)
        if doorData then
            local doorsList = doorData.doors or { doorData }
            for _, d in ipairs(doorsList) do
                local ent = d.object or d.entity
                if (not ent or ent == 0 or not DoesEntityExist(ent)) and d.coords then
                    local modelHash = d.model and (tonumber(d.model) or joaat(d.model)) or 0
                    if modelHash ~= 0 then
                        ent = GetClosestObjectOfType(d.coords.x, d.coords.y, d.coords.z, 4.0, modelHash, false, false, false)
                    end
                    if not ent or ent == 0 then
                        ent = GetClosestObjectOfType(d.coords.x, d.coords.y, d.coords.z, 4.0, 0, false, false, false)
                    end
                end
                addEnt(ent)
            end
        end
    end

    local targetPos = doorCoords and vec3(doorCoords.x, doorCoords.y, doorCoords.z)
    if not targetPos and propertyId and Properties and Properties[propertyId] then
        local p = Properties[propertyId]
        if p and p.metadata and p.metadata.entrance then
            targetPos = vec3(p.metadata.entrance.x, p.metadata.entrance.y, p.metadata.entrance.z)
        end
    end

    if targetPos then
        local objects = GetGamePool('CObject')
        for i = 1, #objects do
            local obj = objects[i]
            if DoesEntityExist(obj) and GetEntityType(obj) == 3 then
                local objCoords = GetEntityCoords(obj)
                local dist = #(objCoords - targetPos)
                if dist <= 3.5 and IsDoorDimension(obj) then
                    addEnt(obj)
                end
            end
        end
    end

    return doorEntities
end

local function GetInwardSwingAngle(ref, doorEnt)
    if not doorEnt or not DoesEntityExist(doorEnt) then return -105.0 end

    local breacherCoords = nil
    if type(ref) == 'number' and DoesEntityExist(ref) then
        breacherCoords = GetEntityCoords(ref)
    elseif (type(ref) == 'vector3' or type(ref) == 'table') and ref.x and ref.y and ref.z then
        breacherCoords = vec3(ref.x, ref.y, ref.z)
    end

    if not breacherCoords then
        local ped = cache.ped or PlayerPedId()
        breacherCoords = GetEntityCoords(ped)
    end

    local localBreacher = GetOffsetFromEntityGivenWorldCoords(doorEnt, breacherCoords.x, breacherCoords.y, breacherCoords.z)

    local localBreacherY = localBreacher.y
    local signBreacherY = 0

    if math.abs(localBreacherY) > 0.05 then
        signBreacherY = localBreacherY > 0 and 1 or -1
    else
        local fwdVec = nil
        if type(ref) == 'number' and DoesEntityExist(ref) then
            fwdVec = GetEntityForwardVector(ref)
        else
            local ped = cache.ped or PlayerPedId()
            fwdVec = GetEntityForwardVector(ped)
        end
        local localTargetPos = GetOffsetFromEntityGivenWorldCoords(doorEnt, breacherCoords.x + fwdVec.x, breacherCoords.y + fwdVec.y, breacherCoords.z + fwdVec.z)
        local localFwdY = localTargetPos.y - localBreacherY
        signBreacherY = localFwdY < 0 and 1 or -1
    end

    local model = GetEntityModel(doorEnt)
    local min, max = GetModelDimensions(model)
    local panelDir = 1

    if min and max then
        local widthX = math.abs(max.x - min.x)
        local widthY = math.abs(max.y - min.y)

        if widthX >= widthY then
            if math.abs(min.x) > max.x then
                panelDir = -1
            else
                panelDir = 1
            end
        else
            if math.abs(min.y) > max.y then
                panelDir = -1
            else
                panelDir = 1
            end
        end
    end

    local swingSign = -panelDir * signBreacherY
    return swingSign >= 0 and 105.0 or -105.0
end

local function EnsureBreachedDoorState()
    if isMonitoringBreachedDoors or #activeBreachedDoors == 0 then return end
    isMonitoringBreachedDoors = true

    CreateThread(function()
        while #activeBreachedDoors > 0 do
            local now = GetGameTimer()
            local i = 1
            while i <= #activeBreachedDoors do
                local rec = activeBreachedDoors[i]
                if now - rec.breachTime > 600000 then
                    if rec.entities and #rec.entities > 0 then
                        for _, sub in ipairs(rec.entities) do
                            if sub.entity and DoesEntityExist(sub.entity) then
                                SetEntityCoords(sub.entity, sub.originalCoords.x, sub.originalCoords.y, sub.originalCoords.z, false, false, false, false)
                                SetEntityRotation(sub.entity, sub.originalRot.x, sub.originalRot.y, sub.originalRot.z, 2, true)
                                SetEntityHeading(sub.entity, sub.originalHeading)
                                SetEntityCollision(sub.entity, true, true)
                                FreezeEntityPosition(sub.entity, true)
                            end
                        end
                    elseif rec.originalEntity and DoesEntityExist(rec.originalEntity) then
                        SetEntityCoords(rec.originalEntity, rec.originalCoords.x, rec.originalCoords.y, rec.originalCoords.z, false, false, false, false)
                        SetEntityRotation(rec.originalEntity, rec.originalRot.x, rec.originalRot.y, rec.originalRot.z, 2, true)
                        SetEntityHeading(rec.originalEntity, rec.originalHeading)
                        SetEntityCollision(rec.originalEntity, true, true)
                        FreezeEntityPosition(rec.originalEntity, true)
                    end
                    table.remove(activeBreachedDoors, i)
                else
                    local foundEnts = FindDoorEntities(rec.doorId, rec.propertyId, rec.doorCoords, rec.breacherCoords)
                    if not rec.entities then rec.entities = {} end

                    for _, doorEnt in ipairs(foundEnts) do
                        local foundSub = nil
                        for _, sub in ipairs(rec.entities) do
                            if sub.entity == doorEnt then
                                foundSub = sub
                                break
                            end
                        end

                        if not foundSub and DoesEntityExist(doorEnt) then
                            local entCoords = GetEntityCoords(doorEnt)
                            local doorRot = GetEntityRotation(doorEnt, 2)
                            local doorHeading = GetEntityHeading(doorEnt)
                            local swingAngle = GetInwardSwingAngle(rec.breacherCoords or rec.doorCoords, doorEnt)
                            local openHeading = (doorHeading + swingAngle) % 360.0

                            foundSub = {
                                entity = doorEnt,
                                originalCoords = entCoords,
                                originalRot = doorRot,
                                originalHeading = doorHeading,
                                openHeading = openHeading,
                                swingAngle = swingAngle
                            }
                            table.insert(rec.entities, foundSub)

                            FreezeEntityPosition(doorEnt, false)
                            SetEntityCollision(doorEnt, false, false)
                            SetEntityHeading(doorEnt, openHeading)
                            FreezeEntityPosition(doorEnt, true)
                        end
                    end

                    if rec.entities then
                        for _, sub in ipairs(rec.entities) do
                            if sub.entity and DoesEntityExist(sub.entity) and sub.openHeading then
                                SetEntityHeading(sub.entity, sub.openHeading)
                                SetEntityCollision(sub.entity, false, false)
                            end
                        end
                    end
                    i = i + 1
                end
            end
            Wait(250)
        end
        isMonitoringBreachedDoors = false
    end)
end

local function ApplyBreachForceToDoor(doorId, propertyId, doorCoords, breacherCoords, swingAngle)
    local existingRecord = nil
    for _, rec in ipairs(activeBreachedDoors) do
        if (propertyId and rec.propertyId and rec.propertyId == propertyId) or (doorId and doorId ~= 0 and rec.doorId and rec.doorId == doorId) then
            existingRecord = rec
            break
        end
    end

    if not existingRecord then
        existingRecord = {
            doorId = doorId,
            propertyId = propertyId,
            doorCoords = doorCoords,
            breacherCoords = breacherCoords,
            swingAngle = swingAngle,
            breachTime = GetGameTimer(),
            entities = {}
        }
        table.insert(activeBreachedDoors, existingRecord)
    else
        if swingAngle and not existingRecord.swingAngle then
            existingRecord.swingAngle = swingAngle
        end
        if doorCoords then existingRecord.doorCoords = doorCoords end
        if breacherCoords then existingRecord.breacherCoords = breacherCoords end
        if not existingRecord.entities then existingRecord.entities = {} end
    end

    local doorEntities = FindDoorEntities(doorId, propertyId, doorCoords, breacherCoords)

    for _, doorEnt in ipairs(doorEntities) do
        if DoesEntityExist(doorEnt) then
            local entCoords = GetEntityCoords(doorEnt)
            local doorRot = GetEntityRotation(doorEnt, 2)
            local doorHeading = GetEntityHeading(doorEnt)

            local finalSwingAngle = GetInwardSwingAngle(breacherCoords or doorCoords, doorEnt)
            local openHeading = (doorHeading + finalSwingAngle) % 360.0

            local subRecord = nil
            for _, sub in ipairs(existingRecord.entities) do
                if sub.entity == doorEnt then
                    subRecord = sub
                    break
                end
            end

            if not subRecord then
                subRecord = {
                    entity = doorEnt,
                    originalCoords = entCoords,
                    originalRot = doorRot,
                    originalHeading = doorHeading,
                    openHeading = openHeading,
                    swingAngle = finalSwingAngle
                }
                table.insert(existingRecord.entities, subRecord)
            else
                subRecord.openHeading = openHeading
                subRecord.swingAngle = finalSwingAngle
            end

            if not existingRecord.originalEntity then
                existingRecord.originalEntity = doorEnt
                existingRecord.originalCoords = entCoords
                existingRecord.originalRot = doorRot
                existingRecord.originalHeading = doorHeading
                existingRecord.openHeading = openHeading
            end

            FreezeEntityPosition(doorEnt, false)
            SetEntityCollision(doorEnt, false, false)

            CreateThread(function()
                local duration = 400
                local startTime = GetGameTimer()
                while true do
                    local elapsed = GetGameTimer() - startTime
                    local t = math.min(1.0, elapsed / duration)
                    local ease = 1.0 - (1.0 - t) * (1.0 - t)
                    local curHeading = (doorHeading + (finalSwingAngle * ease)) % 360.0

                    if DoesEntityExist(doorEnt) then
                        SetEntityHeading(doorEnt, curHeading)
                    end

                    if t >= 1.0 then break end
                    Wait(10)
                end

                if DoesEntityExist(doorEnt) then
                    SetEntityHeading(doorEnt, openHeading)
                    SetEntityCollision(doorEnt, false, false)
                    FreezeEntityPosition(doorEnt, true)
                end
            end)
        end
    end

    EnsureBreachedDoorState()
end

RegisterNetEvent('LNS_Housing:client:breachForceOpenDoor', function(doorId, propertyId, doorCoords, breacherCoords, swingAngle)
    ApplyBreachForceToDoor(doorId, propertyId, doorCoords, breacherCoords, swingAngle)
end)

local function StopBreachingMode()
    local wasBreaching = isBreaching
    isBreaching = false

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeBreachMinigame' })

    if currentCam then
        if DoesCamExist(currentCam) then
            SetCamActive(currentCam, false)
            DestroyCam(currentCam, true)
        end
        currentCam = nil
    end
    RenderScriptCams(false, false, 0, true, true)
    DestroyAllCams(true)

    if currentRamProp then
        if DoesEntityExist(currentRamProp) then
            DetachEntity(currentRamProp, true, true)
            SetEntityAsMissionEntity(currentRamProp, true, true)
            DeleteEntity(currentRamProp)
            DeleteObject(currentRamProp)
        end
        currentRamProp = nil
    end

    local ped = cache.ped or PlayerPedId()
    SetEntityVisible(ped, true, false)
    FreezeEntityPosition(ped, false)
    ClearPedTasks(ped)
    ClearPedTasksImmediately(ped)
    EnableAllControlActions(0)

    if wasBreaching and activeBreachesCount > 0 then
        activeBreachesCount = activeBreachesCount - 1
        if activeBreachesCount == 0 then
            ReleaseScriptAudioBank()
        end
    end

    local raidItem = Settings.Security.RaidItem or 'WEAPON_BATTERINGRAM'
    local raidHash = joaat(raidItem)
    if HasPedGotWeapon(ped, raidHash, false) then
        SetCurrentPedWeapon(ped, raidHash, true)
    end

    DisplayRadar(true)

    currentStartPos = nil
    currentImpactPos = nil
    currentDoorId = nil
    currentPropertyId = nil
    currentPropertyType = nil
    currentHitsCount = 0
end

RegisterNUICallback('breachDragUpdate', function(data, cb)
    if isBreaching and currentRamProp and DoesEntityExist(currentRamProp) and currentStartPos and currentImpactPos then
        local progress = data.progress or 0.0
        local curPos = currentStartPos + (currentImpactPos - currentStartPos) * progress
        SetEntityCoords(currentRamProp, curPos.x, curPos.y, curPos.z, false, false, false, false)
    end
    if cb then cb('ok') end
end)

RegisterNUICallback('breachHit', function(data, cb)
    if not isBreaching or not currentStartPos or not currentImpactPos then
        if cb then cb('ok') end
        return
    end

    currentHitsCount = currentHitsCount + 1

    if currentRamProp and DoesEntityExist(currentRamProp) then
        SetEntityCoords(currentRamProp, currentImpactPos.x, currentImpactPos.y, currentImpactPos.z, false, false, false, false)
    end

    if currentCam and DoesCamExist(currentCam) then
        ShakeCam(currentCam, "SMALL_EXPLOSION_SHAKE", 0.10)
    end

    local requiredHits = Settings.Security.RequiredBreachHits or 3
    if currentHitsCount >= requiredHits then
        local doorId = currentDoorId
        local propertyId = currentPropertyId
        local propertyType = currentPropertyType
        local doorCoords = currentImpactPos

        CreateThread(function()
            local soundIds = {}

            Bridge.Client.PlayAudio({
                audioName = "breaching",
                audioRef = AUDIO_REF,
                audioSource = doorCoords,
                range = 15.0,
                returnSoundId = false,
            })

            Wait(5000)

            for _, soundId in ipairs(soundIds) do
                StopSound(soundId)
                ReleaseSoundId(soundId)
            end
        end)

        Wait(100)
        StopBreachingMode()

        local ped = cache.ped or PlayerPedId()
        local breacherCoords = GetEntityCoords(ped)

        local swingAngle = nil
        local doorEntities = FindDoorEntities(doorId, propertyId, doorCoords, breacherCoords)
        if #doorEntities > 0 then
            swingAngle = GetInwardSwingAngle(ped, doorEntities[1])
        end

        TriggerServerEvent('LNS_Housing:server:policeRaidDoor', propertyId, propertyType, doorId, doorCoords, breacherCoords, swingAngle)
    end

    if cb then cb('ok') end
end)

RegisterNUICallback('breachCancel', function(data, cb)
    StopBreachingMode()
    Bridge.Client.Notify('Breaching cancelled.', 'error')
    if cb then cb('ok') end
end)

function StartPoliceRaid(propertyId, propertyType, doorId)
    if isBreaching then return end
    if not EnsureBreachingWeapon() then return end

    local ped = cache.ped or PlayerPedId()

    ClearPedTasksImmediately(ped)
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)

    SetEntityVisible(ped, false, false)
    Wait(50)

    local pedHeading = GetEntityHeading(ped)

    isBreaching = true
    currentDoorId = doorId
    currentPropertyId = propertyId
    currentPropertyType = propertyType
    currentHitsCount = 0

    activeBreachesCount = activeBreachesCount + 1
    Bridge.Client.LoadAudioBank(AUDIO_BANK, AUDIO_TIMEOUT)

    DisplayRadar(false)

    local doorTarget = GetOffsetFromEntityInWorldCoords(ped, 0.01, 0.11, 0.18)
    currentImpactPos = GetOffsetFromEntityInWorldCoords(ped, 0.01, 0.11, 0.18)
    currentStartPos = GetOffsetFromEntityInWorldCoords(ped, 0.01, -0.45, 0.18)

    local camCoords = GetOffsetFromEntityInWorldCoords(ped, 1.5, -0.3, 0.18)

    currentCam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", camCoords.x, camCoords.y, camCoords.z, 0.0, 0.0, 0.0, 54.0, false, 0)
    PointCamAtCoord(currentCam, doorTarget.x, doorTarget.y, doorTarget.z)
    SetCamActive(currentCam, true)
    RenderScriptCams(true, false, 0, true, true)

    local ramModel = Settings.Security.RamProp or 'w_me_batteringram'
    local modelHash = LoadRamPropModel(ramModel)

    if not modelHash then
        Bridge.Client.Notify('Failed to load battering ram model.', 'error')
        StopBreachingMode()
        return
    end

    currentRamProp = CreateObject(modelHash, currentStartPos.x, currentStartPos.y, currentStartPos.z, false, false, false)

    local rot = Settings.Security.RamRotation or { pitch = 0.0, roll = 0.0, yawOffset = 90.0 }
    SetEntityRotation(currentRamProp, rot.pitch, rot.roll, pedHeading + (rot.yawOffset or 0.0), 2, true)

    FreezeEntityPosition(currentRamProp, true)
    SetEntityCollision(currentRamProp, false, false)

    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'startBreachMinigame' })

    CreateThread(function()
        while isBreaching do
            DisableAllControlActions(0)
            EnableControlAction(0, 239, true)
            EnableControlAction(0, 240, true)

            if IsControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 200)
               or IsControlJustPressed(0, 322) or IsDisabledControlJustPressed(0, 322)
               or IsControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 177)
               or IsControlJustPressed(0, 202) or IsDisabledControlJustPressed(0, 202) then
                StopBreachingMode()
                Bridge.Client.Notify('Breaching cancelled.', 'error')
                break
            end

            Wait(0)
        end
    end)
end

function StartPoliceStashRaid(propertyId, stashId)
    local job = Bridge.Client.GetPlayerJob()
    if not job or job.name ~= 'police' then
        Bridge.Client.Notify('Only police officers are authorized to raid storage!', 'error')
        return
    end

    local accessTool = Settings.Security.PoliceAccessTool or 'police_access_tool'
    local count = Bridge.Client.Search('count', accessTool)
    if not count or count < 1 then
        Bridge.Client.Notify('You need a Police Access Tool to raid this storage!', 'error')
        return
    end

    local isDoorBreached = IsPropertyBreached(propertyId) or lib.callback.await('LNS_Housing:server:isDoorBreached', false, propertyId)
    if not isDoorBreached then
        Bridge.Client.Notify('You must breach the property door first before raiding storage!', 'error')
        return
    end

    local fullStashId = stashId
    if fullStashId and type(fullStashId) == 'string' and not string.find(fullStashId, '^housing_') then
        fullStashId = string.format('housing_%d_%s', propertyId, stashId)
    end

    local duration = Settings.Security.RaidStorageDuration or 6000

    local success = lib.progressBar({
        duration = duration,
        label = 'Breaching Storage...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true,
        },
    })

    if success then
        TriggerServerEvent('LNS_Housing:server:policeRaidStash', propertyId, fullStashId)
        Bridge.Client.Notify('Storage breached successfully!', 'success')
        if fullStashId then
            Bridge.Client.OpenInventory('stash', fullStashId)
        end
    else
        Bridge.Client.Notify('Storage raid cancelled.', 'error')
    end
end

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        StopBreachingMode()
        RestoreBreachedDoor(nil, nil)
    end
end)

CreateThread(function()
    Wait(2000)
    lib.callback('LNS_Housing:server:getBreachedDoors', false, function(breachedDoors)
        if breachedDoors then
            for propertyId, data in pairs(breachedDoors) do
                ApplyBreachForceToDoor(data.doorId, data.propertyId, data.doorCoords, data.breacherCoords, data.swingAngle)
            end
        end
    end)
end)