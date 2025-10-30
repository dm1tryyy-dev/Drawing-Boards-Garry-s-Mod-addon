include("shared.lua")

whiteboardRTs = whiteboardRTs or {}
whiteboardData = whiteboardData or {}

-- Кэш для кругов (оптимизация)
local circleCache = {}
local function GetCachedCircle(radius, segments)
    local key = radius .. "_" .. segments
    if not circleCache[key] then
        local poly = {}
        for i = 0, segments do
            local angle = (i / segments) * math.pi * 2
            poly[#poly + 1] = {x = math.cos(angle) * radius, y = math.sin(angle) * radius}
        end
        circleCache[key] = poly
    end
    return circleCache[key]
end

function ENT:Initialize()
    self.LampSprite = Material("sprites/light_glow02_add_noz")
    self:InitializeWhiteboard()
    self.LastDrawPos = nil
    self.LastErasePos = nil
end

function ENT:InitializeWhiteboard()
    local entIndex = self:EntIndex()
    
    if whiteboardRTs[entIndex] then return end
    
    whiteboardRTs[entIndex] = {}
    whiteboardData[entIndex] = {
        drawData = {},
        eraseData = {}
    }
    
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
    
    render.PushRenderTarget(rt)
    render.Clear(0, 0, 0, 0)
    render.PopRenderTarget()
    
    self:UpdateWhiteboardMaterial()
end

function ENT:ResetLastPosition()
    self.LastDrawPos = nil
end

function ENT:ResetLastErasePosition()
    self.LastErasePos = nil
end

function ENT:ClearWhiteboard()
    local entIndex = self:EntIndex()
    if not whiteboardRTs[entIndex] then return end
    
    if whiteboardData[entIndex] then
        whiteboardData[entIndex].drawData = {}
        whiteboardData[entIndex].eraseData = {}
    end
    
    render.PushRenderTarget(whiteboardRTs[entIndex].rt)
    render.Clear(0, 0, 0, 0)
    render.PopRenderTarget()
    
    self:UpdateWhiteboardMaterial()
    self:ResetLastPosition()
    self:ResetLastErasePosition()
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

function ENT:DrawOnBoard(hitPos, color, size, isNewLine)
    if not IsValid(self) then return end
    
    local entIndex = self:EntIndex()
    if not whiteboardRTs[entIndex] then
        self:InitializeWhiteboard()
        if not whiteboardRTs[entIndex] then return end
    end

    if not whiteboardData[entIndex] then
        whiteboardData[entIndex] = { drawData = {}, eraseData = {} }
    end
    if not whiteboardData[entIndex].drawData then
        whiteboardData[entIndex].drawData = {}
    end
    
    local localPos = self:WorldToLocal(hitPos)
    
    if not self:IsPointOnBoard(localPos) then
        return
    end
    
    local texCoordX, texCoordY = self:LocalToTextureCoords(localPos)
    
    local texSizeX = 1024
    local texSizeY = 1024
    local currentX = texCoordX * texSizeX
    local currentY = texCoordY * texSizeY
    
    local pointSize = size or 8

    table.insert(whiteboardData[entIndex].drawData, {
        x = currentX,
        y = currentY,
        color = color,
        size = pointSize,
        type = "draw"
    })

    if self.LastDrawPos and not isNewLine then
        local lastX = self.LastDrawPos.x
        local lastY = self.LastDrawPos.y
        
        local dist = math.sqrt((currentX - lastX)^2 + (currentY - lastY)^2)
        
        if dist > 2 then
            local steps = math.max(2, math.floor(dist / 4))
            for i = 1, steps - 1 do
                local t = i / steps
                local lineX = lastX + (currentX - lastX) * t
                local lineY = lastY + (currentY - lastY) * t
                table.insert(whiteboardData[entIndex].drawData, {
                    x = lineX,
                    y = lineY,
                    color = color,
                    size = pointSize,
                    type = "draw"
                })
            end
        end
    end
    
    self.LastDrawPos = {x = currentX, y = currentY}
    self:RedrawWhiteboard()
end

function ENT:EraseOnBoard(hitPos, size, isNewLine)
    if not IsValid(self) then return end
    
    local entIndex = self:EntIndex()
    if not whiteboardRTs[entIndex] then return end
    
    if not whiteboardData[entIndex] then
        whiteboardData[entIndex] = { drawData = {}, eraseData = {} }
    end
    
    local localPos = self:WorldToLocal(hitPos)
    
    if not self:IsPointOnBoard(localPos) then
        return
    end
    
    local texCoordX, texCoordY = self:LocalToTextureCoords(localPos)
    
    local texSizeX = 1024
    local texSizeY = 1024
    local currentX = texCoordX * texSizeX
    local currentY = texCoordY * texSizeY
    
    local eraseSize = size or 20
    local eraseRadius = eraseSize / 2
    
    if isNewLine then
        self.LastErasePos = nil
    end
    
    self:EraseAtPosition(currentX, currentY, eraseRadius)

    if self.LastErasePos and not isNewLine then
        local lastX = self.LastErasePos.x
        local lastY = self.LastErasePos.y
        
        local dist = math.sqrt((currentX - lastX)^2 + (currentY - lastY)^2)
        
        if dist > 2 then
            local steps = math.max(2, math.floor(dist / 4))
            for i = 1, steps - 1 do
                local t = i / steps
                local lineX = lastX + (currentX - lastX) * t
                local lineY = lastY + (currentY - lastY) * t
                
                self:EraseAtPosition(lineX, lineY, eraseRadius)
            end
        end
    end
    
    self.LastErasePos = {x = currentX, y = currentY}
    self:RedrawWhiteboard()
end

-- Оптимизированная функция стирания
function ENT:EraseAtPosition(x, y, radius)
    local entIndex = self:EntIndex()
    if not whiteboardData[entIndex] or not whiteboardData[entIndex].drawData then return end
    
    local pointsToRemove = {}
    local radiusSquared = radius * radius
    
    for i, drawPoint in ipairs(whiteboardData[entIndex].drawData) do
        local distSquared = (drawPoint.x - x)^2 + (drawPoint.y - y)^2
        if distSquared <= radiusSquared then
            table.insert(pointsToRemove, i)
        end
    end
    
    for i = #pointsToRemove, 1, -1 do
        table.remove(whiteboardData[entIndex].drawData, pointsToRemove[i])
    end
end

-- Оптимизированная функция перерисовки с кругами
function ENT:RedrawWhiteboard()
    local entIndex = self:EntIndex()
    if not whiteboardRTs[entIndex] then return end
    
    -- Ограничиваем частоту перерисовки для экономии FPS
    if self.NextRedraw and CurTime() < self.NextRedraw then return end
    self.NextRedraw = CurTime() + 0.05 -- Максимум 20 раз в секунду
    
    render.PushRenderTarget(whiteboardRTs[entIndex].rt)
    render.OverrideAlphaWriteEnable(true, true)
    
    local success, err = pcall(function()
        cam.Start2D()
        render.Clear(0, 0, 0, 0)
        
        if whiteboardData[entIndex] and whiteboardData[entIndex].drawData then
            -- Используем кэшированные круги для оптимизации
            for _, drawPoint in ipairs(whiteboardData[entIndex].drawData) do
                surface.SetDrawColor(drawPoint.color.r, drawPoint.color.g, drawPoint.color.b, 255)
                local radius = drawPoint.size or 8
                local segments = 16
                
                -- Получаем кэшированный круг
                local circlePoly = GetCachedCircle(radius/2, segments)
                
                -- Создаем полигон с правильной позицией
                local positionedPoly = {}
                for _, vertex in ipairs(circlePoly) do
                    positionedPoly[#positionedPoly + 1] = {
                        x = drawPoint.x + vertex.x,
                        y = drawPoint.y + vertex.y
                    }
                end
                
                surface.DrawPoly(positionedPoly)
            end
        end
        
        cam.End2D()
    end)
    
    render.OverrideAlphaWriteEnable(false)
    render.PopRenderTarget()
    
    if not success then
        ErrorNoHalt("RedrawWhiteboard error: " .. tostring(err) .. "\n")
        return
    end
    
    self:UpdateWhiteboardMaterial()
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

-- СВЕТОВЫЕ ФУНКЦИИ (оставлены как в оригинале)
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

    -- Сохранка текущих настроек рендера
    render.SuppressEngineLighting(true)
    render.SetColorModulation(1, 1, 1)
    
    -- тест глубины чтобы квады не были видны сквозь стены
    render.OverrideDepthEnable(true, false)
    
    render.SetMaterial(self.LampSprite)

    -- QUADS (оставлены как в оригинале)
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

-- Команда для полной очистки досок типа "whiteboard"
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