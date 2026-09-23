fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'projeFivem'
description 'vbs_core_matrix - Katman 1-8 Birlesik Motor'
version '1.7.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua'
}

client_scripts {
    'client/hud.lua',
    'client/trap_house_client.lua',
    'client/composer_intro.lua',
    'client/mercenary_followers.lua',
    'client/humint_stalking.lua',
    'client/anti_glitch.lua'
    
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/forensics.lua',
    'server/recruitment.lua',
    'server/bureau.lua',
    'server/district_hubs.lua',
    'server/kitchen.lua',
    'server/logistics.lua',
    'server/market.lua',
    'server/blackmarket.lua',
    'server/rendezvous.lua',
    'server/trap_house_interior.lua',
    'server/workbench.lua',
    'server/door_reinforcement.lua',
    'server/wound_system.lua',
    'server/underworld_network.lua',
    'server/gang_hoods.lua',
    'server/mercenary_followers.lua',
    'server/hitsquad.lua',
    'server/team_ai.lua',
    'server/phone_bridge.lua',
    'server/matrix_diagnostics.lua'
}

files {
    'sounds/*.ogg'
}

dependencies {
    'ox_lib',
    'qbx_core',
    'oxmysql',
    'ox_inventory',
    'ox_target',
    'xsound',
    'bob74_ipl'
}