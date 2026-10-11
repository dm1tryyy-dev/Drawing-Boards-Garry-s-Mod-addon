include("shared.lua")

local SCALE_FACTOR = 39.37

local RT_OFFSET = Vector(0.5, 1.5, 2)
local RT_ROTATION = Angle(0, 0, 0)
local RT_SCALE = 1.3

local RT_HALF_WIDTH = 30.5 * RT_SCALE
local RT_HALF_HEIGHT = 20 * RT_SCALE

local BARRIER_OFFSET = Vector(-0.5, 0, 0)
local BARRIER_ROTATION = Angle(0, 90, 0)
local BARRIER_SCALE = 1.0

local DEBUG_MODE = false
local DEBUG_ERASE = false -- включить/выключить отладочные рамки стирания
local ERASE_DEBUG_LIFETIME = 1.5
local RT_DEBUG_COLOR = Color(255, 255, 0, 255)
local BARRIER_DEBUG_COLOR = Color(0, 255, 0, 255)

local OriginalPolygons = {
    {
        { pos = Vector(0.2597, -0.0023, -0.5913) * SCALE_FACTOR, u = 0.9653, v = 0.4608 },
        { pos = Vector(0.2995, -0.0023, -0.5514) * SCALE_FACTOR, u = 0.9503, v = 0.4758 },
        { pos = Vector(0.2995, -0.0023, -0.4888) * SCALE_FACTOR, u = 0.9267, v = 0.4758 },
        { pos = Vector(0.3398, -0.0023, -0.4485) * SCALE_FACTOR, u = 0.9115, v = 0.4910 },
        { pos = Vector(0.9853, -0.0023, -0.4485) * SCALE_FACTOR, u = 0.9115, v = 0.7343 },
        { pos = Vector(1.0216, -0.0023, -0.4122) * SCALE_FACTOR, u = 0.8978, v = 0.7480 },
        { pos = Vector(1.0216, -0.0023, 0.5265) * SCALE_FACTOR, u = 0.5439, v = 0.7480 },
        { pos = Vector(0.9569, -0.0023, 0.5913) * SCALE_FACTOR, u = 0.5195, v = 0.7236 },
        { pos = Vector(0.3386, -0.0023, 0.5913) * SCALE_FACTOR, u = 0.5195, v = 0.4905 },
        { pos = Vector(-0.2521, -0.0023, 0.5913) * SCALE_FACTOR, u = 0.5195, v = 0.2678 },
        { pos = Vector(-0.3071, -0.0023, 0.5913) * SCALE_FACTOR, u = 0.5195, v = 0.2471 },
        { pos = Vector(-0.8979, -0.0023, 0.5913) * SCALE_FACTOR, u = 0.5195, v = 0.0244 },
        { pos = Vector(-0.9626, -0.0023, 0.5265) * SCALE_FACTOR, u = 0.5439, v = -0.0000 },
        { pos = Vector(-0.9626, -0.0023, -0.5265) * SCALE_FACTOR, u = 0.9409, v = 0.0000 },
        { pos = Vector(-0.8979, -0.0023, -0.5913) * SCALE_FACTOR, u = 0.9653, v = 0.0244 },
    },
    {
        { pos = Vector(-0.7997, -0.0023, 0.6890) * SCALE_FACTOR, u = 0.4826, v = 0.0614 },
        { pos = Vector(-0.8979, -0.0023, 0.5913) * SCALE_FACTOR, u = 0.5195, v = 0.0244 },
        { pos = Vector(-0.3071, -0.0023, 0.5913) * SCALE_FACTOR, u = 0.5195, v = 0.2471 },
        { pos = Vector(-0.2796, -0.0023, 0.6188) * SCALE_FACTOR, u = 0.5091, v = 0.2575 },
        { pos = Vector(-0.2796, -0.0023, 0.6637) * SCALE_FACTOR, u = 0.4922, v = 0.2575 },
        { pos = Vector(-0.3050, -0.0023, 0.6890) * SCALE_FACTOR, u = 0.4826, v = 0.2479 },
    },
    {
        { pos = Vector(-0.2521, -0.0023, 0.5913) * SCALE_FACTOR, u = 0.5195, v = 0.2678 },
        { pos = Vector(-0.2796, -0.0023, 0.6188) * SCALE_FACTOR, u = 0.5091, v = 0.2575 },
        { pos = Vector(-0.3071, -0.0023, 0.5913) * SCALE_FACTOR, u = 0.5195, v = 0.2471 },
    },
}

local function IsPointIn2DPolygon(x, z, polygon)
    local inside = false
    local j = #polygon
    for i = 1, #polygon do
        local p1 = polygon[i].pos
        local p2 = polygon[j].pos
        if ((p1.z > z) ~= (p2.z > z)) and
           (x < (p2.x - p1.x) * (z - p1.z) / (p2.z - p1.z) + p1.x) then
            inside = not inside
        end
        j = i
    end
    return inside
end

