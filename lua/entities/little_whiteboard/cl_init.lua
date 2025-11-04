include("shared.lua")

whiteboardRTs = whiteboardRTs or {}
whiteboardData = whiteboardData or {}

local math_abs = math.abs
local math_clamp = math.Clamp
local math_sqrt = math.sqrt
local math_max = math.max
local math_min = math.min
local math_floor = math.floor
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
    self:InitializeWhiteboard()
    self.LastDrawPos = nil
    self.LastErasePos = nil
    self.DebugEnabled = false
    self.DebugPoint = nil
    self.DebugText = ""
    
    self.immediateDrawBuffer = {}
    self.persistentDrawBuffer = {}
    self.immediateEraseBuffer = {}
    
    self.lastImmediateRedraw = 0
    self.lastFullRedraw = 0
    self.fullRedrawScheduled = false
    
    self.immediateRedrawRate = 0.05
    self.fullRedrawRate = 0.3
    self.maxPointsPerFrame = 20
    
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
    
    self.immediateDrawBuffer = self.immediateDrawBuffer or {}
    self.persistentDrawBuffer = self.persistentDrawBuffer or {}
    self.immediateEraseBuffer = self.immediateEraseBuffer or {}
    self.lastImmediateRedraw = self.lastImmediateRedraw or 0
    self.lastFullRedraw = self.lastFullRedraw or 0
    self.maxPointsPerFrame = self.maxPointsPerFrame or 20
    
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

    self.immediateDrawBuffer = {}
    self.persistentDrawBuffer = {}
    self.immediateEraseBuffer = {}
    
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

    local newPoint = {
        x = currentX,
        y = currentY,
        color = color,
        size = pointSize
    }
    
    table.insert(whiteboardData[entIndex].drawData, newPoint)
    table.insert(self.persistentDrawBuffer, newPoint)
    table.insert(self.immediateDrawBuffer, newPoint)
    
    if self.LastDrawPos and not isNewLine then
        local lastX, lastY = self.LastDrawPos.x, self.LastDrawPos.y
        local dx, dy = currentX - lastX, currentY - lastY
        local dist = math_sqrt(dx * dx + dy * dy)
        
        if dist > 3 then
            local steps = math_max(2, math_floor(dist / 6))
            local stepX, stepY = dx / steps, dy / steps
            
            for i = 1, steps - 1 do
                local linePoint = {
                    x = lastX + stepX * i,
                    y = lastY + stepY * i,
                    color = color,
                    size = pointSize
                }
                
                table.insert(whiteboardData[entIndex].drawData, linePoint)
                table.insert(self.persistentDrawBuffer, linePoint)
                table.insert(self.immediateDrawBuffer, linePoint)
            end
        end
    end
    
    self.LastDrawPos = {x = currentX, y = currentY}
    
    self:ScheduleOptimizedRedraw()
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

    local erasedPoints = self:EraseAtPosition(currentX, currentY, eraseRadius)
    
    if #erasedPoints > 0 then
        table.insert(self.immediateEraseBuffer, {
            x = currentX,
            y = currentY,
            radius = eraseRadius,
            erasedPoints = erasedPoints
        })
    end

    if self.LastErasePos and not isNewLine then
        local lastX, lastY = self.LastErasePos.x, self.LastErasePos.y
        local dx, dy = currentX - lastX, currentY - lastY
        local dist = math_sqrt(dx * dx + dy * dy)
        
        if dist > 3 then
            local steps = math_max(2, math_floor(dist / 6))
            local stepX, stepY = dx / steps, dy / steps
            
            for iStep = 1, steps - 1 do
                local lineX = lastX + stepX * iStep
                local lineY = lastY + stepY * iStep
                
                local lineErased = self:EraseAtPosition(lineX, lineY, eraseRadius)
                if #lineErased > 0 then
                    table.insert(self.immediateEraseBuffer, {
                        x = lineX,
                        y = lineY,
                        radius = eraseRadius,
                        erasedPoints = lineErased
                    })
                end
            end
        end
    end
    
    self.LastErasePos = {x = currentX, y = currentY}
    
    self:ScheduleOptimizedRedraw()
end

