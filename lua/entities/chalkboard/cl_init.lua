include("shared.lua")

chalkboardRTs = chalkboardRTs or {}

function ENT:Initialize()
    self.LampSprite = Material("sprites/light_glow02_add_noz")
    self:InitializeChalkboard()
    
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
    self.immediateRedrawRate = 0.033 -- 30 FPS
    self.fullRedrawRate = 0.1        -- 10 FPS
    
    self.ProjectedTexture = ProjectedTexture()
    if self.ProjectedTexture then
        self.ProjectedTexture:SetTexture("effects/flashlight001")
        self.ProjectedTexture:SetFarZ(200)
        self.ProjectedTexture:SetFOV(120)
        self.ProjectedTexture:SetEnableShadows(false)
        self.ProjectedTexture:SetConstantAttenuation(1)
        self.ProjectedTexture:SetLinearAttenuation(0.1)
        self.ProjectedTexture:SetQuadraticAttenuation(0.01)
    end
end

function ENT:InitializeChalkboard()
    local entIndex = self:EntIndex()
    
    if chalkboardRTs[entIndex] then return end
    
    chalkboardRTs[entIndex] = {}
    
    local rt = GetRenderTarget("ChalkboardRT_" .. entIndex, 1024, 1024)
    chalkboardRTs[entIndex].rt = rt
    
    local mat = CreateMaterial("ChalkboardMaterial_" .. entIndex, "UnlitGeneric", {
        ["$basetexture"] = rt:GetName(),
        ["$vertexcolor"] = 1,
        ["$vertexalpha"] = 1,
        ["$model"] = 0,
        ["$nocull"] = 1,
        ["$translucent"] = 1,
        ["$alphatest"] = 1,
        ["$alpha"] = 1
    })
    
    chalkboardRTs[entIndex].mat = mat
    
    -- Инициализируем таблицы
    self.PlayerDrawData = {}
    self.PlayerColors = {}
    self.PlayerLastDrawPos = {}
    self.drawPointsBuffer = {}
    
    render.PushRenderTarget(rt)
    render.Clear(0, 0, 0, 0)
    render.PopRenderTarget()
    
    self:UpdateChalkboardMaterial()
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

function ENT:ClearChalkboard()
    local entIndex = self:EntIndex()
    if not chalkboardRTs[entIndex] then return end
    
    -- Очищаем все данные
    self.PlayerDrawData = {}
    self.PlayerColors = {}
    self.PlayerLastDrawPos = {}
    self.drawPointsBuffer = {}
    
    render.PushRenderTarget(chalkboardRTs[entIndex].rt)
    render.Clear(0, 0, 0, 0)
    render.PopRenderTarget()
    
    self:UpdateChalkboardMaterial()
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

function ENT:GetChalkboardBounds()
    if not self.ChalkBounds then
        local halfWidth = 40.3
        local halfHeight = 21.7
        
        self.ChalkBounds = {
            mins = Vector(-2, -halfWidth, -halfHeight),
            maxs = Vector(2, halfWidth, halfHeight)
        }
    end
    return self.ChalkBounds.mins, self.ChalkBounds.maxs
end

function ENT:DrawBoundsDebug()
    local mins, maxs = self:GetChalkboardBounds()
    
    local pos = self:GetPos()
    local ang = self:GetAngles()
    ang:RotateAroundAxis(ang:Up(), 180)
    local right = ang:Right()
    local up = ang:Up()
    local forward = ang:Forward()
    
    pos = pos - forward
    pos = pos - right  
    pos = pos + up
    
    local halfWidth = 40.3
    local halfHeight = 21.7
    
    local corners = {
        pos + up * halfHeight + right * (-halfWidth),
        pos + up * halfHeight + right * halfWidth,
        pos + up * (-halfHeight) + right * halfWidth,
        pos + up * (-halfHeight) + right * (-halfWidth)
    }
end

