local config = require 'config.client'
local sharedConfig = require 'config.shared'

-- State variables
local currentZones = {}
local currentLocation = {}
local currentBlip = 0
local hasBox = false
local truckVehBlip = 0
local truckerBlip = 0
local returningToStation = false
local returningToDepot = false
local currentPlate
local jobActive = false
local deliveryTimeout = 0
local npcPed = nil
local npcSpawned = false
local rentalNpcPed = nil
local rentalNpcSpawned = false
local totalDeliveries = 0
local completedDeliveries = 0
local waitingForNextDelivery = false
local driverNPC = nil
local locations = {}
local isDelivering = false
local nuiOpen = false

-- Cache frequently accessed values
local PlayerData = QBX.PlayerData or {}
local PlayerJob = PlayerData.job or {}

-- Pre-calculate locale strings
local localeStrings = {
    error_no_driver = "You need to be the driver to return the vehicle",
    error_vehicle_not_correct = "This is not the correct vehicle",
    error_backdoors_not_open = "Back doors are not open",
    error_too_far_from_trunk = "Too far from trunk",
    error_cancelled = "Action cancelled",
    error_get_out_vehicle = "Get out of the vehicle first",
    error_too_far_from_delivery = "Too far from delivery point",
    error_vehicle_already_out = "Vehicle already out",
    info_pickup_paycheck = "Pickup Paycheck",
    info_store_vehicle = "Store Vehicle",
    info_vehicles = "Vehicles",
    info_deliver_to_store = "Deliver to store",
    mission_job_completed = "Job completed",
    mission_store_reached = "Store reached",
    mission_another_box = "Another box",
    mission_return_to_station = "Return to station",
    mission_goto_next_point = "Go to next point",
    menu_header = "Delivery Services",
    npc_talk = "Talk to Manager",
    npc_name = "Delivery Coordinator",
    grab_box = "Grab Box",
    deliver_box = "Deliver Box",
    return_vehicle = "Return Vehicle"
}

-- NUI Functions
local function openNUI()
    if nuiOpen then return end
    
    nuiOpen = true
    SetNuiFocus(true, true)
    
    -- Update status and menu state
    local status = {
        jobActive = jobActive,
        completedDeliveries = completedDeliveries,
        totalDeliveries = totalDeliveries,
        vehicle = currentPlate or "None"
    }
    
    local menuState = {
        true,  -- Rent Vehicle - always available
        jobActive,  -- Return Vehicle - only when job is active
        true   -- Collect Paycheck - always available
    }
    
    SendNUIMessage({
        action = 'openNUI',
        status = status,
        menuState = menuState
    })
end

local function closeNUI()
    if not nuiOpen then return end
    
    nuiOpen = false
    SetNuiFocus(false, false)
    
    SendNUIMessage({
        action = 'closeNUI'
    })
end

-- NUI Callbacks
RegisterNUICallback('closeNUI', function(data, cb)
    closeNUI()
    cb('ok')
end)

RegisterNUICallback('spawnVehicle', function(data, cb)
    if jobActive then
        notify(localeStrings.error_vehicle_already_out, 'error')
        cb('error')
        return
    end
    
    -- Open vehicle selection menu
    openMenuGarage()
    cb('ok')
end)

RegisterNUICallback('returnVehicle', function(data, cb)
    if not jobActive then
        notify("No active job to return vehicle for", 'error')
        cb('error')
        return
    end
    
    returnVehicle()
    cb('ok')
end)

RegisterNUICallback('getPaycheck', function(data, cb)
    getPaid()
    cb('ok')
end)

RegisterNUICallback('requestStatus', function(data, cb)
    local status = {
        jobActive = jobActive,
        completedDeliveries = completedDeliveries,
        totalDeliveries = totalDeliveries,
        vehicle = currentPlate or "None"
    }
    
    SendNUIMessage({
        action = 'updateStatus',
        status = status
    })
    
    cb('ok')
end)

-- F6 Key Handler
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        if IsControlJustPressed(0, 167) then -- F6 key
            if nuiOpen then
                closeNUI()
            else
                openNUI()
            end
        end
        
        -- Close NUI if player dies or is in a cutscene
        if nuiOpen and (IsPedDeadOrDying(PlayerPedId(), true) or IsPauseMenuActive()) then
            closeNUI()
        end
    end
end)

-- Utility functions
local function isPlayerJobTrucker()
    return true -- REMOVED JOB RESTRICTION - SIDE JOB FOR EVERYONE
end

local function notify(message, type)
    if exports and exports.qbx_core then
        exports.qbx_core:Notify(message, type)
    else
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(message)
        EndTextCommandThefeedPostTicker(false, true)
    end
end

local function debugPrint(...)
    if config.debug then
        print(...)
    end
end

-- Function to handle wait for next delivery
local function waitForNextDelivery()
    waitingForNextDelivery = true
    notify("Wait for delivery...", "inform")
    
    Citizen.Wait(60000)
    
    waitingForNextDelivery = false
    notify("Next delivery location available!", "success")
