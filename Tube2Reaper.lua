-- @description Tube2Reaper - search, import and prepare an audio session
-- @version 0.2.1
-- @author Tube2Reaper
local root = debug.getinfo(1, 'S').source:sub(2):match('^(.*)[/\\]')
local tempo = dofile(root..'/lua/tempo.lua')
local jobs = dofile(root..'/lua/jobs.lua')
local ui = dofile(root..'/lua/ui.lua')
local errors = dofile(root..'/lua/errors.lua')
local clipboard = dofile(root..'/lua/clipboard.lua')
local youtube = dofile(root..'/lua/youtube.lua')
local win = reaper.GetOS():match('Win') ~= nil
local suffix = win and '.exe' or ''
local state = {status='Search YouTube or choose a local audio file.', results={}}
state.tempo_mode = reaper.GetExtState('Tube2Reaper', 'tempo_mode')
if state.tempo_mode ~= 'review' and state.tempo_mode ~= 'skip' then state.tempo_mode='auto' end
local workspace = reaper.GetResourcePath()..'/Tube2Reaper'
local serial = 0
local function folder(kind)
  serial = serial + 1
  local p = workspace..'/'..kind..'/'..os.date('%Y%m%d-%H%M%S')..'-'..
    tostring(math.floor(reaper.time_precise()*1000000))..'-'..serial
  reaper.RecursiveCreateDirectory(p, 0); return p
end
local function tool(name)
  for _, p in ipairs({root..'/bin/'..name..suffix, root..'/.tools/bin/'..name..suffix,
    '/opt/homebrew/bin/'..name, '/usr/local/bin/'..name, '/usr/bin/'..name}) do
    if reaper.file_exists(p) then return p end
  end
