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

-- Global Debug Print Utility using ox_lib print
function debugPrint(level, ...)
    local Settings = lib.load('shared.settings')
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