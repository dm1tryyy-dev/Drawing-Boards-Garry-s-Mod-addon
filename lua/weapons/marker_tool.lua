if SERVER then
    util.AddNetworkString("MarkerDraw")
    util.AddNetworkString("MarkerErase") 
    util.AddNetworkString("MarkerColorUpdate")
    util.AddNetworkString("ChalkMarkerUI_UpdateWeapon")
end

include("config.lua")
if CLIENT then
    include("tool_ui.lua")
end

SWEP.Base = "weapon_base"
SWEP.PrintName = "Marker"
SWEP.Author = "dmitry_ostanin"
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
    
    -- Инициализация из общей конфигурации
    self.CurrentColor = self.CurrentColor or "black"
    self.CurrentSize = "medium"
    self.CurrentSizeValue = ChalkMarkerConfig.GetSizeValue("marker", "draw", "medium")
    self.CurrentEraseSize = "medium"
    self.CurrentEraseSizeValue = ChalkMarkerConfig.GetSizeValue("marker", "erase", "medium")
    
    self.WasAttacking = false
    self.WasAttacking2 = false

    -- Устанавливаем начальный цвет
    self:SetMarkerColor(self.CurrentColor)

    if SERVER then
        timer.Simple(0.1, function() 
            if IsValid(self) then 
                self:SyncColorToClient() 
            end 
        end)
    end
    

end

function SWEP:SetMarkerColor(colorName)
    local colorData = ChalkMarkerConfig.GetColorData("marker", colorName)
    self.CurrentColor = colorName
    
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
    self.CurrentSize = sizeName
    self.CurrentSizeValue = ChalkMarkerConfig.GetSizeValue("marker", "draw", sizeName)

end

function SWEP:SetEraseSize(sizeName)
    self.CurrentEraseSize = sizeName
    self.CurrentEraseSizeValue = ChalkMarkerConfig.GetSizeValue("marker", "erase", sizeName)
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
            net.WriteString(self.CurrentColor)
        net.Send(self:GetOwner())
    end
end

function SWEP:Reload()
    -- R - быстрая смена цвета
    local nextColor = ChalkMarkerConfig.GetNextColor("marker", self.CurrentColor)
    
    if CurTime() >= (self.LastColorSwitch or 0) then
        self:SetMarkerColor(nextColor)
        self.LastColorSwitch = CurTime() + 0.5
        return true
    end
    
    return false
end

function SWEP:GetDrawColor()
    local resultColor = ChalkMarkerConfig.GetDrawColor("marker", self.CurrentColor)
    return resultColor
end

-- Настройки для VIEW модели
SWEP.ViewModelOffset = Vector(20, 10, -3.5)
SWEP.ViewModelAngle = Angle(10, 5, 0)

-- Настройки для WORLD модели
SWEP.WorldModelOffset = Vector(7.3, 1, 0)
SWEP.WorldModelAngle = Angle(25, -5, -180)

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
end

function SWEP:PrimaryAttack()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    
    local tr = owner:GetEyeTrace()
    

    if IsValid(tr.Entity) and self:IsSupportedBoard(tr.Entity) then
        local drawColor = self:GetDrawColor()
        
        if SERVER then
            net.Start("MarkerDraw")
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
    
    -- Проверка на обе доски
    if IsValid(tr.Entity) and self:IsSupportedBoard(tr.Entity) then

        if SERVER then
            net.Start("MarkerErase")
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
    
    if SERVER then
        if isAttacking and CurTime() >= self:GetNextPrimaryFire() then
            local tr = owner:GetEyeTrace()
            
            -- Проверка на обе доски
            if IsValid(tr.Entity) and self:IsSupportedBoard(tr.Entity) then
                local isNewLine = not self.WasAttacking
                
                net.Start("MarkerDraw")
                    net.WriteEntity(tr.Entity)
                    net.WriteVector(tr.HitPos)
                    net.WriteColor(self:GetDrawColor())
                    net.WriteUInt(self.CurrentSizeValue or 7, 8)
                    net.WriteBool(isNewLine)
                net.Send(owner)
                
                self:SetNextPrimaryFire(CurTime() + 0.02)
            end
            
            self.WasAttacking = true
        end

        if isAttacking2 and CurTime() >= self:GetNextSecondaryFire() then
            local tr = owner:GetEyeTrace()
            
            -- Проверка на обе доски
            if IsValid(tr.Entity) and self:IsSupportedBoard(tr.Entity) then

                local isNewLine = not self.WasAttacking2
                
                net.Start("MarkerErase")
                    net.WriteEntity(tr.Entity)
                    net.WriteVector(tr.HitPos)
                    net.WriteUInt(self.CurrentEraseSizeValue or 12, 8)
                    net.WriteBool(isNewLine)
                net.Send(owner)
                
                self:SetNextSecondaryFire(CurTime() + 0.02)
            end
            
            self.WasAttacking2 = true
        end
    else

        if isAttacking and CurTime() >= self:GetNextPrimaryFire() then
            local tr = owner:GetEyeTrace()
            
            if IsValid(tr.Entity) and self:IsSupportedBoard(tr.Entity) then
                local drawColor = self:GetDrawColor()
                local isNewLine = not self.WasAttacking
                
                tr.Entity:DrawOnBoard(tr.HitPos, drawColor, self.CurrentSizeValue, isNewLine)
                
                self:SetNextPrimaryFire(CurTime() + 0.02)
                self.WasAttacking = true
            end
        end
        

        if isAttacking2 and CurTime() >= self:GetNextSecondaryFire() then
            local tr = owner:GetEyeTrace()
            
            if IsValid(tr.Entity) and self:IsSupportedBoard(tr.Entity) then

                local isNewLine = not self.WasAttacking2
                
                tr.Entity:EraseOnBoard(tr.HitPos, self.CurrentEraseSizeValue, isNewLine)
                
                self:SetNextSecondaryFire(CurTime() + 0.02)
                self.WasAttacking2 = true
            end
        end
    end
end

if CLIENT then
    net.Receive("MarkerColorUpdate", function()
        local weapon = net.ReadEntity()
        local colorName = net.ReadString()
        
        if IsValid(weapon) and weapon.SetMarkerColor then
            weapon:SetMarkerColor(colorName)
        end
    end)

    net.Receive("MarkerDraw", function()
        local whiteboard = net.ReadEntity()
        local hitPos = net.ReadVector()
        local color = net.ReadColor()
        local size = net.ReadUInt(8)
        local isNewLine = net.ReadBool()
        
        -- Проверяем методы у любой энтити (не только whiteboard)
        if IsValid(whiteboard) and whiteboard.DrawOnBoard then
            whiteboard:DrawOnBoard(hitPos, color, size, isNewLine)
        end
    end)
    
    net.Receive("MarkerErase", function()
        local whiteboard = net.ReadEntity()
        local hitPos = net.ReadVector()
        local size = net.ReadUInt(8)
        local isNewLine = net.ReadBool()
        
        -- Проверяем методы у любой энтити (не только whiteboard)
        if IsValid(whiteboard) and whiteboard.EraseOnBoard then
            whiteboard:EraseOnBoard(hitPos, size, isNewLine)
        end
    end)

end