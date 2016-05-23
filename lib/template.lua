-- Copyright (C) 2016 HuangChuanTong@WPS.CN
--
-- 模块注释

local null = ngx.null
local strsub = string.sub
local strbyte = string.byte
local strchar = string.char
local strfind = string.find
local format = string.format
local error = error
local tonumber = tonumber

local _M = {}
_M._VERSION = '1.0'

local mt = { __index = _M }

function _M.new(self, a, b ...)
    return setmetatable({ a=a, b=c }, mt)
end

-- 模块导出功能函数
function _M.func_123(self)
    return self.a * self.b
end


return _M