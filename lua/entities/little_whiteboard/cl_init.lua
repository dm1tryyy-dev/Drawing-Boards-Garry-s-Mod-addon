include("shared.lua")

littleWhiteboardRTs = littleWhiteboardRTs or {}
local DRAW_DISTANCE = 200
local MAX_DRAW_DISTANCE_SQ = DRAW_DISTANCE * DRAW_DISTANCE
local LITTLE_WHITEBOARD_ASPECT = 14.5 / 21

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
    
    -- Оптимизации
    self.drawGrid = {}
    self.gridCellSize = 64
    self.dirtyRegions = {}
    self.nextRedraw = 0
    self.drawQueue = {}
    self.lastDrawTime = 0
    self.drawThrottleTime = 0.016
    self.pendingDraw = false
    self.LastErasePos = nil
    self.pointCounter = 0
    
    self:InitializeLittleWhiteboard()    
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
    self.drawGrid = {}
    self.drawQueue = {}
    self.pointCounter = 0
    self.LastErasePos = nil
    
    self:ForceRedraw()
end

function ENT:ClearPlayerDrawings(player)
    if not IsValid(player) then return end
    
    local playerID = self:GetPlayerID(player)
    
    for key, cell in pairs(self.drawGrid) do
        for i = #cell, 1, -1 do
            if cell[i].playerID == playerID then
                cell[i].__removed = true
                table.remove(cell, i)
            end
        end
        if #cell == 0 then self.drawGrid[key] = nil end
    end
    
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
    if not self._cachedBounds then
        local halfWidth = 14.5
        local halfHeight = 21
        
        local visualPos = self:GetVisualBoardPosition()
        local ang = self:GetAngles()
        local right = ang:Right()
        local up = ang:Up()
        
        local topLeft_local = self:WorldToLocal(visualPos + (up * halfHeight) + (right * (-halfWidth)))
        local bottomRight_local = self:WorldToLocal(visualPos + (up * (-halfHeight)) + (right * halfWidth))
        
        self._cachedBounds = {
            mins = Vector(-1, math.min(topLeft_local.y, bottomRight_local.y), math.min(topLeft_local.z, bottomRight_local.z)),
            maxs = Vector(1, math.max(topLeft_local.y, bottomRight_local.y), math.max(topLeft_local.z, bottomRight_local.z))
        }
    end 
    return self._cachedBounds.mins, self._cachedBounds.maxs
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
    if not self._texScale then
        local mins, maxs = self:GetLittleWhiteboardBounds()
        self._texScaleX = 1 / (maxs.y - mins.y)
        self._texScaleY = 1 / (maxs.z - mins.z)
        self._texOffsetX = -mins.y
        self._texOffsetY = -mins.z
    end
    
    local texCoordX = (localPos.y + self._texOffsetX) * self._texScaleX
    local texCoordY = 1 - ((localPos.z + self._texOffsetY) * self._texScaleY)
    
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

function ENT:GetGridKey(cellX, cellY)
    return cellX .. "_" .. cellY
end

function ENT:AddPointToGrid(point)
    local cellX = math.floor(point.x / self.gridCellSize)
    local cellY = math.floor(point.y / self.gridCellSize)
    local key = self:GetGridKey(cellX, cellY)
    
    self.drawGrid[key] = self.drawGrid[key] or {}
    point.__gridCell = key
    table.insert(self.drawGrid[key], point)
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
    
    -- Рисуем точки в порядке их создания (сохраняя порядок слоев)
    for _, point in ipairs(points) do
        if not point.__removed then
            surface.SetDrawColor(point.color.r, point.color.g, point.color.b, 255)
            surface.DrawTexturedRect(
                math.Round(point.x - point.w / 2),
                math.Round(point.y - point.h / 2),
                point.w,
                point.h
            )
        end
    end
    
    cam.End2D()
    render.OverrideAlphaWriteEnable(false)
    render.PopRenderTarget()
    
    self:UpdateMaterial()
end

