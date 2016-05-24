-- Copyright (C) 2016 HuangChuanTong@WPS.CN
-- 
-- MySQL proto utils function

local _M = { _VERSION = '0.1' }
local mt = { __index = _M }

local strchar = string.char
local rand = math.random

function _M.rand_str(length)
    local s = ""
    for i=1, tonumber(length) do
        s = s .. strchar(rand(256)-1)
    end
    return s
end


return _M