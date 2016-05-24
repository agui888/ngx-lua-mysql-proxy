-- Copyright (C) 2016 HuangChuanTong@WPS.CN
--
-- MySQL proto or the command define


local _M = {_VERSION = '1.0'}
local mt = { __index = _M }

_M.COM_SLEEP = 0x00           -- （内部线程状态） （无）
_M.COM_QUIT = 0x01            -- 关闭连接 mysql_close
_M.COM_INIT_DB = 0x02         -- 切换数据库 mysql_select_db
_M.COM_QUERY = 0x03           -- SQL查询请求 mysql_real_query
_M.COM_FIELD_LIST = 0x04      -- 获取数据表字段信息 mysql_list_fields
_M.COM_CREATE_DB = 0x05       -- 创建数据库 mysql_create_db
_M.COM_DROP_DB = 0x06         -- 删除数据库 mysql_drop_db
_M.COM_REFRESH = 0x07         -- 清除缓存 mysql_refresh
_M.COM_SHUTDOWN = 0x08        -- 停止服务器 mysql_shutdown
_M.COM_STATISTICS = 0x09      -- 获取服务器统计信息 mysql_stat
_M.COM_PROCESS_INFO = 0x0A    -- 获取当前连接的列表 mysql_list_processes
_M.COM_CONNECT = 0x0B         -- （内部线程状态） （无）
_M.COM_PROCESS_KILL = 0x0C    -- 中断某个连接 mysql_kill
_M.COM_DEBUG = 0x0D           -- 保存服务器调试信息 mysql_dump_debug_info
_M.COM_PING = 0x0E            -- 测试连通性 mysql_ping
_M.COM_TIME = 0x0F            -- （内部线程状态） （无）
_M.COM_DELAYED_INSERT = 0x10  -- （内部线程状态） （无）
_M.COM_CHANGE_USER = 0x11     -- 重新登陆（不断连接） mysql_change_user
_M.COM_BINLOG_DUMP = 0x12     -- 获取二进制日志信息 （无）
_M.COM_TABLE_DUMP = 0x13      -- 获取数据表结构信息 （无）
_M.COM_CONNECT_OUT = 0x14     -- （内部线程状态） （无）
_M.COM_REGISTER_SLAVE = 0x15  -- 从服务器向主服务器进行注册 （无）
_M.COM_STMT_PREPARE = 0x16    -- 预处理SQL语句 mysql_stmt_prepare
_M.COM_STMT_EXECUTE = 0x17    -- 执行预处理语句 mysql_stmt_execute
_M.COM_STMT_SEND_LONG_DATA = 0x18         -- 发送BLOB类型的数据 mysql_stmt_send_long_data
_M.COM_STMT_CLOSE = 0x19      -- 销毁预处理语句 mysql_stmt_close
_M.COM_STMT_RESET = 0x1A      -- 清除预处理语句参数缓存 mysql_stmt_reset
_M.COM_SET_OPTION = 0x1B      -- 设置语句选项 mysql_set_server_option
_M.COM_STMT_FETCH = 0x1C      -- 获取预处理语句的执行结果 mysql_stmt_fetch

_M.name = {}
_M.name[0x00] = COM_SLEEP
_M.name[0x01] = COM_QUIT
_M.name[0x02] = COM_INIT_DB
_M.name[0x03] = COM_QUERY
_M.name[0x04] = COM_FIELD_LIST
_M.name[0x05] = COM_CREATE_DB
_M.name[0x06] = COM_DROP_DB
_M.name[0x07] = COM_REFRESH
_M.name[0x08] = COM_SHUTDOWN
_M.name[0x09] = COM_STATISTICS
_M.name[0x0A] = COM_PROCESS_INFO
_M.name[0x0B] = COM_CONNECT
_M.name[0x0C] = COM_PROCESS_KILL
_M.name[0x0D] = COM_DEBUG
_M.name[0x0E] = COM_PING
_M.name[0x0F] = COM_TIME
_M.name[0x10] = COM_DELAYED_INSERT
_M.name[0x11] = COM_CHANGE_USER
_M.name[0x12] = COM_BINLOG_DUMP
_M.name[0x13] = COM_TABLE_DUMP
_M.name[0x14] = COM_CONNECT_OUT
_M.name[0x15] = COM_REGISTER_SLAVE
_M.name[0x16] = COM_STMT_PREPARE
_M.name[0x17] = COM_STMT_EXECUTE
_M.name[0x18] = COM_STMT_SEND_LONG_DATA
_M.name[0x19] = COM_STMT_CLOSE
_M.name[0x1A] = COM_STMT_RESET
_M.name[0x1B] = COM_SET_OPTION
_M.name[0x1C] = COM_STMT_FETCH

return _M
