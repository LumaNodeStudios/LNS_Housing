fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'LumaNode Studios'
description 'LumaNode Studios - Advanced Housing System'
version '1.0.0'

ui_page 'web/dist/index.html'

files {
    'web/dist/index.html',
    'web/dist/**/*'
}

shared_scripts {
    '@ox_lib/init.lua',
    'shared/settings.lua',
    'bridge/shared.lua'
}

client_scripts {
    'bridge/client/framework.lua',
    'bridge/client/appearance.lua',
    'bridge/client/inventory.lua',
    'client/cl_door_utils.lua',
    'client/cl_housing.lua',
    'client/cl_creator.lua',
    'client/cl_furniture.lua',
    'client/cl_panel.lua',
    'client/cl_zoneCreator.lua',
    'client/cl_lawn.lua',
    'client/cl_apartments.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/server/framework.lua',
    'bridge/server/banking.lua',
    'bridge/server/inventory.lua',
    'server/sv_db.lua',
    'server/sv_housing.lua',
    'server/sv_apartments.lua'
}