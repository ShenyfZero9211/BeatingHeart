local Audio = {}
local recordingDevice = nil
local audioEnergy = 0

function Audio.init()
    local devices = love.audio.getRecordingDevices()
    if #devices > 0 then
        -- 尝试使用默认设备录制
        recordingDevice = devices[1]
        -- LÖVE Audio API: RecordingDevice:start(samplecount, samplerate, bitdepth, channels)
        local success = recordingDevice:start(1024, 8000, 16, 1)
        print("Audio recording device started:", success)
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
