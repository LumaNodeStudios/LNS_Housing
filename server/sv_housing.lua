local Settings = lib.load('shared.settings')

TemporaryAccess = {
    doors = {},
    stashes = {}
}


function IsRentOverdue(p)
    if not p or p.sale_type ~= 'rent' or not p.owner then return false end
    if p.metadata and p.metadata.due_by then
        return os.time() > p.metadata.due_by
    end
    return false
end

function IsRetrievalPeriodActive(p)
    if not p or p.sale_type ~= 'rent' or not p.owner then return false end
    if p.metadata and p.metadata.due_by then
        local now = os.time()
        local retrievalPeriod = Settings.Rent and Settings.Rent.RetrievalPeriod or 604800
        return now > p.metadata.due_by and now <= (p.metadata.due_by + retrievalPeriod)
    end
    return false
end

function SyncPropertyDoor(propertyId)
    local p = Properties[propertyId]
    if not p then return end

    local doorsToSync = {}
    if p.doors and #p.doors > 0 then
        doorsToSync = p.doors
    elseif p.door_id and p.door_id ~= 0 then
        doorsToSync = { p.door_id }
    end

    if #doorsToSync == 0 then return end

    local identifiers = {}

    if not IsRentOverdue(p) then
        if p.owner then
            identifiers[p.owner] = 4
        end

        if p.permissions then
            for type, cids in pairs(p.permissions) do
                for _, cid in ipairs(cids) do
                    if not identifiers[cid] or identifiers[cid] < 1 then
                        identifiers[cid] = 1
                    end
                end
            end
        end
    end

    for _, doorId in ipairs(doorsToSync) do
        exports.ox_doorlock:editDoor(doorId, {
            identifiers = identifiers
        })
    end
end

function ProcessPropertySalePayout(propertyId, amount)
    local p = Properties[propertyId]
    if not p then return end

    if p.agency then
        local commissionRate = tonumber(p.commission_rate) or 10
        local commission = math.floor(amount * (commissionRate / 100))
        local remainder = amount - commission

        if p.agent_cid then
            local agent = Bridge.Server.IsPlayerOnline(p.agent_cid)
            if agent then
                local agentSource = agent.PlayerData.source
                Bridge.Server.AddBankMoney(agentSource, commission, "Property Sale Commission: " .. p.label)
                Bridge.Server.Notify(agentSource, string.format("You received $%s commission for selling %s!", commission, p.label), "success")
            else
                Bridge.Server.AddOfflineBankMoney(p.agent_cid, commission)
            end
        end

        local agencyConfig = Settings.RealEstate.Agencies and Settings.RealEstate.Agencies[p.agency]
        local societyName = agencyConfig and agencyConfig.society or p.agency
        Bridge.Server.AddSocietyMoney(societyName, remainder)
    end
end

function AddSecurityLog(propertyId, title, desc, color)
    local p = Properties[propertyId]
    if not p then return end

    if not p.metadata then p.metadata = {} end
    p.metadata.security_log = p.metadata.security_log or {}

    table.insert(p.metadata.security_log, 1, {
        id = math.random(10000, 99999),
        title = title,
        desc = desc,
        date = os.date("%d/%m/%Y"),
        time = os.date("%H:%M"),
        color = color or "#3b82f6"
    })

    if #p.metadata.security_log > 20 then
        table.remove(p.metadata.security_log, 21)
    end

    SaveProperty(propertyId)
    TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
end

lib.callback.register('LNS_Housing:server:getProperties', function(source)
    WaitForDb()
    return Properties
end)

lib.callback.register('LNS_Housing:server:isDoorBreached', function(source, propertyId)
    if TemporaryAccess.doors[propertyId] and next(TemporaryAccess.doors[propertyId]) then
        return true
    end
    return false
end)

local function HasPermissionAccess(source, propertyId, type)
    return CheckPermission(source, 'house', propertyId, type, true)
end

