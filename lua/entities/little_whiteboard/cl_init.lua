include("shared.lua")

littleWhiteboardRTs = littleWhiteboardRTs or {}
local DRAW_DISTANCE = 100
local MAX_DRAW_DISTANCE_SQ = DRAW_DISTANCE * DRAW_DISTANCE

local markerMaterial = Material("render/marker_draw_unit")
markerMaterial:SetFloat("$alpha", 1)
markerMaterial:SetInt("$translucent", 1)

LittleWhiteboardRTPool = LittleWhiteboardRTPool or {
    free = {},
    used = {},
    size = 2,
    format = {
        size = 1024,
        name = "LittleWhiteboardRT"
    }
}

function LittleWhiteboardRTPool:Initialize()
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

function LittleWhiteboardRTPool:GetBoardRT(ent)
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

function LittleWhiteboardRTPool:ReleaseBoardRT(ent)
    if not IsValid(ent) then return end
    
    local entIndex = ent:EntIndex()
    if self.used[entIndex] then
        local rtData = self.used[entIndex]
        self.used[entIndex] = nil
        table.insert(self.free, rtData)
    end
end

LittleWhiteboardRTPool:Initialize()

function ENT:Initialize()
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
    
    self:InitializeLittleWhiteboard()
    self:ShowLoadingNotification()
    
    self:NextThink(CurTime() + 0.1)
end

function ENT:InitializeLittleWhiteboard()
    local rtData = LittleWhiteboardRTPool:GetBoardRT(self)
    if not rtData then return end
    
    local entIndex = self:EntIndex()
    littleWhiteboardRTs[entIndex] = littleWhiteboardRTs[entIndex] or {}
    littleWhiteboardRTs[entIndex].rt = rtData.rt
    littleWhiteboardRTs[entIndex].mat = rtData.mat
    littleWhiteboardRTs[entIndex].size = self.canvasSize
    littleWhiteboardRTs[entIndex].poolData = rtData
    
    render.PushRenderTarget(rtData.rt)
    render.Clear(0, 0, 0, 0)
    render.PopRenderTarget()
    
    self:UpdateLittleWhiteboardMaterial()
    
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
    if not littleWhiteboardRTs[entIndex] then return end
    
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

function ENT:GetLittleWhiteboardBounds()
    if not self.WhiteboardBounds then
        local halfWidth = 14.5
        local halfHeight = 21
        
        local visualPos = self:GetVisualBoardPosition()
        local ang = self:GetAngles()
        local right = ang:Right()
        local up = ang:Up()
        
        local topLeft_local = self:WorldToLocal(visualPos + (up * halfHeight) + (right * (-halfWidth)))
        local bottomRight_local = self:WorldToLocal(visualPos + (up * (-halfHeight)) + (right * halfWidth))
        
        self.WhiteboardBounds = {
            mins = Vector(-1, math.min(topLeft_local.y, bottomRight_local.y), math.min(topLeft_local.z, bottomRight_local.z)),
            maxs = Vector(1, math.max(topLeft_local.y, bottomRight_local.y), math.max(topLeft_local.z, bottomRight_local.z))
        }
    end 
    return self.WhiteboardBounds.mins, self.WhiteboardBounds.maxs
end

function ENT:GetVisualBoardPosition()
    local pos = self:GetPos()
    local ang = self:GetAngles()
    ang:RotateAroundAxis(ang:Up(), 180)
    ang:RotateAroundAxis(ang:Right(), -9.6)
    local forward = ang:Forward()
    local right = ang:Right()
    local up = ang:Up()
    
    pos = pos - forward * 13.5
    pos = pos + right * 0.1
    pos = pos + up * 49
    
    return pos
end

function ENT:LocalToTextureCoords(localPos)
    local mins, maxs = self:GetLittleWhiteboardBounds()
    
    local texCoordX = (localPos.y - mins.y) / (maxs.y - mins.y)
    local texCoordY = (localPos.z - mins.z) / (maxs.z - mins.z)
    
    texCoordY = 1 - texCoordY
    
    texCoordX = math.Clamp(texCoordX, 0, 1)
    texCoordY = math.Clamp(texCoordY, 0, 1)
        
    return texCoordX, texCoordY
end

function ENT:CalculateBoardPosition(hitPos)
    local visualPos = self:GetVisualBoardPosition()
    local visualAng = self:GetAngles()
    visualAng:RotateAroundAxis(visualAng:Up(), -180)
    visualAng:RotateAroundAxis(visualAng:Right(), -9.6)
    
    local right = visualAng:Right()
    local up = visualAng:Up()
    
    local relativePos = hitPos - visualPos
    local localY = relativePos:Dot(right)
    local localZ = relativePos:Dot(up)
    
    local halfWidth = 14.5
    local halfHeight = 21
    local isOnBoard = math.abs(localY) <= halfWidth and math.abs(localZ) <= halfHeight
    
    local texCoordX, texCoordY = 0, 0
    if isOnBoard then
        texCoordX = (localY + halfWidth) / (halfWidth * 2)
        texCoordY = 1 - ((localZ + halfHeight) / (halfHeight * 2))
        
        texCoordX = math.Clamp(texCoordX, 0, 1)
        texCoordY = math.Clamp(texCoordY, 0, 1)
    end
    
    return isOnBoard, texCoordX, texCoordY
