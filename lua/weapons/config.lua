-- config.lua
ChalkMarkerConfig = ChalkMarkerConfig or {}

-- ============ СЕРВЕРНАЯ ЧАСТЬ ============
if SERVER then
    -- Добавляем новый нетстринг для подтверждения
    util.AddNetworkString("ChalkMarkerUI_ColorConfirmed")
    
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

    -- Обработка обновления оружия через UI
    net.Receive("ChalkMarkerUI_UpdateWeapon", function(len, ply)
        local colorName = net.ReadString()
        local sizeValue = net.ReadUInt(8)
        
        local weapon = ply:GetActiveWeapon()
        if IsValid(weapon) and (weapon:GetClass() == "chalk_tool" or weapon:GetClass() == "marker_tool") then
            
            -- Определяем тип оружия
            local weaponType = weapon:GetClass() == "chalk_tool" and "chalk" or "marker"
            
            -- Устанавливаем цвет
            if weapon.SetPlayerColor then
                weapon:SetPlayerColor(colorName)
            else
                -- Совместимость со старой версией
                weapon.CurrentColor = colorName
                
                -- Обновляем визуал оружия
                if weaponType == "chalk" and weapon.SetChalkColor then
                    weapon:SetChalkColor(colorName)
                elseif weaponType == "marker" and weapon.SetMarkerColor then
                    weapon:SetMarkerColor(colorName)
                end
            end
            
            -- Находим название размера по значению
            local sizeName = "medium"
            if ChalkMarkerConfig.Sizes and ChalkMarkerConfig.Sizes[weaponType .. "_draw"] then
                for name, data in pairs(ChalkMarkerConfig.Sizes[weaponType .. "_draw"]) do
                    if data.value == sizeValue then
                        sizeName = name
                        break
                    end
                end
            end
            
            -- Устанавливаем размер
            if weapon.SetPlayerSize then
                weapon:SetPlayerSize(sizeName)
            else
                -- Совместимость со старой версией
                weapon.CurrentSize = sizeName
                weapon.CurrentSizeValue = sizeValue
            end
            
            -- Синхронизируем цвет с клиентом
            if weaponType == "chalk" then
                net.Start("ChalkColorUpdate")
                    net.WriteEntity(weapon)
                    net.WriteString(colorName)
                net.Send(ply)
            else
                net.Start("MarkerColorUpdate")
                    net.WriteEntity(weapon)
                    net.WriteString(colorName)
                net.Send(ply)
            end
            
            -- Отправляем подтверждение клиенту
            net.Start("ChalkMarkerUI_ColorConfirmed")
                net.WriteString(colorName)
            net.Send(ply)
            
        end
    end)

    -- Обработка обновления размера стирания
    net.Receive("ChalkMarkerUI_UpdateEraseSize", function(len, ply)
        local eraseSizeValue = net.ReadUInt(8)
        
        local weapon = ply:GetActiveWeapon()
        if IsValid(weapon) and (weapon:GetClass() == "chalk_tool" or weapon:GetClass() == "marker_tool") then
            
            -- Определяем тип оружия
            local weaponType = weapon:GetClass() == "chalk_tool" and "chalk" or "marker"
            
            -- Находим название размера по значению
            local eraseSizeName = "medium"
            if ChalkMarkerConfig.Sizes and ChalkMarkerConfig.Sizes[weaponType .. "_erase"] then
                for name, data in pairs(ChalkMarkerConfig.Sizes[weaponType .. "_erase"]) do
                    if data.value == eraseSizeValue then
                        eraseSizeName = name
                        break
                    end
                end
            end
            
            -- Устанавливаем размер стирания
            if weapon.SetPlayerEraseSize then
                weapon:SetPlayerEraseSize(eraseSizeName)
            else
                -- Совместимость со старой версией
                weapon.CurrentEraseSizeValue = eraseSizeValue
                weapon.CurrentEraseSize = eraseSizeName
            end
            
        end
    end)
    
    -- Команда для просмотра всех настроек игроков на сервере (только для админов)
    concommand.Add("server_debug_tools", function(ply)
        if not IsValid(ply) or ply:IsAdmin() then
            -- Оставляем эту команду для админов, но убираем автоматический вывод
            ply:ChatPrint("Use this command only when debugging is needed")
        else
            ply:ChatPrint("You need to be admin to use this command")
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
    
    -- Команда для проверки синхронизации (оставляем для отладки, но убираем авто-вывод)
    concommand.Add("debug_tool_sync", function()
        local ply = LocalPlayer()
        local weapon = ply:GetActiveWeapon()
        
        if IsValid(weapon) and (weapon:GetClass() == "chalk_tool" or weapon:GetClass() == "marker_tool") then
            ply:ChatPrint("Tool sync check - see console for details")
            -- Вывод в консоль только по запросу через команду
        else
            ply:ChatPrint("You need to hold a chalk or marker tool")
        end
    end)
    
    -- Команда для проверки всех игроков на клиенте (оставляем для отладки)
    concommand.Add("debug_all_players_tools", function()
        -- Пустая команда, можно использовать при необходимости
    end)
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

-- ============ КОНФИГУРАЦИЯ РАЗМЕРОВ ============
ChalkMarkerConfig.Sizes = {
    -- Размеры для рисования мелом
    chalk_draw = {
        small = {name = "small", display = "Маленький", value = 5},
        medium = {name = "medium", display = "Средний", value = 7},
        large = {name = "large", display = "Большой", value = 10}
    },
    
    -- Размеры для стирания мелом
    chalk_erase = {
        small = {name = "small", display = "Маленький", value = 10},
        medium = {name = "medium", display = "Средний", value = 15},
        large = {name = "large", display = "Большой", value = 20}
    },
    
    -- Размеры для рисования маркером
    marker_draw = {
        small = {name = "small", display = "Тонкий", value = 5},
        medium = {name = "medium", display = "Средний", value = 7},
        large = {name = "large", display = "Толстый", value = 10}
    },

    -- Размеры для стирания маркером
    marker_erase = {
        small = {name = "small", display = "Маленький", value = 10},
        medium = {name = "medium", display = "Средний", value = 15},
        large = {name = "large", display = "Большой", value = 20}
    }
}

-- ============ ПОРЯДОК ЦВЕТОВ ДЛЯ БЫСТРОЙ СМЕНЫ (R) ============
ChalkMarkerConfig.ColorOrder = {
    chalk = {"white", "yellow", "orange", "pink", "blue", "green"},
    marker = {"black", "red", "blue", "green", "yellow", "orange", "cyan", "purple", "pink", "brown"}
}

-- ============ ПОРЯДОК СМЕНЫ РАЗМЕРОВ ============
ChalkMarkerConfig.SizeOrder = {
    chalk_draw = {"small", "medium", "large"},
    chalk_erase = {"small", "medium", "large"},
    marker_draw = {"small", "medium", "large"},
    marker_erase = {"small", "medium", "large"}
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

-- Получить данные размера
function ChalkMarkerConfig.GetSizeData(weaponType, action, sizeName)
    local sizeKey = weaponType .. "_" .. action
    if ChalkMarkerConfig.Sizes and ChalkMarkerConfig.Sizes[sizeKey] and ChalkMarkerConfig.Sizes[sizeKey][sizeName] then
        return ChalkMarkerConfig.Sizes[sizeKey][sizeName]
    end

    -- Возвращаем размер по умолчанию
    return ChalkMarkerConfig.Sizes[sizeKey] and ChalkMarkerConfig.Sizes[sizeKey].medium or {name = "medium", display = "Средний", value = 7}
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
            for name, data in pairs(ChalkMarkerConfig.Colors[weaponType]) do
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

-- Получение списка размеров для интерфейса
function ChalkMarkerConfig.GetSizesForUI(weaponType, action)
    local sizes = {}
    local sizeKey = weaponType .. "_" .. action
    
    if ChalkMarkerConfig.Sizes and ChalkMarkerConfig.Sizes[sizeKey] then
        for name, data in pairs(ChalkMarkerConfig.Sizes[sizeKey]) do
            table.insert(sizes, {
                name = data.name,
                display = data.display,
                value = data.value
            })
        end
    end
    
    return sizes
end

-- Получение данных цвета для инструмента
function ChalkMarkerConfig.GetColorForTool(weaponType, colorName)
    local data = ChalkMarkerConfig.GetColorData(weaponType, colorName)
    return data and data.tool_color or Vector(1, 1, 1)
end

-- Получение текстуры для маркера
function ChalkMarkerConfig.GetMarkerTexture(colorName)
    local data = ChalkMarkerConfig.GetColorData("marker", colorName)
    return data and data.texture or "models/tools_materials/marker/colors/marker_base_texture"
end

-- Получение цвета для рисования на доске
function ChalkMarkerConfig.GetDrawColor(weaponType, colorName)
    local data = ChalkMarkerConfig.GetColorData(weaponType, colorName)
    return data and data.color or (weaponType == "chalk" and Color(240, 240, 230) or Color(0, 0, 0))
end

-- Получение значения размера
function ChalkMarkerConfig.GetSizeValue(weaponType, action, sizeName)
    local data = ChalkMarkerConfig.GetSizeData(weaponType, action, sizeName)
    return data and data.value or 7
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

-- Получение следующего размера в порядке смены
function ChalkMarkerConfig.GetNextSize(weaponType, action, currentSize)
    local sizeKey = weaponType .. "_" .. action
    if not ChalkMarkerConfig.SizeOrder or not ChalkMarkerConfig.SizeOrder[sizeKey] then 
        return currentSize 
    end
    
    local order = ChalkMarkerConfig.SizeOrder[sizeKey]
    if #order == 0 then return currentSize end
    
    local currentIndex = 1
    for i, sizeName in ipairs(order) do
        if sizeName == currentSize then
            currentIndex = i
            break
        end
    end
    
    local nextIndex = (currentIndex % #order) + 1
    return order[nextIndex]
end

print("ChalkMarker: Configuration loaded")