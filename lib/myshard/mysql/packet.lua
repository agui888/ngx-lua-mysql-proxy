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


-- constants
local STATE_CONNECTED = 1
local STATE_COMMAND_SENT = 2

local COM_QUERY = 0x03
local CLIENT_SSL = 0x0800

local SERVER_MORE_RESULTS_EXISTS = 8

-- 16MB - 1, the default max allowed packet size used by libmysqlclient
local FULL_PACKET_SIZE = 16777215


local mt = { __index = _M }


-- mysql field value type converters
local converters = new_tab(0, 8)

for i = 0x01, 0x05 do
    -- tiny, short, long, float, double
    converters[i] = tonumber
end
-- converters[0x08] = tonumber  -- long long
converters[0x09] = tonumber  -- int24
converters[0x0d] = tonumber  -- year
converters[0xf6] = tonumber  -- newdecimal


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


local function _dump(data)
    local len = #data
    local bytes = new_tab(len, 0)
    for i = 1, len do
        bytes[i] = format("%x", strbyte(data, i))
    end
    return concat(bytes, " ")
end


local function _dumphex(data)
    local len = #data
    local bytes = new_tab(len, 0)
    for i = 1, len do
        bytes[i] = tohex(strbyte(data, i), 2)
    end
    return concat(bytes, " ")
end


function _M.compute_token(password, scramble)
    if password == "" then
        return ""
    end

    local stage1 = sha1(password)
    local stage2 = sha1(stage1)
    local stage3 = sha1(scramble .. stage2)
    local n = #stage1
    local bytes = new_tab(n, 0)
    for i = 1, n do
         bytes[i] = strchar(bxor(strbyte(stage3, i), strbyte(stage1, i)))
    end

    return concat(bytes)
end


function _M.send_packet(conn, req, size)
    local sock = conn.sock

    conn.packet_no = conn.packet_no + 1

     print("packet no: ", conn.packet_no, " size=", size)

    local packet = _M.set_byte3(size) .. strchar(conn.packet_no) .. req

    print("sending packet: ", _dump(packet))

    return sock:send(packet)
end


function _M.recv_packet(conn)
    local sock = conn.sock
    local data, err = sock:receive(4) -- packet header
    if not data then
        return nil, nil, "failed to receive packet header: " .. err
    end

    --print("packet header: ", _dumphex(data))

    local len, pos = _M.get_byte3(data, 1)

    print("packet length: ", len)

    if len == 0 then
        return nil, nil, "empty packet"
    end

    if len > conn.max_packet_size then
        return nil, nil, "packet size too big: " .. len
    end

    local num = strbyte(data, pos)

    print("recv packet: packet no: ", num)

    conn.packet_no = num

    data, err = sock:receive(len)

    -- print("receive returned")

    if not data then
        return nil, nil, "failed to read packet content: " .. err
    end

    -- print("packet content: ", _dump(data))
    -- print("packet content (ascii): ", data)

    local field_count = strbyte(data, 1)

    local typ
    if field_count == 0x00 then
        typ = "OK"
    elseif field_count == 0xff then
        typ = "ERR"
    elseif field_count == 0xfe then
        typ = "EOF"
    elseif field_count <= 250 then
        typ = "DATA"
    end
    print("recv packet typ: ", typ, " cmd: ", field_count)
    return data, typ
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
        return get_byte2(data, pos)
    end

    if first == 253 then
        pos = pos + 1
        return get_byte3(data, pos)
    end

    if first == 254 then
        pos = pos + 1
        return get_byte8(data, pos)
    end

    return false, pos + 1
end


function _M.from_length_coded_str(data, pos)
    local len
    len, pos = from_length_coded_bin(data, pos)
    if len == nil or len == null then
        return null, pos
    end

    return sub(data, pos, pos + len - 1), pos + len
end


function _M.parse_ok_packet(packet)
    local res = new_tab(0, 5)
    local pos

    res.affected_rows, pos = from_length_coded_bin(packet, 2)

    --print("affected rows: ", res.affected_rows, ", pos:", pos)

    res.insert_id, pos = from_length_coded_bin(packet, pos)

    --print("insert id: ", res.insert_id, ", pos:", pos)

    res.server_status, pos = get_byte2(packet, pos)

    --print("server status: ", res.server_status, ", pos:", pos)

    res.warning_count, pos = get_byte2(packet, pos)

    --print("warning count: ", res.warning_count, ", pos: ", pos)

    local message = sub(packet, pos)
    if message and message ~= "" then
        res.message = message
    end

    --print("message: ", res.message, ", pos:", pos)

    return res
end


function _M.parse_eof_packet(packet)
    local pos = 2

    local warning_count, pos = get_byte2(packet, pos)
    local status_flags = get_byte2(packet, pos)

    return warning_count, status_flags
end


function _M.parse_err_packet(packet)
    local errno, pos = get_byte2(packet, 2)
    local marker = sub(packet, pos, pos)
    local sqlstate
    if marker == '#' then
        -- with sqlstate
        pos = pos + 1
        sqlstate = sub(packet, pos, pos + 5 - 1)
        pos = pos + 5
    end

    local message = sub(packet, pos)
    return errno, message, sqlstate
end


function _M.parse_resultset_header_packet(packet)
    local field_count, pos = from_length_coded_bin(packet, 1)

    local extra
    extra = from_length_coded_bin(packet, pos)

    return field_count, extra
end


function _M.parse_field_packet(data)
    local col = new_tab(0, 2)
    local catalog, db, table, orig_table, orig_name, charsetnr, length
    local pos
    catalog, pos = from_length_coded_str(data, 1)

    --print("catalog: ", col.catalog, ", pos:", pos)

    db, pos = from_length_coded_str(data, pos)
    table, pos = from_length_coded_str(data, pos)
    orig_table, pos = from_length_coded_str(data, pos)
    col.name, pos = from_length_coded_str(data, pos)

    orig_name, pos = from_length_coded_str(data, pos)

    pos = pos + 1 -- ignore the filler

    charsetnr, pos = get_byte2(data, pos)

    length, pos = get_byte4(data, pos)

    col.type = strbyte(data, pos)

    --[[
    pos = pos + 1

    col.flags, pos = get_byte2(data, pos)

    col.decimals = strbyte(data, pos)
    pos = pos + 1

    local default = sub(data, pos + 2)
    if default and default ~= "" then
        col.default = default
    end
    --]]

    return col
end


function _M.parse_row_data_packet(data, cols, compact)
    local pos = 1
    local ncols = #cols
    local row
    if compact then
        row = new_tab(ncols, 0)
    else
        row = new_tab(0, ncols)
    end
    for i = 1, ncols do
        local value
        value, pos = from_length_coded_str(data, pos)
        local col = cols[i]
        local typ = col.type
        local name = col.name

        --print("row field value: ", value, ", type: ", typ)

        if value ~= null then
            local conv = converters[typ]
            if conv then
                value = conv(value)
            end
        end

        if compact then
            row[i] = value

        else
            row[name] = value
        end
    end

    return row
end


function _M.recv_field_packet(self)
    local packet, typ, err = recv_packet(self)
    if not packet then
        return nil, err
    end

    if typ == "ERR" then
        local errno, msg, sqlstate = parse_err_packet(packet)
        return nil, msg, errno, sqlstate
    end

    if typ ~= 'DATA' then
        return nil, "bad field packet type: " .. typ
    end

    -- typ == 'DATA'

    return parse_field_packet(packet)
end
return _M