function ENT:LocalToTextureCoords(localPos)
    local mins, maxs = self:GetChalkboardBounds()
    
    local correctionY = 1.0
    local correctionZ = -1.0
    
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
    
    local mins, maxs = self:GetChalkboardBounds()
    
    return math.abs(localPos.x) <= 2 and
           localPos.y >= mins.y and localPos.y <= maxs.y and
           localPos.z >= mins.z and localPos.z <= maxs.z
end

function ENT:DrawOnBoard(hitPos, color, size, isNewLine, player)
    if not IsValid(self) then return end
    
    local entIndex = self:EntIndex()
    if not chalkboardRTs[entIndex] then
        self:InitializeChalkboard()
        if not chalkboardRTs[entIndex] then return end
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
        local dist = math.sqrt((currentX - lastPoint.x)^2 + (currentY - lastPoint.y)^2)
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
            local dist = math.sqrt((currentX - lastX)^2 + (currentY - lastY)^2)
            
            if dist > 2 then
                local steps = math.max(2, math.floor(dist / 4))
                
                -- Создаем таблицу для проверки уже существующих точек
                local existingPoints = {}
                for _, point in ipairs(self.drawPointsBuffer) do
                    if point.playerID == playerID then
                        -- Округляем координаты для сравнения
                        local roundedX = math.floor(point.x * 10) / 10
                        local roundedY = math.floor(point.y * 10) / 10
                        existingPoints[roundedX .. "_" .. roundedY] = true
                    end
                end
                
                for i = 1, steps - 1 do
                    local t = i / steps
                    local lineX = lastX + (currentX - lastX) * t
                    local lineY = lastY + (currentY - lastY) * t
                    
                    -- Округляем координаты для проверки
                    local roundedX = math.floor(lineX * 10) / 10
                    local roundedY = math.floor(lineY * 10) / 10
                    local pointKey = roundedX .. "_" .. roundedY
                    
                    -- Проверяем, нет ли уже такой точки
                    if not existingPoints[pointKey] then
                        existingPoints[pointKey] = true
                        
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
    end
    
    -- Обновляем позиции
    self.PlayerLastDrawPos[playerID] = {x = currentX, y = currentY}
    
    -- Немедленная отрисовка
    self:SmoothImmediateRedraw()
end

function ENT:EraseOnBoard(hitPos, size, isNewLine, player)
    if not IsValid(self) then return end
    
    local entIndex = self:EntIndex()
    if not chalkboardRTs[entIndex] then return end
    
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
        local dist = math.sqrt((currentX - lastX)^2 + (currentY - lastY)^2)
        
        if dist > 2 then
            local steps = math.max(2, math.floor(dist / 4))
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
    self.immediateRedrawRate = self.immediateRedrawRate or 0.033
    self.fullRedrawRate = self.fullRedrawRate or 0.1
    
    local currentTime = CurTime()
    
    if currentTime - self.lastImmediateRedraw >= self.immediateRedrawRate then
        self:SmoothImmediateRedraw()
        self.lastImmediateRedraw = currentTime
    end
end

