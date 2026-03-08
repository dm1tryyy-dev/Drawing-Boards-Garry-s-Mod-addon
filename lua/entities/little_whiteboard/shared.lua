ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Whiteboard (Moveable)"
ENT.Author = "Err0X1s"
ENT.Category = ""
ENT.Spawnable = false
ENT.AdminSpawnable = false
ENT.RenderGroup = RENDERGROUP_OPAQUE
DEFINE_BASECLASS("base_gmodentity")


cleanup.Register("little_whiteboards")
if SERVER then
    CreateConVar("sbox_maxlittle_whiteboards", 3, {FCVAR_NOTIFY, FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_PROTECTED})
end


function ENT:GetChalkboardBounds()
    -- Серверная версия
    local halfWidth = 14.5
	local halfHeight = 20.7
    
    return Vector(-2, -halfWidth, -halfHeight), Vector(2, halfWidth, halfHeight)
end

-- Заглушки для серверных функций
function ENT:DrawOnBoard(hitPos, color, size)
    if SERVER then

    end
end

function ENT:EraseOnBoard(hitPos, size)
    if SERVER then

    end
end
