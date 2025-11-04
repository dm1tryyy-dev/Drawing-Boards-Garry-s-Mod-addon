include("shared.lua")

whiteboardRTs = whiteboardRTs or {}
whiteboardData = whiteboardData or {}

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
    self.LastDrawPos = nil
    self.LastErasePos = nil
    
    self.immediateDrawBuffer = {}
    self.persistentDrawBuffer = {}
    self.immediateEraseBuffer = {}
    
    self.lastImmediateRedraw = 0
    self.lastFullRedraw = 0
    self.fullRedrawScheduled = false
    
    self.immediateRedrawRate = 0.05
    self.fullRedrawRate = 0.3
    self.maxPointsPerFrame = 20
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
    
    self.immediateDrawBuffer = {}
    self.persistentDrawBuffer = {}
    self.immediateEraseBuffer = {}
    
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

    if not self.immediateDrawBuffer then self.immediateDrawBuffer = {} end
    if not self.persistentDrawBuffer then self.persistentDrawBuffer = {} end

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
        local lastX = self.LastDrawPos.x
        local lastY = self.LastDrawPos.y
        
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
        local lastX = self.LastErasePos.x
        local lastY = self.LastErasePos.y
        
        local dist = math_sqrt((currentX - lastX)^2 + (currentY - lastY)^2)
        
        if dist > 3 then
            local steps = math_max(2, math_floor(dist / 6))
            for i = 1, steps - 1 do
                local t = i / steps
                local lineX = lastX + (currentX - lastX) * t
                local lineY = lastY + (currentY - lastY) * t
                
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
        local distSquared = (drawPoint.x - x)^2 + (drawPoint.y - y)^2
        if distSquared <= radiusSquared then
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

hook.Add("KeyRelease", "WhiteboardForceRedraw", function(ply, key)
    if key == IN_ATTACK or key == IN_ATTACK2 then
        local tr = ply:GetEyeTrace()
        local ent = tr.Entity
        if IsValid(ent) and (ent:GetClass() == "little_whiteboard" or ent:GetClass() == "whiteboard") then
            ent:ForceRedraw()
        end
    end
end)