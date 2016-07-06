-- Copyright (C) 2016 HuangChuanTong@WPS.CN

local hash = require("hashfunc")

local _M = {_VERSION = '1.0'}
local _Second = 1000

-- constants
_M.REQ_TIMEOUT = 60 * _Second       -- 应该设大点
_M.BACKEN_TIMEOUT = 3600 * _Second  -- 

-- proxy权限控制，暂时只支持密码访问（不限IP）；对特定db读/写限制;
_M.Proxy_ACL = {
    {user='user1', passwd='mypass', db={"test", "test1", "*"}},
    {user='user2', passwd='mypass', db={"test", "test2"}, readOnly = true},
}

-- 可用mysql节点列表, key值为节点标识，可自定义，在_M.Rules中使用
_M.MySQL_Node_List = {
   custom_name = {host="127.0.0.1", port=3306, user="root", passwd="", charset="utf8", weigth = 70},
   writer_1 = {host="127.0.0.1", port=3306, user="root", passwd="", charset="utf8", weigth = 30},
   reader_1 = {host="localhost", port=3306, user="reader", passwd="readonly", charset="utf8", weigth = 100},
}


-- Rules的查找顺序是先从用 "库名.表名" 在Rules.table中找；
-- 若没有，侧用"库名"在Rules.db中找规则；
-- 若以上都没命中，则找default_[write/read]
-- hash: lrc,rand,wrr; 默认hash规则是wrr
_M.Rules = {
  default_write = {
    node = {"writer_1", "custom_name"}, -- MySQL可以配为MM模式时，即可双写
    hash = "wrr",
  },
  default_read = {
    node = {"writer_1", "read_1"},
    hash = "rand"
  },
}


-- 没在db与table配置中的库或表读写规则按default规则执行
_M.Rules.db = {
    mydb = { 
        default = {"writer_1"}, hash = 'wrr'
    },  -- 表示mydb只能读写在writer_1 上
    db1  = { 
        write = {"writer_1"}, read = {"reader_1", "custom_name"}, 
        hash='wrr' -- 表示db1只能写在writer_1上,读在2个节点
    }
} -- end db config

_M.Rules.db['db_partition'] = {
    partition = {
       {tables = {"a_\d[0:2]"}, write = {"writer_1"}, read = {"reader_1"}, table_used_reg = true, hash=nil},  -- 表名使用正则，加速
       {tables = {"tb1", "tb2"}, write = {"writer_1"}, read = {"custom_name"}, table_used_reg = false}
    } -- 分库功能
}


local function hash_mydb_tb2(where, filed)
    return 'writer_1'
end
-- 由于Lua语法初始化table时key不能带有.号，帮写在外面
-- mydb.tb1读在2个表上, 这里表名是tb1，库是mydb，table内的配置必需带库名
_M.Rules.tables = {}
_M.Rules.tables['mydb.tb1'] = { read = {"reader_1", "custom_name"}, hash='wrr' }
_M.Rules.tables['mydb.tb2'] = { read = {"reader_1", "custom_name"}, hash=hash_mydb_tb2 } -- 可以配置为函数

------ end config -----
--
------ 以下内容请不要修改 ------


function _M.get_mysql_write(db, table)
   local tb = _M.Rules.tables[table]
   if tb then
       if tb.hash then
           return hash(tb.hash, tb.write)
       else
           return hash('rand', tb.write)
       end
   end
   
   local db = _M.Rules.db[db]
   if db then
       if db.partition then
           for _, part in ipairs(db.partition) do
                if part.table_used_reg then
                   for _, tb in ipairs(part.tables) do
                        local res = string.gmatch(table, tb)
                        if res and #res == 1 and res[0][table] ~= nil then
                            return part.hash and hash(part.hash, part.write) or hash('rand', part.write)
                        end
                   end
                else
                   for _, tb in ipairs(part.tables) do
                       if tb == table then 
                          return part.hash and hash(part.hash, part.write) or hash('rand', part.write) 
                        end
                   end
                end
           end
       end
   end

end

function _M.get_mysql_read(db, table)
end
if nil ~= ngx and (not ngx.config
   or not ngx.config.ngx_lua_version
   or ngx.config.ngx_lua_version < 9011)
then
    error("ngx_lua 0.9.11+ required")
end


return _M

