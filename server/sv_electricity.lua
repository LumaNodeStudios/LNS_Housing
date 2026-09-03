local Settings = lib.load('shared.settings')
local FurnitureLookupByModel = {}
local FurnitureLookupByHash = {}
local FurnitureLookupById = {}
local FurnitureLookupByLabel = {}
local isLookupBuilt = false

local function EnsureFurnitureLookup()
    if isLookupBuilt and next(FurnitureLookupByModel) ~= nil then return end

    local SharedFurniture = lib.load('shared.furniture')
    if not SharedFurniture then return end

    FurnitureLookupByModel = {}
    FurnitureLookupByHash = {}
    FurnitureLookupById = {}
    FurnitureLookupByLabel = {}

    for _, cat in ipairs(SharedFurniture) do
        for _, item in ipairs(cat.items or {}) do
            if item.model then
                local modelStr = tostring(item.model):lower()
                local existing = FurnitureLookupByModel[modelStr]
                if not existing or (item.powerConsumption and not existing.powerConsumption) then
                    FurnitureLookupByModel[modelStr] = item
                    local hash = joaat(modelStr)
                    FurnitureLookupByHash[hash] = item
                end
            end
            if item.id then
                local idStr = tostring(item.id):lower()
                local existing = FurnitureLookupById[idStr]
                if not existing or (item.powerConsumption and not existing.powerConsumption) then
                    FurnitureLookupById[idStr] = item
                end
            end
            if item.label then
                local labelStr = tostring(item.label):lower()
                local existing = FurnitureLookupByLabel[labelStr]
                if not existing or (item.powerConsumption and not existing.powerConsumption) then
                    FurnitureLookupByLabel[labelStr] = item
                end
            end
        end
    end
    isLookupBuilt = true
end

local function GetFurnitureItemData(f)
    if not f then return nil end
    EnsureFurnitureLookup()

    if f.label then
        local labelStr = tostring(f.label):lower()
        local item = FurnitureLookupByLabel[labelStr]
        if item and (item.powerConsumption or item.tempEffect) then
            return item
        end
    end

    if f.model then
        local modelStr = tostring(f.model):lower()
        if FurnitureLookupByModel[modelStr] then
            return FurnitureLookupByModel[modelStr]
        end
        local numModel = tonumber(f.model) or joaat(modelStr)
        if numModel and FurnitureLookupByHash[numModel] then
            return FurnitureLookupByHash[numModel]
        end
    end

    if type(f.model) == 'number' then
        if FurnitureLookupByHash[f.model] then
            return FurnitureLookupByHash[f.model]
        end
    end

    if f.label then
        local labelStr = tostring(f.label):lower()
        if FurnitureLookupByLabel[labelStr] then
            return FurnitureLookupByLabel[labelStr]
        end
    end

    if f.id and type(f.id) == 'string' then
        local idStr = f.id:lower()
        if FurnitureLookupById[idStr] then
            return FurnitureLookupById[idStr]
        end
    end

    return nil
end

