-- Helper Methods
function getCountry()
  local country = geodb:query_by_addr(ngx.var.remote_addr, "id")
  return geoip.code_by_id(country)
end

function normalizeKeys(tbl)
  local normalized = {}
  for k, v in pairs(tbl) do
    local key = k:gsub("amp;", "")
    key = key:gsub("[[]]", "")
    normalized[key] = v
  end
  return normalized
end

function emptyGif()
  ngx.exec('/_.gif')
end

function logErrorAndExit(err)
   ngx.log(ngx.ERR, err)
   emptyGif()
end

function initRedis()
  local redis = require "resty.redis"
  local red = redis:new()
  red:set_timeout(3000) -- 3 sec
  local ok, err = red:connect("127.0.0.1", 6379)
  if not ok then logErrorAndExit("Error connecting to redis: ".. err) end
  return red
end

---------------------
ngx.header["Cache-Control"] = "no-cache"
local args = normalizeKeys(ngx.req.get_query_args())
args["action"] = ngx.var.action
args["day"] = os.date("%d", ngx.req.start_time())
args["yday"] = os.date("%j", ngx.req.start_time())
args["week"] = os.date("%W",ngx.req.start_time())
args["month"] = os.date("%m", ngx.req.start_time())
args["year"] = os.date("%Y",ngx.req.start_time())
args["country"] = getCountry()
if args["week"] == "00" then
  args["week"] = "52"
  args["year"] = tostring( tonumber(args["year"]) - 1 )
end
local cjson = require "cjson"
local args_json = cjson.encode(args)
red = initRedis()

ok, err = red:evalsha(ngx.var.redis_counter_hash, 1, "args", args_json)
if not ok then logErrorAndExit("Error evaluating redis script: ".. err) end

ok, err = red:set_keepalive(10000, 100)
if not ok then ngx.log(ngx.ERR, "Error setting redis keep alive ".. err) end
emptyGif()
