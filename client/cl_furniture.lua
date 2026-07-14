local Settings = lib.load('shared.settings')
local Furniture = lib.load('shared.furniture')
local Freecam = Freecam

Modeler = {
    IsMenuActive = false,
    IsFreecamMode = false,
    property_id = nil,
    shellPos = nil,
    CurrentObject = nil,
    CurrentCameraPosition = nil,
    CurrentCameraLookAt = nil,
    CurrentObjectAlpha = 200,
    Cart = {},
    IsHovering = false,
    HoverObject = nil,
    HoverDistance = 5.0,
    HoverSession = 0,

    OpenMenu = function(self, propertyId)
        local property = Properties[propertyId]
        if not property then return end
        
        
        
        self.shellPos = property.door_id and exports.ox_doorlock:getDoor(property.door_id).coords or GetEntityCoords(cache.ped)
        
        self.property_id = propertyId
        self.IsMenuActive = true
        self.MenuOpen = true

        self:UpdateOwnedItems()
        self:StartSelectionThread()

        SendNUIMessage({
            action = "setVisible",
            data = true
        })

        lib.callback('LNS_Housing:server:getFurnitureImages', false, function(imageUrls)
            imageUrls = imageUrls or {}
            local mappings = imageUrls.mappings or {}
            local baseUrl = imageUrls.baseUrl

            for _, category in ipairs(Furniture) do
                for _, item in ipairs(category.items) do
                    if mappings[item.model] then
                        item.imageUrl = mappings[item.model]
                    elseif baseUrl then
                        item.imageUrl = baseUrl .. item.model .. '.png'
                    else
                        item.imageUrl = nil
                    end
                end
            end

            SendNUIMessage({
                action = "setFurnituresData",
                data = Furniture
            })
        end)

        self:FreecamActive(true)
        self:FreecamMode(false)
    end,

    CloseMenu = function(self)
        self.IsMenuActive = false
        self.MenuOpen = false
        SetNuiFocus(false, false)
        self:StopPlacement()
        self:ClearCart()

        SendNUIMessage({
			action = "setOwnedItems",
			data = {},
		})

        SendNUIMessage({
            action = "setVisible",
            data = false
        })

        SetNuiFocus(false, false)

        self:HoverOut()
        self:UnhoverOwnedItem()
        self:StopPlacement()
        self:FreecamActive(false)

        Wait(500)

        self.CurrentCameraPosition = nil
        self.CurrentCameraLookAt = nil
        self.CurrentObject = nil
        self.property_id = nil
    end,

    GetFurnitureFromEntity = function(self, entity)
        local spawned = LoadedFurniture[self.property_id]
        if not spawned then return nil end
        
        for id, ent in pairs(spawned) do
            if ent == entity then
                local property = Properties[self.property_id]
                for _, item in ipairs(property.furniture) do
                    if item.id == id then
                        return item
                    end
                end
            end
        end
        return nil
    end,

    SelectAtCursor = function(self)
        if self.CurrentObject then return end
        
        local hit, entity = self:RaycastFromCamera()
        if hit and entity ~= 0 then
            local item = self:GetFurnitureFromEntity(entity)
            if item then
                
                local data = table.clone(item)
                data.entity = entity
                self:StartPlacement(data)
                
                
                SendNUIMessage({
                    action = "selectFurniture",
                    data = item
                })
                return true
            end
        end
        return false
    end,

    StartSelectionThread = function(self)
        CreateThread(function()
            while self.MenuOpen do
                
                
                if not self.CurrentObject and not self.IsFreecamMode and IsDisabledControlJustPressed(0, 24) then 
                    self:SelectAtCursor()
                end
                Wait(0)
            end
        end)
    end,

    RaycastFromCamera = function(self)
        local camRot = self.IsFreecamMode and Freecam:GetRotation() or GetGameplayCamRot(2)
        local camPos = self.IsFreecamMode and Freecam:GetPosition() or GetGameplayCamCoord()
        local forward = self:RotationToDirection(camRot)
        local target = camPos + (forward * 50.0) 
        
        local ray = StartShapeTestRay(camPos.x, camPos.y, camPos.z, target.x, target.y, target.z, 16, cache.ped, 0)
        local _, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(ray)
        
        return hit, entityHit
    end,

    RotationToDirection = function(self, rotation)
        local adjustedRotation = {
            x = (math.pi / 180) * rotation.x,
            y = (math.pi / 180) * rotation.y,
            z = (math.pi / 180) * rotation.z
        }
        local direction = {
            x = -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
            y = math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
            z = math.sin(adjustedRotation.x)
        }
        return vector3(direction.x, direction.y, direction.z)
    end,

    FreecamActive = function(self, bool)
        if bool then
            Freecam:SetActive(true)
            Freecam:SetKeyboardSetting('BASE_MOVE_MULTIPLIER', 0.1)
            Freecam:SetKeyboardSetting('FAST_MOVE_MULTIPLIER', 2)
            Freecam:SetKeyboardSetting('SLOW_MOVE_MULTIPLIER', 2)
            Freecam:SetFov(45.0)
            self.IsFreecamMode = true
        else
            Freecam:SetActive(false)
            Freecam:SetKeyboardSetting('BASE_MOVE_MULTIPLIER', 5)
            Freecam:SetKeyboardSetting('FAST_MOVE_MULTIPLIER', 10)
            Freecam:SetKeyboardSetting('SLOW_MOVE_MULTIPLIER', 10)
            self.IsFreecamMode = false
        end
    end,

    FreecamMode = function(self, bool)
        self.IsFreecamMode = bool
        if bool then
            Freecam:SetFrozen(false)
            SetNuiFocus(false, false)
            exports.ox_target:disableTargeting(true)
            self:StartFreecamUpdateThread()
        else
            Freecam:SetFrozen(true)
            exports.ox_target:disableTargeting(false)
            SetNuiFocus(true, true)
        end

        SendNUIMessage({
            action = "freecamMode",
            data = bool
        })
    end,

    ConstrainCamera = function(self, camPos, lastCamPos)
        local isInside = true
        
        
        if IsCoordsInsidePropertyZone then
            isInside = IsCoordsInsidePropertyZone(self.property_id, camPos)
        end
        
        
        if isInside and insideApartment and apartmentZone and apartmentZone.contains then
            isInside = apartmentZone:contains(camPos)
        end

        if not isInside then
            if lastCamPos then
                Freecam:SetPosition(lastCamPos.x, lastCamPos.y, lastCamPos.z)
                return lastCamPos
            else
                local fallback = GetEntityCoords(cache.ped)
                Freecam:SetPosition(fallback.x, fallback.y, fallback.z)
                return fallback
            end
        end

        return camPos
    end,

    StartFreecamUpdateThread = function(self)
        if self.FreecamThreadActive then return end
        self.FreecamThreadActive = true
        
        CreateThread(function()
            local lastCamPos = nil
            local lastCamTarget = nil

            while self.IsFreecamMode do
                local camPos = Freecam:GetPosition()
                local lookAt = Freecam:GetTarget(5.0)

                camPos = self:ConstrainCamera(camPos, lastCamPos)

                if not lastCamPos or #(lastCamPos - camPos) > 0.001 or #(lastCamTarget - lookAt) > 0.001 then
                    lastCamPos = camPos
                    lastCamTarget = lookAt

                    SendNUIMessage({
                        action = "updateCamera",
                        data = {
                            cameraPosition = camPos,
                            cameraLookAt = lookAt,
                            cameraFov = GetGameplayCamFov(),
                        }
                    })
                end
                Wait(33) 
            end
            self.FreecamThreadActive = false
        end)
    end,

    StartPlacement = function(self, data)
        self:HoverOut()
        local model = data.model or data.object
        local curObject
        local objectRot
        local objectPos

        self.CurrentCameraLookAt = Freecam:GetTarget(5.0)
        self.CurrentCameraPosition = Freecam:GetPosition()

        if data.entity then
            curObject = data.entity
            objectPos = GetEntityCoords(curObject)
            objectRot = GetEntityRotation(curObject, 2)
            
            
            self.PlacingData = {
                id = data.id,
                isOwned = true,
                originalPos = objectPos,
                originalRot = objectRot
            }
        else
            local hash = GetHashKey(model)
            lib.requestModel(hash)

            curObject = CreateObjectNoOffset(hash, self.CurrentCameraLookAt.x, self.CurrentCameraLookAt.y, self.CurrentCameraLookAt.z, false, false, false)
            objectRot = GetEntityRotation(curObject, 2)
            objectPos = self.CurrentCameraLookAt
            
            self.PlacingData = {
                model = model,
                label = data.label,
                price = data.price,
                category = data.category,
                isOwned = false
            }
        end

        FreezeEntityPosition(curObject, true)
        SetEntityCollision(curObject, false, false)
        SetEntityAlpha(curObject, self.CurrentObjectAlpha, false)
        SetEntityDrawOutline(curObject, true)
        SetEntityDrawOutlineColor(255, 255, 255, 255)

        self.CurrentObject = curObject
        
        
        SendNUIMessage({ 
            action = "setupModel",
            data = {
                objectPosition = objectPos,
                objectRotation = objectRot,
                cameraPosition = self.CurrentCameraPosition,
                cameraLookAt = self.CurrentCameraLookAt,
                cameraFov = GetGameplayCamFov(),
                entity = data.entity,
            }
        })

        
        self:StartPlacementThread()
    end,

    StartPlacementThread = function(self)
        if self.PlacementThreadActive then return end
        self.PlacementThreadActive = true
        
        CreateThread(function()
            local lastCamPos = nil
            local lastCamTarget = nil

            while self.CurrentObject do
                local camPos = Freecam:GetPosition()
                local camTarget = Freecam:GetTarget(5.0)
                
                camPos = self:ConstrainCamera(camPos, lastCamPos)

                
                if not lastCamPos or #(lastCamPos - camPos) > 0.001 or #(lastCamTarget - camTarget) > 0.001 then
                    lastCamPos = camPos
                    lastCamTarget = camTarget

                    SendNUIMessage({
                        action = "updateCamera",
                        data = {
                            cameraPosition = camPos,
                            cameraLookAt = camTarget,
                            cameraFov = GetGameplayCamFov(),
                        }
                    })
                end
                Wait(33) 
            end
            self.PlacementThreadActive = false
        end)
    end,

    NudgeObject = function(self, data)
        if not self.CurrentObject then return end
        
        local pos = GetEntityCoords(self.CurrentObject)
        local rot = GetEntityRotation(self.CurrentObject)
        
        if data.axis == 'x' then
            SetEntityCoords(self.CurrentObject, pos.x + data.amount, pos.y, pos.z)
        elseif data.axis == 'y' then
            SetEntityCoords(self.CurrentObject, pos.x, pos.y + data.amount, pos.z)
        elseif data.axis == 'z' then
            SetEntityCoords(self.CurrentObject, pos.x, pos.y, pos.z + data.amount)
        elseif data.axis == 'rot' then
            SetEntityRotation(self.CurrentObject, rot.x, rot.y, rot.z + data.amount, 2, true)
        end
    end,

    MoveObject = function(self, data)
        local coords = vec3(data.x + 0.0, data.y + 0.0, data.z + 0.0)
        SetEntityCoords(self.CurrentObject, coords)
    end,

    RotateObject = function(self, data)
        SetEntityRotation(self.CurrentObject, data.x + 0.0, data.y + 0.0, data.z + 0.0, 2, true)
    end,

    StopPlacement = function(self, options)
        if self.CurrentObject == nil then return end
        options = options or {}

        local data = self.PlacingData
        
        if options.save then
            if data.isOwned then
                
                self:UpdateFurniture(data.id, GetEntityCoords(self.CurrentObject), GetEntityRotation(self.CurrentObject, 2))
            else
                
            end
        else
            
            if data.isOwned then
                
                SetEntityCoords(self.CurrentObject, data.originalPos.x, data.originalPos.y, data.originalPos.z)
                SetEntityRotation(self.CurrentObject, data.originalRot.x, data.originalRot.y, data.originalRot.z, 2, true)
            else
                DeleteEntity(self.CurrentObject)
            end
        end

        FreezeEntityPosition(self.CurrentObject, true)
        SetEntityCollision(self.CurrentObject, true, true)
        SetEntityAlpha(self.CurrentObject, 255, false)
        SetEntityDrawOutline(self.CurrentObject, false)

        self.CurrentObject = nil
        self.PlacingData = nil
    end,

    PlaceOnGround = function(self)
        if not self.CurrentObject then return end
        
        local pos = GetEntityCoords(self.CurrentObject)
        local startZ = pos.z + 0.1
        local targetZ = pos.z
        local found = false
        
        for i = 1, 5 do
            local startCoords = vector3(pos.x, pos.y, startZ)
            local endCoords = vector3(pos.x, pos.y, pos.z - 30.0)
            local ray = StartShapeTestRay(startCoords.x, startCoords.y, startCoords.z, endCoords.x, endCoords.y, endCoords.z, -1, self.CurrentObject, 7)
            local retval, hit, endCoordsResult, surfaceNormal, entityHit = GetShapeTestResult(ray)
            
            if hit ~= 0 then
                if surfaceNormal.z < 0.0 then
                    startZ = endCoordsResult.z - 0.05
                    if startZ < pos.z - 30.0 then
                        break
                    end
                else
                    targetZ = endCoordsResult.z
                    found = true
                    break
                end
            else
                break
            end
        end
        
        if not found then
            local success, groundZ = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z, false)
            if success then
                targetZ = groundZ
            end
        end

        SetEntityCoords(self.CurrentObject, pos.x, pos.y, targetZ)
        
        local rot = GetEntityRotation(self.CurrentObject, 2)
        SendNUIMessage({
            action = "syncObjectState",
            data = {
                position = { x = pos.x, y = pos.y, z = targetZ },
                rotation = { x = rot.x, y = rot.y, z = rot.z }
            }
        })
    end,

    UpdateFurniture = function(self, furnitureId, pos, rot)
        local property = Properties[self.property_id]
        if not property or not property.furniture then return end
        
        for i, item in ipairs(property.furniture) do
            if item.id == furnitureId then
                item.position = pos
                item.rotation = rot
                break
            end
        end

        if property.isApartment then
            TriggerServerEvent('LNS_Housing:server:saveApartmentFurniture', self.property_id, property.furniture)
        else
            TriggerServerEvent('LNS_Housing:server:saveFurniture', self.property_id, property.furniture)
        end
    end,

    UpdateOwnedItems = function(self)
        local property = Properties[self.property_id]
        if not property then return end

        local ownedItems = {}
        local spawned = LoadedFurniture[self.property_id] or {}

        for _, item in ipairs(property.furniture or {}) do
            local entity = spawned[item.id] or spawned[tonumber(item.id)] or spawned[tostring(item.id)]
            table.insert(ownedItems, {
                id = item.id,
                model = item.model,
                label = item.label,
                entity = entity,
                position = item.position,
                rotation = item.rotation,
                category = item.category
            })
        end

        SendNUIMessage({
			action = "setOwnedItems",
			data = ownedItems,
		})
    end,

    AddToCart = function(self, data)
        local item = {
            label = data.label,
            model = data.model,
            price = data.price,
            entity = self.CurrentObject,
            position = GetEntityCoords(self.CurrentObject),
            rotation = GetEntityRotation(self.CurrentObject, 2),
            category = data.category,
        }

        if self.CurrentObject and DoesEntityExist(self.CurrentObject) then
            FreezeEntityPosition(self.CurrentObject, true)
            SetEntityCollision(self.CurrentObject, true, true)
            SetEntityAlpha(self.CurrentObject, 255, false)
            SetEntityDrawOutline(self.CurrentObject, false)
        end

        self.Cart[self.CurrentObject] = item

        SendNUIMessage({
            action = "addToCart",
            data = item
        })

        self.CurrentObject = nil 
    end,

    RemoveCartItem = function(self, data)
        local entity = tonumber(data.entity)
        if entity and DoesEntityExist(entity) then
            DeleteEntity(entity)
            self.Cart[entity] = nil
        end
    end,

    ClearCart = function(self)
        for _, v in pairs(self.Cart) do
            DeleteEntity(v.entity)
        end
        self.Cart = {}
        SendNUIMessage({ action = "clearCart" })
    end,

    BuyCart = function(self, paymentMethod)
        local items = {}
        local totalPrice = 0

        for _, v in pairs(self.Cart) do
            totalPrice = totalPrice + v.price
            items[#items + 1] = {
                id = math.random(100000, 999999),
                model = v.model,
                label = v.label,
                position = v.position,
                rotation = v.rotation,
                category = v.category
            }
        end

        local property = Properties[self.property_id]
        if property and property.isApartment then
            TriggerServerEvent("LNS_Housing:server:buyApartmentFurniture", self.property_id, items, totalPrice, paymentMethod)
        else
            TriggerServerEvent("LNS_Housing:server:buyFurniture", self.property_id, items, totalPrice, paymentMethod)
        end
        self:ClearCart()
    end,

    HoverIn = function(self, data)
        self:HoverOut()
        self.HoverSession = self.HoverSession + 1
        local currentSession = self.HoverSession

        local hash = GetHashKey(data.model)
        lib.requestModel(hash)
        
        
        if currentSession ~= self.HoverSession then
            return
        end

        self.HoverObject = CreateObjectNoOffset(hash, 0.0, 0.0, 0.0, false, false, false)
        local lookAt = Freecam:GetTarget(self.HoverDistance)
        SetEntityCoords(self.HoverObject, lookAt.x, lookAt.y, lookAt.z)
        FreezeEntityPosition(self.HoverObject, true)
        SetEntityCollision(self.HoverObject, false, false)

        self.IsHovering = true
        CreateThread(function()
            local spawnedObj = self.HoverObject
            while self.IsHovering and self.HoverSession == currentSession and DoesEntityExist(spawnedObj) do
                local rot = GetEntityRotation(spawnedObj)
                SetEntityRotation(spawnedObj, rot.x, rot.y, rot.z + 1.0)
                Wait(10)
            end
        end)
    end,

    HoverOut = function(self)
        self.HoverSession = self.HoverSession + 1 
        if self.HoverObject then
            DeleteEntity(self.HoverObject)
            self.HoverObject = nil
        end
        self.IsHovering = false
    end,

    HoverOwnedItem = function(self, data)
        self:UnhoverOwnedItem()
        
        local entity = tonumber(data.entity)
        if entity then
            entity = math.floor(entity)
            if DoesEntityExist(entity) then
                self.HoveredOwnedEntity = entity
                SetEntityDrawOutlineColor(255, 255, 255, 200)
                SetEntityDrawOutlineShader(1)
                SetEntityDrawOutline(entity, true)
            end
        end
    end,

    UnhoverOwnedItem = function(self)
        if self.HoveredOwnedEntity and DoesEntityExist(self.HoveredOwnedEntity) then
            SetEntityDrawOutline(self.HoveredOwnedEntity, false)
        end
        self.HoveredOwnedEntity = nil
    end,

    RemoveOwnedItem = function(self, data)
        local property = Properties[self.property_id]
        if not property or not property.furniture then return end

        local foundIndex = nil
        for i, item in ipairs(property.furniture) do
            if item.id == data.id or tostring(item.id) == tostring(data.id) then
                foundIndex = i
                break
            end
        end

        if foundIndex then
            table.remove(property.furniture, foundIndex)
            
            if LoadedFurniture[self.property_id] then
                UnloadFurnitures(self.property_id)
                LoadFurnitures(self.property_id)
            end
            
            self:UpdateOwnedItems()

            if property.isApartment then
                TriggerServerEvent('LNS_Housing:server:saveApartmentFurniture', self.property_id, property.furniture)
            else
                TriggerServerEvent('LNS_Housing:server:saveFurniture', self.property_id, property.furniture)
            end
        end
    end
}


