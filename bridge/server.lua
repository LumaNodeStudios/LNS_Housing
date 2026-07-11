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

-- Offline Player Money Management
function Bridge.Server.GetOfflineBankMoney(identifier)
    local onlinePlayer = Bridge.Server.IsPlayerOnline(identifier)
    if onlinePlayer then
        return Bridge.Server.GetBankMoney(onlinePlayer.PlayerData.source)
    end

    if not db then return 0 end
    local query = string.format('SELECT %s FROM %s WHERE %s = ?', db.column, db.table, db.key)
    local result = MySQL.query.await(query, {identifier})
    if result and result[1] then
        local data = json.decode(result[1][db.column])
        return data and data.bank or 0
    end
    return 0
end

function Bridge.Server.RemoveOfflineBankMoney(identifier, amount)
    local safeAmount = normalizeAmount(amount)
    if not safeAmount or safeAmount <= 0 then return false end

    local onlinePlayer = Bridge.Server.IsPlayerOnline(identifier)
    if onlinePlayer then
        return Bridge.Server.RemoveBankMoney(onlinePlayer.PlayerData.source, safeAmount, "Property Transaction")
    end

    if not db then return false end
    local query = string.format('UPDATE %s SET %s = JSON_SET(%s, "$.bank", JSON_EXTRACT(%s, "$.bank") - ?) WHERE %s = ?', db.table, db.column, db.column, db.column, db.key)
    MySQL.update.await(query, {safeAmount, identifier})
    return true
end

function Bridge.Server.AddOfflineBankMoney(identifier, amount)
    local safeAmount = normalizeAmount(amount)
    if not safeAmount or safeAmount <= 0 then return false end

    local onlinePlayer = Bridge.Server.IsPlayerOnline(identifier)
    if onlinePlayer then
        return Bridge.Server.AddBankMoney(onlinePlayer.PlayerData.source, safeAmount, "Property Transaction Payout")
    end

    if not db then return false end
    local query = string.format('UPDATE %s SET %s = JSON_SET(%s, "$.bank", JSON_EXTRACT(%s, "$.bank") + ?) WHERE %s = ?', db.table, db.column, db.column, db.column, db.key)
    MySQL.update.await(query, {safeAmount, identifier})
    return true
end

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

-- Online Player Money Management
function Bridge.Server.GetBankMoney(source)
    if Bridge.Framework == 'qbx' then
        return exports.qbx_core:GetMoney(source, 'bank') or 0
    elseif Bridge.Framework == 'esx' then
        local player = ESX.GetPlayerFromId(source)
        return player and player.getAccount('bank').money or 0
    end
end

function Bridge.Server.GetMoney(source, moneyType)
    if Bridge.Framework == 'qbx' then
        return exports.qbx_core:GetMoney(source, moneyType) or 0
    elseif Bridge.Framework == 'esx' then
        local player = ESX.GetPlayerFromId(source)
        if not player then return 0 end
        if moneyType == 'cash' then
            if player.getMoney then
                return player.getMoney() or 0
            else
                return player.getAccount('money') and player.getAccount('money').money or 0
            end
        else
            return player.getAccount('bank') and player.getAccount('bank').money or 0
        end
    end
end

function Bridge.Server.RemoveBankMoney(source, amount, reason)
    local safeAmount = normalizeAmount(amount)
    if not safeAmount or safeAmount <= 0 then return false end

    if Bridge.Framework == 'qbx' then
        return exports.qbx_core:RemoveMoney(source, 'bank', safeAmount, reason or "Property System")
    elseif Bridge.Framework == 'esx' then
        local player = ESX.GetPlayerFromId(source)
        if player then
            player.removeAccountMoney('bank', safeAmount)
            return true
        end
    end
    return false
end

function Bridge.Server.RemoveMoney(source, moneyType, amount, reason)
    local safeAmount = normalizeAmount(amount)
    if not safeAmount or safeAmount <= 0 then return false end

    if Bridge.Framework == 'qbx' then
        return exports.qbx_core:RemoveMoney(source, moneyType, safeAmount, reason or "Property System")
    elseif Bridge.Framework == 'esx' then
        local player = ESX.GetPlayerFromId(source)
        if player then
            if moneyType == 'cash' then
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

function Bridge.Server.AddBankMoney(source, amount, reason)
    local safeAmount = normalizeAmount(amount)
    if not safeAmount or safeAmount <= 0 then return false end

    if Bridge.Framework == 'qbx' then
        return exports.qbx_core:AddMoney(source, 'bank', safeAmount, reason or "Property Commission")
    elseif Bridge.Framework == 'esx' then
        local player = ESX.GetPlayerFromId(source)
        if player then
            player.addAccountMoney('bank', safeAmount)
            return true
        end
    end
    return false
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
            -- Idk yet
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
        print('No Management System Found')
        if action == 'get' then return 0 end
    end
end

function Bridge.Server.AddSocietyMoney(job, amount)
    handleSocietyMoney(job, amount, 'add')
end

function Bridge.Server.RemoveSocietyMoney(job, amount)
    handleSocietyMoney(job, amount, 'remove')
end

function Bridge.Server.GetSocietyMoney(job)
    return handleSocietyMoney(job, nil, 'get')
end

-- Stash / Inventory Integrations
function Bridge.Server.RegisterStash(propertyId, furnitureId, storageConfig, label)
    if GetResourceState('ox_inventory') == 'started' then
        local stashId = string.format('housing_%d_%s', propertyId, furnitureId)
        local slots = storageConfig and storageConfig.slots or Settings.Stash.slots
        local weight = storageConfig and storageConfig.weight or Settings.Stash.weight
        local stashLabel = label or Settings.Stash.label
        exports.ox_inventory:RegisterStash(stashId, stashLabel, slots, weight)
    else
        print('ox_inventory not started')
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
        end
    end
end

-- Job updates (Supports online players & database updates for offline players)
function Bridge.Server.SetPlayerJob(identifier, jobName, grade)
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
    lib.notify(source, {
        description = msg,
        type = type or 'inform'
    })
end

-- Server-side Garage Registration
function Bridge.Server.RegisterGarage(propertyId, label, garageData)
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
    -- Bomboclat
end