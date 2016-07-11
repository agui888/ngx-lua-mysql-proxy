-- Copyright (C) 2016 HuangChuanTong@WPS.CN
--
-- 处理命令：query

local backen = require "myshard.proxy.conn_backen"

local strbyte = string.byte
local strchar = string.char
local strfind = string.find
local format = string.format

local _M = require "myshard.proxy.conn_class"

-- return err if did not success
function _M.handle_query(conn, query, size)
    print("query-string=[", query, "],db=[", conn.db, "]")
    local need_master = false
    local db, err = backen.get_mysql_connect(conn, need_master)
    if err ~= nil then
        ngx.log(ngx.ERR, "failed to get_mysql_connect() err=", err)
        return err
    end
    assert(db)

    local res, err, errno, sqlstate = db:query(query, conn)
    if err ~= nil then
        if err ~= 'again' then
            ngx.log(ngx.ERR, "query=[", query, "] err=", err,
                "] errno=[", errno, "] sqlstate=", sqlstate)
               return err
        end
        while err == 'again' do
            if err ~= 'again' then
                ngx.log(ngx.ERR, "query=[", query, "] err=", err,
                "] errno=[", errno, "] sqlstate=", sqlstate)
                return err
            end
            conn.packet_no = -1
            res, err, errno, sqlstate = db:read_query_result(conn)
        end
    end

    print("end handl-query: ", query)
    return nil
end


return _M
