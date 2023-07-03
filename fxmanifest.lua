-- ReaperAC | Do not touch this
shared_script "@ReaperAC/reaper-otcdq82s54nsp1fkzjmrto.lua"
fx_version 'cerulean'
game 'gta5'

description 'Simple Warrant Checking System for FiveM'
author 'RijayJH'
version '0.1.0'

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua',
    '@oxmysql/lib/MySQL.lua',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

lua54 'yes'