RegisterNetEvent('LNS_Housing:server:lockpickSuccess', function(propertyId, type, stashId)
    local src = source
    local identifier = Bridge.Server.GetIdentifier(src)
    local isApartment = Properties[propertyId] == nil

    if not isApartment then
        local p = Properties[propertyId]
        if not p then return end

        if HasPermissionAccess(src, propertyId, type == 'stash' and 'storage' or 'entry') then
            return
        end

        if type == 'door' then
            if not TemporaryAccess.doors[propertyId] then TemporaryAccess.doors[propertyId] = {} end
            TemporaryAccess.doors[propertyId][identifier] = true

            FailedAttempts[propertyId] = 0

            local isShell = p.metadata and p.metadata.shell and p.metadata.shell ~= 'mlo'
            if isShell then
                p.metadata.locked = false
            end

            local securityLevel = p.metadata and p.metadata.security_level or 0
            if securityLevel >= 1 then
                TriggerHouseAlarm(propertyId)
            end
            AddSecurityLog(propertyId, "Break-in Detected", "Property door lock successfully bypassed/picked.", "#eab308")

            SetTimeout(60000 * 15, function()
                if TemporaryAccess.doors[propertyId] then
                    TemporaryAccess.doors[propertyId][identifier] = nil
                end
            end)
        elseif type == 'stash' then
            if not TemporaryAccess.stashes[propertyId] then TemporaryAccess.stashes[propertyId] = {} end
            TemporaryAccess.stashes[propertyId][identifier] = true

            SetTimeout(60000 * 15, function()
                if TemporaryAccess.stashes[propertyId] then
                    TemporaryAccess.stashes[propertyId][identifier] = nil
                end
            end)
        end
    else
        if CheckPermission(src, 'apartment', propertyId, type == 'stash' and 'storage' or 'entry') then
            return
        end

        if type == 'door' then
            if not TemporaryAccess.doors[propertyId] then TemporaryAccess.doors[propertyId] = {} end
            TemporaryAccess.doors[propertyId][identifier] = true

            if GetApartmentDoorId then
                local doorId = GetApartmentDoorId(propertyId)
                if doorId then
                    exports.ox_doorlock:setDoorState(doorId, 0)
                end
            end

            SetTimeout(60000 * 15, function()
                if TemporaryAccess.doors[propertyId] then
                    TemporaryAccess.doors[propertyId][identifier] = nil
                end
            end)
        elseif type == 'stash' then
            if not TemporaryAccess.stashes[propertyId] then TemporaryAccess.stashes[propertyId] = {} end
            TemporaryAccess.stashes[propertyId][identifier] = true

            SetTimeout(60000 * 15, function()
                if TemporaryAccess.stashes[propertyId] then
                    TemporaryAccess.stashes[propertyId][identifier] = nil
                end
            end)
        end
    end
end)

RegisterNetEvent('LNS_Housing:server:policeRaidDoor', function(propertyId, propertyType, doorId)
    local src = source
    local playerJob = Bridge.Server.GetPlayerJob(src)
    if not playerJob or playerJob.name ~= 'police' then
        return
    end

    local raidItem = Settings.Security.RaidItem
    local itemCount = exports.ox_inventory:Search(src, 'count', raidItem)
    if itemCount < 1 then
        Bridge.Server.Notify(src, 'You do not have the required breaching item!', 'error')
        return
    end

    if propertyType == 'apartment' then
        local doorName = "Apartment Room #" .. propertyId
        local existingDoor = exports.ox_doorlock:getDoorFromName(doorName)
        if existingDoor then
            doorId = existingDoor.id
        end
    end

    if doorId and doorId ~= 0 then
        exports.ox_doorlock:setDoorState(doorId, 0)

        local identifier = Bridge.Server.GetIdentifier(src)
        if not TemporaryAccess.doors[propertyId] then TemporaryAccess.doors[propertyId] = {} end
        TemporaryAccess.doors[propertyId][identifier] = true

        Bridge.Server.Notify(src, 'Door breached successfully!', 'success')
    else
        
        local p = Properties[propertyId]
        if p and p.metadata and p.metadata.entrance then
            p.metadata.locked = false
            SaveProperty(propertyId)

            local identifier = Bridge.Server.GetIdentifier(src)
            if not TemporaryAccess.doors[propertyId] then TemporaryAccess.doors[propertyId] = {} end
            TemporaryAccess.doors[propertyId][identifier] = true

            TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
            Bridge.Server.Notify(src, 'Door breached successfully!', 'success')
        end
    end
end)

