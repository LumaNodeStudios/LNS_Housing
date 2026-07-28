local Settings = lib.load('shared.settings')

if not Settings.Security.PhysicalKeys.Enabled or not Settings.Locksmith or not Settings.Locksmith.Enabled then
    return
end

local locksmithPed = nil
local locksmithBlip = nil

local function OpenPropertySelectMenu()
    local properties = lib.callback.await('LNS_Housing:server:getMyKeyableProperties', false)
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
            arrow = true,
            onSelect = function()
                OpenRecipientMenu(p)
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

function OpenRecipientMenu(property)
    local options = {
        {
            title = 'Cut for Myself',
            icon = 'user',
            onSelect = function()
                TriggerServerEvent('LNS_Housing:server:cutPhysicalKey', property.id, property.isApartment, nil)
            end
        }
    }

    local players = GetActivePlayers()
    local myPed = cache.ped
    local myCoords = GetEntityCoords(myPed)
    local nearbyIds = {}

    for _, player in ipairs(players) do
        local targetPed = GetPlayerPed(player)
        if targetPed ~= myPed then
            local dist = #(myCoords - GetEntityCoords(targetPed))
            if dist < 5.0 then
                table.insert(nearbyIds, GetPlayerServerId(player))
            end
        end
    end

    if #nearbyIds > 0 then
        local resolved = lib.callback.await('LNS_Housing:server:resolvePlayerNames', false, nearbyIds)
        for _, entry in ipairs(resolved or {}) do
            table.insert(options, {
                title = 'Cut for ' .. entry.name,
                icon = 'user-group',
                onSelect = function()
                    TriggerServerEvent('LNS_Housing:server:cutPhysicalKey', property.id, property.isApartment, entry.serverId)
                end
            })
        end
    end

    lib.registerContext({
        id = 'locksmith_recipient_select',
        title = 'Cut Key - ' .. property.label,
        menu = 'locksmith_property_select',
        options = options
    })
    lib.showContext('locksmith_recipient_select')
end

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