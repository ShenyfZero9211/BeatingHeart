local Audio = {}
local recordingDevice = nil

-- 3-Band 能量积分器
local energyLow = 0
local energyMid = 0
local energyHigh = 0

-- IIR 滤波器状态
local lpLow = 0 -- 低通滤波器 (用于 Kick)
local lpHigh = 0 -- 高通辅助滤波器 (用于隔离 Hat)

function Audio.init()
    local devices = love.audio.getRecordingDevices()
    if #devices > 0 then
        -- 优先寻找虚拟音频线或立体声混音
        for i, dev in ipairs(devices) do
            local name = string.lower(dev:getName())
            if string.find(name, "cable output") or string.find(name, "stereo mix") or string.find(name, "立体声混音") then
                recordingDevice = dev
                break
            end
        end
        if not recordingDevice then recordingDevice = devices[1] end

        local success, err = pcall(function()
            recordingDevice:start(8192, 44100, 16, 1)
        end)
        
        if success then
            print("Audio recording started: " .. recordingDevice:getName())
        else
            print("Failed to start audio recording: ", err)
        end
    end
end

function Audio.update()
    -- 平滑衰减各频段能量 (Release 速度)
    energyLow = energyLow * 0.88
    energyMid = energyMid * 0.82
    energyHigh = energyHigh * 0.75
    
    if recordingDevice then
        local data = recordingDevice:getData()
        if data then
            local sampleCount = data:getSampleCount()
            if sampleCount > 0 then
                local sumL, sumM, sumH = 0, 0, 0
                
                -- 实时 3-Band 数字滤波处理
                -- 利用 LuaJIT 局部变量加速循环
                local samples = data
                local count = sampleCount
                local curLow = lpLow
                local curHigh = lpHigh
                
                for i = 0, count - 1 do
                    local s = samples:getSample(i)
                    local absS = math.abs(s)
                    
                    -- 1. 低频提取 (Kick/Bass) - ~150Hz Cutoff
                    curLow = curLow + 0.02 * (s - curLow)
                    sumL = sumL + math.abs(curLow)
                    
                    -- 2. 高频提取 (Hat/Cymbals) - ~3000Hz+ Cutoff 
                    curHigh = curHigh + 0.4 * (s - curHigh)
                    local h = s - curHigh
                    sumH = sumH + math.abs(h)
                    
                    -- 3. 中频提取 (Snare/Vocals) - 差值法提取中间频带
                    local m = curHigh - curLow
                    sumM = sumM + math.abs(m)
                end
                
                lpLow = curLow
                lpHigh = curHigh
                
                local avgL = sumL / count
                local avgM = sumM / count
                local avgH = (sumH / count) * 1.5 -- 补偿高频由于振幅较小导致的能量偏低
                
                -- 峰值捕捉 (Attack 逻辑)
                if avgL > energyLow then energyLow = avgL * 4.0 end
                if avgM > energyMid then energyMid = avgM * 5.0 end
                if avgH > energyHigh then energyHigh = avgH * 6.0 end
            end
        end
    end
end

function Audio.getBands()
    return math.min(1.0, energyLow), math.min(1.0, energyMid), math.min(1.0, energyHigh)
end

function Audio.getEnergy()
    -- 兼容性旧接口，返回加权后的总能量
    return math.min(1.0, energyLow * 0.8 + energyMid * 0.2)
end

return Audio
