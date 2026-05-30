Bridge.Client.OpenStash = function(propertyId, furnitureId)
    local stashId = string.format('housing_%d_%s', propertyId, furnitureId)
    exports.ox_inventory:openInventory('stash', stashId)
end