local Settings = lib.load('shared.settings')

BreakerTargets = BreakerTargets or {}
local apartmentBreakerTarget = nil
local apartmentBreakerTargets = {}

function RegisterBreakerTarget(id)
    if not Settings.Electricity or Settings.Electricity.Enabled == false then return end
    local p = Properties[id]
    if not p then return end

    if BreakerTargets[id] then
        exports.ox_target:removeZone(BreakerTargets[id])
        BreakerTargets[id] = nil
    end

    local breakerCoords = nil
    if p.metadata and p.metadata.breaker_coords then
        local bc = p.metadata.breaker_coords
        breakerCoords = vector3(bc.x, bc.y, bc.z)
    else
        local entranceCoords = GetEntranceCoords(p)
        if entranceCoords then
            breakerCoords = entranceCoords
        end
    end

    if not breakerCoords then return end

    BreakerTargets[id] = exports.ox_target:addBoxZone({
        coords = breakerCoords,
        size = vec3(1.2, 1.2, 1.8),
        rotation = 0.0,
        debug = Settings.Debug.Zones,
        options = {
            {
                name = 'lns_breaker_reset_' .. id,
                label = locale('target.reset_breaker_box'),
                icon = 'fas fa-bolt',
                onSelect = function()
                    local stats = lib.callback.await('LNS_Housing:server:getPropertyUsageStats', false, id)
                    if stats and not stats.breakerTripped then
                        Bridge.Client.Notify(locale('notify.breaker_normal'), 'inform')
                        return
                    end

                    local difficulty = (Settings.Electricity and Settings.Electricity.BreakerSkillCheck) or { 'easy', 'medium' }
                    local success = Bridge.Client.SkillCheck(difficulty, { 'w', 'a', 's', 'd' })
                    if success then
                        local res = lib.callback.await('LNS_Housing:server:resetBreaker', false, id)
                        if res and res.success then
                            Bridge.Client.Notify(res.message, 'success')
                        else
                            Bridge.Client.Notify(res and res.message or locale('notify.breaker_reset_failed'), 'error')
                        end
                    else
                        Bridge.Client.Notify(locale('notify.breaker_skill_failed'), 'error')
                    end
                end,
                canInteract = function()
                    return true
                end
            }
        }
    })
end

function CreateApartmentBreakerTarget()
    if not Settings.Electricity or Settings.Electricity.Enabled == false then return end

    if apartmentBreakerTargets then
        for _, zoneId in ipairs(apartmentBreakerTargets) do
            exports.ox_target:removeZone(zoneId)
        end
        apartmentBreakerTargets = {}
    end
    if apartmentBreakerTarget then
        exports.ox_target:removeZone(apartmentBreakerTarget)
        apartmentBreakerTarget = nil
    end

    local buildings = Bridge.GetApartmentBuildings()
    for _, building in ipairs(buildings) do
        local breakerCoordsList = building.breakerCoordsList or (building.breakerCoords and { building.breakerCoords }) or {}
        local bId = building.id
        local bLabel = building.label or "Apartments"

        for idx, bCoords in ipairs(breakerCoordsList) do
            local zoneId = exports.ox_target:addBoxZone({
                coords = bCoords,
                size = vec3(1.2, 1.2, 1.8),
                rotation = 0.0,
                debug = Settings.Debug.Zones,
                options = {
                    {
                        name = 'lns_apt_breaker_' .. bId .. '_' .. idx,
                        label = locale('target.reset_apt_breaker'),
                        icon = 'fas fa-bolt',
                        onSelect = function()
                            local myApt = lib.callback.await('LNS_Housing:server:getMyApartment', false)
                            local roomId = myApt and (myApt.roomId or myApt.room_id)
                            if not myApt or not roomId then
                                Bridge.Client.Notify(locale('notify.breaker_no_apt_room'), 'error')
                                return
                            end

                            local myBuildingId = myApt.buildingId or (myApt.roomData and (myApt.roomData.buildingId or myApt.roomData.building_id)) or MyBuildingId
                            if myBuildingId and myBuildingId ~= bId then
                                local actualBldg = Bridge.GetApartmentBuildingById(myBuildingId, true)
                                local actualLabel = actualBldg and actualBldg.label or myBuildingId
                                Bridge.Client.Notify(locale('notify.apt_wrong_building', actualLabel), 'error')
                                return
                            end

                            local stats = lib.callback.await('LNS_Housing:server:getPropertyUsageStats', false, roomId)
                            if stats and not stats.breakerTripped then
                                Bridge.Client.Notify(locale('notify.breaker_apt_normal'), 'inform')
                                return
                            end

                            local difficulty = (Settings.Electricity and Settings.Electricity.BreakerSkillCheck) or { 'easy', 'medium' }
                            local success = Bridge.Client.SkillCheck(difficulty, { 'w', 'a', 's', 'd' })
                            if success then
                                local res = lib.callback.await('LNS_Housing:server:resetBreaker', false, roomId, bId)
                                if res and res.success then
                                    Bridge.Client.Notify(res.message, 'success')
                                else
                                    Bridge.Client.Notify(res and res.message or locale('notify.breaker_reset_failed'), 'error')
                                end
                            else
                                Bridge.Client.Notify(locale('notify.breaker_apt_skill_failed'), 'error')
                            end
                        end,
                        canInteract = function()
                            return true
                        end
                    }
                }
            })
            table.insert(apartmentBreakerTargets, zoneId)
        end
    end
