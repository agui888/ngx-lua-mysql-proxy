-- Copyright (C) 2016 HuangChuanTong@WPS.CN
--
-- ngx.req tcp connecttion from client side
-- the class of Conn{} define

local bit       = require "bit"

local utils     = require "myshard.proxy.utils"
local command    = require "myshard.proxy.command"

local const     = require "myshard.mysql.const"
local packet    = require "myshard.mysql.packet"
local charset   = require "myshard.mysql.charset"
local bytesio   = require "myshard.mysql.bytesio"
local packetio  = require "myshard.mysql.packetio"

------ Start extend the calss of Conn ------
local _M            = require "myshard.proxy.conn_class"
local proxy_query   = require "myshard.proxy.conn_query"
local proxy_select  = require "myshard.proxy.conn_select"
------ End   extend the calss of Conn ------

local bor    = bit.bor
local band   = bit.band
local lshift = bit.lshift
local rshift = bit.rshift

local null    = ngx.null

local strchar = string.char
local strsub  = string.sub
local strlen  = string.len
local strbyte = string.byte
local strfind = string.find
local format  = string.format

local PROTO_VERISON = 10
local SERVER_VERISON = "5.6.01-proxy-mysql-ngx"

local OK = packetio.PKG_TYPE_OK
local EOF = packetio.PKG_TYPE_EOF
local ERR = packetio.PKG_TYPE_ERR
local DATA = packetio.PKG_TYPE_DATA


-- @return success(nil); faild(errmsg)
function _M.Handshake(self)
    local err = self:_send_handshake_pkg()
    if err ~= nil then
        ngx.log(ngx.ERR, "send handshake pkg failed=",err)
        return err
    end

    local ok, errmsg, errno, sqlstate = self:_read_handshake_response()
    if not ok then
        ngx.log(ngx.ERR, "recv handshake response failed, err=[", errmsg,
                "] errno=[", errno, "] sqlstate=[",sqlstate, "]")
        return errmsg
    end
    ngx.log(ngx.NOTICE,"TODO: check the proxy-mysql-ngx auth(user, password).")
    -- TODO: check --> self.auth
    -- checkAuth := CalcPassword(c.salt, []byte(c.server.cfg.Password))
    -- if !bytes.Equal(auth, checkAuth) {
    --     return NewDefaultError(ER_ACCESS_DENIED_ERROR, c.c.RemoteAddr().String(), c.user, "Yes")
    -- }

    local err = self:send_ok()
    if err ~= nil then
        ngx.log(ngx.ERR, "faild on send-ok in handshake, err=",err)
        return err
    end
    return true
end

-- event-loop
function _M.Run(self)
    local pkg, err
    while true do
        pkg, err = self:_recv_packet()
        if nil == pkg or err ~= nil then
            ngx.log(ngx.WARN, "Conn._recv_packet err=[", err, "] End-event-loop.")
            return
        end

        if pkg.typ == ERR then
            ngx.log(ngx.ERR, "TODO: call handle-errno() and send Errno to client and continue event-loop.")
            return

        elseif pkg.typ == DATA then
            err = self:_command_dispath(pkg)
            if err ~= nil then
                if err ~= "closed" then
                    ngx.log(ngx.WARN, "dispath command pkg=", pkg, " err=", err)
                end
                return
            end
        elseif pkg.typ == OK then
            ngx.log(ngx.DEBUG, "recv 'OK',Nothing can be done. continue event_loop.")
        end
        self.packet_no = 0
    end
end

-- @return (bin-string, str_len), bin-string as a package send to client sock.
function _M._make_handshake_pkg(self)
    local pkg = strchar(PROTO_VERISON)  -- 1
            .. bytesio.to_cstring(SERVER_VERISON) -- strlen()+1
            .. bytesio.set_byte4(self.connection_id)  -- 4
            .. bytesio.to_cstring(strsub(self.salt, 1, 8))   -- auth-plugin-data-part-1
            .. bytesio.set_byte2(const.DEFAULT_CAPABILITY)
            .. strchar(charset.UTF8_COLLATION_ID)           -- just support charset=utf8
            .. bytesio.set_byte2(self.state)                 -- autocommit=true/false
            .. strchar(band(rshift(const.DEFAULT_CAPABILITY, 16), 0xff))
            .. strchar(band(rshift(const.DEFAULT_CAPABILITY, 24), 0xff))
            .. strchar(0x15)                            -- filter string
            .. strchar(0, 0, 0, 0, 0, 0, 0, 0, 0, 0)    -- reserved 10 [00]
            .. bytesio.to_cstring(strsub(self.salt, 9, -1))  -- auth-plugin-data-part-2

    local pkg_len = 1 + strlen(SERVER_VERISON) + 1 + 4 + 9 + 1 + 2 + 1 + 2 + 3 + 10
                + strlen(strsub(self.salt, 9, -1)) 
    return pkg, pkg_len
end

-- @return success(nil), faild(errmsg)
function _M._send_handshake_pkg(self)
    local pkg, len = _make_handshake_pkg(self)

    ngx.log(ngx.NOTICE, "Sending handshake pkg_len=>", len)

    local err = self:send_packet(pkg, len)
    if nil ~= err then
        return "failed to send client handshake packet: " .. err
    end
    return nil
end


