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