RegisterNetEvent('LNS_Housing:server:policeRaidStash', function(propertyId)
    local src = source
    local playerJob = Bridge.Server.GetPlayerJob(src)
    if not playerJob or playerJob.name ~= 'police' then
        return
    end

    local raidItem = Settings.Security.RaidItem
    local itemCount = exports.ox_inventory:Search(src, 'count', raidItem)
    if itemCount < 1 then
        Bridge.Server.Notify(src, 'You do not have the required breaching item!', 'error')
        return
    end

    local identifier = Bridge.Server.GetIdentifier(src)
    if not TemporaryAccess.stashes[propertyId] then TemporaryAccess.stashes[propertyId] = {} end
    TemporaryAccess.stashes[propertyId][identifier] = true

    Bridge.Server.Notify(src, 'Storage breached successfully!', 'success')
end)

lib.callback.register('LNS_Housing:server:buyHouse', function(source, propertyId)
    WaitForDb()
    if Settings.RealEstate and Settings.RealEstate.OnlyBuyViaContracts then
        return false
    end

    local p = Properties[propertyId]
    if not p or p.owner then return false end
    if p.sale_type ~= 'direct' then return false end

    local money = Bridge.Server.GetBankMoney(source)

    if money >= tonumber(p.price) then
        Bridge.Server.RemoveBankMoney(source, p.price, "Bought House: " .. p.label)

        ProcessPropertySalePayout(propertyId, p.price)

        p.owner = Bridge.Server.GetIdentifier(source)
        SaveProperty(propertyId)
        SyncPropertyDoor(propertyId)

        MySQL.update.await('UPDATE housing_contracts SET status = ? WHERE property_id = ? AND status = ?', {'declined', propertyId, 'pending'})

        TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
        return true
    end
    return false
end)

