-- config.lua
ChalkMarkerConfig = ChalkMarkerConfig or {}

-- ============ СЕРВЕРНАЯ ЧАСТЬ ============
if SERVER then
    util.AddNetworkString("ChalkMarkerUI_ColorConfirmed")
    util.AddNetworkString("ChalkMarkerUI_UpdateWeapon")
    util.AddNetworkString("ChalkMarkerUI_UpdateEraseSize")
    util.AddNetworkString("ChalkMarkerUI_SyncSize")
    util.AddNetworkString("ChalkMarkerUI_SyncEraseSize")
    
    -- Загрузка конфигурации
    if not ChalkMarkerConfig then
        local configPaths = {
            "config.lua",
            "chalk_tool/config.lua", 
            "marker_tool/config.lua",
            "lua/config.lua"
        }
        
        local configLoaded = false
        for _, path in ipairs(configPaths) do
            if file.Exists(path, "LUA") then
                include(path)
                configLoaded = true
                break
            end
        end

        if not configLoaded then
            ErrorNoHalt("ChalkMarker: config.lua not found on server\n")
        end
    end

    net.Receive("ChalkMarkerUI_UpdateWeapon", function(len, ply)
        local colorName = net.ReadString()
        local sizeValue = net.ReadFloat()
        local customColor = nil
        
        if colorName == "__custom__" then
            customColor = net.ReadColor()
        end
        
        local weapon = ply:GetActiveWeapon()
        if IsValid(weapon) and (weapon:GetClass() == "chalk_tool" or weapon:GetClass() == "marker_tool") then
            local weaponType = weapon:GetClass() == "chalk_tool" and "chalk" or "marker"
            local userid = ply:UserID()
            weapon.PlayerData = weapon.PlayerData or {}
            weapon.PlayerData[userid] = weapon.PlayerData[userid] or {}
            
            if colorName == "__custom__" and customColor then
                weapon.PlayerData[userid].customColor = customColor
                weapon.PlayerData[userid].color = "__custom__"
                weapon.CustomColor = customColor
                weapon.CurrentColor = "__custom__"
                
                if weaponType == "chalk" and weapon.SetChalkColor2 then
                    weapon:SetChalkColor2(Vector(customColor.r/255, customColor.g/255, customColor.b/255))
                elseif weaponType == "marker" and weapon.SetMarkerColor2 then
                    weapon:SetMarkerColor2(Vector(customColor.r/255, customColor.g/255, customColor.b/255))
                    if weapon.SetBodyTexture then
                        weapon:SetBodyTexture("models/tools_materials/marker/colors/marker_base_texture")
                    end
                end
            else
                
                weapon.PlayerData[userid].color = colorName
                weapon.PlayerData[userid].customColor = nil
                weapon.CurrentColor = colorName
                weapon.CustomColor = nil
                
                if weapon.SetPlayerColor then
                    weapon:SetPlayerColor(colorName)
                else
                    if weaponType == "chalk" and weapon.SetChalkColor then
                        weapon:SetChalkColor(colorName)
                    elseif weaponType == "marker" and weapon.SetMarkerColor then
                        weapon:SetMarkerColor(colorName)
                    end
                end
            end
            
            weapon.PlayerData[userid].sizeValue = sizeValue
            weapon.CurrentSizeValue = sizeValue
            
            net.Start("ChalkMarkerUI_SyncSize")
                net.WriteEntity(weapon)
                net.WriteFloat(sizeValue)
            net.Send(ply)
        end
    end)

    net.Receive("ChalkMarkerUI_UpdateEraseSize", function(len, ply)
        local eraseSizeValue = net.ReadFloat()
        
        local weapon = ply:GetActiveWeapon()
        if IsValid(weapon) and (weapon:GetClass() == "chalk_tool" or weapon:GetClass() == "marker_tool") then
            
            -- Сохраняем на сервере
            local userid = ply:UserID()
            weapon.PlayerData = weapon.PlayerData or {}
            weapon.PlayerData[userid] = weapon.PlayerData[userid] or {}
            weapon.PlayerData[userid].eraseSizeValue = eraseSizeValue
            
            -- Сохраняем в локальные переменные
            weapon.CurrentEraseSizeValue = eraseSizeValue
            
            -- Синхронизируем с клиентом
            net.Start("ChalkMarkerUI_SyncEraseSize")
                net.WriteEntity(weapon)
                net.WriteFloat(eraseSizeValue)
            net.Send(ply)
            
            --print("[SERVER] Erase size updated to: " .. eraseSizeValue)
        end
    end)
