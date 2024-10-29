fx_version 'cerulean'
game 'gta5'

author 'ShoeShuffler'
name 'Shuffle-Shop Delivery'
description 'A simple delivery system for qbx_core'
version '1.0.2'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    '@qbx_core/modules/lib.lua',
}

client_scripts{
    '@qbx_core/modules/playerdata.lua',
    'client/*.lua',
}

server_scripts{
    'server/*.lua',
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'