RegisterNUICallback("previewFurniture", function(data, cb)
	Modeler:StartPlacement(data)
	cb("ok")
end)

RegisterNUICallback("moveObject", function(data, cb)
    if TabletPlacement and TabletPlacement.Active and TabletPlacement.Object then
        local coords = vec3(data.x + 0.0, data.y + 0.0, data.z + 0.0)
        SetEntityCoords(TabletPlacement.Object, coords)
    else
        Modeler:MoveObject(data)
    end
    cb("ok")
end)

RegisterNUICallback("rotateObject", function(data, cb)
    if TabletPlacement and TabletPlacement.Active and TabletPlacement.Object then
        SetEntityRotation(TabletPlacement.Object, data.x + 0.0, data.y + 0.0, data.z + 0.0, 2, true)
    else
        Modeler:RotateObject(data)
    end
    cb("ok")
end)

RegisterNUICallback("stopPlacement", function(data, cb)
    Modeler:StopPlacement(data)
    cb("ok")
end)

RegisterNUICallback("nudgeObject", function(data, cb)
    Modeler:NudgeObject(data)
    cb("ok")
end)

RegisterNUICallback("clickWorld", function(data, cb)
    Modeler:SelectAtCursor()
    cb("ok")
end)

RegisterNUICallback("placeOnGround", function(data, cb)
    if TabletPlacement and TabletPlacement.Active and TabletPlacement.Object then
        local pos = GetEntityCoords(TabletPlacement.Object)
        local startZ = pos.z + 0.1
        local targetZ = pos.z
        local found = false
        for i = 1, 5 do
            local startCoords = vector3(pos.x, pos.y, startZ)
            local endCoords = vector3(pos.x, pos.y, pos.z - 30.0)
            local ray = StartShapeTestRay(startCoords.x, startCoords.y, startCoords.z, endCoords.x, endCoords.y, endCoords.z, -1, TabletPlacement.Object, 7)
            local retval, hit, endCoordsResult, surfaceNormal, entityHit = GetShapeTestResult(ray)
            if hit ~= 0 then
                if surfaceNormal.z < 0.0 then
                    startZ = endCoordsResult.z - 0.05
                    if startZ < pos.z - 30.0 then
                        break
                    end
                else
                    targetZ = endCoordsResult.z
                    found = true
                    break
                end
            else
                break
            end
        end
        if not found then
            local success, groundZ = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z, false)
            if success then
                targetZ = groundZ
            end
        end
        SetEntityCoords(TabletPlacement.Object, pos.x, pos.y, targetZ)
        local rot = GetEntityRotation(TabletPlacement.Object, 2)
        SendNUIMessage({
            action = "syncObjectState",
            data = {
                position = { x = pos.x, y = pos.y, z = targetZ },
                rotation = { x = rot.x, y = rot.y, z = rot.z }
            }
        })
    else
        Modeler:PlaceOnGround()
    end
    cb("ok")
