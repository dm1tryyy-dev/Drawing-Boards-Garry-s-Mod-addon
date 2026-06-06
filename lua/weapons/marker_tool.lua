include("config.lua")

local DEBUG_COLORS = false

local function ColorDebug(...)
    if not DEBUG_COLORS then return end

    local msg = ""

    for k, v in ipairs({...}) do
        msg = msg .. tostring(v) .. " "
    end

    print("[MARKER COLOR]", msg)
end

if CLIENT then
    include("tool_ui.lua")
end

if SERVER then
    util.AddNetworkString("MarkerDraw")
    util.AddNetworkString("MarkerErase")
    util.AddNetworkString("MarkerColorUpdate")
    util.AddNetworkString("ChalkMarkerUI_UpdateWeapon")
    util.AddNetworkString("MarkerSyncColor")
    util.AddNetworkString("MarkerSyncColorIndex")
    util.AddNetworkString("WhiteboardClear")
    util.AddNetworkString("WhiteboardClearPlayer")
    util.AddNetworkString("ChalkMarkerUI_UpdateEraseSize")
    util.AddNetworkString("ChalkMarkerUI_SyncSize")
    util.AddNetworkString("ChalkMarkerUI_SyncEraseSize")

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
        
        if not IsValid(whiteboard) or not IsValid(ply) then return end
        
        local isSupported = whiteboard:GetClass() == "whiteboard" or 
                           whiteboard:GetClass() == "little_whiteboard" or
                           whiteboard:GetClass() == "whiteboard_oversized"
        if not isSupported then return end
        
        local weapon = ply:GetActiveWeapon()
        local actualColor = color
        
        if IsValid(weapon) and weapon:GetClass() == "marker_tool" then
            actualColor = weapon:GetDrawColor()
        end
        
        if whiteboard.DrawOnBoard then
            whiteboard:DrawOnBoard(hitPos, actualColor, size, isNewLine, ply)
        end
        
        net.Start("MarkerDraw")
            net.WriteEntity(whiteboard)
            net.WriteVector(hitPos)
            net.WriteColor(actualColor)
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
        
        local isSupported = whiteboard:GetClass() == "whiteboard" or 
                           whiteboard:GetClass() == "little_whiteboard" or
                           whiteboard:GetClass() == "whiteboard_oversized"
        if not isSupported then return end
        
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

    -- Обработчик очистки всей доски
    concommand.Add("marker_clear", function(ply)
        local tr = ply:GetEyeTrace()
        local ent = tr.Entity
        local class = ent:GetClass()
        if IsValid(ent) and (class == "whiteboard" or class == "little_whiteboard" or class == "whiteboard_oversized") then
            if ent.ClearWhiteboard then
                ent:ClearWhiteboard()
            end
            
            net.Start("WhiteboardClear")
                net.WriteEntity(ent)
            net.SendPVS(ent:GetPos())
            
            ply:ChatPrint("Whiteboard cleared!")
        else
            ply:ChatPrint("Look at a whiteboard to clear it!")
        end
    end)

    -- Обработчик очистки только своих рисунков
    -- concommand.Add("marker_clear_self", function(ply)
    --     local tr = ply:GetEyeTrace()
    --     local ent = tr.Entity
    --     local class = ent:GetClass()
    --     if IsValid(ent) and (class == "whiteboard" or class == "little_whiteboard" or class == "whiteboard_oversized") then
    --         if ent.ClearPlayerDrawings then
    --             ent:ClearPlayerDrawings(ply)
                
    --             net.Start("WhiteboardClearPlayer")
    --                 net.WriteEntity(ent)
    --                 net.WriteEntity(ply)
    --             net.SendPVS(ent:GetPos())
                
    --             ply:ChatPrint("Your drawings cleared!")
    --         else
    --             ply:ChatPrint("This whiteboard doesn't support player-specific clearing")
    --         end
    --     else
    --         ply:ChatPrint("Look at a whiteboard to clear your drawings!")
    --     end
    -- end)
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

SWEP.SupportedBoards = {
    "whiteboard",
    "little_whiteboard",
    "whiteboard_oversized"
}

