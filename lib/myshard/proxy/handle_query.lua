-- Copyright (C) 2016 HuangChuanTong@WPS.CN
--
-- 处理命令：query

local backen = require "myshard.proxy.conn_backen"

local strbyte = string.byte
local strchar = string.char
local strfind = string.find
local format = string.format

local _M = {_VERSION = '1.0'}
local mt = { __index = _M }

-- return err if did not success
function _M.handle_query(conn, query, size)
    -- print("query-string=[", query, "],db=[", conn.db, "]")

    local db, err = backen.get_mysql_connect(conn, true)
    if err ~= nil then
        ngx.log(ngx.ERR, "failed to get_mysql_connect() err=", err)
        return err
    end
    assert(db)

    local res, err, errno, sqlstate = db:query(query, conn)
    if err ~= nil then
        ngx.log(ngx.ERR, "query=[", query, "] err=", err,
            "] errno=[", errno, "] sqlstate=", sqlstate)
        return err
    end
    
    db:set_keepalive(30* 1000)

    ngx.log(ngx.INFO, "end handl-query: ", query)
    return nil
end


return _M
