local mysql = require "lib.mysql"


local c = mysql:new()

print("----------------connect to port=4000")
c:connect{
		host = "127.0.0.1",
		port = 4000,
		database = "test",
		user = "root",
		password = "myass"
}

print("----------------connect to port=1234 ")

c:connect{
		host = "127.0.0.1",
		port = 1234,
		database = "test",
		user = "root",
		password = "myass"
}
print("----------------connect to port=3306 ")

c:connect{
		host = "127.0.0.1",
		port = 3306,
		database = "test",
		user = "root",
		password = "myass"
}