function ENT:EraseAtPosition(x, y, radius)
    local entIndex = self:EntIndex()
    if not whiteboardData[entIndex] or not whiteboardData[entIndex].drawData then return {} end
    
    local pointsToRemove = {}
    local erasedPoints = {}
    local radiusSquared = radius * radius
    
    for i, drawPoint in ipairs(whiteboardData[entIndex].drawData) do
        local dx = drawPoint.x - x
        local dy = drawPoint.y - y
        if (dx * dx + dy * dy) <= radiusSquared then
            table.insert(pointsToRemove, i)
            table.insert(erasedPoints, drawPoint)
        end
    end
    
    for i = #pointsToRemove, 1, -1 do
        table.remove(whiteboardData[entIndex].drawData, pointsToRemove[i])
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
    
    if currentTime - self.lastFullRedraw >= self.fullRedrawRate then
        self:ScheduleFullRedraw()
        self.lastFullRedraw = currentTime
    end
end

function ENT:SmoothImmediateRedraw()
    if not self.immediateDrawBuffer then self.immediateDrawBuffer = {} end
    if not self.immediateEraseBuffer then self.immediateEraseBuffer = {} end
    
    if #self.immediateDrawBuffer == 0 and #self.immediateEraseBuffer == 0 then
        return
    end
    
    local entIndex = self:EntIndex()
    if not whiteboardRTs[entIndex] then return end
    
    self.maxPointsPerFrame = self.maxPointsPerFrame or 20
    
    local success, err = pcall(function()
        render.PushRenderTarget(whiteboardRTs[entIndex].rt)
        render.OverrideAlphaWriteEnable(true, true)
        
        cam.Start2D()
        
        if #self.immediateEraseBuffer > 0 then
            render.Clear(0, 0, 0, 0)
            
            if whiteboardData[entIndex] and whiteboardData[entIndex].drawData then
                for _, point in ipairs(whiteboardData[entIndex].drawData) do
                    surface.SetDrawColor(point.color.r, point.color.g, point.color.b, 255)
                    local radius = point.size or 8
                    self:DrawOptimizedCircle(point.x, point.y, radius/2)
                end
            end
            self.immediateEraseBuffer = {}
        end
        
        if #self.immediateDrawBuffer > 0 then
            local pointsToDraw = math_min(#self.immediateDrawBuffer, self.maxPointsPerFrame)
            for i = 1, pointsToDraw do
                local point = self.immediateDrawBuffer[i]
                surface.SetDrawColor(point.color.r, point.color.g, point.color.b, 255)
                local radius = point.size or 8
                self:DrawOptimizedCircle(point.x, point.y, radius/2)
            end
            
            for i = 1, pointsToDraw do
                table.remove(self.immediateDrawBuffer, 1)
            end
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
    
    timer.Simple(0.3, function()
        if IsValid(self) then
            self:FullRedraw()
        end
        self.fullRedrawScheduled = false
    end)
end

function ENT:FullRedraw()
    local entIndex = self:EntIndex()
    if not whiteboardRTs[entIndex] then return end
    
    self.persistentDrawBuffer = {}
    
    local success, err = pcall(function()
        render.PushRenderTarget(whiteboardRTs[entIndex].rt)
        render.OverrideAlphaWriteEnable(true, true)
        
        cam.Start2D()
        render.Clear(0, 0, 0, 0)
        
        if whiteboardData[entIndex] and whiteboardData[entIndex].drawData then
            for _, point in ipairs(whiteboardData[entIndex].drawData) do
                surface.SetDrawColor(point.color.r, point.color.g, point.color.b, 255)
                local radius = point.size or 8
                self:DrawOptimizedCircle(point.x, point.y, radius/2)
            end
        end
        
        cam.End2D()
        render.OverrideAlphaWriteEnable(false)
        render.PopRenderTarget()
    end)
    
    if not success then
        pcall(function() cam.End2D() end)
        pcall(function() render.OverrideAlphaWriteEnable(false) end)
        pcall(function() render.PopRenderTarget() end)
        ErrorNoHalt("FullRedraw error: " .. tostring(err) .. "\n")
        return
    end
    
    self:UpdateWhiteboardMaterial()
end

function ENT:ForceRedraw()
    self.immediateDrawBuffer = self.immediateDrawBuffer or {}
    self.immediateEraseBuffer = self.immediateEraseBuffer or {}
    self.immediateDrawBuffer = {}
    self.immediateEraseBuffer = {}
    self:FullRedraw()
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
    whiteboardRTs[entIndex] = nil
end