end
local function message(s) reaper.MB(tostring(s), 'Tube2Reaper', 0) end
local function base_args()
  local yt = tool('yt-dlp')
  assert(yt, 'YouTube helper missing. See README.md for setup. Local audio works without helpers.')
  local args = {yt, '--ignore-config', '--no-playlist', '--no-colors', '--encoding', 'utf-8',
    '--socket-timeout', '20', '--retries', '2'}
  local deno = tool('deno'); if deno then
    args[#args+1]='--js-runtimes'; args[#args+1]='deno:'..deno
  end
  return args
end
local function start_job(args, callback)
  state.error=nil
  state.job = jobs.start(folder('jobs'), args); state.callback = callback
end
local function save_session()
  reaper.Main_SaveProjectEx(state.project, state.session..'/Tube2Reaper.rpp', 8)
  state.status = state.completion or 'Session saved. Ready to record.'
  state.analysis = nil
end
local function finish_analysis(bpm, confidence)
  reaper.DestroyAudioAccessor(state.accessor); state.accessor = nil
  bpm=tempo.round(bpm)
  if state.tempo_mode ~= 'review' then
    if bpm then
      reaper.SetCurrentBPM(state.project, bpm, false)
      state.completion=string.format('Session saved at %d BPM. Ready to record.', bpm)
    else
      state.completion='Session saved at 120 BPM. No reliable tempo detected; adjust it in REAPER.'
    end
    save_session(); return
  end
  local label = bpm and string.format('Estimated %d BPM (periodicity %.2f).', bpm, confidence) or
    'No reliable tempo found.'
  local ok, value = reaper.GetUserInputs('Confirm tempo — '..label, 1,
    'BPM (whole number; check half/double tempo):', bpm and tostring(bpm) or '120')
  local chosen = tempo.round(value)
  if ok and chosen and chosen >= 20 and chosen <= 400 then
    reaper.SetCurrentBPM(state.project, chosen, false)
    state.completion=string.format('Session saved at %d BPM. Ready to record.', chosen)
  else
    state.completion='Session saved at 120 BPM. Tempo review was skipped.'
  end
  save_session()
end
local function import_audio(path, title, session)
  state.error=nil
  state.completion=nil
  state.session = session or folder('sessions')
  -- Copy in chunks into the session, keeping projects independent of source files.
  local target = state.session..'/ImportedAudio.'..(path:match('%.([%w]+)$') or 'wav')
  if path ~= target then
    local src = assert(io.open(path, 'rb'), 'Cannot read audio')
    local dest = assert(io.open(target, 'wb'), 'Cannot create session audio')
    while true do local chunk=src:read(1024*1024); if not chunk then break end; assert(dest:write(chunk)) end
    src:close(); dest:close()
  end
  reaper.Main_OnCommand(40859, 0) -- New project tab, preserving existing projects.
  state.project = reaper.EnumProjects(-1, '')
  reaper.RecursiveCreateDirectory(state.session..'/Recordings', 0)
  reaper.GetSetProjectInfo_String(state.project, 'RECORD_PATH', 'Recordings', true)
  reaper.SetCurrentBPM(state.project, 120, false)
  reaper.SetEditCurPos(0, false, false)
  reaper.InsertMedia(target, 1)
  local item = reaper.GetSelectedMediaItem(state.project, 0)
  assert(item, 'REAPER could not import this audio format.')
  reaper.SetMediaItemInfo_Value(item, 'C_BEATATTACHMODE', 0)
  local take = reaper.GetActiveTake(item)
  assert(take and not reaper.TakeIsMIDI(take), 'Choose an audio file.')
  local track = reaper.GetMediaItemTrack(item)
  reaper.GetSetMediaTrackInfo_String(track, 'P_NAME', title or 'Imported audio', true)
  reaper.InsertTrackAtIndex(reaper.CountTracks(state.project), true)
  local recording = reaper.GetTrack(state.project, reaper.CountTracks(state.project)-1)
  reaper.GetSetMediaTrackInfo_String(recording, 'P_NAME', 'Recording', true)
  reaper.SetOnlyTrackSelected(recording)
  reaper.TrackList_AdjustWindows(false); reaper.UpdateArrange()
  if state.tempo_mode == 'skip' then
    state.completion='Session saved at 120 BPM. Tempo detection is off.'
    save_session(); return
  end
  state.accessor = assert(reaper.CreateTakeAudioAccessor(take), 'Cannot access audio samples')
  local start = reaper.GetAudioAccessorStartTime(state.accessor)
  state.analysis = {position=start, finish=math.min(start+90,
    reaper.GetAudioAccessorEndTime(state.accessor)), envelope={}, previous=0, buffer=reaper.new_array(22000)}
  state.status = 'Analyzing tempo (first 90 seconds)…'
end
local function analysis_step()
  local a = state.analysis
  if reaper.EnumProjects(-1, '') ~= state.project then
    state.status = 'Select the new Tube2Reaper project tab to continue analysis.'; return
  end
  if a.position >= a.finish then
    local bpm, confidence = tempo.estimate(a.envelope, 100)
    finish_analysis(bpm, confidence); return
  end
  local frames = math.min(22000, math.floor((a.finish-a.position)*22000))
  if frames < 220 then a.position=a.finish; return end
  local got = reaper.GetAudioAccessorSamples(state.accessor, 22000, 1, a.position, frames, a.buffer)
  assert(got >= 0, 'Audio sample read failed')
  local samples = a.buffer.table(1, frames)
  for start=1,frames-219,220 do
    local energy=0
    for i=start,start+219 do energy=energy+samples[i]^2 end
    energy=math.sqrt(energy/220)
    a.envelope[#a.envelope+1]=math.max(0, energy-a.previous)
    a.previous=energy
  end
  a.position=a.position+frames/22000
  state.status=string.format('Analyzing tempo: %.0f / %.0f seconds', a.position, a.finish)
end
local function search()
  local query=(state.query or ''):match('^%s*(.-)%s*$')
  if query=='' then return end
  local args=base_args()
  for _,v in ipairs({'--flat-playlist', '--skip-download', '--print',
    '%(id)s\t%(duration)s\t%(title)s', '--', youtube.target(query)}) do args[#args+1]=v end
  state.results={}; state.status=youtube.is_url(query) and 'Loading YouTube video…' or 'Searching YouTube…'
  start_job(args, function(output)
    for line in output:gmatch('[^\r\n]+') do
      local id, duration, title=line:match('^([%w_-]+)\t([^\t]+)\t(.*)$')
      if id then state.results[#state.results+1]={id=id,title=title,duration=duration} end
    end
    state.status=#state.results..' results. Click a song to download and create its session.'
  end)
end
local function open_youtube(result)
  local response=reaper.ExecProcess(youtube.open_command(reaper.GetOS(),result.id),5000)
  local code=response and tonumber(response:match('^(-?%d+)'))
  assert(code==0,'Could not open the browser for this video.')
  state.status='Opened video in your browser.'
end
local function download(result)
  local args=base_args(); local session=folder('sessions')
  local ffmpeg=tool('ffmpeg')
  assert(ffmpeg, 'FFmpeg missing. See README.md for YouTube helper setup.')
  for _,v in ipairs({'--ffmpeg-location', ffmpeg, '-f', 'bestaudio/best', '-x',
    '--audio-format', 'wav', '--no-progress', '-o', session..'/ImportedAudio.%(ext)s',
    '--', 'https://www.youtube.com/watch?v='..result.id}) do args[#args+1]=v end
  state.status='Downloading '..result.title..'…'
  start_job(args, function() import_audio(session..'/ImportedAudio.wav', result.title, session) end)
end
local function local_file()
  local ok,path=reaper.GetUserFileNameForRead('', 'Choose an audio file', '')
  if ok then import_audio(path, path:match('[^/\\]+$')) end
end
local function guarded(fn)
  local ok,err=xpcall(fn, debug.traceback)
  if not ok then
    if state.accessor then reaper.DestroyAudioAccessor(state.accessor); state.accessor=nil end
    state.analysis=nil; state.job=nil; state.status='Operation failed. See error details.'
    message(err)
  end
end
gfx.init('Tube2Reaper', 820, 700)
local function loop()
  local key=gfx.getchar()
  if key<0 then return end
  for _=1,64 do
    if key<=0 then break end
    if not state.job and not state.analysis then
      ui.handle_key(state,key,{
        search=function() guarded(search) end,
        local_file=function() guarded(local_file) end,
        paste=clipboard.paste,
        copy=function(value) return clipboard.copy(value,workspace) end,
      })
    end
    key=gfx.getchar()
  end
  guarded(function()
    if state.job then
      local code,output,err=jobs.poll(state.job)
      if code then
        local callback,job=state.callback,state.job; state.job=nil;state.callback=nil
        if code~=0 then
          state.error=errors.download(err)
          state.error.details=err~='' and err or ('Helper exit code: '..code)
          state.error.log=job.err
          state.status='Request failed. Choose another result or use local audio.'
        else callback(output) end
      elseif reaper.time_precise()-state.job.started>600 then
        state.job=nil; error('Timed out waiting for helper. It may still be running; logs are in '..workspace..'/jobs')
      end
    elseif state.analysis then analysis_step() end
  end)
  ui.draw(state, {
    search=function() guarded(search) end,
    local_file=function() guarded(local_file) end,
    dismiss_error=function() state.error=nil end,
    error_details=function()
      if state.error then
        reaper.ShowConsoleMsg('\nTube2Reaper — '..state.error.title..'\nLog: '..
          state.error.log..'\n'..state.error.details..'\n')
      end
    end,
    download=function(result) guarded(function() download(result) end) end,
    open=function(result) guarded(function() open_youtube(result) end) end,
    mode=function(mode)
      state.tempo_mode=mode
      reaper.SetExtState('Tube2Reaper','tempo_mode',mode,true)
    end,
  })
  gfx.update(); reaper.defer(loop)
end
reaper.atexit(function() if state.accessor then reaper.DestroyAudioAccessor(state.accessor) end end)
loop()
