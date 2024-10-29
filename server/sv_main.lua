lib.callback.register('ph_delivery:server:spawnVehicle', function(source)
    local function isLocationClear(location)
        local closestVehicle, vehicleCoords = lib.getClosestVehicle(vector3(location.x, location.y, location.z), 2.0,
            false)
        return closestVehicle == nil
    end

    local selectedSpawnLocation
    local maxAttempts = #Config.VehicleSpawnLocation
    local attempts = 0

    repeat
        attempts = attempts + 1
        local randomIndex = math.random(1, #Config.VehicleSpawnLocation)
        selectedSpawnLocation = Config.VehicleSpawnLocation[randomIndex]
    until isLocationClear(selectedSpawnLocation) or attempts >= maxAttempts

    if not isLocationClear(selectedSpawnLocation) then
        return nil
    end

    local veh = qbx.spawnVehicle({
        model = Config.DeliveryVehicle,
        spawnSource = selectedSpawnLocation,
        warp = false,
    })

    return veh
end)

lib.callback.register('ph_delivery:server:getPlayerCoords', function(source)
    local playerPed = GetPlayerPed(source)
    local coords = GetEntityCoords(playerPed)
    return coords
end)

RegisterNetEvent('ph_delivery:server:collectPaycheck',
    function(source, vehNetId, numberOfStopsDone, vehicleReturned, getsLootCrate, distanceCalculated)
        local player = exports.qbx_core:GetPlayer(source)
        local veh = NetworkGetEntityFromNetworkId(vehNetId)
        local payout = distanceCalculated * Config.PayoutPerMeter


        -- Get the vehicle's coordinates
        local vehCoords = GetEntityCoords(veh)
        -- Create a vector3 from Config.PedLocation
        local pedLocation = vector3(Config.PedLocation.x, Config.PedLocation.y, Config.PedLocation.z)
        -- Calculate the distance
        local distance = #(vehCoords - pedLocation)


        local lootItem = Config.lootPool[math.random(1, #Config.lootPool)]
        local bonus = math.random(Config.minBonusPayout, Config.maxBonusPayout)
        local lootChance = math.random(1, 100)


        if distance > 80 and not vehicleReturned then
            payout = payout - Config.leftVehiclePenalty * numberOfStopsDone
        end
        if not vehicleReturned then
            TriggerClientEvent('ph_delivery:client:handleVehicle', source, distance)
        end


        if lootChance <= Config.LootBoxChance and getsLootCrate then
            exports.ox_inventory:AddItem(source, 'postal_lootbox', 1)
        end

        if getsLootCrate then
            payout = payout + bonus
        end

        -- Round the payout to the nearest whole number
        payout = math.floor(payout + 0.5)

        player.Functions.AddMoney('cash', payout, 'Delivery Job')
        exports.qbx_core:Notify(source, 'You have been paid $' .. payout .. ' in total for your deliveries.')

        if getsLootCrate then
            exports.qbx_core:Notify(source, 'You have earned a bonus of $' .. bonus .. ' for your delivery.')
        end
    end)

exports('postal_lootbox', function(event, item, inventory)
    local source = inventory.id

    local lootItem = Config.lootPool[math.random(1, #Config.lootPool)]

    exports.ox_inventory:AddItem(source, lootItem, 1)
    exports.ox_inventory:RemoveItem(source, 'postal_lootbox', 1)
end)
