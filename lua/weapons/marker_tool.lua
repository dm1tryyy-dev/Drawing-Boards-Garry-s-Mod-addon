if SERVER then
    util.AddNetworkString("MarkerDraw")
    util.AddNetworkString("MarkerErase") 
    util.AddNetworkString("MarkerColorUpdate")
    util.AddNetworkString("ChalkMarkerUI_UpdateWeapon")
    util.AddNetworkString("MarkerSyncColor")
    util.AddNetworkString("MarkerSyncColorIndex")

    -- Обработчик синхронизации цвета
    net.Receive("MarkerSyncColor", function(len, ply)
        local colorName = net.ReadString()
        local weapon = ply:GetActiveWeapon()
        
        if IsValid(weapon) and weapon:GetClass() == "marker_tool" then
            weapon:SetPlayerColor(colorName)
        end
    end)

    -- Обработчик синхронизации индекса
    net.Receive("MarkerSyncColorIndex", function()
        local weapon = net.ReadEntity()
        local colorIndex = net.ReadUInt(8)
        
        if IsValid(weapon) then
            weapon.ColorIndex = colorIndex

        end
    end)

    -- Обработчик рисования маркером
    net.Receive("MarkerDraw", function(len, ply)
        local whiteboard = net.ReadEntity()
        local hitPos = net.ReadVector()
        local color = net.ReadColor()
        local size = net.ReadUInt(8)
        local isNewLine = net.ReadBool()
        
        -- Проверяем, что игрок имеет доступ
        if not IsValid(whiteboard) or not IsValid(ply) then return end
        
        -- Проверяем, что это поддерживаемая доска
        local isSupported = whiteboard:GetClass() == "whiteboard" or 
                           whiteboard:GetClass() == "little_whiteboard"
        if not isSupported then return end
        
        -- ВАЖНО: получаем актуальный цвет из оружия игрока
        local weapon = ply:GetActiveWeapon()
        local actualColor = color
        
        if IsValid(weapon) and weapon:GetClass() == "marker_tool" then
            -- Используем цвет, сохраненный на сервере для этого игрока
            actualColor = weapon:GetDrawColor()
        end
        
        -- Вызываем локально для сервера с правильным цветом
        if whiteboard.DrawOnBoard then
            whiteboard:DrawOnBoard(hitPos, actualColor, size, isNewLine, ply)
        end
        
        -- Пересылаем всем с правильным цветом
        net.Start("MarkerDraw")
            net.WriteEntity(whiteboard)
            net.WriteVector(hitPos)
            net.WriteColor(actualColor) -- Используем актуальный цвет
            net.WriteUInt(size, 8)
            net.WriteBool(isNewLine)
            net.WriteEntity(ply)
        net.SendPVS(whiteboard:GetPos())
    end)
    
    -- Обработчик стирания маркером
    net.Receive("MarkerErase", function(len, ply)
        local whiteboard = net.ReadEntity()
        local hitPos = net.ReadVector()
        local size = net.ReadUInt(8)
        local isNewLine = net.ReadBool()
        
        if not IsValid(whiteboard) or not IsValid(ply) then return end
        
        -- Проверяем, что это поддерживаемая доска
        local isSupported = whiteboard:GetClass() == "whiteboard" or 
                           whiteboard:GetClass() == "little_whiteboard"
        if not isSupported then return end
        
        -- Также вызываем локально для сервера
        if whiteboard.EraseOnBoard then
            whiteboard:EraseOnBoard(hitPos, size, isNewLine, ply)
        end

        net.Start("MarkerErase")
            net.WriteEntity(whiteboard)
            net.WriteVector(hitPos)
            net.WriteUInt(size, 8)
            net.WriteBool(isNewLine)
            net.WriteEntity(ply)
        net.SendPVS(whiteboard:GetPos())
    end)
end

include("config.lua")
if CLIENT then
    include("tool_ui.lua")
end

SWEP.Base = "weapon_base"
SWEP.PrintName = "Marker"
SWEP.Author = "Err0X1s"
SWEP.Instructions = "LMB: Draw | RMB: Erase | R: Quick color change | T: Open menu"
SWEP.Spawnable = true
SWEP.AdminSpawnable = true
SWEP.Category = "Drawing Tools"
SWEP.IconOverride = "vgui/entities/spawnicons/marker_icon.png"
SWEP.Slot = 5
SWEP.SlotPos = 1

