-- God damn these are a lot of locals
local onJob = false
local holdingBox = false
local jobComplete = false
local currentBoxes = 0
local box = nil
local route = {}
local numVectors = 0
local currentDropZone = nil
local jobVehicle = nil
local vehicleReturned = false
local blip = nil
local endBlip = nil
local delivered = 0
local getsRandomLoot = false
local cooldown = false
local distanceCovered = 0


local function addDepotBlip()

    endBlip = AddBlipForCoord(Config.PedLocation.x, Config.PedLocation.y, Config.PedLocation.z)
    Wait(800)
    SetBlipSprite(endBlip, 473)
    SetBlipColour(endBlip, 5)
    SetBlipScale(endBlip, 1.0)
    SetBlipRoute(endBlip, true)
    SetBlipRouteColour(endBlip, 5)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString('Postal Depot')
    EndTextCommandSetBlipName(endBlip)


end

-- Function to calculate distance between two vectors
local function calculateDistance(vec1, vec2)
    return #(vec1 - vec2)
end

-- Function to shuffle a table (Pun intended)
local function shuffleTable(t)
    local rand = math.random
    assert(t, "shuffleTable() expected a table, got nil")
    local iterations = #t
    local j

    for i = iterations, 2, -1 do
        j = rand(i)
        t[i], t[j] = t[j], t[i]
    end
end


-- Function to set the delivery blip
local function setDeliveryRoute(coords)

    if blip then
        RemoveBlip(blip)
    end

    if currentDropZone then
        exports.ox_target:removeZone(currentDropZone)
    end
    blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    Wait(800)
    SetBlipSprite(blip, 478)
    SetBlipColour(blip, 28)
    SetBlipScale(blip, 0.6)
    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, 28)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString('Delivery Location')
    EndTextCommandSetBlipName(blip)

    local playerCoords = lib.callback.await('ph_delivery:server:getPlayerCoords', cache.serverId)

    if not playerCoords then
        return
    end

    local drivingDistance = calculateDistance(playerCoords, vector3(coords.x, coords.y, coords.z))


    local dropZone = exports.ox_target:addBoxZone({
        coords = coords,
        size = vector3(2, 2, 2),
        rotation = 0,
        debug = Config.Debug,
        options = {
            label = 'Deliver Package',
            distance = 2.0,
            onSelect = function()
                if not holdingBox then
                    return exports.qbx_core:Notify('You are not holding a box', 'error')
                end
                ClearPedTasksImmediately(cache.ped)
                DeleteObject(box)
                if lib.progressCircle({
                        duration = 500,
                        label = 'Delivering package',
                        useWhileDead = false,
                        canCancel = true,
                        allowFalling = false,
                        allowCuffed = false,
                        allowSwimming = false,
                        allowRagDoll = false,
                        disable = {
                            car = true,
                            move = true,
                            combat = true,

                        },
                        anim = {
                            dict = 'random@domestic',
                            clip = 'pickup_low',
                        }

                    }) then
                    holdingBox = false

                    if currentBoxes == 0 then
                        ClearPedTasks(cache.ped)
                        RemoveBlip(blip)
                        addDepotBlip()
                        exports.ox_target:removeZone(currentDropZone)
                        exports.qbx_core:Notify('All packages delivered, return to the depot to collect your pay', 'success')
                        jobComplete = true
                        distanceCovered = distanceCovered + drivingDistance
                    else
                        distanceCovered = distanceCovered + drivingDistance
                        table.remove(route, 1)
                        ClearPedTasks(cache.ped)
                        RemoveBlip(blip)
                        Wait(1600)
                        setDeliveryRoute(route[1])
                        exports.qbx_core:Notify('Package delivered, go to your next stop', 'success')
                    end
                end
            end,
            canInteract = function()
                if onJob and holdingBox then
                    return true
                else
                    return false
                end
            end
        }
    })
    currentDropZone = dropZone
end


