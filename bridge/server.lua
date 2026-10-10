Bridge.Server = {}

local Settings = lib.load('shared.settings')
local Furniture = lib.load('shared.furniture')
local ESX = Bridge.Framework == 'esx' and exports['es_extended']:getSharedObject() or nil

local function normalizeAmount(amount)
    local parsed = tonumber(amount)
    if not parsed or parsed ~= parsed then return nil end
    parsed = math.floor(parsed + 0.0)
    return parsed >= 0 and parsed or nil
end

local DB_CONFIG = {
    qbx = { table = 'players', column = 'money', key = 'citizenid' },
    esx = { table = 'users', column = 'accounts', key = 'identifier' }
}

local db = DB_CONFIG[Bridge.Framework]

-- Player Data & Framework Getters
function Bridge.Server.GetIdentifier(source)
    if Bridge.Framework == 'qbx' then
        local player = exports.qbx_core:GetPlayer(source)
        return player and player.PlayerData.citizenid
    elseif Bridge.Framework == 'esx' then
        local player = ESX.GetPlayerFromId(source)
        return player and player.identifier
    end
end

function Bridge.Server.GetPlayerName(source)
    if Bridge.Framework == 'qbx' then
        local player = exports.qbx_core:GetPlayer(source)
        if player and player.PlayerData.charinfo then
            return player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname
        end
        return 'Unknown'
    elseif Bridge.Framework == 'esx' then
        local player = ESX.GetPlayerFromId(source)
        return player and player.getName() or 'Unknown'
    end
end

function Bridge.Server.GetPlayerJob(source)
    if Bridge.Framework == 'qbx' then
        local player = exports.qbx_core:GetPlayer(source)
        if player and player.PlayerData.job then
            return {
                name = player.PlayerData.job.name,
                label = player.PlayerData.job.label,
                grade = player.PlayerData.job.grade.level,
                grade_name = player.PlayerData.job.grade.name
            }
        end
    elseif Bridge.Framework == 'esx' then
        local player = ESX.GetPlayerFromId(source)
        if player and player.job then
            return {
                name = player.job.name,
                label = player.job.label,
                grade = player.job.grade,
                grade_name = player.job.grade_label
            }
        end
    end
    return nil
end

function Bridge.Server.GetJobLabel(jobName)
    if not jobName then return nil end
    if Bridge.Framework == 'qbx' then
        local ok, jobs = pcall(function() return exports.qbx_core:GetJobs() end)
        if ok and jobs and jobs[jobName] and jobs[jobName].label then
            return jobs[jobName].label
        end
    elseif Bridge.Framework == 'esx' then
        if ESX and ESX.GetJobs then
            local ok, jobs = pcall(function() return ESX.GetJobs() end)
            if ok and jobs and jobs[jobName] and jobs[jobName].label then
                return jobs[jobName].label
            end
        end
    end
    return nil
end

function Bridge.Server.IsPlayerOnline(identifier)
    if Bridge.Framework == 'qbx' then
        return exports.qbx_core:GetPlayerByCitizenId(identifier)
    elseif Bridge.Framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
        if not xPlayer then return nil end
        return {
            PlayerData = {
                source = xPlayer.source
            }
        }
    end
end

function Bridge.Server.CreateUseableItem(name, callback)
    if Bridge.Framework == 'qbx' then
        exports.qbx_core:CreateUseableItem(name, function(source, item)
            callback(source)
        end)
    elseif Bridge.Framework == 'esx' then
        ESX.RegisterUsableItem(name, function(source)
            callback(source)
        end)
    end
end

function Bridge.Server.Logout(source)
    if Bridge.Framework == 'qbx' then
        exports.qbx_core:Logout(source)
    elseif Bridge.Framework == 'esx' then
        TriggerEvent('esx:playerLogout', source)
    end
end

-- Unified Online Player Money Management
function Bridge.Server.GetMoney(source, moneyType)
    moneyType = moneyType or 'bank'
    if Bridge.Framework == 'qbx' then
        return exports.qbx_core:GetMoney(source, moneyType) or 0
    elseif Bridge.Framework == 'esx' then
        local player = ESX.GetPlayerFromId(source)
        if not player then return 0 end
        if moneyType == 'cash' or moneyType == 'money' then
            if player.getMoney then
                return player.getMoney() or 0
            else
                local account = player.getAccount('money')
                return account and account.money or 0
            end
        else
            local account = player.getAccount('bank')
            return account and account.money or 0
        end
    end
    return 0