SWEP.CurrentColor = "black"
SWEP.MarkerMaterial = nil
SWEP.ColorMaterial = nil
SWEP.BodyMaterial = nil
SWEP.PlayerData = {}
SWEP.ColorIndex = 1

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
    
    if SERVER then
        self.PlayerData = {}
        self.ColorIndex = 1
    end

    self.WasAttacking = false
    self.WasAttacking2 = false
    self.ReloadPressed = false
    self.NextDrawSend = 0

    if CLIENT then
        self.CurrentColor = self.CurrentColor or "black"
        self.ColorIndex = 1
        self.CurrentSizeValue = 7.0
        self.CurrentEraseSizeValue = 15.0
        self:SetMarkerColor(self.CurrentColor)
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
        return self.CurrentColor or "black"
    end
    
    local owner = self:GetOwner()
    if not IsValid(owner) then return "black" end
    
    local userid = owner:UserID()
    local data = self.PlayerData[userid]
    if not data then
        data = {color = "black", colorIndex = 1}
        self.PlayerData[userid] = data
    end
    
    return data.color or "black"
end

function SWEP:SetPlayerColor(colorName)
    local owner = self:GetOwner()

    ColorDebug(
        SERVER and "SERVER" or "CLIENT",
        "SetPlayerColor",
        IsValid(owner) and owner:Nick() or "NULL",
        colorName,
        math.floor(SysTime() * 1000)
    )
    
    if not IsValid(owner) then return end
    
    local colors = ChalkMarkerConfig.ColorOrder.marker or {"black", "red", "blue", "green", "yellow", "orange", "cyan", "purple", "pink", "brown"}
    local foundIndex = 1
    for i, color in ipairs(colors) do
        if color == colorName then
            foundIndex = i
            break
        end
    end
    
    self.ColorIndex = foundIndex
    
    if SERVER then
        local userid = owner:UserID()
        self.PlayerData[userid] = self.PlayerData[userid] or {}
        self.PlayerData[userid].color = colorName
        self.PlayerData[userid].colorIndex = foundIndex
        self:SyncColorToClient()
        self:SyncColorIndexToClient()
    else
        self.CurrentColor = colorName
        self.ColorIndex = foundIndex
        self:SetMarkerColor(colorName)
        self:SyncColorToServer(colorName)
    end
end

function SWEP:GetNextColor()
    local colors = ChalkMarkerConfig.ColorOrder.marker or {"black", "red", "blue", "green", "yellow", "orange", "cyan", "purple", "pink", "brown"}
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

function SWEP:GetDrawSizeValue()
    if CLIENT then
        return self.CurrentSizeValue or 7.0
    else
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

