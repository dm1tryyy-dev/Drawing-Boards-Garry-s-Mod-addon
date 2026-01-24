include("shared.lua")

whiteboardRTs = whiteboardRTs or {}

local math_sqrt = math.sqrt
local math_max = math.max
local math_min = math.min
local math_floor = math.floor
local math_Clamp = math.Clamp
local math_cos = math.cos
local math_sin = math.sin
local math_pi = math.pi

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
    self.LampSprite = Material("sprites/light_glow02_add_noz")
    self:InitializeWhiteboard()
    
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
    
    self:ShowLoadingNotification()
end

function ENT:ShowLoadingNotification()
    if not IsValid(self) then return end
    
    if IsValid(LocalPlayer()) then
        chat.AddText(Color(255, 255, 0), "[Whiteboard] ", Color(255, 255, 255), "Board rendering is loading... This may take up to 40 seconds (but can load immediately in some cases).")
        notification.AddLegacy("Whiteboard rendering is loading... This may take up to 40 seconds (but can load immediately in some cases).", NOTIFY_GENERIC, 5)
    end
    timer.Simple(20, function()
        if IsValid(self) and IsValid(LocalPlayer()) then
            chat.AddText(Color(255, 255, 0), "[Whiteboard] ", Color(255, 255, 255), "Board is still loading... Please wait. (If the board has loaded, ignore the message)")
            notification.AddLegacy("Whiteboard is still loading... Please wait. (If the board has loaded, ignore the message)", NOTIFY_GENERIC, 5)
        end
    end)
end

function ENT:InitializeWhiteboard()
    local entIndex = self:EntIndex()
    
    if whiteboardRTs[entIndex] then return end
    
    whiteboardRTs[entIndex] = {}
    
    local rt = GetRenderTarget("WhiteboardRT_" .. entIndex, 1024, 1024)
    whiteboardRTs[entIndex].rt = rt
    
    local mat = CreateMaterial("WhiteboardMaterial_" .. entIndex, "UnlitGeneric", {
        ["$basetexture"] = rt:GetName(),
        ["$vertexcolor"] = 1,
        ["$vertexalpha"] = 1,
        ["$model"] = 0,
        ["$nocull"] = 1,
        ["$translucent"] = 1,
        ["$alphatest"] = 1,
        ["$alpha"] = 1
    })
    
    whiteboardRTs[entIndex].mat = mat
    
    -- Инициализируем таблицы
    self.PlayerDrawData = {}
    self.PlayerColors = {}
    self.PlayerLastDrawPos = {}
    self.drawPointsBuffer = {}
    
    render.PushRenderTarget(rt)
    render.Clear(0, 0, 0, 0)
    render.PopRenderTarget()
    
    self:UpdateWhiteboardMaterial()
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
    if not whiteboardRTs[entIndex] then return end
    
    -- Очищаем все данные
    self.PlayerDrawData = {}
    self.PlayerColors = {}
    self.PlayerLastDrawPos = {}
    self.drawPointsBuffer = {}
    self.LastErasePos = nil
    
    -- Очищаем RenderTarget
    render.PushRenderTarget(whiteboardRTs[entIndex].rt)
    render.Clear(0, 0, 0, 0)
    render.PopRenderTarget()
    
    self:UpdateWhiteboardMaterial()
    
    -- Принудительная перерисовка
    self:ForceRedraw()
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
    
    texCoordX = math_Clamp(texCoordX, 0, 1)
    texCoordY = math_Clamp(texCoordY, 0, 1)
    
    return texCoordX, texCoordY
end

function ENT:IsPointOnBoard(localPos)
    if not localPos then return false end
    
    local mins, maxs = self:GetWhiteboardBounds()
    
    return math.abs(localPos.x) <= 2 and
           localPos.y >= mins.y and localPos.y <= maxs.y and
           localPos.z >= mins.z and localPos.z <= maxs.z
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
    
    local texCoordX, texCoordY = self:LocalToTextureCoords(localPos)
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
    if not whiteboardRTs[entIndex] then return end
    
    local localPos = self:WorldToLocal(hitPos)
    if not self:IsPointOnBoard(localPos) then return end
    
    local texCoordX, texCoordY = self:LocalToTextureCoords(localPos)
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
    if not whiteboardRTs[entIndex] then return end
    
    local success, err = pcall(function()
        render.PushRenderTarget(whiteboardRTs[entIndex].rt)
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
    
    self:UpdateWhiteboardMaterial()
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

function ENT:UpdateWhiteboardMaterial()
    local entIndex = self:EntIndex()
    if not whiteboardRTs[entIndex] or not whiteboardRTs[entIndex].mat then return end
    
    local mat = whiteboardRTs[entIndex].mat
    mat:SetTexture("$basetexture", whiteboardRTs[entIndex].rt)
    mat:Recompute()
end

function ENT:Draw()
    self:DrawModel()
    self:DrawWhiteboard()
    self:DrawLampGlow()
end

function ENT:DrawWhiteboard()
    local entIndex = self:EntIndex()
    if not whiteboardRTs[entIndex] then return end
    
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
    
    render.SetMaterial(mat)
    render.DrawQuad(topLeft, topRight, bottomRight, bottomLeft)
end

function ENT:Think()
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
    local entIndex = self:EntIndex()
    if whiteboardRTs[entIndex] then
        whiteboardRTs[entIndex] = nil
    end
end

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

-- concommand.Add("marker_local_clear", function(ply)
--     local tr = ply:GetEyeTrace()
--     local ent = tr.Entity
--     if IsValid(ent) and (ent:GetClass() == "little_whiteboard" or ent:GetClass() == "whiteboard") then
--         if ent.ClearPlayerDrawings then
--             ent:ClearPlayerDrawings(ply)
--             print("Your drawings cleared!")
--         else
--             print("This whiteboard doesn't support player-specific clearing")
--         end
--     else
--         print("Look at a whiteboard to clear your drawings!")
--     end
-- end)

hook.Add("KeyRelease", "WhiteboardForceRedraw", function(ply, key)
    if key == IN_ATTACK or key == IN_ATTACK2 then
        local tr = ply:GetEyeTrace()
        local ent = tr.Entity
        if IsValid(ent) and (ent:GetClass() == "little_whiteboard" or ent:GetClass() == "whiteboard") then
            ent:ForceRedraw()
        end
    end
end)
