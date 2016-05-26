-- Copyright (C) 2012 Yichun Zhang (agentzh)


local bit = require "bit"
local bytesio = require "myshard.mysql.bytesio"
local packetio = require "myshard.mysql.packet"

local tcp = ngx.socket.tcp
local null = ngx.null

local strsub = string.sub
local strbyte = string.byte
local strchar = string.char
local strfind = string.find
local format = string.format
local strrep = string.rep
local strlen = string.len

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


if not ngx.config
   or not ngx.config.ngx_lua_version
   or ngx.config.ngx_lua_version < 9011
then
    error("ngx_lua 0.9.11+ required")
end


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


local function _compute_token(password, scramble)
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


function _M.new(self)
    local sock, err = tcp()
    if not sock then
        return nil, err
    end
    return setmetatable({ sock = sock, name="mysql-cli" }, mt)
end


function _M.set_timeout(self, timeout)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end

    return sock:settimeout(timeout)
end


function _M.connect(self, opts)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end

    local max_packet_size = opts.max_packet_size
    if not max_packet_size then
        max_packet_size = 1024 * 1024 -- default 1 MB
    end
    self.max_packet_size = max_packet_size

    local ok, err

    self.compact = opts.compact_arrays

    local database = opts.database or ""
    local user = opts.user or ""

    local pool = opts.pool

    local host = opts.host
    if host then
        local port = opts.port or 3306
        if not pool then
            pool = user .. ":" .. database .. ":" .. host .. ":" .. port
        end

        ok, err = sock:connect(host, port, { pool = pool })

    else
        local path = opts.path
        if not path then
            return nil, 'neither "host" nor "path" options are specified'
        end

        if not pool then
            pool = user .. ":" .. database .. ":" .. path
        end

        ok, err = sock:connect("unix:" .. path, { pool = pool })
    end

    if not ok then
        return nil, 'failed to connect: ' .. err
    end

    local reused = sock:getreusedtimes()

    if reused and reused > 0 then
        self.state = STATE_CONNECTED
        return 1
    end

    local packet, typ, len, err = packetio.recv_packet(self)
    if not packet then
        return nil, err
    end

    if typ == "ERR" then
        local errno, msg, sqlstate = packetio.parse_err_packet(packet)
        return nil, msg, errno, sqlstate
    end

    self.protocol_ver = strbyte(packet)

    -- print("protocol version: ", self.protocol_ver)

    local server_ver, pos = bytesio.from_cstring(packet, 2)
    if not server_ver then
        return nil, "bad handshake initialization packet: bad server version"
    end

    -- print("server version: ", server_ver)

    self._server_ver = server_ver

    local thread_id, pos = bytesio.get_byte4(packet, pos)

    -- print("thread id: ", thread_id)

    local scramble = strsub(packet, pos, pos + 8 - 1)
    if not scramble then
        return nil, "1st part of scramble not found"
    end

    pos = pos + 9 -- skip filler

    -- two lower bytes
    local capabilities  -- server capabilities
    capabilities, pos = bytesio.get_byte2(packet, pos)

    -- print(format("server capabilities: %#x", capabilities))

    self._server_lang = strbyte(packet, pos)
    pos = pos + 1

    print("server lang: ", self._server_lang)

    self._server_status, pos = bytesio.get_byte2(packet, pos)

    -- print("server status: ", self._server_status)

    local more_capabilities
    more_capabilities, pos = bytesio.get_byte2(packet, pos)

    capabilities = bor(capabilities, lshift(more_capabilities, 16))
    self._server_capabilities = capabilities

    -- print("server capabilities: ", capabilities)

    -- local len = strbyte(packet, pos)
    local len = 21 - 8 - 1

    -- print("scramble len: ", len)

    pos = pos + 1 + 10

    local scramble_part2 = strsub(packet, pos, pos + len - 1)
    if not scramble_part2 then
        return nil, "2nd part of scramble not found"
    end

    scramble = scramble .. scramble_part2
    -- print("scramble: ", _dump(scramble))

