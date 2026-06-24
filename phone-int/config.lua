-- Configuration
Config = {}


-- Upload Methods
Config.uploadMethod = 'fivemanage'

-- RoadShop scripts
Config.RoadPad = true
Config.RoadCarPlay = true
Config.RoadWatch = true
Config.SimCardDLC = false
Config.BatterySystem = false

-- Phone Settings
Config.PhoneCommand = 'TogglePhone'
Config.NeedItem = true
Config.RegisterKeyMapping = true
Config.OpenKey = 'f1'
Config.OpenKeyNumber = 288

-- Metadata System (Item-based phone numbers)
Config.UseMetadata = false
Config.InventorySystem = 'jaksam'

-- Backup System
Config.BackupEnabled = true
Config.AutoBackupEnabled = false
Config.MaxBackupsPerPhone = 5

-- Locale Settings
Config.Locale = 'de'
Config.Fahrenheit = false

-- Items Configuration
Config.Items = {
    'phone'
}

-- Target System
Config.UseTarget = false
Config.TargetSystem = 'ox_target'

-- Voice Chat Integration
Config.MumbleExport = 'mumble-voip'
Config.PMAVoiceExport = 'pma-voice'
Config.SaltyExport = 'saltychat'
Config.UsePmaVoice = true
Config.UseMumbleVoip = false
Config.UseSaltyChat = false
Config.UseYacaVoice = false

-- FaceTime / Video Call settings
Config.FaceTime = {
    ['RingingTimeoutSec'] = 30
}

-- Normal Voice Call settings
Config.Call = {
    ['RingTimeoutSec'] = 30
}

-- Event Numbers
Config.EventNumbers = {
    ['77777'] = false
}

-- Addons
Config.Addons = {
    ['roadpods'] = true
}

-- Valet Configuration
Config.ValetServerSideCheck = true
Config.ValetPedModel = 's_m_y_valet_01'
Config.ValetRadius = 500
Config.ValetDeliveryPrice = 500

-- Crypto Settings
Config.Crypto = false

-- Radio Settings
Config.RemoveFromRadioWhenDead = false
Config.RadioNeedItem = false
Config.RadioItems = {
    'radio'
}
Config.lockedRadioChannels = {
    {
        ['frq'] = 110,
        ['jobhasaccess'] = {
            'police',
            'ambulance',
            'fire'
        }
    },
    {
        ['frq'] = 112,
        ['jobhasaccess'] = {
            'police',
            'ambulance',
            'fire'
        }
    },
    {
        ['frq'] = 114,
        ['jobhasaccess'] = {
            'police',
            'ambulance',
            'fire'
        }
    },
    {
        ['frq'] = 115,
        ['jobhasaccess'] = {
            'police',
            'ambulance',
            'fire'
        }
    },
    {
        ['frq'] = 112110,
        ['jobhasaccess'] = {
            'police',
            'ambulance',
            'fire'
        }
    },
    {
        ['frq'] = 911,
        ['jobhasaccess'] = {
            'blackline'
        }
    },
    {
        ['frq'] = 815,
        ['jobhasaccess'] = {
            'goldenehand'
        }
    },
    {
        ['frq'] = 69,
        ['jobhasaccess'] = {
            'gmbh'
        }
    },
    {
        ['frq'] = 808,
        ['jobhasaccess'] = {
            'gmbh',
            'goldenehand',
            'blackline'
        }
    }
}

-- Housing App
-- Supported: 'esx_property', 'rtx_housing', 'ps_housing', 'rx_housing', 'LNS_Housing', 'custom'
Config.HousingSystem = 'LNS_Housing'

-- Camera App
Config.CameraDelay = 2000

-- Taxi Configuration
Config.TaxiPrice = 100
Config.TaxiJob = 'unemployed'
Config.TaxiSociety = 'society_taxi'
Config.TaxiSocietyEnabled = false

-- Service App Configuration
Config.ServiceMinGradeToManage = 0
Config.ServiceBusinessGrades = {
    ['ambulance'] = 0,
    ['blackline'] = 0,
    ['fire'] = 0,
    ['police'] = 0
}

-- News App Access
Config.NewsAppAccess = {
    'police',
    'ambulance',
    'fire',
    'blackline'
}

-- Leitstelle (Dispatch Center)
Config.Leitstelle = {
    ['ambulance'] = 112,
    ['blackline'] = 911,
    ['fire'] = 113,
    ['police'] = 110
}

-- Rent Configuration
Config.RentVehicleSpawnRadius = 500
Config.RentVehicleModel = 's_m_y_valet_01'

--Music
Config.SkipMusicNeedAccept = true

-- Billing Systems
Config.myBilling = false
Config.okokBilling = true
Config.JaksamBilling = false
Config.bcsCompanyManager = false
Config.codemBilling = false
Config.codemBilling2 = false
Config.rxBilling = false
Config.codemBilling2Folder = 'codem-billing'

-- Inventory Integration
Config.codeMInventory = false
Config.TgiannInventory = false

-- Banking System
Config.okokBanking = true
Config.rxBanking = false

-- Garage Systems
Config.JGAdvancedGarages = true
Config.cdGarages = false
Config.CodesignGarage = false

-- Miscellaneous Integrations
Config.VisnAre = true
Config.BrutalAmbulanceJob = false
Config.MXSurround = false

-- Custom Props
Config.UsePhoneProps = true

-- Debug
Config.CarDebug = false

-- Data Management
Config.clearDataTwoWeeks = true

-- Server Info Display
Config.ShowServerInfo = true
Config.AppNotifys = true
Config.CallControl = true
