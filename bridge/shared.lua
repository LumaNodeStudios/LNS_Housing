Bridge = {
    Client = {},
    Server = {},
    Framework = 'qbx',
    GarageScript = nil
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