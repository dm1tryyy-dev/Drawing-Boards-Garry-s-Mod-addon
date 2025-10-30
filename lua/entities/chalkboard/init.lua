AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/boards/chalkboard/chalkboard.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    -- self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_VPHYSICS)
    
    -- local phys = self:GetPhysicsObject()
    -- if IsValid(phys) then
    --     phys:EnableMotion(false)  -- Для статичных досок
    -- end
end