-- Exercise the real controller with REAPER/audio/UI boundaries stubbed.
local real_dofile=dofile
for _,case in ipairs({
  {mode='auto',bpm=120.0007,expected=120,prompts=0,accessors=1},
  {mode='auto',expected=120,prompts=0,accessors=1},
  {mode='review',bpm=128,expected=135,prompts=1,accessors=1},
  {mode='skip',bpm=128,expected=120,prompts=0,accessors=0},
}) do
  local saved,prompts,accessors,bpm=0,0,0,nil
  local deferred, key=nil,108
  local noop=function() end
  reaper=setmetatable({
    GetOS=function() return 'OSX64' end,
    GetExtState=function() return case.mode end,
    GetResourcePath=function() return '/tmp/tube2reaper-test' end,
    time_precise=function() return 1 end,
    EnumProjects=function() return 1 end,
    GetUserFileNameForRead=function() return true,'test.wav' end,
    GetSelectedMediaItem=function() return 1 end,
    GetActiveTake=function() return 1 end,
    TakeIsMIDI=function() return false end,
    CountTracks=function() return 1 end,
    GetTrack=function() return 1 end,
    CreateTakeAudioAccessor=function() accessors=accessors+1; return 1 end,
    GetAudioAccessorStartTime=function() return 0 end,
    GetAudioAccessorEndTime=function() return 0 end,
    new_array=function() return {} end,
    SetCurrentBPM=function(_,value) bpm=value end,
    Main_SaveProjectEx=function() saved=saved+1 end,
    GetUserInputs=function() prompts=prompts+1; return true,'135' end,
    MB=function(err) error(err) end,
    defer=function(fn) deferred=fn end,
  },{__index=function() return noop end})
  gfx={init=noop, update=noop, getchar=function() local v=key;key=0;return v end}
  local original_open=io.open
  io.open=function() return {read=function() return nil end,write=function() return true end,close=noop} end
  dofile=function(path)
    if path:match('/tempo.lua$') then return {
      estimate=function() return case.bpm,0.9 end,
      round=function(value) value=tonumber(value);return value and math.floor(value+0.5) end,
    } end
    if path:match('/ui.lua$') then return {draw=noop,
      handle_key=function(_,key,actions) if key==108 then actions.local_file() end end} end
    return real_dofile(path)
  end
  local ok,err=pcall(real_dofile,'./Tube2Reaper.lua')
  io.open=original_open
  assert(ok,err)
  if deferred and saved==0 then deferred() end
  assert(saved==1,case.mode..': should save once')
  assert(prompts==case.prompts,case.mode..': wrong confirmation behavior')
  assert(accessors==case.accessors,case.mode..': wrong analysis behavior')
  assert(bpm==case.expected,case.mode..': wrong resulting tempo')
  dofile=real_dofile
end
print('Tempo modes passed: automatic, fallback, review, and analysis off')
