-- Copyright (C) 2016 HuangChuanTong@WPS.CN
-- 
-- MySQL proto for mysql-server side handshake

local strchar = string.char
local strsub = string.sub
local strlen =  string.len
local strbyte = string.byte

local bor = bit.bor
local band = bit.band
local lshift = bit.lshift
local rshift = bit.rshift

local packet = require "myshard.mysql.packet"
local const = require "myshard.mysql.const"
local charset = require "myshard.mysql.charset"

local _M = { _VERSION = '0.1' }
local mt = { __index = _M }

local PROTO_VERISON = 10
local SERVER_VERISON = "5.6.30-ngxLuaMyShard-0.1"

-- args: conn was myshard.proxy.conn
local function _make_handshake_pkg(conn)
    local pkg = strchar(PROTO_VERISON)
            .. packet.to_cstring(SERVER_VERISON)
            .. packet.set_byte4(conn.connection_id)
            .. packet.to_cstring(strsub(conn.salt, 1, 8))   -- auth-plugin-data-part-1
            .. packet.set_byte2(const.DEFAULT_CAPABILITY)
            .. strchar(charset.UTF8_COLLATION_ID)           -- just support charset=utf8
            .. packet.set_byte2(conn.state)                 -- autocommit=true/false
            .. strchar(band(rshift(const.DEFAULT_CAPABILITY, 16), 0xff))
            .. strchar(band(rshift(const.DEFAULT_CAPABILITY, 24), 0xff))
            .. strchar(0x15)                            -- filter string
            .. strchar(0, 0, 0, 0, 0, 0, 0, 0, 0, 0)    -- reserved 10 [00]
            .. packet.to_cstring(strsub(conn.salt, 9, -1))  -- auth-plugin-data-part-2

    local pkg_len = 1 + strlen() + 1 + 4 + 9 + 1 + 2 + 1 + 2 + 3 + 10
                + strlen(strsub(conn.salt, 9, -1)) 
    return pkg, pkg_len
end

-- args: conn was myshard.proxy.conn
function _M.send_handshake(conn)
    local pkg, len = _make_handshake_pkg(conn)
    
    ngx.log(ngx.NOTICE, " send handshake pkg_len=>", len)

    local bytes, err = packet.send_packet(conn, pkg, len)
    if not bytes then
        return "failed to send client handshake packet: " .. err
    end
    return nil
end

-- args: conn was myshard.proxy.conn
function _M.read_handshake_response(conn)
    local packet, typ, err= packet.recv_packet(conn)
    if not packet then
        return false, err
    end
    if typ == "ERR" then
        local errno, msg, sqlstate = packet.parse_err_packet(packet)
        return false, msg, errno, sqlstate
    end

    local raw_capability, pos = packet.get_byte4(packet, 1)
    conn.capability =  bor(raw_capability, lshift(raw_capability, 16))
    -- print("client-capability:", conn.capability)
    -- local cap = band(conn.capability, const.DEFAULT_CAPABILITY)
    -- if band(conn.capability, const.CLIENT_PROTOCOL_41) > 0 then
    --         print("clent using proto >4.1")
    -- else
    --         print("warning..... using proto<=4.0")
    -- end
    -- max packet size
    local size, pos = packet.get_byte4(packet, pos)
    print("client.max-packet-size:", size)

    -- charset, if you want to use another charset, use set names
    conn.collation_id = strbyte( strsub(packet, pos, pos + 1))
    print("charset_id=", conn.collation_id, " pos=", pos)
    pos = pos + 1

    -- skip reserved 23[00]
    pos = pos + 23

    -- user name
    local user, next_pos = packet.from_cstring(packet, pos)
    if user ~= nil then
        conn.user = user
        pos = next_pos
        ngx.log(ngx.INFO, "connect with user: ", user)
    else
        ngx.log(ngx.WARN, "user is empty to auth.")
    end

    local auth_len = strbyte(strsub(packet, pos, pos + 1))
    pos = pos + 1
    local auth = strsub(packet, pos, pos+auth_len)
    pos = pos + auth_len
    
    if auth_len > 0 then
        conn.auth = auth
        ngx.log(ngx.INFO, "auth-string-len: ", auth_len)
    else
        ngx.log(ngx.WARN, "auth-string empty.")
    end

    if bor(conn.capability, const.CLIENT_CONNECT_WITH_DB) > 0 then
        local db, pos = packet.from_cstring(packet, pos)
        if db == nil or strlen(db) == 0 then
            return true, nil
        end
        conn.use_db(db)
    end
    return true, nil
end

function _M.send_ok(conn)
    local pkg_len = 3
    local pkg = strchar(const.OK_HEADER)
             .. packet.to_length_encode_int(conn.affected_rows)  -- AffectedRows
             .. packet.to_length_encode_int(conn.last_insert_id) -- InsertId

    if band(conn.capability, const.CLIENT_PROTOCOL_41) > 0 then
        pkg = pkg .. packet.set_byte4(0) 
        pkg_len = pkg_len + 4
    else
        pkg = pkg .. strchar(0)
        pkg_len = pkg_len + 1
    end
    return packet.send_packet(self, pkg, pkg_len)
end
return _M
