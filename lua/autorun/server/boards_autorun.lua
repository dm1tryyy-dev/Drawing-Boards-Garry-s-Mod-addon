util.AddNetworkString("DrawingBoardsWelcome")

-- ==== ADDON SETTINGS ====
workshop_ids = {"3595295430"} --write IDs here

if SERVER and not game.SinglePlayer() then
    for _, id in pairs(workshop_ids) do
        if id and id ~= "" then resource.AddWorkshop(id) end
    end
end


if SERVER then
    print("######################################################################")
    print("    ***    Welcome to the Drawing Boards | Addon is active!    ***    ")
    print("######################################################################")
    
    hook.Add("PlayerInitialSpawn", "WelcomeDrawingBoards", function(ply)
        if IsValid(ply) and ply:IsPlayer() then
            timer.Simple(2, function()
                if IsValid(ply) then
                    net.Start("DrawingBoardsWelcome")
                    net.Send(ply)
                end
            end)
        end
    end)
end