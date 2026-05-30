if Bridge.Framework == 'qbx' then
    Bridge.Client.GetIdentifier = function()
        local data = exports.qbx_core:GetPlayerData()
        return data and data.citizenid
    end

    Bridge.Client.GetPlayerName = function()
        local data = exports.qbx_core:GetPlayerData()
        if data and data.charinfo then
            return data.charinfo.firstname .. ' ' .. data.charinfo.lastname
        end
        return 'Unknown'
    end

    Bridge.Client.GetPlayerJob = function()
        local data = exports.qbx_core:GetPlayerData()
        if data and data.job then
            return {
                name = data.job.name,
                label = data.job.label,
                grade = data.job.grade.level,
                grade_name = data.job.grade.name
            }
        end
        return nil
    end
elseif Bridge.Framework == 'esx' then
    local ESX = exports['es_extended']:getSharedObject()

    Bridge.Client.GetIdentifier = function()
        local data = ESX.GetPlayerData()
        return data and data.identifier
    end

    Bridge.Client.GetPlayerName = function()
        local data = ESX.GetPlayerData()
        if data then
            if data.firstName and data.lastName then
                return data.firstName .. ' ' .. data.lastName
            elseif data.name then
                return data.name
            end
        end
        return 'Unknown'
    end

    Bridge.Client.GetPlayerJob = function()
        local data = ESX.GetPlayerData()
        if data and data.job then
            return {
                name = data.job.name,
                label = data.job.label,
                grade = data.job.grade,
                grade_name = data.job.grade_label
            }
        end
        return nil
    end
end