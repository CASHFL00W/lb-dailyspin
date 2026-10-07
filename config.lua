Config = {}

Config.Debug = false

-- Language: 'auto' follows the language set in the phone's settings, or force 'en' / 'de' (see locales/).
-- Missing keys and unknown languages fall back to English.
Config.Locale = 'auto'
-- Used by 'auto' as long as the phone does not report a (supported) language, and for server-side texts
Config.FallbackLocale = 'en'

-- 'auto' detects qbx_core -> qb-core -> es_extended
Config.Framework = 'auto'

-- Vehicle keys: 'auto' (mk_vehiclekeys, then qbx_vehiclekeys), 'mk_vehiclekeys', 'qbx_vehiclekeys' or 'none'
Config.VehicleKeys = 'auto'

-- ox_lib ACE group allowed to use /dailyspins_reset
Config.AdminGroup = 'group.admin'

---------------------------------------------------------------------------------------------------
-- Phone app
---------------------------------------------------------------------------------------------------
Config.App = {
    identifier  = 'daily-spins',
    name        = 'Daily Spins',
    description = 'Spin the wheel once a day and win cash or a daily mission.',
    developer   = 'CASH',
    defaultApp  = true, -- installed on the home screen by default, otherwise via the App Store
    size        = 24576,
}

---------------------------------------------------------------------------------------------------
-- Cooldown
---------------------------------------------------------------------------------------------------
Config.Cooldown = {
    -- 'rolling' = X hours after the last spin, 'daily' = fixed reset every day at resetHour (server time)
    mode      = 'rolling',
    hours     = 24,
    resetHour = 6,

    -- true = one spin per Rockstar license (all characters share the cooldown), false = per character
    perLicense = true,
}

---------------------------------------------------------------------------------------------------
-- Wheel
-- type:   'cash' | 'mission' | 'empty'
-- weight: chance = weight / sum of all weights. Slices are drawn equally sized regardless of weight.
-- icon:   cash | taxi | package | mail | empty | crown
---------------------------------------------------------------------------------------------------
Config.Wheel = {
    spinDuration = 6000,   -- ms, length of the wheel animation (the server holds follow-up events this long)
    showChances  = true,   -- show the odds inside the app
    cashAccount  = 'bank', -- 'cash' or 'bank' for instant cash prizes

    segments = {
        { type = 'cash',    amount = 500,  label = '$500',    icon = 'cash',    color = '#30d158', weight = 16 },
        { type = 'mission', mission = 'taxi',    label = 'Taxi',    icon = 'taxi',    color = '#ffd60a', weight = 14 },
        { type = 'empty',   label = 'Nothing',   icon = 'empty',   color = '#48484a', weight = 18 },
        { type = 'cash',    amount = 1500, label = '$1,500',  icon = 'cash',    color = '#0a84ff', weight = 8 },
        { type = 'mission', mission = 'courier', label = 'Courier', icon = 'package', color = '#ff9f0a', weight = 14 },
        { type = 'cash',    amount = 1000, label = '$1,000',  icon = 'cash',    color = '#64d2ff', weight = 10 },
        { type = 'mission', mission = 'postman', label = 'Postman', icon = 'mail',    color = '#bf5af2', weight = 14 },
        { type = 'cash',    amount = 7500, label = 'Jackpot', icon = 'crown',   color = '#ff375f', weight = 2 },
    },
}

---------------------------------------------------------------------------------------------------
-- Security (everything is validated server-side)
---------------------------------------------------------------------------------------------------
Config.Security = {
    maxSpeed        = 75,    -- m/s (~270 km/h); faster travel between two steps counts as a teleport
    teleportMinDist = 200,   -- the speed check only applies above this distance (server positions can lag)
    minStepSeconds  = 3,     -- minimum time between two mission steps
    footRadius      = 8.0,   -- tolerance (server position) for on-foot interactions
    driveRadius     = 25.0,  -- tolerance (server position) for in-vehicle steps
    dropPlayer      = false, -- true = kick the player on a detected exploit (otherwise cancel mission + log)
    webhook         = '',    -- optional Discord webhook for exploit logs
}

