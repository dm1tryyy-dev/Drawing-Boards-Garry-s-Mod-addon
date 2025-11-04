include("shared.lua")

chalkboardRTs = chalkboardRTs or {}
chalkboardData = chalkboardData or {}


function ENT:Initialize()
    self.LampSprite = Material("sprites/light_glow02_add_noz")
    self:InitializeChalkboard()
    self.LastDrawPos = nil
    self.LastErasePos = nil
    
    -- ПОЛНАЯ ИНИЦИАЛИЗАЦИЯ ВСЕХ ПЕРЕМЕННЫХ
    self.immediateDrawBuffer = {}
    self.persistentDrawBuffer = {}
    self.immediateEraseBuffer = {}
    
    self.lastImmediateRedraw = 0
    self.lastFullRedraw = 0
    self.fullRedrawScheduled = false
    
    -- Настройки частоты
    self.immediateRedrawRate = 0.033 -- 30 FPS для мгновенного отображения
    self.fullRedrawRate = 0.1        -- 10 FPS для полной перерисовки
    self.maxPointsPerFrame = 20      -- Максимум точек за кадр

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
    chalkboardData[entIndex] = {
        drawData = {},
        eraseData = {}
    }
    
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
    

    self.immediateDrawBuffer = self.immediateDrawBuffer or {}
    self.persistentDrawBuffer = self.persistentDrawBuffer or {}
    self.immediateEraseBuffer = self.immediateEraseBuffer or {}
    self.lastImmediateRedraw = self.lastImmediateRedraw or 0
    self.lastFullRedraw = self.lastFullRedraw or 0
    self.maxPointsPerFrame = self.maxPointsPerFrame or 20
    self.immediateRedrawRate = self.immediateRedrawRate or 0.033
    self.fullRedrawRate = self.fullRedrawRate or 0.1
    
    render.PushRenderTarget(rt)
    render.Clear(0, 0, 0, 0)
    render.PopRenderTarget()
    
    self:UpdateChalkboardMaterial()
end

function ENT:ResetLastPosition()
    self.LastDrawPos = nil
end

function ENT:ResetLastErasePosition()
    self.LastErasePos = nil
end

function ENT:ClearChalkboard()
    local entIndex = self:EntIndex()
    if not chalkboardRTs[entIndex] then return end
    

    if not chalkboardData[entIndex] then
        chalkboardData[entIndex] = { drawData = {}, eraseData = {} }
    end
    
    chalkboardData[entIndex].drawData = {}
    chalkboardData[entIndex].eraseData = {}
    

    self.immediateDrawBuffer = {}
    self.persistentDrawBuffer = {}
    self.immediateEraseBuffer = {}
    
    render.PushRenderTarget(chalkboardRTs[entIndex].rt)
    render.Clear(0, 0, 0, 0)
    render.PopRenderTarget()
    
    self:UpdateChalkboardMaterial()
    self:ResetLastPosition()
    self:ResetLastErasePosition()
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


