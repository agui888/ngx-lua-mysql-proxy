-- Copyright (C) 2016 HuangChuanTong@WPS.CN
--
-- MySQL protocol socket packet 

local packetio  = require "myshard.mysql.packetio"

local _M = {}
local mt = {__index = _M}

-- constants
-- 16MB - 1, the default max allowed packet size used by libmysqlclient
local FULL_PACKET_SIZE  = 16777215
_M.PKG_TYPE_OK          = 0x00
_M.PKG_TYPE_EOF         = 0xfe
_M.PKG_TYPE_ERR         = 0xff
_M.PKG_TYPE_DATA        = -1  --- 自定义，MySQL协议并没此消息类型，表示非以上3种

-- Packet{raw_data, size, typ, cmd}
-- Packet{errno, errmsg, sqlstate}
function _M.New(raw_data, size, cmd)
    self = {
        raw_data = raw_data,
        size = size,
        typ = typ,
        cmd = cmd
    }
    local typ
    if cmd == 0x00 then
        typ = _M.PKG_TYPE_OK
    elseif cmd == 0xff then
        typ = _M.PKG_TYPE_ERR
    elseif cmd == 0xfe then
        typ = _M.PKG_TYPE_EOF
    elseif cmd <= 250 then
        typ = _M.PKG_TYPE_DATA
    end

    if typ == PKG_TYPE_ERR then
        local errno, msg, sqlstate = packetio.parse_err_packet(raw_data)
        self.errno = errno
        self.errmsg = msg
        self.sqlstate =  sqlstate
    end

    return setmetatable(self, _M)
end

function _M:__tostring(self)
    if self.typ == _M.PKG_TYPE_ERR then
        return "Packet{errno=%s, errmsg=`%s`, state=%s}":format(self.errno, self.errmsg, self.sqlstate)
    end

    return "Packet{cmd=[%#X],typ=[%d],raw_data=[%s]}":format(self.cmd, self.typ, self.raw_data)
end

return _M