local function GetBarrierMatrix(ent)
    local mat = Matrix()
    mat:Translate(ent:GetPos())
    mat:Rotate(ent:GetAngles())
    mat:Translate(BARRIER_OFFSET)
    if BARRIER_ROTATION.p ~= 0 or BARRIER_ROTATION.y ~= 0 or BARRIER_ROTATION.r ~= 0 then
        mat:Rotate(BARRIER_ROTATION)
    end
    mat:Scale(Vector(BARRIER_SCALE, BARRIER_SCALE, BARRIER_SCALE))
    return mat
end

local function Draw3DLine(startPos, endPos, color)
    render.DrawLine(startPos, endPos, color, true)
end

function ENT:DrawRTDebug()
    if not DEBUG_MODE then return end
    local pos = self:GetPos()
    local ang = self:GetAngles()
    ang:RotateAroundAxis(ang:Up(), 180)
    local right = ang:Right()
    local up = ang:Up()
    local forward = ang:Forward()
    local rtPos = pos + (right * RT_OFFSET.y) + (up * RT_OFFSET.z) + (forward * RT_OFFSET.x)
    if RT_ROTATION.p ~= 0 or RT_ROTATION.y ~= 0 or RT_ROTATION.r ~= 0 then
        local rtAng = ang + RT_ROTATION
        right = rtAng:Right()
        up = rtAng:Up()
        forward = rtAng:Forward()
    end
    local topLeft = rtPos + (up * RT_HALF_HEIGHT) + (right * (-RT_HALF_WIDTH))
    local topRight = rtPos + (up * RT_HALF_HEIGHT) + (right * RT_HALF_WIDTH)
    local bottomRight = rtPos + (up * (-RT_HALF_HEIGHT)) + (right * RT_HALF_WIDTH)
    local bottomLeft = rtPos + (up * (-RT_HALF_HEIGHT)) + (right * (-RT_HALF_WIDTH))
    Draw3DLine(topLeft, topRight, RT_DEBUG_COLOR)
    Draw3DLine(topRight, bottomRight, RT_DEBUG_COLOR)
    Draw3DLine(bottomRight, bottomLeft, RT_DEBUG_COLOR)
    Draw3DLine(bottomLeft, topLeft, RT_DEBUG_COLOR)
    Draw3DLine(topLeft, bottomRight, Color(RT_DEBUG_COLOR.r, RT_DEBUG_COLOR.g, RT_DEBUG_COLOR.b, 128))
    Draw3DLine(topRight, bottomLeft, Color(RT_DEBUG_COLOR.r, RT_DEBUG_COLOR.g, RT_DEBUG_COLOR.b, 128))
end

