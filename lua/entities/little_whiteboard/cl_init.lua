include("shared.lua")

-- Используем ту же таблицу что и для whiteboard, но с другим префиксом
littleWhiteboardRTs = littleWhiteboardRTs or {}

local math_sqrt = math.sqrt
local math_max = math.max
local math_min = math.min
local math_floor = math.floor
local math_Clamp = math.Clamp
local math_cos = math.cos
local math_sin = math.sin
local math_pi = math.pi
local math_abs = math.abs

local circleCache8 = {}
local circleCache12 = {}
local circleCache16 = {}

local function GetCachedCircle(radius, segments)
    local cache
    if segments == 8 then cache = circleCache8
    elseif segments == 12 then cache = circleCache12
    else cache = circleCache16 end
    
    local key = radius
    if not cache[key] then
        local poly = {}
        local segmentAngle = (2 * math_pi) / segments
        for i = 0, segments do
            local angle = i * segmentAngle
            poly[#poly + 1] = {x = math_cos(angle) * radius, y = math_sin(angle) * radius}
        end
        cache[key] = poly
    end
    return cache[key]
end

function ENT:Initialize()
    self:InitializeLittleWhiteboard()
    
    -- ТАБЛИЦЫ ДЛЯ РАЗДЕЛЕНИЯ ДАННЫХ ИГРОКОВ
    self.PlayerDrawData = {}     -- Точки каждого игрока {playerID: {points}}
    self.PlayerColors = {}       -- Цвета каждого игрока {playerID: color}
    self.PlayerLastDrawPos = {}  -- Последние позиции каждого игрока
    
    -- ЕДИНСТВЕННЫЙ БУФЕР ДЛЯ ТОЧЕК
    self.drawPointsBuffer = {}   -- Все точки для отрисовки
    
    -- Настройки частоты
    self.lastImmediateRedraw = 0
    self.lastFullRedraw = 0
    self.fullRedrawScheduled = false
    self.immediateRedrawRate = 0.05 -- 20 FPS
    self.fullRedrawRate = 0.3       -- 3.3 FPS
    
    self.DebugEnabled = false
    self.DebugPoint = nil
    self.DebugText = ""
    
    self:ShowLoadingNotification()
end

function ENT:ShowLoadingNotification()
    if not IsValid(self) then return end
    
    if IsValid(LocalPlayer()) then
        chat.AddText(Color(255, 255, 0), "[Little Whiteboard] ", Color(255, 255, 255), "Board rendering is loading... This may take up to 40 seconds (but can load immediately in some cases).")
        notification.AddLegacy("Little whiteboard rendering is loading... This may take up to 40 seconds (but can load immediately in some cases).", NOTIFY_GENERIC, 5)
    end
    timer.Simple(20, function()
        if IsValid(self) and IsValid(LocalPlayer()) then
            chat.AddText(Color(255, 255, 0), "[Little Whiteboard] ", Color(255, 255, 255), "Board is still loading... Please wait. (If the board has loaded, ignore the message)")
            notification.AddLegacy("Little whiteboard is still loading... Please wait. (If the board has loaded, ignore the message)", NOTIFY_GENERIC, 5)
        end
    end)
end

function ENT:InitializeLittleWhiteboard()
    local entIndex = self:EntIndex()
    
    if littleWhiteboardRTs[entIndex] then return end
    
    littleWhiteboardRTs[entIndex] = {}
    
    local rt = GetRenderTarget("LittleWhiteboardRT_" .. entIndex, 1024, 1024)
    littleWhiteboardRTs[entIndex].rt = rt
    
    local mat = CreateMaterial("LittleWhiteboardMaterial_" .. entIndex, "UnlitGeneric", {
        ["$basetexture"] = rt:GetName(),
        ["$vertexcolor"] = 1,
        ["$vertexalpha"] = 1,
        ["$model"] = 0,
        ["$nocull"] = 1,
        ["$translucent"] = 1,
        ["$alphatest"] = 1,
        ["$alpha"] = 1
    })
    
    littleWhiteboardRTs[entIndex].mat = mat
    
    -- Инициализируем таблицы
    self.PlayerDrawData = {}
    self.PlayerColors = {}
    self.PlayerLastDrawPos = {}
    self.drawPointsBuffer = {}
    
    render.PushRenderTarget(rt)
    render.Clear(0, 0, 0, 0)
    render.PopRenderTarget()
    
    self:UpdateLittleWhiteboardMaterial()
end

function ENT:ResetLastPosition()
    -- Обнуляем позиции для всех игроков
    self.PlayerLastDrawPos = {}
end

function ENT:ResetLastErasePosition()
    self.LastErasePos = nil
end

function ENT:GetPlayerID(player)
    if not IsValid(player) then return "default" end
    return player:SteamID() or "player_" .. tostring(player:UserID())
end

function ENT:ClearWhiteboard()
    local entIndex = self:EntIndex()
    if not littleWhiteboardRTs[entIndex] then return end
    
    -- Очищаем все данные
    self.PlayerDrawData = {}
    self.PlayerColors = {}
    self.PlayerLastDrawPos = {}
    self.drawPointsBuffer = {}
    
    render.PushRenderTarget(littleWhiteboardRTs[entIndex].rt)
    render.Clear(0, 0, 0, 0)
    render.PopRenderTarget()
    
    self:UpdateLittleWhiteboardMaterial()
end

function ENT:ClearPlayerDrawings(player)
    if not IsValid(player) then return end
    
    local playerID = self:GetPlayerID(player)
    
    -- Создаем новый буфер без точек этого игрока
    local newBuffer = {}
    for _, point in ipairs(self.drawPointsBuffer) do
        if point.playerID ~= playerID then
            table.insert(newBuffer, point)
        end
    end
    
    -- Обновляем буфер
    self.drawPointsBuffer = newBuffer
    
    -- Очищаем данные игрока
    self.PlayerDrawData[playerID] = nil
    self.PlayerColors[playerID] = nil
    self.PlayerLastDrawPos[playerID] = nil
    
    -- Перерисовываем
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
            mins = Vector(-1, math_min(topLeft_local.y, bottomRight_local.y), math_min(topLeft_local.z, bottomRight_local.z)),
            maxs = Vector(1, math_max(topLeft_local.y, bottomRight_local.y), math_max(topLeft_local.z, bottomRight_local.z))
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
    
    texCoordX = math_Clamp(texCoordX, 0, 1)
    texCoordY = math_Clamp(texCoordY, 0, 1)
        
    return texCoordX, texCoordY
end

function ENT:CalculateBoardPosition(hitPos)
    local visualPos = self:GetVisualBoardPosition()
    local visualAng = self:GetAngles()
    visualAng:RotateAroundAxis(visualAng:Up(), -180)
    visualAng:RotateAroundAxis(visualAng:Right(), -9.6)
    
    local right = visualAng:Right()
    local up = visualAng:Up()
    local forward = visualAng:Forward()
    
    local relativePos = hitPos - visualPos
    local localY = relativePos:Dot(right)
    local localZ = relativePos:Dot(up)
    
    local halfWidth = 14.5
    local halfHeight = 21
    local isOnBoard = math_abs(localY) <= halfWidth and math_abs(localZ) <= halfHeight
    
    local texCoordX, texCoordY = 0, 0
    if isOnBoard then
        texCoordX = (localY + halfWidth) / (halfWidth * 2)
        texCoordY = 1 - ((localZ + halfHeight) / (halfHeight * 2))
        
        texCoordX = math_Clamp(texCoordX, 0, 1)
        texCoordY = math_Clamp(texCoordY, 0, 1)
    end
    
    return isOnBoard, texCoordX, texCoordY
end

function ENT:IsPointOnBoard(localPos)
    if not localPos then return false end
    
    local mins, maxs = self:GetLittleWhiteboardBounds()
    
    local inX = math_abs(localPos.x) <= 2
    local inY = localPos.y >= mins.y and localPos.y <= maxs.y
    local inZ = localPos.z >= mins.z and localPos.z <= maxs.z
    
    return inX and inY and inZ
end

function ENT:DrawOnBoard(hitPos, color, size, isNewLine, player)
    if not IsValid(self) then return end
    
    local entIndex = self:EntIndex()
    if not littleWhiteboardRTs[entIndex] then
        self:InitializeLittleWhiteboard()
        if not littleWhiteboardRTs[entIndex] then return end
    end

    local isOnBoard, texCoordX, texCoordY = self:CalculateBoardPosition(hitPos)

    if not isOnBoard then
        return
    end
    
    local texSizeX, texSizeY = 1024, 1024
    local currentX = texCoordX * texSizeX
    local currentY = texCoordY * texSizeY
    local pointSize = size or 8
    
    -- Получаем ID игрока
    local playerID = self:GetPlayerID(player)
    
    -- Инициализируем данные для игрока
    if not self.PlayerDrawData[playerID] then
        self.PlayerDrawData[playerID] = {}
    end
    
    -- Сохраняем цвет игрока
    self.PlayerColors[playerID] = color

    -- Проверяем, нет ли уже такой точки (защита от дублирования)
    local isDuplicate = false
    local lastPoint = self.PlayerDrawData[playerID] and self.PlayerDrawData[playerID][#self.PlayerDrawData[playerID]]
    if lastPoint and not isNewLine then
        local dist = math_sqrt((currentX - lastPoint.x)^2 + (currentY - lastPoint.y)^2)
        if dist < 1 then
            isDuplicate = true
        end
    end
    
    if not isDuplicate then
        -- Создаем точку
        local newPoint = {
            x = currentX,
            y = currentY,
            color = color,
            size = pointSize,
            playerID = playerID,
            timestamp = CurTime()
        }
        
        -- Добавляем в буфер
        table.insert(self.drawPointsBuffer, newPoint)
        table.insert(self.PlayerDrawData[playerID], newPoint)
        
        -- Рисуем линии между точками для этого игрока
        local lastPlayerPos = self.PlayerLastDrawPos[playerID]
        if lastPlayerPos and not isNewLine then
            local lastX, lastY = lastPlayerPos.x, lastPlayerPos.y
            local dist = math_sqrt((currentX - lastX)^2 + (currentY - lastY)^2)
            
            if dist > 3 then
                local steps = math_max(2, math_floor(dist / 6))
                for i = 1, steps - 1 do
                    local t = i / steps
                    local lineX = lastX + (currentX - lastX) * t
                    local lineY = lastY + (currentY - lastY) * t
                    
                    local linePoint = {
                        x = lineX,
                        y = lineY,
                        color = color,
                        size = pointSize,
                        playerID = playerID,
                        timestamp = CurTime() + i * 0.001
                    }
                    
                    table.insert(self.drawPointsBuffer, linePoint)
                    table.insert(self.PlayerDrawData[playerID], linePoint)
                end
            end
        end
    end
    
    -- Обновляем позиции
    self.PlayerLastDrawPos[playerID] = {x = currentX, y = currentY}
    
    -- Немедленная отрисовка
    self:SmoothImmediateRedraw()
end

function ENT:EraseOnBoard(hitPos, size, isNewLine, player)
    if not IsValid(self) then return end
    
    local entIndex = self:EntIndex()
    if not littleWhiteboardRTs[entIndex] then return end
    
    local isOnBoard, texCoordX, texCoordY = self:CalculateBoardPosition(hitPos)
    
    if not isOnBoard then
        return
    end
    
    local texSizeX, texSizeY = 1024, 1024
    local currentX = texCoordX * texSizeX
    local currentY = texCoordY * texSizeY
    local eraseSize = size or 20
    local eraseRadius = eraseSize / 2

    if isNewLine then
        self.LastErasePos = nil
    end

    -- Получаем ID игрока
    local playerID = self:GetPlayerID(player)
    
    -- Стираем точки
    local erasedPoints = self:EraseAtPosition(currentX, currentY, eraseRadius, playerID)
    
    -- Рисуем линии стирания
    if self.LastErasePos and not isNewLine then
        local lastX, lastY = self.LastErasePos.x, self.LastErasePos.y
        local dist = math_sqrt((currentX - lastX)^2 + (currentY - lastY)^2)
        
        if dist > 3 then
            local steps = math_max(2, math_floor(dist / 6))
            for i = 1, steps - 1 do
                local t = i / steps
                local lineX = lastX + (currentX - lastX) * t
                local lineY = lastY + (currentY - lastY) * t
                
                self:EraseAtPosition(lineX, lineY, eraseRadius, playerID)
            end
        end
    end
    
    self.LastErasePos = {x = currentX, y = currentY}
    
    -- Перерисовываем
    self:SmoothImmediateRedraw()
end

function ENT:EraseAtPosition(x, y, radius, playerID)
    local pointsToRemove = {}
    local erasedPoints = {}
    local radiusSquared = radius * radius
    
    -- Ищем точки для удаления в drawPointsBuffer
    for i, point in ipairs(self.drawPointsBuffer) do
        local distSquared = (point.x - x)^2 + (point.y - y)^2
        if distSquared <= radiusSquared then
            -- Если указан конкретный игрок, стираем только его точки
            if not playerID or point.playerID == playerID then
                table.insert(pointsToRemove, i)
                table.insert(erasedPoints, point)
            end
        end
    end
    
    -- Удаляем из основного буфера
    for i = #pointsToRemove, 1, -1 do
        table.remove(self.drawPointsBuffer, pointsToRemove[i])
    end
    
    -- Также удаляем из данных игрока
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
    
    return erasedPoints
end

function ENT:ScheduleOptimizedRedraw()
    self.lastImmediateRedraw = self.lastImmediateRedraw or 0
    self.lastFullRedraw = self.lastFullRedraw or 0
    self.immediateRedrawRate = self.immediateRedrawRate or 0.05
    self.fullRedrawRate = self.fullRedrawRate or 0.3
    
    local currentTime = CurTime()
    
    if currentTime - self.lastImmediateRedraw >= self.immediateRedrawRate then
        self:SmoothImmediateRedraw()
        self.lastImmediateRedraw = currentTime
    end
end

function ENT:SmoothImmediateRedraw()
    local entIndex = self:EntIndex()
    if not littleWhiteboardRTs[entIndex] then return end
    
    local success, err = pcall(function()
        render.PushRenderTarget(littleWhiteboardRTs[entIndex].rt)
        render.OverrideAlphaWriteEnable(true, true)
        
        cam.Start2D()
        
        -- Очищаем и перерисовываем ВСЕ точки
        render.Clear(0, 0, 0, 0)
        
        -- Рисуем все точки из drawPointsBuffer
        for _, point in ipairs(self.drawPointsBuffer) do
            surface.SetDrawColor(point.color.r, point.color.g, point.color.b, 255)
            local radius = point.size or 8
            self:DrawOptimizedCircle(point.x, point.y, radius/2)
        end
        
        cam.End2D()
        render.OverrideAlphaWriteEnable(false)
        render.PopRenderTarget()
    end)
    
    if not success then
        pcall(function() cam.End2D() end)
        pcall(function() render.OverrideAlphaWriteEnable(false) end)
        pcall(function() render.PopRenderTarget() end)
        ErrorNoHalt("SmoothImmediateRedraw error: " .. tostring(err) .. "\n")
        return
    end
    
    self:UpdateLittleWhiteboardMaterial()
end

function ENT:ScheduleFullRedraw()
    self.fullRedrawScheduled = self.fullRedrawScheduled or false
    
    if self.fullRedrawScheduled then return end
    
    self.fullRedrawScheduled = true
    
    timer.Simple(self.fullRedrawRate or 0.3, function()
        if IsValid(self) then
            self:SmoothImmediateRedraw()  -- Используем ту же функцию
        end
        self.fullRedrawScheduled = false
    end)
end

function ENT:ForceRedraw()
    self:SmoothImmediateRedraw()
end

function ENT:DrawOptimizedCircle(x, y, radius)
    local segments
    if radius <= 4 then segments = 8
    elseif radius <= 8 then segments = 12
    else segments = 16 end
    
    local circlePoly = GetCachedCircle(radius, segments)
    local positionedPoly = {}
    
    for _, vertex in ipairs(circlePoly) do
        positionedPoly[#positionedPoly + 1] = {
            x = x + vertex.x,
            y = y + vertex.y
        }
    end
    surface.DrawPoly(positionedPoly)
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

function ENT:Draw()
    self:DrawModel()
    self:DrawLittleWhiteboard()
    if self.DebugEnabled then
        self:DrawDebugInfo()
    end
end

function ENT:DrawLittleWhiteboard()
    local entIndex = self:EntIndex()
    if not littleWhiteboardRTs[entIndex] then return end
    
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
    
    render.SetMaterial(mat)
    render.DrawQuad(topLeft, topRight, bottomRight, bottomLeft)
end

function ENT:OnRemove()
    local entIndex = self:EntIndex()
    if littleWhiteboardRTs[entIndex] then
        littleWhiteboardRTs[entIndex] = nil
    end
end

-- -- ДЕБАГ ФУНКЦИИ
-- function ENT:DebugPlayerDrawings()
--     print("=== LITTLE WHITEBOARD DEBUG ===")
--     print("Entity ID: " .. self:EntIndex())
--     print("Total points in buffer: " .. #self.drawPointsBuffer)
    
--     print("Players with drawings:")
--     for playerID, points in pairs(self.PlayerDrawData) do
--         print("  Player: " .. playerID .. " (" .. #points .. " points)")
--         if self.PlayerColors[playerID] then
--             local col = self.PlayerColors[playerID]
--             print("    Color: " .. col.r .. "," .. col.g .. "," .. col.b)
--         end
--     end
--     print("======================")
-- end

-- Консольные команды уже определены в whiteboard/cl_init.lua и работают для обоих типов досок