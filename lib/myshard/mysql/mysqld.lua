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

local const = require "myshard.mysql.const"
local charset = require "myshard.mysql.charset"
local bytesio = require "myshard.mysql.bytesio"
local packetio = require "myshard.mysql.packetio"

local PROTO_VERISON = 10
local SERVER_VERISON = "5.5.55-shard-0.1"

local OK = packetio.PKG_TYPE_OK
local EOF = packetio.PKG_TYPE_EOF
local ERR = packetio.PKG_TYPE_ERR
local DATA = packetio.PKG_TYPE_DATA

local _M = { _VERSION = '0.1' }
local mt = { __index = _M }

-- args: conn was myshard.proxy.conn
local function _make_handshake_pkg(conn)
    local pkg = strchar(PROTO_VERISON)  -- 1
            .. bytesio.to_cstring(SERVER_VERISON) -- strlen()+1
            .. bytesio.set_byte4(conn.connection_id)  -- 4
            .. bytesio.to_cstring(strsub(conn.salt, 1, 8))   -- auth-plugin-data-part-1
            .. bytesio.set_byte2(const.DEFAULT_CAPABILITY)
            .. strchar(charset.UTF8_COLLATION_ID)           -- just support charset=utf8
            .. bytesio.set_byte2(conn.state)                 -- autocommit=true/false
            .. strchar(band(rshift(const.DEFAULT_CAPABILITY, 16), 0xff))
            .. strchar(band(rshift(const.DEFAULT_CAPABILITY, 24), 0xff))
            .. strchar(0x15)                            -- filter string
            .. strchar(0, 0, 0, 0, 0, 0, 0, 0, 0, 0)    -- reserved 10 [00]
            .. bytesio.to_cstring(strsub(conn.salt, 9, -1))  -- auth-plugin-data-part-2

    local pkg_len = 1 + strlen(SERVER_VERISON) + 1 + 4 + 9 + 1 + 2 + 1 + 2 + 3 + 10
                + strlen(strsub(conn.salt, 9, -1)) 
    return pkg, pkg_len
end

-- args: conn was myshard.proxy.conn
function _M.send_handshake(conn)
    local pkg, len = _make_handshake_pkg(conn)
    
    ngx.log(ngx.NOTICE, " send handshake pkg_len=>", len)

    local bytes, err = packetio.send_packet(conn, pkg, len)
    if not bytes then
        return "failed to send client handshake packet: " .. err
    end
    return nil
end

-- args: conn was myshard.proxy.conn
-- read the handshake from the mysql-client side
function _M.read_handshake_response(conn)
    local data, typ, err= packetio.recv_packet(conn)
    if not data then
        return false, err
    end
    if typ == ERR then
        local errno, msg, sqlstate = packetio.parse_err_packet(data)
        return false, msg, errno, sqlstate
    end

    local capability, pos = bytesio.get_byte4(data, 1)
    conn.capability = capability

    local size, pos = bytesio.get_byte4(data, pos)
    print("client.max-packet-size:", size)

    -- charset, if you want to use another charset, use set names
    conn.collation_id = strbyte( strsub(data, pos, pos + 1))
    print("charset_id=", conn.collation_id, " pos=", pos)
    pos = pos + 1

    -- skip reserved 23[00]
    pos = pos + 23

    -- user name
    local user, next_pos = bytesio.from_cstring(data, pos)
    if user ~= nil then
        conn.user = user
        pos = next_pos
        ngx.log(ngx.INFO, "connect with user: ", user)
    else
        ngx.log(ngx.WARN, "user is empty to auth.")
    end

    local auth_len = strbyte(strsub(data, pos, pos + 1))
    pos = pos + 1
    local auth = strsub(data, pos, pos+auth_len)
    pos = pos + auth_len
    
    if auth_len > 0 then
        conn.auth = auth
        ngx.log(ngx.INFO, "auth-string-len: ", auth_len)
    else
        ngx.log(ngx.WARN, "auth-string empty.")
    end

    if bor(conn.capability, const.CLIENT_CONNECT_WITH_DB) > 0 then
        local db, pos = bytesio.from_cstring(data, pos)
        if db == nil or strlen(db) == 0 then
            return true, nil
        end
        ngx.log(ngx.DEBUG, "Connect with db: ", db)
        conn.db = db
    else
        ngx.log(ngx.NOTICE, "without use db to connect.")
    end
    return true, nil
end

function _M.send_ok(conn)
    local pkg_len = 3
    local pkg = strchar(OK)
             .. bytesio.to_length_encode_int(conn.affected_rows)  -- AffectedRows
             .. bytesio.to_length_encode_int(conn.last_insert_id) -- InsertId

    if band(conn.capability, const.CLIENT_PROTOCOL_41) > 0 then
        pkg = pkg .. bytesio.set_byte4(0) 
        pkg_len = pkg_len + 4
    else
        pkg = pkg .. strchar(0)
        pkg_len = pkg_len + 1
    end
    return packetio.send_packet(conn, pkg, pkg_len)
end
return _M