-- Function to organize routes using nearest neighbor algorithm
local function organizeRoutes(routes)
    local organizedRoutes = {}
    local currentPoint = table.remove(routes, 1)
    table.insert(organizedRoutes, currentPoint)

    while #routes > 0 do
        local nearestIndex = nil
        local nearestDistance = math.huge

        for i, point in ipairs(routes) do
            local distance = calculateDistance(vector3(currentPoint.x, currentPoint.y, currentPoint.z), vector3(point.x, point.y, point.z))
            if distance < nearestDistance then
                nearestDistance = distance
                nearestIndex = i
            end
        end

        currentPoint = table.remove(routes, nearestIndex)
        table.insert(organizedRoutes, currentPoint)
    end

    return organizedRoutes
end

-- Go to the guy, Start the job
RegisterNetEvent('ph_delivery:client:StartJob', function()
    if onJob then
        return
    end

    if cooldown then
        return exports.qbx_core:Notify('You must wait ' .. Config.Cooldown .. ' minutes before starting another job', 'error')
    end

    onJob = true
    local veh = lib.callback.await('ph_delivery:server:spawnVehicle', cache.serverId)
    jobVehicle = NetworkGetEntityFromNetworkId(veh)
    local plate = GetVehicleNumberPlateText(jobVehicle)

    SetEntityAsMissionEntity(jobVehicle, true, true)
    SetVehicleFuelLevel(jobVehicle, 100.0)
    if Config.UsingOXFuel then
    Entity(jobVehicle).state.fuel = 100
    end

    TriggerServerEvent('qb-vehiclekeys:server:AcquireVehicleKeys', plate)

    exports.qbx_core:Notify('Vehicles outback, Bring it into the warehouse and start loading', 'success', 7000)

    -- Generate a random number between 2 and 6
    numVectors = math.random(Config.MinStops, Config.MaxStops)

    -- Shuffle the Config.Routes table
    shuffleTable(Config.Routes)

    -- Select the first numVectors from the shuffled table
    route = {}
    for i = 1, numVectors do
        table.insert(route, Config.Routes[i])
    end

    -- Organize the routes
    route = organizeRoutes(route)

    exports.qbx_core:Notify('you have ' .. numVectors .. ' stops to make', 'success', 7000)

    exports.ox_target:addLocalEntity(jobVehicle,
        {
            {
                name = 'loadPackage',
                icon = 'fa-solid fa-id-card',
                distance = 2.0,
                label = 'Load Package',
                bones = { 'door_dside_r', 'door_pside_r' },
                onSelect = function()
                    if not holdingBox then
                        return exports.qbx_core:Notify('You are not holding a box', 'error')
                    end
                    holdingBox = false
                    SetVehicleDoorOpen(jobVehicle, 2, false, false)
                    SetVehicleDoorOpen(jobVehicle, 3, false, false)
                    lib.requestAnimDict('anim@heists@load_box', 15000)
                    TaskPlayAnim(cache.ped, 'anim@heists@load_box', 'load_box_1', 8.0, 8.0, -1, 1, 0, false, false, false)
                    Wait(3000)
                    ClearPedTasks(cache.ped)
                    DeleteObject(box)

                    currentBoxes = currentBoxes + 1


                    SetVehicleDoorShut(jobVehicle, 2, false)
                    SetVehicleDoorShut(jobVehicle, 3, false)

                    if currentBoxes == numVectors then
                        exports.qbx_core:Notify('All packages loaded, go to your first stop', 'success')
                        setDeliveryRoute(route[1])
                    else
                        exports.qbx_core:Notify('Package loaded, You need to load another package', 'inform')
                    end
                end,
                canInteract = function()
                    if onJob and holdingBox then
                        return true
                    else
                        return false
                    end
                end
            },
            {
                name = 'unloadPackage',
                icon = 'fa-solid fa-id-card',
                distance = 2.0,
                label = 'Unload Package',
                bones = { 'door_dside_r', 'door_pside_r' },
                onSelect = function()
                    if holdingBox then
                        return exports.qbx_core:Notify('You are already holding a box', 'error')
                    end
                    if currentBoxes == 0 then
                        return exports.qbx_core:Notify('Your vehicle is empty', 'error')
                    end
                    holdingBox = true
                    currentBoxes = currentBoxes - 1
                    delivered = delivered + 1
                    SetVehicleDoorOpen(jobVehicle, 2, false, false)
                    SetVehicleDoorOpen(jobVehicle, 3, false, false)
                    lib.requestAnimDict('anim@amb@machinery@speed_drill@', 15000)
                    TaskPlayAnim(cache.ped, 'anim@amb@machinery@speed_drill@', 'unload_rh_03_amy_skater_01', 8.0, 8.0, -1,
                        1, 0, false, false, false)
                    Wait(1000)
                    ClearPedTasksImmediately(cache.ped)
                    lib.requestAnimDict('anim@heists@box_carry@', 15000)
                    TaskPlayAnim(cache.ped, 'anim@heists@box_carry@', 'idle', 8.0, 8.0, -1, 48, 0, false, false, false)
                    lib.requestModel(`prop_cs_cardbox_01`, 10000)
                    box = CreateObject(`prop_cs_cardbox_01`, 0, 0, 0, true, true, true)
                    Wait(10)
                    AttachEntityToEntity(box, cache.ped, GetPedBoneIndex(cache.ped, 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        true, true, false, true, 1, true)
                    SetVehicleDoorShut(jobVehicle, 2, false)
                    SetVehicleDoorShut(jobVehicle, 3, false)
                end,
                canInteract = function()
                    if #route == 0 then
                        return false
                    end
                    local playerCoords = GetEntityCoords(cache.ped)
                    local targetCoords = route[1]
                    local distance = #(playerCoords - targetCoords)
                    if onJob and not holdingBox and distance <= 75 then
                        return true
                    else
                        return false
                    end
                end
            }
        })
end)


-- Collect paycheck
RegisterNetEvent('ph_delivery:client:collectPaycheck', function()

    local rewardEarned

    if currentBoxes == 0 and jobComplete then

        rewardEarned = numVectors
        getsRandomLoot = true
    elseif currentBoxes == 0 and not jobComplete then -- If they have not delivered any packages, Why should they get paid?

        rewardEarned = 0
    else

        rewardEarned = delivered
        cooldown = true
    end


    TriggerServerEvent('ph_delivery:server:collectPaycheck', cache.serverId, NetworkGetNetworkIdFromEntity(jobVehicle),
    rewardEarned, vehicleReturned, getsRandomLoot, distanceCovered)

    jobComplete = false
    onJob = false
    currentBoxes = 0
    route = {}
    numVectors = 0
    distanceCovered = 0
    currentDropZone = nil
    RemoveBlip(endBlip)
    RemoveBlip(blip)
    endBlip = nil
    delivered = 0

    if cooldown then
        CreateThread(function()
            Wait(60 * 1000 * Config.Cooldown)
            cooldown = false
        end)
    end
end)



-------------------------------------INITIALISE SCRIPT-------------------------------------

local function postalMenu()
    local options = {}

    if not onJob then
        table.insert(options, {
            title = 'Start Job',
            icon = 'fa-solid fa-id-card',
            onSelect = function()
                TriggerEvent('ph_delivery:client:StartJob')
            end
        })
    end

    if onJob then
        table.insert(options, {
            title = 'Collect Paycheck',
            icon = 'fa-solid fa-money-bill',
            onSelect = function()
                TriggerEvent('ph_delivery:client:collectPaycheck')
            end
        })
    end

    lib.registerContext({
        id = 'postal_menu',
        title = 'Postal Menu',
        options = options
    })

    lib.showContext('postal_menu')
end

function createPostalPed()
    lib.requestModel(`s_m_m_postal_01`)
    local ped = CreatePed(0, `s_m_m_postal_01`, Config.PedLocation.x, Config.PedLocation.y, Config.PedLocation.z - 1,
        Config.PedLocation.w, false, false)
    SetEntityHeading(ped, Config.PedLocation.w)
    PlaceObjectOnGroundProperly(ped)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_CLIPBOARD', 0, true)

    local option = {
        name = 'postalPedRun',
        icon = 'fa-solid fa-id-card',
        distance = 2.0,
        label = 'Go Postal',
        onSelect = function()
            postalMenu()
        end
    }

    exports.ox_target:addLocalEntity(ped, option)
end

AddEventHandler('onClientResourceStart', function(resource)
    if resource == GetCurrentResourceName() then

        Wait(800)
        createPostalPed()
        local postalBlip = AddBlipForCoord(Config.PedLocation.x, Config.PedLocation.y, Config.PedLocation.z)
        Wait(800)
        SetBlipSprite(postalBlip, 478)
        SetBlipColour(postalBlip, 5)
        SetBlipScale(postalBlip, 0.7)
        SetBlipAsShortRange(postalBlip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString('Postal Depot')
        EndTextCommandSetBlipName(postalBlip)

    end
end)


exports.ox_target:addBoxZone({
    coords = vector3(-313.33480834961, -1282.0482177734, 31.097756576538),
    size = vector3(8, 1.5, 2),
    rotation = 0,
    debug = Config.Debug,
    options = {
        label = 'Pick Up Box',
        distance = 2.0,
        onSelect = function()
            if holdingBox then
                return
            end
            if currentBoxes == numVectors then
                return exports.qbx_core:Notify('Your vehicle is full', 'error')
            end
            if lib.progressCircle({
                    duration = math.random(3000, 5500),
                    label = 'Picking up box',
                    useWhileDead = false,
                    canCancel = true,
                    allowFalling = false,
                    allowCuffed = false,
                    allowSwimming = false,
                    allowRagDoll = false,
                    disable = {
                        car = true,
                        move = true,
                        combat = true,

                    },
                    anim = {
                        dict = 'missheist_agency2aig_13',
                        clip = 'pickup_briefcase_upperbody',
                    }

                }) then
                holdingBox = true
                lib.requestAnimDict('anim@heists@box_carry@', 15000)
                TaskPlayAnim(cache.ped, 'anim@heists@box_carry@', 'idle', 8.0, 8.0, -1, 48, 0, false, false, false)
                Wait(300)
                lib.requestModel(`prop_cs_cardbox_01`, 10000)
                box = CreateObject(`prop_cs_cardbox_01`, 0, 0, 0, true, true, true)
                Wait(10)
                AttachEntityToEntity(box, cache.ped, GetPedBoneIndex(cache.ped, 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    true, true, false, true, 1, true)
            end
        end,
        canInteract = function()
            if onJob and not holdingBox then
                return true
            else
                return false
            end
        end
    }

})


-------------------------------------CAR RETURN-------------------------------------


exports.ox_target:addSphereZone({
    coords = Config.ReturnVehicleLocation,
    radius = 10.0,
    debug = Config.Debug,
    options = {
        label = 'Return Vehicle',
        distance = 6.0,
        onSelect = function ()
            local vehicleWereIn = GetVehiclePedIsIn(PlayerPedId(), false)
            if vehicleWereIn == jobVehicle then
               if DoesEntityExist(jobVehicle) then
                DeleteEntity(jobVehicle)
                vehicleReturned = true
                jobVehicle = nil
               else
                exports.qbx_core:Notify('Error Fetching the vehicle. Try again', 'error')
               end
            else
                exports.qbx_core:Notify('You are not in the vehicle', 'error')
            end
        end,
        canInteract = function ()
            if onJob then
                return true
            else
                return false
            end
        end
    }
})

RegisterNetEvent('ph_delivery:client:handleVehicle', function(distance)

    local timeout = 0

    if not jobVehicle then
        return print('No job vehicle')
    end

    if not DoesEntityExist(jobVehicle) then
        return print('Job vehicle does not exist')
    end

    Wait(1000)

    if distance > Config.VehicleReturnDistance then
        if DoesEntityExist(jobVehicle) then
            SetEntityAsMissionEntity(jobVehicle, false, false)
        end
        Wait(1000)
        local areWeMission = IsEntityAMissionEntity(jobVehicle)

        jobVehicle = nil
    else
        while DoesEntityExist(jobVehicle) do
            SetEntityAsMissionEntity(jobVehicle, false, false)
            Wait(1000)
            DeleteEntity(jobVehicle)
            timeout = timeout + 1

            if timeout > 10 then
                break
            end
        end
    end
end)