function SWEP:SetMarkerColor(colorName)
    local colorData = ChalkMarkerConfig.GetColorData("marker", colorName)
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
    if CLIENT then
        timer.Simple(0.1, function()
            if IsValid(self) then
                self:SyncColorToServer(self.CurrentColor or "black")
                
                if not self.CurrentSizeValue or self.CurrentSizeValue == 0 then
                    self.CurrentSizeValue = 7.0
                end
                if not self.CurrentEraseSizeValue or self.CurrentEraseSizeValue == 0 then
                    self.CurrentEraseSizeValue = 15.0
                end
                
                local colorName = self.CurrentColor or "black"
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

function SWEP:Reload()
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
    if CLIENT then
        local currentColor = self:GetPlayerColor()
        if currentColor == "__custom__" and self.CustomColor then
            return self.CustomColor
        end
        return ChalkMarkerConfig.GetDrawColor("marker", currentColor)
    else
        local owner = self:GetOwner()
        if not IsValid(owner) then return Color(0, 0, 0) end
        local userid = owner:UserID()
        local data = self.PlayerData[userid]
        if data then
            if data.color == "__custom__" and data.customColor then
                return data.customColor
            end
            return ChalkMarkerConfig.GetDrawColor("marker", data.color or "black")
        end
        return Color(0, 0, 0)
    end
end

-- Настройки VIEW/WORLD модели
SWEP.ViewModelOffset = Vector(20, 10, -3.5)
SWEP.ViewModelAngle = Angle(10, 5, 0)
SWEP.WorldModelOffset = Vector(7.8, -2, 0)
SWEP.WorldModelAngle = Angle(-25, -5, 0)

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
    if IsValid(owner) then
        owner:SetupBones()
        local bone = owner:LookupBone("ValveBiped.Bip01_R_Hand")
        if bone then
            local matrix = owner:GetBoneMatrix(bone)
            if matrix then
                local pos = matrix:GetTranslation()
                local ang = matrix:GetAngles()
                local offsetPos = self.WorldModelOffset or Vector(7.3, 1, 0)
                local offsetAng = self.WorldModelAngle or Angle(25, -5, 0)
                local newPos, newAng = LocalToWorld(offsetPos, offsetAng, pos, ang)
                self:SetRenderOrigin(newPos)
                self:SetRenderAngles(newAng)
                self:SetupBones()
                self:DrawModel()
                self:SetRenderOrigin()
                self:SetRenderAngles()
                return
            end
        end
        self:DrawModel()
    else
        self:SetRenderOrigin(nil)
        self:SetRenderAngles(nil)
        self:DrawModel()
    end
end

function SWEP:PrimaryAttack()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    local tr = owner:GetEyeTrace()
    if IsValid(tr.Entity) and self:IsSupportedBoard(tr.Entity) then
        local sizeValue = self:GetDrawSizeValue()
        if CLIENT then
            net.Start("MarkerDraw")
                net.WriteEntity(tr.Entity)
                net.WriteVector(tr.HitPos)
                net.WriteColor(self:GetDrawColor())
                net.WriteUInt(sizeValue or 7, 8)
                net.WriteBool(true)
            net.SendToServer()
        end
    end
    self:SetNextPrimaryFire(CurTime() + 0.02)
    self.WasAttacking = true
end

function SWEP:SecondaryAttack()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    local tr = owner:GetEyeTrace()
    if IsValid(tr.Entity) and self:IsSupportedBoard(tr.Entity) then
        local eraseSizeValue = self:GetEraseSizeValue()
        if CLIENT then
            net.Start("MarkerErase")
                net.WriteEntity(tr.Entity)
                net.WriteVector(tr.HitPos)
                net.WriteUInt(eraseSizeValue or 12, 8)
                net.WriteBool(true)
            net.SendToServer()
        end
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
            local currentColor = self:GetPlayerColor()
            local nextColor = self:GetNextColor()

            ColorDebug(
                "COLOR SWITCH",
                owner:Nick(),
                "TIME:",
                math.floor(SysTime() * 1000),
                "FROM:",
                currentColor,
                "TO:",
                nextColor
            )

            self:SetPlayerColor(nextColor)
        end
    elseif not reloadDown then
        self.ReloadPressed = false
    end
    
    if not isAttacking then self.WasAttacking = false end
    if not isAttacking2 then self.WasAttacking2 = false end
    
    if owner:KeyDown(IN_SPEED) and owner:KeyPressed(IN_RELOAD) then
        if CLIENT then
            local tr = owner:GetEyeTrace()
            local ent = tr.Entity
            if IsValid(ent) and self:IsSupportedBoard(ent) then
                RunConsoleCommand("marker_clear")
            end
        end
        return
    end

    if CLIENT then
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
                self:SetNextPrimaryFire(CurTime() + 0.01)
                self.WasAttacking = true
            end
        end
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
                self:SetNextSecondaryFire(CurTime() + 0.01)
                self.WasAttacking2 = true
            end
        end
    end
end

function SWEP:OnRemove()
    if SERVER then
        self.PlayerData = {}
    end
end

if CLIENT then
    net.Receive("MarkerSyncColorIndex", function()
        local weapon = net.ReadEntity()
        local colorIndex = net.ReadUInt(8)
        if IsValid(weapon) then weapon.ColorIndex = colorIndex end
    end)
    
    net.Receive("MarkerColorUpdate", function()
        local weapon = net.ReadEntity()
        local colorName = net.ReadString()
        if IsValid(weapon) then
            weapon.CurrentColor = colorName
            if weapon.SetMarkerColor then weapon:SetMarkerColor(colorName) end
            local colors = ChalkMarkerConfig.ColorOrder.marker or {"black", "red", "blue", "green", "yellow", "orange", "cyan", "purple", "pink", "brown"}
            for i, color in ipairs(colors) do
                if color == colorName then weapon.ColorIndex = i; break end
            end
        end
    end)

    net.Receive("MarkerDraw", function()
        local whiteboard = net.ReadEntity()
        local hitPos = net.ReadVector()
        local color = net.ReadColor()
        local size = net.ReadUInt(8)
        local isNewLine = net.ReadBool()
        if IsValid(whiteboard) and whiteboard.DrawOnBoard then
            whiteboard:DrawOnBoard(hitPos, color, size, isNewLine)
        end
    end)
    
    net.Receive("MarkerErase", function()
        local whiteboard = net.ReadEntity()
        local hitPos = net.ReadVector()
        local size = net.ReadUInt(8)
        local isNewLine = net.ReadBool()
        if IsValid(whiteboard) and whiteboard.EraseOnBoard then
            whiteboard:EraseOnBoard(hitPos, size, isNewLine)
        end
    end)
end

-- HUD и прицел
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
            "SHIFT+R: Full Clear (only whiteboard and little whiteboard)",
            "R: Quick Change Color",
            "T: Tool Menu (you can assign another key)"
        }
        
        surface.SetFont("HudSelectionText")
        local maxWidth, maxHeight, padding = 0, 0, 20
        local title = "CONTROLS"
        local titleWidth = surface.GetTextSize(title)
        for _, hint in ipairs(hints) do
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
            draw.SimpleText(title, "DermaDefaultBold", x + totalWidth / 2, titleY, Color(255, 255, 255, 255 * hintAlpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            local lineY = titleY + lineHeight - 5
            surface.SetDrawColor(255, 212, 0, 150 * hintAlpha)
            surface.DrawRect(x + padding, lineY, totalWidth - padding * 2, 1)
            for i, hint in ipairs(hints) do
                local textY = y + padding + i * lineHeight
                draw.SimpleText(hint, "HudSelectionText", x + padding, textY, Color(255, 212, 0, 255 * hintAlpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end
        end
        
        local isErasing = owner:KeyDown(IN_ATTACK2)
        local isDrawing = owner:KeyDown(IN_ATTACK)
        local centerX, centerY = ScrW() / 2, ScrH() / 2
        local radius
        if isErasing then 
            radius = self:GetEraseSizeValue() or 15
        elseif isDrawing then 
            radius = (self:GetDrawSizeValue() or 7) * 1.5
        else 
            radius = 20 
        end
        
        local dotRadius, thickness = 5, 3
        local cacheKey = radius .. "_" .. ScrW() .. "_" .. ScrH()
        if not self.ReticleCacheKey or self.ReticleCacheKey ~= cacheKey then
            self.ReticleCacheKey = cacheKey
            self.RingPolyCache, self.DotPolyCache = {}, {}
            local segments, angleStep = 48, (2 * math.pi) / 48
            local innerRadius = radius - thickness
            local outerPoints, innerPoints = {}, {}
            for i = 0, segments do
                local angle = i * angleStep
                local cosA, sinA = math.cos(angle), math.sin(angle)
                outerPoints[i+1] = {x = centerX + cosA * radius, y = centerY + sinA * radius}
                innerPoints[i+1] = {x = centerX + cosA * innerRadius, y = centerY + sinA * innerRadius}
            end
            for i = 1, segments do
                table.insert(self.RingPolyCache, {outerPoints[i], outerPoints[i+1], innerPoints[i+1], innerPoints[i]})
            end
            for i = 0, segments do
                local angle = i * angleStep
                table.insert(self.DotPolyCache, {x = centerX + math.cos(angle) * dotRadius, y = centerY + math.sin(angle) * dotRadius})
            end
        end
        
        draw.NoTexture()
        render.OverrideBlend(true, BLEND_ONE_MINUS_DST_COLOR, BLEND_ZERO, BLENDFUNC_ADD)
        surface.SetDrawColor(255, 255, 255, 255)
        if self.RingPolyCache then 
            for _, poly in ipairs(self.RingPolyCache) do 
                surface.DrawPoly(poly) 
            end 
        end
        if self.DotPolyCache then 
            surface.DrawPoly(self.DotPolyCache) 
        end
        render.OverrideBlend(false)
    end
    
    function SWEP:Holster()
        isShowingHint = false
        return true
    end
end

hook.Add("HUDShouldDraw", "MarkerTool_HideDefaultCrosshair", function(name)
    if name == "CHudCrosshair" then
        local ply = LocalPlayer()
        if IsValid(ply) then
            local wep = ply:GetActiveWeapon()
            if IsValid(wep) and wep:GetClass() == "marker_tool" then
                return false
            end
        end
    end
end)