function ENT:DrawBarrierDebug()
    if not DEBUG_MODE then return end
    local mat = GetBarrierMatrix(self)
    for _, polygon in ipairs(OriginalPolygons) do
        local worldPoints = {}
        for _, point in ipairs(polygon) do
            table.insert(worldPoints, mat * point.pos)
        end
        for i = 1, #worldPoints do
            local nextIndex = (i % #worldPoints) + 1
            Draw3DLine(worldPoints[i], worldPoints[nextIndex], BARRIER_DEBUG_COLOR)
        end
    end
end

function ENT:IsPointInInteractiveZone(hitPos)
    if not hitPos then return false end
    local mat = GetBarrierMatrix(self)
    local invMat = mat:GetInverse()
    local posInZone = invMat * hitPos
    local checkX = posInZone.x
    local checkZ = posInZone.z
    for _, polygon in ipairs(OriginalPolygons) do
        if IsPointIn2DPolygon(checkX, checkZ, polygon) then return true end
    end
    return false
end

function ENT:WorldToRTTextureCoords(hitPos)
    local ang = self:GetAngles()
    ang:RotateAroundAxis(ang:Up(), 180)
    local right = ang:Right()
    local up = ang:Up()
    local forward = ang:Forward()
    local rtPos = self:GetPos() + (right * RT_OFFSET.y) + (up * RT_OFFSET.z) + (forward * RT_OFFSET.x)
    if RT_ROTATION.p ~= 0 or RT_ROTATION.y ~= 0 or RT_ROTATION.r ~= 0 then
        local rtAng = ang + RT_ROTATION
        right = rtAng:Right()
        up = rtAng:Up()
        forward = rtAng:Forward()
    end
    local diff = hitPos - rtPos
    local localX = diff:Dot(right)
    local localY = diff:Dot(up)
    local u = (localX / RT_HALF_WIDTH + 1) / 2
    local v = 1 - ((localY / RT_HALF_HEIGHT + 1) / 2)
    return math.Clamp(u, 0, 1), math.Clamp(v, 0, 1)
end

-- ============================================
-- 1. ПУЛ RT
-- ============================================
TechPanelRTs = TechPanelRTs or {}
local DRAW_DISTANCE = 200
local MAX_DRAW_DISTANCE_SQ = DRAW_DISTANCE * DRAW_DISTANCE
local PANEL_ASPECT = 37.85 / 21.7

local markerMaterial = Material("render/marker_draw_unit")
markerMaterial:SetFloat("$alpha", 1)
markerMaterial:SetInt("$translucent", 1)

TechPanelRTPool = TechPanelRTPool or {
    free = {}, used = {}, size = 5,
    format = { size = 1024, name = "TechPanelRT" }
}

function TechPanelRTPool:Initialize()
    if #self.free > 0 then return end

    local quality = GetConVarNumber("db_opt_render_qlt")
    if quality == 1 then
        self.format.size = 512
    else
        self.format.size = 1024
    end

    for i = 1, self.size do
        local rt = GetRenderTarget(self.format.name .. "_canvas_" .. i, self.format.size, self.format.size)
        local mat = CreateMaterial(self.format.name .. "_mat" .. i, "UnlitGeneric", {
            ["$basetexture"] = rt:GetName(),
            ["$vertexcolor"] = 1,
            ["$vertexalpha"] = 1,
            ["$nocull"]      = 1,
            ["$translucent"] = 1,
            ["$nophys"] = 1,
            ["$linear"] = 1
        })
        render.PushRenderTarget(rt)
        render.Clear(0, 0, 0, 0)
        render.PopRenderTarget()
        table.insert(self.free, { rt = rt, mat = mat, index = i, lastUsed = 0 })
    end
end

function TechPanelRTPool:GetBoardRT(ent)
    if not IsValid(ent) then return nil end
    local entIndex = ent:EntIndex()
    if self.used[entIndex] then return self.used[entIndex] end
    if #self.free > 0 then
        local rtData = table.remove(self.free, 1)
        self.used[entIndex] = rtData
        rtData.lastUsed = CurTime()
        return rtData
    end
    local oldestTime = CurTime()
    local oldestEnt, oldestRT
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

function TechPanelRTPool:ReleaseBoardRT(ent)
    if not IsValid(ent) then return end
    local entIndex = ent:EntIndex()
    if self.used[entIndex] then
        local rtData = self.used[entIndex]
        self.used[entIndex] = nil
        table.insert(self.free, rtData)
    end
end

TechPanelRTPool:Initialize()

-- ============================================
-- 2. ИНИЦИАЛИЗАЦИЯ
-- ============================================
function ENT:Initialize()
    self.canvasSize = 1024
    self.interpStep = 3
    self.redrawDelay = 0.05

    local quality = GetConVarNumber("db_opt_render_qlt")
    if quality == 1 then
        self.canvasSize = 512
        self.interpStep = 3
        self.redrawDelay = 0.05
    end

    self.PlayerDrawData = {}
    self.PlayerColors = {}
    self.PlayerLastDrawPos = {}
    self.drawPointsBuffer = {}
    self.drawGrid = {}
    self.gridCellSize = math.max(16, math.floor(self.canvasSize / 16))
    self.nextRedraw = 0
    self.drawQueue = {}
    self.drawThrottleTime = 0.016
    self.pendingDraw = false
    self.LastErasePos = nil
    self.pointCounter = 0

    self._needsFullRedraw = false
    self._lastEraseRedraw = 0

    self._bufferDirty = false
    self._lastCompact = 0

    self._debugEraseRects = {}

    self:InitializeTechPanel()
    self:InitializeNeonMaterial()
end

function ENT:InitializeTechPanel()
    local rtData = TechPanelRTPool:GetBoardRT(self)
    if not rtData then return end
    local entIndex = self:EntIndex()
    TechPanelRTs[entIndex] = TechPanelRTs[entIndex] or {}
    TechPanelRTs[entIndex].rt = rtData.rt
    TechPanelRTs[entIndex].mat = rtData.mat
    TechPanelRTs[entIndex].size = self.canvasSize
    TechPanelRTs[entIndex].poolData = rtData

    render.PushRenderTarget(rtData.rt)
    render.Clear(0, 0, 0, 0)
    render.PopRenderTarget()

    self:UpdateTechPanelMaterial()

    if #self.drawPointsBuffer > 0 then
        self:DrawPointsOnRT(self.drawPointsBuffer)
    end
end

function ENT:GetPlayerID(player)
    if not IsValid(player) then return "default" end
    return player:SteamID() or "player_" .. tostring(player:UserID())
end

function ENT:ClearTechPanel()
    self._loadingSave = false
    self._cancelLoad = true
    self.PlayerDrawData = {}
    self.PlayerColors = {}
    self.PlayerLastDrawPos = {}
    self.drawPointsBuffer = {}
    self.drawGrid = {}
    self.drawQueue = {}
    self.pointCounter = 0
    self.LastErasePos = nil

    local rtData = self:GetRTData()
    if rtData and rtData.rt then
        render.PushRenderTarget(rtData.rt)
        render.Clear(0, 0, 0, 0)
        render.PopRenderTarget()
    end
    self._needsFullRedraw = false
end

function ENT:ClearWhiteboard() self:ClearTechPanel() end

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

function ENT:GetRTData()
    local entIndex = self:EntIndex()
    if not TechPanelRTs[entIndex] then self:InitializeTechPanel() end
    return TechPanelRTs[entIndex]
end

function ENT:GetDrawMaterial() return markerMaterial end

function ENT:LocalToTextureCoords(localPos)
    if not self._texScale then
        local mins, maxs = self:GetTechPanelBounds()
        self._texScaleX = 1 / (maxs.y - mins.y)
        self._texScaleY = 1 / (maxs.z - mins.z)
        self._texOffsetX = -mins.y
        self._texOffsetY = -mins.z
    end
    local correctedY = localPos.y - 1.2
    local correctedZ = localPos.z - 1
    local texCoordX = (correctedY + self._texOffsetX) * self._texScaleX
    local texCoordY = 1 - ((correctedZ + self._texOffsetY) * self._texScaleY)
    return math.Clamp(texCoordX, 0, 1), math.Clamp(texCoordY, 0, 1)
end

function ENT:UpdateMaterial() self:UpdateTechPanelMaterial() end

function ENT:GetGridKey(cellX, cellY) return cellX .. "_" .. cellY end

function ENT:AddPointToGrid(point)
    local cellX = math.floor(point.x / self.gridCellSize)
    local cellY = math.floor(point.y / self.gridCellSize)
    local key = self:GetGridKey(cellX, cellY)
    self.drawGrid[key] = self.drawGrid[key] or {}
    point.__gridCell = key
    table.insert(self.drawGrid[key], point)
end

function ENT:DrawPointsOnRT(points)
    local rtData = self:GetRTData()
    if not rtData or not rtData.rt then return end

    render.PushRenderTarget(rtData.rt)
    render.OverrideAlphaWriteEnable(true, true)
    cam.Start2D()
    surface.SetMaterial(self:GetDrawMaterial())

    for _, point in ipairs(points) do
        if not point.__removed then
            surface.SetDrawColor(point.color.r, point.color.g, point.color.b, 255)
            surface.DrawTexturedRect(
                math.Round(point.x - point.w / 2),
                math.Round(point.y - point.h / 2),
                point.w, point.h
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

function ENT:RemoveOldestPoint()
    if not self.drawPointsBuffer then return end
    local oldest = table.remove(self.drawPointsBuffer, 1)
    if not oldest then return end
    oldest.__removed = true
    local playerPoints = self.PlayerDrawData[oldest.playerID]
    if playerPoints then
        for k, v in ipairs(playerPoints) do
            if v == oldest then
                table.remove(playerPoints, k)
                break
            end
        end
    end
    self:ForceRedraw()
end

-- ============================================
-- 3. РИСОВАНИЕ
-- ============================================
function ENT:DrawOnBoard(hitPos, color, size, isNewLine, player)
    if not IsValid(self) then return end
    local rtData = self:GetRTData()
    if not rtData or not rtData.rt then return end

    local texCoordX, texCoordY = self:WorldToRTTextureCoords(hitPos)
    local ply = IsValid(player) and player or LocalPlayer()
    if not IsValid(ply) or ply:GetPos():DistToSqr(self:GetPos()) > MAX_DRAW_DISTANCE_SQ then return end

    local canvasSize = rtData.size or 1024
    local scaleFactor = canvasSize / 1024
    local currentX = texCoordX * canvasSize
    local currentY = texCoordY * canvasSize
    local baseSize = (size or 8) * scaleFactor
    local pointW = baseSize
    local pointH = baseSize * PANEL_ASPECT

    local playerID = self:GetPlayerID(player)
    if not self.PlayerDrawData[playerID] then self.PlayerDrawData[playerID] = {} end
    self.PlayerColors[playerID] = color

    local mainPointAllowed = self:IsPointInInteractiveZone(hitPos)

    local isDuplicate = false
    local lastPoint = self.PlayerDrawData[playerID][#self.PlayerDrawData[playerID]]
    if lastPoint and not isNewLine then
        local dupThreshold = math.max(0.5, 1 * scaleFactor)
        if math.sqrt((currentX - lastPoint.x)^2 + (currentY - lastPoint.y)^2) < dupThreshold then
            isDuplicate = true
        end
    end

    if mainPointAllowed and not isDuplicate then
        self.pointCounter = self.pointCounter + 1
        local newPoint = {
            x = currentX, y = currentY,
            color = Color(color.r, color.g, color.b),
            w = pointW, h = pointH,
            playerID = playerID,
            timestamp = CurTime(),
            __removed = false,
            __order = self.pointCounter
        }
        if DB_LIMIT_ENABLED then
            local maxPoints = math.max(DB_LIMIT_MAX, 1)
            while #self.drawPointsBuffer >= maxPoints do
                self:RemoveOldestPoint()
            end
        end
        self:AddPointToGrid(newPoint)
        table.insert(self.drawPointsBuffer, newPoint)
        table.insert(self.PlayerDrawData[playerID], newPoint)
        self.drawQueue = self.drawQueue or {}
        table.insert(self.drawQueue, newPoint)
    end

    local lastPlayerWorldPos = self.PlayerLastWorldPos and self.PlayerLastWorldPos[playerID]
    if lastPlayerWorldPos and not isNewLine then
        local dist = hitPos:Distance(lastPlayerWorldPos)
        if dist > 0.1 then
            local interpStep = math.max(0.05, self.interpStep * 0.1 * scaleFactor)
            local steps = math.max(2, math.floor(dist / interpStep))
            for i = 1, steps - 1 do
                local t = i / steps
                local interpWorldPos = LerpVector(t, lastPlayerWorldPos, hitPos)
                if self:IsPointInInteractiveZone(interpWorldPos) then
                    local interpUX, interpUY = self:WorldToRTTextureCoords(interpWorldPos)
                    self.pointCounter = self.pointCounter + 1
                    local linePoint = {
                        x = interpUX * canvasSize, y = interpUY * canvasSize,
                        color = Color(color.r, color.g, color.b),
                        w = pointW, h = pointH,
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
    end

    self.PlayerLastDrawPos[playerID] = {x = currentX, y = currentY}
    self.PlayerLastWorldPos = self.PlayerLastWorldPos or {}
    self.PlayerLastWorldPos[playerID] = hitPos

    if not self.pendingDraw then
        self.pendingDraw = true
        timer.Simple(self.drawThrottleTime, function()
            if IsValid(self) then self:FlushDrawQueue() end
        end)
    end
    if #self.drawQueue > 50 then self:FlushDrawQueue() end
end

-- ============================================
-- 4. СТИРАНИЕ
-- ============================================
function ENT:EraseOnRT(x, y, radius)
    local rtData = self:GetRTData()
    if not rtData or not rtData.rt then return end

    -- Квадрат на доске с компенсацией PANEL_ASPECT.
    -- RT растягивается на доску неравномерно, поэтому по X/Y разные стороны.
    local sideW = math.max(1, math.floor(radius * 2 + 0.5))
    local sideH = math.max(1, math.floor(sideW * PANEL_ASPECT + 0.5))

    local halfW = sideW * 0.5
    local halfH = sideH * 0.5

    local minX = math.max(0, math.floor(x - halfW))
    local minY = math.max(0, math.floor(y - halfH))
    local maxX = math.min(self.canvasSize, minX + sideW)
    local maxY = math.min(self.canvasSize, minY + sideH)

    if maxX - minX < sideW then minX = math.max(0, maxX - sideW) end
    if maxY - minY < sideH then minY = math.max(0, maxY - sideH) end

    if maxX <= minX or maxY <= minY then return end

    if DEBUG_ERASE then
        if not self._debugEraseRects then self._debugEraseRects = {} end
        table.insert(self._debugEraseRects, {
            minX = minX, minY = minY, maxX = maxX, maxY = maxY,
            time = CurTime()
        })
    end

    render.PushRenderTarget(rtData.rt)
    render.OverrideAlphaWriteEnable(true, true)
    cam.Start2D()

    render.SetScissorRect(minX, minY, maxX, maxY, true)
    render.Clear(0, 0, 0, 0)
    render.SetScissorRect(0, 0, 0, 0, false)

    cam.End2D()
    render.OverrideAlphaWriteEnable(false)
    render.PopRenderTarget()
end

function ENT:EraseOnBoard(hitPos, size, isNewLine, player)
    if not IsValid(self) then return end
    local playerID = self:GetPlayerID(player)
    local rtData = self:GetRTData()
    if not rtData or not rtData.rt then return end

    local texCoordX, texCoordY = self:WorldToRTTextureCoords(hitPos)
    local canvasSize = rtData.size or 1024
    local scaleFactor = canvasSize / 1024
    local currentX = texCoordX * canvasSize
    local currentY = texCoordY * canvasSize
    -- Уменьшаем размер квадрата стирания в 1.5 раза
    local eraseRadius = (size or 20) / 2 * scaleFactor / 1.5

    if isNewLine then
        self.LastErasePos = nil
        if self.PlayerLastEraseWorldPos then self.PlayerLastEraseWorldPos[playerID] = nil end
    end

    if self:IsPointInInteractiveZone(hitPos) then
        self:EraseAtPosition(currentX, currentY, eraseRadius, playerID)
    end

    self.PlayerLastEraseWorldPos = self.PlayerLastEraseWorldPos or {}
    local lastEraseWorldPos = self.PlayerLastEraseWorldPos[playerID]

    if lastEraseWorldPos and not isNewLine then
        local dist = hitPos:Distance(lastEraseWorldPos)
        if dist > 0.1 then
            local interpStep = math.max(0.05, self.interpStep * 0.1 * scaleFactor)
            local steps = math.max(2, math.floor(dist / interpStep))
            for i = 1, steps - 1 do
                local t = i / steps
                local interpWorldPos = LerpVector(t, lastEraseWorldPos, hitPos)
                if self:IsPointInInteractiveZone(interpWorldPos) then
                    local interpUX, interpUY = self:WorldToRTTextureCoords(interpWorldPos)
                    self:EraseAtPosition(interpUX * canvasSize, interpUY * canvasSize, eraseRadius, playerID)
                end
            end
        end
    end

    self.LastErasePos = {x = currentX, y = currentY}
    self.PlayerLastEraseWorldPos[playerID] = hitPos
end

function ENT:EraseAtPosition(x, y, radius, playerID)
    local radiusSq = radius * radius
    local minCellX = math.floor((x - radius) / self.gridCellSize)
    local maxCellX = math.floor((x + radius) / self.gridCellSize)
    local minCellY = math.floor((y - radius) / self.gridCellSize)
    local maxCellY = math.floor((y + radius) / self.gridCellSize)

    local erasedCount = 0

    -- Проход 1: центр точки в радиусе
    for cellX = minCellX, maxCellX do
        for cellY = minCellY, maxCellY do
            local key = self:GetGridKey(cellX, cellY)
            local cell = self.drawGrid[key]
            if cell then
                for i = #cell, 1, -1 do
                    local point = cell[i]
                    if point then
                        local dx = point.x - x
                        local dy = point.y - y
                        if dx * dx + dy * dy <= radiusSq then
                            point.__removed = true
                            table.remove(cell, i)
                            erasedCount = erasedCount + 1
                        end
                    end
                end
                if #cell == 0 then self.drawGrid[key] = nil end
            end
        end
    end

    -- Вычисляем ровно те же границы, что и в EraseOnRT (с компенсацией ASPECT)
    local sideW = math.max(1, math.floor(radius * 2 + 0.5))
    local sideH = math.max(1, math.floor(sideW * PANEL_ASPECT + 0.5))
    local halfW = sideW * 0.5
    local halfH = sideH * 0.5

    local padMinX = x - halfW
    local padMaxX = x + halfW
    local padMinY = y - halfH
    local padMaxY = y + halfH

    local padMinCellX = math.floor(padMinX / self.gridCellSize)
    local padMaxCellX = math.floor(padMaxX / self.gridCellSize)
    local padMinCellY = math.floor(padMinY / self.gridCellSize)
    local padMaxCellY = math.floor(padMaxY / self.gridCellSize)

    -- Проход 2: помечаем как удалённые точки, чьи ПИКСЕЛИ попали в зону затирания
    for cellX = padMinCellX, padMaxCellX do
        for cellY = padMinCellY, padMaxCellY do
            local key = self:GetGridKey(cellX, cellY)
            local cell = self.drawGrid[key]
            if cell then
                for i = #cell, 1, -1 do
                    local point = cell[i]
                    if point and not point.__removed then
                        local halfW2 = (point.w or 8) * 0.5
                        local halfH2 = (point.h or 8) * 0.5
                        local pMinX = point.x - halfW2
                        local pMaxX = point.x + halfW2
                        local pMinY = point.y - halfH2
                        local pMaxY = point.y + halfH2

                        if pMaxX >= padMinX and pMinX <= padMaxX
                           and pMaxY >= padMinY and pMinY <= padMaxY then
                            point.__removed = true
                            table.remove(cell, i)
                            erasedCount = erasedCount + 1
                        end
                    end
                end
                if #cell == 0 then self.drawGrid[key] = nil end
            end
        end
    end

    -- Затираем область на RT с теми же границами
    self:EraseOnRT(x, y, radius)

    if erasedCount > 0 then
        self._bufferDirty = true
    end
end

function ENT:CompactBuffersIfNeeded()
    if not self._bufferDirty then return end
    self._bufferDirty = false

    local newBuffer = {}
    for _, point in ipairs(self.drawPointsBuffer) do
        if not point.__removed then
            table.insert(newBuffer, point)
        end
    end
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

-- ============================================
-- 5. ПЕРЕРИСОВКА
-- ============================================
function ENT:ProcessRedraw()
    if not self._needsFullRedraw then return end
    self._needsFullRedraw = false

    local rtData = self:GetRTData()
    if not rtData or not rtData.rt then return end

    self:CompactBuffersIfNeeded()

    render.PushRenderTarget(rtData.rt)
    render.Clear(0, 0, 0, 0)
    render.PopRenderTarget()

    self:DrawPointsOnRT(self.drawPointsBuffer)
end

function ENT:ForceRedraw()
    self._needsFullRedraw = true
    self._bufferDirty = true
    self.nextRedraw = 0
end

function ENT:ForceFullRedraw()
    self:ForceRedraw()
    self:UpdateTechPanelMaterial()
end

function ENT:UpdateTechPanelMaterial()
    local rtData = self:GetRTData()
    if not rtData or not rtData.mat or not rtData.rt then return end
    local mat = rtData.mat
    mat:SetInt("$notint", 1)
    mat:SetInt("$physprop", 0)
    mat:SetTexture("$basetexture", rtData.rt)
    mat:Recompute()
end

-- Переводит RT-координаты в мировые координаты доски
function ENT:RTToWorld(rtX, rtY)
    local ang = self:GetAngles()
    ang:RotateAroundAxis(ang:Up(), 180)
    local right = ang:Right()
    local up = ang:Up()
    local forward = ang:Forward()
    local rtPos = self:GetPos() + (right * RT_OFFSET.y) + (up * RT_OFFSET.z) + (forward * RT_OFFSET.x)
    if RT_ROTATION.p ~= 0 or RT_ROTATION.y ~= 0 or RT_ROTATION.r ~= 0 then
        local rtAng = ang + RT_ROTATION
        right = rtAng:Right()
        up = rtAng:Up()
        forward = rtAng:Forward()
    end

    local u = rtX / self.canvasSize
    local v = rtY / self.canvasSize

    local worldTopLeft = rtPos + up * RT_HALF_HEIGHT + right * (-RT_HALF_WIDTH)
    local worldXdir = right * (RT_HALF_WIDTH * 2)
    local worldYdir = up * (-RT_HALF_HEIGHT * 2)

    return worldTopLeft + worldXdir * u + worldYdir * v
end

function ENT:DrawEraseDebug()
    if not DEBUG_ERASE then return end
    if not self._debugEraseRects then
        self._debugEraseRects = {}
        return
    end

    local now = CurTime()

    for i = #self._debugEraseRects, 1, -1 do
        local rect = self._debugEraseRects[i]
        if now - rect.time > ERASE_DEBUG_LIFETIME then
            table.remove(self._debugEraseRects, i)
        end
    end

    if #self._debugEraseRects == 0 then return end

    for _, rect in ipairs(self._debugEraseRects) do
        local age = now - rect.time
        local alpha = math.Clamp(255 * (1 - age / ERASE_DEBUG_LIFETIME), 0, 255)

        local tl = self:RTToWorld(rect.minX, rect.minY)
        local tr = self:RTToWorld(rect.maxX, rect.minY)
        local br = self:RTToWorld(rect.maxX, rect.maxY)
        local bl = self:RTToWorld(rect.minX, rect.maxY)

        local col = Color(255, 0, 0, alpha)
        render.DrawLine(tl, tr, col, true)
        render.DrawLine(tr, br, col, true)
        render.DrawLine(br, bl, col, true)
        render.DrawLine(bl, tl, col, true)
    end
end

-- ============================================
-- 6. НЕОН
-- ============================================
function ENT:InitializeNeonMaterial()
    local subMaterials = self:GetMaterials()
    self.neonVMT = "models/board_materials/tech_panel/neon"
    self.neonDynamicMaterial = CreateMaterial("TechPanelNeon_" .. self:EntIndex(), "UnlitGeneric", {
        ["$selfillum"] = 1,
        ["$selfillumtint"] = "[1 1 1]",
        ["$color"] = "[1 1 1]",
        ["$surfaceprop"] = "glass",
        ["$model"] = 1,
        ["$nocull"] = 1
    })
    for i, matName in ipairs(subMaterials) do
        if string.find(string.lower(matName), "neon") or
           string.find(string.lower(matName), "screen") or
           string.find(string.lower(matName), "panel") or
           string.find(string.lower(matName), "light") then
            self.neonSubMaterialIndex = i - 1
            self.neonOriginalMaterial = matName
        end
    end
    if not self.neonSubMaterialIndex then
        for i, matName in ipairs(subMaterials) do
            if matName == self.neonVMT then
                self.neonSubMaterialIndex = i - 1
                self.neonOriginalMaterial = matName
                break
            end
        end
    end
    self:UpdateNeonColor()
end

function ENT:UpdateNeonColor()
    if not self.neonDynamicMaterial then return end
    local lightColor = self:GetLightColor()
    local brightness = self:GetLightBrightness()
    local r = math.Clamp(lightColor.x / 255, 0, 1)
    local g = math.Clamp(lightColor.y / 255, 0, 1)
    local b = math.Clamp(lightColor.z / 255, 0, 1)
    local intensity = math.Clamp(brightness / 5, 0.1, 3)
    r = math.Clamp(r * intensity, 0, 1)
    g = math.Clamp(g * intensity, 0, 1)
    b = math.Clamp(b * intensity, 0, 1)
    self.neonDynamicMaterial:SetVector("$selfillumtint", Vector(r, g, b))
    self.neonDynamicMaterial:SetVector("$color", Vector(r, g, b))
    self.neonDynamicMaterial:Recompute()
    if self.neonSubMaterialIndex then
        self:SetSubMaterial(self.neonSubMaterialIndex, self.neonDynamicMaterial:GetName())
    end
    self:SetColor(Color(lightColor.x, lightColor.y, lightColor.z, 255))
end

function ENT:CreateNeonLight()
    if not self:GetLightEnabled() then return end
    local lightColor = self:GetLightColor()
    local brightness = self:GetLightBrightness()
    local distance = self:GetLightDistance()
    local lightPos = self:GetPos() + self:GetForward() * 10

    local dlight = DynamicLight(self:EntIndex())
    if dlight then
        dlight.Pos = lightPos
        dlight.r = lightColor.x
        dlight.g = lightColor.y
        dlight.b = lightColor.z
        dlight.Brightness = brightness * 0.5
        dlight.Size = distance
        dlight.Decay = 500
        dlight.DieTime = CurTime() + 0.1
    end
    local dlight2 = DynamicLight(self:EntIndex() + 500)
    if dlight2 then
        dlight2.Pos = lightPos + self:GetForward() * 5
        dlight2.r = lightColor.x * 0.7
        dlight2.g = lightColor.y * 0.7
        dlight2.b = lightColor.z * 0.7
        dlight2.Brightness = brightness * 0.3
        dlight2.Size = distance * 0.6
        dlight2.Decay = 300
        dlight2.DieTime = CurTime() + 0.1
    end
end

function ENT:DrawTechPanel()
    if g_HaloRendering then return end
    local rtData = self:GetRTData()
    if not rtData or not rtData.rt then return end
    local mat = rtData.mat
    if not mat then return end

    local pos = self:GetPos()
    local ang = self:GetAngles()
    ang:RotateAroundAxis(ang:Up(), 180)
    local right = ang:Right()
    local up = ang:Up()
    local forward = ang:Forward()
    local rtPos = pos + (right * RT_OFFSET.y) + (up * RT_OFFSET.z) + (forward * RT_OFFSET.x)
    if RT_ROTATION.p ~= 0 or RT_ROTATION.y ~= 0 or RT_ROTATION.r ~= 0 then
        local rtAng = ang + RT_ROTATION
        right = rtAng:Right()
        up = rtAng:Up()
        forward = rtAng:Forward()
    end

    render.SetBlend(1)
    render.SetColorModulation(1, 1, 1)
    render.SetMaterial(mat)

    local topLeft = rtPos + (up * RT_HALF_HEIGHT) + (right * (-RT_HALF_WIDTH))
    local topRight = rtPos + (up * RT_HALF_HEIGHT) + (right * RT_HALF_WIDTH)
    local bottomRight = rtPos + (up * (-RT_HALF_HEIGHT)) + (right * RT_HALF_WIDTH)
    local bottomLeft = rtPos + (up * (-RT_HALF_HEIGHT)) + (right * (-RT_HALF_WIDTH))

    render.DrawQuad(topLeft, topRight, bottomRight, bottomLeft, Color(255, 255, 255, 255))
end

function ENT:Draw()
    self:DrawModel()
    if self:GetPos():DistToSqr(LocalPlayer():GetPos()) > 1000000 then return end
    self:DrawTechPanel()
    self:DrawEraseDebug()
    if DEBUG_MODE then
        self:DrawRTDebug()
        self:DrawBarrierDebug()
    end
end

function ENT:Think()
    if self._needsFullRedraw == nil then self._needsFullRedraw = false end
    if self._lastEraseRedraw == nil then self._lastEraseRedraw = 0 end
    if self._bufferDirty == nil then self._bufferDirty = false end
    if self._lastCompact == nil then self._lastCompact = 0 end

    local rtData = self:GetRTData()
    if rtData and rtData.poolData then
        rtData.poolData.lastUsed = CurTime()
    end

    if self:GetLightEnabled() then
        local currentColor = self:GetLightColor()
        local currentBrightness = self:GetLightBrightness()
        if not self.lastNeonColor or not self.lastNeonBrightness or
           self.lastNeonColor ~= currentColor or
           self.lastNeonBrightness ~= currentBrightness then
            self:UpdateNeonColor()
            self.lastNeonColor = currentColor
            self.lastNeonBrightness = currentBrightness
        end
        self:CreateNeonLight()
    end

    local ply = LocalPlayer()
    if IsValid(ply) then
        local distSq = ply:GetPos():DistToSqr(self:GetPos())
        if distSq > 250000 then
            self.drawThrottleTime = 0.2
        elseif distSq > 45000 and distSq < 100000 then
            self.drawThrottleTime = 0.1
        else
            self.drawThrottleTime = 0.016
        end
    end

    if self._needsFullRedraw then
        if CurTime() - (self._lastEraseRedraw or 0) >= 0.05 then
            self:ProcessRedraw()
            self._lastEraseRedraw = CurTime()
        end
    end

    if self._bufferDirty and CurTime() - (self._lastCompact or 0) > 1.0 then
        self:CompactBuffersIfNeeded()
        self._lastCompact = CurTime()
    end

    self:NextThink(CurTime() + 0.05)
    return true
end

function ENT:OnRemove()
    TechPanelRTPool:ReleaseBoardRT(self)
    local entIndex = self:EntIndex()
    if TechPanelRTs[entIndex] then TechPanelRTs[entIndex] = nil end
    if self.neonSubMaterialIndex and self.neonOriginalMaterial then
        self:SetSubMaterial(self.neonSubMaterialIndex, self.neonOriginalMaterial)
    end
    self.neonDynamicMaterial = nil
end

-- ============================================
-- NET
-- ============================================
net.Receive("MarkerDraw", function()
    local panel = net.ReadEntity()
    local hitPos = net.ReadVector()
    local color = net.ReadColor()
    local size = net.ReadUInt(8)
    local isNewLine = net.ReadBool()
    local player = net.ReadEntity()

    if player == LocalPlayer() then return end

    if IsValid(panel) and panel.DrawOnBoard then
        panel:DrawOnBoard(hitPos, color, size, isNewLine, player)
    end
end)

net.Receive("MarkerErase", function()
    local panel = net.ReadEntity()
    local hitPos = net.ReadVector()
    local size = net.ReadUInt(8)
    local isNewLine = net.ReadBool()
    local player = net.ReadEntity()

    if player == LocalPlayer() then return end

    if IsValid(panel) and panel.EraseOnBoard then
        panel:EraseOnBoard(hitPos, size, isNewLine, player)
    end
end)

net.Receive("TechPanelClear", function()
    local panel = net.ReadEntity()
    if IsValid(panel) and panel.ClearTechPanel then panel:ClearTechPanel() end
end)

net.Receive("TechPanelClearPlayer", function()
    local panel = net.ReadEntity()
    local player = net.ReadEntity()
    if IsValid(panel) and panel.ClearPlayerDrawings then panel:ClearPlayerDrawings(player) end
end)

net.Receive("DBPointLimit_RemoveOldest", function()
    local panel = net.ReadEntity()
    if IsValid(panel) and panel.drawPointsBuffer and #panel.drawPointsBuffer > 0 then
        table.remove(panel.drawPointsBuffer, 1)
        panel:ForceRedraw()
    end
end)