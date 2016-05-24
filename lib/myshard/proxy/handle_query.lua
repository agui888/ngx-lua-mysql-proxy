-- Copyright (C) 2016 HuangChuanTong@WPS.CN
--
-- 模块注释

local conf = require "myshard.conf"
local mysql = require "myshard.mysql.mysql"

local null = ngx.null
local strsub = string.sub
local strbyte = string.byte
local strchar = string.char
local strfind = string.find
local format = string.format
local error = error
local tonumber = tonumber

local _M = {_VERSION = '1.0'}
local mt = { __index = _M }


-- 模块导出功能函数
function _M.handle(conn, query)
    print("query-string: ", query)
	local db, err = mysql.new()
	assert(db)
    db:set_timeout(conf.BACKEN_TIMEOUT)

	local ok, err, errno, sqlstate = db:connect{
		host=conf.MySQL_HOST,
		port=conf.MySQL_PORT,
		user=conf.MySQL_USER,
		db=conn.db,
		password=""
	}
	if not ok then
		ngx.log(ngx.ERR, "error when connect to [",conf.MySQL_HOST, ":", conf.MySQL_PORT, 
				"], err=", err, " errno=", errno)
		return err
	end
	assert(ok)

    local res, err, errno, sqlstate = db:query(conn, query)
	assert(res)
    print("end handl-query: ", query)
    return nil
end


return _M