end

function Bridge.Server.GetBankMoney(source)
    return Bridge.Server.GetMoney(source, 'bank')
end

function Bridge.Server.AddMoney(source, moneyType, amount, reason)
    moneyType = moneyType or 'bank'
    debugPrint('info', 'Bridge.Server.AddMoney', {source = source, moneyType = moneyType, amount = amount, reason = reason})
    local safeAmount = normalizeAmount(amount)
    if not safeAmount or safeAmount <= 0 then return false end

    if Bridge.Framework == 'qbx' then
        return exports.qbx_core:AddMoney(source, moneyType, safeAmount, reason or "Property System Payout")
    elseif Bridge.Framework == 'esx' then
        local player = ESX.GetPlayerFromId(source)
        if player then
            if moneyType == 'cash' or moneyType == 'money' then
                if player.addMoney then
                    player.addMoney(safeAmount)
                else
                    player.addAccountMoney('money', safeAmount)
                end
            else
                player.addAccountMoney('bank', safeAmount)
            end
            return true
        end
    end
    return false
end

function Bridge.Server.AddBankMoney(source, amount, reason)
    return Bridge.Server.AddMoney(source, 'bank', amount, reason)
end

function Bridge.Server.RemoveMoney(source, moneyType, amount, reason)
    moneyType = moneyType or 'bank'
    debugPrint('info', 'Bridge.Server.RemoveMoney', {source = source, moneyType = moneyType, amount = amount, reason = reason})
    local safeAmount = normalizeAmount(amount)
    if not safeAmount or safeAmount <= 0 then return false end

    if Bridge.Framework == 'qbx' then
        return exports.qbx_core:RemoveMoney(source, moneyType, safeAmount, reason or "Property System")
    elseif Bridge.Framework == 'esx' then
        local player = ESX.GetPlayerFromId(source)
        if player then
            if moneyType == 'cash' or moneyType == 'money' then
                if player.removeMoney then
                    player.removeMoney(safeAmount)
                else
                    player.removeAccountMoney('money', safeAmount)
                end
            else
                player.removeAccountMoney('bank', safeAmount)
            end
            return true
        end
    end
    return false
end

function Bridge.Server.RemoveBankMoney(source, amount, reason)
    return Bridge.Server.RemoveMoney(source, 'bank', amount, reason)
end

-- Unified Offline Player Money Management
function Bridge.Server.GetOfflineMoney(identifier, moneyType)
    moneyType = moneyType or 'bank'
    debugPrint('info', 'Bridge.Server.GetOfflineMoney', {identifier = identifier, moneyType = moneyType})
    local onlinePlayer = Bridge.Server.IsPlayerOnline(identifier)
    if onlinePlayer then
        return Bridge.Server.GetMoney(onlinePlayer.PlayerData.source, moneyType)
    end

    if not db then return 0 end
    local query = string.format('SELECT %s FROM %s WHERE %s = ?', db.column, db.table, db.key)
    local result = MySQL.query.await(query, {identifier})
    if result and result[1] then
        local data = json.decode(result[1][db.column])
        return data and data[moneyType] or 0
    end
    return 0
end

function Bridge.Server.GetOfflineBankMoney(identifier)
    return Bridge.Server.GetOfflineMoney(identifier, 'bank')
end

function Bridge.Server.RemoveOfflineMoney(identifier, moneyType, amount)
    moneyType = moneyType or 'bank'
    debugPrint('info', 'Bridge.Server.RemoveOfflineMoney', {identifier = identifier, moneyType = moneyType, amount = amount})
    local safeAmount = normalizeAmount(amount)
    if not safeAmount or safeAmount <= 0 then return false end

    local onlinePlayer = Bridge.Server.IsPlayerOnline(identifier)
    if onlinePlayer then
        return Bridge.Server.RemoveMoney(onlinePlayer.PlayerData.source, moneyType, safeAmount, "Property Transaction")
    end

    if not db then return false end
    local query = string.format('UPDATE %s SET %s = JSON_SET(%s, "$.%s", JSON_EXTRACT(%s, "$.%s") - ?) WHERE %s = ?', db.table, db.column, db.column, moneyType, db.column, moneyType, db.key)
    MySQL.update.await(query, {safeAmount, identifier})
    return true
end

