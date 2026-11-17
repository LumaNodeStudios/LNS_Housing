local Settings = lib.load('shared.settings')

BreakerTargets = BreakerTargets or {}
local apartmentBreakerTarget = nil

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
    local bCoords = Settings.Apartments and Settings.Apartments.Building and Settings.Apartments.Building.breakerCoords
    if not bCoords then return end

    if apartmentBreakerTarget then
        exports.ox_target:removeZone(apartmentBreakerTarget)
        apartmentBreakerTarget = nil
    end

    apartmentBreakerTarget = exports.ox_target:addBoxZone({
        coords = bCoords,
        size = vec3(1.2, 1.2, 1.8),
        rotation = 0.0,
        debug = Settings.Debug.Zones,
        options = {
            {
                name = 'lns_apartment_breaker_reset',
                label = locale('target.reset_apt_breaker'),
                icon = 'fas fa-bolt',
                onSelect = function()
                    local myApt = lib.callback.await('LNS_Housing:server:getMyApartment', false)
                    local roomId = myApt and (myApt.roomId or myApt.room_id)
                    if not myApt or not roomId then
                        Bridge.Client.Notify(locale('notify.breaker_no_apt_room'), 'error')
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
                        local res = lib.callback.await('LNS_Housing:server:resetBreaker', false, roomId)
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
end

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