function ENT:DrawOnBoard(hitPos, color, size, isNewLine)
    if not IsValid(self) then return end
    
    local entIndex = self:EntIndex()
    if not chalkboardRTs[entIndex] then
        self:InitializeChalkboard()
        if not chalkboardRTs[entIndex] then return end
    end


    if not chalkboardData[entIndex] then
        chalkboardData[entIndex] = { drawData = {}, eraseData = {} }
    end
    if not chalkboardData[entIndex].drawData then
        chalkboardData[entIndex].drawData = {}
    end


    if not self.immediateDrawBuffer then self.immediateDrawBuffer = {} end
    if not self.persistentDrawBuffer then self.persistentDrawBuffer = {} end

    local localPos = self:WorldToLocal(hitPos)
    if not self:IsPointOnBoard(localPos) then return end
    
    local texCoordX, texCoordY = self:LocalToTextureCoords(localPos)
    local texSizeX, texSizeY = 1024, 1024
    local currentX = texCoordX * texSizeX
    local currentY = texCoordY * texSizeY
    local pointSize = size or 8

    -- Основная точка
    local newPoint = {
        x = currentX,
        y = currentY,
        color = color,
        size = pointSize
    }
    
    -- Добавление в оба буфера
    table.insert(chalkboardData[entIndex].drawData, newPoint)
    table.insert(self.persistentDrawBuffer, newPoint)
    table.insert(self.immediateDrawBuffer, newPoint)


    if self.LastDrawPos and not isNewLine then
        local lastX, lastY = self.LastDrawPos.x, self.LastDrawPos.y
        local dist = math.sqrt((currentX - lastX)^2 + (currentY - lastY)^2)
        
        if dist > 2 then
            local steps = math.max(2, math.floor(dist / 4))
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
                
                table.insert(chalkboardData[entIndex].drawData, linePoint)
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

    -- Стирание точек и добавление в буфер стирания
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
        local dist = math.sqrt((currentX - lastX)^2 + (currentY - lastY)^2)
        
        if dist > 2 then
            local steps = math.max(2, math.floor(dist / 4))
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
    if not chalkboardData[entIndex] or not chalkboardData[entIndex].drawData then return {} end
    
    local pointsToRemove = {}
    local erasedPoints = {}
    local radiusSquared = radius * radius
    

    for i, drawPoint in ipairs(chalkboardData[entIndex].drawData) do
        local distSquared = (drawPoint.x - x)^2 + (drawPoint.y - y)^2
        if distSquared <= radiusSquared then
            table.insert(pointsToRemove, i)
            table.insert(erasedPoints, drawPoint)
        end
    end
    

    for i = #pointsToRemove, 1, -1 do
        table.remove(chalkboardData[entIndex].drawData, pointsToRemove[i])
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
        self:ImmediateRedraw()
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
    if not chalkboardRTs[entIndex] then return end
    
    self.maxPointsPerFrame = self.maxPointsPerFrame or 20
    
    local success, err = pcall(function()
        render.PushRenderTarget(chalkboardRTs[entIndex].rt)
        render.OverrideAlphaWriteEnable(true, true)
        
        cam.Start2D()
        

        if #self.immediateEraseBuffer > 0 then

            for _, erasePoint in ipairs(self.immediateEraseBuffer) do
                local eraseRadius = erasePoint.radius
                local eraseArea = {
                    x = erasePoint.x - eraseRadius * 2,
                    y = erasePoint.y - eraseRadius * 2,
                    w = eraseRadius * 4,
                    h = eraseRadius * 4
                }
                

                surface.SetDrawColor(0, 0, 0, 0)
                surface.DrawRect(eraseArea.x, eraseArea.y, eraseArea.w, eraseArea.h)

                if chalkboardData[entIndex] and chalkboardData[entIndex].drawData then
                    for _, point in ipairs(chalkboardData[entIndex].drawData) do

                        local pointInRedrawArea = 
                            point.x >= eraseArea.x - point.size and 
                            point.x <= eraseArea.x + eraseArea.w + point.size and
                            point.y >= eraseArea.y - point.size and 
                            point.y <= eraseArea.y + eraseArea.h + point.size
                        
                        if pointInRedrawArea then
                            surface.SetDrawColor(point.color.r, point.color.g, point.color.b, 255)
                            surface.DrawRect(
                                math.Round(point.x - point.size/2), 
                                math.Round(point.y - point.size/2), 
                                point.size, 
                                point.size
                            )
                        end
                    end
                end
            end
            self.immediateEraseBuffer = {}
        end
        

        if #self.immediateDrawBuffer > 0 then
            local pointsToDraw = math.min(#self.immediateDrawBuffer, self.maxPointsPerFrame)
            for i = 1, pointsToDraw do
                local point = self.immediateDrawBuffer[i]
                surface.SetDrawColor(point.color.r, point.color.g, point.color.b, 255)
                surface.DrawRect(
                    math.Round(point.x - point.size/2), 
                    math.Round(point.y - point.size/2), 
                    point.size, 
                    point.size
                )
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
    
    self:UpdateChalkboardMaterial()
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

    if currentTime - self.lastFullRedraw >= self.fullRedrawRate then
        self:ScheduleFullRedraw()
        self.lastFullRedraw = currentTime
    end
end

function ENT:ScheduleFullRedraw()
    self.fullRedrawScheduled = self.fullRedrawScheduled or false
    
    if self.fullRedrawScheduled then return end
    
    self.fullRedrawScheduled = true
    
    timer.Simple(self.fullRedrawRate or 0.1, function()
        if IsValid(self) then
            self:FullRedraw()
        end
        self.fullRedrawScheduled = false
    end)
end

function ENT:FullRedraw()
    local entIndex = self:EntIndex()
    if not chalkboardRTs[entIndex] then return end

    self.persistentDrawBuffer = {}
    
    local success, err = pcall(function()
        render.PushRenderTarget(chalkboardRTs[entIndex].rt)
        render.OverrideAlphaWriteEnable(true, true)
        
        cam.Start2D()
        render.Clear(0, 0, 0, 0)
        
        if chalkboardData[entIndex] and chalkboardData[entIndex].drawData then
            for _, point in ipairs(chalkboardData[entIndex].drawData) do
                surface.SetDrawColor(point.color.r, point.color.g, point.color.b, 255)
                surface.DrawRect(
                    math.Round(point.x - point.size/2), 
                    math.Round(point.y - point.size/2), 
                    point.size, 
                    point.size
                )
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
    
    self:UpdateChalkboardMaterial()
end

function ENT:ForceRedraw()
    self.immediateDrawBuffer = self.immediateDrawBuffer or {}
    self.immediateEraseBuffer = self.immediateEraseBuffer or {}
    self.immediateDrawBuffer = {}
    self.immediateEraseBuffer = {}
    self:FullRedraw()
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

concommand.Add("chalk_clear", function(ply)
    local tr = ply:GetEyeTrace()
    if IsValid(tr.Entity) and tr.Entity:GetClass() == "chalkboard" then
        tr.Entity:ClearChalkboard()
        print("Chalkboard cleared!")
    else
        print("Look at a chalkboard to clear it!")
    end
end)

hook.Add("KeyRelease", "ChalkboardForceRedraw", function(ply, key)
    if key == IN_ATTACK or key == IN_ATTACK2 then
        local tr = ply:GetEyeTrace()
        if IsValid(tr.Entity) and tr.Entity:GetClass() == "chalkboard" then
            tr.Entity:ForceRedraw()
        end
    end
end)