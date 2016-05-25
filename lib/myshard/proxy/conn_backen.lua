-- Copyright (C) 2016 HuangChuanTong@WPS.CN
--
-- 

local conf = require "myshard.conf"
local mysql = require "myshard.mysql.mysql"

local _M = {_VERSION = '1.0'}
local mt = { __index = _M }


-- args:
--   conn was instance of myshard.proxy.conn
--   is_master: bool, master mean to write,
function _M.get_mysql_connect(conn, is_master)
    local db, err = mysql.new()
    assert(db)
    db:set_timeout(conf.BACKEN_TIMEOUT)

    local ok, err, errno, sqlstate = db:connect{
        host=conf.MySQL_HOST,
        port=conf.MySQL_PORT,
        user=conf.MySQL_USER,
        database=conn.db,
        password=conf.MySQL_PASS,
        charset='utf8'
    }
    if not ok then
        ngx.log(ngx.ERR, "error when connect to [",
            conf.MySQL_HOST, ":", conf.MySQL_PORT, "], err=",
            err, " errno=", errno, "sqlstate=", sqlstate)
        return nil, err
    end
    assert(ok)
    return db, nil
end