end)

RegisterNUICallback("closeUI", function(data, cb)
    Modeler:CloseMenu()
	cb("ok")
end)

RegisterNUICallback("hideUI", function(data, cb)
    Modeler:CloseMenu()
	cb("ok")
end)

function SetFreecamModeState(bool)
    if TabletPlacement and TabletPlacement.Active then
        TabletPlacement.IsFreecamMode = bool
        if bool then
            Freecam:SetFrozen(false)
            SetNuiFocus(false, false)
            exports.ox_target:disableTargeting(true)
        else
            Freecam:SetFrozen(true)
            exports.ox_target:disableTargeting(false)
            SetNuiFocus(true, true)
        end
        SendNUIMessage({
            action = "freecamMode",
            data = bool
        })
    else
        Modeler:FreecamMode(bool)
    end
end

RegisterNUICallback("freecamMode", function(data, cb)
    SetFreecamModeState(data)
    cb("ok")
end)

RegisterNUICallback("addToCart", function(data, cb)
    Modeler:AddToCart(data)
    cb("ok")
end)

RegisterNUICallback("removeCartItem", function(data, cb)
    Modeler:RemoveCartItem(data)
    cb("ok")
end)

RegisterNUICallback("buyCartItems", function(data, cb)
    local paymentMethod = data and data.paymentMethod or "bank"
    Modeler:BuyCart(paymentMethod)
    cb("ok")
end)