end

-- ============ КЛИЕНТСКАЯ ЧАСТЬ ============
if CLIENT then
    -- Обработчик подтверждения изменения цвета
    net.Receive("ChalkMarkerUI_ColorConfirmed", function()
        local confirmedColor = net.ReadString()
        
        -- Обновляем локальный кэш подтвержденных цветов
        ChalkMarkerUI = ChalkMarkerUI or {}
        ChalkMarkerUI.LastConfirmedColor = confirmedColor
        ChalkMarkerUI.LastConfirmationTime = CurTime()
    end)
    
    -- -- Команда для проверки синхронизации
    -- concommand.Add("debug_tool_sync", function()
    --     local ply = LocalPlayer()
    --     local weapon = ply:GetActiveWeapon()
        
    --     if IsValid(weapon) and (weapon:GetClass() == "chalk_tool" or weapon:GetClass() == "marker_tool") then
    --         ply:ChatPrint("Tool sync check - see console for details")
    --         print("[DEBUG] Current draw size value:", weapon.CurrentSizeValue)
    --         print("[DEBUG] Current erase size value:", weapon.CurrentEraseSizeValue)
    --     else
    --         ply:ChatPrint("You need to hold a chalk or marker tool")
    --     end
    -- end)

end

-- ============ КОНФИГУРАЦИЯ ЦВЕТОВ ============
ChalkMarkerConfig.Colors = {
    -- Цвета для мела
    chalk = {
        white = {
            name = "white", 
            display = "White", 
            color = Color(240, 240, 230), 
            tool_color = Vector(0.95, 0.95, 0.9)
        },
        yellow = {
            name = "yellow", 
            display = "Yellow", 
            color = Color(255, 255, 150), 
            tool_color = Vector(0.98, 0.95, 0.4)
        },
        orange = {
            name = "orange", 
            display = "Orange", 
            color = Color(255, 200, 100), 
            tool_color = Vector(0.95, 0.7, 0.3)
        },
        pink = {
            name = "pink", 
            display = "Pink", 
            color = Color(255, 180, 200), 
            tool_color = Vector(0.95, 0.7, 0.8)
        },
        blue = {
            name = "blue", 
            display = "Blue", 
            color = Color(150, 200, 255), 
            tool_color = Vector(0.5, 0.7, 0.9)
        },
        green = {
            name = "green", 
            display = "Green", 
            color = Color(150, 220, 150),
            tool_color = Vector(0.5, 0.8, 0.5)
        }
    },
    
    -- Цвета для маркера
    marker = {
        black = {
            name = "black", 
            display = "Black", 
            color = Color(0, 0, 0), 
            tool_color = Vector(0, 0, 0),
            texture = "models/tools_materials/marker/colors/marker_base_texture"
        },
        red = {
            name = "red", 
            display = "Red", 
            color = Color(255, 0, 0), 
            tool_color = Vector(1, 0, 0),
            texture = "models/tools_materials/marker/colors/marker_red_texture"
        },
        blue = {
            name = "blue", 
            display = "Blue", 
            color = Color(0, 0, 255), 
            tool_color = Vector(0, 0, 1),
            texture = "models/tools_materials/marker/colors/marker_blue_texture"
        },
        green = {
            name = "green", 
            display = "Green", 
            color = Color(0, 255, 0), 
            tool_color = Vector(0, 1, 0),
            texture = "models/tools_materials/marker/colors/marker_green_texture"
        },
        yellow = {
            name = "yellow", 
            display = "Yellow", 
            color = Color(255, 255, 0), 
            tool_color = Vector(1, 1, 0),
            texture = "models/tools_materials/marker/colors/marker_yellow_texture"
        },
        orange = {
            name = "orange", 
            display = "Orange", 
            color = Color(255, 165, 0), 
            tool_color = Vector(1, 0.5, 0),
            texture = "models/tools_materials/marker/colors/marker_orange_texture"
        },
        cyan = {
            name = "cyan", 
            display = "Cyan", 
            color = Color(0, 255, 255), 
            tool_color = Vector(0, 1, 1),
            texture = "models/tools_materials/marker/colors/marker_cian_texture"
        },
        purple = {
            name = "purple", 
            display = "Purple", 
            color = Color(128, 0, 128), 
            tool_color = Vector(0.5, 0, 0.5),
            texture = "models/tools_materials/marker/colors/marker_purple_texture"
        },
        pink = {
            name = "pink", 
            display = "Pink", 
            color = Color(255, 192, 203), 
            tool_color = Vector(1, 0.5, 0.8),
            texture = "models/tools_materials/marker/colors/marker_pink_texture"
        },
        brown = {
            name = "brown", 
            display = "Brown", 
            color = Color(158, 83, 0), 
            tool_color = Vector(0.62, 0.32, 0),
            texture = "models/tools_materials/marker/colors/marker_brown_texture"
        }
    }
}

