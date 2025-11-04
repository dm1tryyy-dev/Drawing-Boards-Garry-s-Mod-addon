if SERVER then
    util.AddNetworkString("ChalkDraw")
    util.AddNetworkString("ChalkErase")
    util.AddNetworkString("ChalkColorUpdate")
    util.AddNetworkString("ChalkMarkerUI_UpdateWeapon")
end

include("config.lua")
if CLIENT then
    include("tool_ui.lua")
end

SWEP.Base = "weapon_base"
SWEP.PrintName = "Chalk"
SWEP.Author = "dmitry_ostanin"
SWEP.Instructions = "LMB: Draw | RMB: Erase | R: Quick color change | T: Open menu"
SWEP.Spawnable = true
SWEP.AdminSpawnable = true
SWEP.Category = "Drawing Tools"
SWEP.IconOverride = "vgui/entities/spawnicons/chalk_icon.png"
SWEP.Slot = 5
SWEP.SlotPos = 1

if CLIENT then
    SWEP.WepSelectIcon = surface.GetTextureID("vgui/entities/chalk_mat")
end

SWEP.ViewModel = "models/tools/chalk_tool.mdl"
SWEP.WorldModel = "models/tools/chalk_tool.mdl"
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

function SWEP:Initialize()
    self.ChalkMaterial = Material("models/tools_materials/chalk/Main")
    
    -- Инициализация из общей конфигурации
    self.CurrentColor = self.CurrentColor or "white"
    self.CurrentSize = "medium"
    self.CurrentSizeValue = ChalkMarkerConfig.GetSizeValue("chalk", "draw", "medium") or 7
    self.CurrentEraseSize = "medium"
    self.CurrentEraseSizeValue = ChalkMarkerConfig.GetSizeValue("chalk", "erase", "medium") or 12
    
    self.WasAttacking = false
    self.WasAttacking2 = false


    -- Установка начального цвета
    self:SetChalkColor(self.CurrentColor)

    if SERVER then
        timer.Simple(0.1, function() 
            if IsValid(self) then 
                self:SyncColorToClient() 
            end 
        end)
    end
end

function SWEP:SetChalkColor(colorName)
    local colorData = ChalkMarkerConfig.GetColorData("chalk", colorName)
    self.CurrentColor = colorName
    
    if self.ChalkMaterial then
        self:SetChalkColor2(colorData.tool_color)
    end
    
    if SERVER then
        self:SyncColorToClient()
    end
end

function SWEP:SetChalkSize(sizeName)
    self.CurrentSize = sizeName
    self.CurrentSizeValue = ChalkMarkerConfig.GetSizeValue("chalk", "draw", sizeName)
end

function SWEP:SetEraseSize(sizeName)
    self.CurrentEraseSize = sizeName
    self.CurrentEraseSizeValue = ChalkMarkerConfig.GetSizeValue("chalk", "erase", sizeName)
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
            net.WriteString(self.CurrentColor)
        net.Send(self:GetOwner())
    end
end

function SWEP:Reload()

    local owner = self:GetOwner()
    if IsValid(owner) and owner:KeyDown(IN_SPEED) then
        return false
    end
    
    -- R - быстрая смена цвета
    local nextColor = ChalkMarkerConfig.GetNextColor("chalk", self.CurrentColor)
    
    if CurTime() >= (self.LastColorSwitch or 0) then
        self:SetChalkColor(nextColor)
        self.LastColorSwitch = CurTime() + 0.5
        return true
    end
    
    return false
end

function SWEP:GetDrawColor()
    local resultColor = ChalkMarkerConfig.GetDrawColor("chalk", self.CurrentColor)
    return resultColor
end

-- Настройки для VIEW модели
SWEP.ViewModelOffset = Vector(22, 12, -2.5)
SWEP.ViewModelAngle = Angle(45, 0, 0)

-- Настройки для WORLD модели
SWEP.WorldModelOffset = Vector(7, 1, 0)
SWEP.WorldModelAngle = Angle(25, -10, -5)

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
    self:DrawWorldModelCustom()
end

