ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Tech Panel"
ENT.Author = "Err0X1s"
ENT.Category = ""
ENT.Spawnable = false
ENT.AdminSpawnable = false
ENT.RenderGroup = RENDERGROUP_OPAQUE
DEFINE_BASECLASS("base_gmodentity")

cleanup.Register("tech_panels")
if SERVER then
    CreateConVar("sbox_maxtechpanels", 3, {FCVAR_NOTIFY, FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_PROTECTED})
end

function ENT:SetupDataTables()
    self:NetworkVar("Bool", 0, "LightEnabled")
    self:NetworkVar("Vector", 0, "LightColor")
    self:NetworkVar("Float", 0, "LightBrightness")
    self:NetworkVar("Float", 1, "LightDistance")
    
    -- if SERVER then
    --     self:SetLightEnabled(true)
    --     self:SetLightColor(Vector(255, 255, 255))
    --     self:SetLightBrightness(6.0)
    --     self:SetLightDistance(200.0)
    -- end
end

function ENT:GetTechPanelBounds()
    local halfWidth = 37.85
    local halfHeight = 21.7
    
    return Vector(-2, -halfWidth, -halfHeight), Vector(2, halfWidth, halfHeight)
end

function ENT:DrawOnBoard(hitPos, color, size)
    if SERVER then

    end
end

function ENT:EraseOnBoard(hitPos, size)
    if SERVER then

    end
end