-- Event to Check and Remove Blacklisted Weapons
RegisterNetEvent('ne_weaponblacklist:checkWeapons')
AddEventHandler('ne_weaponblacklist:checkWeapons', function(blacklistedWeapons)
    local playerPed = PlayerPedId()
    for _, weapon in ipairs(blacklistedWeapons) do
        local weaponHash = GetHashKey(weapon)
        if HasPedGotWeapon(playerPed, weaponHash, false) then
            RemoveWeaponFromPed(playerPed, weaponHash)

            -- Notify server for webhook
            TriggerServerEvent('ne_weaponblacklist:weaponRemoved', weapon)

            -- Optional chat message
            TriggerEvent('chat:addMessage', {
                color = {255, 0, 0},
                multiline = true,
                args = {"System", "Blacklisted weapon removed: " .. weapon}
            })
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        local Player = PlayerPedId()
        SetExplosiveAmmoThisFrame(Player, false)
        SetExplosiveMeleeThisFrame(Player, false)
        SetFireAmmoThisFrame(Player, false)
        SetPlayerInvincible(Player, false)
        Citizen.Wait(0)
    end
end)
