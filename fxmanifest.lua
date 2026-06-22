fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'LumaNode Studios'
description 'LumaNode Studios - Advanced Housing System'
version '1.0.0'

ui_page 'web/dist/index.html'

files {
    'web/dist/index.html',
    'web/dist/**/*',
    'stream/[Shells]/*.ytyp',
    'stream/[Walls]/*.ytyp',
    'data/lns_data.dat54.rel',
    'audiodirectory/lns_bank.awc'
}

shared_scripts {
    '@ox_lib/init.lua',
    'shared/furniture.lua',
    'shared/settings.lua',
    'shared/sv_settings.lua',
    'bridge/shared.lua'
}

client_scripts {
    'bridge/client.lua',
    'client/cl_door_utils.lua',
    'client/cl_housing.lua',
    'client/cl_creator.lua',
    'client/cl_furniture.lua',
    'client/cl_panel.lua',
    'client/cl_zoneCreator.lua',
    'client/cl_lawn.lua',
    'client/cl_apartments.lua',
    'client/cl_screenshot.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/server.lua',
    'server/sv_db.lua',
    'server/sv_permissions.lua',
    'server/sv_housing.lua',
    'server/sv_creator.lua',
    'server/sv_furniture.lua',
    'server/sv_lawn.lua',
    'server/sv_panel.lua',
    'server/sv_apartments.lua',
    'server/sv_screenshot.lua',
    'server/sv_screenshot.js'
}

dependencies {
    'screencapture'
}

data_file 'DLC_ITYP_REQUEST' 'stream/[Shells]/starter_shells_k4mb1.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/[Shells]/ps_wall_aqua.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/[Shells]/ps_wall_black.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/[Shells]/ps_wall_green.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/[Shells]/ps_wall_grey.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/[Shells]/ps_wall_purple.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/[Shells]/ps_wall_red.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/[Shells]/ps_wall_wall.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/[Shells]/ps_wall_white.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/[Shells]/ps_wall_yellow.ytyp'

data_file 'AUDIO_WAVEPACK'  'sound/audiodirectory'
data_file 'AUDIO_SOUNDDATA' 'sound/data/lns_data.dat'