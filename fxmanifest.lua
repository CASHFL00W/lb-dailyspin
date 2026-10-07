fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'lb-dailyspin'
author 'CASH'
version '1.0.0'
description 'Daily Spins - a daily lucky wheel phone app for lb-phone (cash prizes or daily missions: taxi, courier, postman)'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'locales/*.lua',
    'shared/locale.lua',
}

client_scripts {
    'client/bridge.lua',
    'client/mission.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/bridge.lua',
    'server/security.lua',
    'server/missions.lua',
    'server/main.lua',
}

files {
    'ui/index.html',
    'ui/style.css',
    'ui/app.js',
    'ui/sounds.js',
    'ui/icon.svg',
}

dependencies {
    'ox_lib',
    'oxmysql',
}
