-- Copyright (C) 2016 HuangChuanTong@WPS.CN
--
-- ngx.req tcp connecttion from client side
--
local bit = require "bit"
local conf = require "myshard.conf"
local mysqld = require "myshard.mysql.mysqld"
local const = require "myshard.mysql.const"
local charset = require "myshard.mysql.charset"
local utils = require "myshard.proxy.utils"

local null = ngx.null
local strsub = string.sub
local strbyte = string.byte
local strchar = string.char
local strfind = string.find
local format = string.format
local band = bit.band
local error = error


local _M = {_VERSION = '0.1'}
local mt = { __index = _M }


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
        -- # TODO: conn_id
        _M.conn_id = 2000
        _M.conn_id = _M.conn_id + 1
    else
        conn_id = myshard:incr("conn_id", 1)
    end

    local map = {
        sock=sock, 
        charset=charset.UTF8_CHARSET,
        user="",
        db="",
        packet_no=-1,
        state=const.SERVER_STATUS_AUTOCOMMIT,
        salt=utils.rand_str(20),
        connection_id = conn_id,
        last_insert_id=0,
        affected_rows=0,
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
    local err = mysqld.send_handshake(self)
    if err ~= nil then
        ngx.log(ngx.ERR, "send handshake pkg failed=",err)
        return false, err
    end

    local ok, errmsg, errno, sqlstate = mysqld.read_handshake_response(self)
    if not ok then
        ngx.log(ngx.ERR, "recv handshake response failed, err=[", errmsg,
                "] errno=[", errno, "] sqlstate=[",sqlstate, "]")
        return false, errmsg
    end

    -- TODO: check --> self.auth
    -- checkAuth := CalcPassword(c.salt, []byte(c.server.cfg.Password))
    -- if !bytes.Equal(auth, checkAuth) {
    --     return NewDefaultError(ER_ACCESS_DENIED_ERROR, c.c.RemoteAddr().String(), c.user, "Yes")
    -- }

    local bytes, err = mysqld.send_ok()
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

function _M.close(self)
        ngx.log(ngx.INFO, "close.")
end

function _M.event_loop(conn)
    while true do
        local pkg, typ, err = packet.recv_packet(conn)
        if err ~= nil or pkg == nil then
                ngx.log(ngx.WARN, "recv err=", err, "typ=",typ)
                return
        end
        local result, err = conn:dispath(pkg)
        local ok, err = conn:write(result)
    end
end


return _M
