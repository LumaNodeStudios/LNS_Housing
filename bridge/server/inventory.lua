local Settings = lib.load('shared.settings')

Bridge.Server.RegisterStash = function(propertyId, furnitureId, storageConfig, label)
    if GetResourceState('ox_inventory') == 'started' then
        local stashId = string.format('housing_%d_%s', propertyId, furnitureId)
        local slots = storageConfig and storageConfig.slots or Settings.Stash.slots
        local weight = storageConfig and storageConfig.weight or Settings.Stash.weight
        local stashLabel = label or Settings.Stash.label
        exports.ox_inventory:RegisterStash(stashId, stashLabel, slots, weight)
    else
        print('ox_inventory not started')
    end
end

Bridge.Server.RegisterPropertyStashes = function(propertyId, furnitureList)
    if not furnitureList then return end
    for _, f in ipairs(furnitureList) do
        local itemData = nil
        for _, cat in ipairs(Settings.Furniture) do
            for _, item in ipairs(cat.items) do
                if (tonumber(item.model) or GetHashKey(item.model)) == (tonumber(f.model) or GetHashKey(f.model)) then
                    itemData = item
                    break
                end
            end
            if itemData then break end
        end

        if itemData and itemData.isStorage then
            Bridge.Server.RegisterStash(propertyId, f.id, itemData.storage, f.label)
        end
    end
end