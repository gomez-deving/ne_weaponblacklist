-- Check Role Permissions
function CheckPermissionForMenu(source)
    local userRoles = {}

    if Config.DiscordAPI == "badger" then
        userRoles = exports.Badger_Discord_API:GetDiscordRoles(source)
        --print("^3[DEBUG] Retrieved Badger roles for " .. GetPlayerName(source) .. ": " .. json.encode(userRoles) .. "^0")
    elseif Config.DiscordAPI == "ne_discord" then
        userRoles = exports.ne_discord:GetDiscordRoles(source)
        --print("^3[DEBUG] Retrieved NE_Discord roles for " .. GetPlayerName(source) .. ": " .. json.encode(userRoles) .. "^0")
    else
        --print("^1[WeaponBlacklist] Invalid Discord API in config!^0")
        return false
    end

    for _, role in pairs(userRoles or {}) do
        for _, allowedRole in pairs(Config.AllowedRoles) do
            if role == allowedRole then
                --print("^2[DEBUG] Player " .. GetPlayerName(source) .. " has an allowed role: " .. role .. "^0")
                return true
            end
        end
    end
    --print("^3[DEBUG] Player " .. GetPlayerName(source) .. " does not have any allowed roles^0")
    return false
end

-- Trigger Client to Remove Blacklisted Weapons
function RemoveBlacklistedWeapons(source)
    --print("^3[DEBUG] Triggering client to remove blacklisted weapons for " .. GetPlayerName(source) .. "^0")
    TriggerClientEvent('ne_weaponblacklist:checkWeapons', source, Config.WeaponBlacklist)
end

-- Send Discord Webhook
local function SendDiscordWebhook(playerSource, weapon)
    if not Config.WebhookURL or Config.WebhookURL == "" then
        --print("^1[WeaponBlacklist] Webhook URL not set^0")
        return
    end

    local playerName = GetPlayerName(playerSource)
    local identifiers = GetPlayerIdentifiers(playerSource)
    local steamID, discordID = "N/A", "N/A"

    for _, id in ipairs(identifiers) do
        if string.find(id, "steam:") then steamID = id end
        if string.find(id, "discord:") then discordID = id:gsub("discord:", "") end -- remove prefix
    end

    -- Format the Discord mention
    local discordMention = discordID ~= "N/A" and "<@" .. discordID .. ">" or "N/A"

    local embed = {
        {
            title = "Blocked Weapon Event",
            color = 16711680,
            fields = {
                {name = "Player Name", value = playerName, inline = true},
                {name = "Steam ID", value = steamID, inline = true},
                {name = "Discord", value = discordMention, inline = true},
                {name = "Weapon", value = weapon, inline = true}
            },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }
    }

    local payload = {
        username = "Weapon Blacklist Logger",
        embeds = embed
    }

    --print("^3[DEBUG] Sending Discord webhook payload: " .. json.encode(payload) .. "^0")

    PerformHttpRequest(Config.WebhookURL, function(err, text, headers)
        --print("^3[DEBUG] Discord webhook response code: " .. tostring(err) .. "^0")
        --print("^3[DEBUG] Discord webhook response text: " .. tostring(text) .. "^0")
        --print("^3[DEBUG] Discord webhook response headers: " .. json.encode(headers) .. "^0")

        if err >= 200 and err < 300 then
            --print("^2[WeaponBlacklist] Discord webhook sent successfully for " .. playerName .. "^0")
        else
            --print("^1[WeaponBlacklist] Failed to send Discord webhook for " .. playerName .. ", HTTP code: " .. tostring(err) .. "^0")
        end
    end, "POST", json.encode(payload), {["Content-Type"] = "application/json"})
end


-- Weapon Give Event
AddEventHandler('giveWeaponEvent', function(source, data)
    local weapon = data.weaponName
    --print("^3[DEBUG] Player " .. GetPlayerName(source) .. " tried to receive weapon: " .. weapon .. "^0")
    if not CheckPermissionForMenu(source) then
        for _, blacklistedWeapon in ipairs(Config.WeaponBlacklist) do
            if weapon == blacklistedWeapon then
                CancelEvent()
                TriggerClientEvent('chat:addMessage', source, {
                    color = {255, 0, 0},
                    multiline = true,
                    args = {"System", "You are not allowed to use this weapon!"}
                })
                --print("^1[WeaponBlacklist] Blocked weapon give for " .. GetPlayerName(source) .. " | Weapon: " .. weapon .. "^0")
                SendDiscordWebhook(source, weapon)
                return
            end
        end
    end
end)

-- Periodic Check for Blacklisted Weapons
CreateThread(function()
    while true do
        Wait(5000)
        for _, playerId in ipairs(GetPlayers()) do
            if not CheckPermissionForMenu(playerId) then
                RemoveBlacklistedWeapons(playerId)
            end
        end
    end
end)

-- On Player Spawn
AddEventHandler('playerSpawned', function()
    local source = source
    if not CheckPermissionForMenu(source) then
        RemoveBlacklistedWeapons(source)
    end
end)

-- Server receives client removal notifications
RegisterNetEvent('ne_weaponblacklist:weaponRemoved')
AddEventHandler('ne_weaponblacklist:weaponRemoved', function(weapon)
    local source = source
    --print("^3[DEBUG] Server received weapon removal from " .. GetPlayerName(source) .. ": " .. weapon .. "^0")
    SendDiscordWebhook(source, weapon)
end)

-- Block Explosions (Optional)
local BlockedExplosions = {1, 2, 4, 5, 25, 32, 33, 35, 36, 37, 38}
AddEventHandler('explosionEvent', function(sender, ev)
    --print("^3[DEBUG] ExplosionEvent from " .. GetPlayerName(sender) .. ": " .. json.encode(ev) .. "^0")
    if ev.ownerNetId == 0 then CancelEvent() end
    if ev.posX == 0.0 and ev.posY == 0.0 then CancelEvent() end
end)

-- Test Webhook Command
RegisterCommand("testWebhook", function(source, args, raw)
    local weapon = args[1] or "TEST_WEAPON"
    --print("^3[DEBUG] Manually sending webhook for " .. GetPlayerName(source) .. " with weapon " .. weapon .. "^0")
    SendDiscordWebhook(source, weapon)
end)