-- ============ ДИНАМИЧЕСКИЕ РАЗМЕРЫ ============
ChalkMarkerConfig.DynamicSizes = {
    -- Минимальные и максимальные значения для ползунков
    chalk = {
        draw_min = 5.0,   -- Минимальный размер рисования для мела
        draw_max = 10.0,  -- Максимальный размер рисования для мела
        erase_min = 10.0,  -- Минимальный размер стирания для мела
        erase_max = 50.0  -- Максимальный размер стирания для мела
    },
    marker = {
        draw_min = 7.0,   -- Минимальный размер рисования для маркера
        draw_max = 15.0,  -- Максимальный размер рисования для маркера
        erase_min = 10.0,  -- Минимальный размер стирания для маркера
        erase_max = 50.0  -- Максимальный размер стирания для маркера
    }
}

-- ============ ПОРЯДОК ЦВЕТОВ ДЛЯ БЫСТРОЙ СМЕНЫ (R) ============
ChalkMarkerConfig.ColorOrder = {
    chalk = {"white", "yellow", "orange", "pink", "blue", "green"},
    marker = {"black", "red", "blue", "green", "yellow", "orange", "cyan", "purple", "pink", "brown"}
}

-- ============ ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ============

-- Получить данные цвета
function ChalkMarkerConfig.GetColorData(weaponType, colorName)
    if ChalkMarkerConfig.Colors and ChalkMarkerConfig.Colors[weaponType] and ChalkMarkerConfig.Colors[weaponType][colorName] then
        return ChalkMarkerConfig.Colors[weaponType][colorName]
    end
    
    -- Возвращаем цвет по умолчанию
    if weaponType == "chalk" then
        return ChalkMarkerConfig.Colors.chalk.white
    else
        return ChalkMarkerConfig.Colors.marker.black
    end
end

-- Получить список цветов для интерфейса
function ChalkMarkerConfig.GetColorsForUI(weaponType)
    local colors = {}
    
    if ChalkMarkerConfig.ColorOrder and ChalkMarkerConfig.ColorOrder[weaponType] and ChalkMarkerConfig.Colors and ChalkMarkerConfig.Colors[weaponType] then
        -- Используем порядок из ColorOrder
        for _, colorName in ipairs(ChalkMarkerConfig.ColorOrder[weaponType]) do
            local data = ChalkMarkerConfig.Colors[weaponType][colorName]
            if data then
                table.insert(colors, {
                    name = data.name,
                    display = data.display,
                    color = data.color
                })
            end
        end
    else
        -- если ColorOrder не задан, используем все цвета
        if ChalkMarkerConfig.Colors and ChalkMarkerConfig.Colors[weaponType] then
            for name, data in ipairs(ChalkMarkerConfig.Colors[weaponType]) do
                table.insert(colors, {
                    name = data.name,
                    display = data.display,
                    color = data.color
                })
            end
        end
    end
    
    return colors