function Bridge.Server.RemoveOfflineBankMoney(identifier, amount)
    return Bridge.Server.RemoveOfflineMoney(identifier, 'bank', amount)
end

function Bridge.Server.AddOfflineMoney(identifier, moneyType, amount)
    moneyType = moneyType or 'bank'
    debugPrint('info', 'Bridge.Server.AddOfflineMoney', {identifier = identifier, moneyType = moneyType, amount = amount})
    local safeAmount = normalizeAmount(amount)
    if not safeAmount or safeAmount <= 0 then return false end

    local onlinePlayer = Bridge.Server.IsPlayerOnline(identifier)
    if onlinePlayer then
        return Bridge.Server.AddMoney(onlinePlayer.PlayerData.source, moneyType, safeAmount, "Property Transaction Payout")
    end

    if not db then return false end
    local query = string.format('UPDATE %s SET %s = JSON_SET(%s, "$.%s", JSON_EXTRACT(%s, "$.%s") + ?) WHERE %s = ?', db.table, db.column, db.column, moneyType, db.column, moneyType, db.key)
    MySQL.update.await(query, {safeAmount, identifier})
    return true
end

function Bridge.Server.AddOfflineBankMoney(identifier, amount)
    return Bridge.Server.AddOfflineMoney(identifier, 'bank', amount)
end

-- Society / Account Management
local function handleSocietyMoney(job, amount, action)
    if GetResourceState('Renewed-Banking') == 'started' then
        if action == 'add' then
            exports['Renewed-Banking']:addAccountMoney(job, amount)
        elseif action == 'remove' then
            exports['Renewed-Banking']:removeAccountMoney(job, amount)
        elseif action == 'get' then
            return exports['Renewed-Banking']:getAccountMoney(job) or 0
        end
    elseif GetResourceState('oneclub_banking') == 'started' then
        if action == 'add' then
            exports.oneclub_banking:PayIntoSocietyFund(job, amount)
        elseif action == 'remove' then
            exports.oneclub_banking:RemoveFromSocietyFund(job, amount)
        elseif action == 'get' then
            return 0
        end
    elseif Bridge.Framework == 'esx' then
        local val = 0
        TriggerEvent('esx_addonaccount:getSharedAccount', 'society_' .. job, function(account)
            if account then
                if action == 'add' then
                    account.addMoney(amount)
                elseif action == 'remove' then
                    account.removeMoney(amount)
                elseif action == 'get' then
                    val = account.money
                end
            end
        end)
        if action == 'get' then return val end
    else
        debugPrint('warn', 'No Management System Found for society money')
        if action == 'get' then return 0 end
    end
end

function Bridge.Server.AddSocietyMoney(job, amount)
    debugPrint('info', 'Bridge.Server.AddSocietyMoney', {job = job, amount = amount})
    handleSocietyMoney(job, amount, 'add')
end

function Bridge.Server.RemoveSocietyMoney(job, amount)
    debugPrint('info', 'Bridge.Server.RemoveSocietyMoney', {job = job, amount = amount})
    handleSocietyMoney(job, amount, 'remove')
end

function Bridge.Server.GetSocietyMoney(job)
    debugPrint('info', 'Bridge.Server.GetSocietyMoney', {job = job})
    return handleSocietyMoney(job, nil, 'get')
end

-- Stash / Inventory Integrations
function Bridge.Server.RegisterStash(propertyId, furnitureId, storageConfig, label)
    debugPrint('info', 'Bridge.Server.RegisterStash', {propertyId = propertyId, furnitureId = furnitureId, storageConfig = storageConfig, label = label})
    local stashId, stashLabel, slots, weight
    if furnitureId and (type(furnitureId) == 'string' or type(furnitureId) == 'number') and not storageConfig and not label and type(propertyId) == 'number' then
        stashId = string.format('housing_%s_%s', tostring(propertyId), tostring(furnitureId))
        stashLabel = Settings.Stash.label
        slots = Settings.Stash.slots
        weight = Settings.Stash.weight
    elseif furnitureId and (type(furnitureId) == 'string' or type(furnitureId) == 'number') then
        stashId = string.format('housing_%s_%s', tostring(propertyId), tostring(furnitureId))
        slots = storageConfig and storageConfig.slots or Settings.Stash.slots
        weight = storageConfig and storageConfig.weight or Settings.Stash.weight
        stashLabel = label or (storageConfig and storageConfig.label) or Settings.Stash.label
    else
        stashId = tostring(propertyId)
        stashLabel = furnitureId or Settings.Stash.label
        slots = (type(storageConfig) == 'table' and storageConfig.slots) or (type(storageConfig) == 'number' and storageConfig) or Settings.Stash.slots
        weight = (type(storageConfig) == 'table' and storageConfig.weight) or (type(label) == 'number' and label) or Settings.Stash.weight
    end

    if Bridge.Inventory == 'ox_inventory' then
        exports.ox_inventory:RegisterStash(stashId, stashLabel, slots, weight)
    else
        debugPrint('warn', 'No supported inventory found or started for RegisterStash')
    end