---------------------------------------------------------------------------------------------------
-- Missions
-- Coordinates are suggestions - verify them in-game for your map.
---------------------------------------------------------------------------------------------------
Config.Missions = {
    timeLimit     = 30,     -- minutes until a mission expires
    returnVehicle = true,   -- the work vehicle must be returned to the depot to get paid
    rewardAccount = 'bank',

    taxi = {
        label       = 'Taxi Driver',
        icon        = 'taxi',
        description = 'Pick up your passenger and drop them off safely at their destination.',
        reward      = { min = 1200, max = 1800 },
        depot       = { coords = vec3(909.5, -177.4, 74.2), label = 'Downtown Cab Co.' },
        vehicle     = {
            model  = 'taxi',
            spawns = {
                vec4(899.3, -180.4, 73.4, 238.4),
                vec4(897.2, -183.4, 73.3, 238.0),
                vec4(903.0, -191.7, 73.4, 59.6),
                vec4(904.9, -188.8, 73.4, 58.0),
            },
        },
        minTripDistance = 900,
        passengerModels = {
            'a_m_y_business_01', 'a_f_y_business_02', 'a_m_m_bevhills_01', 'a_f_y_hipster_02',
            'a_m_y_hipster_01', 'a_f_m_tourist_01', 'a_m_m_tourist_01', 'a_f_y_vinewood_01',
        },
        -- Roadside pickup/drop-off points (the passenger waits here)
        stops = {
            vec4(257.61, -380.57, 44.71, 340.5),
            vec4(-48.58, -790.12, 44.22, 340.5),
            vec4(240.06, -862.77, 29.73, 341.5),
            vec4(826.0, -1885.26, 29.32, 81.5),
            vec4(350.84, -1974.13, 24.52, 318.5),
            vec4(-229.11, -2043.16, 27.75, 233.5),
            vec4(-1053.23, -2716.2, 13.75, 329.5),
            vec4(-774.04, -1277.25, 5.15, 171.5),
            vec4(-1184.3, -1560.6, 4.36, 211.5),
            vec4(-1670.0, -541.2, 35.1, 140.0),
            vec4(-1301.4, -164.5, 44.4, 315.5),
            vec4(-1018.7, 375.4, 70.9, 333.5),
            vec4(-414.8, 254.0, 82.9, 175.5),
            vec4(318.8, 145.4, 103.5, 70.5),
        },
    },

    courier = {
        label       = 'Courier',
        icon        = 'package',
        description = 'Pick up a package at the warehouse and deliver it to the customer.',
        reward      = { min = 1100, max = 1600 },
        depot       = { coords = vec3(153.68, -3211.88, 5.91), label = 'Courier Depot' },
        vehicle     = {
            model  = 'speedo',
            spawns = {
                vec4(141.12, -3204.31, 5.85, 267.5),
                vec4(141.12, -3210.31, 5.85, 267.5),
            },
        },
        prop = 'hei_prop_heist_box',
        warehouses = {
            vec3(717.2, -965.1, 30.4),
            vec3(1197.06, -3253.65, 7.1),
            vec3(1240.6, -3179.0, 7.1),
            vec3(-424.5, -2789.6, 6.0),
        },
        customers = {
            vec3(24.5, -1346.5, 29.5),
            vec3(-47.4, -1758.7, 29.4),
            vec3(1135.8, -982.3, 46.4),
            vec3(373.9, 325.9, 103.6),
            vec3(-1222.9, -906.9, 12.3),
            vec3(-707.5, -914.3, 19.2),
            vec3(1163.4, -323.8, 69.2),
            vec3(-1487.6, -379.1, 40.2),
        },
    },

    postman = {
        label       = 'Postman',
        icon        = 'mail',
        description = 'Deliver mail to three houses, one after another.',
        reward      = { min = 1300, max = 1900 },
        stops       = 3,
        depot       = { coords = vec3(-424.0, -2789.0, 6.0), label = 'PostOP Depot' },
        vehicle     = {
            model  = 'boxville2',
            spawns = {
                vec4(-447.0, -2795.0, 6.0, 45.0),
                vec4(-451.0, -2800.0, 6.0, 45.0),
            },
        },
        prop = 'prop_cs_envolope_01',
        houses = {
            vec3(1301.1, -574.0, 71.7),
            vec3(1323.4, -583.0, 73.2),
            vec3(1341.6, -597.4, 74.7),
            vec3(1367.3, -606.6, 74.7),
            vec3(1386.2, -593.5, 74.5),
            vec3(1389.0, -569.6, 74.5),
            vec3(1385.2, -555.6, 74.7),
            vec3(1360.6, -555.4, 74.7),
            vec3(1348.4, -546.7, 73.9),
            vec3(1328.5, -536.0, 72.4),
            vec3(1303.2, -527.4, 71.5),
        },
    },
}
