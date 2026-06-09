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
        OnlyBuyViaContracts = false, -- If true, players cannot buy direct-sale properties directly and must purchase via an agent contract
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

    -- Blips Settings --
    Blips = {
        ReadyToBuy = {
            Enabled = true,
            Sprite = 350, -- Standard house blip
            Color = 2, -- Green
            Scale = 0.5,
            Label = "Proeprty For Sale"
        },
        Owned = {
            Enabled = true,
            ShowOnlyMyOwned = true, -- If true, players will only see blips for houses they own. If false, they see all owned houses.
            Sprite = 40, -- Safehouse blip
            Color = 3, -- Blue
            Scale = 0.5,
            Label = "Owned Property"
        }
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

    Shells = {
        ["Standard Motel"] = {
            label = "Standard Motel",
            hash = "standardmotel_shell",
            doorOffset = { x = -0.5, y = -2.3, z = 0.0, h = 90.0, width = 1.5 }
        },
        ["Modern Hotel"] = {
            label = "Modern Hotel",
            hash = "modernhotel_shell",
            doorOffset = { x = 4.98, y = 4.35, z = -0.75, h = 179.79, width = 2.0 }
        },
        ["Apartment Furnished"] = {
            label = "Apartment Furnished",
            hash = "furnitured_midapart",
            doorOffset = { x = 1.44, y = -10.25, z = 0.0, h = 0.0, width = 1.5 }
        },
        ["Apartment Unfurnished"] = {
            label = "Apartment Unfurnished",
            hash = "shell_v16mid",
            doorOffset = { x = 1.34, y = -14.36, z = -0.5, h = 354.08, width = 1.5 }
        },
        ["Apartment 2 Unfurnished"] = {
            label = "Apartment 2 Unfurnished",
            hash = "shell_v16low",
            doorOffset = { x = 4.69, y = -6.5, z = -1.0, h = 358.50, width = 1.5 }
        },
        ["Garage"] = {
            label = "Garage",
            hash = "shell_garagem",
            doorOffset = { x = 14.0, y = 1.7, z = -0.76, h = 88.49, width = 2.0 }
        },
        ["Office"] = {
            label = "Office",
            hash = "shell_office1",
            doorOffset = { x = 1.2, y = 4.90, z = -0.73, h = 180.0, width = 2.0 }
        },
        ["Store"] = {
            label = "Store",
            hash = "shell_store1",
            doorOffset = { x = -2.69, y = -4.56, z = -0.62, h = 1.91, width = 2.0 }
        },
        ["Warehouse"] = {
            label = "Warehouse",
            hash = "shell_warehouse1",
            doorOffset = { x = -8.96, y = 0.11, z = -0.95, h = 270.64, width = 2.0 }
        },
        ["Container"] = {
            label = "Container",
            hash = "container_shell",
            doorOffset = { x = 0.05, y = -5.7, z = -0.22, h = 1.7, width = 2.2 }
        },
        ["2 Floor House"] = {
            label = "2 Floor House",
            hash = "shell_michael",
            doorOffset = { x = -9.6, y = 5.63, z = -4.07, h = 268.55, width = 2.0 }
        },
        ["House 1"] = {
            label = "House 1",
            hash = "shell_frankaunt",
            doorOffset = { x = -0.34, y = -5.97, z = -0.57, h = 357.23, width = 2.0 }
        },
        ["House 2"] = {
            label = "House 2",
            hash = "shell_ranch",
            doorOffset = { x = -1.23, y = -5.54, z = -1.1, h = 272.21, width = 2.0 }
        },
        ["House 3"] = {
            label = "House 3",
            hash = "shell_lester",
            doorOffset = { x = -1.61, y = -6.02, z = -0.37, h = 357.7, width = 2.0 }
        },
        ["House 4"] = {
            label = "House 4",
            hash = "shell_trevor",
            doorOffset = { x = 0.2, y = -3.82, z = -0.41, h = 358.4, width = 2.0 }
        },
        ["Trailer"] = {
            label = "Trailer",
            hash = "shell_trailer",
            doorOffset = { x = -1.27, y = -2.08, z = -0.48, h = 358.84, width = 2.0 }
        }
    },

    -- Ignore --
    Rooms = {},
}
