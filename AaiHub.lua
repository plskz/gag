-- ===== Services & Setup =====
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local backpack = player:WaitForChild("Backpack")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local addItem = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("TradeEvents"):WaitForChild("AddItem")
local tradeEvents = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("TradeEvents")

-- ===== Load Rayfield =====
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- ===== Version =====
local SCRIPT_VERSION = "1.0.0"

-- ===== Create Window =====
local Window = Rayfield:CreateWindow({
    Name = "Aai Hub v" .. SCRIPT_VERSION,
    Icon = 0,
    LoadingTitle = "Aai Hub UI v" .. SCRIPT_VERSION,
    ShowText = "Aai Hub",
    Theme = "Default",
    ToggleUIKeybind = "K",
})

-- ===== Create Tab =====
local PetTradeTab = Window:CreateTab("Pet Trade", 0)

-- ===== Target Player input (partial name supported) =====
local targetPlayerName = ""
local PlayerInput = PetTradeTab:CreateInput({
    Name = "Target Player",
    CurrentValue = "",
    PlaceholderText = "Enter player name (partial OK)...",
    RemoveTextAfterFocusLost = false,
    Flag = "PlayerInput",
    Callback = function(Text)
        targetPlayerName = Text
    end,
})

-- ===== Pet Name input =====
local targetPetName = ""
local PetInput = PetTradeTab:CreateInput({
    Name = "Pet Name",
    CurrentValue = "",
    PlaceholderText = "Enter pet name(s) separated by commas...",
    RemoveTextAfterFocusLost = false,
    Flag = "PetInput",
    Callback = function(Text)
        targetPetName = Text:lower()
    end,
})

-- ===== Toggle for clearing pet input =====
local ClearInputEnabled = false
PetTradeTab:CreateToggle({
    Name = "Clear Input After Sending",
    CurrentValue = false,
    Flag = "ClearInputToggle",
    Callback = function(Value)
        ClearInputEnabled = Value
    end,
})

-- ===== Button to send pets =====
PetTradeTab:CreateButton({
    Name = "Send Pets",
    Callback = function()
        if targetPetName == "" then
            Rayfield:Notify({
                Title = "Pet Trade",
                Content = "Please enter pet name(s).",
                Duration = 3,
                Image = "rewind"
            })
            return
        end

        local petsToFind = {}
        for pet in targetPetName:gmatch("[^,]+") do
            pet = pet:gsub("^%s*(.-)%s*$", "%1") -- trim spaces
            table.insert(petsToFind, pet)
        end

        local foundAny = false
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") then
                local itemName = item.Name:lower()
                for _, petName in ipairs(petsToFind) do
                    if itemName:find(petName) then
                        local petId = item:GetAttribute("PET_UUID") or item.Name
                        addItem:FireServer("Pet", petId)
                        foundAny = true
                        break
                    end
                end
            end
        end

        if foundAny then
            Rayfield:Notify({
                Title = "Pet Trade",
                Content = "Sent pets matching: " .. targetPetName,
                Duration = 3,
                Image = "check"
            })
        else
            Rayfield:Notify({
                Title = "Pet Trade",
                Content = "No pets found matching: " .. targetPetName,
                Duration = 3,
                Image = "x"
            })
        end

        if ClearInputEnabled then
            PetInput:Set("")
            targetPetName = ""
        end
    end
})

-- ===== Function to pick/hold a Trading Ticket =====
local function holdTradingTicket()
    for _, item in ipairs(backpack:GetChildren()) do
        if item:IsA("Tool") and item.Name:lower():find("trading ticket") then
            if player.Character and player.Character:FindFirstChild("Humanoid") then
                player.Character.Humanoid:EquipTool(item)
                return true
            end
        end
    end
    print("No Trading Ticket found in backpack.")
    return false
end

-- ===== Toggle to send trade request (partial name match) =====
local SendTradeEnabled = false
local autoAddPetsRunning = false  -- prevents multiple loops

PetTradeTab:CreateToggle({
    Name = "Send Trade Request (Auto Add Pets)",
    CurrentValue = false,
    Flag = "SendTradeToggle",
    Callback = function(Value)
        SendTradeEnabled = Value

        if SendTradeEnabled then
            -- validation
            if targetPlayerName == "" then
                Rayfield:Notify({Title = "Error", Content = "Enter a target player first!", Duration = 4, Image = "x"})
                SendTradeEnabled = false
                return
            end
            if targetPetName == "" then
                Rayfield:Notify({Title = "Error", Content = "Enter pet name(s) first!", Duration = 4, Image = "x"})
                SendTradeEnabled = false
                return
            end

            -- find player (partial match)
            local targetPlayer = nil
            local searchName = targetPlayerName:lower()
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= player and p.Name:lower():find(searchName) then
                    targetPlayer = p
                    break
                end
            end

            if not targetPlayer then
                Rayfield:Notify({Title = "Trade", Content = "Player not found: " .. targetPlayerName, Duration = 4, Image = "x"})
                SendTradeEnabled = false
                return
            end

            -- hold ticket + send request
            holdTradingTicket()
            tradeEvents:WaitForChild("SendRequest"):FireServer(targetPlayer)

            Rayfield:Notify({
                Title = "Trade",
                Content = "Request sent to " .. targetPlayer.Name .. "\nAuto-adding pets every 2s...",
                Duration = 5,
                Image = "check"
            })

            -- start the calm auto-add loop (only once)
            if not autoAddPetsRunning then
                autoAddPetsRunning = true
                spawn(function()
                    local sentAnyPet = false

                    while SendTradeEnabled and not sentAnyPet and wait(2) do
                        local petsToFind = {}
                        for pet in targetPetName:gmatch("[^,]+") do
                            pet = pet:gsub("^%s*(.-)%s*$", "%1"):lower()
                            table.insert(petsToFind, pet)
                        end

                        local foundThisCycle = false

                        for _, item in ipairs(backpack:GetChildren()) do
                            if item:IsA("Tool") then
                                local itemName = item.Name:lower()
                                for _, petName in ipairs(petsToFind) do
                                    if itemName:find(petName) then
                                        local petId = item:GetAttribute("PET_UUID") or item.Name
                                        pcall(function()
                                            addItem:FireServer("Pet", petId)
                                        end)
                                        foundThisCycle = true
                                        sentAnyPet = true
                                    end
                                end
                            end
                        end

                        if foundThisCycle then
                            Rayfield:Notify({
                                Title = "Pet Trade",
                                Content = "Successfully added pet(s)! Stopped auto-add.",
                                Duration = 4,
                                Image = "check"
                            })
                        end
                    end

                    autoAddPetsRunning = false
                end)
            end

        else
            -- toggle turned OFF
            Rayfield:Notify({Title = "Trade", Content = "Auto-add stopped.", Duration = 3, Image = "info"})
        end
    end,
})

-- ===== Toggle for Auto Accept & Confirm =====
local AutoAcceptEnabled = false
PetTradeTab:CreateToggle({
    Name = "Auto Accept & Confirm",
    CurrentValue = false,
    Flag = "AutoAcceptToggle",
    Callback = function(Value)
        AutoAcceptEnabled = Value
        if AutoAcceptEnabled then
            spawn(function()
                while AutoAcceptEnabled do
                    local successAccept, errAccept = pcall(function()
                        tradeEvents:WaitForChild("Accept"):FireServer()
                        tradeEvents:WaitForChild("Confirm"):FireServer()
                    end)
                    if not successAccept then
                        warn("Error auto accepting/confirming: " .. tostring(errAccept))
                    end
                    wait(0.5)
                end
            end)
        end
    end
})
