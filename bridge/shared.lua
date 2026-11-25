Bridge = {
    Client = {},
    Server = {},
    Framework = 'qbx',
    GarageScript = nil,
    PhoneScript = nil
}

-- Auto-detect active framework
if GetResourceState('qbx_core') == 'started' then
    Bridge.Framework = 'qbx'
elseif GetResourceState('es_extended') == 'started' then
    Bridge.Framework = 'esx'
end

-- Auto-detect active garage system
if GetResourceState('qbx_garages') == 'started' then
    Bridge.GarageScript = 'qbx_garages'
elseif GetResourceState('jg-advancedgarages') == 'started' then
    Bridge.GarageScript = 'jg-advancedgarages'
elseif GetResourceState('cd_garage') == 'started' then
    Bridge.GarageScript = 'cd_garage'
elseif GetResourceState('op-garages') == 'started' then
    Bridge.GarageScript = 'op-garages'
end

-- Auto-detect active phone script
if GetResourceState('sd-phone') == 'started' then
    Bridge.PhoneScript = 'sd-phone'
elseif GetResourceState('lb-phone') == 'started' then
    Bridge.PhoneScript = 'lb-phone'
elseif GetResourceState('roadphone') == 'started' then
    Bridge.PhoneScript = 'roadphone'
elseif GetResourceState('yseries') == 'started' then
    Bridge.PhoneScript = 'yseries'
end

-- Auto-detect active inventory system
if GetResourceState('ox_inventory') == 'started' then
    Bridge.Inventory = 'ox_inventory'
elseif GetResourceState('inventory') == 'started' then
    Bridge.Inventory = 'Chezza-Inventory'
end

local Settings = lib.load('shared.settings')