--    local client_flags =0xa205;-- band(8717, self._server_capabilities) --0x3f7cf;
--	print("client_flags=> ", client_flags)
    local client_flags = 0x3f7cf;

    local ssl_verify = opts.ssl_verify
    local use_ssl = opts.ssl or ssl_verify

    if use_ssl then
        if band(capabilities, CLIENT_SSL) == 0 then
            return nil, "ssl disabled on server"
        end

        -- send a SSL Request Packet
        local req = bytesio.set_byte4(bor(client_flags, CLIENT_SSL))
                    .. bytesio.set_byte4(self.max_packet_size)
                    .. "\0" -- TODO: add support for charset encoding
                    .. strrep("\0", 23)

        local packet_len = 4 + 4 + 1 + 23
        local bytes, err = packetio.send_packet(self, req, packet_len)
        if not bytes then
            return nil, "failed to send client authentication packet: " .. err
        end

        local ok, err = sock:sslhandshake(false, nil, ssl_verify)
        if not ok then
            return nil, "failed to do ssl handshake: " .. (err or "")
        end
    end

    local password = opts.password or ""

    local token = _compute_token(password, scramble)

    -- print("token: ", _dump(token))

    local req = bytesio.set_byte4(client_flags)
                .. bytesio.set_byte4(self.max_packet_size)
                .. strchar(33) -- "\0" -- TODO: add support for charset encoding
                .. strrep("\0", 23)
                .. bytesio.to_cstring(user)
                .. bytesio.to_binary_coded_string(token)
                .. bytesio.to_cstring(database)

    local packet_len = 4 + 4 + 1 + 23 + #user + 1
        + #token + 1 + #database + 1

    -- print("packet content length: ", packet_len)
    -- print("packet content: ", _dump(concat(req, "")))

    local bytes, err = packetio.send_packet(self, req, packet_len)
    if not bytes then
        return nil, "failed to send client authentication packet: " .. err
    end

    -- print("packet sent ", bytes, " bytes")

    local packet, typ, len, err = packetio.recv_packet(self)
    if not packet then
        return nil, "client failed to receive the result packet: " .. err
    end

    if typ == 'ERR' then
        local errno, msg, sqlstate = packetio.parse_err_packet(packet)
        return nil, msg, errno, sqlstate
    end

    if typ == 'EOF' then
        return nil, "old pre-4.1 authentication protocol not supported"
    end

    if typ ~= 'OK' then
        return nil, "bad packet type: " .. typ
    end

    self.state = STATE_CONNECTED

    return 1
end


function _M.set_keepalive(self, ...)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end

    if self.state ~= STATE_CONNECTED then
        return nil, "cannot be reused in the current connection state: "
                    .. (self.state or "nil")
    end

    self.state = nil
    return sock:setkeepalive(...)
end


function _M.get_reused_times(self)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end

    return sock:getreusedtimes()
end


function _M.close(self)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end

    self.state = nil

    return sock:close()
end


function _M.server_ver(self)
    return self._server_ver
end


local function send_query(self, query)
    if self.state ~= STATE_CONNECTED then
        return nil, "cannot send query in the current context: "
                    .. (self.state or "nil")
    end

    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end

    self.packet_no = -1

    local cmd_packet = strchar(COM_QUERY) .. query
    local packet_len = 1 + #query

    local bytes, err = packetio.send_packet(self, cmd_packet, packet_len)
    if not bytes then
        return nil, err
    end

    self.state = STATE_COMMAND_SENT

    --print("packet sent ", bytes, " bytes")

    return bytes
end
_M.send_query = send_query


