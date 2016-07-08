-- Copyright (C) 2016 HuangChuanTong@WPS.CN
-- 
-- MySQL protocol of error

local ErrMsg = require "errmsg"
local ErrCode = require "errcode"
local ErrState = require "errstate"

local Error = {}
Error.__index = Error

-- new a Error() instance
-- @param code uint16 , must set.
-- @param message error string
-- @param State  string
-- @return Error instance
local function Error:new(code, message, state)

    assert(type(code) == 'number', "`code` must number.")

    local msg = ErrMsg[code] or message or "no error message."
    local stat = ErrState[code] or state or ErrState.DEFAULT_STATE

    local self = setmetatable({
            code=code, 
            message=msg,
            state=stat
        }, 
        Error)
    return self
end

return Error