CreateThread(function()
    while true do
        Wait(60000 * 60)
        local now = os.time()
        local rentConf = Settings.Rent or {
            RentPeriod = 604800,
            GracePeriod = 259200,
            RetrievalPeriod = 604800,
            LateFee = 250,
            MaxMissedPayments = 3,
            AutoEvict = true
        }

        for id, p in pairs(Properties) do
            if p.owner and p.sale_type == 'rent' then
                local lastPaid = p.metadata.last_rent_paid or 0
                if lastPaid > 0 then
                    local rentPeriod = rentConf.RentPeriod or 604800
                    local gracePeriod = rentConf.GracePeriod or 259200
                    local timeSincePaid = now - lastPaid

                    if timeSincePaid > rentPeriod then
                        local rentAmount = p.metadata.rent_amount or p.price or 1000
                        local autoPayEnabled = p.metadata.auto_pay ~= false

                        local paidSuccessfully = false
                        if autoPayEnabled then
                            local bankMoney = Bridge.Server.GetOfflineBankMoney(p.owner)
                            if bankMoney >= rentAmount then
                                if Bridge.Server.RemoveOfflineBankMoney(p.owner, rentAmount) then
                                    paidSuccessfully = true
                                    p.metadata.last_rent_paid = p.metadata.last_rent_paid + rentPeriod
                                    
                                    p.metadata.rent_history = p.metadata.rent_history or {}
                                    table.insert(p.metadata.rent_history, 1, {
                                        id = math.random(10000, 99999),
                                        date = os.date("%d/%m/%Y"),
                                        type = "Auto-Pay Rent",
                                        amount = rentAmount,
                                        status = "Paid"
                                    })
                                    
                                    if (p.metadata.rent_debt or 0) <= 0 then
                                        p.metadata.missed_payments = 0
                                        p.metadata.due_by = nil
                                        SyncPropertyDoor(id)
                                    end

                                    local tenant = Bridge.Server.IsPlayerOnline(p.owner)
                                    if tenant then
                                        Bridge.Server.Notify(tenant.PlayerData.source, string.format("Auto-pay processed successfully. Paid $%s rent for %s.", rentAmount, p.label), "success")
                                    end
                                end
                            end
                        end

                        if not paidSuccessfully then
                            p.metadata.missed_payments = (p.metadata.missed_payments or 0) + 1
                            local lateFee = rentConf.LateFee or 250
                            p.metadata.rent_debt = (p.metadata.rent_debt or 0) + rentAmount + lateFee
                            
                            p.metadata.rent_history = p.metadata.rent_history or {}
                            table.insert(p.metadata.rent_history, 1, {
                                id = math.random(10000, 99999),
                                date = os.date("%d/%m/%Y"),
                                type = "Missed Rent (Cycle)",
                                amount = rentAmount,
                                status = "Unpaid"
                            })
                            table.insert(p.metadata.rent_history, 1, {
                                id = math.random(10000, 99999),
                                date = os.date("%d/%m/%Y"),
                                type = "Late Fee Applied",
                                amount = lateFee,
                                status = "Unpaid"
                            })

                            if not p.metadata.due_by then
                                p.metadata.due_by = now + gracePeriod
                            end

                            p.metadata.last_rent_paid = p.metadata.last_rent_paid + rentPeriod

                            local tenant = Bridge.Server.IsPlayerOnline(p.owner)
                            if tenant then
                                Bridge.Server.Notify(tenant.PlayerData.source, string.format("Rent auto-pay failed or was disabled for %s! Late fee of $%s applied. Total debt: $%s.", p.label, lateFee, p.metadata.rent_debt), "error")
                            end
                        end

                        SaveProperty(id)
                        TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
                    end

                    if p.metadata.due_by then
                        local timeSinceDue = now - p.metadata.due_by

                        if now > p.metadata.due_by then
                            SyncPropertyDoor(id)

                            local retrievalPeriod = rentConf.RetrievalPeriod or 604800
                            local maxMissed = rentConf.MaxMissedPayments or 3
                            local shouldEvict = (now > p.metadata.due_by + retrievalPeriod) or ((p.metadata.missed_payments or 0) >= maxMissed)

                            if shouldEvict and rentConf.AutoEvict then
                                local oldOwner = p.owner
                                local tenantName = "Resident"
                                local tenant = Bridge.Server.IsPlayerOnline(oldOwner)
                                if tenant then
                                    tenantName = tenant.PlayerData.charinfo and (tenant.PlayerData.charinfo.firstname .. ' ' .. tenant.PlayerData.charinfo.lastname) or tenantName
                                    Bridge.Server.Notify(tenant.PlayerData.source, "You have been evicted from " .. p.label .. " due to unpaid rent debt!", "error")
                                end

                                ResetPropertyOwnershipData(id)

                                p.metadata.tenant_history = p.metadata.tenant_history or {}
                                table.insert(p.metadata.tenant_history, 1, {
                                    date = os.date("%d/%m/%Y %H:%M"),
                                    type = "Evicted",
                                    tenant = tenantName,
                                    citizenid = oldOwner,
                                    reason = "Auto-Eviction: Missed Payments limit reached"
                                })

                                SaveProperty(id)
                                SyncPropertyDoor(id)
                                TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
                            else
                                local tenant = Bridge.Server.IsPlayerOnline(p.owner)
                                if tenant then
                                    local timeLeft = math.max(0, math.ceil(((p.metadata.due_by + retrievalPeriod) - now) / 3600))
                                    local hoursOrDays = timeLeft > 24 and string.format("%d days", math.ceil(timeLeft/24)) or string.format("%d hours", timeLeft)
                                    Bridge.Server.Notify(tenant.PlayerData.source, string.format("Your access to %s is suspended! Settle outstanding debt of $%s. You have %s left to retrieve your items.", p.label, p.metadata.rent_debt, hoursOrDays), "error")
                                end
                            end
                        else
                            local tenant = Bridge.Server.IsPlayerOnline(p.owner)
                            if tenant then
                                local timeLeft = math.max(0, math.ceil((p.metadata.due_by - now) / 3600))
                                local hoursOrDays = timeLeft > 24 and string.format("%d days", math.ceil(timeLeft/24)) or string.format("%d hours", timeLeft)
                                Bridge.Server.Notify(tenant.PlayerData.source, string.format("Your rent for %s is overdue! You have %s left to pay $%s before lockout.", p.label, hoursOrDays, p.metadata.rent_debt), "warning")
                            end
                        end
                    end
                end
            end
        end
    end
end)

