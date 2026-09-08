include("shared.lua")

local SCALE_FACTOR = 39.37  -- Перевод из метров в дюймы (Source units)

-- Настройки для RenderTarget
local RT_OFFSET = Vector(0.5, 2.5, 3.5)        -- Смещение RenderTarget холста
local RT_ROTATION = Angle(0, 0, 0)       -- Поворот RenderTarget холста
local RT_SCALE = 1.5                     -- Масштаб RenderTarget холста

-- Размеры RT холста (константы)
local RT_HALF_WIDTH = 55 * RT_SCALE   -- Половина ширины холста
local RT_HALF_HEIGHT = 38 * RT_SCALE   -- Половина высоты холста

-- Настройки барьера
local BARRIER_OFFSET = Vector(-20, 0, 0)     -- Смещение барьера
local BARRIER_ROTATION = Angle(0, 90, 0)    -- Поворот барьера
local BARRIER_SCALE = 1.4                    -- Базовый масштаб барьера

-- НОВЫЕ ПАРАМЕТРЫ ДЛЯ РАСТЯГИВАНИЯ БАРЬЕРА
local BARRIER_SCALE_X = 1.43  -- Масштаб по ширине (X)
local BARRIER_SCALE_Z = 1.01  -- Масштаб по высоте (Z)

-- Флаг для включения/отключения отладки
local DEBUG_MODE = false

-- Цвета для отладки
local RT_DEBUG_COLOR = Color(255, 255, 0, 255)
local BARRIER_DEBUG_COLOR = Color(0, 255, 0, 255)

-- ============================================
-- ИСХОДНЫЕ ПОЛИГОНЫ ИЗ BLENDER
-- ============================================
local OriginalPolygons = {
    {
        { pos = Vector(1.0551, -0.3550, 0.8217) * SCALE_FACTOR, u = 0.0433, v = 0.3901 },
        { pos = Vector(0.8245, -0.3550, 1.0510) * SCALE_FACTOR, u = 0.0000, v = 0.3465 },
        { pos = Vector(0.0690, -0.3550, 1.0510) * SCALE_FACTOR, u = 0.0000, v = 0.2038 },
        { pos = Vector(0.0227, -0.3550, 1.0047) * SCALE_FACTOR, u = 0.0087, v = 0.1951 },
        { pos = Vector(0.0227, -0.3550, 0.8674) * SCALE_FACTOR, u = 0.0347, v = 0.1951 },
        { pos = Vector(-0.0236, -0.3550, 0.8211) * SCALE_FACTOR, u = 0.0434, v = 0.1863 },
        { pos = Vector(-0.8578, -0.3550, 0.8216) * SCALE_FACTOR, u = 0.0433, v = 0.0287 },
        { pos = Vector(-1.0097, -0.3550, 0.6698) * SCALE_FACTOR, u = 0.0720, v = -0.0000 },
        { pos = Vector(-1.0097, -0.3550, 0.0457) * SCALE_FACTOR, u = 0.1899, v = -0.0000 },
        { pos = Vector(-0.9691, -0.3550, 0.0052) * SCALE_FACTOR, u = 0.1976, v = 0.0077 },
        { pos = Vector(-0.9090, -0.3550, 0.0052) * SCALE_FACTOR, u = 0.1976, v = 0.0190 },
        { pos = Vector(-0.8806, -0.3550, -0.0231) * SCALE_FACTOR, u = 0.2029, v = 0.0244 },
        { pos = Vector(-0.8806, -0.3550, -0.8673) * SCALE_FACTOR, u = 0.3624, v = 0.0244 },
        { pos = Vector(-0.8401, -0.3550, -0.9078) * SCALE_FACTOR, u = 0.3701, v = 0.0320 },
        { pos = Vector(0.9260, -0.3550, -0.9078) * SCALE_FACTOR, u = 0.3701, v = 0.3657 },
        { pos = Vector(1.0551, -0.3550, -0.7788) * SCALE_FACTOR, u = 0.3457, v = 0.3901 }
    }
}

-- Вспомогательная функция проверки точки внутри 2D полигона по осям X и Z
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

-- Функция для получения матрицы барьера с учетом растягивания
local function GetBarrierMatrix(ent)
    local mat = Matrix()
    mat:Translate(ent:GetPos())
    mat:Rotate(ent:GetAngles())
    
    mat:Translate(BARRIER_OFFSET)
    if BARRIER_ROTATION.p != 0 or BARRIER_ROTATION.y != 0 or BARRIER_ROTATION.r != 0 then
        mat:Rotate(BARRIER_ROTATION)
    end
    
    -- Применяем масштаб с учетом растягивания по осям
    local scaleX = BARRIER_SCALE * BARRIER_SCALE_X
    local scaleZ = BARRIER_SCALE * BARRIER_SCALE_Z
    mat:Scale(Vector(scaleX, BARRIER_SCALE, scaleZ))
    
    return mat
