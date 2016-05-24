-- Copyright (C) 2016 HuangChuanTong@WPS.CN
-- --
--

local conf = require "myshard.conf"
local mysql = require "myshard.mysql.mysql"

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
-- return err if did not success
function _M.handle_field_list(conn, data)

end

return _M

