fx_version 'cerulean'
game 'gta5'

author 'Enhanced Trucker Job'
description 'Enhanced trucker job with NUI interface and F6 key functionality'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config/shared.lua'
}

client_scripts {
    'config/client.lua',
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config/server.lua',
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

lua54 'yes'

dependencies {
    'qbx_core',
    'ox_lib',
    'ox_target'
}