function ENT:FlushDrawQueue()
    if not self.drawQueue or #self.drawQueue == 0 then return end
    
    local pointsToDraw = self.drawQueue
    self.drawQueue = {}
    self.pendingDraw = false
    
    self:DrawPointsOnRT(pointsToDraw)
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

    local baseSize = (size or 8) * scaleFactor
    local pointW = baseSize
    local pointH = baseSize * LITTLE_WHITEBOARD_ASPECT
    
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
        self.pointCounter = self.pointCounter + 1
        
        local newPoint = {
            x = currentX,
            y = currentY,
            color = Color(color.r, color.g, color.b),
            w = pointW,
            h = pointH,
            playerID = playerID,
            timestamp = CurTime(),
            __removed = false,
            __order = self.pointCounter
        }
        
        self:AddPointToGrid(newPoint)
        table.insert(self.drawPointsBuffer, newPoint)
        table.insert(self.PlayerDrawData[playerID], newPoint)
        
        self.drawQueue = self.drawQueue or {}
        table.insert(self.drawQueue, newPoint)
        
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

                    self.pointCounter = self.pointCounter + 1
                    local linePoint = {
                        x = lineX,
                        y = lineY,
                        color = Color(color.r, color.g, color.b),
                        w = pointW,
                        h = pointH,
                        playerID = playerID,
                        timestamp = CurTime() + i * 0.001,
                        __removed = false,
                        __order = self.pointCounter
                    }
                    
                    self:AddPointToGrid(linePoint)
                    table.insert(self.drawPointsBuffer, linePoint)
                    table.insert(self.PlayerDrawData[playerID], linePoint)
                    table.insert(self.drawQueue, linePoint)
                end
            end
        end
        
        self.PlayerLastDrawPos[playerID] = {x = currentX, y = currentY}
        
        local now = CurTime()
        if not self.pendingDraw then
            self.pendingDraw = true
            timer.Simple(self.drawThrottleTime, function()
                if IsValid(self) then
                    self:FlushDrawQueue()
                end
            end)
        end
        
        if #self.drawQueue > 50 then
            self:FlushDrawQueue()
        end
        
        self.dirtyRegions[#self.dirtyRegions + 1] = {
            x = currentX - pointW, 
            y = currentY - pointH, 
            w = pointW * 2, 
            h = pointH * 2
        }
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
end

function ENT:EraseAtPosition(x, y, radius, playerID)
    local radiusSq = radius * radius
    local minCellX = math.floor((x - radius) / self.gridCellSize)
    local maxCellX = math.floor((x + radius) / self.gridCellSize)
    local minCellY = math.floor((y - radius) / self.gridCellSize)
    local maxCellY = math.floor((y + radius) / self.gridCellSize)
    
    local erasedCount = 0
    
    for cellX = minCellX, maxCellX do
        for cellY = minCellY, maxCellY do
            local key = self:GetGridKey(cellX, cellY)
            local cell = self.drawGrid[key]
            if cell then
                for i = #cell, 1, -1 do
                    local point = cell[i]
                    if point and (not playerID or point.playerID == playerID) then
                        local dx = point.x - x
                        local dy = point.y - y
                        if dx * dx + dy * dy <= radiusSq then
                            point.__removed = true
                            table.remove(cell, i)
                            erasedCount = erasedCount + 1
                        end
                    end
                end
                if #cell == 0 then
                    self.drawGrid[key] = nil
                end
            end
        end
    end
    
    if erasedCount > 0 then
        self.dirtyRegions[#self.dirtyRegions + 1] = {
            x = x - radius, 
            y = y - radius, 
            w = radius * 2, 
            h = radius * 2
        }
        self.nextRedraw = 0
    end
end

function ENT:ProcessRedraw()
    if not self.dirtyRegions or #self.dirtyRegions == 0 then return end
    
    local entIndex = self:EntIndex()
    local rtData = self:GetRTData()
    if not rtData or not rtData.rt then return end
    
    local newBuffer = {}
    local hasRemoved = false
    for _, point in ipairs(self.drawPointsBuffer) do
        if not point.__removed then
            table.insert(newBuffer, point)
        else
            hasRemoved = true
        end
    end
    
    if hasRemoved then
        self.drawPointsBuffer = newBuffer
        for plyID, data in pairs(self.PlayerDrawData) do
            local newPlayerData = {}
            for _, point in ipairs(data) do
                if not point.__removed then
                    table.insert(newPlayerData, point)
                end
            end
            self.PlayerDrawData[plyID] = newPlayerData
        end
    end
    
    render.PushRenderTarget(rtData.rt)
    render.Clear(0, 0, 0, 0)
    render.PopRenderTarget()
    
    self:DrawPointsOnRT(self.drawPointsBuffer)
    self:UpdateLittleWhiteboardMaterial()
    
    self.dirtyRegions = {}
end

function ENT:ForceRedraw()
    self.dirtyRegions = { {x = 0, y = 0, w = self.canvasSize, h = self.canvasSize} }
    self.nextRedraw = 0
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
    
    local ply = LocalPlayer()
    if IsValid(ply) then
        local distSq = ply:GetPos():DistToSqr(self:GetPos())
        if distSq > 250000 then
            self.drawThrottleTime = 0.1
        else
            self.drawThrottleTime = 0.016
        end
    end
    
    if CurTime() > (self.nextRedraw or 0) then
        self:ProcessRedraw()
        self.nextRedraw = CurTime() + 0.2
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