-- Copyright (C) 2016 HuangChuanTong@WPS.CN
--
-- MySQL sharding 请求入口

local bit = require "bit"
local conn = require "myshard.proxy.conn"
local conf = require "myshard.conf"

local sub = string.sub
local tcp = ngx.socket.tcp
local strbyte = string.byte
local strchar = string.char
local strfind = string.find
local format = string.format
local strrep = string.rep
local null = ngx.null
local band = bit.band
local bxor = bit.bxor
local bor = bit.bor
local lshift = bit.lshift
local rshift = bit.rshift
local tohex = bit.tohex
local sha1 = ngx.sha1_bin
local concat = table.concat
local unpack = unpack
local setmetatable = setmetatable
local error = error
local tonumber = tonumber


---------------------------------------------
function abort(msg)
    ngx.say(msg)
    ngx.eof()
end


local _Start_Conn_Id = 10086

-- request begin :
local function request_entry()
    local conn_id = _Start_Conn_Id

    local shard = ngx.shared.myshard
    if shard == nil then 
        ngx.log(ngx.NOTICE, "TODO: ngx.shared.myshard['conn_id']..")
        _Start_Conn_Id = _Start_Conn_Id + 1
    else
        conn_id = shard:incr("conn_id", 1)
    end

    local c, err = conn.New(conn_id, conf.REQ_TIMEOUT)
    assert(c)

    local err = c:Handshake() -- mysql poto frist comminica
    if nil ~= err then
        ngx.log(ngx.ERR, "handshake failed and close conn, err=", err)
        abort(err)
        return
    end

    ngx.log(ngx.INFO, ngx.var.remote_addr, "handshake finish, go into event_loop Run(), conn_id=", c.conn_id)

    c:Run() -- entry event loop
    ngx.log(ngx.INFO, "conn close, remote=[", ngx.var.remote_addr, ":", ngx.var.remote_port,"] conn_id=", c.conn_id)
    c:Close()
end

request_entry()

