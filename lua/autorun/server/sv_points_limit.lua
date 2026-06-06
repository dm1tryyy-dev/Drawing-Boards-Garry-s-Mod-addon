util.AddNetworkString("DBPointLimit_Sync")
util.AddNetworkString("DBPointLimit_RequestStatus")
util.AddNetworkString("DBPointLimit_SetEnabled")
util.AddNetworkString("DBPointLimit_SetMax")
util.AddNetworkString("DBPointLimit_SendStatus")

-- Серверные ConVar
local limitEnabled = CreateConVar(
    "db_opt_limit_enabled",
    "0",
    FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY
)

local limitMax = CreateConVar(
    "db_opt_limit_max",
    "45000",
    FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY
)

local function SyncToPlayer(ply)
    if not IsValid(ply) then return end

    net.Start("DBPointLimit_Sync")
        net.WriteBool(limitEnabled:GetBool())
        net.WriteInt(limitMax:GetInt(), 32)
    net.Send(ply)
end

local function BroadcastSync()
    net.Start("DBPointLimit_Sync")
        net.WriteBool(limitEnabled:GetBool())
        net.WriteInt(limitMax:GetInt(), 32)
    net.Broadcast()
end

hook.Add("PlayerInitialSpawn", "DBPointLimit_SyncJoin", function(ply)
    SyncToPlayer(ply)
end)

cvars.AddChangeCallback("db_opt_limit_enabled", function(name, old, new)

    print(string.format(
        "[Drawing Boards] Point limit enabled changed: %s -> %s",
        old,
        new
    ))

    BroadcastSync()
end)

cvars.AddChangeCallback("db_opt_limit_max", function(name, old, new)

    local num = math.Clamp(
        tonumber(new) or 45000,
        100,
        500000
    )

    if tostring(num) ~= new then

        limitMax:SetInt(num)

        return
    end

    BroadcastSync()

end)

net.Receive("DBPointLimit_SetEnabled", function(_, ply)
    if not game.SinglePlayer() then
        if not IsValid(ply) or not ply:IsAdmin() then
            return
        end
    end

    local value = net.ReadBool()

    RunConsoleCommand(
        "db_opt_limit_enabled",
        value and "1" or "0"
    )

    print("[Drawing Boards] " .. ply:Nick() ..
        " set limit enabled = " .. tostring(value))
end)

net.Receive("DBPointLimit_SetMax", function(_, ply)
    if not game.SinglePlayer() then
        if not IsValid(ply) or not ply:IsAdmin() then
            return
        end
    end

    local value = math.Clamp(
        net.ReadInt(32),
        100,
        500000
    )

    RunConsoleCommand(
        "db_opt_limit_max",
        tostring(value)
    )

    print("[Drawing Boards] " .. ply:Nick() ..
        " set limit max = " .. value)
end)

net.Receive("DBPointLimit_RequestStatus", function(_, ply)
    if not IsValid(ply) then return end

    net.Start("DBPointLimit_SendStatus")
        net.WriteBool(limitEnabled:GetBool())
        net.WriteInt(limitMax:GetInt(), 32)
    net.Send(ply)
end)

print("[Drawing Boards] Point limit system loaded")