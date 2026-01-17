task.spawn(function()

    local load = require(game.ReplicatedStorage:WaitForChild("Fsys")).load

    set_thread_identity(2)
    local clientData = load("ClientData")
    local items = load("KindDB")
    local router = load("RouterClient")
    local downloader = load("DownloadClient")
    local animationManager = load("AnimationManager")
    local petRigs = load("new:PetRigs")
    set_thread_identity(8)

    local petModels = {}
    local pets = {}
    local equippedPet = nil
    local mountedPet = nil
    local currentMountTrack = nil

    local function updateData(key, action)
        local data = clientData.get(key)
        local clonedData = table.clone(data)
        clientData.predict(key, action(clonedData))
    end

    local function getUniqueId()
        return game:GetService("HttpService"):GenerateGUID(false)
    end

    local function getPetModel(kind)
        if petModels[kind] then return petModels[kind] end
        local streamed = downloader.promise_download_copy("Pets", kind):expect()
        petModels[kind] = streamed
        return streamed
    end

    local function createPet(id, properties)
        local uniqueId = getUniqueId()
        local pet

        set_thread_identity(2)
        updateData("inventory", function(inventory)
            local newPets = table.clone(inventory.pets)
            local item = items[id]
            pet = {
                unique = uniqueId,
                category = "pets",
                id = id,
                kind = item.kind,
                newness_order = 0,
                properties = properties
            }
            newPets[uniqueId] = pet
            inventory.pets = newPets
            return inventory
        end)
        set_thread_identity(8)

        pets[uniqueId] = {data = pet, model = nil}
        return pet
    end

    local function neonify(model, entry)
        local petModel = model:FindFirstChild("PetModel")
        if not petModel then return end
        for neonPart, config in pairs(entry.neon_parts) do
            local truePart = petRigs.get(petModel).get_geo_part(petModel, neonPart)
            truePart.Material = config.Material
            truePart.Color = config.Color
        end
    end

    local function addPetWrapper(wrapper)
        updateData("pet_char_wrappers", function(wrappers)
            wrapper.unique = #wrappers + 1
            wrapper.index = #wrappers + 1
            wrappers[#wrappers + 1] = wrapper
            return wrappers
        end)
    end

    local function addPetState(state)
        updateData("pet_state_managers", function(states)
            states[#states + 1] = state
            return states
        end)
    end

    local function findIndex(tbl, callback)
        for i, v in pairs(tbl) do
            if callback(v, i) then return i end
        end
    end

    local function removePetWrapper(uniqueId)
        updateData("pet_char_wrappers", function(wrappers)
            local index = findIndex(wrappers, function(w) return w.pet_unique == uniqueId end)
            if not index then return wrappers end
            table.remove(wrappers, index)
            for i, w in pairs(wrappers) do
                w.unique = i
                w.index = i
            end
            return wrappers
        end)
    end

    local function clearPetState(uniqueId)
        local pet = pets[uniqueId]
        if not pet or not pet.model then return end
        updateData("pet_state_managers", function(states)
            local index = findIndex(states, function(s) return s.char == pet.model end)
            if not index then return states end
            local clone = table.clone(states)
            clone[index] = table.clone(clone[index])
            clone[index].states = {}
            return clone
        end)
    end

    local function setPetState(uniqueId, id)
        local pet = pets[uniqueId]
        if not pet or not pet.model then return end
        updateData("pet_state_managers", function(states)
            local index = findIndex(states, function(s) return s.char == pet.model end)
            if not index then return states end
            local clone = table.clone(states)
            clone[index] = table.clone(clone[index])
            clone[index].states = {{id = id}}
            return clone
        end)
    end

    local function clearPlayerState()
        updateData("state_manager", function(state)
            local clone = table.clone(state)
            clone.states = {}
            clone.is_sitting = false
            return clone
        end)
    end

    local function setPlayerState(id)
        updateData("state_manager", function(state)
            local clone = table.clone(state)
            clone.states = {{id = id}}
            clone.is_sitting = true
            return clone
        end)
    end

    local function unmount(uniqueId)
        local pet = pets[uniqueId]
        if not pet or not pet.model then return end
        if currentMountTrack then
            currentMountTrack:Stop()
            currentMountTrack:Destroy()
        end
        clearPetState(uniqueId)
        clearPlayerState()
        pet.model:ScaleTo(1)
        mountedPet = nil
    end

    local function mount(uniqueId, playerState, petState)
        local pet = pets[uniqueId]
        if not pet or not pet.model then return end
        local player = game.Players.LocalPlayer
        mountedPet = uniqueId
        setPetState(uniqueId, petState)
        setPlayerState(playerState)
        pet.model:ScaleTo(2)
        currentMountTrack =
            player.Character.Humanoid.Animator:LoadAnimation(
                animationManager.get_track("PlayerRidingPet")
            )
        player.Character.Humanoid.Sit = true
        currentMountTrack:Play()
    end

    local function fly(id) mount(id, "PlayerFlyingPet", "PetBeingFlown") end
    local function ride(id) mount(id, "PlayerRidingPet", "PetBeingRidden") end

    local oldGet = router.get

    router.get = function(name)
        return oldGet(name)
    end

    local Loads = require(game.ReplicatedStorage.Fsys).load
    local InventoryDB = Loads("InventoryDB")

    function GetPetByName(name)
        for _, v in pairs(InventoryDB.pets) do
            if v.name:lower() == name:lower() then
                return v.id
            end
        end
        return false
    end

    -- UI
    local WindUI = loadstring(game:HttpGet(
        "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"
    ))()

    local Confirmed = false

    WindUI:Popup({
        Title = "SNTHNOVA HUB",
        Content = "hello this is adopt me visual enjoy",
        Buttons = {
            {Title = "Cancel", Variant = "Secondary"},
            {
                Title = "Continue",
                Variant = "Primary",
                Callback = function()
                    Confirmed = true
                end
            }
        }
    })

    repeat task.wait() until Confirmed

    local Window = WindUI:CreateWindow({
        Title = "SNTHNOVA HUB",
        Size = UDim2.fromOffset(420, 350),
        Theme = "Dark"
    })

    local PetsTab = Window:Tab({
        Title = "Pets",
        Icon = "heart"
    })

    local petName = nil
    local petType = "FR"

    PetsTab:Input({
        Title = "Pet Name",
        Placeholder = "e.g. Frost Dragon",
        Value = "",
        Callback = function(value)
            petName = value
        end
    })

    PetsTab:Dropdown({
        Title = "Pet Type",
        Values = {"FR", "F", "R", "N"},
        Value = "FR",
        Callback = function(v)
            petType = v
        end
    })

end)
