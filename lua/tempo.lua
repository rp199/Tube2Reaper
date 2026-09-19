-- Dependency-free onset-envelope autocorrelation. Estimates constant tempo only.
local M = {}
function M.round(value)
  value=tonumber(value)
  if not value then return nil end
  return math.floor(value+0.5)
end
function M.estimate(envelope, rate)
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
  for lag = math.floor(rate * 60 / 200), math.ceil(rate * 60 / 60) do
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
  for lag=math.floor(rate*60/200), math.ceil(rate*60/60) do
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
return M
