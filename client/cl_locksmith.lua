local Settings = lib.load('shared.settings')
local locksmithPed = nil
local locksmithBlip = nil

local function IsPhysicalKeysEnabled()
    return Settings and Settings.Security and Settings.Security.PhysicalKeys and Settings.Security.PhysicalKeys.Enabled == true
end

local function ShouldSpawnBuiltInLocksmith()
    if not IsPhysicalKeysEnabled() then return false end
    if not Settings.Locksmith or not Settings.Locksmith.Enabled then return false end
    if Settings.Locksmith.Ped and Settings.Locksmith.Ped.Enabled == false then return false end
    return true
end

local function GetKeyableProperties()
    if not IsPhysicalKeysEnabled() then
        return {}
    end
    return lib.callback.await('LNS_Housing:server:getMyKeyableProperties', false) or {}
end

local function CutPhysicalKey(propertyId, isApartment)
    if not IsPhysicalKeysEnabled() then
        return false, 'physical_keys_disabled'
    end
    return lib.callback.await('LNS_Housing:server:cutPhysicalKey', false, propertyId, isApartment == true)
end

local function OpenPropertySelectMenu()
    if not IsPhysicalKeysEnabled() then
        Bridge.Client.Notify('Physical keys are not enabled.', 'error')
        return
    end

    debugPrint('info', 'Opening locksmith property select menu')
    local properties = GetKeyableProperties()
    if not properties or #properties == 0 then
        Bridge.Client.Notify('You are not a keyholder of any property.', 'error')
        return
    end

    local options = {}
    for _, p in ipairs(properties) do
        table.insert(options, {
            title = p.label,
            description = p.isApartment and 'Apartment' or 'House',
            icon = 'key',
            image = p.image,
            arrow = false,
            onSelect = function()
                TriggerServerEvent('LNS_Housing:server:cutPhysicalKey', p.id, p.isApartment)
            end
        })
    end

    lib.registerContext({
        id = 'locksmith_property_select',
        title = 'Cut a Key - Select Property',
        options = options
    })
    lib.showContext('locksmith_property_select')
end

exports('GetKeyableProperties', GetKeyableProperties)
exports('CutPhysicalKey', CutPhysicalKey)
exports('OpenLocksmithMenu', OpenPropertySelectMenu)

local function CreateLocksmithPed()
    local pedConf = Settings.Locksmith.Ped
    local hash = GetHashKey(pedConf.Model)

    lib.requestModel(hash)
    while not HasModelLoaded(hash) do
        Wait(100)
    end

    locksmithPed = CreatePed(4, hash, pedConf.Coords.x, pedConf.Coords.y, pedConf.Coords.z - 1.0, pedConf.Coords.w, false, true)
    FreezeEntityPosition(locksmithPed, true)
    SetEntityInvincible(locksmithPed, true)
    SetBlockingOfNonTemporaryEvents(locksmithPed, true)

    if pedConf.Scenario then
        TaskStartScenarioInPlace(locksmithPed, pedConf.Scenario, 0, true)
    end

    exports.ox_target:addLocalEntity(locksmithPed, {
        {
            name = 'locksmith_cut_key',
            icon = 'fas fa-key',
            label = 'Cut a Key',
            distance = Settings.Locksmith.Distance,
            onSelect = function()
                OpenPropertySelectMenu()
            end
        }
    })

    if Settings.Locksmith.Blip and Settings.Locksmith.Blip.Enabled then
        locksmithBlip = AddBlipForCoord(pedConf.Coords.x, pedConf.Coords.y, pedConf.Coords.z)
        SetBlipSprite(locksmithBlip, Settings.Locksmith.Blip.Sprite)
        SetBlipDisplay(locksmithBlip, 4)
        SetBlipScale(locksmithBlip, Settings.Locksmith.Blip.Scale)
        SetBlipColour(locksmithBlip, Settings.Locksmith.Blip.Color)
        SetBlipAsShortRange(locksmithBlip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(Settings.Locksmith.Blip.Label)
        EndTextCommandSetBlipName(locksmithBlip)
    end
end

if ShouldSpawnBuiltInLocksmith() then
    CreateThread(function()
        while not NetworkIsPlayerActive(PlayerId()) do
            Wait(100)
        end
        Wait(1000)
        CreateLocksmithPed()
    end)

    AddEventHandler('onResourceStop', function(resourceName)
        if GetCurrentResourceName() ~= resourceName then return end

        if locksmithPed and DoesEntityExist(locksmithPed) then
            DeleteEntity(locksmithPed)
        end
        if locksmithBlip then
            RemoveBlip(locksmithBlip)
        end
    end)
end