function SWEP:DrawWorldModelTranslucent()
    self:DrawWorldModelCustom()
end

function SWEP:DrawWorldModelCustom()
    if not IsValid(self:GetOwner()) then
        self:DrawModel()
        return
    end
    
    local bone = self:GetOwner():LookupBone("ValveBiped.Bip01_R_Hand")
    if not bone then 
        self:DrawModel()
        return
    end
    
    local matrix = self:GetOwner():GetBoneMatrix(bone)
    if not matrix then 
        self:DrawModel()
        return
    end
    
    local pos, ang = matrix:GetTranslation(), matrix:GetAngles()
    
    pos = pos + self.WorldModelOffset.x * ang:Forward()
    pos = pos + self.WorldModelOffset.y * ang:Right()
    pos = pos + self.WorldModelOffset.z * ang:Up()
    
    ang:RotateAroundAxis(ang:Right(), self.WorldModelAngle.p)
    ang:RotateAroundAxis(ang:Up(), self.WorldModelAngle.y)
    ang:RotateAroundAxis(ang:Forward(), self.WorldModelAngle.r)
    
    self:SetRenderOrigin(pos)
    self:SetRenderAngles(ang)
    self:DrawModel()
    self:SetRenderOrigin()
    self:SetRenderAngles()
end

function SWEP:PrimaryAttack()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    
    local tr = owner:GetEyeTrace()
    
    if IsValid(tr.Entity) and tr.Entity:GetClass() == "chalkboard" then
        local drawColor = self:GetDrawColor()

        if SERVER then
            net.Start("ChalkDraw")
                net.WriteEntity(tr.Entity)
                net.WriteVector(tr.HitPos)
                net.WriteColor(drawColor)
                net.WriteUInt(self.CurrentSizeValue or 7, 8)
                net.WriteBool(true) 
            net.Send(owner)
        else
            tr.Entity:DrawOnBoard(tr.HitPos, drawColor, self.CurrentSizeValue, true)
        end
    end
    
    self:SetNextPrimaryFire(CurTime() + 0.05)
    self.WasAttacking = true
end

function SWEP:SecondaryAttack()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    
    local tr = owner:GetEyeTrace()
    
    if IsValid(tr.Entity) and tr.Entity:GetClass() == "chalkboard" then

        if SERVER then
            net.Start("ChalkErase")
                net.WriteEntity(tr.Entity)
                net.WriteVector(tr.HitPos)
                net.WriteUInt(self.CurrentEraseSizeValue or 12, 8)
                net.WriteBool(true)
            net.Send(owner)
        else
            tr.Entity:EraseOnBoard(tr.HitPos, self.CurrentEraseSizeValue, true)
        end
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
        

        if self:GetClass() == "chalk_tool" and IsValid(ent) and ent:GetClass() == "chalkboard" then
            if SERVER then
                RunConsoleCommand("chalk_clear")
            end
            return
        end
    end

    if SERVER then
        -- ЛКМ - рисование
        if isAttacking and CurTime() >= self:GetNextPrimaryFire() then
            local tr = owner:GetEyeTrace()
            
            if IsValid(tr.Entity) and tr.Entity:GetClass() == "chalkboard" then
                local drawColor = self:GetDrawColor()
                local isNewLine = not self.WasAttacking

                if not net.Started then  
                    net.Start("ChalkDraw")
                        net.WriteEntity(tr.Entity)
                        net.WriteVector(tr.HitPos)
                        net.WriteColor(drawColor)
                        net.WriteUInt(self.CurrentSizeValue or 7, 8)
                        net.WriteBool(isNewLine)
                    net.Send(owner)
                end
                self:SetNextPrimaryFire(CurTime() + 0.02)
                self.WasAttacking = true
            end
        end

        -- ПКМ - стирание
        if isAttacking2 and CurTime() >= self:GetNextSecondaryFire() then
            local tr = owner:GetEyeTrace()
            
            if IsValid(tr.Entity) and tr.Entity:GetClass() == "chalkboard" then

                local isNewLine = not self.WasAttacking2
                
                if not net.Started then
                    net.Start("ChalkErase")
                        net.WriteEntity(tr.Entity)
                        net.WriteVector(tr.HitPos)
                        net.WriteUInt(self.CurrentEraseSizeValue or 12, 8)
                        net.WriteBool(isNewLine)
                    net.Send(owner)
                end
                self:SetNextSecondaryFire(CurTime() + 0.02)
                self.WasAttacking2 = true
            end
        end
    else

        if isAttacking and CurTime() >= self:GetNextPrimaryFire() then
            local tr = owner:GetEyeTrace()
            
            if IsValid(tr.Entity) and tr.Entity:GetClass() == "chalkboard" then
                local drawColor = self:GetDrawColor()
                local isNewLine = not self.WasAttacking
                
                tr.Entity:DrawOnBoard(tr.HitPos, drawColor, self.CurrentSizeValue, isNewLine)
                
                self:SetNextPrimaryFire(CurTime() + 0.02)
                self.WasAttacking = true
            end
        end
        

        if isAttacking2 and CurTime() >= self:GetNextSecondaryFire() then
            local tr = owner:GetEyeTrace()
            
            if IsValid(tr.Entity) and tr.Entity:GetClass() == "chalkboard" then

                local isNewLine = not self.WasAttacking2
                
                tr.Entity:EraseOnBoard(tr.HitPos, self.CurrentEraseSizeValue, isNewLine)
                
                self:SetNextSecondaryFire(CurTime() + 0.02)
                self.WasAttacking2 = true
            end
        end
    end
