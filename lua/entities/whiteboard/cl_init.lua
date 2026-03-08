include("shared.lua")

whiteboardRTs = whiteboardRTs or {}
local DRAW_DISTANCE = 100
local MAX_DRAW_DISTANCE_SQ = DRAW_DISTANCE * DRAW_DISTANCE

local markerMaterial = Material("render/marker_draw_unit")
markerMaterial:SetFloat("$alpha", 1)
markerMaterial:SetInt("$translucent", 1)

WhiteboardRTPool = WhiteboardRTPool or {
    free = {},
    used = {},
    size = 3,
    format = {
        size = 1024,
        name = "WhiteboardRT"
    }
}

function WhiteboardRTPool:Initialize()
    if #self.free > 0 then return end
    
    for i = 1, self.size do
        local rt = GetRenderTarget(self.format.name .. i, self.format.size, self.format.size)
        local mat = CreateMaterial(self.format.name .. "_mat" .. i, "UnlitGeneric", {
            ["$basetexture"] = rt:GetName(),
            ["$vertexcolor"] = 1,
            ["$vertexalpha"] = 1,
            ["$model"] = 0,
            ["$nocull"] = 1,
            ["$translucent"] = 1,
            ["$alphatest"] = 1,
            ["$alpha"] = 1
        })
        
        table.insert(self.free, {
            rt = rt,
            mat = mat,
            index = i,
            lastUsed = 0
        })
    end
end

function WhiteboardRTPool:GetBoardRT(ent)
    if not IsValid(ent) then return nil end
    
    local entIndex = ent:EntIndex()
    
    if self.used[entIndex] then
        return self.used[entIndex]
    end
    
    if #self.free > 0 then
        local rtData = table.remove(self.free, 1)
        self.used[entIndex] = rtData
        rtData.lastUsed = CurTime()
        return rtData
    end
    
    local oldestTime = CurTime()
    local oldestEnt = nil
    local oldestRT = nil
    
    for e, rtData in pairs(self.used) do
        if rtData.lastUsed < oldestTime then
            oldestTime = rtData.lastUsed
            oldestEnt = e
            oldestRT = rtData
        end
    end
    
    if oldestEnt and oldestRT then
        self.used[oldestEnt] = nil
        self.used[entIndex] = oldestRT
        oldestRT.lastUsed = CurTime()
        return oldestRT
    end
    
    return nil
end

function WhiteboardRTPool:ReleaseBoardRT(ent)
    if not IsValid(ent) then return end
    
    local entIndex = ent:EntIndex()
    if self.used[entIndex] then
        local rtData = self.used[entIndex]
        self.used[entIndex] = nil
        table.insert(self.free, rtData)
    end
end

WhiteboardRTPool:Initialize()

function ENT:Initialize()
    self.LampSprite = Material("sprites/light_glow02_add_noz")
    
    self.canvasSize = 1024
    self.interpStep = 3
    self.redrawDelay = 0.05

    local quality = GetConVarNumber("render_qlt")
    if quality == 1 then
        self.canvasSize = 512
        self.interpStep = 4
        self.redrawDelay = 0.066
    else
        self.canvasSize = 1024
        self.interpStep = 3
        self.redrawDelay = 0.05
    end
    
    self.PlayerDrawData = {}
    self.PlayerColors = {}
    self.PlayerLastDrawPos = {}
    self.drawPointsBuffer = {}
    
    self:InitializeWhiteboard()
end

function ENT:InitializeWhiteboard()
    local rtData = WhiteboardRTPool:GetBoardRT(self)
    if not rtData then return end
    
    local entIndex = self:EntIndex()
    whiteboardRTs[entIndex] = whiteboardRTs[entIndex] or {}
    whiteboardRTs[entIndex].rt = rtData.rt
    whiteboardRTs[entIndex].mat = rtData.mat
    whiteboardRTs[entIndex].size = self.canvasSize
    whiteboardRTs[entIndex].poolData = rtData
    
    render.PushRenderTarget(rtData.rt)
    render.Clear(0, 0, 0, 0)
    render.PopRenderTarget()
    
    self:UpdateWhiteboardMaterial()
    
    if #self.drawPointsBuffer > 0 then
        self:DrawPointsOnRT(self.drawPointsBuffer)
    end
end

function ENT:GetPlayerID(player)
    if not IsValid(player) then return "default" end
    return player:SteamID() or "player_" .. tostring(player:UserID())
