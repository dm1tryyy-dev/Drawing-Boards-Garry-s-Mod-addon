ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Whiteboard (oversized)"
ENT.Author = "Err0X1s"
ENT.Category = ""
ENT.Spawnable = false
ENT.AdminSpawnable = false
ENT.RenderGroup = RENDERGROUP_OPAQUE
DEFINE_BASECLASS("base_gmodentity")

cleanup.Register("whiteboards_os")
if SERVER then
    CreateConVar("sbox_maxwhiteboards_os", 3, {FCVAR_NOTIFY, FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_PROTECTED})
end

-- Сеттеры для световых свойств
function ENT:SetupDataTables()
    self:NetworkVar("Bool", 0, "LightEnabled")
    self:NetworkVar("Vector", 0, "LightColor")
    self:NetworkVar("Float", 0, "LightBrightness")
    self:NetworkVar("Float", 1, "LightDistance")

	-- значения по умолчанию
	if SERVER then
		self:SetLightEnabled(true)
		self:SetLightColor(Vector(255, 255, 255))
		self:SetLightBrightness(6.0)
		self:SetLightDistance(200.0)
	end
end

function ENT:GetWhiteboardBounds()
    local halfWidth = 84.5
    local halfHeight = 48.4
    local DRAW_BOUNDS_OFFSET_X = 1

    return Vector(-2 + DRAW_BOUNDS_OFFSET_X, -halfWidth, -halfHeight), 
           Vector(2 + DRAW_BOUNDS_OFFSET_X, halfWidth, halfHeight)
end

-- function ENT:GetWhiteboardBounds()
--     if not self._cachedBounds then
--         local halfWidth = 84.5
--         local halfHeight = 48.4
--         local DRAW_BOUNDS_OFFSET_X = 1
--         local DRAW_BOUNDS_OFFSET_Y = -1
--         local DRAW_BOUNDS_OFFSET_Z = 1.4

        
--     return Vector(-2 + DRAW_BOUNDS_OFFSET_X, -halfWidth + DRAW_BOUNDS_OFFSET_Y, -halfHeight + DRAW_BOUNDS_OFFSET_Z),
--            Vector(2 + DRAW_BOUNDS_OFFSET_X, halfWidth + DRAW_BOUNDS_OFFSET_Y, halfHeight + DRAW_BOUNDS_OFFSET_Z)
-- end

-- Заглушки для серверных функций
function ENT:DrawOnBoard(hitPos, color, size)
    if SERVER then

    end
end

function ENT:EraseOnBoard(hitPos, size)
    if SERVER then

    end
end

