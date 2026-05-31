-- Серверная часть системы сохранений досок

if SERVER then
    util.AddNetworkString("BoardSave_RequestSaves")
    util.AddNetworkString("BoardSave_UploadSaveChunk")
    util.AddNetworkString("BoardSave_LoadSave")
    util.AddNetworkString("BoardSave_DeleteSave")
    util.AddNetworkString("BoardSave_ClearAllSaves")
    util.AddNetworkString("BoardSave_SendSaves")
    util.AddNetworkString("BoardSave_SendDrawingChunk")
    
    local SAVES_FOLDER = "board_drawings"
    file.CreateDir(SAVES_FOLDER)
    
    local chunkStorage = {}
    
    local function GetSafeSteamID(steamID)
        if not steamID then return "unknown" end
        return string.gsub(steamID, ":", "_")
    end
    
    local function Transliterate(text)
        if not text or text == "" then return "drawing" end
        
        local rus = {
            ["а"]="a", ["б"]="b", ["в"]="v", ["г"]="g", ["д"]="d",
            ["е"]="e", ["ё"]="e", ["ж"]="zh",["з"]="z", ["и"]="i",
            ["й"]="y", ["к"]="k", ["л"]="l", ["м"]="m", ["н"]="n",
            ["о"]="o", ["п"]="p", ["р"]="r", ["с"]="s", ["т"]="t",
            ["у"]="u", ["ф"]="f", ["х"]="h", ["ц"]="c", ["ч"]="ch",
            ["ш"]="sh",["щ"]="sch",["ъ"]="",  ["ы"]="y", ["ь"]="",
            ["э"]="e", ["ю"]="yu",["я"]="ya",
            ["А"]="A",["Б"]="B",["В"]="V",["Г"]="G",["Д"]="D",
            ["Е"]="E",["Ё"]="E",["Ж"]="Zh",["З"]="Z",["И"]="I",
            ["Й"]="Y",["К"]="K",["Л"]="L",["М"]="M",["Н"]="N",
            ["О"]="O",["П"]="P",["Р"]="R",["С"]="S",["Т"]="T",
            ["У"]="U",["Ф"]="F",["Х"]="H",["Ц"]="C",["Ч"]="Ch",
            ["Ш"]="Sh",["Щ"]="Sch",["Ъ"]="",  ["Ы"]="Y",["Ь"]="",
            ["Э"]="E",["Ю"]="Yu",["Я"]="Ya"
        }
        
        local chars = {}
        for char in string.gmatch(text, "[%z\1-\127\194-\244][\128-\191]*") do
            table.insert(chars, char)
        end
        
        local result = ""
        for _, char in ipairs(chars) do
            if rus[char] then result = result .. rus[char]
            elseif char:match("[a-zA-Z0-9]") then result = result .. char
            else result = result .. "_" end
        end
        
        result = string.gsub(result, "_+", "_")
        result = string.gsub(result, "^_", "")
        result = string.gsub(result, "_$", "")
        if result == "" then result = "drawing" end
        return result
    end
    
    local function GetUniqueFileName(folder, baseName)
        local safeBase = Transliterate(baseName)
        local testPath = folder .. safeBase .. ".dat"
        if not file.Exists(testPath, "DATA") then return safeBase end
        local counter = 2
        while true do
            local newName = safeBase .. "_" .. counter
            local newPath = folder .. newName .. ".dat"
            if not file.Exists(newPath, "DATA") then return newName end
            counter = counter + 1
        end
    end
    
    local function GetToolFolder(steamID, weaponType)
        local safeSteamID = GetSafeSteamID(steamID)
        local toolFolder = (weaponType == "chalk") and "chalk_saves" or "marker_saves"
        return SAVES_FOLDER .. "/" .. safeSteamID .. "/" .. toolFolder .. "/"
    end
    
    local function GetPlayerSaves(ply, weaponType)
        if not IsValid(ply) then return {} end
        local steamID = ply:SteamID()
        if not steamID or steamID == "" or steamID == "STEAM_ID_PENDING" then return {} end
        if not weaponType or (weaponType ~= "chalk" and weaponType ~= "marker") then return {} end
        
        local folder = GetToolFolder(steamID, weaponType)
        local saves = {}
        if not file.IsDir(folder, "DATA") then return saves end
        
        local files, _ = file.Find(folder .. "*.dat", "DATA")
        if not files then return saves end
        
        for _, fileName in ipairs(files) do
            local filePath = folder .. fileName
            local data = file.Read(filePath, "DATA")
            if data and data ~= "" then
                local originalName = fileName:match("(.+)%.dat$") or "Unknown"
                local timestamp = 0
                local points = 0
                local pos = 1
                
                if string.sub(data, pos, pos + 1) == "T:" then
                    pos = pos + 2
                    local timeEnd = string.find(data, "\0", pos)
                    if timeEnd then
                        timestamp = tonumber(string.sub(data, pos, timeEnd - 1)) or 0
                        pos = timeEnd + 1
                    end
                end
                
                if string.sub(data, pos, pos + 1) == "N:" then
                    pos = pos + 2
                    local nameEnd = string.find(data, "\0", pos)
                    if nameEnd then
                        originalName = string.sub(data, pos, nameEnd - 1)
                        pos = nameEnd + 1
                    end
                end
                if pos + 2 <= #data then
                    points = string.byte(data, pos) + string.byte(data, pos + 1) * 256
                end
                
                table.insert(saves, {
                    name = originalName,
                    timestamp = timestamp,
                    points = points,
                    boardClass = "board"
                })
            end
        end

        table.sort(saves, function(a, b) return a.timestamp > b.timestamp end)
        return saves
    end
    
    local function SaveDrawing(ply, saveName, chunkData, chunkIndex, totalChunks, weaponType, boardClass)
        if not IsValid(ply) then return false end
        local steamID = ply:SteamID()
        if not steamID or steamID == "" or steamID == "STEAM_ID_PENDING" then return false end
        if not saveName or saveName == "" then return false end
        if not weaponType or (weaponType ~= "chalk" and weaponType ~= "marker") then return false end
        
        local key = GetSafeSteamID(steamID) .. "_" .. Transliterate(saveName)
        
        if not chunkStorage[key] then
            chunkStorage[key] = {
                chunks = {}, total = totalChunks, weaponType = weaponType,
                boardClass = boardClass, timestamp = os.time(), originalName = saveName
            }
        end
        
        chunkStorage[key].chunks[chunkIndex] = chunkData
        
        for k, v in pairs(chunkStorage) do
            if v.timestamp and os.time() - v.timestamp > 300 then chunkStorage[k] = nil end
        end
        
        local storage = chunkStorage[key]
        if storage and table.Count(storage.chunks) == totalChunks then
            local fullData = ""
            for i = 1, totalChunks do fullData = fullData .. (storage.chunks[i] or "") end
            
            local folder = GetToolFolder(steamID, weaponType)
            file.CreateDir(folder)
            
            if not file.IsDir(folder, "DATA") then
                file.CreateDir(SAVES_FOLDER)
                file.CreateDir(SAVES_FOLDER .. "/" .. GetSafeSteamID(steamID))
                file.CreateDir(SAVES_FOLDER .. "/" .. GetSafeSteamID(steamID) .. "/" .. (weaponType == "chalk" and "chalk_saves" or "marker_saves"))
            end
            
            local uniqueFileName = GetUniqueFileName(folder, storage.originalName)
            local filePath = folder .. uniqueFileName .. ".dat"
            local timeData = "T:" .. storage.timestamp .. "\0"
            local nameData = "N:" .. storage.originalName .. "\0"
            file.Write(filePath, timeData .. nameData .. fullData)
            
            chunkStorage[key] = nil
            
            local saves = GetPlayerSaves(ply, weaponType)
            net.Start("BoardSave_SendSaves")
            net.WriteTable(saves)
            net.Send(ply)
        end
        return true
    end
    
    local function LoadDrawing(ply, saveName, weaponType)
        if not IsValid(ply) then return false end
        local steamID = ply:SteamID()
        if not steamID or steamID == "" or steamID == "STEAM_ID_PENDING" then return false end
        if not weaponType or (weaponType ~= "chalk" and weaponType ~= "marker") then return false end
        
        local folder = GetToolFolder(steamID, weaponType)
        if not file.IsDir(folder, "DATA") then return false end
        
        local files, _ = file.Find(folder .. "*.dat", "DATA")
        if not files then return false end
        
        local targetFile = nil
        for _, fileName in ipairs(files) do
            local filePath = folder .. fileName
            local data = file.Read(filePath, "DATA")
            if data and data ~= "" then
                local nameStart = string.find(data, "N:")
                if nameStart then
                    local namePos = nameStart + 2
                    local nameEnd = string.find(data, "\0", namePos)
                    if nameEnd then
                        if string.sub(data, namePos, nameEnd - 1) == saveName then
                            targetFile = filePath; break
                        end
                    end
                end
            end
        end
        
        if not targetFile then return false end
        
        local fullData = file.Read(targetFile, "DATA")
        if not fullData or #fullData == 0 then return false end
        
        local pointsData = fullData
        local timeStart = string.find(fullData, "T:")
        if timeStart then
            local timeEnd = string.find(fullData, "\0", timeStart + 2)
            if timeEnd then
                local nameStart = string.find(fullData, "N:", timeEnd)
                if nameStart then
                    local nameEnd = string.find(fullData, "\0", nameStart + 2)
                    if nameEnd then pointsData = string.sub(fullData, nameEnd + 1) end
                end
            end
        end
        
        local totalBytes = #pointsData
        local CHUNK_SIZE = 64000
        local totalChunks = math.ceil(totalBytes / CHUNK_SIZE)
        local chunks = {}
        for i = 1, totalChunks do
            local startPos = (i - 1) * CHUNK_SIZE + 1
            local endPos = math.min(startPos + CHUNK_SIZE - 1, totalBytes)
            chunks[i] = pointsData:sub(startPos, endPos)
        end
        
        local currentChunk = 1
        local function SendNextChunk()
            if currentChunk > totalChunks then return end
            net.Start("BoardSave_SendDrawingChunk")
            net.WriteString(saveName)
            net.WriteUInt(#chunks[currentChunk], 16)
            net.WriteData(chunks[currentChunk], #chunks[currentChunk])
            net.WriteUInt(currentChunk, 16)
            net.WriteUInt(totalChunks, 16)
            net.Broadcast()
            currentChunk = currentChunk + 1
            if currentChunk <= totalChunks then timer.Simple(0.05, SendNextChunk) end
        end
        SendNextChunk()
        return true
    end
    
    local function DeleteSave(ply, saveName, weaponType)
        if not IsValid(ply) then return false end
        local steamID = ply:SteamID()
        if not steamID or steamID == "" or steamID == "STEAM_ID_PENDING" then return false end
        if not weaponType or (weaponType ~= "chalk" and weaponType ~= "marker") then return false end
        
        local folder = GetToolFolder(steamID, weaponType)
        if not file.IsDir(folder, "DATA") then return false end
        
        local files, _ = file.Find(folder .. "*.dat", "DATA")
        if not files then return false end
        
        for _, fileName in ipairs(files) do
            local filePath = folder .. fileName
            local data = file.Read(filePath, "DATA")
            if data and data ~= "" then
                local nameStart = string.find(data, "N:")
                if nameStart then
                    local nameEnd = string.find(data, "\0", nameStart + 2)
                    if nameEnd and string.sub(data, nameStart + 2, nameEnd - 1) == saveName then
                        file.Delete(filePath)
                        return true
                    end
                end
            end
        end
        return false
    end
    
    local function ClearAllSaves(ply, weaponType)
        if not IsValid(ply) then return false end
        local steamID = ply:SteamID()
        if not steamID or steamID == "" or steamID == "STEAM_ID_PENDING" then return false end
        if not weaponType or (weaponType ~= "chalk" and weaponType ~= "marker") then return false end
        
        local folder = GetToolFolder(steamID, weaponType)
        if not file.IsDir(folder, "DATA") then return 0 end
        
        local files, _ = file.Find(folder .. "*.dat", "DATA")
        if not files then return 0 end
        
        local deletedCount = 0
        for _, fileName in ipairs(files) do
            file.Delete(folder .. fileName)
            deletedCount = deletedCount + 1
        end
        return deletedCount
    end
    
    net.Receive("BoardSave_RequestSaves", function(len, ply)
        local weaponType = net.ReadString()
        local saves = GetPlayerSaves(ply, weaponType)
        net.Start("BoardSave_SendSaves")
        net.WriteTable(saves)
        net.Send(ply)
    end)
    
    net.Receive("BoardSave_UploadSaveChunk", function(len, ply)
        local saveName = net.ReadString()
        local dataLen = net.ReadUInt(16)
        local chunkData = net.ReadData(dataLen)
        local chunkIndex = net.ReadUInt(16)
        local totalChunks = net.ReadUInt(16)
        local weaponType = net.ReadString()
        local boardClass = net.ReadString()
        local pointsCount = net.ReadUInt(32)
        SaveDrawing(ply, saveName, chunkData, chunkIndex, totalChunks, weaponType, boardClass)
    end)
    
    net.Receive("BoardSave_LoadSave", function(len, ply)
        local saveName = net.ReadString()
        local weaponType = net.ReadString()
        LoadDrawing(ply, saveName, weaponType)
    end)
    
    net.Receive("BoardSave_DeleteSave", function(len, ply)
        local saveName = net.ReadString()
        local weaponType = net.ReadString()
        DeleteSave(ply, saveName, weaponType)
        local saves = GetPlayerSaves(ply, weaponType)
        net.Start("BoardSave_SendSaves")
        net.WriteTable(saves)
        net.Send(ply)
    end)
    
    net.Receive("BoardSave_ClearAllSaves", function(len, ply)
        local weaponType = net.ReadString()
        ClearAllSaves(ply, weaponType)
        net.Start("BoardSave_SendSaves")
        net.WriteTable({})
        net.Send(ply)
    end)
    
    print("[Board Save System] Server loaded! Saves path: data/board_drawings/")
end