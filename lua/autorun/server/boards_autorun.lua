util.AddNetworkString("DrawingBoardsWelcome")

if SERVER then
    hook.Add("PlayerInitialSpawn", "WelcomeDrawingBoards", function(ply)
        if IsValid(ply) and ply:IsPlayer() then
            net.Start("DrawingBoardsWelcome")
            net.Send(ply)
        end
    end)
end