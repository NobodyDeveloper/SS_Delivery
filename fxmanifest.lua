fx_version 'cerulean'
game 'gta5'

author 'ShoeShuffler'
name 'Shuffle-Shop Delivery'
description 'A simple delivery system for qbx_core'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    '@qbx_core/modules/lib.lua',
    '@qbx_core/shared/locale.lua',
}

client_scripts{
    '@PolyZone/client.lua',
    '@PolyZone/EntityZone.lua',
    '@PolyZone/BoxZone.lua',
    '@PolyZone/CircleZone.lua',
    '@PolyZone/RemoveZone',
    '@qbx_core/modules/playerdata.lua',
    'client/*.lua',
}

server_scripts{
    'server/*.lua',
    '@oxmysql/lib/MySQL.lua',
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'