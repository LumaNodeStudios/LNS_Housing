return {
    -- Debugging options to toggle print logs and visible boundaries/draw zones
    Debug = {
        BuyHouses = true, 
        LawnGrowth = true, 
        Zones = true 
    },

    -- Real estate job and agency management settings
    RealEstate = {
        Command = 'properties',                     -- Command for real estate agents to open properties menu
        OnlyBuyViaContracts = false,                -- If true, players can only buy houses through a signed contract with an agent
        Jobs = { 'realestate', 'luxuryestate' },    -- Jobs allowed to access the real estate agent actions
        Groups = { --[['admin', 'god', 'superadmin']] },  -- Admin groups that have full agent permissions
        Agencies = {
            ['realestate'] = {
                label = 'Dynasty 8 Real Estate',
                society = 'realestate',             -- Society account name for deposits/payments
                defaultCommission = 10              -- Default commission percentage for sales
            },
            ['luxuryestate'] = {
                label = 'Luxury Real Estate',
                society = 'luxuryestate',
                defaultCommission = 15 
            }
        },
        -- Permission ranks required for specific real estate actions
        Permissions = {
            CreateHouse = 2,       
            DraftContract = 1,     
            ManageListings = 3,    
            ManageEmployees = 4,   
        }
    },

    -- Default properties for the personal stash/storage in houses
    Stash = {
        label = 'Property Storage', -- Display label when opening the stash
        slots = 50,                 -- Number of storage slots
        weight = 100000             -- Maximum weight capacity of the stash (e.g., in grams)
    },

    -- Rent system, grace periods, late fees, and eviction settings
    Rent = {
        RentPeriod = 604800,        -- 7 days (in seconds)
        GracePeriod = 259200,       -- 3 days to pay after cycle due before lockout (in seconds)
        RetrievalPeriod = 604800,   -- 7 days of temporary stash retrieval after lockout (in seconds)
        LateFee = 250,              -- Flat late fee added to debt on missed payment
        MaxMissedPayments = 3,      -- Max missed payments threshold for eviction
        AutoEvict = true,           -- Auto evict player after retrieval period expires
    },

    -- Security, burglary, and property raid settings
    Security = {
        LockpickItem = 'lockpick',   -- Item needed for ordinary house lockpicking
        RaidItem = 'police_ram',        -- Item needed by police/authorized factions to raid properties
        RaidDuration = 50000,         -- Time in milliseconds required to break open a door during a raid
        RaidStorageDuration = 10000,  -- Time in milliseconds to break open a property stash
        MaxLevel = 5,                 -- Maximum upgradable lock level for houses
        UpgradePrice = {             -- Upgrade price for each security level
            [1] = 10000,
            [2] = 20000,
            [3] = 30000,
            [4] = 40000,
            [5] = 50000
        },
        AlarmDuration = 30000,        -- Duration of burglar alarm in milliseconds (30 seconds)
        AlarmFailThreshold = {        -- Number of failed attempts allowed before alarm triggers
            [0] = 999, -- Level 0: No alarm
            [1] = 4,   -- Level 1: alarm triggers on 4th fail
            [2] = 3,   -- Level 2: alarm triggers on 3rd fail
            [3] = 2,   -- Level 3: alarm triggers on 2nd fail
            [4] = 2,   -- Level 4: alarm triggers on 2nd fail
            [5] = 1,   -- Level 5 (max): alarm triggers on 1st fail
        },
        -- Lockpicking minigame difficulty settings based on security/lock levels
        Difficulty = {
            [0] = { rounds = 1, speed = 1.0, area = 50 }, -- Level 0: 1 round, normal speed, very large target area
            [1] = { rounds = 2, speed = 1.1, area = 40 }, -- Level 1: 2 rounds, slightly faster, large target area
            [2] = { rounds = 3, speed = 1.2, area = 35 }, -- Level 2: 3 rounds, medium speed, medium-large area
            [3] = { rounds = 3, speed = 1.3, area = 30 }, -- Level 3: 3 rounds, faster, medium area
            [4] = { rounds = 4, speed = 1.4, area = 25 }, -- Level 4: 4 rounds, medium-fast speed, medium-small area
            [5] = { rounds = 4, speed = 1.4, area = 25 }, -- Level 5: 4 rounds, fast speed, small area
        }
    },

    MaxKeys = 5, -- Maximum number of physical keys/copies that can be shared per property

    -- Shell/Interior template configurations (interiors spawned under the map)
    ShellSpawningZ = -100.0, -- Z coordinate to spawn shells
    Shells = {
        ["Standard Motel"] = {
            label = "Standard Motel",
            hash = "standardmotel_shell",
            doorOffset = { x = -0.5, y = -2.3, z = 0.0, h = 90.0, width = 1.5 } -- Exit door offset from the shell origin
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

    IPLs = {
        ["Eclipse Penthouse 1"] = {
            label = "Eclipse Penthouse 1",
            ipls = { "apa_v_mp_h_01_a" },
            coords = vec4(-786.8663, 315.7642, 217.6385, 270.0),
            exitCoords = vec4(-786.8663, 315.7642, 217.6385, 270.0),
            zoneSize = vec3(150.0, 150.0, 80.0)
        },
        ["Eclipse Penthouse 2"] = {
            label = "Eclipse Penthouse 2",
            ipls = { "apa_v_mp_h_02_a" },
            coords = vec4(-786.9563, 315.6229, 187.9136, 270.0),
            exitCoords = vec4(-786.9563, 315.6229, 187.9136, 270.0),
            zoneSize = vec3(150.0, 150.0, 80.0)
        },
        ["Eclipse Penthouse 3"] = {
            label = "Eclipse Penthouse 3",
            ipls = { "apa_v_mp_h_03_a" },
            coords = vec4(-786.8741, 315.7975, 157.9137, 270.0),
            exitCoords = vec4(-786.8741, 315.7975, 157.9137, 270.0),
            zoneSize = vec3(150.0, 150.0, 80.0)
        }
    },

    -- Placeholder for dynamic custom room configurations
    Rooms = {},

    -- Housing specific settings
    Housing = {
        Creator = {
            Command = 'createhouse', -- Command to initiate house creation
            Group = 'admin'          -- User group permitted to run this command
        },

        -- Lawn mowing and grass growth simulation settings
        Lawn = {
            Enabled = true,
            GrowthTime = 120,      -- Time (in minutes) for grass to fully grow
            MaxSink = 0.25,        -- Maximum distance grass models can sink into the ground
            Spacing = 1.5,         -- Distance spacing between individual grass props
            RenderDistance = 80.0, -- Distance (in meters) at which grass props will render for players
            Models = {             -- Grass prop models spawned on unmaintained lawns
                { model = 'prop_veg_grass_01_a', zOffset = 0.0 },
                { model = 'prop_grass_dry_02',   zOffset = -0.3 },
                { model = 'prop_veg_grass_01_c', zOffset = 0.0 },
            },
            MowerProp = 'prop_lawnmower_01',    -- Prop model of the push lawnmower
            CutDistance = 1,                    -- Radius in meters for cutting grass with push mower
            RequireItem = 'lawnmower',          -- Inventory item required to use a push mower
            MowerVehicles = { 'mower' },        -- Vehicle models categorized as lawnmowers
            VehicleCutDistance = 3.0,           -- Cutting radius in meters when using a lawnmower vehicle
        },

        -- Map blips/icons for properties
        Blips = {
            ReadyToBuy = {
                Enabled = true,
                Sprite = 350,   -- Blip icon ID (350 is house icon)
                Color = 2,      -- Blip color ID (2 is green)
                Scale = 0.5,    -- Size of the blip icon
                Label = "Property For Sale"
            },
            Owned = {
                Enabled = true,
                ShowOnlyMyOwned = true, -- Only display owned properties belonging to the local player
                Sprite = 40,    -- Blip icon ID (40 is safehouse icon)
                Color = 3,      -- Blip color ID (3 is blue)
                Scale = 0.5,
                Label = "Owned Property"
            }
        }
    },

    -- Apartment specific settings
    Apartments = {
        Enabled = true, -- Toggle for enabling or disabling apartment system
        CanBreakIn = true, -- If true, apartments can be lockpicked/broken into

        Creator = {
            Command = 'createapartment', -- Command to initiate apartment creation
            EditCommand = 'editapartment', -- Command to edit existing apartments
            Group = 'admin'              -- User group permitted to run this command
        },

        -- Configuration for the main apartment building lobby/reception
        Building = {
            sprite = 475,               -- Blip icon ID for apartments
            color = 3,                  -- Blip color ID
            scale = 0.8,
            label = "WIWANG Apartments",
            coords = vec3(-826.53, -700.2, 27.06), -- Entrance vector coordinate
            postal = '8083'             -- Postal map code
        }
    }
}
