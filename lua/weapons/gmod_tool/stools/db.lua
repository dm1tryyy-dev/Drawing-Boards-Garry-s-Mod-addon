TOOL.Category = "Drawing Boards"
TOOL.Name = "#Boards"
TOOL.Command = nil
TOOL.ConfigName = ""


-- Типы досок
local BoardTypes = {
    ["chalkboard"] = {
        model = "models/boards/chalkboard/chalkboard.mdl",
        class = "chalkboard",
        static = true,
        has_light = true,
        wall_offset = 1.0
    },
    ["whiteboard"] = {
        model = "models/boards/whiteboard/whiteboard.mdl",
        class = "whiteboard",
        static = true,
        has_light = true,
        wall_offset = 1.0
    },
    ["little whiteboard"] = {
        model = "models/boards/little_whiteboard/little_whiteboard.mdl",
        class = "little_whiteboard",
        static = false,
        has_light = false,
        floor_offset = 5
    }
}

if CLIENT then
    language.Add("tool.db.name", "Drawing Boards")
    language.Add("tool.db.desc", "Spawn various drawing boards")
    language.Add("tool.db.0", "Left Click to spawn a board. Right click to change board type.")

    local ghostEntity = nil
    local lastBoardType = ""
end

-- ConVar
TOOL.ClientConVar = {
    ["type"] = "chalkboard",
    ["physics"] = "0",
    ["light"] = "0", 
    ["lr"] = "255",   
    ["lg"] = "255", 
    ["lb"] = "255",   
    ["brightness"] = "6",     
    ["distance"] = "200",
}


-- проверка на размещение
function CanPlaceOnSurface(trace, normalThreshold)
    if not trace.Hit then return false end
    
    local hitNormal = trace.HitNormal
    local dot = hitNormal:Dot(Vector(0, 0, 1))
    
    if math.abs(dot) > normalThreshold then
        return false
    end
    
    return true
end

-- позиция
function GetWallPosition(trace, wallOffset)
    local hitPos = trace.HitPos
    local hitNormal = trace.HitNormal
    return hitPos + hitNormal * wallOffset
end

-- угол
function GetWallAngles(trace)
    local hitNormal = trace.HitNormal
    return hitNormal:Angle()
end

-- Клиентская часть для призрачной модели
if CLIENT then
    local function GetCurrentBoardType()
        return GetConVar("db_type"):GetString() or "chalkboard"
    end
    
    function UpdateGhostEntity(ply)
        if not ply:Alive() then return end
        
        local trace = ply:GetEyeTrace()
        if not trace.Hit then
            if IsValid(ghostEntity) then
                ghostEntity:Remove()
            end
            return
        end
        
        local boardType = GetCurrentBoardType()
        local boardData = BoardTypes[boardType]
        if not boardData then return end
        if lastBoardType ~= boardType and IsValid(ghostEntity) then
            ghostEntity:Remove()
            ghostEntity = nil
        end
        lastBoardType = boardType
        if not IsValid(ghostEntity) then
            ghostEntity = ClientsideModel(boardData.model, RENDERGROUP_OTHER)
            if not IsValid(ghostEntity) then return end
            
            ghostEntity:SetNoDraw(true)
            ghostEntity:SetRenderMode(RENDERMODE_TRANSALPHA)
            ghostEntity:SetColor(Color(255, 255, 255, 100))
        end
        if boardData.static then
            local canPlace = CanPlaceOnSurface(trace, 0.3)
            
            if canPlace then
                local pos = GetWallPosition(trace, boardData.wall_offset)
                local ang = GetWallAngles(trace)
                
                ghostEntity:SetPos(pos)
                ghostEntity:SetAngles(ang)
                ghostEntity:SetNoDraw(false)
            else
                ghostEntity:SetNoDraw(true)
            end
        else
            local pos = trace.HitPos + Vector(0, 0, boardData.floor_offset)
            local ang = Angle(0, ply:EyeAngles().y + 180, 0)
            
            ghostEntity:SetPos(pos)
            ghostEntity:SetAngles(ang)
            ghostEntity:SetNoDraw(false)
        end
    end
    
    hook.Add("PostDrawOpaqueRenderables", "DrawingBoardsGhostRender", function()
        if not IsValid(ghostEntity) or ghostEntity:GetNoDraw() then return end
        
        render.SetBlend(0.4)
        render.SetColorModulation(1, 1, 1)
        ghostEntity:DrawModel()
        render.SetBlend(1)
        render.SetColorModulation(1, 1, 1)
    end)

    hook.Add("Think", "DrawingBoardsGhost", function()
        local ply = LocalPlayer()
        local weapon = ply:GetActiveWeapon()
        
        if not IsValid(weapon) or weapon:GetClass() ~= "gmod_tool" then
            if IsValid(ghostEntity) then
                ghostEntity:Remove()
                ghostEntity = nil
            end
            return
        end
        
        if weapon:GetMode() ~= "db" then
            if IsValid(ghostEntity) then
                ghostEntity:Remove()
                ghostEntity = nil
            end
            return
        end
        
        UpdateGhostEntity(ply)
    end)

    hook.Add("OnEndEntity", "DrawingBoardsCleanup", function()
        if IsValid(ghostEntity) then
            ghostEntity:Remove()
            ghostEntity = nil
        end
    end)
