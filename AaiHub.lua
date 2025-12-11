-- ===== Services & Setup =====
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local backpack = player:WaitForChild("Backpack")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local addItem = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("TradeEvents"):WaitForChild("AddItem")
local tradeEvents = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("TradeEvents")

-- ===== Load Rayfield =====
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- ===== Create Window =====
local Window = Rayfield:CreateWindow({
    Name = "Aai Hub",
    Icon = 0,
    LoadingTitle = "Aai Hub UI",
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
PetTradeTab:CreateToggle({
    Name = "Send Trade Request",
    CurrentValue = false,
    Flag = "SendTradeToggle",
    Callback = function(Value)
        SendTradeEnabled = Value
        if SendTradeEnabled and targetPlayerName ~= "" then
            -- find first matching player (case-insensitive)
            local targetPlayer = nil
            local searchName = targetPlayerName:lower()
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= player and p.Name:lower():find(searchName) then
                    targetPlayer = p
                    break
                end
            end

            if targetPlayer then
                holdTradingTicket()
                tradeEvents:WaitForChild("SendRequest"):FireServer(targetPlayer)
                print("Trade request sent to " .. targetPlayer.Name)
                Rayfield:Notify({
                    Title = "Trade",
                    Content = "Trade request sent to " .. targetPlayer.Name,
                    Duration = 2,
                    Image = "check"
                })
            else
                warn("No player found matching: " .. targetPlayerName)
                Rayfield:Notify({
                    Title = "Trade",
                    Content = "Player not found: " .. targetPlayerName,
                    Duration = 2,
                    Image = "x"
                })
            end
        end
    end
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
