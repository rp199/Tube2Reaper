-- Dependency-free onset-envelope autocorrelation. Estimates constant tempo only.
local M = {}
local MIN_BPM, MAX_BPM = 50, 300
function M.round(value)
  value=tonumber(value)
  if not value then return nil end
  return math.floor(value+0.5)
end

function M.first_onset(envelope, rate)
  if #envelope < math.max(3, math.floor(rate * 0.1)) then return nil end
  local peak = 0
  for _, value in ipairs(envelope) do peak = math.max(peak, value) end
  if peak < 1e-8 then return nil end

  local sorted = {}
  for i, value in ipairs(envelope) do sorted[i] = value end
  table.sort(sorted)
  local floor = sorted[math.max(1, math.floor(#sorted * 0.5))]
  local threshold = math.max(peak * 0.12, floor * 6)
  for i, value in ipairs(envelope) do
    if value >= threshold then return (i - 1) / rate end
  end
end

function M.alignment_shift(onset, bpm)
  onset, bpm = tonumber(onset), tonumber(bpm)
  if not onset or not bpm or onset < 0 or bpm <= 0 then return nil end
  local beat = 60 / bpm
  local remainder = onset % beat
  if remainder < 0.03 or beat - remainder < 0.03 then return 0 end
  return beat - remainder
end

local function estimate_once(envelope, rate)
  if #envelope < rate * 4 then return nil end
  -- Smooth narrow transients so fractional frame periods do not favor subharmonics.
  local smooth = {}
  for i=1,#envelope do
    smooth[i] = ((envelope[i-2] or 0) + 2*(envelope[i-1] or 0) +
      3*envelope[i] + 2*(envelope[i+1] or 0) + (envelope[i+2] or 0))/9
  end
  envelope = smooth
  local mean, power = 0, 0
  for _, v in ipairs(envelope) do mean = mean + v end
  mean = mean / #envelope
  local x = {}
  for i, v in ipairs(envelope) do x[i] = v - mean; power = power + x[i]^2 end
  if power < 1e-10 then return nil end
  local scores, best, bestlag = {}, -math.huge, nil
  for lag = math.floor(rate * 60 / MAX_BPM), math.ceil(rate * 60 / MIN_BPM) do
    local cross, a, b = 0, 0, 0
    for i = lag + 1, #x do
      cross = cross + x[i] * x[i-lag]
      a = a + x[i]^2; b = b + x[i-lag]^2
    end
    local score = cross / math.sqrt(math.max(a*b, 1e-20))
    scores[lag] = score
    local ranked = score
    if ranked > best then best, bestlag = ranked, lag end
  end
  -- Prefer the first comparable local peak over repeated two/three-beat periods.
  for lag=math.floor(rate*60/MAX_BPM), math.ceil(rate*60/MIN_BPM) do
    if scores[lag] >= best-0.06 and scores[lag] >= (scores[lag-1] or -1) and
      scores[lag] >= (scores[lag+1] or -1) then bestlag=lag; break end
  end
  if not bestlag or scores[bestlag] < 0.12 then return nil end
  local l, c, r = scores[bestlag-1], scores[bestlag], scores[bestlag+1]
  local offset = 0
  if l and r and math.abs(l-2*c+r) > 1e-9 then
    offset = math.max(-0.5, math.min(0.5, 0.5*(l-r)/(l-2*c+r)))
  end
  return 60*rate/(bestlag+offset), c
end

function M.estimate(envelope, rate)
  local window = math.floor(rate * 30)
  if #envelope <= math.floor(rate * 45) then return estimate_once(envelope,rate) end

  local hop = math.floor(window / 2)
  local best_bpm, best_confidence = nil, -math.huge
  local first = 1
  while first + window - 1 <= #envelope do
    local segment = {}
    for i = first, first + window - 1 do segment[#segment+1] = envelope[i] end
    local bpm, confidence = estimate_once(segment,rate)
    if confidence and confidence > best_confidence then
      best_bpm, best_confidence = bpm, confidence
    end
    first = first + hop
  end
  return best_bpm, best_confidence > -math.huge and best_confidence or nil
end
return M
