local Settings = lib.load('shared.settings')
local Furniture = lib.load('shared.furniture')
local Freecam = Freecam

local function FindCatalogItem(model)
    for _, category in ipairs(Furniture) do
        for _, item in ipairs(category.items) do
            if item.model == model then
                return item, category.id
            end
        end
    end
end

Modeler = {
    IsMenuActive = false,
    IsFreecamMode = false,
    FurnitureDataReady = false,
    property_id = nil,
    shellPos = nil,
    CurrentObject = nil,
    CurrentCameraPosition = nil,
    CurrentCameraLookAt = nil,
    CurrentObjectAlpha = 200,
    Cart = {},
    last_property_id = nil,
    IsHovering = false,
    HoverObject = nil,
    HoverDistance = 5.0,
    HoverSession = 0,
    Clipboard = nil,

    OpenMenu = function(self, propertyId)
        local property = Properties[propertyId]
        if not property then return end

        if self.last_property_id and self.last_property_id ~= propertyId then
            self:ClearCart()
        end
        self.last_property_id = propertyId

        local entranceCoords = GetEntranceCoords(property)
        self.shellPos = entranceCoords or GetEntityCoords(cache.ped)
        self.property_id = propertyId
        self.IsMenuActive = true
        self.MenuOpen = true
        self:SpawnCartProps()
        self:UpdateOwnedItems()
        self:StartSelectionThread()

        SendNUIMessage({ action = "setVisible", data = true })

        local cartList = {}
        for _, item in pairs(self.Cart) do
            table.insert(cartList, item)
        end
        SendNUIMessage({
            action = "setCart",
            data = cartList
        })

        if self.FurnitureDataReady then
            SendNUIMessage({ action = "setFurnituresData", data = Furniture })
        else
            lib.callback('LNS_Housing:server:getFurnitureImages', false, function(imageUrls)
                imageUrls = imageUrls or {}
                local mappings = imageUrls.mappings or {}
                local baseUrl = imageUrls.baseUrl

                if not baseUrl and next(mappings) == nil then
                    lib.print.error('getFurnitureImages returned no baseUrl and no mappings, not caching')
                else
                    self.FurnitureDataReady = true
                end

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

                SendNUIMessage({ action = "setFurnituresData", data = Furniture })
            end)
        end

        self:FreecamActive(true)
        self:FreecamMode(false)

        TriggerServerEvent('LNS_Housing:server:enterFurnitureBucket', propertyId)
    end,

    CloseMenu = function(self)
        self.IsMenuActive = false
        self.MenuOpen = false
        SetNuiFocus(false, false)
        self:StopPlacement()
        self:DespawnCartProps()

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

        TriggerServerEvent('LNS_Housing:server:leaveFurnitureBucket')

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

        GetCartItemFromEntity = function(self, entity)
        for _, item in pairs(self.Cart) do
            if item.entity == entity then return item end
        end
        return nil
    end,

    ResolveEntity = function(self, entity)
        local cartItem = self:GetCartItemFromEntity(entity)
        if cartItem then return cartItem, 'cart' end

        local owned = self:GetFurnitureFromEntity(entity)
        if owned then return owned, 'owned' end

        return nil
    end,

    ScreenPointToRay = function(self, nx, ny)
        local camPos = GetFinalRenderedCamCoord()
        local camRot = GetFinalRenderedCamRot(2)
        local fov = GetFinalRenderedCamFov()
        local sw, sh = GetActiveScreenResolution()
        local aspect = sw / sh

        local forward = self:RotationToDirection(camRot)
        local right = vector3(forward.y, -forward.x, 0.0)
        local rl = #right
        if rl < 0.0001 then
            right = vector3(1.0, 0.0, 0.0)
        else
            right = right / rl
        end
        local up = vector3(
            right.y * forward.z,
            -right.x * forward.z,
            right.x * forward.y - right.y * forward.x
        )

        local tanY = math.tan(math.rad(fov) / 2.0)
        local tanX = tanY * aspect
        local ox = (nx * 2.0 - 1.0) * tanX
        local oy = (1.0 - ny * 2.0) * tanY

        local dir = forward + right * ox + up * oy
        dir = dir / #dir

        return camPos, dir
    end,

    RaycastFromScreen = function(self, nx, ny)
        local origin, dir = self:ScreenPointToRay(nx, ny)
        local target = origin + dir * 50.0

        local ray = StartExpensiveSynchronousShapeTestLosProbe(
            origin.x, origin.y, origin.z,
            target.x, target.y, target.z,
            16, cache.ped, 0
        )
        local _, hit, hitCoords, _, entityHit = GetShapeTestResult(ray)

        return hit == 1, entityHit, hitCoords
    end,

    RayHitsEntityBounds = function(self, entity, origin, dir)
        local PAD = 0.05
        local MIN_SIZE = 0.25
        local mn, mx = GetModelDimensions(GetEntityModel(entity))
        local lo = GetOffsetFromEntityGivenWorldCoords(entity, origin.x, origin.y, origin.z)
        local far = origin + dir
        local lf = GetOffsetFromEntityGivenWorldCoords(entity, far.x, far.y, far.z)
        local ld = lf - lo
        local o = { lo.x, lo.y, lo.z }
        local d = { ld.x, ld.y, ld.z }
        local lower = { mn.x, mn.y, mn.z }
        local upper = { mx.x, mx.y, mx.z }

        local tNear, tFar = -math.huge, math.huge
        for i = 1, 3 do
            local a, b = lower[i] - PAD, upper[i] + PAD
            if b - a < MIN_SIZE then
                local c = (a + b) / 2.0
                a, b = c - MIN_SIZE / 2.0, c + MIN_SIZE / 2.0
            end

            if math.abs(d[i]) < 1e-6 then
                if o[i] < a or o[i] > b then return nil end
            else
                local t1, t2 = (a - o[i]) / d[i], (b - o[i]) / d[i]
                if t1 > t2 then t1, t2 = t2, t1 end
                if t1 > tNear then tNear = t1 end
                if t2 < tFar then tFar = t2 end
                if tNear > tFar then return nil end
            end
        end

        if tFar < 0.0 then return nil end
        if tNear < 0.0 then tNear = tFar end
        if tNear > 50.0 then return nil end

        return tNear
    end,

    PickByBounds = function(self, origin, dir)
        local bestEntity, bestT = nil, math.huge

        local function check(entity)
            if entity and DoesEntityExist(entity) then
                local t = self:RayHitsEntityBounds(entity, origin, dir)
                if t and t < bestT then
                    bestEntity, bestT = entity, t
                end
            end
        end

        for _, item in pairs(self.Cart) do check(item.entity) end
        for _, entity in pairs(LoadedFurniture[self.property_id] or {}) do check(entity) end

        return bestEntity, bestT
    end,

    SelectAtCursor = function(self, nx, ny)
        if not self.IsMenuActive or self.CurrentObject then return false end
        nx = nx or 0.5
        ny = ny or 0.5

        local origin, dir = self:ScreenPointToRay(nx, ny)

        local item, kind, entity
        local bestDist = math.huge
        local worldHitDist = math.huge
        local hit, hitEntity, hitCoords = self:RaycastFromScreen(nx, ny)

        if hit and hitEntity ~= 0 then
            worldHitDist = #(hitCoords - origin)
            local resolved, resolvedKind = self:ResolveEntity(hitEntity)
            if resolved then
                item, kind, entity = resolved, resolvedKind, hitEntity
                bestDist = worldHitDist
            end
        end

        local boxEntity, boxDist = self:PickByBounds(origin, dir)
        if boxEntity and boxDist < bestDist then
            local blocked = (not item) and worldHitDist < boxDist - 0.1
            if not blocked then
                local resolved, resolvedKind = self:ResolveEntity(boxEntity)
                if resolved then
                    item, kind, entity = resolved, resolvedKind, boxEntity
                end
            end
        end

        if not item then return false end

        self:UnhoverOwnedItem()

        local data = table.clone(item)
        data.entity = entity
        data.kind = kind
        self:StartPlacement(data)

        local p = self.PlacingData
        SendNUIMessage({
            action = "selectFurniture",
            data = {
                kind = p.kind,
                id = p.id,
                cartId = p.cartId,
                model = p.model,
                label = p.label,
                price = p.price,
                category = p.category,
            }
        })
        return true
    end,

    CopyCurrent = function(self)
        if not self.IsMenuActive or not self.CurrentObject or not self.PlacingData then return false end
        local d = self.PlacingData
        self.Clipboard = {
            model = d.model,
            label = d.label,
            price = d.price,
            category = d.category,
            position = GetEntityCoords(self.CurrentObject),
            rotation = GetEntityRotation(self.CurrentObject, 2),
        }
        return true
    end,

    CommitPlacement = function(self)
        if not self.CurrentObject then return end
        if self.PlacingData and self.PlacingData.kind == 'new' then
            self:AddToCart(self.PlacingData)
        else
            self:StopPlacement({ save = true })
        end
    end,

    PasteClipboard = function(self)
        local clip = self.Clipboard
        if not self.IsMenuActive or not clip then return false end

        if self.CurrentObject then
            local wasPaste = self.PlacingData and self.PlacingData.fromPaste
            local curPos = GetEntityCoords(self.CurrentObject)
            local curRot = GetEntityRotation(self.CurrentObject, 2)
            self:CommitPlacement()
            if wasPaste then
                clip.position = curPos
                clip.rotation = curRot
            end
        end

        self:StartPlacement({
            model = clip.model,
            label = clip.label,
            price = clip.price,
            category = clip.category,
            position = clip.position,
            rotation = clip.rotation,
            fromPaste = true,
        })

        SendNUIMessage({
            action = "selectFurniture",
            data = {
                kind = 'new',
                model = clip.model,
                label = clip.label,
                price = clip.price,
                category = clip.category,
            }
        })
        return true
    end,

        DeleteCurrent = function(self)
        if not self.IsMenuActive or not self.CurrentObject or not self.PlacingData then return false end

        local d = self.PlacingData

        if d.kind == 'new' then
            self:StopPlacement()
        elseif d.kind == 'cart' then
            local cartId = d.cartId
            self.CurrentObject = nil
            self.PlacingData = nil
            self:RemoveCartItem({ cartId = cartId })
            SendNUIMessage({ action = "removeCartItem", data = { cartId = cartId } })
        elseif d.kind == 'owned' then
            local id = d.id
            self:StopPlacement()
            self:RemoveOwnedItem({ id = id })
        end

        SendNUIMessage({ action = "placementEnded" })
        return true
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
        
        local currentZone = apartmentZones and apartmentZones[self.property_id]
        if isInside and insideApartment and currentZone and currentZone.contains then
            isInside = currentZone:contains(camPos)
        end

        local anchor = self.shellPos or GetEntityCoords(cache.ped)
        if isInside and #(camPos - anchor) > 50.0 then
            isInside = false
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

        StartPlacement = function(self, data)
        self:HoverOut()
        local model = data.model or data.object
        local catalog, catalogCategory = FindCatalogItem(model)
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
                kind = data.kind or 'owned',
                id = data.id,
                cartId = data.cartId,
                model = model,
                label = data.label or (catalog and catalog.label),
                price = data.price or (catalog and catalog.price),
                category = data.category or catalogCategory,
                originalPos = objectPos,
                originalRot = objectRot,
            }
        else
            local hash = GetHashKey(model)
            lib.requestModel(hash)

            local spawn = data.position or self.CurrentCameraLookAt
            curObject = CreateObjectNoOffset(hash, spawn.x, spawn.y, spawn.z, false, false, false)
            if data.rotation then
                SetEntityRotation(curObject, data.rotation.x, data.rotation.y, data.rotation.z, 2, true)
            end
            objectRot = GetEntityRotation(curObject, 2)
            objectPos = spawn

            self.PlacingData = {
                kind = 'new',
                model = model,
                label = data.label or (catalog and catalog.label),
                price = data.price or (catalog and catalog.price),
                category = data.category or catalogCategory,
                fromPaste = data.fromPaste,
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
                local sleep = self.IsFreecamMode and 150 or 60
                Wait(sleep)
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

        local data = self.PlacingData or {}
        local ent = self.CurrentObject

        if options.save then
            if data.kind == 'owned' then
                self:UpdateFurniture(data.id, GetEntityCoords(ent), GetEntityRotation(ent, 2))
            elseif data.kind == 'cart' then
                local cartItem = self.Cart[data.cartId]
                if cartItem then
                    cartItem.position = GetEntityCoords(ent)
                    cartItem.rotation = GetEntityRotation(ent, 2)
                end
            end
        else
            if data.kind == 'new' then
                DeleteEntity(ent)
            elseif data.originalPos then
                SetEntityCoords(ent, data.originalPos.x, data.originalPos.y, data.originalPos.z)
                SetEntityRotation(ent, data.originalRot.x, data.originalRot.y, data.originalRot.z, 2, true)
            end
        end

        if DoesEntityExist(ent) then
            FreezeEntityPosition(ent, true)
            SetEntityCollision(ent, true, true)
            SetEntityAlpha(ent, 255, false)
            SetEntityDrawOutline(ent, false)
        end

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

    SpawnCartProps = function(self)
        for cartId, item in pairs(self.Cart) do
            if not item.entity or not DoesEntityExist(item.entity) then
                local hash = tonumber(item.model) or GetHashKey(item.model)
                lib.requestModel(hash)
                local obj = CreateObjectNoOffset(hash, item.position.x, item.position.y, item.position.z, false, false, false)
                SetEntityRotation(obj, item.rotation.x, item.rotation.y, item.rotation.z, 2, true)
                FreezeEntityPosition(obj, true)
                SetEntityCollision(obj, true, true)
                SetEntityAlpha(obj, 255, false)
                SetEntityDrawOutline(obj, false)
                item.entity = obj
            end
        end
    end,

    DespawnCartProps = function(self)
        for cartId, item in pairs(self.Cart) do
            if item.entity and DoesEntityExist(item.entity) then
                DeleteEntity(item.entity)
                item.entity = nil
            end
        end
    end,

        AddToCart = function(self, data)
        if not self.CurrentObject then return end

        local cartId = tostring(math.random(100000, 999999)) .. '_' .. tostring(GetGameTimer())
        local item = {
            cartId = cartId,
            label = data.label,
            model = data.model,
            price = data.price or 0,
            entity = self.CurrentObject,
            position = GetEntityCoords(self.CurrentObject),
            rotation = GetEntityRotation(self.CurrentObject, 2),
            category = data.category,
        }

        if DoesEntityExist(self.CurrentObject) then
            FreezeEntityPosition(self.CurrentObject, true)
            SetEntityCollision(self.CurrentObject, true, true)
            SetEntityAlpha(self.CurrentObject, 255, false)
            SetEntityDrawOutline(self.CurrentObject, false)
        end

        self.Cart[cartId] = item

        SendNUIMessage({
            action = "addToCart",
            data = item
        })

        self.CurrentObject = nil
        self.PlacingData = nil
    end,

    RemoveCartItem = function(self, data)
        local targetCartId = data.cartId
        local entity = tonumber(data.entity)

        local foundKey = nil
        for k, v in pairs(self.Cart) do
            if (targetCartId and v.cartId == targetCartId) or (entity and v.entity == entity) or (data.model and v.model == data.model and v.position and data.position and #(vector3(v.position.x, v.position.y, v.position.z) - vector3(data.position.x, data.position.y, data.position.z)) < 0.05) then
                foundKey = k
                if v.entity and DoesEntityExist(v.entity) then
                    DeleteEntity(v.entity)
                end
                break
            end
        end

        if foundKey then
            self.Cart[foundKey] = nil
        end
    end,

    ClearCart = function(self)
        self:DespawnCartProps()
        self.Cart = {}
        SendNUIMessage({ action = "clearCart" })
    end,

    BuyCart = function(self, paymentMethod)
        local items = {}
        local totalPrice = 0

        for _, v in pairs(self.Cart) do
            totalPrice = totalPrice + (v.price or 0)
            items[#items + 1] = {
                id = math.random(100000, 999999),
                model = v.model,
                label = v.label,
                position = v.position,
                rotation = v.rotation,
                category = v.category
            }
        end

        if #items == 0 then
            return false, "Basket is empty"
        end

        local property = Properties[self.property_id]
        local success = false
        local reason = nil

        if property and property.isApartment then
            success, reason = lib.callback.await("LNS_Housing:server:buyApartmentFurniture", false, self.property_id, items, totalPrice, paymentMethod)
        else
            success, reason = lib.callback.await("LNS_Housing:server:buyFurniture", false, self.property_id, items, totalPrice, paymentMethod)
        end

        if success then
            self:ClearCart()
            return true
        else
            return false, reason or "Payment failed"
        end
    end,

    HoverIn = function(self, data)
        self:HoverOut()
        self.HoverSession = self.HoverSession + 1
        self.PendingHoverItem = data
        self.PendingHoverTime = GetGameTimer() + 150
    end,

    HoverOut = function(self)
        self.HoverSession = self.HoverSession + 1
        self.PendingHoverItem = nil
        if self.HoverObject then
            DeleteEntity(self.HoverObject)
            self.HoverObject = nil
        end
        self.IsHovering = false
    end,

    SpawnHoverObject = function(self, data)
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
    Modeler:SelectAtCursor(data and data.x, data and data.y)
    cb("ok")
end)

RegisterNUICallback("copyFurniture", function(data, cb)
    Modeler:CopyCurrent()
    cb("ok")
end)

RegisterNUICallback("pasteFurniture", function(data, cb)
    Modeler:PasteClipboard()
    cb("ok")
end)

RegisterNUICallback("deleteFurniture", function(data, cb)
    Modeler:DeleteCurrent()
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
    debugPrint('info', 'Furniture NUI: freecamMode', data)
    SetFreecamModeState(data)
    cb("ok")
end)

RegisterNUICallback("addToCart", function(data, cb)
    debugPrint('info', 'Furniture NUI: addToCart', data)
    Modeler:AddToCart(data)
    cb("ok")
end)

RegisterNUICallback("removeCartItem", function(data, cb)
    debugPrint('info', 'Furniture NUI: removeCartItem', data)
    Modeler:RemoveCartItem(data)
    cb("ok")
end)

RegisterNUICallback("getCart", function(data, cb)
    local cartList = {}
    for _, item in pairs(Modeler.Cart) do
        if item and item.entity and DoesEntityExist(item.entity) then
            table.insert(cartList, item)
        end
    end
    cb(cartList)
end)

RegisterNUICallback("clearCart", function(data, cb)
    debugPrint('info', 'Furniture NUI: clearCart')
    Modeler:ClearCart()
    cb("ok")
end)

RegisterNUICallback("buyCartItems", function(data, cb)
    debugPrint('info', 'Furniture NUI: buyCartItems', data)
    local paymentMethod = data and data.paymentMethod or "bank"
    local success, reason = Modeler:BuyCart(paymentMethod)
    cb({ success = success, reason = reason })
end)

RegisterNUICallback("hoverIn", function(data, cb)
    debugPrint('verbose', 'Furniture NUI: hoverIn', data)
    Modeler:HoverIn(data)
    cb("ok")
end)

RegisterNUICallback("hoverOut", function(data, cb)
    debugPrint('verbose', 'Furniture NUI: hoverOut')
    Modeler:HoverOut()
    cb("ok")
end)

RegisterNUICallback("hoverOwnedItem", function(data, cb)
    debugPrint('verbose', 'Furniture NUI: hoverOwnedItem', data)
    Modeler:HoverOwnedItem(data)
    cb("ok")
end)

RegisterNUICallback("unhoverOwnedItem", function(data, cb)
    debugPrint('verbose', 'Furniture NUI: unhoverOwnedItem')
    Modeler:UnhoverOwnedItem()
    cb("ok")
end)

RegisterNUICallback("removeOwnedItem", function(data, cb)
    debugPrint('info', 'Furniture NUI: removeOwnedItem', data)
    Modeler:RemoveOwnedItem(data)
    cb("ok")
end)

RegisterNUICallback("toggleCursor", function(data, cb)
    debugPrint('info', 'Furniture NUI: toggleCursor')
    local isFocused = IsNuiFocused()
    SetNuiFocus(not isFocused, not isFocused)
    cb("ok")
end)

RegisterNetEvent('LNS_Housing:client:openFurnitureMenu', function(propertyId)
    debugPrint('info', 'LNS_Housing:client:openFurnitureMenu received', {propertyId = propertyId})
    Modeler:OpenMenu(propertyId)
end)

CreateThread(function()
    while true do
        local sleep = 500
        local isTabletActive = TabletPlacement and TabletPlacement.Active
        if Modeler.IsMenuActive or isTabletActive then
            sleep = 0
            
            if Modeler.PendingHoverItem and GetGameTimer() >= Modeler.PendingHoverTime then
                local data = Modeler.PendingHoverItem
                Modeler.PendingHoverItem = nil
                CreateThread(function()
                    Modeler:SpawnHoverObject(data)
                end)
            end
            
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

                if Modeler.IsMenuActive and Modeler.CurrentObject then
                    DisableControlAction(0, 178, true)
                    if IsDisabledControlJustPressed(0, 178) then
                        Modeler:DeleteCurrent()
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

RegisterCommand('checkfurniture', function()
    lib.print.info('Starting furniture check...')
    local invalidCount = 0
    local validCount = 0

    for _, category in ipairs(Furniture) do
        for _, item in ipairs(category.items) do
            local hash = tonumber(item.model) or GetHashKey(item.model)
            if IsModelInCdimage(hash) then
                validCount = validCount + 1
            else
                lib.print.error(string.format('Model NOT in game: %s (%s) under category: %s', item.model, item.label, category.label))
                invalidCount = invalidCount + 1
            end
        end
    end

    lib.print.info(string.format('Check finished. Valid models: %d, Non-existent models: %d', validCount, invalidCount))
end, false)

local function TryOpenFurnitureMenu()
    if not HasFurnitureManagePermission then return end

    local propertyId = InsidePropertyId or CurrentApartmentId
    if propertyId then
        TriggerEvent('LNS_Housing:client:openFurnitureMenu', propertyId)
    end
end

CreateThread(function()
    if Settings.FurnitureMenu then
        if Settings.FurnitureMenu.Command and Settings.FurnitureMenu.Command.Enabled then
            RegisterCommand(Settings.FurnitureMenu.Command.Name, function()
                TryOpenFurnitureMenu()
            end, false)
        end

        if Settings.FurnitureMenu.Keybind and Settings.FurnitureMenu.Keybind.Enabled then
            lib.addKeybind({
                name = 'open_furniture_menu',
                description = 'Open Furniture Menu',
                defaultKey = Settings.FurnitureMenu.Keybind.DefaultKey or 'F6',
                onPressed = function()
                    TryOpenFurnitureMenu()
                end
            })
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    if Modeler then
        Modeler:ClearCart()
    end
end)