end

-- Получить минимальные и максимальные значения для размеров
function ChalkMarkerConfig.GetMinMaxSizes(weaponType, action)
    if ChalkMarkerConfig.DynamicSizes and ChalkMarkerConfig.DynamicSizes[weaponType] then
        if action == "draw" then
            return ChalkMarkerConfig.DynamicSizes[weaponType].draw_min, 
                   ChalkMarkerConfig.DynamicSizes[weaponType].draw_max
        elseif action == "erase" then
            return ChalkMarkerConfig.DynamicSizes[weaponType].erase_min,
                   ChalkMarkerConfig.DynamicSizes[weaponType].erase_max
        end
    end
    
    -- Значения по умолчанию
    if action == "draw" then
        return 1, 20
    else
        return 5, 40
    end
end

-- Получить данные цвета для инструмента
function ChalkMarkerConfig.GetColorForTool(weaponType, colorName)
    local data = ChalkMarkerConfig.GetColorData(weaponType, colorName)
    return data and data.tool_color or Vector(1, 1, 1)
end

-- Получить текстуру для маркера
function ChalkMarkerConfig.GetMarkerTexture(colorName)
    local data = ChalkMarkerConfig.GetColorData("marker", colorName)
    return data and data.texture or "models/tools_materials/marker/colors/marker_base_texture"
end

-- Получить цвета для рисования на доске
function ChalkMarkerConfig.GetDrawColor(weaponType, colorName)
    local data = ChalkMarkerConfig.GetColorData(weaponType, colorName)
    return data and data.color or (weaponType == "chalk" and Color(240, 240, 230) or Color(0, 0, 0))
end