RegisterNetEvent('LNS_Housing:server:toggleLock', function(propertyId)
    local src = source
    local p = Properties[propertyId]
    if not p then return end

    local hasAccess = HasPermissionAccess(src, propertyId, 'entry') or HasPermissionAccess(src, propertyId, 'manage')

    if not hasAccess then
        Bridge.Server.Notify(src, 'You do not have key access to lock/unlock this property.', 'error')
        return
    end

    if p.metadata.locked == nil then
        p.metadata.locked = true
    end

    p.metadata.locked = not p.metadata.locked
    SaveProperty(propertyId)
    TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)

    local state = p.metadata.locked and 'locked' or 'unlocked'
    Bridge.Server.Notify(src, 'Property is now ' .. state .. '.', 'success')
end)

RegisterNetEvent('LNS_Housing:server:enterPropertyBucket', function(propertyId)
    local src = source
    SetPlayerRoutingBucket(src, propertyId)
end)

RegisterNetEvent('LNS_Housing:server:leavePropertyBucket', function()
    local src = source
    SetPlayerRoutingBucket(src, 0)
end)

FailedAttempts = {}

local function GetEntranceCoordsServer(p)
    if not p then return nil end

    if p.metadata and p.metadata.entrance then
        local ent = p.metadata.entrance
        return vec3(ent.x, ent.y, ent.z)
    end

    local doorId = p.door_id
    if (not doorId or doorId == 0) and p.doors and #p.doors > 0 then
        doorId = p.doors[1]
    end

    if doorId and doorId ~= 0 then
        local door = exports.ox_doorlock:getDoor(doorId)
        if door and door.coords then
            return vec3(door.coords.x, door.coords.y, door.coords.z)
        end
    end

    if p.zone_data and p.zone_data.points and #p.zone_data.points > 0 then
        local sumX, sumY, sumZ = 0, 0, 0
        local count = #p.zone_data.points
        for _, pt in ipairs(p.zone_data.points) do
            sumX = sumX + pt.x
            sumY = sumY + pt.y
            sumZ = sumZ + pt.z
        end
        return vec3(sumX / count, sumY / count, sumZ / count)
    end

    return nil
end

local ActiveAlarms = {}

function TriggerHouseAlarm(propertyId)
    if ActiveAlarms[propertyId] then return end

    local p = Properties[propertyId]
    if not p then return end

    local coords = GetEntranceCoordsServer(p)
    if not coords then return end

    ActiveAlarms[propertyId] = true
    local duration = Settings.Security.AlarmDuration or 30000

    TriggerClientEvent('LNS_Housing:client:triggerHouseAlarm', -1, coords, duration)

    if source and source > 0 then
        TriggerClientEvent('LNS_Housing:client:triggerDispatch', source, coords, p.label, 'House alarm triggered at ' .. p.label .. '!')
    end

    if p.owner then
        local onlineOwner = Bridge.Server.IsPlayerOnline(p.owner)
        if onlineOwner then
            Bridge.Server.Notify(onlineOwner.PlayerData.source, 'Your property alarm at ' .. p.label .. ' has been triggered!', 'error')
        end
    end

    AddSecurityLog(propertyId, "Alarm Triggered", "Security alarm triggered by unauthorized entry attempt.", "#ef4444")

    SetTimeout(duration, function()
        ActiveAlarms[propertyId] = nil
    end)
