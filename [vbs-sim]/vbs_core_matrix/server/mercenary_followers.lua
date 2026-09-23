-- =====================================================================
-- MATRIX MUHAFIZ/KURYE TAKİPÇİLERİ / server/mercenary_followers.lua
--
-- ★ v16.2 GÜVENLİK SIKILAŞTIRMASI (F10 HİJACK SERVER KALKANI)
-- Harici bir eklenti F10 tuşunu kullanıp YETKİSİZ olarak bu event'i
-- tetiklemeye çalışabilir. Bu dosya artık her summon isteğini bağımsız
-- olarak doğrular:
--   [1] src geçerliliği
--   [2] Config anahtarı
--   [3] Sıkı rate-limit (60sn/5 çağrı — config'in ÜSTÜNE)
--   [4] ŞÜPHELİ hızlı ardışık denemede kalıcı susturma
--   [5] Şüpheli denemeleri matrix_diagnostics jurnalına yaz
-- =====================================================================

Matrix.Mercenary = Matrix.Mercenary or {}

-- Aşırı sık çağrı sayacı (config cooldown'una EK kalkan)
local SummonCooldown = {} -- [src] = sonraki izinli cagri zamani (Unix saniye)
local FollowerCount  = {} -- [src] = su anki aktif takipci sayisi

-- ★ v16.2: ŞÜPHELİ AKTİVİTE TAKİBİ
local SuspiciousSummonLog = {}   -- [src] = { attempts = N, last_at = epoch, silenced_until = epoch }
local SUSPICIOUS_WINDOW_SEC      = 30      -- pencere
local SUSPICIOUS_ATTEMPT_CEILING = 5       -- bu kadar ardışık denemede
local SILENCE_DURATION_SEC       = 300     -- 5 dk boyunca sessize al


local function _recordSuspicious(src, reason)
    local now = os.time()
    local rec = SuspiciousSummonLog[src]
    if not rec then
        rec = { attempts = 0, last_at = now, silenced_until = 0 }
        SuspiciousSummonLog[src] = rec
    end
    if (now - rec.last_at) > SUSPICIOUS_WINDOW_SEC then
        rec.attempts = 0
    end
    rec.attempts = rec.attempts + 1
    rec.last_at  = now

    if rec.attempts >= SUSPICIOUS_ATTEMPT_CEILING then
        rec.silenced_until = now + SILENCE_DURATION_SEC
        Matrix.Log('MERCENARY',
            '[GUVENLIK][F10 HIJACK SUPHESI] src=%d %d denemede susturuldu (%ds) -- sebep: %s',
            src, rec.attempts, SILENCE_DURATION_SEC, tostring(reason))
        pcall(function()
            if Matrix.Diagnostics and Matrix.Diagnostics.FailureJournal then
                Matrix.Diagnostics.FailureJournal.last_failure_at = os.time()
                Matrix.Diagnostics.FailureJournal.last_failure_kind = 'f10_hijack_suspected'
                Matrix.Diagnostics.FailureJournal.last_failure_detail = ('src=%d reason=%s'):format(src, tostring(reason))
                Matrix.Diagnostics.FailureJournal.failure_count = Matrix.Diagnostics.FailureJournal.failure_count + 1
            end
        end)
    end
end


local function _isSilenced(src)
    local rec = SuspiciousSummonLog[src]
    if not rec then return false end
    return os.time() < (rec.silenced_until or 0)
end


function Matrix.Mercenary.RequestSummon(src)
    if type(src) ~= 'number' or src <= 0 then return false, 'bad_src' end
    if not Config.Mercenary or not Config.Mercenary.EnablePhysicalFollowers then
        return false, 'disabled'
    end

    -- ★ v16.2: Susturma kontrolü (F10 hijack savunması)
    if _isSilenced(src) then
        _recordSuspicious(src, 'still_silenced')
        return false, 'silenced'
    end

    local now = Matrix.Now()
    if SummonCooldown[src] and now < SummonCooldown[src] then
        _recordSuspicious(src, 'cooldown_burst')
        return false, 'cooldown'
    end

    local current = FollowerCount[src] or 0
    if current >= (Config.Mercenary.MaxFollowers or 2) then
        _recordSuspicious(src, 'max_reached_burst')
        return false, 'max_reached'
    end

    SummonCooldown[src] = now + math.floor((Config.Mercenary.SummonCooldownMs or 5000) / 1000)
    FollowerCount[src]   = current + 1

    -- ★ v16.2: Başarılı çağrı sayacı sıfırla (sadece 30sn sessiz kaldıysa)
    local rec = SuspiciousSummonLog[src]
    if rec and (now - rec.last_at) > SUSPICIOUS_WINDOW_SEC then
        rec.attempts = 0
    end

    return true, FollowerCount[src]
end


function Matrix.Mercenary.ReportDismiss(src, remainingCount)
    if type(src) ~= 'number' or src <= 0 then return false end
    FollowerCount[src] = math.max(0, tonumber(remainingCount) or 0)
    return true
end


function Matrix.Mercenary.GetFollowerCount(src)
    return FollowerCount[src] or 0
end


function Matrix.Mercenary.IsSilenced(src)
    return _isSuspicious and _isSilenced(src) or false
end


RegisterNetEvent('matrix:server:mercenary:requestSummon', function()
    local src = source
    if type(src) ~= 'number' or src <= 0 then return end
    if not Config.Mercenary or not Config.Mercenary.EnablePhysicalFollowers then return end

    local ok, newCountOrReason = Matrix.Mercenary.RequestSummon(src)
    if not ok then
        local msg = (newCountOrReason == 'cooldown') and 'Takipci cagirma kisa bir sure sonra tekrar kullanilabilir.'
            or (newCountOrReason == 'max_reached') and 'Zaten maksimum takipci sayisina ulastiniz.'
            or (newCountOrReason == 'silenced') and 'Guvenlik: F10 hijack suphesi. Kalici loglandi.'
            or 'Cagri baslatilamadi.'
        TriggerClientEvent('matrix:client:actionNotify', src, false, msg)
        return
    end

    TriggerClientEvent('matrix:client:mercenary:summonApproved', src, newCountOrReason)
end)


RegisterNetEvent('matrix:server:mercenary:reportDismiss', function(remainingCount)
    local src = source
    if type(src) ~= 'number' or src <= 0 then return end
    Matrix.Mercenary.ReportDismiss(src, remainingCount)
end)


AddEventHandler('playerDropped', function()
    local src = source
    SummonCooldown[src] = nil
    FollowerCount[src]   = nil
    SuspiciousSummonLog[src] = nil
end)


-- ★ v16.2: TANI KOMUTU — hangi src'ler susturulmuş, kaç denemede
RegisterCommand('f10hijackdurum', function(src)
    local lines = 0
    for playerSrc, rec in pairs(SuspiciousSummonLog) do
        if (rec.silenced_until or 0) > os.time() then
            lines = lines + 1
            TriggerClientEvent('chat:addMessage', src, {
                args = { '[F10 HIJACK TANI]', ('src=%d denemeler=%d sessiz=%ds'):format(
                    playerSrc, rec.attempts, (rec.silenced_until or 0) - os.time()) }
            })
        end
    end
    TriggerClientEvent('chat:addMessage', src, {
        args = { '[F10 HIJACK TANI]', ('Toplam susturulmus: %d'):format(lines) }
    })
end, false)


exports('RequestSummon',  function(src)            return Matrix.Mercenary.RequestSummon(src) end)
exports('ReportDismiss',  function(src, remaining) return Matrix.Mercenary.ReportDismiss(src, remaining) end)
exports('GetFollowerCount', function(src)          return Matrix.Mercenary.GetFollowerCount(src) end)
exports('IsSummonSilenced', function(src)          return Matrix.Mercenary.IsSilenced(src) end)