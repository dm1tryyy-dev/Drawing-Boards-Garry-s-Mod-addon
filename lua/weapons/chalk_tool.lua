include("config.lua")

if CLIENT then
    include("tool_ui.lua")
end

if SERVER then
    util.AddNetworkString("ChalkDraw")
    util.AddNetworkString("ChalkErase")
    util.AddNetworkString("ChalkColorUpdate")
    util.AddNetworkString("ChalkMarkerUI_UpdateWeapon")
    util.AddNetworkString("ChalkSyncColor")
    util.AddNetworkString("ChalkSyncColorIndex")
    util.AddNetworkString("ChalkboardClear")
    util.AddNetworkString("ChalkboardClearPlayer")
    util.AddNetworkString("ChalkMarkerUI_UpdateWeapon")
    util.AddNetworkString("ChalkMarkerUI_UpdateEraseSize")
    util.AddNetworkString("ChalkMarkerUI_SyncSize")
    util.AddNetworkString("ChalkMarkerUI_SyncEraseSize")

    -- Обработчик синхронизации цвета
    net.Receive("ChalkSyncColor", function(len, ply)
        local colorName = net.ReadString()
        local weapon = ply:GetActiveWeapon()
        
        if IsValid(weapon) and weapon:GetClass() == "chalk_tool" then
            weapon:SetPlayerColor(colorName)
        end
    end)

    -- Обработчик синхронизации индекса
    net.Receive("ChalkSyncColorIndex", function()
        local weapon = net.ReadEntity()
        local colorIndex = net.ReadUInt(8)
        
        if IsValid(weapon) then
            weapon.ColorIndex = colorIndex

        end
    end)

    -- Обработчик рисования мелом
    net.Receive("ChalkDraw", function(len, ply)
        local chalkboard = net.ReadEntity()
        local hitPos = net.ReadVector()
        local color = net.ReadColor()
        local size = net.ReadUInt(8)
        local isNewLine = net.ReadBool()
        
        -- Проверяем, что игрок имеет доступ
        if not IsValid(chalkboard) or not IsValid(ply) then return end
        
        local class = chalkboard:GetClass()
        if class ~= "chalkboard" and class ~= "chalkboard_oversized" then return end
        
        -- ВАЖНО: получаем актуальный цвет из оружия игрока
        local weapon = ply:GetActiveWeapon()
        local actualColor = color
        
        if IsValid(weapon) and weapon:GetClass() == "chalk_tool" then
            -- Используем цвет, сохраненный на сервере для этого игрока
            actualColor = weapon:GetDrawColor()
        end
        
        -- Вызываем локально для сервера с правильным цветом
        if chalkboard.DrawOnBoard then
            chalkboard:DrawOnBoard(hitPos, actualColor, size, isNewLine, ply)
        end
        
        -- Пересылаем всем с правильным цветом
        net.Start("ChalkDraw")
            net.WriteEntity(chalkboard)
            net.WriteVector(hitPos)
            net.WriteColor(actualColor) -- Используем актуальный цвет
            net.WriteUInt(size,8)
            net.WriteBool(isNewLine)
            net.WriteEntity(ply)
        net.SendPVS(chalkboard:GetPos())
    end)
    
    -- Обработчик стирания мелом
    net.Receive("ChalkErase", function(len, ply)
        local chalkboard = net.ReadEntity()
        local hitPos = net.ReadVector()
        local size = net.ReadUInt(8)
        local isNewLine = net.ReadBool()
        
        if not IsValid(chalkboard) or not IsValid(ply) then return end
        
        local class = chalkboard:GetClass()
        if class ~= "chalkboard" and class ~= "chalkboard_oversized" then return end
        
        -- Также вызываем локально для сервера
        if chalkboard.EraseOnBoard then
            chalkboard:EraseOnBoard(hitPos, size, isNewLine, ply)
        end

        net.Start("ChalkErase")
            net.WriteEntity(chalkboard)
            net.WriteVector(hitPos)
            net.WriteUInt(size,8)
            net.WriteBool(isNewLine)
            net.WriteEntity(ply)
        net.SendPVS(chalkboard:GetPos())
    end)
    
    -- Обработчик очистки всей доски
    concommand.Add("chalk_clear", function(ply)
        local tr = ply:GetEyeTrace()
        local ent = tr.Entity
        local class = ent:GetClass()
        if IsValid(ent) and (class == "chalkboard" or  class == "chalkboard_oversized") then
            -- Очищаем локально на сервере
            if ent.ClearChalkboard then
                ent:ClearChalkboard()
            end
            
            -- Отправляем всем клиентам
            net.Start("ChalkboardClear")
                net.WriteEntity(ent)
            net.SendPVS(ent:GetPos())
            
            ply:ChatPrint("Chalkboard cleared!")
        else
            ply:ChatPrint("Look at a chalkboard to clear it!")
        end
    end)
    
    -- Обработчик очистки только своих рисунков
    concommand.Add("chalk_clear_my", function(ply)
        local tr = ply:GetEyeTrace()
        local ent = tr.Entity
        local class = ent:GetClass()
        if IsValid(ent) and (class == "chalkboard" or  class == "chalkboard_oversized") then
            if ent.ClearPlayerDrawings then
                -- Очищаем локально на сервере
                ent:ClearPlayerDrawings(ply)
                
                -- Отправляем всем клиентам
                net.Start("ChalkboardClearPlayer")
                    net.WriteEntity(ent)
                    net.WriteEntity(ply)
                net.SendPVS(ent:GetPos())
                
                ply:ChatPrint("Your drawings cleared!")
            else
                ply:ChatPrint("This chalkboard doesn't support player-specific clearing")
            end
        else
            ply:ChatPrint("Look at a chalkboard to clear your drawings!")
        end
    end)