end

-- NPC Functions
local function createNPC()
    if npcSpawned or (npcPed and DoesEntityExist(npcPed)) then return end
    
    if not sharedConfig.locations or not sharedConfig.locations.npc then
        debugPrint("NPC configuration not found, using default values")
        local defaultNpcConfig = {
            model = 's_m_m_trucker_01',
            coords = vector3(129.6644, -3220.2898, 5.8576),
            heading = 1.1093
        }
        sharedConfig.locations = sharedConfig.locations or {}
        sharedConfig.locations.npc = defaultNpcConfig
    end
    
    local npcConfig = sharedConfig.locations.npc
    local model = GetHashKey(npcConfig.model)
    
    if not IsModelValid(model) then
        debugPrint("Invalid NPC model:", npcConfig.model)
        return
    end
    
    RequestModel(model)
    local timeout = 0
    while not HasModelLoaded(model) and timeout < 5000 do
        timeout = timeout + 100
        Citizen.Wait(100)
    end
    
    if not HasModelLoaded(model) then
        debugPrint("Failed to load NPC model:", npcConfig.model)
        return
    end
    
    npcPed = CreatePed(0, model, npcConfig.coords.x, npcConfig.coords.y, npcConfig.coords.z - 1, npcConfig.heading, false, false)
    
    if not npcPed or not DoesEntityExist(npcPed) then
        debugPrint("Failed to create NPC")
        return
    end
    
    SetEntityAsMissionEntity(npcPed, true, true)
    SetBlockingOfNonTemporaryEvents(npcPed, true)
    SetPedFleeAttributes(npcPed, 0, 0)
    SetPedCombatAttributes(npcPed, 17, 1)
    SetPedRandomComponentVariation(npcPed, 0)
    SetPedRandomProps(npcPed)
    FreezeEntityPosition(npcPed, true)
    SetEntityInvincible(npcPed, true)
    
    if exports and exports.ox_target then
        exports.ox_target:addLocalEntity(npcPed, {
            {
                name = 'trucker_npc',
                icon = 'fas fa-truck',
                label = localeStrings.npc_talk,
                distance = 2.5,
                onSelect = function()
                    openNUI()
                end,
                canInteract = function()
                    local ped = PlayerPedId()
                    return not IsPedInAnyVehicle(ped, false) and not jobActive
                end
            }
        })
    end
    
    npcSpawned = true
    debugPrint("NPC created successfully")
end

local function createRentalNPC()
    if rentalNpcSpawned or (rentalNpcPed and DoesEntityExist(rentalNpcPed)) then return end
    
    local rentalNpcConfig = sharedConfig.locations.rentalNpc or {
        model = 's_m_m_autoshop_02',
        coords = vector3(130.0339, -3178.6028, 5.8960),
        heading = 176.9028
    }
    
    local model = GetHashKey(rentalNpcConfig.model)
    RequestModel(model)
    local timeout = 0
    while not HasModelLoaded(model) and timeout < 5000 do
        timeout = timeout + 100
        Citizen.Wait(100)
    end
    
    if not HasModelLoaded(model) then
        debugPrint("Failed to load rental NPC model")
        return
    end
    
    rentalNpcPed = CreatePed(0, model, rentalNpcConfig.coords.x, rentalNpcConfig.coords.y, rentalNpcConfig.coords.z - 1, rentalNpcConfig.heading, false, false)
    
    if not DoesEntityExist(rentalNpcPed) then
        debugPrint("Failed to create rental NPC")
        return
    end
    
    SetEntityAsMissionEntity(rentalNpcPed, true, true)
    SetBlockingOfNonTemporaryEvents(rentalNpcPed, true)
    SetPedFleeAttributes(rentalNpcPed, 0, 0)
    SetPedCombatAttributes(rentalNpcPed, 17, 1)
    SetPedRandomComponentVariation(rentalNpcPed, 0)
    SetPedRandomProps(rentalNpcPed)
    FreezeEntityPosition(rentalNpcPed, true)
    SetEntityInvincible(rentalNpcPed, true)
    
    if exports and exports.ox_target then
        exports.ox_target:addLocalEntity(rentalNpcPed, {
            {
                name = 'trucker_return_npc',
                icon = 'fas fa-undo',
                label = localeStrings.return_vehicle,
                distance = 15.5,
                onSelect = function()
                    if lib and lib.progressBar then
                        local success = lib.progressBar({
                            duration = 2000,
                            label = 'Processing vehicle return...',
                            useWhileDead = false,
                            canCancel = false,
                            disable = {
                                car = true,
                                move = true,
                                combat = true
                            }
                        })

                        if success then
                            returnVehicle()
                        else
                            notify(" Vehicle return cancelled.", "error")
                        end
                    else
                        returnVehicle()
                    end
                end,
                canInteract = function()
                    return jobActive
                end
            }
        })
    end
    
    rentalNpcSpawned = true
    debugPrint("Rental NPC created successfully")
