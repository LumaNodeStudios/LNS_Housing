local Settings = lib.load('shared.settings')

-- NUI Callback to pick a nearby door from ox_doorlock (Interactive)
RegisterNUICallback('pickDoor', function(_, cb)
    SendNUIMessage({ action = 'toggleVisibility', data = { visible = false } })
    SetNuiFocus(false, false) -- Hide UI while picking
    
    local doorId = exports.LNS_Housing:DoorPicker()
    
    SendNUIMessage({ action = 'toggleVisibility', data = { visible = true } })
    SetNuiFocus(true, true) -- Show UI again
    
    if doorId then
        SendNUIMessage({
            action = 'addDoor',
            data = doorId
        })
        if type(doorId) == 'table' then
            Settings.Notify('New Door selected at ' .. math.floor(doorId.coords.x) .. ', ' .. math.floor(doorId.coords.y), 'success')
        else
            Settings.Notify('Door ID ' .. doorId .. ' added to list.', 'success')
        end
    end
    cb('ok')
end)

-- NUI Callback to trigger the zone creator
RegisterNUICallback('createZone', function(_, cb)
    SendNUIMessage({ action = 'toggleVisibility', data = { visible = false } })
    SetNuiFocus(false, false) -- Hide UI while creating zone
    
    local zoneData = exports.LNS_Housing:PolyCreator()
    
    SendNUIMessage({ action = 'toggleVisibility', data = { visible = true } })
    SetNuiFocus(true, true) -- Show UI again
    
    if zoneData then
        -- Convert points to simple table for JSON
        local simplePoints = {}
        for i, p in ipairs(zoneData.points) do
            simplePoints[i] = {x = p.x, y = p.y, z = p.z}
        end
        
        cb({
            points = simplePoints,
            thickness = zoneData.thickness
        })
    else
        cb(nil)
    end
end)

RegisterNUICallback('createYardZone', function(_, cb)
    SendNUIMessage({ action = 'toggleVisibility', data = { visible = false } })
    SetNuiFocus(false, false) -- Hide UI while creating zone
    
    local zoneData = exports.LNS_Housing:PolyCreator()
    
    SendNUIMessage({ action = 'toggleVisibility', data = { visible = true } })
    SetNuiFocus(true, true) -- Show UI again
    
    if zoneData then
        -- Convert points to simple table for JSON
        local simplePoints = {}
        for i, p in ipairs(zoneData.points) do
            simplePoints[i] = {x = p.x, y = p.y, z = p.z}
        end
        
        cb({
            points = simplePoints,
            thickness = zoneData.thickness
        })
    else
        cb(nil)
    end
end)

RegisterNUICallback('takePhoto', function(_, cb)
    SendNUIMessage({ action = 'toggleVisibility', data = { visible = false } })
    SetNuiFocus(false, false)
    
    Wait(300)

    local oldCamMode = GetFollowPedCamViewMode()
    SetFollowPedCamViewMode(4)

    Wait(200)

    local done = false
    local uploading = false

    CreateThread(function()
        while not done do
            if uploading then
                lib.showTextUI('Uploading photo, please wait...')
            else
                lib.showTextUI('[ENTER] Take Photo | [BACKSPACE] Cancel')
            end
            Wait(0)
        end
        lib.hideTextUI()
    end)

    CreateThread(function()
        Wait(500)

        while not done do
            Wait(0)

            DisableControlAction(0, 191, true)
            DisableControlAction(0, 177, true)

            if IsDisabledControlJustReleased(0, 191) then
                uploading = true

                exports['screenshot-basic']:requestScreenshotUpload(Settings.ImageUpload.Url, 'file', {
                    headers = { ['Authorization'] = Settings.ImageUpload.Token }
                }, function(data)
                    local resp = json.decode(data)
                    done = true
                    SetFollowPedCamViewMode(oldCamMode)
                    SendNUIMessage({ action = 'toggleVisibility', data = { visible = true } })
                    SetNuiFocus(true, true)

                    if resp and resp.data and resp.data.url then
                        cb(resp.data.url)
                        Settings.Notify('Photo uploaded successfully!', 'success')
                    else
                        cb(nil)
                        Settings.Notify('Failed to upload photo. Check console for errors.', 'error')
                        print('^1[Housing] Photo upload failed: ' .. tostring(data) .. '^7')
                    end
                end)

            elseif IsDisabledControlJustReleased(0, 177) and not uploading then
                done = true
                SetFollowPedCamViewMode(oldCamMode)
                SendNUIMessage({ action = 'toggleVisibility', data = { visible = true } })
                SetNuiFocus(true, true)
                cb(nil)
            end
        end
    end)
end)