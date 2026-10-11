-- ============================================================
-- DrawingGeometry: серверная часть
-- ============================================================

if not SERVER then return end

if not DrawingGeometry or not DrawingGeometry.IsValidBoard then
    include("autorun/geometry_shared.lua")
end

if not DrawingGeometry or not DrawingGeometry.IsValidBoard then
    print("[DB] ERROR: geometry_shared.lua not loaded!")
    return
end

util.AddNetworkString("DrawingGeometry_FinalizeShape")

net.Receive("DrawingGeometry_FinalizeShape", function(len, ply)
    if not IsValid(ply) then return end

    local board = net.ReadEntity()
    local mode  = net.ReadUInt(4)

    if not IsValid(board) then return end
    if not board.DrawOnBoard then return end

    local weapon = ply:GetActiveWeapon()
    if not IsValid(weapon) then return end

    local weaponClass = weapon:GetClass()
    if not DrawingGeometry.IsValidBoard(board, weaponClass) then return end

    local DRAW_DISTANCE = 200
    if ply:GetPos():DistToSqr(board:GetPos()) > DRAW_DISTANCE * DRAW_DISTANCE then
        return
    end

    local color = weapon.GetDrawColor and weapon:GetDrawColor() or Color(255, 255, 255)
    local size  = weapon.GetDrawSizeValue and weapon:GetDrawSizeValue() or 7

    local count = net.ReadUInt(16)
    if count == 0 or count > 2048 then return end

    local points = {}
    for i = 1, count do
        points[i] = net.ReadVector()
    end

    -- Принудительно сбрасываем последнюю позицию игрока на этой доске,
    -- чтобы первая точка фигуры не интерполировалась с предыдущим рисованием.
    if board.PlayerLastDrawPos and board.GetPlayerID then
        local pid = board:GetPlayerID(ply)
        board.PlayerLastDrawPos[pid] = nil
    end

    -- Локально на сервере
    local first = true
    for i = 1, count do
        board:DrawOnBoard(points[i], color, size, first, ply)
        first = false
    end

    -- Рассылаем другим игрокам через существующие сетевые каналы
    local netName = (weaponClass == "chalk_tool") and "ChalkDraw" or "MarkerDraw"
    local sizeByte = math.Clamp(math.floor(size), 0, 255)

    for _, other in ipairs(player.GetAll()) do
        if other ~= ply then
            local firstFlag = true
            for i = 1, count do
                net.Start(netName)
                    net.WriteEntity(board)
                    net.WriteVector(points[i])
                    net.WriteColor(color)
                    net.WriteUInt(sizeByte, 8)
                    net.WriteBool(firstFlag)
                net.Send(other)
                firstFlag = false
            end
        end
    end
end)