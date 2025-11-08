ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Whiteboard (Moveable)"
ENT.Author = "Err0X1s"
ENT.Category = ""
ENT.Spawnable = false
ENT.AdminSpawnable = false
ENT.RenderGroup = RENDERGROUP_OPAQUE

ENT = ENT or {}

function ENT:GetChalkboardBounds()
    -- Серверная версия
    local halfWidth = 14.5
	local halfHeight = 20.7
    
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