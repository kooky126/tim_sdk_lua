# tim_sdk_lua
tencent im server sdk by lua

腾讯即时通信 IM（ https://cloud.tencent.com/document/product/269 ）服务端sdk基本功能的lua实现

需要用到resty.hmac、zlib、resty.http，注意设置nginx的 lua_package_path和lua_package_cpath

luarocks install lua-zlib --tree=/usr/local/webserver/lualib

opm --install-dir /usr/local/webserver install anjia0532/lua-resty-redis-util

opm --install-dir /usr/local/webserver install ledgetech/lua-resty-http

注意修改 __sdkappid，__key 到你控制台的对应数据

基本使用

local timsdk = require 'tim_server_sdk'

--计算sig

timsdk.gensig('admin')

--调用服务端restapi

timsdk.restapi('v4/im_open_login_svc/account_check','{"CheckItem":[{"UserID":"admin"},{"UserID":"UserID_2"}]}')

