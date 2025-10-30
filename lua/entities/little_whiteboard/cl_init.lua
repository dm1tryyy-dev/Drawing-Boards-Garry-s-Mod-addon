include("shared.lua")

whiteboardRTs = whiteboardRTs or {}
whiteboardData = whiteboardData or {}

-- Кэш для часто используемых значений
local math_abs = math.abs
local math_clamp = math.Clamp
local math_sqrt = math.sqrt
local math_max = math.max
local math_min = math.min
local math_floor = math.floor
local math_cos = math.cos
local math_sin = math.sin
local math_pi = math.pi

local vector_up = Vector(0, 0, 1)
local vector_right = Vector(0, 1, 0)
local vector_forward = Vector(1, 0, 0)

function ENT:Initialize()
    self:InitializeWhiteboard()
    self.LastDrawPos = nil
    self.LastErasePos = nil
    self.DebugEnabled = false
    self.DebugPoint = nil
    self.DebugText = ""
    
    -- Предварительный расчет границ
    self:GetWhiteboardBounds()
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
end

function ENT:GetWhiteboardBounds()
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
    local mins, maxs = self:GetWhiteboardBounds()
    
    local texCoordX = (localPos.y - mins.y) / (maxs.y - mins.y)
    local texCoordY = (localPos.z - mins.z) / (maxs.z - mins.z)
    
    texCoordY = 1 - texCoordY
    
    texCoordX = math_clamp(texCoordX, 0, 1)
    texCoordY = math_clamp(texCoordY, 0, 1)
        
    return texCoordX, texCoordY
end

function ENT:IsPointOnBoard(localPos)
    if not localPos then return false end
    
    local mins, maxs = self:GetWhiteboardBounds()
    
    local inX = math_abs(localPos.x) <= 2
    local inY = localPos.y >= mins.y and localPos.y <= maxs.y
    local inZ = localPos.z >= mins.z and localPos.z <= maxs.z
    
    return inX and inY and inZ
end

-- Оптимизированная функция для расчета позиции на доске
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
        
        texCoordX = math_clamp(texCoordX, 0, 1)
        texCoordY = math_clamp(texCoordY, 0, 1)
    end
    
    return isOnBoard, texCoordX, texCoordY
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
    
    local isOnBoard, texCoordX, texCoordY = self:CalculateBoardPosition(hitPos)

    if not isOnBoard then
        self.LastDrawPos = nil
        return
    end
    if isNewLine then
        self.LastDrawPos = nil
    end
    
    local texSizeX, texSizeY = 1024, 1024
    local currentX = texCoordX * texSizeX
    local currentY = texCoordY * texSizeY
    
    local pointSize = size or 8
    local drawData = whiteboardData[entIndex].drawData

    drawData[#drawData + 1] = {
        x = currentX,
        y = currentY,
        color = color,
        size = pointSize
    }
    
    -- Интерполяция между точками
    if self.LastDrawPos and not isNewLine then
        local lastX, lastY = self.LastDrawPos.x, self.LastDrawPos.y
        local dx, dy = currentX - lastX, currentY - lastY
        local dist = math_sqrt(dx * dx + dy * dy)
        
        if dist > 2 then
            local steps = math_max(2, math_floor(dist / 4))
            local stepX, stepY = dx / steps, dy / steps
            
            for i = 1, steps - 1 do
                drawData[#drawData + 1] = {
                    x = lastX + stepX * i,
                    y = lastY + stepY * i,
                    color = color,
                    size = pointSize
                }
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
    
    local isOnBoard, texCoordX, texCoordY = self:CalculateBoardPosition(hitPos)
    
    if not isOnBoard then
        self.LastErasePos = nil
        return
    end
    if isNewLine then
        self.LastErasePos = nil
    end
    
    local texSizeX, texSizeY = 1024, 1024
    local currentX = texCoordX * texSizeX
    local currentY = texCoordY * texSizeY
    
    local eraseSize = size or 20
    local eraseRadius = eraseSize / 2
    local eraseRadiusSq = eraseRadius * eraseRadius
    
    local drawData = whiteboardData[entIndex].drawData
    if not drawData then return end
    
    -- Удаление точек в радиусе
    local i = 1
    while i <= #drawData do
        local drawPoint = drawData[i]
        local dx = drawPoint.x - currentX
        local dy = drawPoint.y - currentY
        
        if (dx * dx + dy * dy) <= eraseRadiusSq then
            table.remove(drawData, i)
        else
            i = i + 1
        end
    end
    
    -- Удаление вдоль линии
    if self.LastErasePos and not isNewLine then
        local lastX, lastY = self.LastErasePos.x, self.LastErasePos.y
        local dx, dy = currentX - lastX, currentY - lastY
        local dist = math_sqrt(dx * dx + dy * dy)
        
        if dist > 2 then
            local steps = math_max(3, math_floor(dist / 3))
            local stepX, stepY = dx / steps, dy / steps
            
            for iStep = 1, steps - 1 do
                local lineX = lastX + stepX * iStep
                local lineY = lastY + stepY * iStep
                
                local j = 1
                while j <= #drawData do
                    local drawPoint = drawData[j]
                    local pdx = drawPoint.x - lineX
                    local pdy = drawPoint.y - lineY
                    
                    if (pdx * pdx + pdy * pdy) <= eraseRadiusSq then
                        table.remove(drawData, j)
                    else
                        j = j + 1
                    end
                end
            end
        end
    end
    
    self.LastErasePos = {x = currentX, y = currentY}
    self:RedrawWhiteboard()
