package.cpath = package.cpath.. ";../?.lua"
require("busted")

conf = require ("conf")
dump = require("test.dumper")


describe("get MySQL asscess node", function ()
    it("test defalut access",function ()
        local res = conf:get_mysql_write("no-exist-db","no-exist-tb")
        res = conf:get_mysql_read("no-exist-db","no-exist-tb")
       
        res = conf:get_mysql_write("db1", "no-exist-tb")
        assert.are.is_true(res['name'] == "writer_1")

        res = conf:get_mysql_read("mydb", "no-exist-tb")
        assert.are.is_true(res['name'] == "writer_1")

        res = conf:get_mysql_read("db_partition", "tb1")
        assert.are.is_true(res['name'] == "custom_name")

        res = conf:get_mysql_write("db_partition", "tb2")
        assert.are.is_true(res['name'] == "writer_1")

        res = conf:get_mysql_read("db_partition", "db_table_111")
        assert.are.is_true(res['name'] == "reader_1")
        
    end)
end)