end

function Bridge.Server.Search(source, searchType, item, metadata)
    debugPrint('info', 'Bridge.Server.Search', {source = source, searchType = searchType, item = item})
    if Bridge.Inventory == 'ox_inventory' then
        return exports.ox_inventory:Search(source, searchType, item, metadata)
    end
    return searchType == 'count' and 0 or {}
end

function Bridge.Server.AddItem(source, item, count, metadata, slot)
    debugPrint('info', 'Bridge.Server.AddItem', {source = source, item = item, count = count, slot = slot})
    if Bridge.Inventory == 'ox_inventory' then
        return exports.ox_inventory:AddItem(source, item, count, metadata, slot)
    end
    return false
end

function Bridge.Server.RemoveItem(source, item, count, metadata, slot)
    debugPrint('info', 'Bridge.Server.RemoveItem', {source = source, item = item, count = count, slot = slot})
    if Bridge.Inventory == 'ox_inventory' then
        return exports.ox_inventory:RemoveItem(source, item, count, metadata, slot)
    end
    return false
end

function Bridge.Server.ClearInventory(invId, keepItems)
    debugPrint('info', 'Bridge.Server.ClearInventory', {invId = invId})
    if not invId then return false end
    if Bridge.Inventory == 'ox_inventory' then
        return exports.ox_inventory:ClearInventory(invId, keepItems)
    end
    return false
end

function Bridge.Server.GetInventory(invId)
    if not invId then return nil end
    if Bridge.Inventory == 'ox_inventory' then
        return exports.ox_inventory:GetInventory(invId)
    end
    return nil
end

function Bridge.Server.GetInventoryItems(invId)
    local inv = Bridge.Server.GetInventory(invId)
    return inv and inv.items or {}
end

function Bridge.Server.RegisterInventoryHook(event, cb, options)
    debugPrint('info', 'Bridge.Server.RegisterInventoryHook', {event = event})
    if Bridge.Inventory == 'ox_inventory' then
        return exports.ox_inventory:registerHook(event, cb, options)
    end
    return nil
end

function Bridge.Server.GetItemDef(itemName)
    if not itemName then return nil end
    if Bridge.Inventory == 'ox_inventory' then
        return exports.ox_inventory:Items(itemName)
    end
    return nil
end

function Bridge.Server.SetItemMetadata(invId, slot, metadata)
    if not invId or not slot then return false end
    if Bridge.Inventory == 'ox_inventory' then
        return exports.ox_inventory:SetMetadata(invId, slot, metadata)
    end
    return false
end

function Bridge.Server.OnClosedInventory(cb)
    if Bridge.Inventory == 'ox_inventory' then
        AddEventHandler('ox_inventory:closedInventory', function(playerId, invId)
            cb(playerId, invId)
        end)
    end
end

function Bridge.Server.IsInventoryStarted()
    if Bridge.Inventory == 'ox_inventory' then
        return GetResourceState('ox_inventory') == 'started'
    end
    return false
end

function Bridge.Server.GetOfflineKeyCount(propertyId, isApartment, itemName, onlineIdentifiers)
    if not itemName then return 0 end
    onlineIdentifiers = onlineIdentifiers or {}
    local count = 0

    if Bridge.Inventory == 'ox_inventory' then
        local success, rows = pcall(MySQL.query.await, 'SELECT name, data FROM ox_inventory WHERE data LIKE ?', {'%' .. itemName .. '%'})
        if success and rows then
            for _, row in ipairs(rows) do
                local isOnline = false
                for onlineId in pairs(onlineIdentifiers) do
                    if string.find(row.name, onlineId, 1, true) then
                        isOnline = true
                        break
                    end
                end

                if not isOnline then
                    local data = json.decode(row.data)
                    if data then
                        for _, item in pairs(data) do
                            if item.name == itemName and item.metadata then
                                local meta = item.metadata
                                local match = (meta.propertyId == propertyId or tostring(meta.propertyId) == tostring(propertyId) or (tonumber(meta.propertyId) and tonumber(meta.propertyId) == tonumber(propertyId)))
                                if match and (meta.isApartment == true) == (isApartment == true) then
                                    count = count + (item.count or 1)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return count