end

function ENT:RedrawWhiteboard()
    local entIndex = self:EntIndex()
    if not whiteboardRTs[entIndex] then return end
    
    render.PushRenderTarget(whiteboardRTs[entIndex].rt)
    render.OverrideAlphaWriteEnable(true, true)
    
    local success, err = pcall(function()
        cam.Start2D()
        render.Clear(0, 0, 0, 0)
        
        local drawData = whiteboardData[entIndex] and whiteboardData[entIndex].drawData
        if drawData then
            for i = 1, #drawData do
                local drawPoint = drawData[i]
                surface.SetDrawColor(drawPoint.color.r, drawPoint.color.g, drawPoint.color.b, 255)
                local radius = drawPoint.size or 8
                self:DrawCircle(drawPoint.x, drawPoint.y, radius/2, 16)
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

-- Оптимизированная функция рисования круга (для белых досок)
function ENT:DrawCircle(x, y, radius, segments)
    local poly = {}
    local segmentAngle = (2 * math_pi) / segments
    
    for i = 0, segments do
        local angle = i * segmentAngle
        poly[#poly + 1] = {
            x = x + math_cos(angle) * radius, 
            y = y + math_sin(angle) * radius
        }
    end
    
    surface.DrawPoly(poly)
end

function ENT:UpdateWhiteboardMaterial()
    local entIndex = self:EntIndex()
    if not whiteboardRTs[entIndex] or not whiteboardRTs[entIndex].mat then return end
    
    local mat = whiteboardRTs[entIndex].mat
    mat:SetTexture("$basetexture", whiteboardRTs[entIndex].rt)
    mat:Recompute()
end

-- Кэшированные значения для отрисовки
local draw_whiteboard_vectors = {
    halfWidth = 14.5,
    halfHeight = 21,
    pos_offset_forward = -13.6,
    pos_offset_right = 0.1,
    pos_offset_up = 49
}

function ENT:Draw()
    self:DrawModel()
    self:DrawWhiteboard()
    if self.DebugEnabled then
        self:DrawDebugInfo()
    end
end

function ENT:DrawWhiteboard()
    local entIndex = self:EntIndex()
    if not whiteboardRTs[entIndex] then return end
    
    local mat = whiteboardRTs[entIndex].mat
    if not mat then return end

    local pos = self:GetPos()
    local ang = self:GetAngles()
    ang:RotateAroundAxis(ang:Up(), 180)
    ang:RotateAroundAxis(ang:Right(), -9.6)
    local right = ang:Right()
    local up = ang:Up()
    local forward = ang:Forward()
    
    -- Применяем смещения
    pos = pos + forward * draw_whiteboard_vectors.pos_offset_forward
    pos = pos + right * draw_whiteboard_vectors.pos_offset_right
    pos = pos + up * draw_whiteboard_vectors.pos_offset_up
    
    local hw = draw_whiteboard_vectors.halfWidth
    local hh = draw_whiteboard_vectors.halfHeight
    
    -- Вычисляем углы доски
    local topLeft = pos + (up * hh) + (right * (-hw))
    local topRight = pos + (up * hh) + (right * hw)
    local bottomRight = pos + (up * (-hh)) + (right * hw)
    local bottomLeft = pos + (up * (-hh)) + (right * (-hw))
    
    render.SetMaterial(mat)
    render.DrawQuad(topLeft, topRight, bottomRight, bottomLeft)
end

function ENT:OnRemove()
    local entIndex = self:EntIndex()
    whiteboardRTs[entIndex] = nil
end
