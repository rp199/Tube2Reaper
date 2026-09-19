-- Runs inside REAPER and exercises the real project/session APIs.
local script=debug.getinfo(1,'S').source:sub(2)
local root=assert(script:match('^(.*)[/\\]tests[/\\][^/\\]+$'),'Cannot find repository root')
local module_root=os.getenv('TUBE2REAPER_MODULE_ROOT') or root
local session=dofile(module_root..'/lua/session.lua')
local work=assert(os.getenv('TUBE2REAPER_CI_ROOT'),'TUBE2REAPER_CI_ROOT is required')
local result_path=assert(os.getenv('TUBE2REAPER_CI_RESULT'),'TUBE2REAPER_CI_RESULT is required')

local function write_result(message)
  local file=assert(io.open(result_path,'wb'))
  file:write(message,'\n')
  file:close()
end

local function write_fixture(path)
  local sample_rate,seconds=44100,2
  local samples=sample_rate*seconds
  local data_size=samples*2
  local file=assert(io.open(path,'wb'))
  file:write(string.pack('<c4I4c4c4I4I2I2I4I4I2I2c4I4',
    'RIFF',36+data_size,'WAVE','fmt ',16,1,1,sample_rate,
    sample_rate*2,2,16,'data',data_size))
  local chunk={}
  for i=0,samples-1 do
    local value=math.floor(math.sin(2*math.pi*440*i/sample_rate)*8000)
    chunk[#chunk+1]=string.pack('<i2',value)
    if #chunk==4096 then file:write(table.concat(chunk));chunk={} end
  end
  if #chunk>0 then file:write(table.concat(chunk)) end
  file:close()
end

local function assert_equal(actual,expected,label)
  assert(actual==expected,string.format('%s: expected %s, got %s',label,tostring(expected),tostring(actual)))
end

local function run()
  reaper.RecursiveCreateDirectory(work,0)
  local fixture=work..'/source-fixture.wav'
  local directory=work..'/session'
  write_fixture(fixture)

  local created=session.create(reaper,fixture,'CI Fixture',directory)
  assert_equal(reaper.EnumProjects(-1,''),created.project,'active project')
  assert_equal(reaper.CountTracks(created.project),2,'track count')
  assert_equal(select(2,reaper.GetSetMediaTrackInfo_String(
    reaper.GetTrack(created.project,0),'P_NAME','',false)),'CI Fixture','imported track name')
  assert_equal(select(2,reaper.GetSetMediaTrackInfo_String(
    reaper.GetTrack(created.project,1),'P_NAME','',false)),'Recording','recording track name')
  assert_equal(reaper.CountMediaItems(created.project),1,'media item count')
  assert_equal(reaper.GetMediaItemInfo_Value(created.item,'C_BEATATTACHMODE'),0,'item timebase')
  assert_equal(select(2,reaper.GetSetProjectInfo_String(
    created.project,'RECORD_PATH','',false)),'Recordings','recording path')
  assert_equal(math.floor(reaper.Master_GetTempo()+0.5),120,'project tempo')
  assert(reaper.file_exists(created.target),'session audio was not copied')

  local project_path=session.save(reaper,created.project,directory)
  assert(reaper.file_exists(project_path),'project was not saved')
  local project_file=assert(io.open(project_path,'rb'))
  local project_text=project_file:read('*a')
  project_file:close()
  assert(project_text:find('ImportedAudio.wav',1,true),'saved project does not reference session audio')
  assert(not project_text:find('source-fixture.wav',1,true),'saved project references the original fixture')
  local recordings=io.open(directory..'/Recordings/.tube2reaper-ci','wb')
  assert(recordings,'recording directory was not created')
  recordings:close()
  os.remove(directory..'/Recordings/.tube2reaper-ci')
  write_result('PASS '..project_path)
end

local ok,err=xpcall(run,debug.traceback)
if not ok then
  pcall(write_result,'FAIL '..tostring(err))
  reaper.ShowConsoleMsg('Tube2Reaper integration failure:\n'..tostring(err)..'\n')
end

-- Let REAPER finish its current script callback before closing the test instance.
reaper.defer(function() reaper.Main_OnCommand(40004,0) end)