end

function Bridge.Server.RemoveOfflineKeys(propertyId, itemName)
    if not itemName then return end

    if Bridge.Inventory == 'ox_inventory' then
        local success, rows = pcall(MySQL.query.await, 'SELECT name, data FROM ox_inventory WHERE data LIKE ?', {'%' .. itemName .. '%'})
        if success and rows then
            for _, row in ipairs(rows) do
                local data = json.decode(row.data)
                if data then
                    local modified = false
                    local newItems = {}
                    for slotIdx, item in pairs(data) do
                        if item and item.name == itemName and item.metadata and (item.metadata.propertyId == propertyId or tonumber(item.metadata.propertyId) == tonumber(propertyId) or tostring(item.metadata.propertyId) == tostring(propertyId)) and not item.metadata.isApartment then
                            modified = true
                        else
                            newItems[slotIdx] = item
                        end
                    end
                    if modified then
                        MySQL.update.await('UPDATE ox_inventory SET data = ? WHERE name = ?', {json.encode(newItems), row.name})
                    end
                end
            end
        end
    end
end

function Bridge.Server.RegisterPropertyStashes(propertyId, furnitureList)
    if not furnitureList then return end
    for _, f in ipairs(furnitureList) do
        local itemData = nil
        for _, cat in ipairs(Furniture) do
            for _, item in ipairs(cat.items) do
                if (tonumber(item.model) or GetHashKey(item.model)) == (tonumber(f.model) or GetHashKey(f.model)) then
                    itemData = item
                    break
                end
            end
            if itemData then break end
        end

        if itemData and itemData.isStorage then
            Bridge.Server.RegisterStash(propertyId, f.id, itemData.storage, f.label)
            local isFridge = itemData.isFridge or itemData.type == 'fridge'
            if isFridge and RegisterFridgeStash then
                local stashId = string.format('housing_%s_%s', tostring(propertyId), tostring(f.id))
                RegisterFridgeStash(stashId, propertyId, f.id)
            end
            local isTrash = itemData.isTrash or itemData.type == 'trash' or itemData.isDisposal or itemData.type == 'disposal'
            if isTrash and RegisterTrashStash then
                local stashId = string.format('housing_%s_%s', tostring(propertyId), tostring(f.id))
                RegisterTrashStash(stashId, propertyId, f.id)
            end
        end
    end
end

-- Job updates (Supports online players & database updates for offline players)
function Bridge.Server.SetPlayerJob(identifier, jobName, grade)
    debugPrint('info', 'Bridge.Server.SetPlayerJob', {identifier = identifier, jobName = jobName, grade = grade})
    local onlinePlayer = Bridge.Server.IsPlayerOnline(identifier)
    if onlinePlayer then
        local src = onlinePlayer.PlayerData.source
        if Bridge.Framework == 'qbx' then
            exports.qbx_core:SetJob(src, jobName, grade)
            return true
        elseif Bridge.Framework == 'esx' then
            local xPlayer = ESX.GetPlayerFromId(src)
            if xPlayer then
                xPlayer.setJob(jobName, grade)
                return true
            end
        end
    end

    if Bridge.Framework == 'qbx' then
        local result = MySQL.query.await('SELECT job FROM players WHERE citizenid = ?', {identifier})
        if result and result[1] then
            local jobData = json.decode(result[1].job or '{}')
            jobData.name = jobName
            jobData.grade = jobData.grade or {}
            jobData.grade.level = grade
            local rows = MySQL.update.await('UPDATE players SET job = ? WHERE citizenid = ?', {json.encode(jobData), identifier})
            return rows > 0
        end
    elseif Bridge.Framework == 'esx' then
        local rows = MySQL.update.await('UPDATE users SET job = ?, job_grade = ? WHERE identifier = ?', {jobName, grade, identifier})
        return rows > 0
    end
    return false
end

