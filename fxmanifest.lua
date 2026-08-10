fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

game 'rdr3'
lua54 'yes'
name 'bcc-butcher'
description 'Butcher shops and hunting-wagon carcass sales'
author 'BCC Team'
version '0.1.0'

shared_scripts {
    'configs/main.lua',
    'configs/locations.lua',
    'configs/pricing.lua',
    'locale.lua',
    'language/*.lua',
}

client_scripts {
    'client/init.lua',
    'client/menu.lua',
    'client/locations.lua',
}

server_scripts {
    'server/init.lua',
    'server/pricing.lua',
    'server/sales.lua',
}

dependencies {
    'bcc-animal-data',
    'bcc-hunting-wagon',
    'bcc-utils',
    'bcc-wagons',
    'feather-menu',
    'vorp_core',
}
