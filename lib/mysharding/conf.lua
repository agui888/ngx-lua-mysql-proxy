-- Copyright (C) 2016 HuangChuanTong@WPS.CN

local _M = {}
_M._VERSION = '1.0'

local mt = { __index = _M }

local Second = 1000
-- constants
_M.REQ_TIMEOUT = 60 * Second     -- 应该设大点
_M.BACKEN_TIMEOUT = 3600 * Second  -- 


return _M