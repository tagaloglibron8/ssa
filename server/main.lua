local QBX = exports['qbx_core']:GetCoreObject()
local config = require 'config.server'
local sharedConfig = require 'config.shared'

-- Server-side functions for the enhanced trucker job
local function getPlayerData(source)
    local Player = QBX.Functions.GetPlayer(source)
    if not Player then return nil end
    return Player
end

-- Spawn vehicle callback
lib.callback.register('qbx_truckerjob:server:spawnVehicle', function(source, modelHash)
    local Player = getPlayerData(source)
    if not Player then return nil, nil end
    
    -- Check if player has enough money for rental
    local rentalCost = config.job.bailPrice
    if Player.PlayerData.money.cash < rentalCost then
        TriggerClientEvent('qbx_core:notify', source, 'You need $' .. rentalCost .. ' to rent a vehicle', 'error')
        return nil, nil
    end
    
    -- Deduct rental cost
    Player.Functions.RemoveMoney('cash', rentalCost, 'trucker-vehicle-rental')
    
    -- Generate plate
    local plate = 'TRUCK' .. math.random(1000, 9999)
    
    -- Spawn vehicle on client
    local coords = sharedConfig.locations.vehicle.coords
    local vehicle = CreateVehicle(modelHash, coords.x, coords.y, coords.z, coords.w, true, true)
    
    if not vehicle or not DoesEntityExist(vehicle) then
        -- Refund if vehicle spawn failed
        Player.Functions.AddMoney('cash', rentalCost, 'trucker-vehicle-refund')
        TriggerClientEvent('qbx_core:notify', source, 'Failed to spawn vehicle', 'error')
        return nil, nil
    end
    
    -- Set vehicle properties
    SetVehicleNumberPlateText(vehicle, plate)
    SetEntityAsMissionEntity(vehicle, true, true)
    
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    return netId, plate
end)

-- Get new task callback
lib.callback.register('qbx_truckerjob:server:getNewTask', function(source, isFirstTask)
    local Player = getPlayerData(source)
    if not Player then return nil, nil, nil end
    
    -- Generate delivery pool
    local pool = {}
    
    -- Add stores to pool
    if sharedConfig.deliveries.stores then
        for i = 1, #sharedConfig.deliveries.stores do
            table.insert(pool, {type = "store", index = i})
        end
    end
    
    -- Add houses to pool
    if sharedConfig.deliveries.houses then
        for i = 1, #sharedConfig.deliveries.houses do
            table.insert(pool, {type = "house", index = i})
        end
    end
    
    -- Shuffle pool
    for i = #pool, 2, -1 do
        local j = math.random(i)
        pool[i], pool[j] = pool[j], pool[i]
    end
    
    -- Select random location and box count
    local poolIndex = math.random(1, #pool)
    local boxCount = math.random(config.deliveries.drops.min, config.deliveries.drops.max)
    
    return poolIndex, boxCount, pool
end)

-- Record drop event
RegisterNetEvent('qbx_truckerjob:server:recordDrop', function()
    local Player = getPlayerData(source)
    if not Player then return end
    
    -- You can add database logging here if needed
    print(('Player %s recorded a delivery drop'):format(Player.PlayerData.name))
end)

-- Get paid event
RegisterNetEvent('qbx_truckerjob:server:getPaid', function(amount, completedDeliveries, totalDeliveries)
    local Player = getPlayerData(source)
    if not Player then return end
    
    local basePay = sharedConfig.payment.base
    local pay = amount or (completedDeliveries * basePay)
    
    -- Apply tax
    local tax = math.floor(pay * (config.job.paymentTax / 100))
    local finalPay = pay - tax
    
    Player.Functions.AddMoney('bank', finalPay, 'trucker-delivery-payment')
    
    TriggerClientEvent('qbx_core:notify', source, 
        ('You earned $%d for %d/%d deliveries (Tax: $%d)'):format(finalPay, completedDeliveries, totalDeliveries, tax), 
        'success'
    )
end)

-- Return vehicle event
RegisterNetEvent('qbx_truckerjob:server:returnVehicle', function()
    local Player = getPlayerData(source)
    if not Player then return end
    
    -- You can add additional logic here for vehicle returns
    print(('Player %s returned their vehicle'):format(Player.PlayerData.name))
end)