end

-- Функция для отрисовки 3D линий (рамок)
local function Draw3DLine(startPos, endPos, color)
    render.DrawLine(startPos, endPos, color, true)
end

-- Функция для отрисовки рамки RT холста
function ENT:DrawRTDebug()
    if not DEBUG_MODE then return end
    
    local pos = self:GetPos()
    local ang = self:GetAngles()
    ang:RotateAroundAxis(ang:Up(), 180)
    
    local right = ang:Right()
    local up = ang:Up()
    local forward = ang:Forward()
    
    local rtPos = pos + (right * RT_OFFSET.y) + (up * RT_OFFSET.z) + (forward * RT_OFFSET.x)
    
    if RT_ROTATION.p != 0 or RT_ROTATION.y != 0 or RT_ROTATION.r != 0 then
        local rtAng = ang + RT_ROTATION
        right = rtAng:Right()
        up = rtAng:Up()
        forward = rtAng:Forward()
    end
    
    -- Углы RT холста (используем константы)
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

-- Функция для отрисовки рамки барьера
function ENT:DrawBarrierDebug()
    if not DEBUG_MODE then return end
    
    local mat = GetBarrierMatrix(self)
    
    for _, polygon in ipairs(OriginalPolygons) do
        local worldPoints = {}

        for _, point in ipairs(polygon) do
            local worldPos = mat * point.pos
            table.insert(worldPoints, worldPos)
        end
        
        -- Рисуем контур полигона
        for i = 1, #worldPoints do
            local nextIndex = (i % #worldPoints) + 1
            Draw3DLine(worldPoints[i], worldPoints[nextIndex], BARRIER_DEBUG_COLOR)
        end
    end
end

-- Логический барьер
function ENT:IsPointInInteractiveZone(hitPos)
    if not hitPos then return false end
    
    local mat = GetBarrierMatrix(self)
    local invMat = mat:GetInverse()
    local posInZone = invMat * hitPos

    local checkX = posInZone.x
    local checkZ = posInZone.z

    for _, polygon in ipairs(OriginalPolygons) do
        if IsPointIn2DPolygon(checkX, checkZ, polygon) then
            return true
        end
    end

    return false
end

-- Точный перевод мировой 3D координаты клика в 2D UV-координаты
function ENT:WorldToRTTextureCoords(hitPos)
    local ang = self:GetAngles()
    ang:RotateAroundAxis(ang:Up(), 180)
    
    local right = ang:Right()
    local up = ang:Up()
    local forward = ang:Forward()
    
    local rtPos = self:GetPos() + (right * RT_OFFSET.y) + (up * RT_OFFSET.z) + (forward * RT_OFFSET.x)
    
    if RT_ROTATION.p != 0 or RT_ROTATION.y != 0 or RT_ROTATION.r != 0 then
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
-- 1. ОСНОВНАЯ ЛОГИКА ПУЛА И RT
-- ============================================
TechPanelRTs = TechPanelRTs or {}

local DRAW_DISTANCE = 200
local MAX_DRAW_DISTANCE_SQ = DRAW_DISTANCE * DRAW_DISTANCE
local PANEL_ASPECT = 37.85 / 21.7

local markerMaterial = Material("render/marker_draw_unit")
markerMaterial:SetFloat("$alpha", 1)
markerMaterial:SetInt("$translucent", 1)

TechPanelRTPool = TechPanelRTPool or {
    free = {},
    used = {},
    size = 3,
    format = {
        size = 1024,
        name = "TechPanelRT"
    }
}

function TechPanelRTPool:Initialize()
    if #self.free > 0 then return end
    
    for i = 1, self.size do
        local rt = GetRenderTarget(self.format.name .. "_canvas_" .. i, self.format.size, self.format.size)
        
        local mat = CreateMaterial(self.format.name .. "_mat" .. i, "UnlitGeneric", {
            ["$basetexture"] = rt:GetName(),
            ["$vertexcolor"] = 1,
            ["$vertexalpha"] = 1,
            ["$nocull"]      = 1,
            ["$translucent"] = 1,
            ["$nophys"] = 1
        })
        
        render.PushRenderTarget(rt)
        render.Clear(0, 0, 0, 0)
        render.PopRenderTarget()
        
        table.insert(self.free, {
            rt = rt,
            mat = mat,
            index = i,
            lastUsed = 0
        })
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
-- 2. ИНИЦИАЛИЗАЦИЯ ЭНТИТИ
-- ============================================
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
    self:ForceRedraw()
end

function ENT:ClearWhiteboard()
    self:ClearTechPanel()
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

function ENT:GetRTData()
    local entIndex = self:EntIndex()
    if not TechPanelRTs[entIndex] then
        self:InitializeTechPanel()
    end
    return TechPanelRTs[entIndex]
end

function ENT:GetDrawMaterial()
    return markerMaterial
end

function ENT:LocalToTextureCoords(localPos)
    if not self._texScale then
        local mins, maxs = self:GetTechPanelBounds()
        self._texScaleX = 1 / (maxs.y - mins.y)
        self._texScaleY = 1 / (maxs.z - mins.z)
        self._texOffsetX = -mins.y
        self._texOffsetY = -mins.z
    end
    
    local correctionY = -1.2
    local correctionZ = -1
    local correctedY = localPos.y + correctionY
    local correctedZ = localPos.z + correctionZ
    
    local texCoordX = (correctedY + self._texOffsetX) * self._texScaleX
    local texCoordY = 1 - ((correctedZ + self._texOffsetY) * self._texScaleY)
    
    return math.Clamp(texCoordX, 0, 1), math.Clamp(texCoordY, 0, 1)
end

function ENT:UpdateMaterial()
    self:UpdateTechPanelMaterial()
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
-- 3. ЛОГИКА РИСОВАНИЯ И СТИРАНИЯ
-- ============================================
function ENT:DrawOnBoard(hitPos, color, size, isNewLine, player)
    if not IsValid(self) then return end
    
    local rtData = self:GetRTData()
    if not rtData or not rtData.rt then return end
    
    local texCoordX, texCoordY = self:WorldToRTTextureCoords(hitPos)
    
    local ply = IsValid(player) and player or LocalPlayer()
    if not IsValid(ply) or ply:GetPos():DistToSqr(self:GetPos()) > MAX_DRAW_DISTANCE_SQ then return end
    
    local canvasSize = rtData.size or 1024
    local scaleFactor = 1024 / canvasSize
    
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
        if math.sqrt((currentX - lastPoint.x)^2 + (currentY - lastPoint.y)^2) < 1 then
            isDuplicate = true
        end
    end
    
    if mainPointAllowed and not isDuplicate then
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
        
        self.dirtyRegions[#self.dirtyRegions + 1] = {
            x = currentX - pointW,
            y = currentY - pointH,
            w = pointW * 2,
            h = pointH * 2
        }
    end
    
    -- ИНТЕРПОЛЯЦИЯ ЛИНИИ ПО МИРОВЫМ КООРДИНАТАМ
    local lastPlayerWorldPos = self.PlayerLastWorldPos and self.PlayerLastWorldPos[playerID]
    if lastPlayerWorldPos and not isNewLine then
        local dist = hitPos:Distance(lastPlayerWorldPos)
        if dist > 0.1 then
            local steps = math.max(2, math.floor(dist / (self.interpStep * 0.1)))
            for i = 1, steps - 1 do
                local t = i / steps
                local interpWorldPos = LerpVector(t, lastPlayerWorldPos, hitPos)
                
                if self:IsPointInInteractiveZone(interpWorldPos) then
                    local interpUX, interpUY = self:WorldToRTTextureCoords(interpWorldPos)
                    self.pointCounter = self.pointCounter + 1
                    
                    local linePoint = {
                        x = interpUX * canvasSize,
                        y = interpUY * canvasSize,
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
    end
    
    self.PlayerLastDrawPos[playerID] = {x = currentX, y = currentY}
    self.PlayerLastWorldPos = self.PlayerLastWorldPos or {}
    self.PlayerLastWorldPos[playerID] = hitPos
    
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
end

function ENT:EraseOnBoard(hitPos, size, isNewLine, player)
    if not IsValid(self) then return end
    
    local playerID = self:GetPlayerID(player)
    
    local rtData = self:GetRTData()
    if not rtData or not rtData.rt then return end
    
    local texCoordX, texCoordY = self:WorldToRTTextureCoords(hitPos)
    local canvasSize = rtData.size or 1024
    
    local currentX = texCoordX * canvasSize
    local currentY = texCoordY * canvasSize
    local eraseRadius = (size or 20) / 2
    
    if isNewLine then
        self.LastErasePos = nil
        if self.PlayerLastEraseWorldPos then
            self.PlayerLastEraseWorldPos[playerID] = nil
        end
    end
    
    if self:IsPointInInteractiveZone(hitPos) then
        self:EraseAtPosition(currentX, currentY, eraseRadius, playerID)
    end
    
    -- ИНТЕРПОЛЯЦИЯ СТИРАНИЯ ПО МИРОВЫМ КООРДИНАТАМ
    self.PlayerLastEraseWorldPos = self.PlayerLastEraseWorldPos or {}
    local lastEraseWorldPos = self.PlayerLastEraseWorldPos[playerID]
    
    if lastEraseWorldPos and not isNewLine then
        local dist = hitPos:Distance(lastEraseWorldPos)
        if dist > 0.1 then
            local steps = math.max(2, math.floor(dist / (self.interpStep * 0.1)))
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
    
    for cellX = minCellX, maxCellX do
        for cellY = minCellY, maxCellY do
            local key = self:GetGridKey(cellX, cellY)
            local cell = self.drawGrid[key]
            
            if cell then
                for i = #cell, 1, -1 do
                    local point = cell[i]
                    if point and (not playerID or point.playerID == playerID) then
                        if (point.x - x)^2 + (point.y - y)^2 <= radiusSq then
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

-- ============================================
-- 4. ПЕРЕРИСОВКА И МАТЕРИАЛЫ
-- ============================================
function ENT:ProcessRedraw()
    if not self.dirtyRegions or #self.dirtyRegions == 0 then return end
    
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
    self.dirtyRegions = {}
end

function ENT:ForceRedraw()
    self.dirtyRegions = {
        {x = 0, y = 0, w = self.canvasSize, h = self.canvasSize}
    }
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

-- ============================================
-- 5. НЕОНОВОЕ СВЕЧЕНИЕ
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
        dlight.Brightness = brightness * 0.7
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
        dlight2.Size = distance * 0.4
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
    
    if RT_ROTATION.p != 0 or RT_ROTATION.y != 0 or RT_ROTATION.r != 0 then
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
    if DEBUG_MODE then
        self:DrawRTDebug()
        self:DrawBarrierDebug()
    end
end

function ENT:Think()
    local rtData = self:GetRTData()
    if rtData and rtData.poolData then
        rtData.poolData.lastUsed = CurTime()
    end
    
    if self:GetLightEnabled() then
        local currentColor = self:GetLightColor()
        local currentBrightness = self:GetLightBrightness()
        
        if not self.lastNeonColor or not self.lastNeonBrightness or
           self.lastNeonColor != currentColor or
           self.lastNeonBrightness != currentBrightness then
            self:UpdateNeonColor()
            self.lastNeonColor = currentColor
            self.lastNeonBrightness = currentBrightness
        end
        
        self:CreateNeonLight()
    end
    
    local ply = LocalPlayer()
    if IsValid(ply) then
        if ply:GetPos():DistToSqr(self:GetPos()) > 250000 then
            self.drawThrottleTime = 0.1
        else
            self.drawThrottleTime = 0.016
        end
    end
    
    if CurTime() > (self.nextRedraw or 0) then
        self:ProcessRedraw()
        self.nextRedraw = CurTime() + 0.2
    end
    
    self:NextThink(CurTime() + 0.05)
    return true
end

function ENT:OnRemove()
    TechPanelRTPool:ReleaseBoardRT(self)
    
    local entIndex = self:EntIndex()
    if TechPanelRTs[entIndex] then
        TechPanelRTs[entIndex] = nil
    end
    
    if self.neonSubMaterialIndex and self.neonOriginalMaterial then
        self:SetSubMaterial(self.neonSubMaterialIndex, self.neonOriginalMaterial)
    end
    
    self.neonDynamicMaterial = nil
end

-- ============================================
-- NET-СООБЩЕНИЯ И ХУКИ
-- ============================================
net.Receive("MarkerDraw", function()
    local panel = net.ReadEntity()
    local hitPos = net.ReadVector()
    local color = net.ReadColor()
    local size = net.ReadUInt(8)
    local isNewLine = net.ReadBool()
    local player = net.ReadEntity()
    
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
    
    if IsValid(panel) and panel.EraseOnBoard then
        panel:EraseOnBoard(hitPos, size, isNewLine, player)
    end
end)

net.Receive("TechPanelClear", function()
    local panel = net.ReadEntity()
    if IsValid(panel) and panel.ClearTechPanel then
        panel:ClearTechPanel()
    end
end)

net.Receive("TechPanelClearPlayer", function()
    local panel = net.ReadEntity()
    local player = net.ReadEntity()
    if IsValid(panel) and panel.ClearPlayerDrawings then
        panel:ClearPlayerDrawings(player)
    end
end)

net.Receive("DBPointLimit_RemoveOldest", function()
    local panel = net.ReadEntity()
    if IsValid(panel) and panel.drawPointsBuffer and #panel.drawPointsBuffer > 0 then
        table.remove(panel.drawPointsBuffer, 1)
        panel:ForceRedraw()
    end
end)

hook.Add("KeyRelease", "TechPanelForceRedraw", function(ply, key)
    if key == IN_ATTACK or key == IN_ATTACK2 then
        local tr = ply:GetEyeTrace()
        local ent = tr.Entity
        if IsValid(ent) and (ent:GetClass() == "tech_panel" or ent:GetClass() == "tech_panel_oversized") then
            if ent.ForceRedraw then
                ent:ForceRedraw()
            end
        end
    end
end)