end

function ENT:ClearWhiteboard()
    local entIndex = self:EntIndex()
    if not whiteboardRTs[entIndex] then return end
    
    self.PlayerDrawData = {}
    self.PlayerColors = {}
    self.PlayerLastDrawPos = {}
    self.drawPointsBuffer = {}
    self.LastErasePos = nil
    
    self:ForceRedraw()
end

function ENT:ClearPlayerDrawings(player)
    if not IsValid(player) then return end
    
    local playerID = self:GetPlayerID(player)
    
    local newBuffer = {}
    for _, point in ipairs(self.drawPointsBuffer) do
        if point.playerID ~= playerID then
            table.insert(newBuffer, point)
        end
    end
    
    self.drawPointsBuffer = newBuffer
    self.PlayerDrawData[playerID] = nil
    self.PlayerColors[playerID] = nil
    self.PlayerLastDrawPos[playerID] = nil
    
    self:ForceRedraw()
end

function ENT:GetWhiteboardBounds()
    if not self.WhiteboardBounds then
        local halfWidth = 37.85
        local halfHeight = 21.7
        
        self.WhiteboardBounds = {
            mins = Vector(-2, -halfWidth, -halfHeight),
            maxs = Vector(2, halfWidth, halfHeight)
        }
    end
    return self.WhiteboardBounds.mins, self.WhiteboardBounds.maxs
end

function ENT:LocalToTextureCoords(localPos)
    local mins, maxs = self:GetWhiteboardBounds()
    
    local correctionY = -1.2
    local correctionZ = -1
    
    local correctedY = localPos.y + correctionY
    local correctedZ = localPos.z + correctionZ
    
    local texCoordX = (correctedY - mins.y) / (maxs.y - mins.y)
    local texCoordY = (correctedZ - mins.z) / (maxs.z - mins.z)
    
    texCoordY = 1 - texCoordY
    
    texCoordX = math.Clamp(texCoordX, 0, 1)
    texCoordY = math.Clamp(texCoordY, 0, 1)
    
    return texCoordX, texCoordY
end

function ENT:IsPointOnBoard(localPos)
    if not localPos then return false end
    
    local mins, maxs = self:GetWhiteboardBounds()
    
    return math.abs(localPos.x) <= 2 and
           localPos.y >= mins.y and localPos.y <= maxs.y and
           localPos.z >= mins.z and localPos.z <= maxs.z
end

function ENT:GetRTData()
    return whiteboardRTs[self:EntIndex()]
end

function ENT:GetDrawMaterial()
    return markerMaterial
end

function ENT:UpdateMaterial()
    self:UpdateWhiteboardMaterial()
end

function ENT:DrawPointsOnRT(points)
    local entIndex = self:EntIndex()
    local rtData = self:GetRTData()
    if not rtData or not rtData.rt then return end
    
    render.PushRenderTarget(rtData.rt)
    render.OverrideAlphaWriteEnable(true, true)
    
    cam.Start2D()
    
    local material = self:GetDrawMaterial()
    surface.SetMaterial(material)
    
    for _, point in ipairs(points) do
        surface.SetDrawColor(point.color.r, point.color.g, point.color.b, 255)
        local halfSize = point.size / 2
        surface.DrawTexturedRect(
            math.Round(point.x - halfSize),
            math.Round(point.y - halfSize),
            point.size,
            point.size
        )
    end
    
    cam.End2D()
    render.OverrideAlphaWriteEnable(false)
    render.PopRenderTarget()
    
    self:UpdateMaterial()
end