-- Server-side Notifications
function Bridge.Server.Notify(source, msg, type)
    debugPrint('info', 'Bridge.Server.Notify', {source = source, msg = msg, type = type})
    lib.notify(source, {
        description = msg,
        type = type or 'inform'
    })
end

-- Server-side Garage Registration
function Bridge.Server.RegisterGarage(propertyId, label, garageData)
    debugPrint('info', 'Bridge.Server.RegisterGarage', {propertyId = propertyId, label = label, garageData = garageData})
    if Bridge.GarageScript == 'qbx_garages' then
        local garageName = string.format("property-%s-garage", propertyId)
        local spawn = garageData.spawn or garageData
        local config = {
            label = label or string.format("Property Garage %s", propertyId),
            vehicleType = "car",
            accessPoints = {
                {
                    coords = vector3(garageData.x, garageData.y, garageData.z),
                    spawn = vector4(spawn.x, spawn.y, spawn.z, spawn.h or 0.0),
                    dropPoint = vector3(garageData.x, garageData.y, garageData.z)
                }
            },
            canAccess = function(source)
                return CheckPermission(source, 'house', propertyId, 'entry')
            end
        }
        exports.qbx_garages:RegisterGarage(garageName, config)
    end
end

function Bridge.Server.UnregisterGarage(propertyId)
    debugPrint('info', 'Bridge.Server.UnregisterGarage', {propertyId = propertyId})
    -- Handled automatically or per garage script
end

-- Phone Scripts
function Bridge.Server.PhoneNotification(source, data)
    debugPrint('info', 'Bridge.Server.PhoneNotification', {source = source, data = data})
    if Bridge.PhoneScript == 'yseries' then
        exports.yseries:SendNotification({
            title = data.title,
            text = data.body,
        }, 'source', source)
        return true
    end
    return false
end

RegisterNetEvent('LNS_Housing:server:motionAlert', function(propertyLabel)
    local src = source
    debugPrint('info', 'LNS_Housing:server:motionAlert event received', {src = src, propertyLabel = propertyLabel})
    if type(propertyLabel) ~= 'string' then return end

    Bridge.Server.PhoneNotification(src, {
        title = 'Home Security',
        body = ('Motion detected at the front door of %s!'):format(propertyLabel)
    })
end)

function Bridge.Server.SetPlayerInside(source, propertyId)
    if not source or not propertyId then return end
    propertyId = tonumber(propertyId)

    if Bridge.Framework == 'qbx' then
        local player = exports.qbx_core:GetPlayer(source)
        if not player then return end

        player.PlayerData.metadata = player.PlayerData.metadata or {}
        player.PlayerData.metadata.lnsProperty = {
            type = 'house',
            id = propertyId
        }
        player.PlayerData.metadata.currentPropertyId = propertyId
        player.PlayerData.metadata.inside = {
            house = propertyId,
            apartment = {
                apartmentType = nil,
                apartmentId = nil
            }
        }

        if Properties and Properties[propertyId] and GetEntranceCoordsServer then
            local entCoords = GetEntranceCoordsServer(Properties[propertyId])
            if entCoords then
                player.PlayerData.position = vec4(entCoords.x, entCoords.y, entCoords.z, 0.0)
            end
        end

        if player.Functions and player.Functions.SetMetaData then
            player.Functions.SetMetaData('lnsProperty', player.PlayerData.metadata.lnsProperty)
            player.Functions.SetMetaData('currentPropertyId', player.PlayerData.metadata.currentPropertyId)
            player.Functions.SetMetaData('inside', player.PlayerData.metadata.inside)
        end
    end
end

function Bridge.Server.ClearPlayerInside(source)
    if not source then return end

    if Bridge.Framework == 'qbx' then
        local player = exports.qbx_core:GetPlayer(source)
        if not player then return end

        player.PlayerData.metadata = player.PlayerData.metadata or {}
        player.PlayerData.metadata.lnsProperty = nil
        player.PlayerData.metadata.currentPropertyId = nil
        player.PlayerData.metadata.inside = {
            house = nil,
            apartment = {
                apartmentType = nil,
                apartmentId = nil
            }
        }

        if player.Functions and player.Functions.SetMetaData then
            player.Functions.SetMetaData('lnsProperty', nil)
            player.Functions.SetMetaData('currentPropertyId', nil)
            player.Functions.SetMetaData('inside', player.PlayerData.metadata.inside)
        end
    end
end