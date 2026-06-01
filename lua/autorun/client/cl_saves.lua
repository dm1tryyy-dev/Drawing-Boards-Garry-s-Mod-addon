if CLIENT then
    BoardSaveSystem = BoardSaveSystem or {}
    BoardSaveSystem.SaveKey = KEY_F2
    BoardSaveSystem.LoadKey = KEY_F3
    BoardSaveSystem.UI = nil
    BoardSaveSystem.BlurBackground = nil
    BoardSaveSystem.CurrentBoard = nil
    BoardSaveSystem.CurrentSaves = {}
    BoardSaveSystem.CurrentWeaponType = nil
    BoardSaveSystem.PendingSaveName = nil
    BoardSaveSystem.LoadingPoints = nil
    BoardSaveSystem.IsSaving = false
    BoardSaveSystem.IsLoading = false
    BoardSaveSystem.ShouldRefreshUI = false
    BoardSaveSystem.SelectedSaves = {}
    BoardSaveSystem.LastClickTime = 0
    BoardSaveSystem.PendingLoads = {}
    BoardSaveSystem.LoadedCount = 0
    BoardSaveSystem.SelectedCountLabel = nil
    BoardSaveSystem.LoadSelectedBtn = nil
    BoardSaveSystem.DeleteSelectedBtn = nil

    if file.Exists("board_save_key.txt", "DATA") then
        local savedKey = tonumber(file.Read("board_save_key.txt", "DATA"))
        if savedKey then BoardSaveSystem.SaveKey = savedKey end
    end
    if file.Exists("board_load_key.txt", "DATA") then
        local savedKey = tonumber(file.Read("board_load_key.txt", "DATA"))
        if savedKey then BoardSaveSystem.LoadKey = savedKey end
    end

    BoardSaveSystem.Icons = {
        load = Material("vgui/icons/upload.png"),
        delete = Material("vgui/icons/delete-button.png"),
        refresh = Material("vgui/icons/refresh-arrow.png"),
        select_all = Material("vgui/icons/tick.png"),
        deselect_all = Material("vgui/icons/cross.png")
    }
    
    BoardSaveSystem.WeaponToBoards = {
        ["chalk"] = {"chalkboard", "chalkboard_oversized"},
        ["marker"] = {"whiteboard", "whiteboard_oversized", "little_whiteboard"}
    }
    
    surface.CreateFont("BoardSave_Title", {font = "Verdana", size = 22, weight = 700, antialias = true})
    surface.CreateFont("BoardSave_Label", {font = "Verdana", size = 16, weight = 600, antialias = true})
    surface.CreateFont("BoardSave_Button", {font = "Verdana", size = 15, weight = 600, antialias = true})
    surface.CreateFont("BoardSave_List", {font = "Verdana", size = 14, weight = 500, antialias = true})
    surface.CreateFont("BoardSave_Header", {font = "Verdana", size = 14, weight = 700, antialias = true})
    surface.CreateFont("BoardSave_Counter", {font = "Verdana", size = 16, weight = 700, antialias = true})
    surface.CreateFont("BoardSave_Path", {font = "Verdana", size = 13, weight = 500, antialias = true})

    function BoardSaveSystem.CompressPointsBinary(points)
        local buffer = {}
        local len = #points
        buffer[1] = string.char(bit.band(len, 0xFF), bit.band(bit.rshift(len, 8), 0xFF))
        for i, p in ipairs(points) do
            local x = math.min(65535, math.max(0, math.floor(p.x * 10 + 32768)))
            local y = math.min(65535, math.max(0, math.floor(p.y * 10 + 32768)))
            buffer[#buffer + 1] = string.char(bit.band(x, 0xFF), bit.band(bit.rshift(x, 8), 0xFF), bit.band(y, 0xFF), bit.band(bit.rshift(y, 8), 0xFF), p.r, p.g, p.b, p.w or 8, p.h or 8)
        end
        return table.concat(buffer)
    end
    
    function BoardSaveSystem.DecompressPointsBinary(data)
        if not data or #data < 2 then return {} end
        local points = {}
        local pos = 1
        local len = string.byte(data, pos) + string.byte(data, pos + 1) * 256
        pos = pos + 2
        for i = 1, len do
            if pos + 8 > #data then break end
            local x = string.byte(data, pos) + string.byte(data, pos + 1) * 256 - 32768
            local y = string.byte(data, pos + 2) + string.byte(data, pos + 3) * 256 - 32768
            local r = string.byte(data, pos + 4)
            local g = string.byte(data, pos + 5)
            local b = string.byte(data, pos + 6)
            local w = string.byte(data, pos + 7)
            local h = string.byte(data, pos + 8)
            pos = pos + 9
            table.insert(points, {x = x / 10, y = y / 10, r = r, g = g, b = b, w = w, h = h, playerID = "saved"})
        end
        return points
    end
    
    function BoardSaveSystem.SplitIntoChunks(data, chunkSize)
        local chunks = {}
        for i = 1, #data, chunkSize do
            table.insert(chunks, data:sub(i, math.min(i + chunkSize - 1, #data)))
        end
        return chunks
    end
    
    function BoardSaveSystem.ConvertPointsToSave(points)
        local savePoints = {}
        for _, point in ipairs(points) do
            if not point.__removed then
                table.insert(savePoints, {
                    x = point.x, y = point.y,
                    r = point.color.r, g = point.color.g, b = point.color.b,
                    w = point.w, h = point.h,
                    playerID = point.playerID or "unknown"
                })
            end
        end
        return savePoints
    end
    
    function BoardSaveSystem.UpdateSelectedCounter()
        local count = 0
        for _ in pairs(BoardSaveSystem.SelectedSaves) do count = count + 1 end
        if BoardSaveSystem.SelectedCountLabel and BoardSaveSystem.SelectedCountLabel:IsValid() then
            BoardSaveSystem.SelectedCountLabel:SetText(count .. " selected")
        end
        local enabled = (count >= 2)
        if BoardSaveSystem.LoadSelectedBtn and BoardSaveSystem.LoadSelectedBtn:IsValid() then
            BoardSaveSystem.LoadSelectedBtn:SetEnabled(enabled)
            BoardSaveSystem.LoadSelectedBtn:SetAlpha(enabled and 255 or 100)
        end
        if BoardSaveSystem.DeleteSelectedBtn and BoardSaveSystem.DeleteSelectedBtn:IsValid() then
            BoardSaveSystem.DeleteSelectedBtn:SetEnabled(enabled)
            BoardSaveSystem.DeleteSelectedBtn:SetAlpha(enabled and 255 or 100)
        end
    end
    
    function BoardSaveSystem.LoadPointsToBoard(board, points, merge)
        if not IsValid(board) then return end
        
        if board._loadingSave then
            board._loadQueue = board._loadQueue or {}
            table.insert(board._loadQueue, {points = points, merge = merge})
            return
        end
        
        board._loadingSave = true
        board._cancelLoad = false
        board._loadQueue = board._loadQueue or {}
        
        if not merge then
            board.drawPointsBuffer = {}
            board.drawGrid = {}
            board.drawQueue = {}
            board.PlayerDrawData = {}
            board.PlayerLastDrawPos = {}
            board.dirtyRegions = {}
            board.pointCounter = 0
        end
        
        local MAX_POINTS = 45000
        local pointsToLoad = points
        
        if #points > MAX_POINTS then
            pointsToLoad = {}
            local step = #points / MAX_POINTS
            for i = 0, MAX_POINTS - 1 do
                local idx = math.floor(1 + i * step)
                if idx <= #points then table.insert(pointsToLoad, points[idx]) end
            end
            notification.AddLegacy("Optimized " .. #points .. " points to " .. #pointsToLoad, NOTIFY_GENERIC, 3)
        end
        local batchPoints = {}
        
        local currentPoints = board.drawPointsBuffer or {}
        local startOrder = #currentPoints
        
        for i, pointData in ipairs(pointsToLoad) do
            local newPoint = {
                x = pointData.x, y = pointData.y,
                color = Color(pointData.r, pointData.g, pointData.b),
                w = pointData.w, h = pointData.h,
                playerID = pointData.playerID,
                timestamp = CurTime(),
                __removed = false,
                __order = startOrder + i
            }
            table.insert(currentPoints, newPoint)
            table.insert(batchPoints, newPoint)
        end
        
        board.drawPointsBuffer = currentPoints
        board.dirtyRegions = {}
        board.nextRedraw = 0
        
        local rtData = nil
        local entIndex = board:EntIndex()
        if not rtData and chalkboardRTs then rtData = chalkboardRTs[entIndex] end
        if not rtData and chalkboardOSRTs then rtData = chalkboardOSRTs[entIndex] end
        if not rtData and whiteboardRTs then rtData = whiteboardRTs[entIndex] end
        if not rtData and whiteboardOSRTs then rtData = whiteboardOSRTs[entIndex] end
        if not rtData and littleWhiteboardRTs then rtData = littleWhiteboardRTs[entIndex] end
        
        if not rtData or not rtData.rt then
            notification.AddLegacy("No RT found!", NOTIFY_ERROR, 3)
            board._loadingSave = false
            return
        end
        
        -- НЕ очищаем RT если merge (чтобы не стереть первую загрузку)
        if not merge then
            render.PushRenderTarget(rtData.rt)
            render.Clear(0, 0, 0, 0)
            render.PopRenderTarget()
        end
        
        local BATCH_SIZE = 200
        local totalBatches = math.ceil(#batchPoints / BATCH_SIZE)
        local currentBatch = 1
        
        local function DrawNextBatch()
            if board._cancelLoad then 
                board._loadingSave = false
                board._loadQueue = {}
                return 
            end
            if not IsValid(board) then return end
            if currentBatch > totalBatches then
                board._loadingSave = false
                if board.UpdateChalkboardMaterial then board:UpdateChalkboardMaterial() end
                if board.UpdateWhiteboardMaterial then board:UpdateWhiteboardMaterial() end
                if board.UpdateLittleWhiteboardMaterial then board:UpdateLittleWhiteboardMaterial() end
                
                if #board._loadQueue > 0 then
                    local nextLoad = table.remove(board._loadQueue, 1)
                    timer.Simple(0.1, function()
                        if IsValid(board) then
                            BoardSaveSystem.LoadPointsToBoard(board, nextLoad.points, nextLoad.merge)
                        end
                    end)
                end
                return
            end
            
            local startIdx = (currentBatch - 1) * BATCH_SIZE + 1
            local endIdx = math.min(startIdx + BATCH_SIZE - 1, #batchPoints)
            
            board.drawQueue = {}
            for i = startIdx, endIdx do
                table.insert(board.drawQueue, batchPoints[i])
            end
            
            if board.FlushDrawQueue then board:FlushDrawQueue()
            elseif board.DrawPointsOnRT then board:DrawPointsOnRT(board.drawQueue) end
            
            currentBatch = currentBatch + 1
            timer.Simple(0.005, DrawNextBatch)
        end
        
        timer.Simple(0.05, function()
            if IsValid(board) then
                DrawNextBatch()
            end
        end)
    end
    
    function BoardSaveSystem.DrawBlur(panel, layers, density, alpha)
        local blur = Material("pp/blurscreen")
        local x, y = panel:LocalToScreen(0, 0)
        surface.SetDrawColor(255, 255, 255, alpha or 255)
        surface.SetMaterial(blur)
        for i = 1, layers do
            blur:SetFloat("$blur", (i / layers) * density)
            blur:Recompute()
            render.UpdateScreenEffectTexture()
            surface.DrawTexturedRect(-x, -y, ScrW(), ScrH())
        end
    end
    
    function BoardSaveSystem.CreateBlurBackground()
        local blurPanel = vgui.Create("DPanel")
        blurPanel:SetSize(ScrW(), ScrH())
        blurPanel:SetPos(0, 0)
        blurPanel:SetZPos(-100)
        blurPanel:SetMouseInputEnabled(true)
        blurPanel.Paint = function(self, w, h)
            draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 180))
            BoardSaveSystem.DrawBlur(self, 3, 5, 255)
        end
        blurPanel.OnMousePressed = function() BoardSaveSystem.CloseMenu() end
        return blurPanel
    end
    
    function BoardSaveSystem.RequestSaves(weaponType)
        net.Start("BoardSave_RequestSaves")
        net.WriteString(weaponType or "")
        net.SendToServer()
    end
    
    function BoardSaveSystem.UploadSave(saveName, points, weaponType, boardClass, setPending)
        if BoardSaveSystem.IsSaving then
            notification.AddLegacy("Save already in progress...", NOTIFY_ERROR, 3)
            return
        end
        BoardSaveSystem.IsSaving = true
        if setPending ~= false then
            BoardSaveSystem.PendingSaveName = saveName
        end
        local binaryData = BoardSaveSystem.CompressPointsBinary(points)
        local CHUNK_SIZE = 64000
        local chunks = BoardSaveSystem.SplitIntoChunks(binaryData, CHUNK_SIZE)
        local totalChunks = #chunks
        local currentChunk = 1
        
        local function SendNextChunk()
            if currentChunk > totalChunks then
                timer.Simple(1, function() BoardSaveSystem.IsSaving = false end)
                return
            end
            local chunk = chunks[currentChunk]
            net.Start("BoardSave_UploadSaveChunk")
            net.WriteString(saveName)
            net.WriteUInt(#chunk, 16)
            net.WriteData(chunk, #chunk)
            net.WriteUInt(currentChunk, 16)
            net.WriteUInt(totalChunks, 16)
            net.WriteString(weaponType or "")
            net.WriteString(boardClass or "")
            net.WriteUInt(#points, 32)
            net.SendToServer()
            currentChunk = currentChunk + 1
            timer.Simple(0.1, SendNextChunk)
        end
        
        surface.PlaySound("buttons/button15.wav")
        SendNextChunk()
    end
    
    function BoardSaveSystem.RequestLoadSave(saveName, weaponType)
        if BoardSaveSystem.IsLoading then
            notification.AddLegacy("Load already in progress...", NOTIFY_ERROR, 3)
            return
        end
        BoardSaveSystem.IsLoading = true
        net.Start("BoardSave_LoadSave")
        net.WriteString(saveName)
        net.WriteString(weaponType or "")
        net.SendToServer()
    end
    
    function BoardSaveSystem.RequestDeleteSave(saveName, weaponType)
        net.Start("BoardSave_DeleteSave")
        net.WriteString(saveName)
        net.WriteString(weaponType or "")
        net.SendToServer()
    end
    
    function BoardSaveSystem.RequestClearAllSaves(weaponType)
        net.Start("BoardSave_ClearAllSaves")
        net.WriteString(weaponType or "")
        net.SendToServer()
    end
    
    net.Receive("BoardSave_SendSaves", function()
        BoardSaveSystem.CurrentSaves = net.ReadTable()
        if BoardSaveSystem.ShouldRefreshUI then
            if BoardSaveSystem.UI and BoardSaveSystem.UI:IsValid() and BoardSaveSystem.SavesRows then
                BoardSaveSystem.RefreshSavesList()
            end
            BoardSaveSystem.ShouldRefreshUI = false
        end
        if BoardSaveSystem.PendingSaveName then
            for _, save in ipairs(BoardSaveSystem.CurrentSaves) do
                if save.name == BoardSaveSystem.PendingSaveName then
                    notification.AddLegacy("✓ Saved: " .. BoardSaveSystem.PendingSaveName .. " (" .. (save.points or 0) .. " points)", NOTIFY_GENERIC, 3)
                    BoardSaveSystem.PendingSaveName = nil
                    break
                end
            end
        end
    end)
    
    net.Receive("BoardSave_SendDrawingChunk", function()
        local saveName = net.ReadString()
        local dataLen = net.ReadUInt(16)
        local chunkData = net.ReadData(dataLen)
        local chunkIndex = net.ReadUInt(16)
        local totalChunks = net.ReadUInt(16)
        
        if not BoardSaveSystem.LoadingPoints then
            BoardSaveSystem.LoadingPoints = {name = saveName, chunks = {}, total = totalChunks}
        end
        BoardSaveSystem.LoadingPoints.chunks[chunkIndex] = chunkData
        
        if table.Count(BoardSaveSystem.LoadingPoints.chunks) == totalChunks then
            local fullData = ""
            for i = 1, totalChunks do fullData = fullData .. (BoardSaveSystem.LoadingPoints.chunks[i] or "") end
            local points = BoardSaveSystem.DecompressPointsBinary(fullData)
            
            if IsValid(BoardSaveSystem.CurrentBoard) then
                local shouldMerge = false
                if BoardSaveSystem.PendingLoads and #BoardSaveSystem.PendingLoads > 0 then
                    shouldMerge = (BoardSaveSystem.LoadedCount > 0)
                    BoardSaveSystem.LoadedCount = BoardSaveSystem.LoadedCount + 1
                    for i, name in ipairs(BoardSaveSystem.PendingLoads) do
                        if name == saveName then table.remove(BoardSaveSystem.PendingLoads, i); break end
                    end
                end
                BoardSaveSystem.LoadPointsToBoard(BoardSaveSystem.CurrentBoard, points, shouldMerge)
                notification.AddLegacy("Loaded: " .. saveName .. " (" .. #points .. " points)", NOTIFY_GENERIC, 3)
                if BoardSaveSystem.PendingLoads and #BoardSaveSystem.PendingLoads > 0 then
                    timer.Simple(0.1, function()
                        BoardSaveSystem.RequestLoadSave(BoardSaveSystem.PendingLoads[1], BoardSaveSystem.CurrentWeaponType)
                    end)
                else
                    BoardSaveSystem.LoadedCount = 0
                    BoardSaveSystem.CloseMenu()
                end
            end
            BoardSaveSystem.LoadingPoints = nil
            BoardSaveSystem.IsLoading = false
        end
    end)
    
    function BoardSaveSystem.GetCurrentWeaponType()
        local ply = LocalPlayer()
        if not IsValid(ply) then return nil end
        local weapon = ply:GetActiveWeapon()
        if not IsValid(weapon) then return nil end
        local weaponName = weapon:GetPrintName() or ""
        if weaponName == "Chalk" then return "chalk"
        elseif weaponName == "Marker" then return "marker" end
        return nil
    end
    
    function BoardSaveSystem.GetValidBoardForWeapon(weaponType)
        if not weaponType then return nil end
        local ply = LocalPlayer()
        if not IsValid(ply) then return nil end
        local allowedClasses = BoardSaveSystem.WeaponToBoards[weaponType]
        if not allowedClasses then return nil end
        local eyeTrace = ply:GetEyeTrace()
        if not eyeTrace.Hit or not eyeTrace.Entity then return nil end
        local entClass = eyeTrace.Entity:GetClass()
        for _, class in ipairs(allowedClasses) do
            if entClass == class then return eyeTrace.Entity end
        end
        return nil
    end
    
    function BoardSaveSystem.GetBoardFromLook()
        local ply = LocalPlayer()
        if not IsValid(ply) then return nil end
        local eyeTrace = ply:GetEyeTrace()
        if not eyeTrace.Hit or not eyeTrace.Entity then return nil end
        local entClass = eyeTrace.Entity:GetClass()
        local allBoardClasses = {"chalkboard", "chalkboard_oversized", "whiteboard", "whiteboard_oversized", "little_whiteboard"}
        for _, class in ipairs(allBoardClasses) do
            if entClass == class then return eyeTrace.Entity end
        end
        return nil
    end
    
    function BoardSaveSystem.GetWeaponTypeFromBoard(board)
        if not IsValid(board) then return nil end
        local boardClass = board:GetClass()
        for weaponType, classes in pairs(BoardSaveSystem.WeaponToBoards) do
            for _, class in ipairs(classes) do
                if class == boardClass then return weaponType end
            end
        end
        return nil
    end
    
    function BoardSaveSystem.CanSave()
        local weaponType = BoardSaveSystem.GetCurrentWeaponType()
        if not weaponType then
            notification.AddLegacy("You need to hold a chalk or marker to save!", NOTIFY_ERROR, 3)
            return false, nil, nil
        end
        local board = BoardSaveSystem.GetValidBoardForWeapon(weaponType)
        if not IsValid(board) then
            if weaponType == "chalk" then
                notification.AddLegacy("Look at a chalkboard or oversized chalkboard to save!", NOTIFY_ERROR, 3)
            else
                notification.AddLegacy("Look at a whiteboard, oversized whiteboard, or little whiteboard to save!", NOTIFY_ERROR, 3)
            end
            return false, nil, nil
        end
        return true, board, weaponType
    end
    
    function BoardSaveSystem.CanLoad()
        local board = BoardSaveSystem.GetBoardFromLook()
        if not IsValid(board) then
            notification.AddLegacy("Look at any board to load drawings!", NOTIFY_ERROR, 3)
            return false, nil, nil
        end
        local weaponType = BoardSaveSystem.GetWeaponTypeFromBoard(board)
        if not weaponType then
            notification.AddLegacy("This board type is not supported!", NOTIFY_ERROR, 3)
            return false, nil, nil
        end
        return true, board, weaponType
    end
    
    function BoardSaveSystem.CloseMenu()
        if BoardSaveSystem.UI and BoardSaveSystem.UI:IsValid() then BoardSaveSystem.UI:Remove() BoardSaveSystem.UI = nil end
        if BoardSaveSystem.BlurBackground and BoardSaveSystem.BlurBackground:IsValid() then BoardSaveSystem.BlurBackground:Remove() BoardSaveSystem.BlurBackground = nil end
        BoardSaveSystem.SavesRows = nil
        BoardSaveSystem.SelectedSaves = {}
        BoardSaveSystem.PendingLoads = {}
        BoardSaveSystem.LoadedCount = 0
        BoardSaveSystem.SelectedCountLabel = nil
        BoardSaveSystem.LoadSelectedBtn = nil
        BoardSaveSystem.DeleteSelectedBtn = nil
    end
    
    function BoardSaveSystem.SaveCurrentDrawing()
        local canSave, board, weaponType = BoardSaveSystem.CanSave()
        if not canSave then return end
        BoardSaveSystem.CurrentBoard = board
        BoardSaveSystem.CurrentWeaponType = weaponType
        local points = board.drawPointsBuffer or {}
        local savePoints = BoardSaveSystem.ConvertPointsToSave(points)
        if #savePoints == 0 then
            notification.AddLegacy("Board is empty! Nothing to save.", NOTIFY_ERROR, 3)
            return
        end
        if ChalkMarkerUI and ChalkMarkerUI.BlockInput then ChalkMarkerUI.BlockInput(true) end
        
        local MAX_POINTS_PER_PART = 45000
        
        local frame = vgui.Create("DFrame")
        frame:SetSize(400, 170)
        frame:Center()
        frame:SetTitle("Save Drawing")
        frame:SetDraggable(true)
        frame:ShowCloseButton(true)
        frame:MakePopup()
        frame:SetDeleteOnClose(true)
        
        local label = vgui.Create("DLabel", frame)
        label:SetSize(380, 20)
        label:SetPos(10, 30)
        label:SetText("Enter a name for this drawing:")
        label:SetFont("BoardSave_Label")
        label:SetTextColor(Color(200, 200, 200))
        
        local textEntry = vgui.Create("DTextEntry", frame)
        textEntry:SetSize(380, 30)
        textEntry:SetPos(10, 55)
        textEntry:SetFont("BoardSave_Button")
        textEntry:SetText(os.date("drawing_%Y%m%d_%H%M%S"))
        textEntry:RequestFocus()
        
        local partsLabel = vgui.Create("DLabel", frame)
        partsLabel:SetSize(380, 20)
        partsLabel:SetPos(10, 90)
        if #savePoints > MAX_POINTS_PER_PART then
            local parts = math.ceil(#savePoints / MAX_POINTS_PER_PART)
            partsLabel:SetText("Will be saved in " .. parts .. " parts (".. #savePoints .. " points)")
        else
            partsLabel:SetText(#savePoints .. " points")
        end
        partsLabel:SetFont("BoardSave_Label")
        partsLabel:SetTextColor(Color(150, 150, 200))
        
        local function doSave()
            local saveName = textEntry:GetValue()
            if saveName and saveName ~= "" then
                if #savePoints > MAX_POINTS_PER_PART then
                    local parts = math.ceil(#savePoints / MAX_POINTS_PER_PART)
                    notification.AddLegacy("Saving " .. #savePoints .. " points in " .. parts .. " parts...", NOTIFY_GENERIC, 3)
                    for part = 1, parts do
                        BoardSaveSystem.IsSaving = false
                        local startIdx = (part - 1) * MAX_POINTS_PER_PART + 1
                        local endIdx = math.min(startIdx + MAX_POINTS_PER_PART - 1, #savePoints)
                        local partPoints = {}
                        for i = startIdx, endIdx do
                            table.insert(partPoints, savePoints[i])
                        end
                        local partName = part == 1 and saveName or (saveName .. "_" .. part)
                        notification.AddLegacy("✓ Saved: " .. partName .. " (" .. #partPoints .. " points)", NOTIFY_GENERIC, 3)
                        BoardSaveSystem.UploadSave(partName, partPoints, weaponType, board:GetClass(), false)
                    end
                else
                    notification.AddLegacy("Saving: " .. saveName .. " (" .. #savePoints .. " points)...", NOTIFY_GENERIC, 2)
                    BoardSaveSystem.PendingSaveName = saveName
                    BoardSaveSystem.UploadSave(saveName, savePoints, weaponType, board:GetClass(), true)
                end
                surface.PlaySound("buttons/button15.wav")
            end
            if ChalkMarkerUI and ChalkMarkerUI.BlockInput then ChalkMarkerUI.BlockInput(false) end
            frame:Close()
        end
        
        local saveBtn = vgui.Create("DButton", frame)
        saveBtn:SetSize(180, 35)
        saveBtn:SetPos(10, 120)
        saveBtn:SetText("Save")
        saveBtn:SetFont("BoardSave_Button")
        saveBtn.Paint = function(self, w, h)
            local color = self:IsHovered() and Color(70, 160, 255, 220) or Color(70, 130, 200, 180)
            draw.RoundedBox(6, 0, 0, w, h, color)
            draw.SimpleText("Save", "BoardSave_Button", w/2, h/2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        saveBtn.DoClick = doSave
        
        local cancelBtn = vgui.Create("DButton", frame)
        cancelBtn:SetSize(180, 35)
        cancelBtn:SetPos(210, 120)
        cancelBtn:SetText("Cancel")
        cancelBtn:SetFont("BoardSave_Button")
        cancelBtn.Paint = function(self, w, h)
            local color = self:IsHovered() and Color(120, 120, 120, 220) or Color(90, 90, 90, 180)
            draw.RoundedBox(6, 0, 0, w, h, color)
            draw.SimpleText("Cancel", "BoardSave_Button", w/2, h/2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        cancelBtn.DoClick = function()
            if ChalkMarkerUI and ChalkMarkerUI.BlockInput then ChalkMarkerUI.BlockInput(false) end
            frame:Close()
        end
        
        textEntry.OnEnter = doSave
        frame.OnClose = function()
            if ChalkMarkerUI and ChalkMarkerUI.BlockInput then ChalkMarkerUI.BlockInput(false) end
        end
    end
    
    function BoardSaveSystem.OpenLoadMenu()
        local canLoad, board, weaponType = BoardSaveSystem.CanLoad()
        if not canLoad then return end
        BoardSaveSystem.CloseMenu()
        BoardSaveSystem.CurrentBoard = board
        BoardSaveSystem.CurrentWeaponType = weaponType
        BoardSaveSystem.SelectedSaves = {}
        BoardSaveSystem.BlurBackground = BoardSaveSystem.CreateBlurBackground()
        BoardSaveSystem.ShouldRefreshUI = true
        BoardSaveSystem.RequestSaves(weaponType)
        
        local frame = vgui.Create("DFrame")
        BoardSaveSystem.UI = frame
        frame:SetSize(725, 680)
        frame:Center()
        frame:SetTitle("")
        frame:SetDraggable(true)
        frame:ShowCloseButton(false)
        frame:SetDeleteOnClose(false)
        frame:MakePopup()
        frame:SetZPos(100)
        
        frame.Paint = function(self, w, h)
            draw.RoundedBox(16, 0, 0, w, h, Color(30, 35, 45, 230))
            draw.RoundedBox(16, 0, 0, w, h, Color(255, 255, 255, 10))
            local title = weaponType == "chalk" and "Chalk Drawings" or "Marker Drawings"
            draw.SimpleText(title, "BoardSave_Title", w/2, 28, Color(240, 240, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            local boardClass = board:GetClass() or "Unknown"
            draw.SimpleText("Target board: " .. boardClass, "BoardSave_Label", w/2, 60, Color(150, 150, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText("IMPORTANT: Loaded drawings cannot be edited (erased) locally.", "BoardSave_Button", w/2, 88, Color(255, 200, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        
        local clearAllBtn = vgui.Create("DButton", frame)
        clearAllBtn:SetSize(110, 35)
        clearAllBtn:SetPos(20, 12)
        clearAllBtn:SetText("Clear all")
        clearAllBtn:SetFont("BoardSave_Button")
        clearAllBtn.Paint = function(self, w, h)
            local color = self:IsHovered() and Color(255, 80, 80, 220) or Color(200, 60, 60, 180)
            draw.RoundedBox(8, 0, 0, w, h, color)
            draw.SimpleText("Clear all", "BoardSave_Button", w/2, h/2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        clearAllBtn.DoClick = function()
            Derma_Query("Delete ALL " .. (weaponType == "chalk" and "chalk" or "marker") .. " drawings?",
                "WARNING: DELETE ALL SAVES",
                "Yes", function()
                    BoardSaveSystem.RequestClearAllSaves(weaponType)
                    BoardSaveSystem.ShouldRefreshUI = true
                    BoardSaveSystem.RequestSaves(weaponType)
                    surface.PlaySound("buttons/button10.wav")
                    BoardSaveSystem.SelectedSaves = {}
                    BoardSaveSystem.UpdateSelectedCounter()
                end,
                "No", function() end)
        end

        local selectAllBtn = vgui.Create("DButton", frame)
        selectAllBtn:SetSize(40, 35)
        selectAllBtn:SetPos(140, 12)
        selectAllBtn:SetText("")
        selectAllBtn.Paint = function(self, w, h)
            local color = self:IsHovered() and Color(100, 100, 100, 220) or Color(80, 80, 80, 180)
            draw.RoundedBox(8, 0, 0, w, h, color)
            if BoardSaveSystem.Icons.select_all and not BoardSaveSystem.Icons.select_all:IsError() then
                surface.SetMaterial(BoardSaveSystem.Icons.select_all)
                surface.SetDrawColor(255, 255, 255, 255)
                surface.DrawTexturedRect(8, 6, 24, 24)
            else draw.SimpleText("✓", "BoardSave_Title", w/2, h/2 - 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER) end
        end
        selectAllBtn.DoClick = function()
            BoardSaveSystem.SelectedSaves = {}
            if BoardSaveSystem.CurrentSaves then
                for _, save in ipairs(BoardSaveSystem.CurrentSaves) do BoardSaveSystem.SelectedSaves[save.name] = true end
            end
            BoardSaveSystem.UpdateSelectedCounter()
            surface.PlaySound("garrysmod/ui_click.wav")
        end

        local deselectAllBtn = vgui.Create("DButton", frame)
        deselectAllBtn:SetSize(40, 35)
        deselectAllBtn:SetPos(190, 12)
        deselectAllBtn:SetText("")
        deselectAllBtn.Paint = function(self, w, h)
            local color = self:IsHovered() and Color(100, 100, 100, 220) or Color(80, 80, 80, 180)
            draw.RoundedBox(8, 0, 0, w, h, color)
            if BoardSaveSystem.Icons.deselect_all and not BoardSaveSystem.Icons.deselect_all:IsError() then
                surface.SetMaterial(BoardSaveSystem.Icons.deselect_all)
                surface.SetDrawColor(255, 255, 255, 255)
                surface.DrawTexturedRect(8, 6, 24, 24)
            else draw.SimpleText("✗", "BoardSave_Title", w/2, h/2 - 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER) end
        end
        deselectAllBtn.DoClick = function()
            BoardSaveSystem.SelectedSaves = {}
            BoardSaveSystem.UpdateSelectedCounter()
            surface.PlaySound("garrysmod/ui_click.wav")
        end
        
        local refreshBtn = vgui.Create("DButton", frame)
        refreshBtn:SetSize(35, 35)
        refreshBtn:SetPos(frame:GetWide() - 95, 12)
        refreshBtn:SetText("")
        refreshBtn.Paint = function(self, w, h)
            local color = self:IsHovered() and Color(100, 100, 100, 220) or Color(80, 80, 80, 180)
            draw.RoundedBox(8, 0, 0, w, h, color)
            if BoardSaveSystem.Icons.refresh and not BoardSaveSystem.Icons.refresh:IsError() then
                surface.SetMaterial(BoardSaveSystem.Icons.refresh)
                surface.SetDrawColor(255, 255, 255, 255)
                surface.DrawTexturedRect(6, 6, w - 12, h - 12)
            else draw.SimpleText("⟳", "BoardSave_Title", w/2, h/2 - 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER) end
        end
        refreshBtn.DoClick = function()
            BoardSaveSystem.ShouldRefreshUI = true
            BoardSaveSystem.RequestSaves(weaponType)
            BoardSaveSystem.SelectedSaves = {}
            BoardSaveSystem.UpdateSelectedCounter()
            surface.PlaySound("garrysmod/ui_click.wav")
        end
        
        local closeBtn = vgui.Create("DButton", frame)
        closeBtn:SetSize(35, 35)
        closeBtn:SetPos(frame:GetWide() - 48, 12)
        closeBtn:SetText("")
        closeBtn.Paint = function(self, w, h)
            local bgColor = self:IsHovered() and Color(255, 50, 50, 180) or Color(80, 80, 80, 180)
            draw.RoundedBox(8, 0, 0, w, h, bgColor)
            draw.SimpleText("×", "BoardSave_Title", w/2, h/2 - 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        closeBtn.DoClick = function() surface.PlaySound("garrysmod/ui_click.wav") BoardSaveSystem.CloseMenu() end
        
        local headerPanel = vgui.Create("DPanel", frame)
        headerPanel:SetSize(680, 30)
        headerPanel:SetPos(25, 105)
        headerPanel.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(60, 65, 75, 220))
            draw.RoundedBox(4, 0, 0, w, h, Color(255, 255, 255, 10))
        end
        
        local nameHeader = vgui.Create("DLabel", headerPanel)
        nameHeader:SetSize(400, 30)
        nameHeader:SetPos(15, 0)
        nameHeader:SetText("Drawing Name & Date")
        nameHeader:SetFont("BoardSave_Header")
        nameHeader:SetTextColor(Color(220, 220, 220))
        nameHeader:SetContentAlignment(4)
        
        local pointsHeader = vgui.Create("DLabel", headerPanel)
        pointsHeader:SetSize(100, 30)
        pointsHeader:SetPos(450, 0)
        pointsHeader:SetText("Points")
        pointsHeader:SetFont("BoardSave_Header")
        pointsHeader:SetTextColor(Color(220, 220, 220))
        pointsHeader:SetContentAlignment(5)
        
        local actionsHeader = vgui.Create("DLabel", headerPanel)
        actionsHeader:SetSize(100, 30)
        actionsHeader:SetPos(565, 0)
        actionsHeader:SetText("Actions")
        actionsHeader:SetFont("BoardSave_Header")
        actionsHeader:SetTextColor(Color(220, 220, 220))
        actionsHeader:SetContentAlignment(5)
        
        local loadSelectedBtn = vgui.Create("DButton", frame)
        loadSelectedBtn:SetSize(160, 40)
        loadSelectedBtn:SetPos(25, 595)
        loadSelectedBtn:SetText("")
        loadSelectedBtn:SetFont("BoardSave_Button")
        loadSelectedBtn:SetEnabled(false)
        loadSelectedBtn:SetAlpha(100)
        loadSelectedBtn.Paint = function(self, w, h)
            local color
            if self:IsEnabled() then color = self:IsHovered() and Color(70, 160, 255, 220) or Color(70, 130, 200, 180)
            else color = Color(60, 60, 60, 150) end
            draw.RoundedBox(8, 0, 0, w, h, color)
            if BoardSaveSystem.Icons.load and not BoardSaveSystem.Icons.load:IsError() then
                surface.SetMaterial(BoardSaveSystem.Icons.load)
                surface.SetDrawColor(255, 255, 255, self:IsEnabled() and 255 or 100)
                surface.DrawTexturedRect(8, 8, 24, 24)
            end
            draw.SimpleText("Load selected", "BoardSave_Button", 40, h/2, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        loadSelectedBtn.DoClick = function()
            if not loadSelectedBtn:IsEnabled() then return end
            local selected = {}
            for saveName, _ in pairs(BoardSaveSystem.SelectedSaves) do table.insert(selected, saveName) end
            if #selected >= 2 then
                BoardSaveSystem.PendingLoads = {}
                for _, name in ipairs(selected) do table.insert(BoardSaveSystem.PendingLoads, name) end
                BoardSaveSystem.LoadedCount = 0
                BoardSaveSystem.RequestLoadSave(BoardSaveSystem.PendingLoads[1], weaponType)
                surface.PlaySound("garrysmod/ui_click.wav")
            end
        end
        
        local counterLabel = vgui.Create("DLabel", frame)
        counterLabel:SetSize(200, 40)
        counterLabel:SetPos(frame:GetWide() / 2 - 100, 595)
        counterLabel:SetText("0 selected")
        counterLabel:SetFont("BoardSave_Counter")
        counterLabel:SetTextColor(Color(100, 150, 255))
        counterLabel:SetContentAlignment(5)
        BoardSaveSystem.SelectedCountLabel = counterLabel
        
        local deleteSelectedBtn = vgui.Create("DButton", frame)
        deleteSelectedBtn:SetSize(165, 40)
        deleteSelectedBtn:SetPos(frame:GetWide() - 185, 595)
        deleteSelectedBtn:SetText("")
        deleteSelectedBtn:SetFont("BoardSave_Button")
        deleteSelectedBtn:SetEnabled(false)
        deleteSelectedBtn:SetAlpha(100)
        deleteSelectedBtn.Paint = function(self, w, h)
            local color
            if self:IsEnabled() then color = self:IsHovered() and Color(255, 80, 80, 220) or Color(200, 60, 60, 180)
            else color = Color(100, 40, 40, 150) end
            draw.RoundedBox(8, 0, 0, w, h, color)
            if BoardSaveSystem.Icons.delete and not BoardSaveSystem.Icons.delete:IsError() then
                surface.SetMaterial(BoardSaveSystem.Icons.delete)
                surface.SetDrawColor(255, 255, 255, self:IsEnabled() and 255 or 100)
                surface.DrawTexturedRect(8, 8, 24, 24)
            end
            draw.SimpleText("Delete selected", "BoardSave_Button", 40, h/2, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        deleteSelectedBtn.DoClick = function()
            if not deleteSelectedBtn:IsEnabled() then return end
            local selected = {}
            for saveName, _ in pairs(BoardSaveSystem.SelectedSaves) do table.insert(selected, saveName) end
            if #selected >= 2 then
                Derma_Query("Delete " .. #selected .. " drawings?", "Confirm Delete",
                    "Yes", function()
                        for _, name in ipairs(selected) do BoardSaveSystem.RequestDeleteSave(name, weaponType) end
                        timer.Simple(0.5, function()
                            BoardSaveSystem.ShouldRefreshUI = true
                            BoardSaveSystem.RequestSaves(weaponType)
                            BoardSaveSystem.SelectedSaves = {}
                            BoardSaveSystem.UpdateSelectedCounter()
                        end)
                        surface.PlaySound("buttons/button14.wav")
                    end,
                    "No", function() end)
            end
        end
        
        BoardSaveSystem.LoadSelectedBtn = loadSelectedBtn
        BoardSaveSystem.DeleteSelectedBtn = deleteSelectedBtn
        
        local scrollPanel = vgui.Create("DScrollPanel", frame)
        scrollPanel:SetSize(680, 440)
        scrollPanel:SetPos(25, 138)
        scrollPanel.Paint = function(self, w, h) draw.RoundedBox(8, 0, 0, w, h, Color(40, 45, 55, 200)) end
        
        local listContainer = vgui.Create("DPanel", scrollPanel)
        listContainer:SetSize(670, 100)
        listContainer.Paint = function() end
        BoardSaveSystem.SavesRows = {}
        
        function BoardSaveSystem.RefreshSavesList()
            if not IsValid(listContainer) then return end
            for _, row in ipairs(BoardSaveSystem.SavesRows) do if IsValid(row) then row:Remove() end end
            BoardSaveSystem.SavesRows = {}
            if not BoardSaveSystem.CurrentSaves or #BoardSaveSystem.CurrentSaves == 0 then
                local emptyLabel = vgui.Create("DLabel", listContainer)
                emptyLabel:SetSize(670, 60) emptyLabel:SetPos(0, 20)
                emptyLabel:SetText("No saved drawings found!")
                emptyLabel:SetFont("BoardSave_Label") emptyLabel:SetTextColor(Color(150, 150, 150)) emptyLabel:SetContentAlignment(5)
                table.insert(BoardSaveSystem.SavesRows, emptyLabel)
                listContainer:SetTall(100) return
            end
            table.sort(BoardSaveSystem.CurrentSaves, function(a, b) return (a.timestamp or 0) > (b.timestamp or 0) end)
            local rowHeight = 60
            local totalHeight = #BoardSaveSystem.CurrentSaves * rowHeight + 10
            listContainer:SetTall(totalHeight) scrollPanel:InvalidateLayout()
            for i, save in ipairs(BoardSaveSystem.CurrentSaves) do
                local yPos = (i - 1) * rowHeight + 5
                local rowPanel = vgui.Create("DPanel", listContainer)
                rowPanel:SetSize(650, 55) rowPanel:SetPos(15, yPos)
                rowPanel.SaveName = save.name
                rowPanel.Paint = function(self, w, h)
                    if BoardSaveSystem.SelectedSaves[self.SaveName] then draw.RoundedBox(6, 0, 0, w, h, Color(70, 130, 200, 100))
                    elseif self:IsHovered() then draw.RoundedBox(6, 0, 0, w, h, Color(70, 130, 200, 60)) end
                    draw.RoundedBox(6, 0, 0, w, h, Color(50, 55, 65, 180))
                end
                rowPanel.OnMousePressed = function(self, code)
                    if code == MOUSE_LEFT then
                        local ctrlDown = input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL)
                        local shiftDown = input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT)
                        
                        if shiftDown then
                            local lastSelectedIdx = nil
                            for idx, row in ipairs(BoardSaveSystem.SavesRows) do
                                if IsValid(row) and BoardSaveSystem.SelectedSaves[row.SaveName] then
                                    lastSelectedIdx = idx
                                end
                            end
                            
                            local currentIdx = nil
                            for idx, row in ipairs(BoardSaveSystem.SavesRows) do
                                if IsValid(row) and row.SaveName == self.SaveName then
                                    currentIdx = idx
                                    break
                                end
                            end
                            
                            if lastSelectedIdx and currentIdx then
                                local startIdx = math.min(lastSelectedIdx, currentIdx)
                                local endIdx = math.max(lastSelectedIdx, currentIdx)
                                BoardSaveSystem.SelectedSaves = {}
                                for idx = startIdx, endIdx do
                                    local row = BoardSaveSystem.SavesRows[idx]
                                    if IsValid(row) then
                                        BoardSaveSystem.SelectedSaves[row.SaveName] = true
                                        row.Selected = true
                                    end
                                end
                            end
                        elseif ctrlDown then
                            if BoardSaveSystem.SelectedSaves[self.SaveName] then
                                BoardSaveSystem.SelectedSaves[self.SaveName] = nil
                                self.Selected = false
                            else
                                BoardSaveSystem.SelectedSaves[self.SaveName] = true
                                self.Selected = true
                            end
                        else
                            -- Одиночное выделение
                            BoardSaveSystem.SelectedSaves = {}
                            for _, row in ipairs(BoardSaveSystem.SavesRows) do
                                if IsValid(row) then row.Selected = false end
                            end
                            BoardSaveSystem.SelectedSaves[self.SaveName] = true
                            self.Selected = true
                        end

                        for _, row in ipairs(BoardSaveSystem.SavesRows) do
                            if IsValid(row) then
                                row.Selected = BoardSaveSystem.SelectedSaves[row.SaveName] == true
                            end
                        end
                        BoardSaveSystem.UpdateSelectedCounter()
                    end
                end

                local nameLabel = vgui.Create("DLabel", rowPanel)
                nameLabel:SetSize(350, 25) nameLabel:SetPos(15, 8) nameLabel:SetText(save.name)
                nameLabel:SetFont("BoardSave_Label") nameLabel:SetTextColor(Color(255, 255, 255)) nameLabel:SetContentAlignment(4)

                local dateLabel = vgui.Create("DLabel", rowPanel)
                dateLabel:SetSize(350, 20) dateLabel:SetPos(15, 30)
                dateLabel:SetText(os.date("%Y-%m-%d %H:%M:%S", save.timestamp))

                dateLabel:SetFont("BoardSave_List") dateLabel:SetTextColor(Color(150, 150, 150)) dateLabel:SetContentAlignment(4)
                local pointsLabel = vgui.Create("DLabel", rowPanel)
                pointsLabel:SetSize(100, 55) pointsLabel:SetPos(430, 0) pointsLabel:SetText(tostring(save.points or 0))
                pointsLabel:SetFont("BoardSave_Label") pointsLabel:SetTextColor(Color(200, 200, 200)) pointsLabel:SetContentAlignment(5)

                local loadBtn = vgui.Create("DButton", rowPanel)
                loadBtn:SetSize(32, 32) loadBtn:SetPos(560, 12) loadBtn:SetText("") loadBtn.SaveName = save.name

                loadBtn.Paint = function(self, w, h)
                    local color = self:IsHovered() and Color(70, 160, 255, 255) or Color(70, 130, 200, 200)
                    draw.RoundedBox(6, 0, 0, w, h, color)
                    if BoardSaveSystem.Icons.load and not BoardSaveSystem.Icons.load:IsError() then
                        surface.SetMaterial(BoardSaveSystem.Icons.load) surface.SetDrawColor(255, 255, 255, 255)
                        surface.DrawTexturedRect(6, 6, w - 12, h - 12)

                    else draw.SimpleText("L", "BoardSave_Button", w/2, h/2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER) end
                end

                loadBtn.DoClick = function(self) BoardSaveSystem.RequestLoadSave(self.SaveName, weaponType) surface.PlaySound("garrysmod/ui_click.wav") BoardSaveSystem.CloseMenu() end
                
                local deleteBtn = vgui.Create("DButton", rowPanel)
                deleteBtn:SetSize(32, 32) deleteBtn:SetPos(605, 12) deleteBtn:SetText("") deleteBtn.SaveName = save.name
                deleteBtn.Paint = function(self, w, h)
                    local color = self:IsHovered() and Color(255, 80, 80, 255) or Color(200, 60, 60, 200)
                    draw.RoundedBox(6, 0, 0, w, h, color)

                    if BoardSaveSystem.Icons.delete and not BoardSaveSystem.Icons.delete:IsError() then
                        surface.SetMaterial(BoardSaveSystem.Icons.delete) surface.SetDrawColor(255, 255, 255, 255)
                        surface.DrawTexturedRect(6, 6, w - 12, h - 12)
                    else draw.SimpleText("D", "BoardSave_Button", w/2, h/2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER) end
                end
                deleteBtn.DoClick = function(self)
                    Derma_Query("Delete '" .. self.SaveName .. "'?", "Confirm", "Yes", function()
                        BoardSaveSystem.RequestDeleteSave(self.SaveName, weaponType)
                        BoardSaveSystem.ShouldRefreshUI = true BoardSaveSystem.RequestSaves(weaponType)
                        surface.PlaySound("buttons/button14.wav")
                    end, "No", function() end)
                end
                table.insert(BoardSaveSystem.SavesRows, rowPanel)
            end
            BoardSaveSystem.UpdateSelectedCounter()
        end
        BoardSaveSystem.RefreshSavesList()
        
        local ply = LocalPlayer()
        local steamID = ply:SteamID()
        local safeSteamID = string.gsub(steamID or "unknown", ":", "_")
        local folderPath = "garrysmod/data/board_drawings/" .. safeSteamID .. "/" .. (weaponType == "chalk" and "chalk_saves" or "marker_saves")
        local pathLabel = vgui.Create("DLabel", frame)
        pathLabel:SetSize(700, 18) pathLabel:SetPos(25, 650)
        pathLabel:SetText("Saves: " .. folderPath)
        pathLabel:SetFont("BoardSave_Path") pathLabel:SetTextColor(Color(210, 210, 220)) pathLabel:SetContentAlignment(4)
    end
    
    local lastSaveKey = false
    local lastLoadKey = false
    hook.Add("Think", "BoardSaveSystem_Keys", function()

        if ChalkMarkerUI and ChalkMarkerUI.State and ChalkMarkerUI.State.IsOpen then return end
        if input.IsKeyDown(BoardSaveSystem.SaveKey) and not lastSaveKey then BoardSaveSystem.SaveCurrentDrawing() end
        if input.IsKeyDown(BoardSaveSystem.LoadKey) and not lastLoadKey then BoardSaveSystem.OpenLoadMenu() end
        lastSaveKey = input.IsKeyDown(BoardSaveSystem.SaveKey)
        lastLoadKey = input.IsKeyDown(BoardSaveSystem.LoadKey)
        
    end)
    hook.Add("OnKeyCodePressed", "BoardSaveSystem_ESC", function(ply, key)
        if key == KEY_ESCAPE and BoardSaveSystem.UI and BoardSaveSystem.UI:IsValid() then BoardSaveSystem.CloseMenu() end
    end)
end