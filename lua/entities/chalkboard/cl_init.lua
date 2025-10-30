include("shared.lua")

chalkboardRTs = chalkboardRTs or {}
chalkboardData = chalkboardData or {}

function ENT:Initialize()
    self.LampSprite = Material("sprites/light_glow02_add_noz")
    self:InitializeChalkboard()
    self.LastDrawPos = nil
    self.LastErasePos = nil
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
    

    if chalkboardData[entIndex] then
        chalkboardData[entIndex].drawData = {}
        chalkboardData[entIndex].eraseData = {}
    end
    
    
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
    
    -- -- Синяя рамка для отладки
    -- render.SetColorMaterial()
    -- render.DrawLine(corners[1], corners[2], Color(0, 0, 255, 255), true)
    -- render.DrawLine(corners[2], corners[3], Color(0, 0, 255, 255), true)
    -- render.DrawLine(corners[3], corners[4], Color(0, 0, 255, 255), true)
    -- render.DrawLine(corners[4], corners[1], Color(0, 0, 255, 255), true)
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

    table.insert(chalkboardData[entIndex].drawData, {
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
                table.insert(chalkboardData[entIndex].drawData, {
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
    self:RedrawChalkboard()
end

function ENT:EraseOnBoard(hitPos, size, isNewLine)
    if not IsValid(self) then return end
    
    local entIndex = self:EntIndex()
    if not chalkboardRTs[entIndex] then return end
    

    if not chalkboardData[entIndex] then
        chalkboardData[entIndex] = { drawData = {}, eraseData = {} }
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
    self:RedrawChalkboard()
end

-- Вспомогательная функция для стирания в конкретной позиции
function ENT:EraseAtPosition(x, y, radius)
    local entIndex = self:EntIndex()
    if not chalkboardData[entIndex] or not chalkboardData[entIndex].drawData then return end
    
    local pointsToRemove = {}
    local radiusSquared = radius * radius
    
    for i, drawPoint in ipairs(chalkboardData[entIndex].drawData) do
        local distSquared = (drawPoint.x - x)^2 + (drawPoint.y - y)^2
        if distSquared <= radiusSquared then
            table.insert(pointsToRemove, i)
        end
    end
    

    for i = #pointsToRemove, 1, -1 do
        table.remove(chalkboardData[entIndex].drawData, pointsToRemove[i])
    end
end

function ENT:RedrawChalkboard()
    local entIndex = self:EntIndex()
    if not chalkboardRTs[entIndex] then return end
    
    render.PushRenderTarget(chalkboardRTs[entIndex].rt)
    render.OverrideAlphaWriteEnable(true, true)
    
    local success, err = pcall(function()
        cam.Start2D()
        render.Clear(0, 0, 0, 0)
        

        if chalkboardData[entIndex] and chalkboardData[entIndex].drawData then
            for _, drawPoint in ipairs(chalkboardData[entIndex].drawData) do
                surface.SetDrawColor(drawPoint.color.r, drawPoint.color.g, drawPoint.color.b, 255)
                local pointSize = drawPoint.size or 8
                surface.DrawRect(
                    math.Round(drawPoint.x - pointSize/2), 
                    math.Round(drawPoint.y - pointSize/2), 
                    pointSize, 
                    pointSize
                )
            end
        end
        
        cam.End2D()
    end)
    
    render.OverrideAlphaWriteEnable(false)
    render.PopRenderTarget()
    
    if not success then
        ErrorNoHalt("RedrawChalkboard error: " .. tostring(err) .. "\n")
        return
    end
    
    self:UpdateChalkboardMaterial()
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
    
    -- -- Зеленая рамка для отладки
    -- render.SetColorMaterial()
    -- render.DrawLine(topLeft, topRight, Color(0, 255, 0, 255))
    -- render.DrawLine(topRight, bottomRight, Color(0, 255, 0, 255))
    -- render.DrawLine(bottomRight, bottomLeft, Color(0, 255, 0, 255))
    -- render.DrawLine(bottomLeft, topLeft, Color(0, 255, 0, 255))
end


-- СВЕТОВЫЕ ФУНКЦИИ
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
