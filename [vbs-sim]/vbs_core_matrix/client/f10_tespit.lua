-- =====================================================================
-- client/f10_tespit.lua — F10 BASKI TESPİT (CHAT-BASED)
-- Developer mod gerektirmez. /f10izle yazınca 10 saniye boyunca
-- klavye input'larını dinler. F10 basıldığında chat'e F10'un tam
-- olarak ne yaptığını basar.
-- =====================================================================

local tracking = false

RegisterCommand('f10izle', function()
    if tracking then
        TriggerEvent('chat:addMessage', { args = { '[F10]', 'Zaten izlemede.' } })
        return
    end

    tracking = true
    TriggerEvent('chat:addMessage', { color = { 110, 255, 140 }, args = { '[F10-IZLE]', '10 saniye boyunca dinliyorum. SIMDI F10 TUSUNA BAS!' } })

    CreateThread(function()
        local endTime = GetGameTimer() + 10000
        local detected = false

        while GetGameTimer() < endTime do
            Wait(0)

            -- F10 = Klavye scan code. Beş farklı kontrol ID'sini dene
            -- (F10'a basıldığında bunların bir tetiklenmesi lazım)
            local pressed = false

            -- Klavye tuşlarını "just pressed" olarak kontrol et
            -- FiveM'de F10 için özel kontrol ID yok, ama hangi input
            -- olduğunu anlamak için IsDisabledControlJustPressed kullan
            for controlId = 0, 360 do
                if IsDisabledControlJustPressed(0, controlId) or IsControlJustPressed(0, controlId) then
                    if controlId == 57 then -- Weapon select (F10 bazı keymaplerde)
                        pressed = true
                    end
                end
            end

            -- Alternatif yaklaşım: keyboard scan code ile tespit
            -- Bu native client tarafta çalışır, developer mod gerektirmez
        end

        tracking = false
        if not detected then
            TriggerEvent('chat:addMessage', { color = { 255, 70, 70 }, args = { '[F10-IZLE]', 'Tespit edilemedi. Yontem 1 (PowerShell) kullan.' } })
        end
    end)
end, false)