end

local function deleteNPC()
    if npcPed and DoesEntityExist(npcPed) then
        if exports and exports.ox_target then
            exports.ox_target:removeLocalEntity(npcPed, 'trucker_npc')
        end
        DeleteEntity(npcPed)
        npcPed = nil
    end
    npcSpawned = false
    
    if rentalNpcPed and DoesEntityExist(rentalNpcPed) then
        if exports and exports.ox_target then
            exports.ox_target:removeLocalEntity(rentalNpcPed, 'trucker_return_npc')
        end
        DeleteEntity(rentalNpcPed)
        rentalNpcPed = nil
    end
    rentalNpcSpawned = false
    
    debugPrint("NPCs deleted")
end

-- Main functions
local function returnToStation()
    if DoesBlipExist(truckVehBlip) then
        SetBlipRoute(truckVehBlip, true)
        returningToStation = true
    end
end

local function isTruckerVehicle(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return false end
    if not sharedConfig.vehicles then return false end
    local model = GetEntityModel(vehicle)
    return sharedConfig.vehicles[model] ~= nil
end

local function removeElements()
    ClearAllBlipRoutes()
    
    local blips = {truckVehBlip, truckerBlip, currentBlip}
    for _, blip in ipairs(blips) do
        if blip and DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    
    truckVehBlip = 0
    truckerBlip = 0
    currentBlip = 0

    for _, zone in ipairs(currentZones) do
        if zone and zone.remove then
            zone:remove()
        end
    end

    currentZones = {}
end

local function getPaid()
    TriggerServerEvent('qbx_truckerjob:server:getPaid')

    if DoesBlipExist(currentBlip) then
        RemoveBlip(currentBlip)
        ClearAllBlipRoutes()
        currentBlip = 0
    end
end

-- Helper to safely delete a vehicle
local function safeDeleteVehicle(vehicle)
    if DoesEntityExist(vehicle) then
        NetworkRequestControlOfEntity(vehicle)
        SetEntityAsMissionEntity(vehicle, true, true)
        DeleteVehicle(vehicle)
    end
end

function returnVehicle()
    local ped = PlayerPedId()
    
    if IsPedInAnyVehicle(ped, false) then
        local vehicle = GetVehiclePedIsIn(ped, false)
        if GetPedInVehicleSeat(vehicle, -1) ~= ped then
            return notify(localeStrings.error_no_driver, 'error')
        end

        if not isTruckerVehicle(vehicle) then
            return notify(localeStrings.error_vehicle_not_correct, 'error')
        end

        safeDeleteVehicle(vehicle)
        TriggerServerEvent('qbx_truckerjob:server:returnVehicle')
    end

    if DoesBlipExist(currentBlip) then
        RemoveBlip(currentBlip)
        ClearAllBlipRoutes()
        currentBlip = 0
    end

    if currentLocation and currentLocation.zoneCombo and currentLocation.zoneCombo.remove then
        currentLocation.zoneCombo:remove()
    end

    if totalDeliveries > 0 and completedDeliveries > 0 then
        local basePay = 200
        local pay = math.floor(completedDeliveries * basePay)
        TriggerServerEvent('qbx_truckerjob:server:getPaid', pay, completedDeliveries, totalDeliveries)

        if completedDeliveries >= totalDeliveries then
            notify((" All deliveries completed! You earned $%d"):format(pay), 'success')
        else
            notify(("Partial deliveries done: %d/%d. You still earned $%d"):format(completedDeliveries, totalDeliveries, pay), 'inform')
        end
    else
        notify(" Vehicle returned but no deliveries were completed.", 'error')
    end

    ClearAllBlipRoutes()
    returningToStation = false
    returningToDepot = false
    jobActive = false
    currentLocation = {}
    hasBox = false
    currentPlate = nil
    totalDeliveries = 0
    completedDeliveries = 0
    waitingForNextDelivery = false

    notify(localeStrings.mission_job_completed, 'success')
end

function openMenuGarage()
    if jobActive then
        return notify(localeStrings.error_vehicle_already_out, 'error')
    end
    
    if not sharedConfig.vehicles then
        return notify("No vehicles configured", 'error')
    end
    
    local truckMenu = {}
    for modelHash, vehicleName in pairs(sharedConfig.vehicles) do
        truckMenu[#truckMenu + 1] = {
            title = vehicleName,
            event = 'qbx_truckerjob:client:spawnVehicle',
            args = modelHash
        }
    end

    if lib and lib.registerContext then
        lib.registerContext({
            id = 'trucker_veh_menu',
            title = localeStrings.menu_header,
            options = truckMenu
        })

        lib.showContext('trucker_veh_menu')
    else
        -- Fallback menu system
        for _, option in ipairs(truckMenu) do
            print(option.title)
        end
    end
end