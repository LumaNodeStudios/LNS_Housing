local Settings = lib.load('shared.settings')

function GetAgencyLabel(jobName)
    if not jobName then return 'Real Estate' end
    local agencyConfig = Settings.RealEstate.Agencies and Settings.RealEstate.Agencies[jobName]
    if agencyConfig and agencyConfig.label and agencyConfig.label ~= '' then
        return agencyConfig.label
    end

    local liveLabel = Bridge.Server.GetJobLabel(jobName)
    if liveLabel and liveLabel ~= '' then
        return liveLabel
    end

    local formatted = tostring(jobName):gsub("^%l", string.upper):gsub("_", " ")
    if not formatted:lower():find("real estate") and not formatted:lower():find("agency") then
        formatted = formatted .. " Real Estate"
    end
    return formatted
end

function IsKeyholder(source, targetId, isApartment)
    local identifier = Bridge.Server.GetIdentifier(source)
    if not identifier then return false end

    if isApartment then
        local rows = MySQL.query.await('SELECT citizenid, permissions FROM apartments WHERE room_id = ?', {targetId})
        if not rows then return false end

        for _, row in ipairs(rows) do
            if row.citizenid == identifier then return true end
            local perms = row.permissions and json.decode(row.permissions)
            if perms and type(perms) == 'table' then
                if perms.entry and type(perms.entry) == 'table' then
                    for _, cid in ipairs(perms.entry) do
                        if cid == identifier then return true end
                    end
                elseif #perms > 0 then
                    for _, cid in ipairs(perms) do
                        if cid == identifier then return true end
                    end
                end
            end
        end
        return false
    end

    local p = Properties[targetId]
    if not p then return false end

    if p.owner == identifier then return true end
    if p.permissions and type(p.permissions) == 'table' then
        if p.permissions.entry and type(p.permissions.entry) == 'table' then
            for _, cid in ipairs(p.permissions.entry) do
                if cid == identifier then return true end
            end
        elseif #p.permissions > 0 then
            for _, cid in ipairs(p.permissions) do
                if cid == identifier then return true end
            end
        end
    end
    return false
end

function HasPhysicalKey(source, targetId, isApartment)
    local pk = Settings.Security.PhysicalKeys
    if not pk or not pk.Enabled then return nil end

    local slots = exports.ox_inventory:Search(source, 'slots', pk.Item)
    if not slots or #slots == 0 then return false end

    local hasMatchingKey = false
    for _, slot in ipairs(slots) do
        local meta = slot.metadata or {}
        if meta.propertyId == targetId and (meta.isApartment == true) == (isApartment == true) then
            hasMatchingKey = true
            break
        end
    end

    if not hasMatchingKey then return false end

    if pk.RequireKeyholder then
        return IsKeyholder(source, targetId, isApartment)
    end

    return true
end

