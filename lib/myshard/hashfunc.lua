local os = require("os")
local math = require("math")
math.randomseed(os.time())

local function hash_rand(array)
    assert(nil ~= array and type(array) == "table", array)
    return array[math.random(1, #array)]
end

local function hash_wrr(array)
    local sum = 0
    for _, v in ipairs(array) do 
        sum = sum + v.weigth  
    end
    
    local n = math.random(1, sum)
    local tmp = 0
    for _, v in ipairs(array) do
        if n > tmp and n <= (tmp + v.weigth) then
            return v
        end
        tmp = tmp + v.weigth 
    end
    
    return _M.hash_rand(array)
end

local function hash_lrc(array)

end


local _hash_func = {
  wrr  = hash_wrr,
  rand = hash_rand,
  lrc  = hash_lrc
}
local function __call(self, name, arr)
    local func = _hash_func[name]
    if nil ~= func then
        return func(arr)
    else
        print(name, arr)
        return hash_rand(arr)
    end
end

local _M = {hash_wrr = hash_wrr, hash_rand = hash_rand, hash_lrc = hash_lrc}
local mt = {__index = _M, __call = __call}

return setmetatable({}, mt)
