return {
    -- General & Core Settings --
    Debug = {
        BuyHouses = true, -- Set to true to allow buying houses via ox_target on doors
        LawnGrowth = true, -- Set to true for 5 min growth (300s), false for 7 days (604800s)
        Zones = true -- Seto to true for zone boxes, false to hide zone boxes
    },

    Creator = {
        Command = 'createhouse',
        Group = 'admin'
    },

    ApartmentCreator = {
        Command = 'createapartment',
        Group = 'admin'
    },

    RealEstate = {
        Command = 'properties',
        OnlyBuyViaContracts = true, -- If true, players cannot buy direct-sale properties directly and must purchase via an agent contract
        Jobs = { 'realestate', 'luxuryestate' },
        Groups = { 'admin', 'god', 'superadmin' },
        Agencies = {
            ['realestate'] = {
                label = 'Dynasty 8 Real Estate',
                society = 'realestate',
                defaultCommission = 10 -- 10% commission
            },
            ['luxuryestate'] = {
                label = 'Luxury Real Estate',
                society = 'luxuryestate',
                defaultCommission = 15 -- 15% commission
            }
        },
        Permissions = {
            CreateHouse = 2,       -- Minimum grade to create houses
            DraftContract = 1,     -- Minimum grade to create/draft contracts
            ManageListings = 3,    -- Minimum grade to edit details or delete listings
            ManageEmployees = 4,   -- Minimum grade to manage employee options
        }
    },

    ImageUpload = {
        Url = 'https://api.fivemanage.com/api/v3/file',
        Token = 'xOSaS3kRrUNyEvNBnWg2FWdxX8uKg2Zp' -- Change this if your token is invalid or expired
    },

    -- Housing --
    Stash = {
        label = 'Property Storage',
        slots = 50,
        weight = 100000 -- 100kg
    },

    Security = {
        LockpickItem = 'lockpic2k',
        RaidItem = 'lockpick', -- Item required for police raids
        RaidDuration = 50000,         -- Time in ms for progressbar
        RaidStorageDuration = 10000,         -- Time in ms for progressbar
        MaxLevel = 5,
        Difficulty = {
            [0] = { rounds = 1, speed = 1.0, area = 40 }, -- Level 0 (Default)
            [1] = { rounds = 2, speed = 1.2, area = 35 },
            [2] = { rounds = 3, speed = 1.4, area = 30 },
            [3] = { rounds = 4, speed = 1.6, area = 25 },
            [4] = { rounds = 5, speed = 1.8, area = 20 },
            [5] = { rounds = 6, speed = 2.0, area = 15 },
        }
    },

    Lawn = {
        Enabled = true,
        GrowthTime = 120, -- time in seconds for grass to grow 100% (2 hours)
        MaxSink = 0.25,    -- maximum depth (in meters) the grass starts underground and grows up from
        Spacing = 1.5,     -- spacing distance between grass spawn points
        RenderDistance = 80.0, -- distance (in units) from yard center to start rendering grass props
        Models = {
            { model = 'prop_veg_grass_01_a', zOffset = 0.0 },
            { model = 'prop_grass_dry_02',   zOffset = -0.3 },
            { model = 'prop_veg_grass_01_c', zOffset = 0.0 },
        },
        MowerProp = 'prop_lawnmower_01',
        CutDistance = 1,  -- distance to cut a grass prop
        RequireItem = 'lawnmower', -- require this inventory item to mow
        MowerVehicles = { 'mower' }, -- Drivable mower vehicle models
        VehicleCutDistance = 3.0,    -- Cut distance when in a vehicle (wider area)
    },

    -- Apartments --
    Apartments = {
        Enabled = true, -- Set to false to disable starting apartments completely
    },

    ApartmentBuilding = {
        sprite = 475,
        color = 3,
        scale = 0.8,
        label = "WIWANG Apartments",
        coords = vec3(-826.53, -700.2, 27.06),
        postal = '8083'
    },

    MaxKeys = 5,

    Furniture = lib.load('shared.furniture'),

    -- Ignore --
    Rooms = {},
}