function Bridge.GetPoliceJobs()
    local configured = Settings and Settings.Security and Settings.Security.PoliceJobs
    if configured == nil then
        return { 'police' }
    end

    local jobs = {}
    local seen = {}

    if type(configured) == 'string' then
        if configured ~= '' then
            jobs[1] = configured
        end
    elseif type(configured) == 'table' then
        for _, jobName in ipairs(configured) do
            if type(jobName) == 'string' and jobName ~= '' and not seen[jobName] then
                seen[jobName] = true
                jobs[#jobs + 1] = jobName
            end
        end
        for key, value in pairs(configured) do
            if type(key) == 'string' and value == true and key ~= '' and not seen[key] then
                seen[key] = true
                jobs[#jobs + 1] = key
            end
        end
    end

    return jobs
end

function Bridge.IsPoliceJob(job)
    local jobName = type(job) == 'table' and job.name or job
    if type(jobName) ~= 'string' or jobName == '' then return false end

    for _, allowedJob in ipairs(Bridge.GetPoliceJobs()) do
        if jobName == allowedJob then
            return true
        end
    end

    return false
end

function Bridge.GetRealEstateAgencyJobs()
    local agencies = Settings and Settings.RealEstate and Settings.RealEstate.Agencies
    if type(agencies) ~= 'table' then return {} end

    local groups = {}
    for jobName, _ in pairs(agencies) do
        if type(jobName) == 'string' and jobName ~= '' then
            groups[jobName] = 0
        end
    end
    return groups
end

function Bridge.IsRealEstateAgencyJob(job)
    if Settings and Settings.RealEstate and Settings.RealEstate.AgentAccessUnowned == false then
        return false
    end

    local jobName = type(job) == 'table' and job.name or job
    if type(jobName) ~= 'string' or jobName == '' then return false end

    local agencies = Settings and Settings.RealEstate and Settings.RealEstate.Agencies
    return type(agencies) == 'table' and agencies[jobName] ~= nil
end

-- Apartment Buildings Helper Functions
function Bridge.GetApartmentBuildings()
    local apts = Settings and Settings.Apartments
    if not apts or apts.Enabled == false then return {} end

    local buildings = {}
    if apts.Buildings and type(apts.Buildings) == 'table' and #apts.Buildings > 0 then
        for i, b in ipairs(apts.Buildings) do
            local id = b.id or ('building_' .. i)
            local coords = b.coords or (b.entrance) or vec3(0, 0, 0)
            local bCoordsList = {}
            if b.breakerCoords then
                if type(b.breakerCoords) == 'table' and b.breakerCoords[1] ~= nil then
                    for _, bc in ipairs(b.breakerCoords) do
                        if bc and bc.x and bc.y and bc.z then
                            table.insert(bCoordsList, vec3(bc.x, bc.y, bc.z))
                        end
                    end
                elseif b.breakerCoords.x and b.breakerCoords.y and b.breakerCoords.z then
                    table.insert(bCoordsList, vec3(b.breakerCoords.x, b.breakerCoords.y, b.breakerCoords.z))
                end
            end

            table.insert(buildings, {
                id = id,
                label = b.label or ("Apartments " .. id),
                sprite = b.sprite or 475,
                color = b.color or 3,
                scale = b.scale or 0.8,
                coords = vec3(coords.x, coords.y, coords.z),
                entrance = b.entrance and vec3(b.entrance.x, b.entrance.y, b.entrance.z) or vec3(coords.x, coords.y, coords.z),
                ped = b.ped,
                pedmodel = b.pedmodel or `a_m_y_business_01`,
                breakerCoords = b.breakerCoords,
                breakerCoordsList = bCoordsList,
                type = b.type,
                shell = b.shell,
                shellCoords = b.shellCoords,
                ipl = b.ipl,
                spawnCoords = b.spawnCoords,
                wardrobe = b.wardrobe,
                stash = b.stash,
            })
        end
    elseif apts.Building and type(apts.Building) == 'table' then
        local b = apts.Building
        local coords = b.coords or vec3(-826.53, -700.2, 27.06)
        local bCoordsList = {}
        if b.breakerCoords then
            if type(b.breakerCoords) == 'table' and b.breakerCoords[1] ~= nil then
                for _, bc in ipairs(b.breakerCoords) do
                    if bc and bc.x and bc.y and bc.z then
                        table.insert(bCoordsList, vec3(bc.x, bc.y, bc.z))
                    end
                end
            elseif b.breakerCoords.x and b.breakerCoords.y and b.breakerCoords.z then
                table.insert(bCoordsList, vec3(b.breakerCoords.x, b.breakerCoords.y, b.breakerCoords.z))
            end
        end
        table.insert(buildings, {
            id = 'wiwang',
            label = b.label or "WIWANG Apartments",
            sprite = b.sprite or 475,
            color = b.color or 3,
            scale = b.scale or 0.8,
            coords = vec3(coords.x, coords.y, coords.z),
            entrance = vec3(coords.x, coords.y, coords.z),
            ped = b.ped,
            pedmodel = b.pedmodel or `a_m_y_business_01`,
            breakerCoords = b.breakerCoords,
            breakerCoordsList = bCoordsList,
            wardrobe = b.wardrobe,
            stash = b.stash,
        })
    end

    return buildings
end

function Bridge.GetApartmentBuildingById(buildingId, allowFallback)
    local buildings = Bridge.GetApartmentBuildings()
    if not buildings or #buildings == 0 then return nil end

    if buildingId then
        local bIdStr = tostring(buildingId):lower()
        for _, b in ipairs(buildings) do
            if tostring(b.id):lower() == bIdStr then
                return b
            end
        end
    end

    if allowFallback then
        return buildings[1]
    end

    return nil
end

function Bridge.GetNearestApartmentBuilding(coords)
    local buildings = Bridge.GetApartmentBuildings()
    if not buildings or #buildings == 0 then return nil end
    if not coords then return buildings[1] end

    local targetPos = vec3(coords.x, coords.y, coords.z)
    local nearest = buildings[1]
    local nearestDist = #(targetPos - nearest.coords)

    for i = 2, #buildings do
        local b = buildings[i]
        local dist = #(targetPos - b.coords)
        if dist < nearestDist then
            nearestDist = dist
            nearest = b
        end
    end

    return nearest
end

-- Check whether a furniture catalog entry counts toward a property's storage stash limit.
function Bridge.IsCountedStorageStash(itemData)
    if not itemData or not itemData.isStorage then return false end

    local isTrash = itemData.isTrash or itemData.type == 'trash' or itemData.isDisposal or itemData.type == 'disposal'
    if isTrash then return false end

    local isFridge = itemData.isFridge or itemData.type == 'fridge' or (itemData.id and tostring(itemData.id):lower():find('fridge') ~= nil)
    if isFridge then
        return Settings and Settings.Stash and Settings.Stash.CountFridgesInLimit == true or false
    end

    return true
end

-- Global Debug Print Utility using ox_lib print
function debugPrint(level, ...)
    if Settings and Settings.Debug and Settings.Debug.Prints then
        if level == 'error' then
            lib.print.error(...)
        elseif level == 'warn' then
            lib.print.warn(...)
        elseif level == 'info' then
            lib.print.info(...)
        elseif level == 'verbose' then
            lib.print.verbose(...)
        elseif level == 'debug' then
            lib.print.debug(...)
        else
            lib.print.debug(level, ...)
        end
    end
end

-- Global alias for ox_lib locale fallback
_L = locale