end

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    if apartmentBreakerTargets then
        for _, zoneId in ipairs(apartmentBreakerTargets) do
            exports.ox_target:removeZone(zoneId)
        end
        apartmentBreakerTargets = {}
    end
    if apartmentBreakerTarget then
        exports.ox_target:removeZone(apartmentBreakerTarget)
        apartmentBreakerTarget = nil
    end
end)

function CheckPropertyTemperatureNotify(propertyId)
    if not Settings.Temperature or Settings.Temperature.Enabled == false or Settings.Temperature.NotifyOnEnter == false then return end

    CreateThread(function()
        Wait(600)
        local stats = lib.callback.await('LNS_Housing:server:getPropertyUsageStats', false, propertyId)
        if not stats or not stats.netTemp then return end

        local isCelsius = Settings.Temperature and (Settings.Temperature.Unit == 'Celsius' or Settings.Temperature.Unit == 'C')
        local unitSym = isCelsius and "°C" or "°F"
        local displayTemp = stats.displayTemp or (isCelsius and ((stats.netTemp - 32) * (5 / 9)) or stats.netTemp)
        local minComfort = isCelsius and (((Settings.Temperature.MinComfortableTemp or 62.0) - 32) * (5 / 9)) or (Settings.Temperature.MinComfortableTemp or 62.0)
        local maxComfort = isCelsius and (((Settings.Temperature.MaxComfortableTemp or 78.0) - 32) * (5 / 9)) or (Settings.Temperature.MaxComfortableTemp or 78.0)

        if displayTemp < minComfort then
            Bridge.Client.Notify(locale('notify.temp_cold', displayTemp, unitSym), 'warning')
        elseif displayTemp > maxComfort then
            Bridge.Client.Notify(locale('notify.temp_hot', displayTemp, unitSym), 'warning')
        else
            Bridge.Client.Notify(locale('notify.temp_comfortable', displayTemp, unitSym), 'inform')
        end

        if stats.breakerTripped then
            Wait(1200)
            Bridge.Client.Notify(locale('notify.power_overload', stats.totalPower, stats.maxPower), 'error')
        end
    end)
end

RegisterNetEvent('LNS_Housing:client:breakerTrippedNotify', function(propertyId, totalPower, maxPower)
    if not Settings.Electricity or Settings.Electricity.Enabled == false then return end
    Bridge.Client.Notify(locale('notify.power_tripped_capacity', totalPower, maxPower), 'error')
end)

RegisterNetEvent('LNS_Housing:client:breakerReset', function(propertyId)
    Bridge.Client.Notify(locale('notify.power_restored'), 'success')
end)