local function read_result(self, out_conn)
    if self.state ~= STATE_COMMAND_SENT then
        return nil, "cannot read result in the current context: " .. self.state
    end

    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end

    print(self.name, " goin to recv_packet on read_result .")
    local packet, typ, len, err = packetio.recv_packet(self)
    if not packet then
        print("read-result: errp=[", err, "] len=[", len, "]")
        return nil, err
    end
    print("read-result: typ=[", typ, "] len=[", len, "]")
    if typ == "ERR" then
        self.state = STATE_CONNECTED
        local errno, msg, sqlstate = packetio.parse_err_packet(packet)
        return nil, msg, errno, sqlstate
    end

    if typ == 'OK' then
        local res = packetio.parse_ok_packet(packet)
        if res and band(res.server_status, SERVER_MORE_RESULTS_EXISTS) ~= 0 then
            return res, "again"
        end

        self.state = STATE_CONNECTED
        return res
    end

    if typ ~= 'DATA' then
        self.state = STATE_CONNECTED

        return nil, "packet type " .. typ .. " not supported"
    end

    -- typ == 'DATA'

    local bytes, err = out_conn:send_packet(packet, len) -- 
    if err ~= nil then
        ngx.log(ngx.NOTICE, "failed to send query resutl header packet to client, err=", err)
        self:close()
        return nil, err
    end

    --print("read the result set header packet")

    local field_count, extra = packetio.parse_result_set_header_packet(packet)

    --print("field count: ", field_count)
    for i = 1, field_count do
--        local packet, err, errno, sqlstate = packetio.recv_field_packet(self)
		local packet, typ, len, err = packetio.recv_packet(self)
        if not packet then
            return nil, err, errno, sqlstate
        end
--        local len = errno

        bytes, err = out_conn:send_packet(packet, len)
        if err ~= nil then
            ngx.log(ngx.NOTICE, "failed to send query resutl of col to client, err=",
                err, " remain [", field_count-i+1,"]cols did not read")
            self:close()
            return nil, err
          end
    end

    packet, typ, len, err = packetio.recv_packet(self)
    if not packet then
        return nil, err
    end

    if typ ~= 'EOF' then
        return nil, "unexpected packet type " .. typ .. " while eof packet is "
            .. "expected"
    end
    bytes, err = out_conn:send_packet(packet, len)
    if err ~= nil then
        ngx.log(ngx.NOTICE, "failed to send query col EOF, err=", err)
        self:close()
        return nil, err
    end

    -- typ == 'EOF'
    local i = 0
    while true do
        --print("reading a row")
        packet, typ, len, err = packetio.recv_packet(self)
        if not packet then
            return nil, err
        end

        bytes, err = out_conn:send_packet(packet, len)
        if err ~= nil then
            ngx.log(ngx.NOTICE, "failed to send query col EOF, err=", err)
            self:close()
            return nil, err
          end

        if typ == 'EOF' then
            local warning_count, status_flags = packetio.parse_eof_packet(packet)
            --print("status flags: ", status_flags)
            if band(status_flags, SERVER_MORE_RESULTS_EXISTS) ~= 0 then
                return rows, "again"
            end
            break
        end
        i = i + 1
    end

    self.state = STATE_CONNECTED

    return true, nil
end

_M.read_result = read_result

-- args: out_conn was the instance of myshard.proxy.conn
function _M.query(self, query, out_conn)

    local bytes, err = send_query(self, query)
    if not bytes then
        return nil, "failed to send query: " .. err
    end

    return read_result(self, out_conn)

end


function _M.send_commad(self, cmd, pkg, pkg_len, out_conn)
    if self.state ~= STATE_CONNECTED then
        return nil, "cannot send commad in the current context: "
                    .. (self.state or "nil")
    end

    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end
    self.packet_no = -1

    local cmd_packet = strchar(cmd) .. pkg
    local packet_len = 1 + pkg_len

    print(format("%s -> send cmd[%#x] data[%s] len[%d]",self.name, cmd, cmd_packet, packet_len ))
    local bytes, err = packetio.send_packet(self, cmd_packet, packet_len)
    if not bytes or err ~=nil then
        print("err = ", err)
        return nil, err
    end

    self.state = STATE_COMMAND_SENT

    return read_result(self, out_conn)
end


function _M.set_compact_arrays(self, value)
    self.compact = value
end


return _M