end

function TOOL:LeftClick(trace)
    if not trace.HitPos then return false end
    if CLIENT then return true end
    
    local ply = self:GetOwner()
    local boardType = self:GetClientInfo("type")
    local physicsEnabled = self:GetClientNumber("physics") == 1
    local boardData = BoardTypes[boardType]
    
    if not boardData then return false end
    if not util.IsValidModel(boardData.model) then
        ply:ChatPrint("Error: model not found!")
        return false
    end

    local ent = ents.Create(boardData.class)
    if not IsValid(ent) then return false end
    ent:SetModel(boardData.model)

    -- Получаем значения с новыми именами ConVar
    local lightEnabled = self:GetClientNumber("light") == 1
    local lightR = self:GetClientNumber("lr")
    local lightG = self:GetClientNumber("lg")
    local lightB = self:GetClientNumber("lb")
    local lightBrightness = self:GetClientNumber("brightness")
    local lightDistance = self:GetClientNumber("distance")
    
    ent:Spawn()
    ent:Activate()

    if boardData.has_light then
        if ent.SetLightEnabled then
            ent:SetLightEnabled(lightEnabled)
            ent:SetLightColor(Vector(lightR, lightG, lightB))
            ent:SetLightBrightness(lightBrightness)
            ent:SetLightDistance(lightDistance)
        end
    end

    local spawnPos, spawnAngles

    if boardData.static then
        if not CanPlaceOnSurface(trace, 0.3) then
            ply:ChatPrint("The board can only be placed on vertical walls!")
            ent:Remove()
            return false
        end

        spawnPos = trace.HitPos + trace.HitNormal * boardData.wall_offset
        spawnAngles = GetWallAngles(trace)
    else
        spawnPos = trace.HitPos + Vector(0, 0, boardData.floor_offset)
        spawnAngles = Angle(0, ply:EyeAngles().y + 180, 0)
    end

    ent:SetPos(spawnPos)
    ent:SetAngles(spawnAngles)

    if not boardData.static then
        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableMotion(true)
            phys:Wake()
        end
    else
        if physicsEnabled then
            ent:SetMoveType(MOVETYPE_VPHYSICS)
            local phys = ent:GetPhysicsObject()
            if IsValid(phys) then
                phys:EnableMotion(true)
                phys:Wake()
            end
        else
            ent:SetMoveType(MOVETYPE_NONE)
        end
        
        if trace.Entity and trace.Entity:IsValid() and trace.Entity:GetClass() ~= "worldspawn" then
            constraint.Weld(ent, trace.Entity, 0, trace.PhysicsBone, 0, true)
        end
    end

    undo.Create("Drawing Board")
        undo.AddEntity(ent)
        undo.SetPlayer(ply)
    undo.Finish()
    
    return true
end