function ENT:DrawOnBoard(hitPos, color, size, isNewLine, player)
    if not IsValid(self) then return end
    
    local entIndex = self:EntIndex()
    if not whiteboardRTs[entIndex] then
        self:InitializeWhiteboard()
        if not whiteboardRTs[entIndex] then return end
    end

    local localPos = self:WorldToLocal(hitPos)
    if not self:IsPointOnBoard(localPos) then return end
    
    local ply = IsValid(player) and player or LocalPlayer()
    if not IsValid(ply) then return end
    if ply:GetPos():DistToSqr(self:GetPos()) > MAX_DRAW_DISTANCE_SQ then
        return
    end

    local texCoordX, texCoordY = self:LocalToTextureCoords(localPos)
    
    local canvasSize = whiteboardRTs[entIndex].size or 1024
    local scaleFactor = 1024 / canvasSize

    local currentX = texCoordX * canvasSize
    local currentY = texCoordY * canvasSize
    local pointSize = (size or 8) * scaleFactor 
    
    local playerID = self:GetPlayerID(player)
    
    if not self.PlayerDrawData[playerID] then
        self.PlayerDrawData[playerID] = {}
    end
    
    self.PlayerColors[playerID] = color

    local isDuplicate = false
    local lastPoint = self.PlayerDrawData[playerID][#self.PlayerDrawData[playerID]]
    if lastPoint and not isNewLine then
        local dist = math.sqrt((currentX - lastPoint.x)^2 + (currentY - lastPoint.y)^2)
        if dist < 1 then
            isDuplicate = true
        end
    end
    
    if not isDuplicate then
        local newPoint = {
            x = currentX,
            y = currentY,
            color = Color(color.r, color.g, color.b),
            size = pointSize,
            playerID = playerID,
            timestamp = CurTime()
        }
        local pointsToDraw = {newPoint}
        
        table.insert(self.drawPointsBuffer, newPoint)
        table.insert(self.PlayerDrawData[playerID], newPoint)
        
        local lastPlayerPos = self.PlayerLastDrawPos[playerID]
        if lastPlayerPos and not isNewLine then
            local lastX, lastY = lastPlayerPos.x, lastPlayerPos.y
            local dist = math.sqrt((currentX - lastX)^2 + (currentY - lastY)^2)
            if dist > 2 then
                local steps = math.max(2, math.floor(dist / self.interpStep))
                for i = 1, steps - 1 do
                    local t = i / steps
                    local lineX = lastX + (currentX - lastX) * t
                    local lineY = lastY + (currentY - lastY) * t

                    local linePoint = {
                        x = lineX,
                        y = lineY,
                        color = Color(color.r, color.g, color.b),
                        size = pointSize,
                        playerID = playerID,
                        timestamp = CurTime() + i * 0.001
                    }
                    table.insert(self.drawPointsBuffer, linePoint)
                    table.insert(self.PlayerDrawData[playerID], linePoint)
                    table.insert(pointsToDraw, linePoint)
                end
            end
        end
        
        self.PlayerLastDrawPos[playerID] = {x = currentX, y = currentY}
        
        self:DrawPointsOnRT(pointsToDraw)
    end
end

function ENT:EraseOnBoard(hitPos, size, isNewLine, player)
    if not IsValid(self) then return end
    
    local entIndex = self:EntIndex()
    if not whiteboardRTs[entIndex] then return end
    
    local localPos = self:WorldToLocal(hitPos)
    if not self:IsPointOnBoard(localPos) then return end
    
    local ply = IsValid(player) and player or LocalPlayer()
    if not IsValid(ply) then return end
    if ply:GetPos():DistToSqr(self:GetPos()) > MAX_DRAW_DISTANCE_SQ then
        return
    end

    local texCoordX, texCoordY = self:LocalToTextureCoords(localPos)
    local canvasSize = whiteboardRTs[entIndex].size or 1024
    local currentX = texCoordX * canvasSize
    local currentY = texCoordY * canvasSize
    local eraseSize = size or 20
    local eraseRadius = eraseSize / 2

    if isNewLine then
        self.LastErasePos = nil
    end

    local playerID = self:GetPlayerID(player)
    
    self:EraseAtPosition(currentX, currentY, eraseRadius, playerID)
    
    if self.LastErasePos and not isNewLine then
        local lastX, lastY = self.LastErasePos.x, self.LastErasePos.y
        local dist = math.sqrt((currentX - lastX)^2 + (currentY - lastY)^2)
        
        if dist > 2 then
            local steps = math.max(2, math.floor(dist / self.interpStep))
            for i = 1, steps - 1 do
                local t = i / steps
                local lineX = lastX + (currentX - lastX) * t
                local lineY = lastY + (currentY - lastY) * t
                
                self:EraseAtPosition(lineX, lineY, eraseRadius, playerID)
            end
        end
    end
    
    self.LastErasePos = {x = currentX, y = currentY}
    self:ForceRedraw()
end

function ENT:EraseAtPosition(x, y, radius, playerID)
    local pointsToRemove = {}
    local radiusSquared = radius * radius
    
    for i, point in ipairs(self.drawPointsBuffer) do
        local distSquared = (point.x - x)^2 + (point.y - y)^2
        if distSquared <= radiusSquared then
            if not playerID or point.playerID == playerID then
                table.insert(pointsToRemove, i)
            end
        end
    end
    
    for i = #pointsToRemove, 1, -1 do
        table.remove(self.drawPointsBuffer, pointsToRemove[i])
    end
    
    if playerID and self.PlayerDrawData[playerID] then
        local playerPointsToRemove = {}
        for i, point in ipairs(self.PlayerDrawData[playerID]) do
            local distSquared = (point.x - x)^2 + (point.y - y)^2
            if distSquared <= radiusSquared then
                table.insert(playerPointsToRemove, i)
            end
        end
        
        for i = #playerPointsToRemove, 1, -1 do
            table.remove(self.PlayerDrawData[playerID], playerPointsToRemove[i])
        end
    end
end

function ENT:ForceRedraw()
    local entIndex = self:EntIndex()
    if not whiteboardRTs[entIndex] or not whiteboardRTs[entIndex].rt then return end
    
    render.PushRenderTarget(whiteboardRTs[entIndex].rt)
    render.Clear(0, 0, 0, 0)
    render.PopRenderTarget()
    
    self:DrawPointsOnRT(self.drawPointsBuffer)
    self:UpdateWhiteboardMaterial()
end

function ENT:UpdateWhiteboardMaterial()
    local entIndex = self:EntIndex()
    if not whiteboardRTs[entIndex] or not whiteboardRTs[entIndex].mat then return end
    
    local mat = whiteboardRTs[entIndex].mat
    mat:SetTexture("$basetexture", whiteboardRTs[entIndex].rt)
    mat:Recompute()
end

function ENT:DrawWhiteboard()
    local entIndex = self:EntIndex()
    
    if not whiteboardRTs[entIndex] or not whiteboardRTs[entIndex].rt then
        self:InitializeWhiteboard()
        if not whiteboardRTs[entIndex] or not whiteboardRTs[entIndex].rt then
            return
        end
    end
    
    local mat = whiteboardRTs[entIndex].mat
    if not mat then return end

    local pos = self:GetPos()
    local ang = self:GetAngles()
    ang:RotateAroundAxis(ang:Up(), 180)
    local right = ang:Right()
    local up = ang:Up()
    local forward = ang:Forward()
    
    pos = pos - forward
    pos = pos + right*1.2
    pos = pos + up
    
    local halfWidth = 37.85
    local halfHeight = 21.7
    
    local topLeft = pos + (up * halfHeight) + (right * (-halfWidth))
    local topRight = pos + (up * halfHeight) + (right * halfWidth)
    local bottomRight = pos + (up * (-halfHeight)) + (right * halfWidth)
    local bottomLeft = pos + (up * (-halfHeight)) + (right * (-halfWidth))
    
    render.SetBlend(1)
    render.SetColorModulation(1, 1, 1)
    render.SetMaterial(mat)
    render.DrawQuad(topLeft, topRight, bottomRight, bottomLeft)
end

function ENT:Draw()
    self:DrawModel()
    self:DrawWhiteboard()
    self:DrawLampGlow()
end

function ENT:Think()
    local entIndex = self:EntIndex()
    if whiteboardRTs[entIndex] and whiteboardRTs[entIndex].poolData then
        whiteboardRTs[entIndex].poolData.lastUsed = CurTime()
    end

    self:UpdateLight()
    self:NextThink(CurTime() + 0.1)
    return true
end

function ENT:UpdateLight()
    if not self:GetLightEnabled() then return end
    
    local lampLocalPos = Vector(0, 0, 24.5)
    local lampWorldPos = self:LocalToWorld(lampLocalPos)
    local forward = self:GetForward()
    local lightPos = lampWorldPos + forward * 15
    
    local lightColor = self:GetLightColor()
    
    local dlight = DynamicLight(self:EntIndex())
    if dlight then
        dlight.Pos = lightPos
        dlight.r = lightColor.x
        dlight.g = lightColor.y
        dlight.b = lightColor.z
        dlight.Brightness = self:GetLightBrightness() * 0.5
        dlight.Size = self:GetLightDistance() * 2
        dlight.Decay = 1000
        dlight.DieTime = CurTime() + 1
    end
end

function ENT:DrawLampGlow()
    if not self:GetLightEnabled() or not self.LampSprite then return end
    
    local lightColor = self:GetLightColor()
    local brightness = self:GetLightBrightness() * 0.3
    local lampLocalPos = Vector(1.3, 0, 22)
    local lampWorldPos = self:LocalToWorld(lampLocalPos)
    local right = self:GetRight()
    local up = self:GetUp()

    local baseWidth = 200
    local baseHeight = 16

    render.SuppressEngineLighting(true)
    render.SetColorModulation(1, 1, 1)
    render.OverrideDepthEnable(true, false)
    
    render.SetMaterial(self.LampSprite)

    render.DrawQuad(
        lampWorldPos + right * (-baseWidth/2) + up * (-baseHeight/2),
        lampWorldPos + right * (baseWidth/2) + up * (-baseHeight/2),
        lampWorldPos + right * (baseWidth/2) + up * (baseHeight/2),
        lampWorldPos + right * (-baseWidth/2) + up * (baseHeight/2),
        Color(lightColor.x, lightColor.y, lightColor.z, 255 * brightness)
    )

    render.DrawQuad(
        lampWorldPos + right * (-baseWidth) + up * (-baseHeight),
        lampWorldPos + right * (baseWidth) + up * (-baseHeight),
        lampWorldPos + right * (baseWidth) + up * (baseHeight),
        lampWorldPos + right * (-baseWidth) + up * (baseHeight),
        Color(lightColor.x, lightColor.y, lightColor.z, 100 * brightness)
    )

    render.DrawQuad(
        lampWorldPos + right * (-baseWidth/3) + up * (-baseHeight/3),
        lampWorldPos + right * (baseWidth/3) + up * (-baseHeight/3),
        lampWorldPos + right * (baseWidth/3) + up * (baseHeight/3),
        lampWorldPos + right * (-baseWidth/3) + up * (baseHeight/3),
        Color(255, 255, 255, 200 * brightness)
    )

    render.OverrideDepthEnable(false, false)
    render.SuppressEngineLighting(false)
end

function ENT:OnRemove()
    WhiteboardRTPool:ReleaseBoardRT(self)
    
    local entIndex = self:EntIndex()
    if whiteboardRTs[entIndex] then
        whiteboardRTs[entIndex] = nil
    end
    
    if self.ProjectedTexture then
        self.ProjectedTexture:Remove()
        self.ProjectedTexture = nil
    end
end

net.Receive("MarkerDraw", function()
    local whiteboard = net.ReadEntity()
    local hitPos = net.ReadVector()
    local color = net.ReadColor()
    local size = net.ReadUInt(8)
    local isNewLine = net.ReadBool()
    local player = net.ReadEntity()
    
    if IsValid(whiteboard) and whiteboard.DrawOnBoard then
        whiteboard:DrawOnBoard(hitPos, color, size, isNewLine, player)
    end
end)

net.Receive("MarkerErase", function()
    local whiteboard = net.ReadEntity()
    local hitPos = net.ReadVector()
    local size = net.ReadUInt(8)
    local isNewLine = net.ReadBool()
    local player = net.ReadEntity()
    
    if IsValid(whiteboard) and whiteboard.EraseOnBoard then
        whiteboard:EraseOnBoard(hitPos, size, isNewLine, player)
    end
end)

net.Receive("WhiteboardClear", function()
    local whiteboard = net.ReadEntity()
    if IsValid(whiteboard) and whiteboard.ClearWhiteboard then
        whiteboard:ClearWhiteboard()
    end
end)

net.Receive("WhiteboardClearPlayer", function()
    local whiteboard = net.ReadEntity()
    local player = net.ReadEntity()
    if IsValid(whiteboard) and whiteboard.ClearPlayerDrawings then
        whiteboard:ClearPlayerDrawings(player)
    end
end)

concommand.Add("marker_clear", function(ply)
    local tr = ply:GetEyeTrace()
    local ent = tr.Entity
    if IsValid(ent) and (ent:GetClass() == "little_whiteboard" or ent:GetClass() == "whiteboard")then
        ent:ClearWhiteboard()
        print("Whiteboard cleared!")
    else
        print("Look at a whiteboard to clear it!")
    end
end)

hook.Add("KeyRelease", "WhiteboardForceRedraw", function(ply, key)
    if key == IN_ATTACK or key == IN_ATTACK2 then
        local tr = ply:GetEyeTrace()
        local ent = tr.Entity
        if IsValid(ent) and (ent:GetClass() == "little_whiteboard" or ent:GetClass() == "whiteboard") then
            ent:ForceRedraw()
        end
    end
end)