function CalculatePropertyPowerAndTemp(propertyId)
    if not propertyId then return 0.0, 70.0, false, 5.0, 0.0 end
    
    local numId = tonumber(propertyId)
    local strId = tostring(propertyId)
    local p = Properties[propertyId] or (numId and Properties[numId]) or Properties[strId]
    local furnitureList = nil
    local sourceName = "Properties Table"

    if p and p.furniture then
        if type(p.furniture) == 'table' and #p.furniture > 0 then
            furnitureList = p.furniture
        elseif type(p.furniture) == 'string' then
            furnitureList = json.decode(p.furniture)
        end
    end

    if not furnitureList or (type(furnitureList) == 'table' and #furnitureList == 0) then
        local dbRow = MySQL.single.await('SELECT furniture FROM apartments WHERE room_id = ? OR room_id = ?', { strId, numId or strId })
        if dbRow and dbRow.furniture then
            furnitureList = json.decode(dbRow.furniture or '[]')
            sourceName = "apartments DB table"
        end
    end

    if not furnitureList or (type(furnitureList) == 'table' and #furnitureList == 0) then
        if numId then
            local dbProp = MySQL.single.await('SELECT furniture FROM housing_properties WHERE id = ?', { numId })
            if dbProp and dbProp.furniture then
                furnitureList = json.decode(dbProp.furniture or '[]')
                sourceName = "housing_properties DB table"
            end
        end
    end

    print(string.format("^3[DEBUG Electricity]^7 Starting Calculation for Property #%s (Source: %s)", strId, sourceName))

    local totalPower = 0.0
    local tempDelta = 0.0
    local baseTemp = (Settings.Temperature and Settings.Temperature.BaseTemperature) or 70.0
    local itemsMatchedCount = 0

    if furnitureList and type(furnitureList) == 'table' then
        print(string.format("^3[DEBUG Electricity]^7 Found %d furniture items in payload.", #furnitureList))
        for i, f in ipairs(furnitureList) do
            print(string.format("^2[DEBUG Item #%d Raw Payload]^7 %s", i, json.encode(f)))

            local itemData = GetFurnitureItemData(f)
            if itemData then
                itemsMatchedCount = itemsMatchedCount + 1
                print(string.format("^2[DEBUG Item #%d Matched Catalog]^7 ID: %s | Label: %s | Model: %s | Catalog Power: %s | Catalog Temp: %s",
                    i, tostring(itemData.id), tostring(itemData.label), tostring(itemData.model),
                    tostring(itemData.powerConsumption or itemData.power_consumption or itemData.power or "NONE"),
                    tostring(itemData.tempEffect or itemData.temp_effect or itemData.temp or "NONE")))
            else
                print(string.format("^1[DEBUG Item #%d UNMATCHED CATALOG]^7 Model '%s' / Label '%s' could not be found in shared/furniture.lua",
                    i, tostring(f.model or f.name or f.object), tostring(f.label or 'None')))
            end

            local itemRef = itemData or f
            local pwr = 0.0
            if itemRef then
                pwr = tonumber(itemRef.powerConsumption) or tonumber(itemRef.power_consumption) or tonumber(itemRef.power) or 0.0
            end

            local tmp = 0.0
            if itemRef then
                tmp = tonumber(itemRef.tempEffect) or tonumber(itemRef.temp_effect) or tonumber(itemRef.temp) or 0.0
            end

            totalPower = totalPower + pwr
            tempDelta = tempDelta + tmp

            print(string.format("^5[DEBUG Item #%d Final Contribution]^7 Added Power: %.2f kWh | Added Temp: %.1f°F | Running Power: %.2f kWh",
                i, pwr, tmp, totalPower))
        end
    else
        print(string.format("^1[DEBUG Electricity]^7 Furniture list is EMPTY or invalid for Property #%s", strId))
    end

    print(string.format("^3[DEBUG Electricity Summary]^7 Property #%s | Matched %d/%d items | Total Power: %.2f kWh | Base Temp: %.1f°F | Temp Delta: %.1f°F | Net Temp: %.1f°F",
        strId, itemsMatchedCount, furnitureList and #furnitureList or 0, totalPower, baseTemp, tempDelta, baseTemp + tempDelta))

    local maxPower = (p and p.metadata and tonumber(p.metadata.max_power)) or ((Settings.Electricity and Settings.Electricity.DefaultMaxPower) or 5.0)
    local tripped = p and p.metadata and p.metadata.breaker_tripped or false

    if totalPower > maxPower and not tripped then
        if p then
            if not p.metadata then p.metadata = {} end
            p.metadata.breaker_tripped = true
            SaveProperty(propertyId)
        end
        tripped = true
        TriggerClientEvent('LNS_Housing:client:breakerTrippedNotify', -1, propertyId, totalPower, maxPower)
    end

    local netTemp = baseTemp + tempDelta
    return totalPower, netTemp, tripped, maxPower, tempDelta
end

lib.callback.register('LNS_Housing:server:getPropertyUsageStats', function(source, propertyId)
    local numId = tonumber(propertyId)
    local strId = tostring(propertyId)
    local totalPower, netTemp, tripped, maxPower, tempDelta = CalculatePropertyPowerAndTemp(propertyId)
    local p = Properties[propertyId] or (numId and Properties[numId]) or Properties[strId]

    local tempUnit = (Settings.Temperature and Settings.Temperature.Unit) or 'Fahrenheit'
    local isCelsius = (tempUnit == 'Celsius' or tempUnit == 'C')
    local unitSymbol = isCelsius and '°C' or '°F'

    local displayTemp = isCelsius and ((netTemp - 32) * (5 / 9)) or netTemp
    local displayDelta = isCelsius and (tempDelta * (5 / 9)) or tempDelta
    local maxTemp = isCelsius and 38.0 or 100.0

    return {
        totalPower = totalPower,
        maxPower = maxPower,
        powerLevel = p and p.metadata and p.metadata.power_level or 1,
        netTemp = netTemp,
        displayTemp = displayTemp,
        tempDelta = tempDelta,
        displayDelta = displayDelta,
        tempUnit = tempUnit,
        unitSymbol = unitSymbol,
        maxTemp = maxTemp,
        breakerTripped = tripped,
        breakerCoords = p and p.metadata and p.metadata.breaker_coords or nil
    }
end)

lib.callback.register('LNS_Housing:server:resetBreaker', function(source, propertyId)
    local src = source
    local p = Properties[propertyId]
    if not p then return { success = false, message = "Property not found." } end

    local totalPower, netTemp, tripped, maxPower = CalculatePropertyPowerAndTemp(propertyId)
    if totalPower > maxPower then
        return {
            success = false,
            message = string.format("Breaker tripped again! Usage (%.1f kWh) exceeds max limit (%.1f kWh). Remove electronics or upgrade power.", totalPower, maxPower)
        }
    end

    p.metadata.breaker_tripped = false
    SaveProperty(propertyId)
    TriggerClientEvent('LNS_Housing:client:breakerReset', -1, propertyId)

    return {
        success = true,
        message = "Breaker box reset! Electrical power restored."
    }
end)

lib.callback.register('LNS_Housing:server:upgradePower', function(source, propertyId, targetLevel)
    local src = source
    local p = Properties[propertyId]
    if not p then return { success = false, message = "Property not found." } end

    local cid = Bridge.Server.GetIdentifier(src)
    if p.owner ~= cid then
        return { success = false, message = "Only the property owner can upgrade electricity capacity." }
    end

    local upgradesConfig = Settings.Electricity and Settings.Electricity.Upgrades
    if not upgradesConfig or not upgradesConfig[targetLevel] then
        return { success = false, message = "Invalid upgrade tier." }
    end

    local tier = upgradesConfig[targetLevel]
    local price = tier.price or 0

    if price > 0 then
        local money = Bridge.Server.GetMoney(src, 'bank')
        if money < price then
            money = Bridge.Server.GetMoney(src, 'cash')
            if money < price then
                return { success = false, message = "Insufficient funds for power upgrade." }
            else
                Bridge.Server.RemoveMoney(src, 'cash', price, "Upgraded property #" .. propertyId .. " power grid")
            end
        else
            Bridge.Server.RemoveMoney(src, 'bank', price, "Upgraded property #" .. propertyId .. " power grid")
        end
    end

    p.metadata.max_power = tier.maxPower
    p.metadata.power_level = targetLevel

    local totalPower, netTemp = CalculatePropertyPowerAndTemp(propertyId)
    if totalPower <= tier.maxPower then
        p.metadata.breaker_tripped = false
    end

    SaveProperty(propertyId)
    TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)

    return {
        success = true,
        maxPower = tier.maxPower,
        powerLevel = targetLevel,
        breakerTripped = p.metadata.breaker_tripped,
        totalPower = totalPower,
        netTemp = netTemp
    }
end)

local function GetPropertyEntrance(p)
    if not p then return nil end
    if GetEntranceCoordsServer then
        local c = GetEntranceCoordsServer(p)
        if c then return c end
    end
    if p.metadata and p.metadata.entrance then
        local ent = p.metadata.entrance
        return vec3(ent.x, ent.y, ent.z)
    end
    return nil
end

RegisterCommand('cutpower', function(source, args)
    local src = source
    local propertyId = tonumber(args[1])
    
    if not propertyId and src > 0 then
        local playerPed = GetPlayerPed(src)
        local pCoords = GetEntityCoords(playerPed)
        local closestId = nil
        local closestDist = 9999.0
        
        for id, p in pairs(Properties) do
            local e = GetPropertyEntrance(p)
            if e then
                local dist = #(pCoords - vector3(e.x, e.y, e.z))
                if dist < closestDist then
                    closestDist = dist
                    closestId = id
                end
            end
        end
        if closestDist < 50.0 then
            propertyId = closestId
        end
    end

    if not propertyId or not Properties[propertyId] then
        if src > 0 then
            Bridge.Server.Notify(src, "Usage: /cutpower [propertyId] (or stand near your property)", "error")
        else
            print("Usage: /cutpower [propertyId]")
        end
        return
    end

    local p = Properties[propertyId]
    if not p.metadata then p.metadata = {} end
    p.metadata.breaker_tripped = true
    SaveProperty(propertyId)

    local totalPower, maxPower = 0.0, 5.0
    if CalculatePropertyPowerAndTemp then
        totalPower, _, _, maxPower = CalculatePropertyPowerAndTemp(propertyId)
    end

    TriggerClientEvent('LNS_Housing:client:breakerTrippedNotify', -1, propertyId, totalPower, maxPower)
    
    if src > 0 then
        Bridge.Server.Notify(src, string.format("Power manually cut to Property #%d! Circuit breaker tripped.", propertyId), "warning")
    else
        print(string.format("[LNS_Housing] Power cut to Property #%d", propertyId))
    end
end, false)

RegisterCommand('restorepower', function(source, args)
    local src = source
    local propertyId = tonumber(args[1])

    if not propertyId and src > 0 then
        local playerPed = GetPlayerPed(src)
        local pCoords = GetEntityCoords(playerPed)
        local closestId = nil
        local closestDist = 9999.0

        for id, p in pairs(Properties) do
            local e = GetPropertyEntrance(p)
            if e then
                local dist = #(pCoords - vector3(e.x, e.y, e.z))
                if dist < closestDist then
                    closestDist = dist
                    closestId = id
                end
            end
        end
        if closestDist < 50.0 then
            propertyId = closestId
        end
    end

    if not propertyId or not Properties[propertyId] then
        if src > 0 then
            Bridge.Server.Notify(src, "Usage: /restorepower [propertyId] (or stand near your property)", "error")
        else
            print("Usage: /restorepower [propertyId]")
        end
        return
    end

    local p = Properties[propertyId]
    if not p.metadata then p.metadata = {} end
    p.metadata.breaker_tripped = false
    SaveProperty(propertyId)

    TriggerClientEvent('LNS_Housing:client:breakerReset', -1, propertyId)

    if src > 0 then
        Bridge.Server.Notify(src, string.format("Power restored to Property #%d!", propertyId), "success")
    else
        print(string.format("[LNS_Housing] Power restored to Property #%d", propertyId))
    end
end, false)