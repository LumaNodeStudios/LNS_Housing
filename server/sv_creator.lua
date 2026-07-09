local Settings = lib.load('shared.settings')
local SvSettings = lib.load('shared.sv_settings')

exports('GetSvSettings', function()
    return SvSettings
end)

function GetRealEstatePermission(source)
    return CheckPermission(source, 'realestate')
end

lib.callback.register('LNS_Housing:server:uploadPhoto', function(source, base64Data)
    local promise = promise.new()
    
    TriggerEvent('LNS_Housing:server:uploadPropertyPhotoJS', base64Data, function(url)
        promise:resolve(url)
    end)
    
    return Citizen.Await(promise)
end)

lib.callback.register('LNS_Housing:server:createHouse', function(source, data)
    local playerJob = Bridge.Server.GetPlayerJob(source)
    local citizenid = Bridge.Server.GetIdentifier(source)

    if playerJob then
        data.agency = playerJob.name
        data.agent_cid = citizenid
        local agencyConfig = Settings.RealEstate.Agencies and Settings.RealEstate.Agencies[playerJob.name]
        data.commission_rate = agencyConfig and agencyConfig.defaultCommission or 10
    end

    local spawnCoords = nil
    if data.entranceType == 'coords' and data.entranceCoords then
        data.doors = {}
        data.entrance = data.entranceCoords
        spawnCoords = vector4(data.entranceCoords.x, data.entranceCoords.y, data.entranceCoords.z, data.entranceCoords.h or 0.0)
    elseif data.doors and #data.doors > 0 then
        local doorIds = {}
        for i, door in ipairs(data.doors) do
            if type(door) == 'table' and door.isNew then
                local newDoorId = exports.ox_doorlock:createDoorlock({
                    name = (data.name or data.label or 'Property') .. ' Door ' .. i,
                    model = door.model,
                    coords = door.coords,
                    heading = door.heading,
                    state = 1,
                    maxDistance = 2.0
                })
                doorIds[#doorIds+1] = newDoorId
                if i == 1 then
                    spawnCoords = vector4(door.coords.x, door.coords.y, door.coords.z, door.heading or 0.0)
                end
            else
                doorIds[#doorIds+1] = door
                if i == 1 then
                    local doorData = nil
                    if exports.ox_doorlock and exports.ox_doorlock.getDoor then
                        pcall(function() doorData = exports.ox_doorlock:getDoor(door) end)
                    elseif exports.ox_doorlock and exports.ox_doorlock.getDoorData then
                        pcall(function() doorData = exports.ox_doorlock:getDoorData(door) end)
                    end
                    if doorData and doorData.coords then
                        spawnCoords = vector4(doorData.coords.x, doorData.coords.y, doorData.coords.z, doorData.heading or 0.0)
                    end
                end
            end
        end
        data.doors = doorIds
    end

    if not spawnCoords and data.zone_data and data.zone_data.points and #data.zone_data.points > 0 then
        local sumX, sumY, sumZ = 0, 0, 0
        local count = #data.zone_data.points
        for _, pt in ipairs(data.zone_data.points) do
            sumX = sumX + pt.x
            sumY = sumY + pt.y
            sumZ = sumZ + pt.z
        end
        spawnCoords = vector4(sumX / count, sumY / count, sumZ / count, 0.0)
    end

    data.spawn_coords = spawnCoords

    if data.garageCoords then
        local spawn = data.garageSpawnCoords or data.garageCoords
        data.garage_data = {
            x = data.garageCoords.x,
            y = data.garageCoords.y,
            z = data.garageCoords.z,
            h = data.garageCoords.h or 0.0,
            spawn = {
                x = spawn.x,
                y = spawn.y,
                z = spawn.z,
                h = spawn.h or 0.0
            }
        }
    end

    local newHouse = CreateProperty(data)
    if newHouse then
        if newHouse.metadata and newHouse.metadata.garage_data then
            Bridge.Server.RegisterGarage(newHouse.id, newHouse.label, newHouse.metadata.garage_data)
        end
        TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
        return newHouse
    end
    return nil
end)

RegisterNetEvent('LNS_Housing:server:placeBid', function(data)
    local src = source
    local propertyId = data.id
    local amount = tonumber(data.amount)
    local p = Properties[propertyId]

    if not p or p.sale_type ~= 'auction' then return end
    if not p.auction_data or p.auction_data.status ~= 'live' then
        Bridge.Server.Notify(src, 'Auction is not live!', 'error')
        return
    end

    if amount <= p.auction_data.current_bid then
        Bridge.Server.Notify(src, 'Bid must be higher than current!', 'error')
        return
    end

    local bankMoney = Bridge.Server.GetBankMoney(src)
    if bankMoney < amount then
        Bridge.Server.Notify(src, 'Not enough money in bank to place this bid!', 'error')
        return
    end

    local removed = Bridge.Server.RemoveBankMoney(src, amount, "Auction Bid: " .. p.label)
    if not removed then
        Bridge.Server.Notify(src, 'Failed to process bid transaction.', 'error')
        return
    end

    local prevBidder = p.auction_data.highest_bidder
    local prevAmount = p.auction_data.current_bid
    if prevBidder and prevAmount > 0 then
        Bridge.Server.AddOfflineBankMoney(prevBidder, prevAmount)
        local onlinePrev = Bridge.Server.IsPlayerOnline(prevBidder)
        if onlinePrev then
            Bridge.Server.Notify(onlinePrev.PlayerData.source, "You have been outbid on " .. p.label .. "! $" .. prevAmount .. " has been refunded to your bank.", "warning")
        end
    end

    p.auction_data.current_bid = amount
    p.auction_data.highest_bidder = Bridge.Server.GetIdentifier(src)

    SaveProperty(propertyId)
    TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
    Bridge.Server.Notify(src, 'You placed a bid of $' .. amount, 'success')
end)

RegisterNetEvent('LNS_Housing:server:controlAuction', function(data)
    local src = source
    local propertyId = data.id
    local action = data.action
    local p = Properties[propertyId]

    if not p or p.sale_type ~= 'auction' or p.owner then return end

    if action == 'start' then
        p.auction_data.status = 'live'
    elseif action == 'pause' then
        p.auction_data.status = 'paused'
    elseif action == 'end' then
        if p.auction_data.highest_bidder then
            p.auction_data.status = 'pending'
            Bridge.Server.Notify(src, 'Auction ended. Waiting for confirmation of bid: $' .. p.auction_data.current_bid, 'inform')
        else
            p.auction_data.status = 'ended'
        end
    elseif action == 'confirm' then
        if p.auction_data.status == 'pending' and p.auction_data.highest_bidder then
            local bidderId = p.auction_data.highest_bidder
            local amount = p.auction_data.current_bid
            local bidder = Bridge.Server.IsPlayerOnline(bidderId)

            ProcessPropertySalePayout(propertyId, amount)

            p.owner = bidderId
            p.auction_data.status = 'ended'
            if bidder then
                Bridge.Server.Notify(bidder.PlayerData.source, 'Congratulations! Your bid for ' .. p.label .. ' was confirmed!', 'success')
            end
            SyncPropertyDoor(propertyId)

            MySQL.update.await('UPDATE housing_contracts SET status = ? WHERE property_id = ? AND status = ?', {'declined', propertyId, 'pending'})

            Bridge.Server.Notify(src, 'Sale confirmed for ' .. p.label, 'success')
        end
    end

    SaveProperty(propertyId)
    TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
end)