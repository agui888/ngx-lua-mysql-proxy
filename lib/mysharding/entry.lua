-- Copyright (C) 2016 HuangChuanTong@WPS.CN
--
-- MySQL sharding 请求入口

local bit = require "bit"
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
	local conn, err = conn.New()
	assert(conn)

	local ok, err = conn.handshake() -- mysql poto frist comminica
	if not ok:
		abort(err)
	end

	ngx.log(ngx.INFO, ngx.var.remote_addr, " handshake finish, go into event_loop(), conn_id=%s", conn.conn_id)
	-- entry event loop
	conn.event_loop()
	ngx.log(ngx.INFO, "conn close, remote=[", ngx.var.remote_addr, "] conn_id=%s", conn.conn_id)
	conn.close()
end

request_entry()
return 


function connect_mysql_backen(host, port)
	local tcpsock = tcp()
	local tcpsock, err = tcp()
	if not tcpsock then
		ngx.log(ngx.ERR, "failed to creatre tcp() err=", err)
		return nil, err
	end
	-- TODO: pool += user .. ":" .. database .. ":" .. 
	local pool = host .. ":" .. port
	local ok, err = tcpsock:connect(host, port, { pool = pool })
	if not ok then
		ngx.log(ngx.ERR, "failed to connect:[", host, ":", host,"] err=", err)
		return nil, err
	end
	tcpsock:settimeout(BACKEN_TIMEOUT) 
	return tcpsock, nil
end

local mysql_svr, err = connect_mysql_backen(mysql_host, mysql_port)
if mysql_svr == nil or err ~= nil then
	abort(err)
	return
end

-- porxy main loop
function poxy_loop(req_sock, backen_sock)
	local recv, err, ok
	while true do
		local recv = backen_sock:receive()
		if not recv then
			ngx.log(ngx.INFO, "backen receive()->nil. err=", err)
			break
		end
		ok, err =  req_sock:send(recv)
		if not ok then
			ngx.log(ngx.INFO,"failed to send() to client, err=", err)
			break
		end
		recv, err = req_sock:receive()
		if not recv then 
			ngx.log(ngx.INFO,"failed to req.receive() from client, err=", err)
			break
		end
		ok, err = backn_sock:send(recv)
		if not ok then
			ngx.log(ngx.INFO,"failed to send() to backen, err=", err)
			break
		end
	end
end

poxy_loop(sock, mysql_svr)

mysql_svr:setkeepalive(0, 300)