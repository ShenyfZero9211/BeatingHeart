local Audio = {}
local recordingDevice = nil

-- Sustain 能量积分器 (极度平滑，代表氛围)
local energyLow = 0
local energyMid = 0
local energyHigh = 0

-- Beat 脉冲 (瞬时触发，代表节奏)
local beatPulse = 0
local avgEnergyL = 0 -- 低频滑动平均，用于对比瞬态

-- IIR 滤波器状态
local lpLow = 0 
local lpHigh = 0 

function Audio.init()
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
        pcall(function() recordingDevice:start(8192, 44100, 16, 1) end)
    end
end

function Audio.update(dt)
    dt = dt or 0.016
    
    if recordingDevice then
        local data = recordingDevice:getData()
        if data then
            local sampleCount = data:getSampleCount()
            if sampleCount > 0 then
                local sumL, sumM, sumH = 0, 0, 0
                local samples = data
                local count = sampleCount
                local curLow = lpLow
                local curHigh = lpHigh
                
                for i = 0, count - 1 do
                    local s = samples:getSample(i)
                    curLow = curLow + 0.02 * (s - curLow)
                    sumL = sumL + math.abs(curLow)
                    curHigh = curHigh + 0.4 * (s - curHigh)
                    local h = s - curHigh
                    sumH = sumH + math.abs(h)
                    local m = curHigh - curLow
                    sumM = sumM + math.abs(m)
                end
                lpLow = curLow
                lpHigh = curHigh
                
                local rawL = (sumL / count) * 4.0
                local rawM = (sumM / count) * 5.0
                local rawH = (sumH / count) * 11.0
                
                -- 生理平滑：略微上调攻击速度（2.4），找回爆发力
                local attackSpeed = 2.4 
                if rawL > energyLow then
                    energyLow = energyLow + (rawL - energyLow) * attackSpeed * dt
                else
                    energyLow = energyLow * math.pow(0.85, dt * 60)
                end
                
                if rawM > energyMid then
                    energyMid = energyMid + (rawM - energyMid) * (attackSpeed * 0.8) * dt
                else
                    energyMid = energyMid * math.pow(0.82, dt * 60)
                end
                
                if rawH > energyHigh then
                    energyHigh = energyHigh + (rawH - energyHigh) * (attackSpeed * 1.2) * dt
                else
                    energyHigh = energyHigh * math.pow(0.75, dt * 60)
                end
                
                -- 2. Beat (瞬态脉冲) - 灵敏化节奏监控 (1.6 -> 1.35)
                avgEnergyL = avgEnergyL + (rawL - avgEnergyL) * 1.5 * dt
                if rawL > avgEnergyL * 1.35 and rawL > 0.06 then
                    beatPulse = 1.0
                end
            end
        end
    end

    -- 能量自然衰减与脉冲快速消退 (0.2s 左右衰减完毕)
    beatPulse = math.max(0, beatPulse - dt * 5.0)
    energyLow = energyLow * math.pow(0.92, dt * 60)
    energyMid = energyMid * math.pow(0.90, dt * 60)
    energyHigh = energyHigh * math.pow(0.85, dt * 60)
end

function Audio.getBands()
    return math.min(1.0, energyLow), math.min(1.0, energyMid), math.min(1.0, energyHigh)
end

function Audio.getBeatPulse()
    return beatPulse
end

return Audio
