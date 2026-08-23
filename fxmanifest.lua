fx_version 'cerulean'
game 'gta5'

author 'Rico Scripts'
description 'Uitgebreid beheer voor spelerwinkels en tankstations'
version '1.0.0'

sql_file 'sql/install.sql'
rs_sql 'sql/install.sql'

lua54 'yes'

ui_page 'web/index.html'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'locales/nl.lua',
    'shared/utils.lua'
}

client_scripts {
    'client/main.lua',
    'client/npcs.lua',
    'client/fuel.lua',
    'client/admin.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/logging.lua',
    'server/repository.lua',
    'server/business.lua',
    'server/fuel.lua',
    'server/orders.lua',
    'server/staff.lua',
    'server/admin.lua',
    'server/main.lua'
}

files {
    'web/index.html',
    'web/style.css',
    'web/app.js'
}

dependencies {
    'es_extended',
    'ox_lib',
    'oxmysql',
    'ox_inventory',
    'ox_target'
}

escrow_ignore {
    'config.lua',
    'locales/*.lua'
}
