-- Copyright (C) 2016 HuangChuanTong@WPS.CN
--
-- ngx.req tcp connecttion from client side
-- Conn 是一个类，此处使用语法糖方式定义一个lua的class，本文件定义一个全局的metatable _M
-- 以`conn_`开头的文件，都是对类的方法扩展。

-- 
local _M = {_VERSION = '0.1'}
local mt = { __index = _M }

-- @param: conn_id number
-- @return: a new Conn{} class instance, and error string
function _M.New(conn_id, timeout)
    local sock = ngx.req.socket(true)
    if not sock then
        ngx.log(ngx.ERR, "ngx.req.socket() err=", err)
        return nil, err
    end

    sock:settimeout(timeout)
    local self = {
        name="proxy-mysql-ngx", -- for debug log
        sock=sock, 
        charset=charset.UTF8_CHARSET,
        user="",
        db="",
        packet_no=-1,
        state=const.SERVER_STATUS_AUTOCOMMIT,
        salt=utils.rand_str(20),
        connection_id = conn_id,
        last_insert_id=0,
        affected_rows=0,
        auto_commit=true,
        max_packet_size = 16 * 1024 * 1024 -- default 16 MB
    }
    return setmetatable(self, mt)
end

return _M