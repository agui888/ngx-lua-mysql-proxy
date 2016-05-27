-- Copyright (C) 2016 HuangChuanTong@WPS.CN

if not ngx.config
   or not ngx.config.ngx_lua_version
   or ngx.config.ngx_lua_version < 9011
then
    error("ngx_lua 0.9.11+ required")
end


local _M = {}
_M._VERSION = '1.0'

local mt = { __index = _M }

local Second = 1000
-- constants
_M.REQ_TIMEOUT = 60 * Second       -- 应该设大点
_M.BACKEN_TIMEOUT = 3600 * Second  -- 

------- 
_M.MySQL_HOST = "127.0.0.1"
_M.MySQL_PORT = 3306
_M.MySQL_USER = "root"
_M.MySQL_PASS = ""


return _M

