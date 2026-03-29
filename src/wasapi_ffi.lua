local ffi = require("ffi")

-- 定义 WASAPI Bridge C 接口 v1.05
ffi.cdef[[
    int wasapi_init();
    void wasapi_get_bands(float* l, float* m, float* h);
    void wasapi_get_format(int* channels, int* bits, int* rate);
    void wasapi_stop();
]]

local Wasapi = {}
local lib = nil

local function logToFile(msg)
    print(msg)
    local f = io.open("debug_log.txt", "a")
    if f then
        f:write(os.date("[%H:%M:%S] ") .. msg .. "\n")
        f:close()
    end
end

function Wasapi.init()
    logToFile("[WASAPI] (v1.05) Attempting to load wasapi_bridge.dll...")
    
    local ok, res = pcall(ffi.load, "wasapi_bridge.dll")
    if not ok then
        logToFile("[WASAPI] DLL Loading failed: " .. tostring(res))
        return false
    end
    
    lib = res
    logToFile("[WASAPI] DLL Linked Successfully. Initializing Endpoint...")
    
    local init_ok = lib.wasapi_init()
    if init_ok == 1 then
        -- 读取并记录硬件格式
        local chan = ffi.new("int[1]")
        local bits = ffi.new("int[1]")
        local rate = ffi.new("int[1]")
        lib.wasapi_get_format(chan, bits, rate)
        
        logToFile(string.format("[WASAPI] HW FORMAT DETECTED: %d channels, %d bits, %d Hz", 
                  chan[0], bits[0], rate[0]))
        logToFile("[WASAPI] SUCCESS: Native Hardware Engine is Running.")
        return true
    else
        logToFile("[WASAPI] FAILED: Driver init returned 0. Audio endpoint activation error.")
        return false
    end
end

function Wasapi.getBands()
    if not lib then return 0, 0, 0 end
    local l, m, h = ffi.new("float[1]"), ffi.new("float[1]"), ffi.new("float[1]")
    lib.wasapi_get_bands(l, m, h)
    return l[0], m[0], h[0]
end

function Wasapi.stop()
    if lib then lib.wasapi_stop() end
end

return Wasapi
