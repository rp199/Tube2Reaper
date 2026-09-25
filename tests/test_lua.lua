local tempo = dofile('lua/tempo.lua')
assert(tempo.round(120.0007)==120)
assert(tempo.round(120.5)==121)
assert(tempo.round('135.8')==136)
assert(tempo.round('invalid')==nil)
assert(tempo.estimate({}, 100) == nil)
local silence = {}; for i=1,6000 do silence[i]=0 end
assert(tempo.estimate(silence, 100) == nil)
assert(tempo.first_onset(silence,100)==nil)
local delayed={}
for i=1,300 do delayed[i]=i==126 and 1 or 0 end
assert(math.abs(tempo.first_onset(delayed,100)-1.25)<0.001)
assert(math.abs(tempo.alignment_shift(1.25,120)-0.25)<0.001)
assert(tempo.alignment_shift(1.501,120)==0)
for _, bpm in ipairs({60, 80, 100, 120, 150, 180, 200, 224, 260, 300}) do
  local envelope={}
  for i=1,6000 do
    local phase=((i-1)*bpm/6000)%1
    local distance=math.min(phase,1-phase)*6000/bpm
    envelope[i]=math.exp(-0.5*(distance/1.5)^2)
  end
  local estimated = assert(tempo.estimate(envelope,100))
  assert(math.abs(estimated-bpm)<2, string.format('%s BPM estimated as %s',bpm,estimated))
end
local changing={}
for i=1,9000 do
  if i<=3000 then
    local phase=((i-1)*224/6000)%1
    local distance=math.min(phase,1-phase)*6000/224
    changing[i]=math.exp(-0.5*(distance/1.5)^2)
  else
    changing[i]=0
  end
end
local windowed=assert(tempo.estimate(changing,100))
assert(math.abs(windowed-224)<2,'Strongest stable window should determine tempo')
reaper = {GetOS=function() return 'OSX64' end}
local jobs=dofile('lua/jobs.lua')
assert(jobs.quote("a'b") == "'a'\\''b'")
assert(jobs.quote('$(touch nope)') == "'$(touch nope)'")
assert(not pcall(jobs.quote, 'bad\nargument'))
print('Lua tests passed: tempo fixtures, onset alignment, silence, command argument escaping')
