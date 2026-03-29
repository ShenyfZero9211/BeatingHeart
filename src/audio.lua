local Audio = {}

local recordingDevice = nil
local sampleRate = 44100
local bufferSize = 4096 -- 足够采集瞬时包络即可
local queueSize = 10 -- 缓冲区队列深度
local fftBuffer = nil

-- 多模态引擎状态
local Wasapi = nil
local nativeMode = false

-- 频带分析结果 (0.0 - 1.0)
local lowBand = 0
local midBand = 0
local hiBand = 0
local beatPulse = 0

function Audio.init()
    -- [Path B1] 尝试加载原生 WASAPI 驱动
    local success, res = pcall(require, "src.wasapi_ffi")
    if success then
        Wasapi = res
        if Wasapi.init() then
            nativeMode = true
            print("[AUDIO] Native Hardware-Loopback Mode Engaged.")
            return
        end
    end

    -- [Fallback] 降级至 OpenAL 方案
    local devices = love.audio.getRecordingDevices()
    if #devices > 0 then
        for i, dev in ipairs(devices) do
            local name = string.lower(dev:getName())
            if string.find(name, "cable output") or string.find(name, "stereo mix") or string.find(name, "立体声混音") then
                recordingDevice = dev
                break
            end
        end
        
        if not recordingDevice then recordingDevice = devices[1] end
        
        local ok = recordingDevice:start(sampleRate, bufferSize, 16)
        if ok then
            print("[AUDIO] OpenAL Fallback: Capturing from " .. recordingDevice:getName())
        end
    else
        print("[AUDIO] CRITICAL: No audio capture devices found.")
    end
end

function Audio.update(dt)
    if nativeMode then
        -- [Path B1] 从 C 驱动直接读取分频数据
        local l, m, h = Wasapi.getBands()
        lowBand = l
        midBand = m
        hiBand = h
        
        -- 在 Native 模式下，节拍响应完全同步
        beatPulse = math.max(0, beatPulse - dt * 2.5) -- 自然平滑
        if lowBand > 0.65 then beatPulse = math.min(1.0, beatPulse + lowBand * 0.4) end
        return
    end

    -- [Fallback] 传统的 OpenAL 基于时域能量的简单分析
    if not recordingDevice then return end
    
    local data = recordingDevice:getData()
    if data then
        local count = data:getSampleCount()
        if count > 0 then
            local lAcc, mAcc, hAcc = 0, 0, 0
            
            -- 使用非均匀步进抽样计算 RMS 粗略代表能量
            for i = 0, count - 1, 4 do
                local sample = math.abs(data:getSample(i))
                lAcc = lAcc + sample
            end
            
            local avg = lAcc / (count / 4)
            lowBand = lowBand * 0.8 + avg * 0.2
            midBand = midBand * 0.8 + avg * 0.15
            hiBand = hiBand * 0.8 + avg * 0.1
            
            -- 瞬阶检测 (Beat Pulse)
            if avg > 0.08 then
                beatPulse = math.min(1, beatPulse + 0.3)
            else
                beatPulse = math.max(0, beatPulse - dt * 4)
            end
        end
    end
end

function Audio.getBands()
    return lowBand, midBand, hiBand
end

function Audio.getBeatPulse()
    return beatPulse
end

function Audio.stop()
    if nativeMode then
        Wasapi.stop()
    elseif recordingDevice then
        recordingDevice:stop()
    end
end

return Audio
