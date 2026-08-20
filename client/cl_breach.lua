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
        local count = exports.ox_inventory:Search('count', raidItem)
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
            if record.originalEntity and DoesEntityExist(record.originalEntity) then
                SetEntityCoords(record.originalEntity, record.originalCoords.x, record.originalCoords.y, record.originalCoords.z, false, false, false, false)
                SetEntityRotation(record.originalEntity, record.originalRot.x, record.originalRot.y, record.originalRot.z, 2, true)
                SetEntityHeading(record.originalEntity, record.originalHeading)
                SetEntityCollision(record.originalEntity, true, true)
                FreezeEntityPosition(record.originalEntity, true)
            end
        else
            table.insert(remaining, record)
        end
    end
    activeBreachedDoors = remaining
end

RegisterNetEvent('LNS_Housing:client:breachRestoreDoor', function(doorId, propertyId)
    RestoreBreachedDoor(doorId, propertyId)
end)

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
                    if rec.originalEntity and DoesEntityExist(rec.originalEntity) then
                        SetEntityCoords(rec.originalEntity, rec.originalCoords.x, rec.originalCoords.y, rec.originalCoords.z, false, false, false, false)
                        SetEntityRotation(rec.originalEntity, rec.originalRot.x, rec.originalRot.y, rec.originalRot.z, 2, true)
                        SetEntityHeading(rec.originalEntity, rec.originalHeading)
                        SetEntityCollision(rec.originalEntity, true, true)
                        FreezeEntityPosition(rec.originalEntity, true)
                    end
                    table.remove(activeBreachedDoors, i)
                else
                    if rec.originalEntity and DoesEntityExist(rec.originalEntity) and rec.openHeading then
                        SetEntityHeading(rec.originalEntity, rec.openHeading)
                        SetEntityCollision(rec.originalEntity, false, false)
                    end
                    i = i + 1
                end
            end
            Wait(250)
        end
        isMonitoringBreachedDoors = false
    end)
end

local function FindDoorEntities(doorId, propertyId)
    local doorEntities = {}
    local seen = {}

    local function addEnt(ent)
        if ent and ent ~= 0 and DoesEntityExist(ent) and GetEntityType(ent) == 3 and not seen[ent] then
            seen[ent] = true
            table.insert(doorEntities, ent)
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
                        ent = GetClosestObjectOfType(d.coords.x, d.coords.y, d.coords.z, 3.0, modelHash, false, false, false)
                    end
                    if not ent or ent == 0 then
                        ent = GetClosestObjectOfType(d.coords.x, d.coords.y, d.coords.z, 3.0, 0, false, false, false)
                    end
                end
                addEnt(ent)
            end
        end
    end

    if #doorEntities == 0 and propertyId and Properties and Properties[propertyId] then
        local p = Properties[propertyId]
        if p and p.metadata and p.metadata.entrance then
            local eCoords = vec3(p.metadata.entrance.x, p.metadata.entrance.y, p.metadata.entrance.z)
            local ent = GetClosestObjectOfType(eCoords.x, eCoords.y, eCoords.z, 3.0, 0, false, false, false)
            addEnt(ent)
        end
    end

    if #doorEntities == 0 then
        local ped = cache.ped or PlayerPedId()
        local pedCoords = GetEntityCoords(ped)
        local forwardVector = GetEntityForwardVector(ped)
        local targetPos = pedCoords + (forwardVector * 3.5)

        local raycast = StartExpensiveSynchronousShapeTestLosProbe(
            pedCoords.x, pedCoords.y, pedCoords.z + 0.3,
            targetPos.x, targetPos.y, targetPos.z + 0.3,
            1 | 16 | 32,
            ped,
            7
        )
        local _, hit, _, _, entityHit = GetShapeTestResult(raycast)
        if hit == 1 and DoesEntityExist(entityHit) and GetEntityType(entityHit) == 3 then
            addEnt(entityHit)
        end

        if #doorEntities == 0 then
            local searchCenter = pedCoords + (forwardVector * 1.5)
            local ent = GetClosestObjectOfType(searchCenter.x, searchCenter.y, searchCenter.z, 2.5, 0, false, false, false)
            addEnt(ent)
        end
    end

    return doorEntities
end

