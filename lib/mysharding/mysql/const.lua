-- Copyright (C) 2016 HuangChuanTong@WPS.CN
-- 
-- MySQL proto const define


module(..., package.seeall)

local bit = require "bit"
local band = bit.band
local bxor = bit.bxor
local bor = bit.bor
local lshift = bit.lshift
local rshift = bit.rshift
local tohex = bit.tohex

local _M = { _VERSION = '0.15' }
local mt = { __index = _M }


local CLIENT_LONG_PASSWORD = 0x0001
local CLIENT_FOUND_ROWS = 0x0002
local CLIENT_LONG_FLAG = 0x0004
local CLIENT_CONNECT_WITH_DB = 0x0008
local CLIENT_NO_SCHEMA = 0x0010
local CLIENT_COMPRESS = 0x0020
local CLIENT_ODBC = 0x0040
local CLIENT_LOCAL_FILES = 0x0080
local CLIENT_IGNORE_SPACE = 0x0100
local CLIENT_PROTOCOL_41 = 0x0200
local CLIENT_INTERACTIVE = 0x0400
local CLIENT_SSL = 0x0800
local CLIENT_IGNORE_SIGPIPE = 0x1000
local CLIENT_TRANSACTIONS = 0x2000
local CLIENT_RESERVED = 0x4000
local CLIENT_SECURE_CONNECTION = 0x8000
local CLIENT_MULTI_STATEMENTS = 0x10000
local CLIENT_MULTI_RESULTS = 0x20000
local CLIENT_PS_MULTI_RESULTS = 0x40000
local CLIENT_PLUGIN_AUTH = 0x80000
local CLIENT_CONNECT_ATTRS = 0x100000
local CLIENT_PLUGIN_AUTH_LENENC_CLIENT_DATA = 0x200000

local DEFAULT_CAPABILITY = bor(CLIENT_LONG_PASSWORD, CLIENT_LONG_FLAG,
    CLIENT_CONNECT_WITH_DB, CLIENT_PROTOCOL_41,
    CLIENT_TRANSACTIONS, CLIENT_SECURE_CONNECTION)


local UTF8_CHARSET         = "utf8"
local UTF8_COLLATION_ID    = 33
local UTF8_COLLATION_NAME  = "utf8_general_ci"

local SERVER_STATUS_AUTOCOMMIT           uint16 = 0x0002