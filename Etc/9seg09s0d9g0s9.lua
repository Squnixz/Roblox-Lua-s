local md5 = {}
local hmac = {}
local base64 = {}
local CodeGenerator = {}
do
    local K = {
        0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee, 0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
        0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be, 0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
        0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa, 0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
        0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed, 0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
        0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c, 0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
        0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05, 0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
        0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039, 0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
        0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1, 0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391,
    }

    local function add(a, b)
        local lsw = bit32.band(a, 0xFFFF) + bit32.band(b, 0xFFFF)
        local msw = bit32.rshift(a, 16) + bit32.rshift(b, 16) + bit32.rshift(lsw, 16)
        return bit32.bor(bit32.lshift(msw, 16), bit32.band(lsw, 0xFFFF))
    end

    local function rol(x, n)
        return bit32.bor(bit32.lshift(x, n), bit32.rshift(x, 32 - n))
    end

    local function F(x, y, z) return bit32.bor(bit32.band(x, y), bit32.band(bit32.bnot(x), z)) end
    local function G(x, y, z) return bit32.bor(bit32.band(x, z), bit32.band(y, bit32.bnot(z))) end
    local function H(x, y, z) return bit32.bxor(x, bit32.bxor(y, z)) end
    local function I(x, y, z) return bit32.bxor(y, bit32.bor(x, bit32.bnot(z))) end

    function md5.sum(message)
        local a, b, c, d = 0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476

        local msg_len = #message
        local padded = message .. "\128"
        while #padded % 64 ~= 56 do padded = padded .. "\0" end

        local len_bits = msg_len * 8
        local len_bytes = ""
        for i = 0, 7 do
            len_bytes = len_bytes .. string.char(bit32.band(bit32.rshift(len_bits, i * 8), 0xFF))
        end
        padded = padded .. len_bytes

        for i = 1, #padded, 64 do
            local chunk = padded:sub(i, i + 63)
            local X = {}
            for j = 0, 15 do
                local b1, b2, b3, b4 = chunk:byte(j * 4 + 1, j * 4 + 4)
                X[j] = bit32.bor(b1, bit32.lshift(b2, 8), bit32.lshift(b3, 16), bit32.lshift(b4, 24))
            end

            local aa, bb, cc, dd = a, b, c, d
            local S = {7, 12, 17, 22, 5, 9, 14, 20, 4, 11, 16, 23, 6, 10, 15, 21}

            for j = 0, 63 do
                local f, k, shift_idx
                if j < 16 then
                    f = F(b, c, d); k = j; shift_idx = j % 4
                elseif j < 32 then
                    f = G(b, c, d); k = (5 * j + 1) % 16; shift_idx = 4 + (j % 4)
                elseif j < 48 then
                    f = H(b, c, d); k = (3 * j + 5) % 16; shift_idx = 8 + (j % 4)
                else
                    f = I(b, c, d); k = (7 * j) % 16; shift_idx = 12 + (j % 4)
                end

                local temp = add(a, f)
                temp = add(temp, X[k])
                temp = add(temp, K[j + 1])
                temp = rol(temp, S[shift_idx + 1])

                local new_b = add(b, temp)
                a, b, c, d = d, new_b, b, c
            end

            a = add(a, aa); b = add(b, bb); c = add(c, cc); d = add(d, dd)
        end

        local function to_le_bytes(n)
            local s = ""
            for i = 0, 3 do s = s .. string.char(bit32.band(bit32.rshift(n, i * 8), 0xFF)) end
            return s
        end

        return to_le_bytes(a) .. to_le_bytes(b) .. to_le_bytes(c) .. to_le_bytes(d)
    end
end

function hmac.new(key, msg, hash_func)
    if #key > 64 then key = hash_func(key) end

    local o_pad, i_pad = "", ""
    for i = 1, 64 do
        local byte = (i <= #key and string.byte(key, i)) or 0
        o_pad = o_pad .. string.char(bit32.bxor(byte, 0x5C))
        i_pad = i_pad .. string.char(bit32.bxor(byte, 0x36))
    end

    return hash_func(o_pad .. hash_func(i_pad .. msg))
end

do
    local B64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

    function base64.encode(data)
        return (data:gsub(".", function(x)
            local r, val = "", x:byte()
            for i = 8, 1, -1 do r = r .. ((val % 2^i - val % 2^(i-1) > 0) and "1" or "0") end
            return r
        end) .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(x)
            if #x < 6 then return "" end
            local c = 0
            for i = 1, 6 do c = c + (x:sub(i,i) == "1" and 2^(6-i) or 0) end
            return B64_CHARS:sub(c + 1, c + 1)
        end) .. ({ "", "==", "=" })[#data % 3 + 1]
    end
end

function CodeGenerator:GenerateReservedServerCode(placeId)
    local uuid = {}
    for i = 1, 16 do uuid[i] = math.random(0, 255) end
    uuid[7] = bit32.bor(bit32.band(uuid[7], 0x0F), 0x40)
    uuid[9] = bit32.bor(bit32.band(uuid[9], 0x3F), 0x80)

    local first_bytes = ""
    for i = 1, 16 do
        first_bytes = first_bytes .. string.char(uuid[i])
    end

    local game_code = string.format("%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
        uuid[1], uuid[2], uuid[3], uuid[4], uuid[5], uuid[6], uuid[7], uuid[8],
        uuid[9], uuid[10], uuid[11], uuid[12], uuid[13], uuid[14], uuid[15], uuid[16])
    local place_bytes = ""
    local pid = placeId
    for _ = 1, 8 do
        place_bytes = string.char(pid % 256) .. place_bytes
        pid = math.floor(pid / 256)
    end

    local content = first_bytes .. place_bytes
    local secret = "e4Yn8ckbCJtw2sv7qmbg"
    local sig = hmac.new(secret, content, md5.sum)

    local access_bytes = sig .. content
    local access_code = base64.encode(access_bytes)
    access_code = access_code:gsub("+", "-"):gsub("/", "_")
    local padding = 0
    access_code = access_code:gsub("=", function() padding = padding + 1; return "" end)
    access_code = access_code .. tostring(padding)

    return access_code, game_code
end

print(CodeGenerator)
return CodeGenerator