local function GetInwardSwingAngle(ped, doorEnt)
    local playerForward = GetEntityForwardVector(ped)
    local originalHeading = GetEntityHeading(doorEnt)

    SetEntityHeading(doorEnt, (originalHeading + 105.0) % 360.0)
    local fwdPlus = GetEntityForwardVector(doorEnt)
    local dotPlus = (fwdPlus.x * playerForward.x) + (fwdPlus.y * playerForward.y)

    SetEntityHeading(doorEnt, (originalHeading - 105.0) % 360.0)
    local fwdMinus = GetEntityForwardVector(doorEnt)
    local dotMinus = (fwdMinus.x * playerForward.x) + (fwdMinus.y * playerForward.y)

    SetEntityHeading(doorEnt, originalHeading)

    if dotPlus < dotMinus then
        return 105.0
    else
        return -105.0
    end
end

local function ApplyBreachForceToDoor(doorId, propertyId)
    local ped = cache.ped or PlayerPedId()
    local pedCoords = GetEntityCoords(ped)

    local doorEntities = FindDoorEntities(doorId, propertyId)
    if #doorEntities == 0 then return end

    for _, doorEnt in ipairs(doorEntities) do
        if DoesEntityExist(doorEnt) then
            local alreadyBreached = false
            for _, rec in ipairs(activeBreachedDoors) do
                if rec.originalEntity == doorEnt then
                    alreadyBreached = true
                    break
                end
            end

            if not alreadyBreached then
                local doorCoords = GetEntityCoords(doorEnt)
                local doorRot = GetEntityRotation(doorEnt, 2)
                local doorHeading = GetEntityHeading(doorEnt)

                local swingAngle = GetInwardSwingAngle(ped, doorEnt)
                local openHeading = (doorHeading + swingAngle) % 360.0

                local record = {
                    originalEntity = doorEnt,
                    originalCoords = doorCoords,
                    originalRot = doorRot,
                    originalHeading = doorHeading,
                    openHeading = openHeading,
                    doorId = doorId,
                    propertyId = propertyId,
                    breachTime = GetGameTimer()
                }
                table.insert(activeBreachedDoors, record)

                print(('^2[LNS_Housing Breach]^0 Slamming door entity %s wide open into room (Heading: %.1f -> %.1f)'):format(tostring(doorEnt), doorHeading, openHeading))

                FreezeEntityPosition(doorEnt, false)
                SetEntityCollision(doorEnt, false, false)

                CreateThread(function()
                    local duration = 350
                    local startTime = GetGameTimer()
                    while true do
                        local elapsed = GetGameTimer() - startTime
                        local t = math.min(1.0, elapsed / duration)
                        --local ease = 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t)
                        local ease = 1.0 - (1.0 - t) * (1.0 - t)

                        local curHeading = (doorHeading + (swingAngle * ease)) % 360.0

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
    end

    EnsureBreachedDoorState()
end

RegisterNetEvent('LNS_Housing:client:breachForceOpenDoor', function(doorId, propertyId)
    ApplyBreachForceToDoor(doorId, propertyId)
end)

local function StopBreachingMode()
    isBreaching = false

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeBreachMinigame' })

    if currentCam and DoesCamExist(currentCam) then
        SetCamActive(currentCam, false)
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(currentCam, true)
        DestroyAllCams(true)
        currentCam = nil
    end

    if currentRamProp and DoesEntityExist(currentRamProp) then
        DeleteEntity(currentRamProp)
        currentRamProp = nil
    end

    local ped = cache.ped or PlayerPedId()
    SetEntityVisible(ped, true, false)
    ClearPedTasks(ped)
    ClearPedTasksImmediately(ped)
    EnableAllControlActions(0)

    if activeBreachesCount > 0 then
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

            qbx.playAudio({
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

        ApplyBreachForceToDoor(doorId, propertyId)
        TriggerServerEvent('LNS_Housing:server:policeRaidDoor', propertyId, propertyType, doorId)
    end

    if cb then cb('ok') end
end)

RegisterNUICallback('breachCancel', function(data, cb)
    if isBreaching then
        StopBreachingMode()
        Bridge.Client.Notify('Breaching cancelled.', 'error')
    end
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
    qbx.loadAudioBank(AUDIO_BANK, AUDIO_TIMEOUT)

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

            if IsControlJustPressed(0, 322) or IsDisabledControlJustPressed(0, 73) or IsDisabledControlJustPressed(0, 25) then
                StopBreachingMode()
                Bridge.Client.Notify('Breaching cancelled.', 'error')
                break
            end

            Wait(0)
        end
    end)
end

function StartPoliceStashRaid(propertyId, stashId)
    StartPoliceRaid(propertyId, 'house', nil)
end

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        StopBreachingMode()
        RestoreBreachedDoor(nil, nil)
    end
end)