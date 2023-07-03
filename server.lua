local QBCore = exports['qb-core']:GetCoreObject()

local function parseDate(str)
    local y, m, d = string.match(str, "(%d+)-(%d+)-(%d+)")
    return tonumber(str) or os.time({year = y, month = m, day = d})
end

function HasAllowedJob(src)
    if src then
        local Player = QBCore.Functions.GetPlayer(src)
        return Player.PlayerData.job.name == Config.JobName and Player.PlayerData.job.grade.level >= Config.LowestRank
    else
        return false
    end
end

AddEventHandler('onResourceStart', function(r) if GetCurrentResourceName() ~= r then return end
    local result = MySQL.query.await('SELECT * FROM `rj_warrants`')
    if result then
        for i = 1, #result do
            local row = result[i]
            local today = os.date('%Y-%m-%d')
            local seconds = 60 * 60 * 24
            local d1 = parseDate(row.date)
            local d2 = parseDate(today)
            local diff = math.floor(os.difftime(d1, d2) / seconds)
            if diff < 1 then
                MySQL.query.await('DELETE FROM `rj_warrants` WHERE citizenid = ?', {row.citizenid})
            end
            Wait(1000)
        end
    end
end)

lib.callback.register('rj-warrants:callback:warrants', function(source, cid)
    if not cid then return false end
    local diff
    local row = MySQL.single.await('SELECT * FROM `rj_warrants` WHERE citizenid = ?', {cid})
    if row and row.date then
        local today = os.date('%Y-%m-%d')
        local seconds = 60 * 60 * 24
        local d1 = parseDate(row.date)
        local d2 = parseDate(today)
        diff = math.ceil(os.difftime(d1, d2) / seconds)
        return diff
    else
        return 0
    end
end)

lib.callback.register('rj-warrants:callback:warrantspd', function(source, cid)
    local tab = {}
    local result
    if cid then
        result = MySQL.query.await('SELECT rj_warrants.citizenid, date, officer, charinfo FROM rj_warrants INNER JOIN players ON rj_warrants.citizenid = players.citizenid AND rj_warrants.citizenid = ?', {cid})
    else
        result = MySQL.query.await('SELECT rj_warrants.citizenid, date, officer, charinfo FROM rj_warrants INNER JOIN players ON rj_warrants.citizenid = players.citizenid')
    end
    if result then
        for k, v in pairs(result) do
            local date = tonumber(v.date)
            if date then result[k].date = os.date("%Y-%m-%d", result[k].date) end
        end
        return result
    else
        return false
    end
end)

lib.callback.register('rj-warrants:callback:payments', function(source)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Config.PayType == 'bank' then
        if Player.PlayerData.money['bank'] >= Config.Cost then
            Player.Functions.RemoveMoney('bank', Config.Cost, 'Look Up Warrants')
            return true
        else
            return false
        end
    elseif Config.PayType == 'cash' then
        local search = exports.ox_inventory:GetItem(src, 'money', nil, true)
        if search >= Config.Cost then
            exports.ox_inventory:RemoveItem(src, 'money', Config.Cost)
            return true
        else
            return false
        end
    else
        print('^1Unknown Payment method')
        return false
    end
end)

lib.addCommand('setwarrant', {
    help = 'Sets Warrant for a certain suspect (POLICE ONLY)',
    params = {
        {
            name = 'citizenid',
            type = 'string',
            help = 'Target player\'s citizen id', },
        {
            name = 'days',
            type = 'number',
            help = 'Number of Days the warrant will last for',
        },
    },
}, function(source, args, raw)
    local Player = QBCore.Functions.GetPlayer(source)
    local name = ("%s %s"):format(Player.PlayerData.charinfo.firstname, Player.PlayerData.charinfo.lastname)
    if HasAllowedJob(source) then
        SetWarrant(args, name, source)
    else
        TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = 'You do not have permission to use this command' })
    end
end)