end

if CLIENT then
    net.Receive("ChalkColorUpdate", function()
        local weapon = net.ReadEntity()
        local colorName = net.ReadString()
        
        if IsValid(weapon) and weapon.SetChalkColor then
            weapon:SetChalkColor(colorName)
        end
    end)

    net.Receive("ChalkDraw", function()
        local chalkboard = net.ReadEntity()
        local hitPos = net.ReadVector()
        local color = net.ReadColor()
        local size = net.ReadUInt(8)
        local isNewLine = net.ReadBool()
        
        if IsValid(chalkboard) and chalkboard.DrawOnBoard then
            chalkboard:DrawOnBoard(hitPos, color, size, isNewLine)
        end
    end)
    
    net.Receive("ChalkErase", function()
        local chalkboard = net.ReadEntity()
        local hitPos = net.ReadVector()
        local size = net.ReadUInt(8)
        local isNewLine = net.ReadBool()
        
        if IsValid(chalkboard) and chalkboard.EraseOnBoard then
            chalkboard:EraseOnBoard(hitPos, size, isNewLine)
        end
    end)
end

-- Сообщение с подсказками управления
if CLIENT then
    local hintState = {
        alpha = 0,
        offset = -300,
        showTime = 0,
        hasShown = false
    }

    function SWEP:DrawHUD()
        local hints = {
            "LMB: Draw",
            "RMB: Erase", 
            "SHIFT+R: Full Clear (only chalkboard)",
            "R: Quick Change Color",
            "T: Tool Menu (you can assign another key)"
        }
        

        local isActive = self:GetOwner() == LocalPlayer() and self:GetOwner():GetActiveWeapon() == self
        
        if isActive and not hintState.hasShown then

            hintState.showTime = CurTime()
            hintState.hasShown = true
            hintState.alpha = 0
            hintState.offset = -300
        end
        
        local timeSinceShow = CurTime() - hintState.showTime
        local shouldShow = isActive and timeSinceShow < 10
        
        local targetAlpha = shouldShow and 1 or 0
        local targetOffset = shouldShow and 20 or -300
        

        hintState.alpha = Lerp(FrameTime() * 4, hintState.alpha, targetAlpha)
        hintState.offset = Lerp(FrameTime() * 6, hintState.offset, targetOffset)
        
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
        hintState.hasShown = false
        hintState.alpha = 0
        hintState.offset = -300
        return true
    end
    

    function SWEP:OnRemove()
        hintState.hasShown = false
        hintState.alpha = 0
        hintState.offset = -300
    end
end