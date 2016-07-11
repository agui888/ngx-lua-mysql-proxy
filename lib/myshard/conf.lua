-- Copyright (C) 2016 HuangChuanTong@WPS.CN

local d = require("test.dumper")
local hash = require("hashfunc")
local stringx = require("pl.stringx")

local _M = {_VERSION = '1.0'}
local _Second = 1000

stringx.import()

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

Rules = {} -- class Rules
    -- default[write/read] must setting.
    Rules.default = {
      write = {"writer_1", "custom_name"}, -- MySQL可以配为MM模式时，即可双写
      read  = {"writer_1", "read_1"},
      hash = "wrr",
    }

    --- if db,tables is {} , mean no settings of partition of db and tables.
    --- `db`,`tables` can not be nil, must a table.
    --- 没在db与table配置中的库或表读写规则按default规则执行
    Rules.db = {}
    Rules.tables = {}

    Rules.db["mydb"] = { 
        default = {"writer_1"}, hash = "wrr"
    }  -- 表示mydb只能读写在writer_1 上

    Rules.db["db1"]  = { 
        write = {"writer_1"}, read = {"reader_1", "custom_name"}, 
        hash="wrr" -- 表示db1只能写在writer_1上,读在2个节点
    }
    Rules.db['db_partition'] = {
      partition = {
        { tables = {[[db_table_%d+]]}, 
          write = {"writer_1"}, 
          read = {"reader_1"}, 
          table_used_ngx_reg = true,   -- 表名使用正则，加速标识
          hash=nil
        },
        { tables = {"tb1", "tb2"}, 
          write = {"writer_1"}, 
          read = {"custom_name"}, 
          table_used_reg = false,
          hash=nil
         }
      } -- 分库功能
    }
    
    -- partition of tables
    Rules.tables['mydb.tb1'] = { read = {"reader_1", "custom_name"}, hash="wrr" }
    Rules.tables['mydb.tb2'] = { read = {"reader_1", "custom_name"}, hash=hash_mydb_tb2 } -- 可以配置为函数

    ------- class Rules member function -----
    function Rules.get_mysql(self, rule, mode)
      local h = rule.hash or "rand"
      local rule_mode = rule[mode] or rule.default
      if rule_mode == nil then
         print("no setings of DB rule", mode, "using default")
         rule_mode = Rules.default[mode]
      end

      local arr = {} 
      for _, node in ipairs(rule_mode) do
        local m = _M.MySQL_Node_List[node]
        if m then
           m['name'] = node
           table.insert(arr, m)
        end
      end
      assert(#arr >= 1, ("%sable node of MySQL must setting."):format(mode))
      return hash(h, arr)
    end
-- end class Rules

_M.Rules = Rules
------ end config -----

assert(_M.Rules == Rules)
assert(Rules.db['db1'] ~= nil)
------ 以下内容请不要修改 ------
local function _get_mysql(db, table, mode)
  db, table = db:strip('`'), table:strip('`')

  local tb = _M.Rules.tables[db .. "." .. table]
  if tb then
    return _.Rules:get_mysql(tb, mode)
  end

  local dbrule = _M.Rules.db[db]
  
  if nil == dbrule then
    -- return the default_mode
    -- print("dbrule was nil", db, table, mode)
    return Rules:get_mysql(Rules.default, mode)
  end

  if dbrule.partition then
    for _, part in ipairs(dbrule.partition) do
      for _, regex in ipairs(part.tables) do
        if part.table_used_ngx_reg then
--          local m = ngx.re.match(table, regex, "o")
          local m = table:match(regex)
          if nil ~= m then
            return Rules:get_mysql(part, mode)
          else
            -- print("TODO: regex not found?")
          end
        else
          if regex == table then
            return Rules:get_mysql(part, mode)
          end
        end
      end
    end -- for 
  end -- if dbrule.partition

  return Rules:get_mysql(dbrule, mode)

--  print("db empty db=",db, mode, "get default")
--  return Rules:get_mysql(Rules.default, mode)

end

function _M.get_mysql_write(self, db, table)
  return _get_mysql(db, table, 'write')
end

function _M.get_mysql_read(self, db, table)
    return _get_mysql(db, table, 'read')
end

if nil ~= ngx and (not ngx.config
   or not ngx.config.ngx_lua_version
   or ngx.config.ngx_lua_version < 9011)
then
    error("ngx_lua 0.9.11+ required")
end

return _M

