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