-- Получение следующего цвета в порядке смены
function ChalkMarkerConfig.GetNextColor(weaponType, currentColor)
    if not ChalkMarkerConfig.ColorOrder or not ChalkMarkerConfig.ColorOrder[weaponType] then 
        return currentColor 
    end
    
    local order = ChalkMarkerConfig.ColorOrder[weaponType]
    if #order == 0 then return currentColor end
    
    local currentIndex = 1
    for i, colorName in ipairs(order) do
        if colorName == currentColor then
            currentIndex = i
            break
        end
    end
    
    local nextIndex = (currentIndex % #order) + 1
    return order[nextIndex]
end

-- Добавляем эту функцию в конец config.lua:
-- if CLIENT then
--     -- Функция для принудительного обновления слайдеров
--     function ChalkMarkerConfig.UpdateSizeSliders(weaponType, drawValue, eraseValue)
--         if not ChalkMarkerUI or not ChalkMarkerUI.State.IsOpen then return end
        
--         local weapon = ChalkMarkerUI.State.CurrentWeapon
--         if not IsValid(weapon) then return end
        
--         -- Обновляем значения в оружии
--         weapon.CurrentSizeValue = drawValue
--         weapon.CurrentEraseSizeValue = eraseValue
        
--         -- Если открыта вкладка размера, обновляем слайдеры
--         if ChalkMarkerUI.State.ActiveTab == "size" and ChalkMarkerUI.ContentPanel then
--             -- Ищем слайдеры в контенте
--             for _, child in ipairs(ChalkMarkerUI.ContentPanel:GetChildren()) do
--                 if child:GetClassName() == "DNumSlider" then
--                     local text = child.Label and child.Label:GetText() or ""
--                     if string.find(text, "Draw") then
--                         child:SetValue(drawValue)
--                         if child.TextArea then
--                             child.TextArea:SetValue(tostring(drawValue))
--                         end
--                     elseif string.find(text, "Erase") then
--                         child:SetValue(eraseValue)
--                         if child.TextArea then
--                             child.TextArea:SetValue(tostring(eraseValue))
--                         end
--                     end
--                 end
--             end
--         end
--     end
-- #end 
    -- Отладочная команда для тестирования
    -- concommand.Add("test_slider", function()
    --     local ply = LocalPlayer()
    --     local weapon = ply:GetActiveWeapon()
        
    --     if IsValid(weapon) and (weapon:GetClass() == "chalk_tool" or weapon:GetClass() == "marker_tool") then
    --         local weaponType = weapon:GetClass() == "chalk_tool" and "chalk" or "marker"
            
    --         -- Тестовые значения
    --         local testDraw = 5
    --         local testErase = 10
            
    --         print("[TEST] Setting draw size to:", testDraw)
    --         print("[TEST] Setting erase size to:", testErase)
            
    --         weapon.CurrentSizeValue = testDraw
    --         weapon.CurrentEraseSizeValue = testErase
            
    --         ChalkMarkerConfig.UpdateSizeSliders(weaponType, testDraw, testErase)
            
    --         ply:ChatPrint("Test values set: Draw=" .. testDraw .. ", Erase=" .. testErase)
    --     end
    -- end)
--end

print("ChalkMarker: Configuration loaded")

-- ============ ФУНКЦИИ ДЛЯ ПОЛУЧЕНИЯ РАЗМЕРОВ ДЛЯ UI ============

-- Получить список размеров для интерфейса (для обратной совместимости)
function ChalkMarkerConfig.GetSizesForUI(weaponType, action)
    local sizes = {}
    local minVal, maxVal = ChalkMarkerConfig.GetMinMaxSizes(weaponType, action)
    
    -- Создаем список размеров с шагом 1
    for i = minVal, maxVal do
        -- Создаем читаемое имя размера
        local sizeName
        if i <= 5 then
            sizeName = "Tiny"
        elseif i <= 8 then
            sizeName = "Small"
        elseif i <= 12 then
            sizeName = "Medium"
        elseif i <= 16 then
            sizeName = "Large"
        else
            sizeName = "Huge"
        end
        
        table.insert(sizes, {
            name = tostring(i),  -- Используем число как строку для совместимости
            display = sizeName .. " (" .. i .. "px)",
            value = i
        })
    end
    
    return sizes
end

-- Получить значение размера по имени (для обратной совместимости)
function ChalkMarkerConfig.GetSizeValue(weaponType, action, sizeName)
    local minVal, maxVal = ChalkMarkerConfig.GetMinMaxSizes(weaponType, action)
    
    -- Если sizeName - число, конвертируем в число
    if tonumber(sizeName) then
        return tonumber(sizeName)
    end
    
    -- Ищем по имени
    local sizes = ChalkMarkerConfig.GetSizesForUI(weaponType, action)
    for _, size in ipairs(sizes) do
        if size.name == sizeName then
            return size.value
        end
    end
    
    -- Возвращаем среднее значение по умолчанию
    return math.floor((minVal + maxVal) / 2)
end

-- Получить имя размера по значению (для обратной совместимости)
function ChalkMarkerConfig.GetSizeName(weaponType, action, value)
    local sizes = ChalkMarkerConfig.GetSizesForUI(weaponType, action)
    for _, size in ipairs(sizes) do
        if size.value == value then
            return size.name
        end
    end
    return tostring(value)
end

-- ============ ФИКС СИНХРОНИЗАЦИИ РАЗМЕРОВ ============
if CLIENT then
    -- Переопределяем обработчик синхронизации размера рисования
    net.Receive("ChalkMarkerUI_SyncSize", function()
        local weapon = net.ReadEntity()
        local sizeValue = net.ReadFloat()  -- ИСПРАВЛЕНО: ReadFloat вместо ReadUInt
        
        if IsValid(weapon) then
            weapon.CurrentSizeValue = sizeValue
        end
    end)
    
    -- Переопределяем обработчик синхронизации размера стирания
    net.Receive("ChalkMarkerUI_SyncEraseSize", function()
        local weapon = net.ReadEntity()
        local sizeValue = net.ReadFloat()  -- ИСПРАВЛЕНО: ReadFloat вместо ReadUInt
        
        if IsValid(weapon) then
            weapon.CurrentEraseSizeValue = sizeValue
        end
    end)
end