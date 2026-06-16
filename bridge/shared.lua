Bridge = {
    Client = {},
    Server = {},
    Framework = 'qbx'
}

if GetResourceState('qbx_core') == 'started' then
    Bridge.Framework = 'qbx'
elseif GetResourceState('es_extended') == 'started' then
    Bridge.Framework = 'esx'
end

Bridge.GarageScript = nil
if GetResourceState('qbx_garages') == 'started' then
    Bridge.GarageScript = 'qbx_garages'
elseif GetResourceState('jg-advancedgarages') == 'started' then
    Bridge.GarageScript = 'jg-advancedgarages'
end