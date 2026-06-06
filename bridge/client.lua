Bridge.Client = {}

local ESX = Bridge.Framework == 'esx' and exports['es_extended']:getSharedObject() or nil

-- Framework Functions

function Bridge.Client.GetIdentifier()
    if Bridge.Framework == 'qbx' then
        local data = exports.qbx_core:GetPlayerData()
        return data and data.citizenid
    elseif Bridge.Framework == 'esx' then
        local data = ESX.GetPlayerData()
        return data and data.identifier
    end
end

function Bridge.Client.GetPlayerName()
    if Bridge.Framework == 'qbx' then
        local data = exports.qbx_core:GetPlayerData()
        if data and data.charinfo then
            return data.charinfo.firstname .. ' ' .. data.charinfo.lastname
        end
        return 'Unknown'
    elseif Bridge.Framework == 'esx' then
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
end

function Bridge.Client.GetPlayerJob()
    if Bridge.Framework == 'qbx' then
        local data = exports.qbx_core:GetPlayerData()
        if data and data.job then
            return {
                name = data.job.name,
                label = data.job.label,
                grade = data.job.grade.level,
                grade_name = data.job.grade.name
            }
        end
    elseif Bridge.Framework == 'esx' then
        local data = ESX.GetPlayerData()
        if data and data.job then
            return {
                name = data.job.name,
                label = data.job.label,
                grade = data.job.grade,
                grade_name = data.job.grade_label
            }
        end
    end
    return nil
end

-- Appearance / Wardrobe Function

function Bridge.Client.OpenWardrobe(propertyId, furnitureId)
    if GetResourceState('illenium-appearance') == 'started' then
        TriggerEvent('illenium-appearance:client:openOutfitMenu')
    else
        print('No clothing/appearance menu found!')
    end
end

-- Inventory / Stash Function

function Bridge.Client.OpenStash(propertyId, furnitureId)
    if GetResourceState('ox_inventory') == 'started' then
        local stashId = string.format('housing_%d_%s', propertyId, furnitureId)
        exports.ox_inventory:openInventory('stash', stashId)
    else
        print('No inventory found!')
    end
end