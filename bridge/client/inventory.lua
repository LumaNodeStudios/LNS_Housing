Bridge.Client.OpenStash = function(propertyId, furnitureId)
    if getResourceState('ox_inventory') ~= 'started' then
        local stashId = string.format('housing_%d_%s', propertyId, furnitureId)
        exports.ox_inventory:openInventory('stash', stashId)
    else
        print('ox_inventory not started')
    end
end