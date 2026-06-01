local function normalizeAmount(amount)
    local parsed = tonumber(amount)
    if not parsed or parsed ~= parsed then
        return nil
    end

    parsed = math.floor(parsed + 0.0)
    if parsed < 0 then
        return nil
    end

    return parsed
end

if Bridge.Framework == 'qbx' then
    Bridge.Server.GetBankMoney = function(source)
        return exports.qbx_core:GetMoney(source, 'bank') or 0
    end

    Bridge.Server.RemoveBankMoney = function(source, amount, reason)
        local player = exports.qbx_core:GetPlayer(source)
        local safeAmount = normalizeAmount(amount)
        if not player or not safeAmount or safeAmount <= 0 then
            return false
        end

        if player then
            player.Functions.RemoveMoney('bank', safeAmount, reason or "Property System")
            return true
        end

        return false
    end

    Bridge.Server.AddBankMoney = function(source, amount, reason)
        local player = exports.qbx_core:GetPlayer(source)
        local safeAmount = normalizeAmount(amount)
        if not player or not safeAmount or safeAmount <= 0 then
            return false
        end

        if player then
            player.Functions.AddMoney('bank', safeAmount, reason or "Property Commission")
            return true
        end

        return false
    end

    Bridge.Server.GetOfflineBankMoney = function(identifier)
        local result = MySQL.query.await('SELECT money FROM players WHERE citizenid = ?', {identifier})
        if result and result[1] then
            local money = json.decode(result[1].money)
            return money and money.bank or 0
        end
        return 0
    end

    Bridge.Server.RemoveOfflineBankMoney = function(identifier, amount)
        local safeAmount = normalizeAmount(amount)
        if not safeAmount or safeAmount <= 0 then
            return false
        end

        MySQL.update.await('UPDATE players SET money = JSON_SET(money, "$.bank", JSON_EXTRACT(money, "$.bank") - ?) WHERE citizenid = ?', {safeAmount, identifier})
        return true
    end

    Bridge.Server.AddOfflineBankMoney = function(identifier, amount)
        local safeAmount = normalizeAmount(amount)
        if not safeAmount or safeAmount <= 0 then
            return false
        end

        MySQL.update.await('UPDATE players SET money = JSON_SET(money, "$.bank", JSON_EXTRACT(money, "$.bank") + ?) WHERE citizenid = ?', {safeAmount, identifier})
        return true
    end

    Bridge.Server.AddSocietyMoney = function(job, amount)
        if GetResourceState('Renewed-Banking') == 'started' then
            exports['Renewed-Banking']:addAccountMoney(job, amount)
        else
            print('No Management System Found')
        end
    end

    Bridge.Server.RemoveSocietyMoney = function(job, amount)
        if GetResourceState('Renewed-Banking') == 'started' then
            exports['Renewed-Banking']:removeAccountMoney(job, amount)
        else
            print('No Management System Found')
        end
    end

    Bridge.Server.GetSocietyMoney = function(job)
        if GetResourceState('Renewed-Banking') == 'started' then
            return exports['Renewed-Banking']:getAccountMoney(job) or 0
        else
            return print('No Management System Found')
        end
    end
elseif Bridge.Framework == 'esx' then
    local ESX = exports['es_extended']:getSharedObject()

    Bridge.Server.GetBankMoney = function(source)
        local player = ESX.GetPlayerFromId(source)
        return player and player.getAccount('bank').money or 0
    end

    Bridge.Server.RemoveBankMoney = function(source, amount, reason)
        local player = ESX.GetPlayerFromId(source)
        local safeAmount = normalizeAmount(amount)
        if not player or not safeAmount or safeAmount <= 0 then
            return false
        end

        player.removeAccountMoney('bank', safeAmount)
        return true
    end

    Bridge.Server.AddBankMoney = function(source, amount, reason)
        local player = ESX.GetPlayerFromId(source)
        local safeAmount = normalizeAmount(amount)
        if not player or not safeAmount or safeAmount <= 0 then
            return false
        end

        player.addAccountMoney('bank', safeAmount)
        return true
    end

    Bridge.Server.GetOfflineBankMoney = function(identifier)
        local result = MySQL.query.await('SELECT accounts FROM users WHERE identifier = ?', {identifier})
        if result and result[1] then
            local accounts = json.decode(result[1].accounts)
            return accounts and accounts.bank or 0
        end
        return 0
    end

    Bridge.Server.RemoveOfflineBankMoney = function(identifier, amount)
        local safeAmount = normalizeAmount(amount)
        if not safeAmount or safeAmount <= 0 then
            return false
        end

        MySQL.update.await('UPDATE users SET accounts = JSON_SET(accounts, "$.bank", JSON_EXTRACT(accounts, "$.bank") - ?) WHERE identifier = ?', {safeAmount, identifier})
        return true
    end

    Bridge.Server.AddOfflineBankMoney = function(identifier, amount)
        local safeAmount = normalizeAmount(amount)
        if not safeAmount or safeAmount <= 0 then
            return false
        end

        MySQL.update.await('UPDATE users SET accounts = JSON_SET(accounts, "$.bank", JSON_EXTRACT(accounts, "$.bank") + ?) WHERE identifier = ?', {safeAmount, identifier})
        return true
    end

    Bridge.Server.AddSocietyMoney = function(job, amount)
        if GetResourceState('Renewed-Banking') == 'started' then
            exports['Renewed-Banking']:addAccountMoney(job, amount)
        else
            TriggerEvent('esx_addonaccount:getSharedAccount', 'society_' .. job, function(account)
                if account then
                    account.addMoney(amount)
                end
            end)
        end
    end

    Bridge.Server.RemoveSocietyMoney = function(job, amount)
        if GetResourceState('Renewed-Banking') == 'started' then
            exports['Renewed-Banking']:removeAccountMoney(job, amount)
        else
            TriggerEvent('esx_addonaccount:getSharedAccount', 'society_' .. job, function(account)
                if account then
                    account.removeMoney(amount)
                end
            end)
        end
    end

    Bridge.Server.GetSocietyMoney = function(job)
        if GetResourceState('Renewed-Banking') == 'started' then
            return exports['Renewed-Banking']:getAccountMoney(job) or 0
        else
            local money = 0
            TriggerEvent('esx_addonaccount:getSharedAccount', 'society_' .. job, function(account)
                if account then
                    money = account.money
                end
            end)
            return money
        end
    end
end