if CLIENT then
    SWEP.WepSelectIcon = surface.GetTextureID("vgui/entities/marker_mat")
end

SWEP.ViewModel = "models/tools/marker_tool.mdl"
SWEP.WorldModel = "models/tools/marker_tool.mdl"
SWEP.HoldType = "pistol"
SWEP.ViewModelFOV = 70
SWEP.UseHands = true

SWEP.DrawAmmo = false 
SWEP.DrawWeaponInfoBox = false 

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

-- Список поддерживаемых досок
SWEP.SupportedBoards = {
    "whiteboard",
    "little_whiteboard"
}

SWEP.CurrentColor = "black"
SWEP.MarkerMaterial = nil
SWEP.ColorMaterial = nil
SWEP.BodyMaterial = nil
SWEP.PlayerData = {}
SWEP.ColorIndex = 1

-- Функция проверки является ли энтити доской
function SWEP:IsSupportedBoard(entity)
    if not IsValid(entity) then return false end
    
    for _, boardClass in ipairs(self.SupportedBoards) do
        if entity:GetClass() == boardClass then
            return true
        end
    end
    
    return false
end

function SWEP:Initialize()
    self.MarkerMaterial = Material("models/tools_materials/marker/Marker")
    self.ColorMaterial = Material("models/tools_materials/marker/Color")
    self.BodyMaterial = Material("models/tools_materials/marker/Body")
    
    -- Инициализация таблицы данных игроков
    if SERVER then
        self.PlayerData = {}
        self.ColorIndex = 1 -- Инициализация индекса на сервере
    end

    self.WasAttacking = false
    self.WasAttacking2 = false

    if CLIENT then
        -- Инициализация из общей конфигурации
        self.CurrentColor = self.CurrentColor or "black"
        self.ColorIndex = 1 -- Инициализация индекса на клиенте
        self.CurrentSize = "medium"
        self.CurrentSizeValue = ChalkMarkerConfig.GetSizeValue("marker", "draw", "medium")
        self.CurrentEraseSize = "medium"
        self.CurrentEraseSizeValue = ChalkMarkerConfig.GetSizeValue("marker", "erase", "medium")

        -- Устанавливаем начальный цвет
        self:SetMarkerColor(self.CurrentColor)
    else
        self.CurrentColor = nil
        self.CurrentSize = nil
        self.CurrentSizeValue = nil
        self.CurrentEraseSize = nil
        self.CurrentEraseSizeValue = nil
    end

    if SERVER then
        timer.Simple(0.1, function() 
            if IsValid(self) then 
                self:SyncColorToClient() 
                self:SyncColorIndexToClient()
            end 
        end)
    end
end

function SWEP:GetPlayerColor()
    if CLIENT then
        return self.CurrentColor or "black"
    end
    
    -- SERVER
    local owner = self:GetOwner()
    if not IsValid(owner) then return "black" end
    
    -- Используем UserID для более быстрого доступа
    local userid = owner:UserID()
    local data = self.PlayerData[userid]
    if not data then
        data = {color = "black", colorIndex = 1}
        self.PlayerData[userid] = data
    end
    
    return data.color
end

function SWEP:SetPlayerColor(colorName)
    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    
    -- Находим индекс цвета (10 цветов в правильном порядке)
    local colors = ChalkMarkerConfig.ColorOrder.marker or {"black", "red", "blue", "green", "yellow", "orange", "cyan", "purple", "pink", "brown"}
    local foundIndex = 1
    for i, color in ipairs(colors) do
        if color == colorName then
            foundIndex = i
            break
        end
    end
    
    -- Обновляем индекс
    self.ColorIndex = foundIndex
    
    if SERVER then
        -- Сохраняем на сервере
        local userid = owner:UserID()
        self.PlayerData[userid] = self.PlayerData[userid] or {}
        self.PlayerData[userid].color = colorName
        self.PlayerData[userid].colorIndex = foundIndex
        
        -- Синхронизируем с клиентом
        self:SyncColorToClient()
        self:SyncColorIndexToClient()
    else
        -- Обновляем на клиенте
        self.CurrentColor = colorName
        self.ColorIndex = foundIndex
        self:SetMarkerColor(colorName)
        
        -- СИНХРОНИЗИРУЕМ С СЕРВЕРОМ
        self:SyncColorToServer(colorName)
    end