end


SWEP.Base = "weapon_base"
SWEP.PrintName = "Chalk"
SWEP.Author = "Err0X1s"
SWEP.Instructions = "LMB: Draw | RMB: Erase | R: Quick color change | T: Open menu"
SWEP.Spawnable = true
SWEP.AdminSpawnable = true
--SWEP.NoAnimations = true
SWEP.Category = "Drawing Tools"
SWEP.IconOverride = "vgui/entities/spawnicons/chalk_icon.png"
SWEP.Slot = 5
SWEP.SlotPos = 1

if CLIENT then
    SWEP.WepSelectIcon = surface.GetTextureID("vgui/entities/chalk_mat")
end

SWEP.ViewModel = "models/tools/chalk_tool.mdl"
SWEP.WorldModel = "models/tools/chalk_tool.mdl"
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

SWEP.CurrentColor = "white"
SWEP.ChalkMaterial = nil
SWEP.PlayerData = {}
SWEP.ColorIndex = 1

-- Функция проверки является ли энтити chalkboard
function SWEP:IsChalkboard(entity)
    if not IsValid(entity) then return false end
    local class = entity:GetClass()
    return class == "chalkboard" or class == "chalkboard_oversized"
end

function SWEP:Initialize()
    self.ChalkMaterial = Material("models/tools_materials/chalk/Main")
    
    -- Инициализация таблицы данных игроков
    if SERVER then
        self.PlayerData = {}
        self.ColorIndex = 1 -- Инициализация индекса на сервере
    end

    self.WasAttacking = false
    self.WasAttacking2 = false
    self.ReloadPressed = false

    if CLIENT then
        -- Инициализация из общей конфигурации
        self.CurrentColor = self.CurrentColor or "white"
        self.ColorIndex = 1 -- Инициализация индекса на клиенте
        self.CurrentSizeValue = 7.0  -- Значение по умолчанию
        self.CurrentEraseSizeValue = 15  -- Значение по умолчанию

        -- Устанавливаем начальный цвет
        self:SetChalkColor(self.CurrentColor)
    else
        self.CurrentColor = nil
        self.CurrentSizeValue = nil
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
        return self.CurrentColor or "white"
    end
    
    -- SERVER
    local owner = self:GetOwner()
    if not IsValid(owner) then return "white" end
    
    local userid = owner:UserID()
    local data = self.PlayerData[userid]
    if not data then
        data = {color = "white", colorIndex = 1}
        self.PlayerData[userid] = data
    end
    
    return data.color or "white"
