-- Copyright (C) 2016 HuangChuanTong@WPS.CN
--
-- ngx.req tcp connecttion from client side
--
local bit = require "bit"
local conf = require "mysharding.conf"
local package = require "mysharding.mysql.package"
local const = require "mysharding.mysql.const"

local null = ngx.null
local strsub = string.sub
local strbyte = string.byte
local strchar = string.char
local strfind = string.find
local format = string.format
local band = bit.band
local error = error
local tonumber = tonumber
local rand = math.random

local _M = {}
_M._VERSION = '1.0'

local mt = { __index = _M }

local function _rand_str(length)
    local s = ""
    for i=1, tonumber(length) do
        s = s .. strchar(rand(256)-1)
    end
    return s
end

_M.conn_id = 2000
function _M.new(self)
    local sock = ngx.req.socket(true)
    if not sock then
        ngx.log(ngx.ERR, "ngx.req.socket() err=", err)
        return nil, err
    end

    sock:settimeout(conf.REQ_TIMEOUT)
    local conn_id = _M.conn_id
	local myshard = ngx.shared.myshard
	if myshard == nil then 
		_M.conn_id = _M.conn_id + 1
	else
		conn_id = myshard:incr("conn_id", 1)
	end

    local map = {sock=sock, 
        charset="utf8",
        user="",
        db="",
		packet_no=-1,
        state=const.SERVER_STATUS_AUTOCOMMIT,
        salt="12345678901234567890", -- _rand_str(20),
        connection_id = conn_id,
        last_insert_id=-1,
        affected_rows=-1,
        auto_commit=true,
		max_packet_size = 16 * 1024 * 1024 -- default 16 MB
    }
    return setmetatable(map, mt)
end

function _M.use_db(self, db)
    print("conn use_db:", db)
    self.db = db
end

function _M.handshake(self)

    local err = package.send_handshake(self)
    if err ~= nil then
        ngx.log(ngx.ERR, "send handshake pkg failed=",err)
        return false, err
    end

    local ok, errmsg, errno, sqlstate = package.recv_handshake_response(self)
    if not ok then
        ngx.log(ngx.ERR, "recv handshake response failed, err=[", errmsg,
                "] errno=[", errno, "] sqlstate=[",sqlstate, "]")
        return false, errmsg
    end

    local bytes, err = self:send_ok()
	if err ~= nil then
			ngx.log(ngx.ERR, "faild on send-ok in handshake, err=",err)
			return false, err
	end

    return true, nil
end


function _M.dispath(self, pkg)
		return pkg, nil
end

function _M.write(self, resutl)
		if result ~= nil then
			self.sock:send(result)
		end
		return ok, nil
end

function _M.send_ok(self)
		local pkg_len = 3
		local pkg = strchar(const.OK_HEADER)
				 ..  package.to_length_encode_int(0) -- AffectedRows
				 ..  package.to_length_encode_int(0) -- InsertId

		if band(self.capability, const.CLIENT_PROTOCOL_41) > 0 then
				pkg = pkg .. package.set_byte4(0) 
				pkg_len = pkg_len + 4
		else
				pkg = pkg .. strchar(0)
				pkg_len = pkg_len + 1
		end
		return package.send_packet(self, pkg, pkg_len)
end

function _M.close(self)
		ngx.log(ngx.INFO, "close.")
end

function _M.event_loop(conn)
    while true do
        local pkg, typ, err = package.recv_packet(conn)
		if err ~= nil or pkg == nil then
				ngx.log(ngx.WARN, "recv err=", err, "typ=",typ)
				return
		end
        local result, err = conn:dispath(pkg)
        local ok, err = conn:write(result)
    end
end


return _M
