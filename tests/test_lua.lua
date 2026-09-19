local tempo = dofile('lua/tempo.lua')
assert(tempo.round(120.0007)==120)
assert(tempo.round(120.5)==121)
assert(tempo.round('135.8')==136)
assert(tempo.round('invalid')==nil)
assert(tempo.estimate({}, 100) == nil)
local silence = {}; for i=1,6000 do silence[i]=0 end
assert(tempo.estimate(silence, 100) == nil)
for _, bpm in ipairs({80, 100, 120, 150, 180}) do
  local envelope={}
  for i=1,6000 do
    local phase=((i-1)*bpm/6000)%1
    local distance=math.min(phase,1-phase)*6000/bpm
    envelope[i]=math.exp(-0.5*(distance/1.5)^2)
  end
  local estimated = assert(tempo.estimate(envelope,100))
  assert(math.abs(estimated-bpm)<2, string.format('%s BPM estimated as %s',bpm,estimated))
end
reaper = {GetOS=function() return 'OSX64' end}
local jobs=dofile('lua/jobs.lua')
assert(jobs.quote("a'b") == "'a'\\''b'")
assert(jobs.quote('$(touch nope)') == "'$(touch nope)'")
assert(not pcall(jobs.quote, 'bad\nargument'))
print('Lua tests passed: tempo fixtures, silence, command argument escaping')