function TOOL:RightClick(trace)
    if CLIENT then return true end
    
    local ply = self:GetOwner()
    local currentType = self:GetClientInfo("type")
    local types = table.GetKeys(BoardTypes)
    local currentIndex = table.KeyFromValue(types, currentType) or 1
    local nextIndex = currentIndex + 1
    
    if nextIndex > #types then
        nextIndex = 1
    end
    
    local nextType = types[nextIndex]
    ply:ConCommand("db_type " .. nextType)
    ply:ChatPrint("Type selected: " .. nextType)
    
    return true
end

function TOOL.BuildCPanel(CPanel)
    CPanel:AddControl("Header", {
        Text = "#tool.db.name",
        Description = "#tool.db.desc"
    })
    
    local propSelect = CPanel:AddControl("PropSelect", {
        Label = "Board Type",
        ConVar = "type",
        Category = "DrawingBoards",
        Models = {}
    })
    
    for name, data in pairs(BoardTypes) do
        propSelect:AddModel(data.model, {
            db_type = name
        })
    end
    
    CPanel:AddControl("Label", {
        Text = "Chalkboard/Whiteboard - wall mounted\nLittle Whiteboard - movable"
    })

    CPanel:ControlHelp("")
    
    CPanel:AddControl("CheckBox", {
        Label = "Enable Physics for Wall Boards",
        Command = "db_physics",
    })
    CPanel:ControlHelp("If enabled, wall boards will have physics and can fall.\nIf disabled, they will be welded in place.")
    CPanel:ControlHelp("")

    CPanel:AddControl("CheckBox", {
        Label = "Enable Light",
        Command = "db_light",
    })

    CPanel:AddControl("Color", {
        Label = "Light Color",
        Red = "db_lr",
        Green = "db_lg", 
        Blue = "db_lb",
        ShowAlpha = false,
        ShowHSV = true,
        ShowRGB = true,
    })
    CPanel:ControlHelp("")
    
    CPanel:AddControl("Slider", {
        Label = "Light Brightness",
        Command = "db_brightness",
        Type = "Integer",
        Min = 1,
        Max = 10,
    })

    CPanel:AddControl("Slider", {
        Label = "Light Distance", 
        Command = "db_distance",
        Type = "Integer",
        Min = 100,
        Max = 500,
    })
    CPanel:ControlHelp("")

    CPanel:AddControl("Button", {
        Label = "Reset Settings to Default",
        Command = "db_reset"
    })
    -- Быстрая очистка досок на всей карте через кнопку
    CPanel:AddControl("Button", {
        Label = "Cleanup All Boards",
        Command = "db_cleanup"
    })
    CPanel:ControlHelp("")
    CPanel:AddControl("Label", {
        Text = "To completely clear the boards, use these console commands:"
    })
    CPanel:ControlHelp("")
    CPanel:ControlHelp("chalk_clear - clears chalkboards")
    CPanel:ControlHelp("")
    CPanel:ControlHelp("marker_clear - clears whiteboards and little whiteboards")
    CPanel:ControlHelp("")
end

-- Очистка
if SERVER then
    cleanup.Register("db")
    for name, boardData in pairs(BoardTypes) do
        cleanup.Add(boardData.class, boardData.class, function(ent) 
            return true 
        end)
    end
    
    function ClearAllBoards(ply)
        local count = 0
        for _, boardData in pairs(BoardTypes) do
            for _, ent in pairs(ents.FindByClass(boardData.class)) do
                if IsValid(ent) then
                    ent:Remove()
                    count = count + 1
                end
            end
        end
        
        if ply:IsValid() then
            ply:ChatPrint("Cleared " .. count .. " boards!")
        end
    end
    
    concommand.Add("db_cleanup", function(ply)
        ClearAllBoards(ply)
    end)

    concommand.Add("db_reset", function(ply)
        ply:ConCommand("db_type chalkboard")
        ply:ConCommand("db_physics 0")
        ply:ConCommand("db_light 0")
        ply:ConCommand("db_lr 255")
        ply:ConCommand("db_lg 255")
        ply:ConCommand("db_lb 255")
        ply:ConCommand("db_brightness 6")
        ply:ConCommand("db_distance 200")
        ply:ChatPrint("Drawing Boards settings reset to default!")
    end)
end
