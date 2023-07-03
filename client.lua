local ox_inventory = exports.ox_inventory
local QBCore = exports['qb-core']:GetCoreObject()
local IsTargetReady = GetResourceState("ox_target") == "started" or GetResourceState("qb-target") == "started"
local pedSpawned = false

-- local function SpawnPed()
--     if pedSpawned then return end
--     local model = joaat(Config.model)
--     lib.requestModel(model)
--     Wait(2000)
--     local coords = Config.coords4
--     local shopdude = CreatePed(0, model, coords.x, coords.y, coords.z-1.0, coords.w, false, false)


--     TaskStartScenarioInPlace(shopdude, 'WORLD_HUMAN_CLIPBOARD', 0, true)
--     FreezeEntityPosition(shopdude, true)
--     SetEntityInvincible(shopdude, true)
--     SetBlockingOfNonTemporaryEvents(shopdude, true)
--     Wait(500)
--     pedSpawned = true
--     if IsTargetReady then
--         if Config.targettype == 'ox' then
--             exports.ox_target:addLocalEntity(shopdude, {
--                 {
--                     name = 'rj-warrants',
--                     label = 'Check Warrants ($'..tostring(Config.Cost)..')',
--                     event = 'rj-warrants:client:targetted',
--                     icon = 'fa-solid fa-scroll',
--                     canInteract = function(_, distance)
--                         return distance < 2.0
--                     end
--                 },
--                 {
--                     name = 'rj-warrants:pd',
--                     label = 'Check Warrants(POLICE)',
--                     event = 'rj-warrants:client:targettedpd',
--                     icon = 'fa-solid fa-scroll',
--                     canInteract = function(_, distance)
--                         if QBCore.Functions.GetPlayerData().job.name == Config.JobName and QBCore.Functions.GetPlayerData().job.grade.level >= Config.LowestRank then
--                             return distance < 2.0
--                         else
--                             return false
--                         end
--                     end
--                 },
--             })
--         elseif Config.targettype == 'qb' then
--             exports['qb-target']:AddTargetEntity(shopdude, {
--                 {
--                     num = 1,
--                     type = 'client',
--                     event = 'rj-warrants:client:targetted',
--                     icon = 'fa-solid fa-scroll',
--                     label = 'Check Warrants',
--                     canInteract = function(_, distance)
--                         return distance < 2.0
--                     end
--                 },
--                 {
--                     num = 2,
--                     type = 'client',
--                     event = 'rj-warrants:client:targettedpd',
--                     icon = 'fa-solid fa-scroll',
--                     label = 'Check Warrants(POLICE)',
--                     canInteract = function(_, distance)
--                         if QBCore.Functions.GetPlayerData().job.name == Config.JobName and QBCore.Functions.GetPlayerData().job.grade.level >= Config.LowestRank then
--                             return distance < 2.0
--                         else
--                             return false
--                         end
--                     end
--                 }
--             })
--         else
--             print('This target is not supported')
--         end
--     else
--         print('No targets found')
--     end
-- end

-- AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
--     SpawnPed()
-- end)

-- AddEventHandler('onResourceStart', function(resource) if GetCurrentResourceName() ~= resource then return end
--     SpawnPed()
-- end)

function Menu()
    local Player = QBCore.Functions.GetPlayerData()
    local check = lib.callback.await('rj-warrants:callback:warrants', false, Player.citizenid)

    local active
    local desc
    if check > 0 then
        active = "ACTIVE"
        desc = tostring(check).." Days Left"
    else
        active = "INACTIVE"
        desc = nil
    end
    lib.registerContext({
        id = 'rj-warrants:open',
        title = 'Warrants Check',
        options = {
            {
                title = Player.charinfo.firstname.." "..Player.charinfo.lastname.." : Warrant "..active,
                description = desc,
            },
        },
    })
    lib.showContext('rj-warrants:open')
end

function PDMenu(cid)
    local check = lib.callback.await('rj-warrants:callback:warrantspd', 100, cid)
    local opt = {}
    for i = 1, #check do
        local info = json.decode(check[i].charinfo)
        opt[#opt + 1] = {
            title = info.firstname..' '..info.lastname,
            description = "Citizen ID: "..check[i].citizenid.."\nExpiry Date: "..check[i].date.."\nOfficer: "..check[i].officer,
            icon = 'fa-solid fa-user',
            arrow = true,
            onSelect = function()
                lib.hideContext()
                lib.showContext('rj-warrants:openpd'..i)
            end,
        }
        lib.registerContext({
            id = 'rj-warrants:openpd'..i,
            title = check[i].citizenid,
            options = {
                {
                    title = 'Remove Public Warrant',
                    description = 'Remove this suspect\'s public warrant post?',
                    icon = 'xmark',
                    serverEvent = 'rj-warrants:server:removewarrant',
                    args = {
                      cid = check[i].citizenid
                    },
                    onSelect = function()
                        lib.hideContext()
                    end
                }
            },
            menu = 'rj-warrants:openpd'
        })
    end
    table.sort(opt, function(a, b) return a.title < b.title end)
    lib.registerContext({
        id = 'rj-warrants:openpd',
        title = 'Active Public Warrants',
        options = opt,
    })
    lib.showContext('rj-warrants:openpd')
end

RegisterNetEvent('rj-warrants:client:targetted', function()
    local coords = GetEntityCoords(PlayerPedId())
    local payment
    -- local distance = #(coords - vector3(Config.coords4.x, Config.coords4.y, Config.coords4.z))
    -- if distance > 3.0 then print('end') return end

    if Config.Pay then
        local success = exports['qb-phone']:PhoneNotification("Payment Request", 'Payment Request from the Warrant Officer', 'fas fa-gavel', '#b3e0f2', "NONE", 'fas fa-check-circle', 'fas fa-times-circle')
        if success then
            payment = lib.callback.await('rj-warrants:callback:payments', false)
        else
            return
        end
        if payment then
            lib.notify({
                title = 'Payment Successful',
                description = 'Your Payment has been successful',
                type = 'success'
            })
            Menu()
        else
            lib.notify({
                title = 'Not Enough Money',
                description = 'You do not have enough money',
                type = 'error'
            })
        end
    else
        Menu()
    end
end)

RegisterNetEvent('rj-warrants:client:targettedpd', function()
    local coords = GetEntityCoords(PlayerPedId())
    -- local distance = #(coords - vector3(Config.coords4.x, Config.coords4.y, Config.coords4.z))
    -- if distance > 3.0 then print('end') return end

    PDMenu()
end)

lib.callback.register('rj-warrants:callback:openmenu', function(cid)
    PDMenu(cid)
end)

RegisterNetEvent('rj-warrants:client:PlayerWarrants', function()
    local input = lib.inputDialog('Get a Civilian\'s Warrants', {
        { type = "select", label = "Search Type", options = {{value = 'cid', label = 'Citizen ID'}, {value = 'sid', label = 'Server ID'}}, default = 'sid', required = true },
        { type = "input", label = "ID", required = true },
    })
    if not input then return end
    if input[1] == 'cid' then
        TriggerServerEvent('rj-warrants:server:PlayerWarrants', input[2], true)
    elseif input[1] == 'sid' then
        TriggerServerEvent('rj-warrants:server:PlayerWarrants', input[2], false)
    end
end)