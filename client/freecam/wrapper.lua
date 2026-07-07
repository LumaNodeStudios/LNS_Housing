Freecam = {}

function Freecam:IsActive()
    return IsFreecamActive()
end

function Freecam:SetActive(active)
    return SetFreecamActive(active)
end

function Freecam:IsFrozen()
    return IsFreecamFrozen()
end

function Freecam:SetFrozen(frozen)
    return SetFreecamFrozen(frozen)
end

function Freecam:GetFov()
    return GetFreecamFov()
end

function Freecam:SetFov(fov)
    return SetFreecamFov(fov)
end

function Freecam:GetPosition()
    return GetFreecamPosition()
end

function Freecam:SetPosition(x, y, z)
    return SetFreecamPosition(x, y, z)
end

function Freecam:GetRotation()
    return GetFreecamRotation()
end

function Freecam:SetRotation(x, y, z)
    return SetFreecamRotation(x, y, z)
end

function Freecam:GetMatrix()
    return GetFreecamMatrix()
end

function Freecam:GetTarget(distance)
    return GetFreecamTarget(distance)
end

function Freecam:GetKeyboardControl(key)
    return _G.KEYBOARD_CONTROL_MAPPING[key]
end

function Freecam:GetGamepadControl(key)
    return _G.GAMEPAD_CONTROL_MAPPING[key]
end

function Freecam:GetKeyboardSetting(key)
    return _G.KEYBOARD_CONTROL_SETTINGS[key]
end

function Freecam:GetGamepadSetting(key)
    return _G.GAMEPAD_CONTROL_SETTINGS[key]
end

function Freecam:GetCameraSetting(key)
    return _G.CAMERA_SETTINGS[key]
end

function Freecam:SetKeyboardControl(key, value)
    _G.KEYBOARD_CONTROL_MAPPING[key] = value
end

function Freecam:SetGamepadControl(key, value)
    _G.GAMEPAD_CONTROL_MAPPING[key] = value
end

function Freecam:SetKeyboardSetting(key, value)
    _G.KEYBOARD_CONTROL_SETTINGS[key] = value
end

function Freecam:SetGamepadSetting(key, value)
    _G.GAMEPAD_CONTROL_SETTINGS[key] = value
end

function Freecam:SetCameraSetting(key, value)
    _G.CAMERA_SETTINGS[key] = value
end
