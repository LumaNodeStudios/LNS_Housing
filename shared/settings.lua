return {
    ----------------------------------------------------------------------------
    -- Core & Debug Settings
    ----------------------------------------------------------------------------
    Debug = {
        Prints = false,
        LawnGrowth = false, 
        Zones = false 
    },

    -- Spawn elevation (Z coordinate) for shell-based interior templates
    ShellSpawningZ = -100.0,

    -- Maximum number of physical key copies that can be shared per property/apartment
    MaxKeys = 5,

    ----------------------------------------------------------------------------
    -- Real Estate Agency & Agent Settings
    ----------------------------------------------------------------------------
    RealEstate = {
        Command = 'housing',                      -- Command to open the real estate menu (set to nil to disable)
        Item = {
            Enabled = false,                 -- If true, players can use the item below to open the real estate menu
            Name = 'realestate_tablet',              -- Item name that opens the real estate (properties) menu when used
        },
        ContractDistance = 5.0,             -- Max distance to draft a contract (in meters)
        OnlyBuyViaContracts = false,        -- If true, players can only buy houses through a signed contract with an agent
        Jobs = { 'realestate', 'luxuryestate' }, -- Jobs allowed to access the real estate agent actions
        Groups = { 'admin' },                        -- Admin groups that have full agent permissions (e.g. {'admin', 'god', 'superadmin'})
        Agencies = {
            ['realestate'] = {
                label = 'Dynasty 8 Real Estate',
                society = 'realestate',     -- Society account name for deposits/payments
                defaultCommission = 10      -- Default commission percentage for sales
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

    ----------------------------------------------------------------------------
    -- Housing System Settings
    ----------------------------------------------------------------------------
    Housing = {
        CanBreakIn = false,                  -- If true, houses can be lockpicked/broken into

        -- Access configurations for the house creator tool
        Creator = {
            Command = 'createhouse',        -- Command to initiate house creation
            Group = 'admin'                 -- User group permitted to run this command
        },

        -- Lawn mowing and grass growth simulation settings
        Lawn = {
            Enabled = false,
            GrowthTime = 120,               -- Time (in minutes) for grass to fully grow
            MaxSink = 0.25,                 -- Maximum distance grass models can sink into the ground
            Spacing = 1.5,                  -- Distance spacing between individual grass props
            RenderDistance = 80.0,          -- Distance (in meters) at which grass props will render for players
            Models = {                      -- Grass prop models spawned on unmaintained lawns
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
                Sprite = 350,               -- Blip icon ID (350 is house icon)
                Color = 2,                  -- Blip color ID (2 is green)
                Scale = 0.5,                -- Size of the blip icon
                Label = "Property For Sale"
            },
            Owned = {
                Enabled = true,
                ShowOnlyMyOwned = true,     -- Only display owned properties belonging to the local player
                Sprite = 40,                -- Blip icon ID (40 is safehouse icon)
                Color = 3,                  -- Blip color ID (3 is blue)
                Scale = 0.5,
                Label = "Owned Property"
            }
        }
    },

    ----------------------------------------------------------------------------
    -- Apartment System Settings
    ----------------------------------------------------------------------------
    Apartments = {
        Enabled = true,                     -- Toggle for enabling or disabling apartment system
        CanBreakIn = false,                  -- If true, apartments can be lockpicked/broken into

        Creator = {
            Command = 'createapartment',    -- Command to initiate apartment creation
            EditCommand = 'editapartment',  -- Command to edit existing apartments
            Group = 'admin'                 -- User group permitted to run this command
        },

        -- Configuration for the main apartment building lobby/reception
        Building = {
            sprite = 475,                   -- Blip icon ID for apartments
            color = 3,                      -- Blip color ID
            scale = 0.8,
            label = "WIWANG Apartments",
            coords = vec3(-826.53, -700.2, 27.06), -- Entrance vector coordinate
            breakerCoords = vec3(-828.53, -702.2, 27.06) -- Shared breaker box interaction location
        }
    },

    ----------------------------------------------------------------------------
    -- Default Stash & Storage Settings
    ----------------------------------------------------------------------------
    Stash = {
        label = 'Property Storage',         -- Display label when opening the stash
        slots = 50,                         -- Number of storage slots
        weight = 100000                     -- Maximum weight capacity of the stash (e.g., in grams)
    },

    ----------------------------------------------------------------------------
    -- Refrigerator & Perishable Preservation Settings
    ----------------------------------------------------------------------------
    Fridge = {
        Enabled = true,                     -- Enable or disable fridge durability loss slowdown for food/drinks
        DecayMultiplier = 10.0,             -- Decay slowdown factor (e.g. 10.0 = food/drinks spoil 10x slower in fridges)
        Slots = 40,                         -- Default fridge storage slots
        Weight = 60000,                     -- Default fridge storage weight capacity (in grams)
        RequirePower = true,                -- If electricity system is enabled, fridges only slow decay when breaker is active

        -- Item Decay Filtering Mode:
        -- 'none'      : All perishable items placed in the fridge have decay slowed down (default).
        -- 'whitelist' : ONLY items listed in ItemFilter will have decay slowed down (unlisted items decay at normal speed).
        -- 'blacklist' : Items listed in ItemFilter decay at normal speed (they are excluded from fridge decay slowdown).
        FilterMode = 'none',                -- 'none' | 'whitelist' | 'blacklist'

        -- Whitelist or Blacklist items to filter based on FilterMode.
        -- Supports list format: { 'water', 'sandwich', 'burger' }
        -- Or table format:       { ['water'] = true, ['sandwich'] = true }
        ItemFilter = {
            -- 'water',
            -- 'sandwich',
            -- 'burger',
        },
    },

    ----------------------------------------------------------------------------
    -- Trash Can & Waste Disposal Settings
    ----------------------------------------------------------------------------
    TrashCan = {
        Enabled = true,                     -- Enable or disable trash can / waste disposal furniture
        Slots = 15,                         -- Default trash can storage slots
        Weight = 50000,                     -- Default trash can weight capacity (in grams)
        DestroyOnClose = true,              -- Permanently delete all items placed inside when inventory is closed
        NotifyOnDestroy = true,             -- Notify player when items are permanently destroyed
    },

    ----------------------------------------------------------------------------
    -- Property & Apartment Trash Buildup & Cleanliness Settings
    ----------------------------------------------------------------------------
    Trash = {
        Enabled = true,                     -- Enable or disable property & apartment trash buildup over time
        BuildupInterval = 7200,             -- Time in seconds (e.g. 7200 = 2 hours) for each trash pile to accumulate
        MaxTrash = 8,                       -- Maximum number of trash piles that can accumulate in a property/apartment
        CleanDuration = 4000,               -- Duration in milliseconds to clean/pickup a trash pile
        ThrowDuration = 2500,               -- Duration in milliseconds to toss a trash bag into a street dumpster
        RequireKeyAccess = false,           -- If true, only players with keys/entry permission can clean trash inside (if false, visitors/cleaners can help)
        MinDoorDistance = 2.0,              -- Minimum distance in meters trash props must stay away from room/apartment entrance doors
        MinWallMargin = 0.95,               -- Minimum distance in meters trash props must stay inside poly zone boundaries away from walls
        MinPileSpread = 1.6,                -- Minimum distance in meters between individual trash piles so they spread naturally across the room
        StrictRoomBounds = true,            -- Strictly validate room containment, interior IDs, and line-of-sight

        -- Trash models spawned on the floor inside properties when trash accumulates
        TrashModels = {
            'prop_rub_litter_01',
            'prop_rub_litter_02',
            'prop_rub_litter_03',
        },

        -- Trash bag inventory item integration (uses inventory bridge)
        Item = {
            Enabled = false,                -- If true, picking up trash gives an inventory item; disposing requires and removes the item
            Name = 'trashbag',              -- Inventory item identifier (e.g. 'trashbag' or 'garbagebag')
            MaxCarry = nil,                 -- Optional: max trash bags a player can hold in inventory at once (nil = limited only by inventory weight/slots)
        },

        -- Carried trash bag prop attachment settings
        CarryProp = {
            model = 'prop_cs_rub_binbag_01',
            bone = 57005,                   -- SKEL_R_Hand
            offset = vec3(0.12, 0.0, -0.05),
            rotation = vec3(220.0, 120.0, 0.0),
            animDict = 'missfbi4prepp1',
            animClip = '_bag_walk_garbage_man',
        },

        -- Street Dumpster Models for ox_target:addModel
        -- Trash must be taken outside and thrown into any of these dumpster models
        DumpsterModels = {
            'prop_dumpster_01a',
            'prop_dumpster_02a',
            'prop_dumpster_02b',
            'prop_dumpster_4a',
            'prop_dumpster_4b',
            'prop_dumpster_3a',
            'prop_cs_dumpster_01a',
            'p_dumpster_t',
            'prop_bin_05a',
            'prop_bin_06a',
            'prop_bin_07a',
            'prop_bin_08a',
            'prop_bin_10a',
            'prop_bin_11a',
            'prop_bin_12a',
            'prop_bin_13a',
            'prop_bin_14a',
            'prop_bin_beach_01a',
            'prop_bin_delpiero',
            'prop_recyclebin_01a',
            'prop_recyclebin_02_c',
            'prop_recyclebin_04_a',
            'prop_recyclebin_04_b',
            'prop_recyclebin_05_a',
        },

        -- Optional Cash/Money reward for properly disposing of trash in a street dumpster
        Reward = {
            Enabled = false,
            Min = 1500,
            Max = 5000,
            Account = 'cash',             -- 'money' or 'cash'
        },

        -- Visual flies swarm particle effect inside properties when trash is at maximum level
        FliesEffect = true,

        -- Autonomous Cleaning Robot settings
        Robot = {
            Enabled = true,                     -- Enable autonomous robot cleaners (mula_prop_cleandock props)
            DefaultTimer = 3600,                -- Default timer in seconds (3600s = 1 hour, 0 = disabled/manual only)
            Speed = 1.0,                        -- Robot drive speed (meters per second)
            CleanDuration = 3000,               -- Duration in milliseconds the robot pauses at each trash pile to clean it
            MaxWaypoints = 60,                  -- Maximum path waypoints per route
            AutoCheckInterval = 30,             -- How often in seconds the server checks cleaning timers (30s)
            DockHeadingOffset = 180.0,          -- Angle offset for dock opening exit direction (180.0: Mula dock opening faces local -Y)
            RobotHeadingOffset = 0.0,           -- Angle offset for robot prop front orientation (0.0: standard +Y forward facing)
            AvailableTimers = {
                { label = 'Disabled (Manual Clean Only)', value = 0 },
                { label = 'Every 15 Minutes', value = 900 },
                { label = 'Every 30 Minutes', value = 1800 },
                { label = 'Every 1 Hour', value = 3600 },
                { label = 'Every 2 Hours', value = 7200 },
                { label = 'Every 4 Hours', value = 14400 },
                { label = 'Every 8 Hours', value = 28800 },
                { label = 'Every 12 Hours', value = 43200 },
                { label = 'Every 24 Hours', value = 86400 },
            }
        },

        -- Curated floor offsets for standard shells (relative to shell origin)
        ShellOffsets = {
            ['Standard Motel'] = {
                vec3(0.5, 0.2, 0.0),
                vec3(-1.2, 1.0, 0.0),
                vec3(1.4, -1.2, 0.0),
                vec3(-0.8, -1.5, 0.0),
                vec3(0.0, 1.5, 0.0),
                vec3(1.1, 0.9, 0.0),
                vec3(-1.4, -0.6, 0.0),
                vec3(0.7, -1.8, 0.0),
            },
            ['Modern Hotel'] = {
                vec3(2.5, 2.0, -0.75),
                vec3(-2.0, 1.5, -0.75),
                vec3(1.8, -1.5, -0.75),
                vec3(-1.5, -2.0, -0.75),
                vec3(3.2, 0.0, -0.75),
                vec3(-0.5, 2.2, -0.75),
                vec3(0.5, -2.2, -0.75),
                vec3(-2.5, -0.5, -0.75),
            },
            ['Apartment Furnished'] = {
                vec3(0.5, -4.5, 0.0),
                vec3(-1.8, -3.0, 0.0),
                vec3(2.2, -6.5, 0.0),
                vec3(-1.2, -7.5, 0.0),
                vec3(1.5, -2.0, 0.0),
                vec3(-0.8, -5.5, 0.0),
                vec3(1.8, -4.0, 0.0),
                vec3(-1.5, -6.2, 0.0),
            },
            ['Apartment Unfurnished'] = {
                vec3(0.8, -5.0, -0.5),
                vec3(-2.0, -4.0, -0.5),
                vec3(2.5, -8.0, -0.5),
                vec3(-1.5, -9.0, -0.5),
                vec3(1.0, -11.0, -0.5),
                vec3(-0.5, -6.5, -0.5),
                vec3(1.8, -6.0, -0.5),
                vec3(-1.0, -7.5, -0.5),
            },
            ['Apartment 2 Unfurnished'] = {
                vec3(2.0, -3.0, -1.0),
                vec3(-1.5, -2.5, -1.0),
                vec3(3.0, -4.5, -1.0),
                vec3(-2.2, -4.0, -1.0),
                vec3(0.5, -1.5, -1.0),
                vec3(1.2, -4.8, -1.0),
                vec3(-0.8, -3.8, -1.0),
                vec3(2.5, -1.8, -1.0),
            },
            ['Trailer'] = {
                vec3(0.4, 0.5, -0.48),
                vec3(-0.6, 1.8, -0.48),
                vec3(0.5, -1.0, -0.48),
                vec3(-0.5, -0.2, -0.48),
                vec3(0.0, 2.5, -0.48),
                vec3(0.3, -1.8, -0.48),
                vec3(-0.4, 1.1, -0.48),
                vec3(0.2, 3.2, -0.48),
            },
            ['House 1'] = {
                vec3(1.5, -2.0, -0.57),
                vec3(-1.8, -1.5, -0.57),
                vec3(2.0, -4.0, -0.57),
                vec3(-1.2, -4.5, -0.57),
                vec3(0.5, 0.5, -0.57),
                vec3(-0.5, -2.8, -0.57),
                vec3(1.0, -3.2, -0.57),
                vec3(-1.5, -0.5, -0.57),
            },
            ['House 2'] = {
                vec3(1.2, -1.5, -1.1),
                vec3(-2.0, -2.0, -1.1),
                vec3(1.8, -3.5, -1.1),
                vec3(-1.5, 0.5, -1.1),
                vec3(0.2, -4.0, -1.1),
                vec3(-0.8, -2.8, -1.1),
                vec3(1.0, -0.5, -1.1),
                vec3(-1.0, -4.5, -1.1),
            },
            ['House 3'] = {
                vec3(1.5, -2.0, -0.37),
                vec3(-1.2, -1.5, -0.37),
                vec3(2.2, -3.5, -0.37),
                vec3(-1.8, -4.0, -0.37),
                vec3(0.0, -0.5, -0.37),
                vec3(-0.6, -2.8, -0.37),
                vec3(1.2, -0.8, -0.37),
                vec3(0.5, -4.2, -0.37),
            },
            ['House 4'] = {
                vec3(1.0, -1.0, -0.41),
                vec3(-1.5, -0.5, -0.41),
                vec3(1.8, -2.5, -0.41),
                vec3(-1.0, -2.0, -0.41),
                vec3(0.2, 1.0, -0.41),
                vec3(-0.5, -3.0, -0.41),
                vec3(1.2, 0.2, -0.41),
                vec3(-1.2, 0.5, -0.41),
            },
            ['Garage'] = {
                vec3(4.0, 0.0, -0.76),
                vec3(8.0, 1.5, -0.76),
                vec3(10.0, -1.0, -0.76),
                vec3(2.0, -1.5, -0.76),
                vec3(6.0, 2.0, -0.76),
                vec3(5.0, -1.8, -0.76),
                vec3(9.0, 0.5, -0.76),
                vec3(3.0, 1.8, -0.76),
            },
            ['2 Floor House'] = {
                vec3(-4.0, 2.0, -4.07),
                vec3(-6.0, 4.0, -4.07),
                vec3(-2.0, 3.5, -4.07),
                vec3(-5.0, 0.5, -4.07),
                vec3(-1.5, 1.0, -4.07),
                vec3(-3.5, 4.5, -4.07),
                vec3(-5.5, 2.5, -4.07),
                vec3(-2.8, 1.2, -4.07),
            },
            ['Container'] = {
                vec3(0.0, -2.0, -0.22),
                vec3(-0.5, -3.5, -0.22),
                vec3(0.5, -1.0, -0.22),
                vec3(-0.4, -0.5, -0.22),
                vec3(0.4, -4.5, -0.22),
                vec3(-0.3, -1.5, -0.22),
                vec3(0.3, -2.8, -0.22),
                vec3(-0.2, -4.0, -0.22),
            },
            ['Office'] = {
                vec3(0.5, 2.0, -0.73),
                vec3(-1.5, 1.5, -0.73),
                vec3(1.8, 3.5, -0.73),
                vec3(-1.2, 3.0, -0.73),
                vec3(0.0, 4.0, -0.73),
                vec3(-0.8, 2.2, -0.73),
                vec3(1.2, 1.8, -0.73),
                vec3(0.5, 3.2, -0.73),
            },
            ['Store'] = {
                vec3(-1.0, -2.0, -0.62),
                vec3(1.5, -1.5, -0.62),
                vec3(-1.8, 0.5, -0.62),
                vec3(1.2, 1.0, -0.62),
                vec3(0.0, -3.0, -0.62),
                vec3(-0.5, -0.5, -0.62),
                vec3(1.0, -2.5, -0.62),
                vec3(-1.2, -1.0, -0.62),
            },
            ['Warehouse'] = {
                vec3(-3.0, 1.5, -0.95),
                vec3(-5.0, -1.0, -0.95),
                vec3(1.0, 2.0, -0.95),
                vec3(2.5, -1.5, -0.95),
                vec3(-1.0, -0.5, -0.95),
                vec3(-2.0, -1.8, -0.95),
                vec3(2.0, 0.8, -0.95),
                vec3(-4.0, 0.5, -0.95),
            },
        }
    },

    ----------------------------------------------------------------------------
    -- Rent & Eviction Management
    ----------------------------------------------------------------------------
    Rent = {
        RentPeriod = 604800,                -- 7 days (in seconds)
        GracePeriod = 259200,               -- 3 days to pay after cycle due before lockout (in seconds)
        RetrievalPeriod = 604800,           -- 7 days of temporary stash retrieval after lockout (in seconds)
        LateFee = 250,                      -- Flat late fee added to debt on missed payment
        MaxMissedPayments = 3,              -- Max missed payments threshold for eviction
        AutoEvict = false,                  -- Auto evict player after retrieval period expires
    },

    ----------------------------------------------------------------------------
    -- Electricity & Power System Settings
    ----------------------------------------------------------------------------
    Electricity = {
        Enabled = false,                    -- Enable or disable property electricity & breaker power grid
        DefaultMaxPower = 5.0,              -- Default max kWh power capacity
        BreakerSkillCheck = { 'easy', 'medium' }, -- Skill check difficulty for resetting tripped breaker box
        Upgrades = {                        -- Upgradable kWh capacity tiers
            [1] = { maxPower = 5.0,  price = 0,     label = "Standard Circuit (5.0 kWh)" },
            [2] = { maxPower = 10.0, price = 5000,  label = "Enhanced Circuit (10.0 kWh)" },
            [3] = { maxPower = 20.0, price = 12000, label = "High-Capacity Circuit (20.0 kWh)" },
            [4] = { maxPower = 35.0, price = 25000, label = "Heavy-Duty Grid (35.0 kWh)" },
            [5] = { maxPower = 50.0, price = 45000, label = "Industrial Power Grid (50.0 kWh)" }
        }
    },

    ----------------------------------------------------------------------------
    -- Temperature & Climate Settings
    ----------------------------------------------------------------------------
    Temperature = {
        Enabled = false,                    -- Enable or disable property temperature & climate system
        Unit = 'Celsius',                -- Temperature scale unit: 'Celsius' or 'Fahrenheit'
        BaseTemperature = 70.0,             -- Base interior temperature in °C (21.1°C / 70.0°F)
        MinComfortableTemp = 62.0,          -- Temperature below which property is flagged as cold
        MaxComfortableTemp = 78.0,          -- Temperature above which property is flagged as hot
        NotifyOnEnter = false,               -- Display climate notification toast on entering property/apartment
    },

    ----------------------------------------------------------------------------
    -- Security, Burglary & Key Settings (RAM IS EXPERIMENTAL!)
    ----------------------------------------------------------------------------
    Security = {
        PoliceJobs = { 'police' },          -- Jobs authorized as police (door/stash breaching, securing doors, property access, dispatch alerts)
        LockpickItem = 'lockpick',          -- Item needed for ordinary house lockpicking
        RaidItem = 'WEAPON_BATTERINGRAM',   -- Item needed by police/authorized factions to raid door
        PoliceAccessTool = 'police_access_tool', -- Item needed by police to raid/breach storage/stashes
        RequiredBreachHits = 3,             -- Minimum hits required with battering ram to breach door
        RamProp = 'w_me_batteringram',     -- Battering ram prop model used in 3D drag minigame (custom weapon prop)
        RamRotation = { pitch = 64.9, roll = 37.0, yawOffset = 66.8 }, -- User configured 3D modeler rotation
        RaidDuration = 6000,                -- Time in milliseconds required to break open a door during a raid
        RaidStorageDuration = 6000,         -- Time in milliseconds to break open a property stash
        MaxLevel = 5,                       -- Maximum upgradable lock level for houses
        UpgradePrice = {                    -- Upgrade price for each security level
            [1] = 10000,
            [2] = 20000,
            [3] = 30000,
            [4] = 40000,
            [5] = 50000
        },
        doorbellCameraPrice = 1000,
        DoorbellCameraRenderDistance = 30.0, -- Distance (in meters) at which doorbell camera props will render for players
        CameraProps = {
            `prop_cctv_cam_07a`,
        },
        AlarmDuration = 30000,              -- Duration of burglar alarm in milliseconds (30 seconds)
        AlarmFailThreshold = {              -- Number of failed attempts allowed before alarm triggers
            [0] = 999,
            [1] = 4,
            [2] = 3,
            [3] = 2,
            [4] = 2,
            [5] = 1,
        },
        -- Lockpicking minigame difficulty settings based on security/lock levels
        Difficulty = {
            [0] = { rounds = 2, speed = 1.0, area = 50 },
            [1] = { rounds = 2, speed = 1.1, area = 40 },
            [2] = { rounds = 3, speed = 1.2, area = 35 },
            [3] = { rounds = 3, speed = 1.3, area = 28 },
            [4] = { rounds = 4, speed = 1.4, area = 22 },
            [5] = { rounds = 5, speed = 1.5, area = 18 },
        },
        -- Physical key item settings
        PhysicalKeys = {
            Enabled = false,                 -- If true, 'entry' access (enter/lock/unlock) for houses AND apartments requires holding a physical key item bound (via metadata) to that specific property/apartment
            Item = 'house_key',             -- Item name used as the physical key. Every copy MUST be given via GivePhysicalKey/GiveApartmentPhysicalKey or the locksmith, or it will not open anything.
            RequireKeyholder = false,       -- If true, having the key item is not enough on its own. The person must ALSO be a listed keyholder (owner, or in permissions.entry) on that property/apartment. If false, the key alone is sufficient (so a stolen key still works).
        },
    },

    ----------------------------------------------------------------------------
    -- NPC Locksmith Settings
    ----------------------------------------------------------------------------
    Locksmith = {
        Enabled = false, -- Keep false if PhysicalKeys is disabled, set to true if PhysicalKeys is enabled
        BlankKeyItem = 'blank_house_key',   -- Item required and consumed to cut a new key
        Distance = 2.0,                     -- Interaction distance for the target option
        Ped = {
            Model = 'a_m_m_business_01',
            Coords = vec4(170.06, -1799.52, 29.32, 321.68), -- Adjust to your locksmith location
            Scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
        },
        Blip = {
            Enabled = true,
            Sprite = 186,
            Color = 1,
            Scale = 0.8,
            Label = 'Locksmith'
        }
    },

    ----------------------------------------------------------------------------
    -- Furniture System Settings
    ----------------------------------------------------------------------------
    FurnitureMenu = {
        Radial = {
            Enabled = true,                 -- Enable/disable opening the furniture menu via radial menu
        },
        Command = {
            Enabled = false,                 -- Enable/disable opening the furniture menu via a command
            Name = 'furniture'              -- The command name (e.g. /furniture)
        },
        Keybind = {
            Enabled = false,                 -- Enable/disable opening the furniture menu via a keybind
            DefaultKey = 'F6'               -- Default key mapping (can be reconfigured in game settings)
        }
    },

    ----------------------------------------------------------------------------
    -- Shell / Interior Template Configurations
    ----------------------------------------------------------------------------
    Shells = {
        ["Standard Motel"] = {
            label = "Standard Motel",
            hash = "standardmotel_shell",
            doorOffset = { x = -0.5, y = -2.3, z = 0.0, h = 90.0, width = 1.5 }, -- Exit door offset from the shell origin
            previewUrl = "https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/standardmotel_shell.png" -- Image link/URL or relative path to preview image
        },
        ["Modern Hotel"] = {
            label = "Modern Hotel",
            hash = "modernhotel_shell",
            doorOffset = { x = 4.98, y = 4.35, z = -0.75, h = 179.79, width = 2.0 },
            previewUrl = "https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/modernhotel_shell.png"
        },
        ["Apartment Furnished"] = {
            label = "Apartment Furnished",
            hash = "furnitured_midapart",
            doorOffset = { x = 1.44, y = -10.25, z = 0.0, h = 0.0, width = 1.5 },
            previewUrl = "https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/furnitured_midapart.png"
        },
        ["Apartment Unfurnished"] = {
            label = "Apartment Unfurnished",
            hash = "shell_v16mid",
            doorOffset = { x = 1.34, y = -14.36, z = -0.5, h = 354.08, width = 1.5 },
            previewUrl = "https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/shell_v16mid.png"
        },
        ["Apartment 2 Unfurnished"] = {
            label = "Apartment 2 Unfurnished",
            hash = "shell_v16low",
            doorOffset = { x = 4.69, y = -6.5, z = -1.0, h = 358.50, width = 1.5 },
            previewUrl = "https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/shell_v16low.png"
        },
        ["Garage"] = {
            label = "Garage",
            hash = "shell_garagem",
            doorOffset = { x = 14.0, y = 1.7, z = -0.76, h = 88.49, width = 2.0 },
            previewUrl = "https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/shell_garagem.png"
        },
        ["Office"] = {
            label = "Office",
            hash = "shell_office1",
            doorOffset = { x = 1.2, y = 4.90, z = -0.73, h = 180.0, width = 2.0 },
            previewUrl = "https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/shell_office1.png"
        },
        ["Store"] = {
            label = "Store",
            hash = "shell_store1",
            doorOffset = { x = -2.69, y = -4.56, z = -0.62, h = 1.91, width = 2.0 },
            previewUrl = "https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/shell_store1.png"
        },
        ["Warehouse"] = {
            label = "Warehouse",
            hash = "shell_warehouse1",
            doorOffset = { x = -8.96, y = 0.11, z = -0.95, h = 270.64, width = 2.0 },
            previewUrl = "https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/shell_warehouse1.png"
        },
        ["Container"] = {
            label = "Container",
            hash = "container_shell",
            doorOffset = { x = 0.05, y = -5.7, z = -0.22, h = 1.7, width = 2.2 },
            previewUrl = "https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/container_shell.png"
        },
        ["2 Floor House"] = {
            label = "2 Floor House",
            hash = "shell_michael",
            doorOffset = { x = -9.6, y = 5.63, z = -4.07, h = 268.55, width = 2.0 },
            previewUrl = "https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/shell_michael.png"
        },
        ["House 1"] = {
            label = "House 1",
            hash = "shell_frankaunt",
            doorOffset = { x = -0.34, y = -5.97, z = -0.57, h = 357.23, width = 2.0 },
            previewUrl = "https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/shell_frankaunt.png"
        },
        ["House 2"] = {
            label = "House 2",
            hash = "shell_ranch",
            doorOffset = { x = -1.23, y = -5.54, z = -1.1, h = 272.21, width = 2.0 },
            previewUrl = "https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/shell_ranch.png"
        },
        ["House 3"] = {
            label = "House 3",
            hash = "shell_lester",
            doorOffset = { x = -1.61, y = -6.02, z = -0.37, h = 357.7, width = 2.0 },
            previewUrl = "https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/shell_lester.png"
        },
        ["House 4"] = {
            label = "House 4",
            hash = "shell_trevor",
            doorOffset = { x = 0.2, y = -3.82, z = -0.41, h = 358.4, width = 2.0 },
            previewUrl = "https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/shell_trevor.png"
        },
        ["Trailer"] = {
            label = "Trailer",
            hash = "shell_trailer",
            doorOffset = { x = -1.27, y = -2.08, z = -0.48, h = 358.84, width = 2.0 },
            previewUrl = "https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Docs/Housing/Shell_Thumbnails/shell_trailer.png"
        }
    },

    ----------------------------------------------------------------------------
    -- IPL / Interior Teleport Configurations
    ----------------------------------------------------------------------------
    IPLs = {
        ["Eclipse Penthouse 1"] = {
            label = "Eclipse Penthouse 1",
            ipls = { "apa_v_mp_h_01_a" },
            coords = vec4(-786.8663, 315.7642, 217.6385, 270.0),
            exitCoords = vec4(-786.8663, 315.7642, 217.6385, 270.0),
            previewUrl = "" -- Image link/URL or relative path to preview image
        },
        ["Eclipse Penthouse 2"] = {
            label = "Eclipse Penthouse 2",
            ipls = { "apa_v_mp_h_02_a" },
            coords = vec4(-786.9563, 315.6229, 187.9136, 270.0),
            exitCoords = vec4(-786.9563, 315.6229, 187.9136, 270.0),
            previewUrl = ""
        },
        ["Eclipse Penthouse 3"] = {
            label = "Eclipse Penthouse 3",
            ipls = { "apa_v_mp_h_03_a" },
            coords = vec4(-786.8741, 315.7975, 157.9137, 270.0),
            exitCoords = vec4(-786.8741, 315.7975, 157.9137, 270.0),
            previewUrl = ""
        }
    },

    -- IGNORE
    Rooms = {},
}