end

function SWEP:GetNextColor()
    -- 10 цветов в правильном порядке
    local colors = ChalkMarkerConfig.ColorOrder.marker or {"black", "red", "blue", "green", "yellow", "orange", "cyan", "purple", "pink", "brown"}
    
    -- Убедимся, что ColorIndex валиден
    if not self.ColorIndex or self.ColorIndex < 1 or self.ColorIndex > #colors then
        self.ColorIndex = 1
    end
    
    -- Используем сохраненный индекс
    local nextIndex = (self.ColorIndex % #colors) + 1
    
    return colors[nextIndex]
end

function SWEP:GetPlayerSize()
    if CLIENT then
        return self.CurrentSize or "medium"
    end
    
    -- SERVER
    local owner = self:GetOwner()
    if not IsValid(owner) then return "medium" end
    
    local userid = owner:UserID()
    local data = self.PlayerData[userid]
    if not data then
        data = {size = "medium"}
        self.PlayerData[userid] = data
    end
    
    return data.size or "medium"
end

function SWEP:SetPlayerSize(sizeName)
    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    
    if SERVER then
        local userid = owner:UserID()
        self.PlayerData[userid] = self.PlayerData[userid] or {}
        self.PlayerData[userid].size = sizeName
    else
        self.CurrentSize = sizeName
        self.CurrentSizeValue = ChalkMarkerConfig.GetSizeValue("marker", "draw", sizeName)
    end
end

function SWEP:GetPlayerEraseSize()
    if CLIENT then
        return self.CurrentEraseSize or "medium"
    end
    
    -- SERVER
    local owner = self:GetOwner()
    if not IsValid(owner) then return "medium" end
    
    local userid = owner:UserID()
    local data = self.PlayerData[userid]
    if not data then
        data = {eraseSize = "medium"}
        self.PlayerData[userid] = data
    end
    
    return data.eraseSize or "medium"
end

function SWEP:SetPlayerEraseSize(sizeName)
    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    
    if SERVER then
        local userid = owner:UserID()
        self.PlayerData[userid] = self.PlayerData[userid] or {}
        self.PlayerData[userid].eraseSize = sizeName
    else
        self.CurrentEraseSize = sizeName
        self.CurrentEraseSizeValue = ChalkMarkerConfig.GetSizeValue("marker", "erase", sizeName)
    end
end

function SWEP:GetDrawSizeValue()
    local sizeName = self:GetPlayerSize()
    return ChalkMarkerConfig.GetSizeValue("marker", "draw", sizeName)
end

function SWEP:GetEraseSizeValue()
    local sizeName = self:GetPlayerEraseSize()
    return ChalkMarkerConfig.GetSizeValue("marker", "erase", sizeName)
end

function SWEP:SetMarkerColor(colorName)
    local colorData = ChalkMarkerConfig.GetColorData("marker", colorName)
    
    -- Обновляем локальную переменную на клиенте
    if CLIENT then
        self.CurrentColor = colorName
    end
    
    if self.BodyMaterial then
        self:SetBodyTexture(colorData.texture)
    end
    if self.MarkerMaterial and self.ColorMaterial then
        self:SetMarkerColor2(colorData.tool_color)
    end
    
    if SERVER then
        self:SyncColorToClient()
    end
end

function SWEP:SetMarkerSize(sizeName)
    self:SetPlayerSize(sizeName)
end

function SWEP:SetEraseSize(sizeName)
    self:SetPlayerEraseSize(sizeName)
end

function SWEP:SetBodyTexture(texturePath)
    if not self.BodyMaterial then return end
    self.BodyMaterial:SetTexture("$basetexture", texturePath)
end

function SWEP:SetMarkerColor2(colorVector)
    if not self.MarkerMaterial or not self.ColorMaterial then return end
    
    self.MarkerMaterial:SetVector("$color2", colorVector)
    self.ColorMaterial:SetVector("$color2", colorVector)
end

function SWEP:SyncColorToClient()
    if SERVER and IsValid(self:GetOwner()) then
        net.Start("MarkerColorUpdate")
            net.WriteEntity(self)
            net.WriteString(self:GetPlayerColor())
        net.Send(self:GetOwner())
    end
end

function SWEP:SyncColorIndexToClient()
    if SERVER and IsValid(self:GetOwner()) then
        net.Start("MarkerSyncColorIndex")
            net.WriteEntity(self)
            net.WriteUInt(self.ColorIndex or 1, 8)
        net.Send(self:GetOwner())
    end
end

function SWEP:Deploy()
    -- Синхронизируем цвет при взятии оружия
    if CLIENT then
        timer.Simple(0.1, function()
            if IsValid(self) then
                self:SyncColorToServer(self.CurrentColor or "black")
            end
        end)
    end
    
    return true
end

function SWEP:Reload()
    local owner = self:GetOwner()
    if IsValid(owner) and owner:KeyDown(IN_SPEED) then
        return false
    end
    
    -- R - быстрая смена цвета
    if CurTime() >= (self.LastColorSwitch or 0) then
        local nextColor = self:GetNextColor()
        self:SetPlayerColor(nextColor)
        self.LastColorSwitch = CurTime() + 0.5
        
        return true
    end
    
    return false
end

function SWEP:SyncColorToServer(colorName)
    if CLIENT then
        net.Start("MarkerSyncColor")
            net.WriteString(colorName)
        net.SendToServer()
    end
end

function SWEP:GetDrawColor()
    local currentColor = self:GetPlayerColor()
    local resultColor = ChalkMarkerConfig.GetDrawColor("marker", currentColor)
    return resultColor
end

-- ==========================================

-- Настройки для VIEW модели
SWEP.ViewModelOffset = Vector(20, 10, -3.5)
SWEP.ViewModelAngle = Angle(10, 5, 0)

-- Настройки для WORLD модели
SWEP.WorldModelOffset = Vector(7.3, 1, 0)
SWEP.WorldModelAngle = Angle(25, -5, 0)

function SWEP:GetViewModelPosition(pos, ang)
    pos = pos + self.ViewModelOffset.x * ang:Forward()
    pos = pos + self.ViewModelOffset.y * ang:Right()
    pos = pos + self.ViewModelOffset.z * ang:Up()
    
    ang:RotateAroundAxis(ang:Right(), self.ViewModelAngle.p)
    ang:RotateAroundAxis(ang:Up(), self.ViewModelAngle.y)
    ang:RotateAroundAxis(ang:Forward(), self.ViewModelAngle.r)
    
    return pos, ang
end

function SWEP:DrawWorldModel()
    local owner = self:GetOwner()
    
    -- Если оружие в руках игрока
    if IsValid(owner) then
        -- ДЛЯ ВСЕХ ИГРОКОВ (и для себя через камеру, и для других) используем кастомную отрисовку
        local bone = owner:LookupBone("ValveBiped.Bip01_R_Hand")
        
        if bone then
            local matrix = owner:GetBoneMatrix(bone)
            if matrix then
                local pos, ang = matrix:GetTranslation(), matrix:GetAngles()
                
                -- Применяем смещения
                pos = pos + ang:Forward() * self.WorldModelOffset.x
                pos = pos + ang:Right() * self.WorldModelOffset.y
                pos = pos + ang:Up() * self.WorldModelOffset.z
                
                ang:RotateAroundAxis(ang:Right(), self.WorldModelAngle.p)
                ang:RotateAroundAxis(ang:Up(), self.WorldModelAngle.y)
                ang:RotateAroundAxis(ang:Forward(), self.WorldModelAngle.r)
                
                -- Рисуем модель
                self:SetRenderOrigin(pos)
                self:SetRenderAngles(ang)
                self:DrawModel()
                self:SetRenderOrigin()
                self:SetRenderAngles()
                
                -- Выходим, т.к. уже отрисовали
                return
            end
        end
    end
    
    -- Fallback: если что-то пошло не так - стандартная отрисовка
    self:DrawModel()
end

function SWEP:DrawWorldModelTranslucent()
    self:DrawWorldModel()
end

--[[
-- Закомментированная функция кастомной отрисовки
function SWEP:DrawWorldModelCustom()
    local owner = self:GetOwner()
    if not IsValid(owner) then
        self:DrawModel()
        return
    end
    
    -- Проверяем кости в порядке: кисть -> предплечье -> плечо
    local boneNames = {
        "ValveBiped.Bip01_R_Hand",      -- Кисть
        "ValveBiped.Bip01_R_Forearm",   -- Предплечье
        "ValveBiped.Bip01_R_Upperarm",  -- Плечо
    }
    
    local boneIndex
    for _, boneName in ipairs(boneNames) do
        boneIndex = owner:LookupBone(boneName)
        if boneIndex then break end
    end
    
    if not boneIndex then 
        self:DrawModel()
        return
    end
    
    -- Получаем позицию и угол кости в мировых координатах
    local bonePos, boneAng = owner:GetBonePosition(boneIndex)
    if not bonePos then 
        self:DrawModel()
        return
    end
    
    -- Применяем смещения
    local pos = bonePos + boneAng:Forward() * self.WorldModelOffset.x
    pos = pos + boneAng:Right() * self.WorldModelOffset.y
    pos = pos + boneAng:Up() * self.WorldModelOffset.z
    
    local ang = Angle(boneAng.p, boneAng.y, boneAng.r)
    ang:RotateAroundAxis(ang:Right(), self.WorldModelAngle.p)
    ang:RotateAroundAxis(ang:Up(), self.WorldModelAngle.y)
    ang:RotateAroundAxis(ang:Forward(), self.WorldModelAngle.r)
    
    self:SetRenderOrigin(pos)
    self:SetRenderAngles(ang)
    self:DrawModel()

    self:SetRenderOrigin()
    self:SetRenderAngles()
end
--]]

function SWEP:PrimaryAttack()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    
    local tr = owner:GetEyeTrace()
    
    -- Проверка на обе доски
    if IsValid(tr.Entity) and self:IsSupportedBoard(tr.Entity) then
        local sizeValue = self:GetDrawSizeValue()
        
        net.Start("MarkerDraw")
            net.WriteEntity(tr.Entity)
            net.WriteVector(tr.HitPos)
            net.WriteColor(self:GetDrawColor())
            net.WriteUInt(sizeValue or 7, 8)
            net.WriteBool(true)
        net.SendToServer()
    end
    
    self:SetNextPrimaryFire(CurTime() + 0.05)
    self.WasAttacking = true
end

function SWEP:SecondaryAttack()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    
    local tr = owner:GetEyeTrace()
    
    -- Проверка на обе доски
    if IsValid(tr.Entity) and self:IsSupportedBoard(tr.Entity) then
        local eraseSizeValue = self:GetEraseSizeValue()
        
        net.Start("MarkerErase")
            net.WriteEntity(tr.Entity)
            net.WriteVector(tr.HitPos)
            net.WriteUInt(eraseSizeValue or 12, 8)
            net.WriteBool(true)
        net.SendToServer()
    end
    
    self:SetNextSecondaryFire(CurTime() + 0.05)
    self.WasAttacking2 = true
end

function SWEP:Think()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    
    local isAttacking = owner:KeyDown(IN_ATTACK)
    local isAttacking2 = owner:KeyDown(IN_ATTACK2)
    
    -- Сброс флагов при отпускании кнопок
    if not isAttacking then
        self.WasAttacking = false
    end
    
    if not isAttacking2 then
        self.WasAttacking2 = false
    end
    
    if owner:KeyDown(IN_SPEED) and owner:KeyPressed(IN_RELOAD) then
        local tr = owner:GetEyeTrace()
        local ent = tr.Entity  
        if self:GetClass() == "marker_tool" and IsValid(ent) and self:IsSupportedBoard(ent) then
            if SERVER then
                RunConsoleCommand("marker_clear")
            end
            return
        end
    end

    -- КЛИЕНТСКАЯ ЧАСТЬ: отправка сетевых сообщений при удержании
    if CLIENT then
        -- Рисование
        if isAttacking and CurTime() >= self:GetNextPrimaryFire() then
            local tr = owner:GetEyeTrace()
            
            if IsValid(tr.Entity) and self:IsSupportedBoard(tr.Entity) then
                local isNewLine = not self.WasAttacking
                local sizeValue = self:GetDrawSizeValue()
                
                net.Start("MarkerDraw")
                    net.WriteEntity(tr.Entity)
                    net.WriteVector(tr.HitPos)
                    net.WriteColor(self:GetDrawColor())
                    net.WriteUInt(sizeValue or 7, 8)
                    net.WriteBool(isNewLine)
                net.SendToServer()
                
                self:SetNextPrimaryFire(CurTime() + 0.02)
                self.WasAttacking = true
            end
        end
        
        -- Стирание
        if isAttacking2 and CurTime() >= self:GetNextSecondaryFire() then
            local tr = owner:GetEyeTrace()
            
            if IsValid(tr.Entity) and self:IsSupportedBoard(tr.Entity) then
                local isNewLine = not self.WasAttacking2
                local eraseSizeValue = self:GetEraseSizeValue()
                
                net.Start("MarkerErase")
                    net.WriteEntity(tr.Entity)
                    net.WriteVector(tr.HitPos)
                    net.WriteUInt(eraseSizeValue or 12, 8)
                    net.WriteBool(isNewLine)
                net.SendToServer()
                
                self:SetNextSecondaryFire(CurTime() + 0.02)
                self.WasAttacking2 = true
            end
        end
    else
        -- СЕРВЕРНАЯ ЧАСТЬ
        if isAttacking and CurTime() >= self:GetNextPrimaryFire() then
            self:SetNextPrimaryFire(CurTime() + 0.02)
            self.WasAttacking = true
        end

        if isAttacking2 and CurTime() >= self:GetNextSecondaryFire() then
            self:SetNextSecondaryFire(CurTime() + 0.02)
            self.WasAttacking2 = true
        end
    end
end

function SWEP:OnRemove()
    if SERVER then
        -- Очищаем данные игроков при удалении оружия
        self.PlayerData = {}
    end
end

function SWEP:OwnerChanged()
    -- При смене владельца можно очистить старые данные
    if SERVER then
        -- Оставляем только данные текущего владельца
        local owner = self:GetOwner()
        if IsValid(owner) then
            local userid = owner:UserID()
            local currentData = self.PlayerData[userid]
            self.PlayerData = {}
            self.PlayerData[userid] = currentData or {color = "black", colorIndex = 1, size = "medium", eraseSize = "medium"}
        else
            self.PlayerData = {}
        end
    end
end

if CLIENT then
    net.Receive("MarkerSyncColorIndex", function()
        local weapon = net.ReadEntity()
        local colorIndex = net.ReadUInt(8)
        
        if IsValid(weapon) then
            weapon.ColorIndex = colorIndex
        end
    end)
    
    net.Receive("MarkerColorUpdate", function()
        local weapon = net.ReadEntity()
        local colorName = net.ReadString()
        
        if IsValid(weapon) then
            -- Обновляем локальную переменную на клиенте
            weapon.CurrentColor = colorName
            if weapon.SetMarkerColor then
                weapon:SetMarkerColor(colorName)
            end
            
            -- Также обновляем индекс на клиенте
            local colors = ChalkMarkerConfig.ColorOrder.marker or {"black", "red", "blue", "green", "yellow", "orange", "cyan", "purple", "pink", "brown"}
            for i, color in ipairs(colors) do
                if color == colorName then
                    weapon.ColorIndex = i
                    break
                end
            end
        end
    end)

    net.Receive("MarkerDraw", function()
        local whiteboard = net.ReadEntity()
        local hitPos = net.ReadVector()
        local color = net.ReadColor()
        local size = net.ReadUInt(8)
        local isNewLine = net.ReadBool()
        local player = net.ReadEntity()
        
        if IsValid(whiteboard) and whiteboard.DrawOnBoard then
            whiteboard:DrawOnBoard(hitPos, color, size, isNewLine)
        end
    end)
    
    net.Receive("MarkerErase", function()
        local whiteboard = net.ReadEntity()
        local hitPos = net.ReadVector()
        local size = net.ReadUInt(8)
        local isNewLine = net.ReadBool()
        local player = net.ReadEntity()
        
        if IsValid(whiteboard) and whiteboard.EraseOnBoard then
            whiteboard:EraseOnBoard(hitPos, size, isNewLine)
        end
    end)
end

-- Сообщение с подсказками управления (HUD)
if CLIENT then
    local hintState = {
        alpha = 0,
        offset = -300,
        showTime = 0,
        fadingOut = false,
        fadeStartTime = 0
    }

    function SWEP:DrawHUD()
        local owner = self:GetOwner()
        if not IsValid(owner) or owner ~= LocalPlayer() then return end
        if owner:GetActiveWeapon() ~= self then return end
        
        local hints = {
            "LMB: Draw",
            "RMB: Erase", 
            "SHIFT+R: Full Clear (only whiteboard and little whiteboard)",
            "R: Quick Change Color",
            "T: Tool Menu (you can assign another key)"
        }
        
        local currentTime = CurTime()
        
        -- Инициализация при первом показе
        if hintState.showTime == 0 then
            hintState.showTime = currentTime
            hintState.fadingOut = false
            hintState.alpha = 0
            hintState.offset = -300
        end
        
        local timeSinceShow = currentTime - hintState.showTime
        
        -- Логика показа/скрытия
        local targetAlpha, targetOffset
        
        if not hintState.fadingOut then
            -- Показываем первые 10 секунд
            if timeSinceShow < 10 then
                targetAlpha = 1
                targetOffset = 20
            else
                -- Начинаем скрывать
                hintState.fadingOut = true
                hintState.fadeStartTime = currentTime
            end
        end
        
        if hintState.fadingOut then
            -- Скрываем в течение 1 секунды
            local fadeDuration = 1.0
            local fadeProgress = math.Clamp((currentTime - hintState.fadeStartTime) / fadeDuration, 0, 1)
            
            if fadeProgress < 1 then
                -- Плавно двигаем влево и уменьшаем прозрачность
                targetOffset = Lerp(fadeProgress, 20, -300)
                targetAlpha = Lerp(fadeProgress, 1, 0)
            else
                -- Скрытие завершено, сбрасываем состояние
                hintState.showTime = 0
                return
            end
        end
        
        -- Плавная анимация
        if targetAlpha and targetOffset then
            hintState.alpha = Lerp(FrameTime() * 6, hintState.alpha, targetAlpha)
            hintState.offset = Lerp(FrameTime() * 8, hintState.offset, targetOffset)
        end
        
        if hintState.alpha <= 0.01 then return end
        
        surface.SetFont("HudSelectionText")
        local maxWidth = 0
        local maxHeight = 0
        local padding = 20

        local title = "CONTROLS"
        local titleWidth = surface.GetTextSize(title)
        
        for i, hint in ipairs(hints) do
            local w, h = surface.GetTextSize(hint)
            maxWidth = math.max(maxWidth, w)
            maxHeight = math.max(maxHeight, h)
        end
        
        maxWidth = math.max(maxWidth, titleWidth)
        local lineHeight = maxHeight + 8
        local totalWidth = maxWidth + padding * 2
        local totalHeight = (#hints + 1) * lineHeight + padding * 2
        
        local x = hintState.offset
        local y = ScrH() / 2 - totalHeight / 2
        
        -- Фон
        surface.SetDrawColor(0, 0, 0, 200 * hintState.alpha)
        surface.DrawRect(x, y, totalWidth, totalHeight)
        
        -- Толстая рамка
        local border = 3
        surface.SetDrawColor(255, 212, 0, 255 * hintState.alpha)
        surface.DrawRect(x, y, totalWidth, border)
        surface.DrawRect(x, y + totalHeight - border, totalWidth, border)
        surface.DrawRect(x, y, border, totalHeight)
        surface.DrawRect(x + totalWidth - border, y, border, totalHeight)
        
        -- Заголовок
        local titleY = y + padding
        draw.SimpleText(title, "DermaDefaultBold", x + totalWidth / 2, titleY, 
                       Color(255, 255, 255, 255 * hintState.alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        
        -- Разделительная линия под заголовком
        local lineY = titleY + lineHeight - 5
        surface.SetDrawColor(255, 212, 0, 150 * hintState.alpha)
        surface.DrawRect(x + padding, lineY, totalWidth - padding * 2, 1)
        
        -- Подсказки с шрифтом HudSelectionText
        for i, hint in ipairs(hints) do
            local textY = y + padding + i * lineHeight
            draw.SimpleText(hint, "HudSelectionText", x + padding, textY, 
                           Color(255, 212, 0, 255 * hintState.alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
    end
    
    function SWEP:Holster()
        hintState.showTime = 0
        hintState.fadingOut = false
        hintState.alpha = 0
        hintState.offset = -300
        return true
    end
    
    function SWEP:OnRemove()
        hintState.showTime = 0
        hintState.fadingOut = false
        hintState.alpha = 0
        hintState.offset = -300
    end
    
    function SWEP:OwnerChanged()
        hintState.showTime = 0
        hintState.fadingOut = false
        hintState.alpha = 0
        hintState.offset = -300
    end
end