end

function SWEP:SetPlayerColor(colorName)
    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    
    -- Находим индекс цвета
    local colors = ChalkMarkerConfig.ColorOrder.chalk or {"white", "yellow", "orange", "pink", "blue", "green"}
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
        self:SetChalkColor(colorName)
        
        -- СИНХРОНИЗИРУЕМ С СЕРВЕРОМ
        self:SyncColorToServer(colorName)
    end
end

function SWEP:GetNextColor()
    local colors = ChalkMarkerConfig.ColorOrder.chalk or {
        "white",
        "yellow",
        "orange",
        "pink",
        "blue",
        "green"
    }

    local currentColor = self:GetPlayerColor()
    local currentIndex = 1

    for i, color in ipairs(colors) do
        if color == currentColor then
            currentIndex = i
            break
        end
    end

    local nextIndex = (currentIndex % #colors) + 1

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
        self.CurrentSizeValue = ChalkMarkerConfig.GetSizeValue("chalk", "draw", sizeName)
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
        self.CurrentEraseSizeValue = ChalkMarkerConfig.GetSizeValue("chalk", "erase", sizeName)
    end
end

function SWEP:GetDrawSizeValue()
    if CLIENT then
        
        return self.CurrentSizeValue or 7.0
    else
        -- SERVER
        local owner = self:GetOwner()
        if IsValid(owner) then
            local userid = owner:UserID()
            if self.PlayerData and self.PlayerData[userid] and self.PlayerData[userid].sizeValue then
                return self.PlayerData[userid].sizeValue
            end
        end
        return 7.0
    end
end

function SWEP:GetEraseSizeValue()
    if CLIENT then
        return self.CurrentEraseSizeValue or 15.0
    else
        local owner = self:GetOwner()
        if IsValid(owner) then
            local userid = owner:UserID()
            if self.PlayerData and self.PlayerData[userid] and self.PlayerData[userid].eraseSizeValue then
                return self.PlayerData[userid].eraseSizeValue
            end
        end
        return 15.0
    end
end

function SWEP:SetChalkColor(colorName)
    local colorData = ChalkMarkerConfig.GetColorData("chalk", colorName)
    
    -- Обновляем локальную переменную на клиенте
    if CLIENT then
        self.CurrentColor = colorName
    end
    
    if self.ChalkMaterial then
        self:SetChalkColor2(colorData.tool_color)
    end
    
    if SERVER then
        self:SyncColorToClient()
    end
end

function SWEP:SetChalkColor2(colorVector)
    if not self.ChalkMaterial then return end
    
    self.ChalkMaterial:SetVector("$color2", colorVector)
    self.ChalkMaterial:Recompute()
end

function SWEP:SyncColorToClient()
    if SERVER and IsValid(self:GetOwner()) then
        net.Start("ChalkColorUpdate")
            net.WriteEntity(self)
            net.WriteString(self:GetPlayerColor())
        net.Send(self:GetOwner())
    end
end

function SWEP:SyncColorIndexToClient()
    if SERVER and IsValid(self:GetOwner()) then
        net.Start("ChalkSyncColorIndex")
            net.WriteEntity(self)
            net.WriteUInt(self.ColorIndex or 1, 8)
        net.Send(self:GetOwner())
    end
end

function SWEP:Deploy()
    if CLIENT then
        timer.Simple(0.1, function()
            if IsValid(self) then
                self:SyncColorToServer(self.CurrentColor or "white")
                
                if not self.CurrentSizeValue or self.CurrentSizeValue == 0 then
                    self.CurrentSizeValue = 7.0
                end
                
                if not self.CurrentEraseSizeValue or self.CurrentEraseSizeValue == 0 then
                    self.CurrentEraseSizeValue = 15.0
                end
                
                local colorName = self.CurrentColor or "white"
                net.Start("ChalkMarkerUI_UpdateWeapon")
                    net.WriteString(colorName)
                    net.WriteFloat(self.CurrentSizeValue)
                    if colorName == "__custom__" and self.CustomColor then
                        net.WriteColor(self.CustomColor)
                    end
                net.SendToServer()
                
                net.Start("ChalkMarkerUI_UpdateEraseSize")
                    net.WriteFloat(self.CurrentEraseSizeValue)
                net.SendToServer()
            end
        end)
    end
    return true
end

function SWEP:UpdateSizeFromServer(sizeName, sizeValue)
    self.CurrentSize = sizeName
    self.CurrentSizeValue = sizeValue
end

function SWEP:UpdateEraseSizeFromServer(sizeName, sizeValue)
    self.CurrentEraseSize = sizeName
    self.CurrentEraseSizeValue = sizeValue
end

function SWEP:Reload()
    return false
end

function SWEP:SyncColorToServer(colorName)
    if CLIENT then
        net.Start("ChalkSyncColor")
            net.WriteString(colorName)
        net.SendToServer()
    end
end

function SWEP:GetDrawColor()
    if CLIENT then
        local currentColor = self:GetPlayerColor()
        if currentColor == "__custom__" and self.CustomColor then
            return self.CustomColor
        end
        return ChalkMarkerConfig.GetDrawColor("chalk", currentColor)
    else
        -- SERVER
        local owner = self:GetOwner()
        if not IsValid(owner) then return Color(240, 240, 230) end
        
        local userid = owner:UserID()
        local data = self.PlayerData[userid]
        if data then
            if data.color == "__custom__" and data.customColor then
                return data.customColor
            end
            return ChalkMarkerConfig.GetDrawColor("chalk", data.color or "white")
        end
        return Color(240, 240, 230)
    end
end

-- ========================================

-- Настройки для VIEW модели
SWEP.ViewModelOffset = Vector(22, 12, -2.5)
SWEP.ViewModelAngle = Angle(45, 0, 0)

-- Настройки для WORLD модели
SWEP.WorldModelOffset = Vector(8, -2, 0)
SWEP.WorldModelAngle = Angle(-25, -10, -5)

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
        -- КРИТИЧНО: обновляем кости перед получением матрицы
        owner:SetupBones()
        
        local bone = owner:LookupBone("ValveBiped.Bip01_R_Hand")
        
        if bone then
            local matrix = owner:GetBoneMatrix(bone)
            if matrix then
                -- Получаем позицию и угол из матрицы кости
                local pos = matrix:GetTranslation()
                local ang = matrix:GetAngles()
                
                -- Применяем смещения с использованием локальных координат
                local offsetPos = self.WorldModelOffset or Vector(7, 1, 0)
                local offsetAng = self.WorldModelAngle or Angle(25, -10, -5)
                
                -- Конвертируем локальные смещения в мировые координаты
                local newPos, newAng = LocalToWorld(
                    offsetPos, 
                    offsetAng, 
                    pos, 
                    ang
                )
                
                -- Устанавливаем позицию для отрисовки
                self:SetRenderOrigin(newPos)
                self:SetRenderAngles(newAng)
                
                -- КРИТИЧНО: принудительно обновляем кости модели оружия
                self:SetupBones()
                
                -- Рисуем модель
                self:DrawModel()
                
                -- Сбрасываем рендер позицию (важно для последующих кадров)
                self:SetRenderOrigin()
                self:SetRenderAngles()
                
                return
            end
        end
        
        -- Fallback если не нашли кость - используем стандартную отрисовку
        self:DrawModel()
    else
        -- Если оружие на земле - стандартная отрисовка
        self:SetRenderOrigin(nil)
        self:SetRenderAngles(nil)
        self:DrawModel()
    end
end

function SWEP:DrawWorldModelTranslucent()
    self:DrawWorldModel()
end

function SWEP:PrimaryAttack()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    
    local tr = owner:GetEyeTrace()
    
    -- Проверка на chalkboard
    if IsValid(tr.Entity) and self:IsChalkboard(tr.Entity) then
        local sizeValue = self:GetDrawSizeValue()
        
        net.Start("ChalkDraw")
            net.WriteEntity(tr.Entity)
            net.WriteVector(tr.HitPos)
            net.WriteColor(self:GetDrawColor())
            net.WriteUInt(sizeValue or 7,8)
            net.WriteBool(true)
        net.SendToServer()
    end
    
    self:SetNextPrimaryFire(CurTime() + 0.02)
    self.WasAttacking = true
end

function SWEP:SecondaryAttack()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    
    local tr = owner:GetEyeTrace()
    
    -- Проверка на chalkboard
    if IsValid(tr.Entity) and self:IsChalkboard(tr.Entity) then
        local eraseSizeValue = self:GetEraseSizeValue()
        
        net.Start("ChalkErase")
            net.WriteEntity(tr.Entity)
            net.WriteVector(tr.HitPos)
            net.WriteUInt(eraseSizeValue or 12,8)
            net.WriteBool(true)
        net.SendToServer()
    end
    
    self:SetNextSecondaryFire(CurTime() + 0.02)
    self.WasAttacking2 = true
end

function SWEP:Think()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    
    local isAttacking = owner:KeyDown(IN_ATTACK)
    local isAttacking2 = owner:KeyDown(IN_ATTACK2)

    local reloadDown = owner:KeyDown(IN_RELOAD)

    if reloadDown and not self.ReloadPressed then

        self.ReloadPressed = true

        if SERVER and not owner:KeyDown(IN_SPEED) then
            local nextColor = self:GetNextColor()
            self:SetPlayerColor(nextColor)
        end

    elseif not reloadDown then

        self.ReloadPressed = false

    end
    
    -- Сброс флагов при отпускании кнопок
    if not isAttacking then
        self.WasAttacking = false
    end
    
    if not isAttacking2 then
        self.WasAttacking2 = false
    end
    
    if owner:KeyDown(IN_SPEED) and owner:KeyPressed(IN_RELOAD) then
        if CLIENT then
            local tr = owner:GetEyeTrace()
            local ent = tr.Entity  
            if self:GetClass() == "chalk_tool" and IsValid(ent) and self:IsChalkboard(ent) then
                RunConsoleCommand("chalk_clear")
            end
        end
        return
    end

    if CLIENT then
        -- КЛИЕНТ отправляет сообщения на сервер
        if isAttacking and CurTime() >= self:GetNextPrimaryFire() then
            local tr = owner:GetEyeTrace()
            
            if IsValid(tr.Entity) and self:IsChalkboard(tr.Entity) then
                local isNewLine = not self.WasAttacking
                local sizeValue = self:GetDrawSizeValue()
                
                net.Start("ChalkDraw")
                    net.WriteEntity(tr.Entity)
                    net.WriteVector(tr.HitPos)
                    net.WriteColor(self:GetDrawColor())
                    net.WriteUInt(sizeValue or 7,8)
                    net.WriteBool(isNewLine)
                net.SendToServer()
                
                self:SetNextPrimaryFire(CurTime() + 0.01)
                self.WasAttacking = true
            end
        end
        
        if isAttacking2 and CurTime() >= self:GetNextSecondaryFire() then
            local tr = owner:GetEyeTrace()
            
            if IsValid(tr.Entity) and self:IsChalkboard(tr.Entity) then
                local isNewLine = not self.WasAttacking2
                local eraseSizeValue = self:GetEraseSizeValue()
                
                net.Start("ChalkErase")
                    net.WriteEntity(tr.Entity)
                    net.WriteVector(tr.HitPos)
                    net.WriteUInt(eraseSizeValue or 12,8)
                    net.WriteBool(isNewLine)
                net.SendToServer()
                
                self:SetNextSecondaryFire(CurTime() + 0.01)
                self.WasAttacking2 = true
            end
        end
    else
        -- СЕРВЕРНАЯ ЧАСТЬ
        if isAttacking then
            if CurTime() >= self:GetNextPrimaryFire() then
                self:SetNextPrimaryFire(CurTime() + 0.01)
                self.WasAttacking = true
            end
        end

        if isAttacking2 then
            if CurTime() >= self:GetNextSecondaryFire() then
                self:SetNextSecondaryFire(CurTime() + 0.01)
                self.WasAttacking2 = true
            end
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
            self.PlayerData[userid] = currentData or {color = "white", colorIndex = 1, size = "medium", eraseSize = "medium"}
        else
            self.PlayerData = {}
        end
    end
end

if CLIENT then
    net.Receive("ChalkSyncColorIndex", function()
        local weapon = net.ReadEntity()
        local colorIndex = net.ReadUInt(8)
        
        if IsValid(weapon) then
            weapon.ColorIndex = colorIndex
        end
    end)
    
    net.Receive("ChalkColorUpdate", function()
        local weapon = net.ReadEntity()
        local colorName = net.ReadString()
        
        if IsValid(weapon) then
            -- Обновляем локальную переменную на клиенте
            weapon.CurrentColor = colorName
            if weapon.SetChalkColor then
                weapon:SetChalkColor(colorName)
            end
            
            -- Также обновляем индекс на клиенте
            local colors = ChalkMarkerConfig.ColorOrder.chalk or {"white", "yellow", "orange", "pink", "blue", "green"}
            for i, color in ipairs(colors) do
                if color == colorName then
                    weapon.ColorIndex = i
                    break
                end
            end
        end
    end)
end


-- Сообщение с подсказками управления (HUD)
if CLIENT then
    local hintAlpha = 0
    local hintOffset = -300
    local hintStartTime = 0
    local isShowingHint = false

    function SWEP:DrawHUD()
        local owner = self:GetOwner()
        if not IsValid(owner) or owner ~= LocalPlayer() then return end
        if owner:GetActiveWeapon() ~= self then return end
        
        local currentTime = CurTime()
        
        if not isShowingHint then
            isShowingHint = true
            hintStartTime = currentTime
            hintAlpha = 0
            hintOffset = -300
        end
        
        local timeSinceShow = currentTime - hintStartTime
        
        if timeSinceShow < 10 then
            hintAlpha = math.min(hintAlpha + FrameTime() * 6, 1)
            hintOffset = math.min(hintOffset + FrameTime() * 600, 20)
        elseif timeSinceShow < 10.5 then
            local fadeProgress = (timeSinceShow - 10) / 0.5
            hintOffset = Lerp(fadeProgress, 20, -300)
            hintAlpha = Lerp(fadeProgress, 1, 0)
        else
            hintAlpha = 0
        end
        
        local hints = {
            "LMB: Draw",
            "RMB: Erase", 
            "SHIFT+R: Full Clear (only chalkboard)",
            "R: Quick Change Color",
            "T: Tool Menu (you can assign another key)"
        }
        
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
        
        local x = hintOffset
        local y = ScrH() / 2 - totalHeight / 2
        
        if hintAlpha > 0.01 then
            surface.SetDrawColor(0, 0, 0, 200 * hintAlpha)
            surface.DrawRect(x, y, totalWidth, totalHeight)
            
            local border = 3
            surface.SetDrawColor(255, 212, 0, 255 * hintAlpha)
            surface.DrawRect(x, y, totalWidth, border)
            surface.DrawRect(x, y + totalHeight - border, totalWidth, border)
            surface.DrawRect(x, y, border, totalHeight)
            surface.DrawRect(x + totalWidth - border, y, border, totalHeight)
            
            local titleY = y + padding
            draw.SimpleText(title, "DermaDefaultBold", x + totalWidth / 2, titleY, 
                        Color(255, 255, 255, 255 * hintAlpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            
            local lineY = titleY + lineHeight - 5
            surface.SetDrawColor(255, 212, 0, 150 * hintAlpha)
            surface.DrawRect(x + padding, lineY, totalWidth - padding * 2, 1)
            
            for i, hint in ipairs(hints) do
                local textY = y + padding + i * lineHeight
                draw.SimpleText(hint, "HudSelectionText", x + padding, textY, 
                            Color(255, 212, 0, 255 * hintAlpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end
        end
        
        -- НЕГАТИВНЫЙ ПРИЦЕЛ ЧЕРЕЗ OVERRIDEBLEND (ВСЕГДА ПОКАЗЫВАЕТСЯ)
        local isErasing = owner:KeyDown(IN_ATTACK2)
        local isDrawing = owner:KeyDown(IN_ATTACK)
        
        local centerX = ScrW() / 2
        local centerY = ScrH() / 2
        
        -- Определяем радиус в зависимости от режима
        local radius
        if isErasing then
            radius = self:GetEraseSizeValue() or 15
            -- radius = radius * 1.5 -- Увеличиваем для лучшей видимости
        elseif isDrawing then
            radius = self:GetDrawSizeValue() or 7
            radius = radius * 1.5 -- Увеличиваем для лучшей видимости
        else
            radius = 20 -- Радиус по умолчанию когда ничего не нажато
        end
        
        local dotRadius = 5 -- Статический радиус центрального круга
        local thickness = 3 -- Толщина кольца
        
        -- Кэшируем геометрию прицела
        local cacheKey = radius .. "_" .. ScrW() .. "_" .. ScrH()
        if not self.ReticleCacheKey or self.ReticleCacheKey ~= cacheKey then
            self.ReticleCacheKey = cacheKey
            self.RingPolyCache = {}
            self.DotPolyCache = {}
            
            local segments = 48
            local angleStep = (2 * math.pi) / segments
            local innerRadius = radius - thickness
            
            -- Кэшируем кольцо
            local outerPoints = {}
            local innerPoints = {}
            
            for i = 0, segments do
                local angle = i * angleStep
                local cosA = math.cos(angle)
                local sinA = math.sin(angle)
                
                outerPoints[i+1] = {
                    x = centerX + cosA * radius,
                    y = centerY + sinA * radius
                }
                innerPoints[i+1] = {
                    x = centerX + cosA * innerRadius,
                    y = centerY + sinA * innerRadius
                }
            end
            
            for i = 1, segments do
                table.insert(self.RingPolyCache, {
                    outerPoints[i],
                    outerPoints[i+1],
                    innerPoints[i+1],
                    innerPoints[i]
                })
            end
            
            -- Кэшируем центральный круг
            for i = 0, segments do
                local angle = i * angleStep
                table.insert(self.DotPolyCache, {
                    x = centerX + math.cos(angle) * dotRadius,
                    y = centerY + math.sin(angle) * dotRadius
                })
            end
        end
        
        draw.NoTexture()
        
        -- Включаем режим инверсии
        render.OverrideBlend(true, BLEND_ONE_MINUS_DST_COLOR, BLEND_ZERO, BLENDFUNC_ADD)
        
        surface.SetDrawColor(255, 255, 255, 255)
        
        -- Рисуем кольцо
        if self.RingPolyCache then
            for _, poly in ipairs(self.RingPolyCache) do
                surface.DrawPoly(poly)
            end
        end
        
        -- Рисуем центральный круг
        if self.DotPolyCache then
            surface.DrawPoly(self.DotPolyCache)
        end
        
        -- Выключаем инверсию
        render.OverrideBlend(false)
    end
    
    -- Сбрасываем флаг при убирании оружия
    function SWEP:Holster()
        isShowingHint = false
        return true
    end
    
    -- Также сбрасываем при смерти
    hook.Add("PlayerDeath", "ResetChalkHint", function(ply)
        if ply == LocalPlayer() then
            isShowingHint = false
        end
    end)
    
    -- И при спавне
    hook.Add("PlayerSpawn", "ResetChalkHintSpawn", function(ply)
        if ply == LocalPlayer() then
            isShowingHint = false
        end
    end)
end

-- Отключаем стандартный прицел когда оружие активно
hook.Add("HUDShouldDraw", "ChalkTool_HideDefaultCrosshair", function(name)
    if name == "CHudCrosshair" then
        local ply = LocalPlayer()
        if IsValid(ply) then
            local wep = ply:GetActiveWeapon()
            if IsValid(wep) and wep:GetClass() == "chalk_tool" then
                return false
            end
        end
    end
end)