function SetWarrant(args, name, source)
    local otherPlayer = MySQL.scalar.await('SELECT * FROM `players` WHERE citizenid = ?', {args.citizenid})
    local checking = MySQL.query.await('SELECT * FROM `rj_warrants` WHERE citizenid = ?', {args.citizenid})
    if otherPlayer ~= nil then
        if args.days ~= nil or args.days > 1 then
            local today = os.date('%Y-%m-%d')
            local seconds = 60 * 60 * 24
            local d1 = parseDate(today)
            local finaldate = d1 + args.days*seconds
            local endDate = checking[1] and parseDate(checking[1].date)
            local date = endDate and endDate > finaldate and endDate or os.date("%Y-%m-%d", finaldate)
            local id
            if checking[1] then
                id = MySQL.update.await('UPDATE `rj_warrants` SET date = ?, officer = ? WHERE citizenid = ?', {date, name, args.citizenid})
            else
                id = MySQL.insert.await('INSERT INTO `rj_warrants` (citizenid, date, officer) VALUES (?, ?, ?)', {args.citizenid, date, name})
            end
            if id then
                if source then TriggerClientEvent('ox_lib:notify', source, { type = 'success', description = 'Successfully added warrant' }) end
            else
                if source then TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = 'Something went wrong' }) end
            end
        else
            if source then TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = 'Invalid number of days' }) end
        end
    else
        if source then TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = 'Citizen ID doesnt exist or warrant already exists!' }) end
    end
end
exports('SetWarrant', SetWarrant)

lib.addCommand('removewarrant', {
    help = 'Removes Player Warrant(POLICE ONLY)',
    params = {
        {
            name = 'citizenid',
            type = 'string',
            help = 'Target player\'s citizen id',
        },
    },
}, function(source, args, raw)
    local Player = QBCore.Functions.GetPlayer(source)
    if HasAllowedJob(source) then
        local otherPlayer = MySQL.scalar.await('SELECT * FROM `rj_warrants` WHERE citizenid = ?', {args.citizenid})
        if otherPlayer ~= nil then
            local result = MySQL.query.await('DELETE FROM `rj_warrants` WHERE citizenid = ?', {args.citizenid})
            if result then
                TriggerClientEvent('ox_lib:notify', source, { type = 'success', description = 'Successfully removed warrant' })
            else
                TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = 'Something went wrong' })
            end
        else
            TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = 'Citizen ID not found in the warrants list' })
        end
    else
        TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = 'You do not have permission to use this command' })
    end
end)

lib.addCommand('getwarrants', {help = 'Get active Non-MDT warrants (Police Only)'}, function (source, args, raw)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player.PlayerData.job.name ~= Config.JobName then return end
    lib.callback('rj-warrants:callback:openmenu', source)
end)

lib.addCommand('playerwarrants', {help = 'See someone\'s Warrants (Police Only)'}, function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    local job = Player.PlayerData.job.name
    if job ~= Config.JobName then return end
    TriggerClientEvent('rj-warrants:client:PlayerWarrants', source)
end)

RegisterNetEvent('rj-warrants:server:removewarrant', function(data)
    local src = source
    if not data.cid then return end
    local result = MySQL.query.await('DELETE FROM `rj_warrants` WHERE citizenid = ?', {data.cid})
    if result then
        TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Successfully removed warrant' })
    else
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Something went wrong' })
    end
    lib.callback.await('rj-warrants:callback:openmenu', src)
end)

RegisterCommand('sqlstuff', function()
    local result = MySQL.query.await('SELECT * FROM `rj_warrants`')
    print(json.encode(result, {indent = true}))
end)

RegisterNetEvent('rj-warrants:server:PlayerWarrants', function(ciz, isCID)
    local src = source
    local cid = ciz
    if not isCID then
        local target = QBCore.Functions.GetPlayer(tonumber(ciz))
        if target then
            cid = target.PlayerData.citizenid
        end
    end
    lib.callback.await('rj-warrants:callback:openmenu', src, cid)
end)