function ENT:SmoothImmediateRedraw()
    local entIndex = self:EntIndex()
    if not chalkboardRTs[entIndex] then return end
    
    local success, err = pcall(function()
        render.PushRenderTarget(chalkboardRTs[entIndex].rt)
        render.OverrideAlphaWriteEnable(true, true)
        
        cam.Start2D()
        
        -- Очищаем и перерисовываем ВСЕ точки
        render.Clear(0, 0, 0, 0)
        
        -- Рисуем все точки из drawPointsBuffer
        for _, point in ipairs(self.drawPointsBuffer) do
            surface.SetDrawColor(point.color.r, point.color.g, point.color.b, 255)
            surface.DrawRect(
                math.Round(point.x - point.size/2), 
                math.Round(point.y - point.size/2), 
                point.size, 
                point.size
            )
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
    
    self:UpdateChalkboardMaterial()
end

function ENT:ScheduleFullRedraw()
    self.fullRedrawScheduled = self.fullRedrawScheduled or false
    
    if self.fullRedrawScheduled then return end
    
    self.fullRedrawScheduled = true
    
    timer.Simple(self.fullRedrawRate or 0.1, function()
        if IsValid(self) then
            self:SmoothImmediateRedraw()  -- Используем ту же функцию
        end
        self.fullRedrawScheduled = false
    end)
end

function ENT:ForceRedraw()
    self:SmoothImmediateRedraw()
end

function ENT:UpdateChalkboardMaterial()
    local entIndex = self:EntIndex()
    if not chalkboardRTs[entIndex] or not chalkboardRTs[entIndex].mat then return end
    
    local mat = chalkboardRTs[entIndex].mat
    mat:SetTexture("$basetexture", chalkboardRTs[entIndex].rt)
    mat:Recompute()

    mat:SetInt("$translucent", 1)
    mat:SetInt("$alphatest", 1)
    mat:SetFloat("$alpha", 1)
end

function ENT:Draw()
    self:DrawModel()
    self:DrawChalkboard()
    self:DrawLampGlow()
    self:DrawProjectedLight()
    self:DrawBoundsDebug()
end

function ENT:DrawChalkboard()
    local entIndex = self:EntIndex()
    if not chalkboardRTs[entIndex] then return end
    
    local mat = chalkboardRTs[entIndex].mat
    if not mat then return end

    local pos = self:GetPos()
    local ang = self:GetAngles()
    ang:RotateAroundAxis(ang:Up(), 180)
    local right = ang:Right()
    local up = ang:Up()
    local forward = ang:Forward()
    
    pos = pos - forward
    pos = pos - right  
    pos = pos + up
    
    local halfWidth = 40.3
    local halfHeight = 21.7
    
    local topLeft = pos + (up * halfHeight) + (right * (-halfWidth))
    local topRight = pos + (up * halfHeight) + (right * halfWidth)
    local bottomRight = pos + (up * (-halfHeight)) + (right * halfWidth)
    local bottomLeft = pos + (up * (-halfHeight)) + (right * (-halfWidth))
    
    render.SetBlend(1)
    render.SetMaterial(mat)
    render.DrawQuad(topLeft, topRight, bottomRight, bottomLeft)
    render.SetBlend(1)
end

-- СВЕТОВЫЕ ФУНКЦИИ
function ENT:Think()
    self:UpdateLight()
    self:UpdateProjectedLight()
    self:NextThink(CurTime() + 0.1)
    return true
end

function ENT:DrawProjectedLight()
    if not self:GetLightEnabled() then return end
    if not self.ProjectedTexture then return end
    
    local lightColor = self:GetLightColor()
    local brightness = self:GetLightBrightness()
    local distance = self:GetLightDistance()

    local normalizedColor = Vector(
        lightColor.x / 255,
        lightColor.y / 255, 
        lightColor.z / 255
    )
    

    local lightPos = self:GetPos() + self:GetForward() * 60
    local lightAng = self:GetAngles()
    lightAng:RotateAroundAxis(lightAng:Up(), 180)

    self.ProjectedTexture:SetPos(lightPos)
    self.ProjectedTexture:SetAngles(lightAng)
    self.ProjectedTexture:SetColor(Color(
        normalizedColor.x * 255,
        normalizedColor.y * 255,
        normalizedColor.z * 255
    ))
    self.ProjectedTexture:SetBrightness(brightness / 10)
    self.ProjectedTexture:SetFarZ(distance)
    

    self.ProjectedTexture:Update()
end

function ENT:UpdateLight()
    if not self:GetLightEnabled() then return end
    
    local lampLocalPos = Vector(0, 0, 22.5)
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

function ENT:UpdateProjectedLight()
    if not self:GetLightEnabled() then return end
    
    local lightColor = self:GetLightColor()
    local brightness = self:GetLightBrightness()
    local distance = self:GetLightDistance()
    

    local lightPos = self:GetPos()
    
    local dlight = DynamicLight(self:EntIndex() + 1000)
    if dlight then
        dlight.Pos = lightPos
        dlight.r = lightColor.x
        dlight.g = lightColor.y
        dlight.b = lightColor.z
        dlight.Brightness = (brightness / 10) * 0.3
        dlight.Size = distance*2
        dlight.Decay = 1000
        dlight.DieTime = CurTime() + 1
    end
end

function ENT:DrawLampGlow()
    if not self:GetLightEnabled() or not self.LampSprite then return end
    
    local lightColor = self:GetLightColor()
    local brightness = self:GetLightBrightness() * 0.3
    local lampLocalPos = Vector(1.5, 0, 23.5)
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
    if chalkboardRTs[entIndex] then
        chalkboardRTs[entIndex] = nil
    end
    
    if self.ProjectedTexture then
        self.ProjectedTexture:Remove()
        self.ProjectedTexture = nil
    end
end

-- КЛИЕНТСКИЕ СЕТЕВЫЕ ОБРАБОТЧИКИ
net.Receive("ChalkDraw", function()
    local chalkboard = net.ReadEntity()
    local hitPos = net.ReadVector()
    local color = net.ReadColor()
    local size = net.ReadUInt(8)
    local isNewLine = net.ReadBool()
    local player = net.ReadEntity()
    
    if IsValid(chalkboard) and chalkboard.DrawOnBoard then
        chalkboard:DrawOnBoard(hitPos, color, size, isNewLine, player)
    end
end)

net.Receive("ChalkErase", function()
    local chalkboard = net.ReadEntity()
    local hitPos = net.ReadVector()
    local size = net.ReadUInt(8)
    local isNewLine = net.ReadBool()
    local player = net.ReadEntity()
    
    if IsValid(chalkboard) and chalkboard.EraseOnBoard then
        chalkboard:EraseOnBoard(hitPos, size, isNewLine, player)
    end
end)

net.Receive("ChalkboardClear", function()
    local chalkboard = net.ReadEntity()
    if IsValid(chalkboard) and chalkboard.ClearChalkboard then
        chalkboard:ClearChalkboard()
    end
end)

net.Receive("ChalkboardClearPlayer", function()
    local chalkboard = net.ReadEntity()
    local player = net.ReadEntity()
    if IsValid(chalkboard) and chalkboard.ClearPlayerDrawings then
        chalkboard:ClearPlayerDrawings(player)
    end
end)

-- КЛИЕНТСКИЕ КОМАНДЫ ДЛЯ ОТЛАДКИ
concommand.Add("chalk_clear", function(ply)
    local tr = ply:GetEyeTrace()
    if IsValid(tr.Entity) and tr.Entity:GetClass() == "chalkboard" then
        -- Отправляем запрос на сервер
        RunConsoleCommand("chalk_clear")
    else
        print("Look at a chalkboard to clear it!")
    end
end)

concommand.Add("chalk_clear", function(ply)
    local tr = ply:GetEyeTrace()
    local ent = tr.Entity
    if IsValid(ent) and ent:GetClass() == "chalkboard" then
        ent:ClearWhiteboard()
        print("Chalkboard cleared!")
    else
        print("Look at a chalkboard to clear it!")
    end
end)

-- concommand.Add("chalk_local_clear", function(ply)
--     local tr = ply:GetEyeTrace()
--     local ent = tr.Entity
--     if IsValid(ent) and  ent:GetClass() == "chalkboard" then
--         if ent.ClearPlayerDrawings then
--             ent:ClearPlayerDrawings(ply)
--             print("Your drawings cleared!")
--         else
--             print("This chalkboard doesn't support player-specific clearing")
--         end
--     else
--         print("Look at a chalkboard to clear your drawings!")
--     end
-- end)

-- function ENT:DebugPlayerDrawings()
--     print("=== CHALKBOARD DEBUG ===")
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