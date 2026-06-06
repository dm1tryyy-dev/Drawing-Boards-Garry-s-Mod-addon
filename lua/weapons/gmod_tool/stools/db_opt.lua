TOOL.Category = "Drawing Boards"
TOOL.Name = "#Options"
TOOL.Mode = "db_opt"
TOOL.Command = nil
TOOL.ConfigName = ""

if CLIENT then
    language.Add("tool.db_opt.name", "Drawing Boards Options")
    language.Add("tool.db_opt.desc", "Configure settings")
    language.Add("tool.db_opt.0", "Board Options")
end

-- ConVar для настроек (префикс db_opt_ добавляется автоматически)
TOOL.ClientConVar = {
    ["render_qlt"] = "2",
    ["limit_enabled"] = "0",
    ["limit_max"] = "45000"
}

function TOOL:LeftClick(trace)
    return false
end

function TOOL:RightClick(trace)
    return false
end

function TOOL.BuildCPanel(CPanel)
    CPanel:AddControl("Header", {
        Text = "#tool.db.name",
        Description = "#tool.db.desc"
    })
    
    -- Кнопка для смены клавиши открытия меню
    local keybindButton = vgui.Create("DButton")
    keybindButton:SetText("Change Menu Key (Current: T)")
    keybindButton:SetTall(30)
    
    -- Функция для обновления текста кнопки
    local function UpdateButtonText()
        if file.Exists("chalk_marker_keybind.txt", "DATA") then
            local savedKey = tonumber(file.Read("chalk_marker_keybind.txt", "DATA"))
            if savedKey then
                local keyName = input.GetKeyName(savedKey)
                keybindButton:SetText("Change Menu Key (Current: " .. keyName .. ")")
                return
            end
        end
        keybindButton:SetText("Change Menu Key (Current: T)")
    end
    
    UpdateButtonText()
    
    keybindButton.DoClick = function()
        keybindButton:SetText("Press any key...")
        keybindButton:SetDisabled(true)
        
        local keybindFrame = vgui.Create("DFrame")
        keybindFrame:SetSize(350, 150)
        keybindFrame:SetTitle("Press any keyboard key")
        keybindFrame:SetVisible(true)
        keybindFrame:SetDraggable(false)
        keybindFrame:ShowCloseButton(false)
        keybindFrame:MakePopup()
        keybindFrame:Center()
        
        local instructionLabel = vgui.Create("DLabel", keybindFrame)
        instructionLabel:SetText("Press any key on the keyboard to bind\n\n(Release Q to cancel or click in any place)")
        instructionLabel:SetPos(20, 30)
        instructionLabel:SetSize(310, 80)
        instructionLabel:SetContentAlignment(5)
        instructionLabel:SetTextColor(Color(255, 255, 255))
        instructionLabel:SetWrap(true)
        
        local wasQPressed = input.IsKeyDown(KEY_Q)
        
        keybindFrame.OnKeyCodePressed = function(self, keyCode)
            if keyCode == KEY_ESCAPE or keyCode == KEY_Q or keyCode == KEY_R then
                return true
            end
            
            if keyCode == KEY_LWIN or keyCode == KEY_RWIN then
                return true
            end
            
            local keyName = input.GetKeyName(keyCode)
            file.Write("chalk_marker_keybind.txt", tostring(keyCode))
            
            if ChalkMarkerUI then
                ChalkMarkerUI.Keybind = keyCode
                ChalkMarkerUI.KeybindBlocked = true
                timer.Simple(0.5, function()
                    if ChalkMarkerUI then
                        ChalkMarkerUI.KeybindBlocked = false
                    end
                end)
            end
            
            keybindFrame:Remove()
            UpdateButtonText()
            keybindButton:SetDisabled(false)
            
            print("[DB] Menu key set to: " .. keyName .. " ")
            return true
        end
        
        keybindFrame.Think = function()
            local isQPressedNow = input.IsKeyDown(KEY_Q)
            if wasQPressed and not isQPressedNow then
                keybindFrame:Remove()
                UpdateButtonText()
                keybindButton:SetDisabled(false)
                return
            end
            wasQPressed = isQPressedNow
            
            if keybindFrame:IsValid() and keybindFrame:IsMouseInputEnabled() then
                if input.IsMouseDown(MOUSE_LEFT) then
                    local x, y = keybindFrame:GetPos()
                    local w, h = keybindFrame:GetSize()
                    local mouseX, mouseY = gui.MousePos()
                    
                    if mouseX < x or mouseX > x + w or mouseY < y or mouseY > y + h then
                        keybindFrame:Remove()
                        UpdateButtonText()
                        keybindButton:SetDisabled(false)
                    end
                end
            end
        end
        
        keybindFrame:RequestFocus()
    end
    
    CPanel:AddItem(keybindButton)
    
    -- Кнопка сброса клавиши на T
    local resetKeyButton = vgui.Create("DButton")
    resetKeyButton:SetText("Reset Menu Key to Default (T)")
    resetKeyButton:SetTall(30)
    resetKeyButton.DoClick = function()
        file.Write("chalk_marker_keybind.txt", tostring(KEY_T))
        if ChalkMarkerUI then
            ChalkMarkerUI.Keybind = KEY_T
            ChalkMarkerUI.KeybindBlocked = true
            timer.Simple(0.5, function()
                if ChalkMarkerUI then
                    ChalkMarkerUI.KeybindBlocked = false
                end
            end)
        end
        UpdateButtonText()
        print("[DB] Menu key reset to: T")
    end
    
    CPanel:AddItem(resetKeyButton)
    CPanel:ControlHelp("")
    CPanel:AddControl("Label", {
        Text = "Change Tool Menu key for chalk and marker.\nClick and press any keyboard key to bind it."
    })
    CPanel:ControlHelp("")
    
    -- ============ КНОПКИ ДЛЯ НАСТРОЙКИ КЛАВИШ СОХРАНЕНИЯ ============
    
    CPanel:AddControl("Label", {
        Text = "Save/Load Drawings Keys:"
    })
    CPanel:ControlHelp("")
    
    -- Кнопка для смены клавиши сохранения (F2)
    local saveKeyButton = vgui.Create("DButton")
    saveKeyButton:SetText("Change Save Drawings Key (Current: F2)")
    saveKeyButton:SetTall(30)
    
    local function UpdateSaveButtonText()
        if file.Exists("board_save_key.txt", "DATA") then
            local savedKey = tonumber(file.Read("board_save_key.txt", "DATA"))
            if savedKey then
                local keyName = input.GetKeyName(savedKey)
                saveKeyButton:SetText("Change Save Drawings Key (Current: " .. keyName .. ")")
                return
            end
        end
        saveKeyButton:SetText("Change Save Drawings Key (Current: F2)")
    end
    
    UpdateSaveButtonText()
    
    saveKeyButton.DoClick = function()
        saveKeyButton:SetText("Press any key...")
        saveKeyButton:SetDisabled(true)
        
        local saveFrame = vgui.Create("DFrame")
        saveFrame:SetSize(350, 150)
        saveFrame:SetTitle("Press any keyboard key")
        saveFrame:SetVisible(true)
        saveFrame:SetDraggable(false)
        saveFrame:ShowCloseButton(false)
        saveFrame:MakePopup()
        saveFrame:Center()
        
        local instructionLabel = vgui.Create("DLabel", saveFrame)
        instructionLabel:SetText("Press any key on the keyboard to bind as SAVE DRAWINGS key\n\n(Release Q to cancel or click in any place)")
        instructionLabel:SetPos(20, 30)
        instructionLabel:SetSize(310, 80)
        instructionLabel:SetContentAlignment(5)
        instructionLabel:SetTextColor(Color(255, 255, 255))
        instructionLabel:SetWrap(true)
        
        local wasQPressed = input.IsKeyDown(KEY_Q)
        
        saveFrame.OnKeyCodePressed = function(self, keyCode)
            if keyCode == KEY_ESCAPE or keyCode == KEY_Q then
                return true
            end
            if keyCode == KEY_LWIN or keyCode == KEY_RWIN then
                return true
            end
            
            local keyName = input.GetKeyName(keyCode)
            file.Write("board_save_key.txt", tostring(keyCode))
            
            if BoardSaveSystem then
                BoardSaveSystem.SaveKey = keyCode
            end
            
            saveFrame:Remove()
            UpdateSaveButtonText()
            saveKeyButton:SetDisabled(false)
            
            print("[DB] Save drawing key set to: " .. keyName)
            return true
        end
        
        saveFrame.Think = function()
            local isQPressedNow = input.IsKeyDown(KEY_Q)
            if wasQPressed and not isQPressedNow then
                saveFrame:Remove()
                UpdateSaveButtonText()
                saveKeyButton:SetDisabled(false)
                return
            end
            wasQPressed = isQPressedNow
            
            if saveFrame:IsValid() and saveFrame:IsMouseInputEnabled() then
                if input.IsMouseDown(MOUSE_LEFT) then
                    local x, y = saveFrame:GetPos()
                    local w, h = saveFrame:GetSize()
                    local mouseX, mouseY = gui.MousePos()
                    
                    if mouseX < x or mouseX > x + w or mouseY < y or mouseY > y + h then
                        saveFrame:Remove()
                        UpdateSaveButtonText()
                        saveKeyButton:SetDisabled(false)
                    end
                end
            end
        end
        
        saveFrame:RequestFocus()
    end
    
    CPanel:AddItem(saveKeyButton)
    
    -- Кнопка сброса клавиши сохранения на F2
    local resetSaveKeyButton = vgui.Create("DButton")
    resetSaveKeyButton:SetText("Reset Save Drawings Key to Default (F2)")
    resetSaveKeyButton:SetTall(30)
    resetSaveKeyButton.DoClick = function()
        file.Write("board_save_key.txt", tostring(KEY_F2))
        if BoardSaveSystem then
            BoardSaveSystem.SaveKey = KEY_F2
        end
        UpdateSaveButtonText()
        print("[DB] Save drawing key reset to: F2")
    end
    CPanel:AddItem(resetSaveKeyButton)
    CPanel:ControlHelp("")
    
    -- Кнопка для смены клавиши загрузки (F3)
    local loadKeyButton = vgui.Create("DButton")
    loadKeyButton:SetText("Change Load Drawings Key (Current: F3)")
    loadKeyButton:SetTall(30)
    
    local function UpdateLoadButtonText()
        if file.Exists("board_load_key.txt", "DATA") then
            local savedKey = tonumber(file.Read("board_load_key.txt", "DATA"))
            if savedKey then
                local keyName = input.GetKeyName(savedKey)
                loadKeyButton:SetText("Change Load Drawings Key (Current: " .. keyName .. ")")
                return
            end
        end
        loadKeyButton:SetText("Change Load Drawings Key (Current: F3)")
    end
    
    UpdateLoadButtonText()
    
    loadKeyButton.DoClick = function()
        loadKeyButton:SetText("Press any key...")
        loadKeyButton:SetDisabled(true)
        
        local loadFrame = vgui.Create("DFrame")
        loadFrame:SetSize(350, 150)
        loadFrame:SetTitle("Press any keyboard key")
        loadFrame:SetVisible(true)
        loadFrame:SetDraggable(false)
        loadFrame:ShowCloseButton(false)
        loadFrame:MakePopup()
        loadFrame:Center()
        
        local instructionLabel = vgui.Create("DLabel", loadFrame)
        instructionLabel:SetText("Press any key on the keyboard to bind as LOAD DRAWINGS key\n\n(Release Q to cancel or click in any place)")
        instructionLabel:SetPos(20, 30)
        instructionLabel:SetSize(310, 80)
        instructionLabel:SetContentAlignment(5)
        instructionLabel:SetTextColor(Color(255, 255, 255))
        instructionLabel:SetWrap(true)
        
        local wasQPressed = input.IsKeyDown(KEY_Q)
        
        loadFrame.OnKeyCodePressed = function(self, keyCode)
            if keyCode == KEY_ESCAPE or keyCode == KEY_Q then
                return true
            end
            if keyCode == KEY_LWIN or keyCode == KEY_RWIN then
                return true
            end
            
            local keyName = input.GetKeyName(keyCode)
            file.Write("board_load_key.txt", tostring(keyCode))
            
            if BoardSaveSystem then
                BoardSaveSystem.LoadKey = keyCode
            end
            
            loadFrame:Remove()
            UpdateLoadButtonText()
            loadKeyButton:SetDisabled(false)
            
            print("[DB] Load drawings key set to: " .. keyName)
            return true
        end
        
        loadFrame.Think = function()
            local isQPressedNow = input.IsKeyDown(KEY_Q)
            if wasQPressed and not isQPressedNow then
                loadFrame:Remove()
                UpdateLoadButtonText()
                loadKeyButton:SetDisabled(false)
                return
            end
            wasQPressed = isQPressedNow
            
            if loadFrame:IsValid() and loadFrame:IsMouseInputEnabled() then
                if input.IsMouseDown(MOUSE_LEFT) then
                    local x, y = loadFrame:GetPos()
                    local w, h = loadFrame:GetSize()
                    local mouseX, mouseY = gui.MousePos()
                    
                    if mouseX < x or mouseX > x + w or mouseY < y or mouseY > y + h then
                        loadFrame:Remove()
                        UpdateLoadButtonText()
                        loadKeyButton:SetDisabled(false)
                    end
                end
            end
        end
        
        loadFrame:RequestFocus()
    end
    
    CPanel:AddItem(loadKeyButton)
    
    -- Кнопка сброса клавиши загрузки на F3
    local resetLoadKeyButton = vgui.Create("DButton")
    resetLoadKeyButton:SetText("Reset Load Drawings Key to Default (F3)")
    resetLoadKeyButton:SetTall(30)
    resetLoadKeyButton.DoClick = function()
        file.Write("board_load_key.txt", tostring(KEY_F3))
        if BoardSaveSystem then
            BoardSaveSystem.LoadKey = KEY_F3
        end
        UpdateLoadButtonText()
        print("[DB] Load drawings key reset to: F3")
    end
    CPanel:AddItem(resetLoadKeyButton)
    CPanel:ControlHelp("")
    
    -- Загрузка текущей клавиши при открытии панели
    if file.Exists("chalk_marker_keybind.txt", "DATA") then
        local savedKey = tonumber(file.Read("chalk_marker_keybind.txt", "DATA"))
        if savedKey then
            local keyName = input.GetKeyName(savedKey)
            keybindButton:SetText("Change Menu Key (Current: " .. keyName .. ")")
        end
    end
    
    -- Быстрая очистка досок на всей карте через кнопку
    CPanel:AddControl("Button", {
        Label = "Cleanup All Boards",
        Command = "db_cleanup"
    })
    CPanel:ControlHelp("")
    CPanel:AddControl("Label", {
        Text = "To completely clear the boards, use these console commands:"
    })
    CPanel:ControlHelp("")
    CPanel:ControlHelp("chalk_clear - clears chalkboards")
    CPanel:ControlHelp("")
    CPanel:ControlHelp("marker_clear - clears whiteboards and little whiteboards")
    CPanel:ControlHelp("")

    local lowQualityCheckbox = vgui.Create("DCheckBoxLabel")
    lowQualityCheckbox:SetText("Low Quality Mode (Recommended for weak PCs!)")
    lowQualityCheckbox:SetIndent(5)
    lowQualityCheckbox:SetTall(30)
    lowQualityCheckbox:SetTextColor(Color(255, 255, 255))
    
    -- Загружаем сохраненное значение
    local isLowQuality = GetConVarNumber("db_opt_render_qlt") == 1
    lowQualityCheckbox:SetValue(isLowQuality)
    
    lowQualityCheckbox.OnChange = function(self, value)
        RunConsoleCommand("db_opt_render_qlt", value and "1" or "2")
        print("[DB] Low Quality Mode: " .. (value and "Enabled (512x512)" or "Disabled (1024x1024)"))
    end
    
    CPanel:AddItem(lowQualityCheckbox)
    CPanel:ControlHelp("")
    CPanel:ControlHelp("  Enable = 512x512 (better FPS)")
    CPanel:ControlHelp("  Disable = 1024x1024 (default)")
    CPanel:ControlHelp("")
    CPanel:ControlHelp("")
    CPanel:ControlHelp("Board Points Limit")
    -- ============ НАСТРОЙКИ ЛИМИТА ТОЧЕК НА ДОСКЕ ============
    CPanel:ControlHelp("")
    -- Проверка прав доступа
    local hasAccess = false
    if game.SinglePlayer() then
        hasAccess = true
    elseif IsValid(LocalPlayer()) and LocalPlayer():IsAdmin() then
        hasAccess = true
    end
    
    if not hasAccess then
        CPanel:AddControl("Label", {
            Text = "These settings are only available to server administrators.\nCommands in the client console don't work."
        })
        CPanel:ControlHelp("")
    else
        local limitEnabled = DB_LIMIT_ENABLED or false
        local limitMax = DB_LIMIT_MAX or 45000

        -- Галочка для включения/выключения лимита
        local limitCheckbox = vgui.Create("DCheckBoxLabel")
        DB_LimitCheckbox = limitCheckbox
        limitCheckbox:SetText("Enable Point Limit on Boards")
        limitCheckbox:SetIndent(5)
        limitCheckbox:SetTall(30)
        limitCheckbox:SetTextColor(Color(255, 255, 255))
        limitCheckbox:SetValue(limitEnabled)
        
        -- Поле для ввода числа
        CPanel:AddControl("Label", {
            Text = "Maximum Points per Board:"
        })
        
        local numberWang = vgui.Create("DNumberWang")
        DB_LimitNumberWang = numberWang
        numberWang:SetMin(100)
        numberWang:SetMax(500000)
        numberWang:SetValue(limitMax)
        numberWang:SetTall(25)
        numberWang:SetEnabled(limitEnabled)
        
        -- Обработчик изменения галочки
        limitCheckbox.OnChange = function(self, value)
            if DB_LIMIT_SYNCING then return end
            numberWang:SetEnabled(value)
            net.Start("DBPointLimit_SetEnabled")
                net.WriteBool(value)
            net.SendToServer()
        end
        
        local updatingNumberWang = false
        numberWang.OnValueChanged = function(self, value)
            if DB_LIMIT_SYNCING then return end
            if updatingNumberWang then return end

            local intValue = math.Clamp(
                math.floor(tonumber(value) or 100),
                100,
                500000
            )

            if game.SinglePlayer() then
                RunConsoleCommand(
                    "db_opt_limit_max",
                    tostring(intValue)
                )
            else
                net.Start("DBPointLimit_SetMax")
                    net.WriteInt(intValue, 32)
                net.SendToServer()
            end
        end
        numberWang.OnLoseFocus = function(self)

            local intValue = math.Clamp(
                math.floor(self:GetValue()),
                100,
                500000
            )

            updatingNumberWang = true
            self:SetValue(intValue)
            updatingNumberWang = false
        end
        
        CPanel:AddItem(limitCheckbox)
        CPanel:AddItem(numberWang)
        CPanel:ControlHelp("")
        CPanel:ControlHelp("When limit is reached, oldest points are removed automatically")
        CPanel:ControlHelp("Console commands:")
        CPanel:ControlHelp("  db_opt_limit_enabled 0/1")
        CPanel:ControlHelp("  db_opt_limit_max [number]")

    end
    CPanel:ControlHelp("")
end