end

function ENT:GetRTData()
    return littleWhiteboardRTs[self:EntIndex()]
end

function ENT:GetDrawMaterial()
    return markerMaterial
end

function ENT:UpdateMaterial()
    self:UpdateLittleWhiteboardMaterial()
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
    
    local ply = IsValid(player) and player or LocalPlayer()
    if not IsValid(ply) then return end
    if ply:GetPos():DistToSqr(self:GetPos()) > MAX_DRAW_DISTANCE_SQ then
        return
    end

    local entIndex = self:EntIndex()
    if not littleWhiteboardRTs[entIndex] then
        self:InitializeLittleWhiteboard()
        if not littleWhiteboardRTs[entIndex] then return end
    end

    local isOnBoard, texCoordX, texCoordY = self:CalculateBoardPosition(hitPos)

    if not isOnBoard then
        return
    end
    
    local canvasSize = littleWhiteboardRTs[entIndex].size or 1024
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
    
    local ply = IsValid(player) and player or LocalPlayer()
    if not IsValid(ply) then return end
    if ply:GetPos():DistToSqr(self:GetPos()) > MAX_DRAW_DISTANCE_SQ then
        return
    end

    local entIndex = self:EntIndex()
    if not littleWhiteboardRTs[entIndex] then return end
    
    local isOnBoard, texCoordX, texCoordY = self:CalculateBoardPosition(hitPos)
    
    if not isOnBoard then
        return
    end
    
    local canvasSize = littleWhiteboardRTs[entIndex].size or 1024
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
    if not littleWhiteboardRTs[entIndex] or not littleWhiteboardRTs[entIndex].rt then return end
    
    render.PushRenderTarget(littleWhiteboardRTs[entIndex].rt)
    render.Clear(0, 0, 0, 0)
    render.PopRenderTarget()
    
    self:DrawPointsOnRT(self.drawPointsBuffer)
    self:UpdateLittleWhiteboardMaterial()
end

function ENT:UpdateLittleWhiteboardMaterial()
    local entIndex = self:EntIndex()
    if not littleWhiteboardRTs[entIndex] or not littleWhiteboardRTs[entIndex].mat then return end
    
    local mat = littleWhiteboardRTs[entIndex].mat
    mat:SetTexture("$basetexture", littleWhiteboardRTs[entIndex].rt)
    mat:Recompute()
end

local draw_whiteboard_vectors = {
    halfWidth = 14.5,
    halfHeight = 21,
    pos_offset_forward = -13.6,
    pos_offset_right = 0.1,
    pos_offset_up = 49
}

function ENT:DrawLittleWhiteboard()
    local entIndex = self:EntIndex()
    
    if not littleWhiteboardRTs[entIndex] or not littleWhiteboardRTs[entIndex].rt then
        self:InitializeLittleWhiteboard()
        if not littleWhiteboardRTs[entIndex] or not littleWhiteboardRTs[entIndex].rt then
            return
        end
    end
    
    local mat = littleWhiteboardRTs[entIndex].mat
    if not mat then return end

    local pos = self:GetPos()
    local ang = self:GetAngles()
    ang:RotateAroundAxis(ang:Up(), 180)
    ang:RotateAroundAxis(ang:Right(), -9.6)
    local right = ang:Right()
    local up = ang:Up()
    local forward = ang:Forward()
    
    pos = pos + forward * draw_whiteboard_vectors.pos_offset_forward
    pos = pos + right * draw_whiteboard_vectors.pos_offset_right
    pos = pos + up * draw_whiteboard_vectors.pos_offset_up
    
    local hw = draw_whiteboard_vectors.halfWidth
    local hh = draw_whiteboard_vectors.halfHeight

    local topLeft = pos + (up * hh) + (right * (-hw))
    local topRight = pos + (up * hh) + (right * hw)
    local bottomRight = pos + (up * (-hh)) + (right * hw)
    local bottomLeft = pos + (up * (-hh)) + (right * (-hw))
    
    render.SetBlend(1)
    render.SetColorModulation(1, 1, 1)
    render.SetMaterial(mat)
    render.DrawQuad(topLeft, topRight, bottomRight, bottomLeft)
end

function ENT:Draw()
    self:DrawModel()
    self:DrawLittleWhiteboard()
end

function ENT:Think()
    local entIndex = self:EntIndex()
    if littleWhiteboardRTs[entIndex] and littleWhiteboardRTs[entIndex].poolData then
        littleWhiteboardRTs[entIndex].poolData.lastUsed = CurTime()
    end
    self:NextThink(CurTime() + 0.1)
    return true
end

function ENT:OnRemove()
    LittleWhiteboardRTPool:ReleaseBoardRT(self)
    
    local entIndex = self:EntIndex()
    if littleWhiteboardRTs[entIndex] then
        littleWhiteboardRTs[entIndex] = nil
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