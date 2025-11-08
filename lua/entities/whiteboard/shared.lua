ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Whiteboard"
ENT.Author = "Err0X1s"
ENT.Category = ""
ENT.Spawnable = false
ENT.AdminSpawnable = false
ENT.RenderGroup = RENDERGROUP_OPAQUE

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

ENT = ENT or {}

function ENT:GetChalkboardBounds()
    -- Серверная версия
    local halfWidth = 37.85
    local halfHeight = 21.7
    
    return Vector(-2, -halfWidth, -halfHeight), Vector(2, halfWidth, halfHeight)
end

-- Заглушки для серверных функций
function ENT:DrawOnBoard(hitPos, color, size)
    if SERVER then

        print(string.format("[SERVER] Draw at %s with color %s", tostring(hitPos), tostring(color)))
    end
end

function ENT:EraseOnBoard(hitPos, size)
    if SERVER then
        print(string.format("[SERVER] Erase at %s", tostring(hitPos)))
    end
end