-- read the handshake from the mysql-client side
-- @return success(true, nil), faild(false, errmsg, errno, sqlstate)
function _M._read_handshake_response(self)
    local data, typ, err= self:_recv_packet()
    if not data then
        return false, err
    end
    if typ == ERR then
        local errno, msg, sqlstate = packetio.parse_err_packet(data)
        return false, msg, errno, sqlstate
    end

    local capability, pos = bytesio.get_byte4(data, 1)
    self.capability = capability

    local size, pos = bytesio.get_byte4(data, pos)

    -- charset, if you want to use another charset, use set names
    self.collation_id = strbyte( strsub(data, pos, pos + 1))
    print("TODO: charset_id=", self.collation_id, " pos=", pos)
    pos = pos + 1

    -- skip reserved 23[00]
    pos = pos + 23

    -- user name
    local user, next_pos = bytesio.from_cstring(data, pos)
    if user ~= nil then
        self.user = user
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
        self.auth = auth
        ngx.log(ngx.INFO, "auth-string-len: ", auth_len)
    else
        ngx.log(ngx.WARN, "auth-string empty.")
    end

    if bor(self.capability, const.CLIENT_CONNECT_WITH_DB) > 0 then
        local db, pos = bytesio.from_cstring(data, pos)
        if db == nil or strlen(db) == 0 then
            return true, nil
        end
        ngx.log(ngx.DEBUG, "Connect with db: ", db)
        self.db = db
    else
        ngx.log(ngx.NOTICE, "without use db to connect.")
    end
    return true, nil
end

-- class private function. dispath then MySQL command.
-- @param pkg instance of packet.New(raw_data, size, cmd)
function _M._command_dispath(self, pkg)
    local cmd = pkg.cmd
    local size = pkg.size
    local data = strsub(pkg.raw_data, 2)

    ngx.log(ngx.NOTICE, format("dispath-pkg cmd=>[%#x] data=[%s]", cmd, data))

    if cmd == command.COM_QUERY then
        return proxy_query.handle_query(self, data, size)

    elseif cmd == command.COM_FIELD_LIST then

        return proxy_select.handle_field_list(self, data, size)

    elseif cmd == command.COM_INIT_DB then
        if strlen(data) > 0 then
            self.db = data
            --return nil
        end
        local err = self:send_ok()
        return err
    else 
        ngx.log(ngx.NOTICE, format(" **** Commad[%#x] not supported data=[%s]", cmd, data))
        return proxy_select.handle_field_list(self, data, size)

    elseif cmd == command.COM_QUIT then
        return "closed"
    end
    return pkg, nil
end

-- @return: sunccess(nil), faild(errmsg)
function _M.send_ok(self)
    local pkg_len = 3
    local pkg = strchar(OK)
             .. bytesio.to_length_encode_int(self.affected_rows)  -- AffectedRows
             .. bytesio.to_length_encode_int(self.last_insert_id) -- InsertId

    if band(self.capability, const.CLIENT_PROTOCOL_41) > 0 then
        pkg = pkg .. bytesio.set_byte4(0) 
        pkg_len = pkg_len + 4
    else
        pkg = pkg .. strchar(0)
        pkg_len = pkg_len + 1
    end
    return self:send_packet(pkg, pkg_len)
end

-- @param raw_data binary data send to socket
-- @param size data length.
-- @return: success(nil), faild(errmsg)
function _M.send_packet(self, raw_data, size)
    self.packet_no = self.packet_no + 1
    if self.packet_no > 255 then
        self.packet_no = 0
    end

    print(format("[%s] -> send packet-no=[%d] data-len=[%d] pkg-size=header+data=[%d]",
        self.name, self.packet_no, size, size + 4))

    local packet = bytesio.set_byte3(size)
        .. strchar(self.packet_no) 
        .. raw_data

    local bytes, err = self.sock:send(packet)
    if bytes ~= (size+4) then
        local err = 'send bytes[%s] expect,but send[%s]':format(size+4, bytes)
        ngx.log(ngx.ERR, err)
        return err
    end
    return err
end

-- recv raw data from the socket follw the MySQL-potocol.
-- @return (packet{}, errmsg)
function _M._recv_packet(self)
    local sock = self.sock
    local header, err = sock:receive(4) -- packet header
    if not header then
        if err == 'closed' then
            print(self.name, " sock closed")
            return nil, err 
        end
        return nil, "failed to receive packet header: " .. err
    end

    local len, pos = bytesio.get_byte3(header, 1)

    -- print("packet header: ", bytesio.dumphex(header))
    -- print("packet length: ", len)

    if len == 0 then
        return nil, "empty packet"
    end

    if len > self.max_packet_size then
        return nil, "packet size too big: " .. len
    end

    self.packet_no = strbyte(header, pos)

    local data, err = sock:receive(len)

    if not data then
        return nil, "failed to read packet content: " .. err
    end

    -- print("packet content: ", bytesio.dump(data))
    -- print("packet content (ascii): ", data)

    local cmd = strbyte(data, 1)

    print(format("[%s] recv packet-no=[%d] len=[%d] cmd=[%s]",
        self.name, self.packet_no, len, cmd))

    local pkg, err = packet.New(data, len, cmd)
    return pkg, err
end


function _M.Close(self)
    ngx.log(ngx.INFO, "close.")
end


return _M
