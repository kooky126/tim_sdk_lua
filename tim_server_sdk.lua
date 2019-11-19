--腾讯即时通信 IM（https://cloud.tencent.com/document/product/269）服务端sdk基本功能的lua实现
--by kooky126
--需要用到resty.hmac、zlib、resty.http，注意设置nginx的 lua_package_path和lua_package_cpath
--luarocks install lua-zlib --tree=/usr/local/webserver/lualib
--opm --install-dir /usr/local/webserver install anjia0532/lua-resty-redis-util
--opm --install-dir /usr/local/webserver install ledgetech/lua-resty-http
--基本使用
--local timsdk = require 'tim_server_sdk'
--计算sig
--timsdk.gensig('admin')
--调用服务端restapi
--timsdk.restapi('v4/im_open_login_svc/account_check','{"CheckItem":[{"UserID":"admin"},{"UserID":"UserID_2"}]}')

--注意修改 __sdkappid，__key 到你控制台的对应数据

local hmac = require "resty.hmac"
local cjson = require "cjson"
local zlib = require "zlib"
local http = require "resty.http"

local _M = {}
_M.__sdkappid = your appid
_M.__key = 'your key'
_M.__expire = 180 * 86400
_M.__version = '2.0'

function _M.hmac_sha256(s)
    local hmac_sha256 = hmac:new(_M.__key, hmac.ALGOS.SHA256)
    hmac_sha256:update(s)
    local digest = hmac_sha256:final()
    hmac_sha256:reset()
    return digest
end

function _M.hmacsha256(identifier, curr_time)
    local content_to_be_signed = "TLS.identifier:" .. identifier .. "\n" ..
                                     "TLS.sdkappid:" .. _M.__sdkappid .. "\n" ..
                                     "TLS.time:" .. curr_time .. "\n" ..
                                     "TLS.expire:" .. _M.__expire .. "\n"
    return ngx.encode_base64(_M.hmac_sha256(content_to_be_signed))
end

--生成 UserSig
--identifier为客户端省份
function _M.gensig(identifier)
    local now = ngx.time()
    local m = {}
    m["TLS.ver"] = _M.__version
    m["TLS.identifier"] = identifier
    m["TLS.sdkappid"] = _M.__sdkappid
    m["TLS.expire"] = _M.__expire
    m["TLS.time"] = now
    m["TLS.sig"] = _M.hmacsha256(identifier, now)
    local stream = zlib.deflate()
    local zstr = stream(cjson.encode(m), 'finish')
    local out = ngx.encode_base64(zstr)
    out = string.gsub(out, '+', '*')
    out = string.gsub(out, '/', '-')
    out = string.gsub(out, '=', '_')
    return out
end

--服务端restapi调用
--command为完整指令，含ver/servicename/command，如v4/im_open_login_svc/account_check
--body，内容块，json字串格式，如{"CheckItem":[{"UserID":"18971146490"},{"UserID":"UserID_2"}]}
function _M.restapi(command, body)
    local admin = 'administrator'
    local sig = _M.gensig(admin)
    local url = 'https://console.tim.qq.com/' .. command .. '?sdkappid=' ..
                    _M.__sdkappid .. '&identifier=' .. admin .. '&usersig=' ..
                    sig .. '&random=99999999&contenttype=json'
    local httpc = http.new()
    local resStr -- 响应结果  
    local res, err = httpc:request_uri(url, {
        ssl_verify = false,
        method = "POST",
        -- args = str,  
        body = body,
        headers = {["Content-Type"] = "application/json"}
    })

    if not res then
        ngx.log(ngx.WARN, "failed to request: ", err)
        return resStr
    end
    -- 请求之后，状态码  
    ngx.status = res.status
    if ngx.status ~= 200 then
        ngx.log(ngx.WARN, "非200状态，ngx.status:" .. ngx.status)
        return resStr
    end
    -- header中的信息遍历，只是为了方便看头部信息打的日志，用不到的话，可以不写的  
    for key, val in pairs(res.headers) do
        if type(val) == "table" then
            ngx.log(ngx.WARN, "table:" .. key, ": ", table.concat(val, ", "))
        else
            ngx.log(ngx.WARN, "one:" .. key, ": ", val)
        end
    end
    -- 响应的内容  
    resStr = res.body
    return cjson.decode(resStr)
end
return _M
