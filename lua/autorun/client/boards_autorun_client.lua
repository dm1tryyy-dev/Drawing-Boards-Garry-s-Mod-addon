net.Receive("DrawingBoardsWelcome", function()
    chat.AddText(Color(0,186,235), "Loading the addon Drawing Boards")
    chat.AddText(Color(235,98,10), "Welcome to the Drawing Boards", Color(0,186,235), " | ", Color(0,235,52), "Addon is active! Open it from the tools menu and let your creativity run wild!", Color(0,186,235))
end)

concommand.Add("db_limit_status", function()
    net.Start("DBPointLimit_RequestStatus")
    net.SendToServer()
end)

net.Receive("DBPointLimit_SendStatus", function()
    local enabled = net.ReadBool()
    local maxPoints = net.ReadInt(32)

    print(string.format(
        "[Drawing Boards] Point Limit: %s | Max Points: %d",
        enabled and "ENABLED" or "DISABLED",
        maxPoints
    ))
end)

DB_LIMIT_ENABLED = false
DB_LIMIT_MAX = 45000
DB_LIMIT_SYNCING = false

net.Receive("DBPointLimit_Sync", function()

    DB_LIMIT_SYNCING = true

    DB_LIMIT_ENABLED = net.ReadBool()
    DB_LIMIT_MAX = net.ReadInt(32)

    if IsValid(DB_LimitCheckbox) then
        DB_LimitCheckbox:SetValue(DB_LIMIT_ENABLED and 1 or 0)
    end

    if IsValid(DB_LimitNumberWang) then
        DB_LimitNumberWang:SetValue(DB_LIMIT_MAX)
        DB_LimitNumberWang:SetEnabled(DB_LIMIT_ENABLED)
    end

    DB_LIMIT_SYNCING = false

    print(string.format(
        "[Drawing Boards] Point limit synced: enabled=%s, max=%d",
        tostring(DB_LIMIT_ENABLED),
        DB_LIMIT_MAX
    ))
end)