-- Copyright (C) 2016 HuangChuanTong@WPS.CN
--
-- MySQL sharding 请求入口

local bit = require "bit"
local conn = require "mysharding.proxy.conn"
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


local mysql_host = "127.0.0.1"
local mysql_port = 3306
---------------------------------------------
function abort(msg)
	ngx.say(msg)
	ngx.eof()
end
-- request begin :
function request_entry()
	local c, err = conn.new()
	assert(c)

	local ok, err = c:handshake() -- mysql poto frist comminica
	if ok ~= true then
		abort(err)
		return
	end

	ngx.log(ngx.INFO, ngx.var.remote_addr, "handshake finish, go into event_loop(), conn_id=%s", c.conn_id)
	-- entry event loop
	c:event_loop()
	ngx.log(ngx.INFO, "conn close, remote=[", ngx.var.remote_addr, "] conn_id=%s", c.conn_id)
	c:close()
end

request_entry()

