local Audio = {}
local recordingDevice = nil
local audioEnergy = 0

function Audio.init()
    local devices = love.audio.getRecordingDevices()
    if #devices > 0 then
        -- Smart Detection: 优先寻找虚拟音频线或立体声混音
        for i, dev in ipairs(devices) do
            local name = string.lower(dev:getName())
            if string.find(name, "cable output") or string.find(name, "stereo mix") or string.find(name, "立体声混音") then
                recordingDevice = dev
                break
            end
        end
        
        -- Fallback: 默认麦克风
        if not recordingDevice then
            recordingDevice = devices[1]
        end

        local success, err = pcall(function()
            recordingDevice:start(8192, 44100, 16, 1)
        end)
        
        if success then
            print("Audio recording started: " .. recordingDevice:getName())
        else
            print("Failed to start audio recording: ", err)
        end
    else
        print("No recording devices found. Audio reactivity disabled.")
    end
end

function Audio.update()
    -- 平滑衰减音频能量
    audioEnergy = audioEnergy * 0.85
    
    if recordingDevice then
        local data = recordingDevice:getData()
        if data then
            local sampleCount = data:getSampleCount()
            if sampleCount > 0 then
                local sum = 0
                -- 计算这段采样中的绝对值之和（基础能量提取法）
                for i = 0, sampleCount - 1 do
                    local sample = data:getSample(i)
                    sum = sum + math.abs(sample)
                end
                local avg = sum / sampleCount
                -- 如果瞬时能量超过衰减后的能量，突变拉高
                if avg > audioEnergy then
                    audioEnergy = avg * 2.5
                end
            end
        end
    end
end

function Audio.getEnergy()
    -- 输出平滑后的强度因子(通常在0.0~0.5内跳动)
    return math.min(1.0, audioEnergy)
end

return Audio
