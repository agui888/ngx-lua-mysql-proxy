-- the code copy from: https://github.com/openresty/lua-resty-mysql
-- Copyright (C) 2012 Yichun Zhang (agentzh)
-- modfiy by: HuangChuanTong@WPS.CN
-- mysql TCP 通信协议处理
-- 
local bit = require "bit"

local strsub = string.sub
local strbyte = string.byte
local strchar = string.char
local strfind = string.find
local strlen =  string.len
local format = string.format
local concat = table.concat
local bor = bit.bor
local band = bit.band
local lshift = bit.lshift
local rshift = bit.rshift

local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function (narr, nrec) return {} end
end

local _M = { _VERSION = '0.15' }
local mt = { __index = _M }


function _M.get_byte2(data, i)
    local a, b = strbyte(data, i, i + 1)
    return bor(a, lshift(b, 8)), i + 2
end


function _M.get_byte3(data, i)
    local a, b, c = strbyte(data, i, i + 2)
    return bor(a, lshift(b, 8), lshift(c, 16)), i + 3
end


function _M.get_byte4(data, i)
    local a, b, c, d = strbyte(data, i, i + 3)
    return bor(a, lshift(b, 8), lshift(c, 16), lshift(d, 24)), i + 4
end


function _M.get_byte8(data, i)
    local a, b, c, d, e, f, g, h = strbyte(data, i, i + 7)

    -- XXX workaround for the lack of 64-bit support in bitop:
    local lo = bor(a, lshift(b, 8), lshift(c, 16), lshift(d, 24))
    local hi = bor(e, lshift(f, 8), lshift(g, 16), lshift(h, 24))
    return lo + hi * 4294967296, i + 8

    -- return bor(a, lshift(b, 8), lshift(c, 16), lshift(d, 24), lshift(e, 32),
               -- lshift(f, 40), lshift(g, 48), lshift(h, 56)), i + 8
end


function _M.set_byte2(n)
    return strchar(band(n, 0xff), band(rshift(n, 8), 0xff))
end


function _M.set_byte3(n)
    return strchar(band(n, 0xff),
                   band(rshift(n, 8), 0xff),
                   band(rshift(n, 16), 0xff))
end


function _M.set_byte4(n)
    -- print("band", band)
    return strchar(band(n, 0xff),
                   band(rshift(n, 8), 0xff),
                   band(rshift(n, 16), 0xff),
                   band(rshift(n, 24), 0xff))
end


function _M.from_cstring(data, i)
    local last = strfind(data, "\0", i, true)
    if not last then
        return nil, nil
    end

    return strsub(data, i, last), last + 1
end


function _M.to_cstring(data)
    return data .. "\0"
end


function _M.to_binary_coded_string(data)
    return strchar(#data) .. data
end


function _M.to_length_encode_int(num)
        if num <= 250 then
                return strchar(num)
        elseif num <= 0xffff then
                return strchar(0xfc, num, band(rshift(num, 8), 0xff))
        elseif num <= 0xffffff then
                return strchar(0xfd, num, band(rshift(num, 8), 0xff), band(rshift(num, 16), 0xff))
        elseif num <= 0xffffffffffffffff then
                return strchar(0xfd, num, band(rshift(num, 8), 0xff), band(rshift(num, 16), 0xff),
                                         band(rshift(num, 24), 0xff), band(rshift(num, 32), 0xff), 
                                         band(rshift(num, 48), 0xff), band(rshift(num, 56), 0xff))
        end
end


function _M.from_length_coded_bin(data, pos)
    local first = strbyte(data, pos)

    --print("LCB: first: ", first)

    if not first then
        return nil, pos
    end

    if first >= 0 and first <= 250 then
        return first, pos + 1
    end

    if first == 251 then
        return null, pos + 1
    end

    if first == 252 then
        pos = pos + 1
        return _M.get_byte2(data, pos)
    end

    if first == 253 then
        pos = pos + 1
        return _M.get_byte3(data, pos)
    end

    if first == 254 then
        pos = pos + 1
        return _M.get_byte8(data, pos)
    end

    return false, pos + 1
end


function _M.from_length_coded_str(data, pos)
    local len
    len, pos = _M.from_length_coded_bin(data, pos)
    if len == nil or len == null then
        return null, pos
    end

    return strsub(data, pos, pos + len - 1), pos + len
end


function _M.dump(data)
    local len = #data
    local bytes = new_tab(len, 0)
    for i = 1, len do
        bytes[i] = format("%x", strbyte(data, i))
    end
    return concat(bytes, " ")
end


function _M.dumphex(data)
    local len = #data
    local bytes = new_tab(len, 0)
    for i = 1, len do
        bytes[i] = tohex(strbyte(data, i), 2)
    end
    return concat(bytes, " ")
end


return _M
