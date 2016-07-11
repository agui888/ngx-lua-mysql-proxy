-- the code copy from: https://github.com/openresty/lua-resty-mysql
-- Copyright (C) 2012 Yichun Zhang (agentzh)
-- modfiy by: HuangChuanTong@WPS.CN
-- MySQL TCP 通信协议处理
--
-- 关于 MySQL服务端 返回的报文解释：
-- parse_* 函数（6个），对应该MySQL服务端回应客户端的6种报文结构
-- 只有6种报文，详情查看：http://hutaow.com/blog/2013/11/06/mysql-protocol-analysis/#43-
----------------------------------

local bit       = require "bit"
local bytesio   = require "myshard.mysql.bytesio"

local strsub    = string.sub
local strbyte   = string.byte
local strchar   = string.char
local format    = string.format

local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function (narr, nrec) return {} end
end


local _M = { _VERSION = '0.15' }
local mt = { __index = _M }


local FULL_PACKET_SIZE  = 16777215
_M.PKG_TYPE_OK          = 0x00
_M.PKG_TYPE_EOF         = 0xfe
_M.PKG_TYPE_ERR         = 0xff
_M.PKG_TYPE_DATA        = -1  --- 自定义，MySQL协议并没此消息类型，表示非以上3种

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


-------- 6种报文解释函数 ---------
function _M.parse_ok_packet(packet)
    local res = new_tab(0, 5)
    local pos

    res.affected_rows, pos = bytesio.from_length_coded_bin(packet, 2)

    --print("affected rows: ", res.affected_rows, ", pos:", pos)

    res.insert_id, pos = bytesio.from_length_coded_bin(packet, pos)

    --print("insert id: ", res.insert_id, ", pos:", pos)

    res.server_status, pos = bytesio.get_byte2(packet, pos)

    --print("server status: ", res.server_status, ", pos:", pos)

    res.warning_count, pos = bytesio.get_byte2(packet, pos)

    --print("warning count: ", res.warning_count, ", pos: ", pos)

    local message = strsub(packet, pos)
    if message and message ~= "" then
        res.message = message
    end

    --print("message: ", res.message, ", pos:", pos)

    return res
end


function _M.parse_eof_packet(packet)
    local pos = 2

    local warning_count, pos = bytesio.get_byte2(packet, pos)
    local status_flags = bytesio.get_byte2(packet, pos)

    return warning_count, status_flags
end


function _M.parse_err_packet(packet)
    local errno, pos = bytesio.get_byte2(packet, 2)
    local marker = strsub(packet, pos, pos)
    local sqlstate
    if marker == '#' then
        -- with sqlstate
        pos = pos + 1
        sqlstate = strsub(packet, pos, pos + 5 - 1)
        pos = pos + 5
    end

    local message = strsub(packet, pos)
    return errno, message, sqlstate
end


function _M.parse_result_set_header_packet(packet)
    local field_count, pos = bytesio.from_length_coded_bin(packet, 1)

    local extra
    extra = bytesio.from_length_coded_bin(packet, pos)

    return field_count, extra
end


function _M.parse_field_packet(data)
    local col = new_tab(0, 2)
    local catalog, db, table, orig_table, orig_name, charsetnr, length
    local pos
    catalog, pos = bytesio.from_length_coded_str(data, 1)

    --print("catalog: ", col.catalog, ", pos:", pos)

    db, pos = bytesio.from_length_coded_str(data, pos)
    table, pos = bytesio.from_length_coded_str(data, pos)
    orig_table, pos = bytesio.from_length_coded_str(data, pos)
    col.name, pos = bytesio.from_length_coded_str(data, pos)

    orig_name, pos = bytesio.from_length_coded_str(data, pos)

    pos = pos + 1 -- ignore the filler

    charsetnr, pos = bytesio.get_byte2(data, pos)

    length, pos = bytesio.get_byte4(data, pos)

    col.type = strbyte(data, pos)

    --[[
    pos = pos + 1

    col.flags, pos = get_byte2(data, pos)

    col.decimals = strbyte(data, pos)
    pos = pos + 1

    local default = strsub(data, pos + 2)
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
        value, pos = bytesio.from_length_coded_str(data, pos)
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

return _M
