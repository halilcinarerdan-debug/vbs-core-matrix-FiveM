-- =====================================================================
-- MATRIX ORTAK KRIPTO MODULU / shared/crypto.lua
--
-- Saf Lua 5.4 SHA-256 uygulamasi. Lua 5.4'un yerel bitwise operatorleri
-- (&, |, ~, <<, >>) kullanilir -- bit32/bit kutuphanesi GEREKMEZ (bu
-- kaynak fxmanifest.lua icinde `lua54 'yes'` ile calisir).
--
-- Standart FIPS 180-4 SHA-256: 64 tur, 512-bit (16x32-bit kelime) blok
-- isleme, mesaj genisletme (message schedule) W[0..63], 8x32-bit hash
-- durumu (h0..h7), standart K sabitleri.
--
-- KATI ANAYASA: math.random YOK. Tamamen deterministik, saf fonksiyon.
--
-- Kullanim:
--   local hex = sha256.hex("abc")
--   -- hex == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
--
-- Bu dosya shared_scripts icinde ('shared/crypto.lua') YUKLENIR; global
-- `sha256` tablosu hem client hem server tarafinda (Config global
-- tablosuyla AYNI desende) erisilebilir olur.
-- =====================================================================

sha256 = sha256 or {}

local floor        = math.floor
local char         = string.char
local byte         = string.byte
local format       = string.format
local rep          = string.rep
local sub          = string.sub

-- Lua 5.4 native bitwise ops (operators, not functions) -- wrap them as
-- locals so the rest of the file reads like a portable bit-library API.
local function BAND(a, b)  return a & b end
local function BOR(a, b)   return a | b end
local function BXOR(a, b)  return a ~ b end
local function BNOT(a)     return (~a) & 0xFFFFFFFF end
local function LSHIFT(a,n) return (a << n) & 0xFFFFFFFF end
local function RSHIFT(a,n) return (a & 0xFFFFFFFF) >> n end

local function ROTR(x, n)
    x = x & 0xFFFFFFFF
    return ((x >> n) | (x << (32 - n))) & 0xFFFFFFFF
end

local function ADD32(...)
    local sum = 0
    for _, v in ipairs({...}) do
        sum = (sum + v) & 0xFFFFFFFF
    end
    return sum
end

-- ---------------------------------------------------------------------
-- FIPS 180-4 K sabitleri (ilk 64 asal sayinin kup koklerinin kesirli
-- kismindan turetilen 32-bit sabitler).
-- ---------------------------------------------------------------------
local K = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
}

-- Baslangic hash degerleri (ilk 8 asal sayinin karekokunun kesirli
-- kismindan turetilen 32-bit sabitler).
local H0 = { 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19 }

--- Mesaji SHA-256 padding kurallarina gore doldurur:
--- 0x80 byte'i + 0-dolgu + 64-bit (big-endian) orijinal uzunluk (bit
--- cinsinden), toplam uzunluk 64'un kati olacak sekilde.
local function Pad(msg)
    local msgLen      = #msg
    local bitLen      = msgLen * 8
    local out         = { msg, char(0x80) }
    local paddedLen    = msgLen + 1
    local zeroCount    = (56 - (paddedLen % 64)) % 64
    out[#out + 1] = rep(char(0), zeroCount)

    -- 64-bit big-endian uzunluk. Lua 5.4 tamsayilari 64-bit'tir; pratikte
    -- mesaj boyutu 2^53'u asmayacagi icin ust 32-bit her zaman 0'dir,
    -- ama tam FIPS uyumu icin yine de tum 8 byte yaziliyor.
    local lenBytes = {}
    for i = 7, 0, -1 do
        lenBytes[#lenBytes + 1] = char((bitLen >> (i * 8)) & 0xFF)
    end
    out[#out + 1] = table.concat(lenBytes)

    return table.concat(out)
end

--- 512-bit (64 byte) bir bloğu işleyip 8x32-bit hash durumunu günceller.
local function ProcessBlock(block, H)
    local W = {}
    for t = 0, 15 do
        local o = t * 4
        local b1, b2, b3, b4 = byte(block, o + 1, o + 4)
        W[t] = ((b1 << 24) | (b2 << 16) | (b3 << 8) | b4) & 0xFFFFFFFF
    end

    for t = 16, 63 do
        local s0 = BXOR(BXOR(ROTR(W[t - 15], 7), ROTR(W[t - 15], 18)), RSHIFT(W[t - 15], 3))
        local s1 = BXOR(BXOR(ROTR(W[t - 2], 17), ROTR(W[t - 2], 19)), RSHIFT(W[t - 2], 10))
        W[t] = ADD32(W[t - 16], s0, W[t - 7], s1)
    end

    local a, b, c, d, e, f, g, h = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]

    for t = 0, 63 do
        local S1    = BXOR(BXOR(ROTR(e, 6), ROTR(e, 11)), ROTR(e, 25))
        local ch    = BXOR(BAND(e, f), BAND(BNOT(e), g))
        local temp1 = ADD32(h, S1, ch, K[t + 1], W[t])
        local S0    = BXOR(BXOR(ROTR(a, 2), ROTR(a, 13)), ROTR(a, 22))
        local maj   = BXOR(BXOR(BAND(a, b), BAND(a, c)), BAND(b, c))
        local temp2 = ADD32(S0, maj)

        h = g
        g = f
        f = e
        e = ADD32(d, temp1)
        d = c
        c = b
        b = a
        a = ADD32(temp1, temp2)
    end

    H[1] = ADD32(H[1], a)
    H[2] = ADD32(H[2], b)
    H[3] = ADD32(H[3], c)
    H[4] = ADD32(H[4], d)
    H[5] = ADD32(H[5], e)
    H[6] = ADD32(H[6], f)
    H[7] = ADD32(H[7], g)
    H[8] = ADD32(H[8], h)
end

--- SHA-256 hesaplar, 32 byte'lik ham digest (binary string) doner.
function sha256.digest(input)
    input = tostring(input or '')
    local padded = Pad(input)
    local H = { H0[1], H0[2], H0[3], H0[4], H0[5], H0[6], H0[7], H0[8] }

    for i = 1, #padded, 64 do
        ProcessBlock(sub(padded, i, i + 63), H)
    end

    local out = {}
    for i = 1, 8 do
        out[i] = format('%08x', H[i])
    end
    return table.concat(out)
end

--- SHA-256 hesaplar, 64 karakterlik kucuk-harf hex string doner.
--- sha256.hex("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
function sha256.hex(input)
    return sha256.digest(input)
end

return sha256
