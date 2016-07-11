-- Copyright (C) 2016 HuangChuanTong@WPS.CN
--
-- 

local conf  = require "myshard.conf"
local mysql = require "myshard.mysql.mysql"

local _M = require "myshard.proxy.conn_class"

-- @param is_master bool, true mean to write
-- @return (mysql_conn, errmsg)
function _M.get_mysql_connect(self, is_master)

    local mysql_node

    if is_master then
        mysql_node = conf.get_mysql_write(self.db, "")
    else
        mysql_node = conf.get_mysql_read(self.db, "")
    end
    if mysql_node == nil then
        return nil, "No MySQL node found."
    end


    local db, err = mysql.new()
    assert(db)
    db:set_timeout(conf.BACKEN_TIMEOUT)

    local ok, err, errno, sqlstate = db:connect{
        host=mysql_node.host,
        port=mysql_node.port,
        user=mysql_node.user,
        database=self.db,
        password=mysql_node.passwd,
        charset=mysql_node.charset or 'utf8'
    }

    if not ok then
        ngx.log(ngx.ERR, "error when connect to [",
            mysql_node.host, ":", mysql_node.port, "], err=",
            err, " errno=", errno, "sqlstate=", sqlstate)
        return nil, err
    end
    assert(ok)
    return db, nil
end

return _M
