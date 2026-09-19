fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'V-Interact'
author 'V-Scripts'
description 'V-Interact'
version '1.0.0'


shared_scripts {
    'config.lua',
}

client_scripts {
    'client/client.lua',
    'client/vehicle_doors.lua',
    'client/peds.lua',
    'client/object_interactions.lua',
    'client/defaults/*.lua'
}


files {
    'html/dui.html',
    'html/dui.css',
    'html/dui.js',
    'html/marker.html',
    'html/vendor/fontawesome/css/all.min.css',
    'html/vendor/fontawesome/webfonts/fa-solid-900.woff2',
    'html/vendor/fontawesome/webfonts/fa-regular-400.woff2'
}