end

RegisterNetEvent('LNS_Housing:server:lockpickFailed', function(propertyId)
    local src = source
    local isApartment = Properties[propertyId] == nil
    if isApartment then return end

    local p = Properties[propertyId]
    if not p then return end

    if HasPermissionAccess(src, propertyId, 'entry') then
        return
    end

    local securityLevel = p.metadata and p.metadata.security_level or 0
    if securityLevel == 0 then return end

    FailedAttempts[propertyId] = (FailedAttempts[propertyId] or 0) + 1

    local threshold = Settings.Security.AlarmFailThreshold and Settings.Security.AlarmFailThreshold[securityLevel] or 3
    if FailedAttempts[propertyId] >= threshold then
        FailedAttempts[propertyId] = 0
        TriggerHouseAlarm(propertyId)
    end
end)

RegisterNetEvent('LNS_Housing:server:notifyPoliceFallback', function(message)
    local players = GetPlayers()
    for i = 1, #players do
        local pId = tonumber(players[i])
        local job = Bridge.Server.GetPlayerJob(pId)
        if job and job.name == 'police' then
            Bridge.Server.Notify(pId, message, 'warning')
        end
    end
end)

exports('ToggleLock', function(propertyId)
    local p = Properties[propertyId]
    if not p then return nil end
    if p.metadata.locked == nil then
        p.metadata.locked = true
    end
    p.metadata.locked = not p.metadata.locked
    SaveProperty(propertyId)
    SyncPropertyDoor(propertyId)
    TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
    return p.metadata.locked
end)

exports('GiveKey', function(propertyId, targetIdentifier)
    local p = Properties[propertyId]
    if not p then return false end
    if not p.permissions then
        p.permissions = { entry = {}, storage = {}, wardrobe = {}, manage = {} }
    end
    if not p.permissions.entry then p.permissions.entry = {} end

    for _, cid in ipairs(p.permissions.entry) do
        if cid == targetIdentifier then
            return true
        end
    end

    table.insert(p.permissions.entry, targetIdentifier)
    SaveProperty(propertyId)
    SyncPropertyDoor(propertyId)
    TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
    return true
end)

exports('RemoveKey', function(propertyId, targetIdentifier)
    local p = Properties[propertyId]
    if not p or not p.permissions then return false end

    local removed = false
    for category, list in pairs(p.permissions) do
        if type(list) == 'table' then
            for i = #list, 1, -1 do
                if list[i] == targetIdentifier then
                    table.remove(list, i)
                    removed = true
                end
            end
        end
    end

    if removed then
        SaveProperty(propertyId)
        SyncPropertyDoor(propertyId)
        TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
        return true
    end
    return false
end)

local LockedStashes = {}

RegisterNetEvent('LNS_Housing:server:toggleStashLock', function(propertyId, stashId)
    local src = source
    local isApartment = Properties[propertyId] == nil
    local hasAccess = CheckPermission(src, isApartment and 'apartment' or 'house', propertyId, 'storage')

    if not hasAccess then
        Bridge.Server.Notify(src, 'You do not have permission to lock/unlock this storage.', 'error')
        return
    end

    LockedStashes[stashId] = not LockedStashes[stashId]
    local state = LockedStashes[stashId] and 'locked' or 'unlocked'
    Bridge.Server.Notify(src, 'Storage is now ' .. state .. '.', 'success')
end)

lib.callback.register('LNS_Housing:server:isStashLocked', function(source, stashId)
    if LockedStashes[stashId] == nil then
        LockedStashes[stashId] = true
    end
    return LockedStashes[stashId]
end)