RegisterNUICallback("hoverIn", function(data, cb)
    Modeler:HoverIn(data)
    cb("ok")
end)

RegisterNUICallback("hoverOut", function(data, cb)
    Modeler:HoverOut()
    cb("ok")
end)

RegisterNUICallback("hoverOwnedItem", function(data, cb)
    Modeler:HoverOwnedItem(data)
    cb("ok")
end)

RegisterNUICallback("unhoverOwnedItem", function(data, cb)
    Modeler:UnhoverOwnedItem()
    cb("ok")
end)

RegisterNUICallback("removeOwnedItem", function(data, cb)
    Modeler:RemoveOwnedItem(data)
    cb("ok")
end)

RegisterNUICallback("toggleCursor", function(data, cb)
    local isFocused = IsNuiFocused()
    SetNuiFocus(not isFocused, not isFocused)
    cb("ok")
end)



RegisterNetEvent('LNS_Housing:client:openFurnitureMenu', function(propertyId)
    Modeler:OpenMenu(propertyId)
end)


CreateThread(function()
    while true do
        local sleep = 500
        local isTabletActive = TabletPlacement and TabletPlacement.Active
        if Modeler.IsMenuActive or isTabletActive then
            sleep = 0
            
            DisableControlAction(0, 19, true)

            if not IsNuiFocused() then
                local isFreecam = Modeler.IsFreecamMode or (isTabletActive and TabletPlacement.IsFreecamMode)
                
                if IsDisabledControlJustReleased(0, 19) then
                    SetFreecamModeState(false)
                end

                if isFreecam then
                    DisableControlAction(0, 177, true)
                    if IsDisabledControlJustReleased(0, 177) then
                        SetFreecamModeState(false)
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

RegisterCommand('checkfurniture', function()
    print('^2[LNS_Housing] Starting furniture check...^0')
    local invalidCount = 0
    local validCount = 0

    for _, category in ipairs(Furniture) do
        for _, item in ipairs(category.items) do
            local hash = tonumber(item.model) or GetHashKey(item.model)
            if IsModelInCdimage(hash) then
                validCount = validCount + 1
            else
                print(string.format('^1[LNS_Housing] Model NOT in game: %s (%s) under category: %s^0', item.model, item.label, category.label))
                invalidCount = invalidCount + 1
            end
        end
    end

    print(string.format('^2[LNS_Housing] Check finished. Valid models: %d, Non-existent models: %d^0', validCount, invalidCount))
end, false)