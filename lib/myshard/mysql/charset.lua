-- Copyright (C) 2016 HuangChuanTong@WPS.CN
-- 
-- MySQL proto charset define

local _M = { _VERSION = '0.15' }
local mt = { __index = _M }

_M.UTF8_CHARSET         = "utf8"
_M.UTF8_COLLATION_ID    = 33
_M.UTF8_COLLATION_NAME  = "utf8_general_ci"

return _M