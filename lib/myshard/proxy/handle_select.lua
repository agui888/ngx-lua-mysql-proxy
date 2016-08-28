-- Copyright (C) 2016 HuangChuanTong@WPS.CN
-- 
--

local backen = require "myshard.proxy.conn_backen"
local commad = require "myshard.proxy.commad"

local strsub = string.sub
local strbyte = string.byte
local strchar = string.char

local _M = {_VERSION = '1.0'}
local mt = { __index = _M }


-- return err if did not success
function _M.handle_field_list(conn, data, size)
    local db, err = backen.get_mysql_connect(conn, true)
    if err ~= nil then
        ngx.log(ngx.ERR, "failed to get_mysql_connect() err=", err)
        return err
    end
    assert(db)

    local ok, err = db:send_commad(commad.COM_FIELD_LIST, data, size, conn)
    if not ok then
        ngx.log(ngx.ERR, "failed to send_commad to backen, err=", err)
        return err
    end
    db:set_keepalive(30* 1000)
    return nil
end

return _M