function CheckPermission(source, permType, targetId, actionType, ignoreTemp)
    debugPrint('info', 'CheckPermission called', {source = source, permType = permType, targetId = targetId, actionType = actionType, ignoreTemp = ignoreTemp})
    if permType == 'admin' then
        if Bridge.Framework == 'esx' then
            local ESX = exports['es_extended']:getSharedObject()
            local player = ESX.GetPlayerFromId(source)
            if player then
                local group = player.getGroup()
                return group == 'admin' or group == 'god' or group == 'superadmin'
            end
        else
            return IsPlayerAceAllowed(source, 'admin')
        end
        return false
    elseif permType == 'realestate' then
        local isAllowed = false
        local jobName = nil
        local gradeLevel = 0
        local isAdmin = false

        local allowedGroups = Settings.RealEstate.Groups
        if Bridge.Framework == 'qbx' then
            for _, group in ipairs(allowedGroups) do
                if IsPlayerAceAllowed(tostring(source), 'group.' .. group) or IsPlayerAceAllowed(tostring(source), group) then
                    isAdmin = true
                    break
                end
            end
        elseif Bridge.Framework == 'esx' then
            local ESX = exports['es_extended']:getSharedObject()
            local p = ESX.GetPlayerFromId(source)
            local playerGroup = p and p.getGroup()
            if playerGroup then
                for _, group in ipairs(allowedGroups) do
                    if playerGroup == group then
                        isAdmin = true
                        break
                    end
                end
            end
        end

        local playerJob = Bridge.Server.GetPlayerJob(source)
        if playerJob then
            local allowedJobs = Settings.RealEstate.Jobs
            for _, job in ipairs(allowedJobs) do
                if playerJob.name == job then
                    isAllowed = true
                    jobName = playerJob.name
                    gradeLevel = playerJob.grade
                    break
                end
            end
        end

        if isAdmin then
            isAllowed = true
            if not jobName then
                jobName = 'admin'
            end
            gradeLevel = 100
        end

        local data = {
            allowed = false,
            citizenid = Bridge.Server.GetIdentifier(source)
        }

        if isAllowed then
            local permConfig = Settings.RealEstate.Permissions
            local agencyConfig = Settings.RealEstate.Agencies and Settings.RealEstate.Agencies[jobName]

            local societyBalance = 0
            if gradeLevel >= (permConfig.ManageEmployees) and jobName ~= 'admin' then
                local societyName = agencyConfig and agencyConfig.society or jobName
                societyBalance = Bridge.Server.GetSocietyMoney(societyName) or 0
            end

            local citizenid = Bridge.Server.GetIdentifier(source)
            local createHouse = gradeLevel >= (permConfig.CreateHouse)
            local draftContract = gradeLevel >= (permConfig.DraftContract)
            local manageListings = gradeLevel >= (permConfig.ManageListings)
            local manageEmployees = gradeLevel >= (permConfig.ManageEmployees)
            local commissionRate = agencyConfig and agencyConfig.defaultCommission or 10

            data = {
                allowed = true,
                job = jobName,
                grade = gradeLevel,
                citizenid = citizenid,
                agencyLabel = GetAgencyLabel(jobName),
                societyBalance = societyBalance,
                defaultCommission = commissionRate,
                permissions = {
                    createHouse = createHouse,
                    draftContract = draftContract,
                    manageListings = manageListings,
                    manageEmployees = manageEmployees,
                }
            }
        end

        if actionType then
            if not data.allowed then return false end
            return data.permissions[actionType] == true
        end

        return data
    elseif permType == 'house' then
        local propertyId = targetId
        local accessType = actionType or 'entry'
        local p = Properties[propertyId]
        if not p then return false end

        if accessType == 'lockpick' then
            if Settings.Housing and not Settings.Housing.CanBreakIn then return false end
            local identifier = Bridge.Server.GetIdentifier(source)
            if not p.owner then return false end
            if p.owner == identifier then return false end
            if p.permissions and p.permissions['entry'] then
                for _, cid in ipairs(p.permissions['entry']) do
                    if cid == identifier then return false end
                end
            end
            return true
        end

        if accessType == 'lockpickStash' then
            if Settings.Housing and not Settings.Housing.CanBreakIn then return false end
            local identifier = Bridge.Server.GetIdentifier(source)
            if not p.owner then return false end
            if p.owner == identifier then return false end
            if p.permissions and p.permissions['storage'] then
                for _, cid in ipairs(p.permissions['storage']) do
                    if cid == identifier then return false end
                end
            end
            return true
        end

        if accessType == 'furniture' then
            local identifier = Bridge.Server.GetIdentifier(source)
            if not p.owner then return false end
            if p.owner == identifier then return true end
            if p.permissions and p.permissions['furniture'] then
                for _, cid in ipairs(p.permissions['furniture']) do
                    if cid == identifier then return true end
                end
            end
            return false
        end

        if not ignoreTemp then
            local playerJob = Bridge.Server.GetPlayerJob(source)
            if playerJob and playerJob.name == 'police' then
                if accessType ~= 'storage' and accessType ~= 'stash' then
                    return true
                end
            end
        end

        if accessType == 'entry' or accessType == 'doors' then
            local keyResult = HasPhysicalKey(source, propertyId, false)
            if keyResult ~= nil then
                return keyResult
            end
        end

        local identifier = Bridge.Server.GetIdentifier(source)
        local hasStandardAccess = false
        if not IsRentOverdue(p) then
            if p.owner == identifier then
                hasStandardAccess = true
            elseif p.permissions and type(p.permissions) == 'table' then
                if p.permissions[accessType] and type(p.permissions[accessType]) == 'table' then
                    for _, cid in ipairs(p.permissions[accessType]) do
                        if cid == identifier then
                            hasStandardAccess = true
                            break
                        end
                    end
                elseif (accessType == 'entry' or accessType == 'doors') and #p.permissions > 0 then
                    for _, cid in ipairs(p.permissions) do
                        if cid == identifier then
                            hasStandardAccess = true
                            break
                        end
                    end
                end
            end
        end

        if hasStandardAccess then return true end

        if IsRentOverdue(p) and IsRetrievalPeriodActive(p) then
            if accessType == 'storage' or accessType == 'stash' or accessType == 'wardrobe' or accessType == 'garage' then
                if p.owner == identifier then return true end
                if p.permissions and p.permissions[accessType] then
                    for _, cid in ipairs(p.permissions[accessType]) do
                        if cid == identifier then return true end
                    end
                end
            end
        end

        if not ignoreTemp then
            if accessType == 'entry' or accessType == 'doors' then
                if TemporaryAccess.doors[propertyId] and TemporaryAccess.doors[propertyId][identifier] then
                    return true
                end
            elseif accessType == 'storage' or accessType == 'stash' then
                if TemporaryAccess.stashes[propertyId] and TemporaryAccess.stashes[propertyId][identifier] then
                    return true
                end
            end
        end

        return false
    elseif permType == 'apartment' then
        local roomId = targetId
        local accessType = actionType or 'entry'

        if not ignoreTemp then
            local playerJob = Bridge.Server.GetPlayerJob(source)
            if playerJob and playerJob.name == 'police' then
                if accessType ~= 'storage' and accessType ~= 'stash' then
                    return true
                end
            end
        end

        if accessType == 'entry' or accessType == 'doors' then
            local keyResult = HasPhysicalKey(source, roomId, true)
            if keyResult ~= nil then
                return keyResult
            end
        end

        local citizenid = Bridge.Server.GetIdentifier(source)
        if not citizenid then return false end

        local license = GetPlayerIdentifierByType(source, 'license2')
        if not license or license == '' then
            license = GetPlayerIdentifierByType(source, 'license')
        end

        local isOwner = false
        if citizenid then
            local checkOwner = MySQL.single.await('SELECT id FROM apartments WHERE room_id = ? AND citizenid = ?', {roomId, citizenid})
            if checkOwner then
                isOwner = true
            end
        end

        if accessType == 'lockpick' then
            if Settings.Apartments and not Settings.Apartments.CanBreakIn then return false end
            if isOwner then return false end
            local result = MySQL.single.await('SELECT citizenid, permissions FROM apartments WHERE room_id = ?', {roomId})
            if not result then return false end
            local permissions = json.decode(result.permissions or '{"entry":[], "storage":[], "wardrobe":[], "furniture":[], "manage":[]}')
            if permissions['entry'] then
                for _, cid in ipairs(permissions['entry']) do
                    if cid == citizenid then return false end
                end
            end
            return true
        end

        if accessType == 'lockpickStash' then
            if Settings.Apartments and not Settings.Apartments.CanBreakIn then return false end
            if isOwner then return false end
            local result = MySQL.single.await('SELECT citizenid, permissions FROM apartments WHERE room_id = ?', {roomId})
            if not result then return false end
            local permissions = json.decode(result.permissions or '{"entry":[], "storage":[], "wardrobe":[], "furniture":[], "manage":[]}')
            if permissions['storage'] then
                for _, cid in ipairs(permissions['storage']) do
                    if cid == citizenid then return false end
                end
            end
            return true
        end

        if not ignoreTemp then
            if accessType == 'storage' or accessType == 'stash' then
                if TemporaryAccess.stashes[roomId] and TemporaryAccess.stashes[roomId][citizenid] then
                    return true
                end
            elseif accessType == 'entry' or accessType == 'doors' then
                if TemporaryAccess.doors[roomId] and TemporaryAccess.doors[roomId][citizenid] then
                    return true
                end
            end
        end

        local result = MySQL.single.await('SELECT citizenid, permissions FROM apartments WHERE room_id = ? ORDER BY id ASC LIMIT 1', {roomId})
        if result then
            if result.citizenid == citizenid then return true end
            
            local permissions = json.decode(result.permissions or '{"entry":[], "storage":[], "wardrobe":[], "furniture":[], "manage":[]}')
            if type(permissions) == 'table' then
                if permissions[accessType] and type(permissions[accessType]) == 'table' then
                    for _, cid in ipairs(permissions[accessType]) do
                        if cid == citizenid then return true end
                    end
                elseif (accessType == 'entry' or accessType == 'doors') and #permissions > 0 then
                    for _, cid in ipairs(permissions) do
                        if cid == citizenid then return true end
                    end
                end
            end
        end

        return false
    end

    return false
end

lib.callback.register('LNS_Housing:server:checkPermission', function(source, permType, targetId, actionType, ignoreTemp)
    return CheckPermission(source, permType, targetId, actionType, ignoreTemp)
end)

exports('CheckPermission', function(source, permType, targetId, actionType, ignoreTemp)
    return CheckPermission(source, permType, targetId, actionType, ignoreTemp)
end)