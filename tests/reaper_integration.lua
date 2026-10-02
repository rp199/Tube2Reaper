-- Runs inside REAPER and exercises the real project/session APIs.
local script=debug.getinfo(1,'S').source:sub(2)
local module_root=os.getenv('TUBE2REAPER_MODULE_ROOT')
if not module_root then
  module_root=assert(script:match('^(.*)[/\\]tests[/\\][^/\\]+$'),'Cannot find repository root')
end
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
  write_fixture(fixture)

  local project,project_path_before=reaper.EnumProjects(-1,'')
  reaper.SetCurrentBPM(project,137,false)
  reaper.SetEditCurPos(1.25,false,false)
  reaper.InsertTrackAtIndex(0,true)
  local existing=reaper.GetTrack(project,0)
  reaper.GetSetMediaTrackInfo_String(existing,'P_NAME','Existing track',true)
  local _,record_path_before=reaper.GetSetProjectInfo_String(project,'RECORD_PATH','',false)

  local created=session.add(reaper,fixture,'CI Fixture')
  assert_equal(reaper.EnumProjects(-1,''),created.project,'active project')
  assert_equal(select(2,reaper.EnumProjects(-1,'')),project_path_before,'project path')
  assert_equal(reaper.CountTracks(created.project),2,'track count')
  assert_equal(select(2,reaper.GetSetMediaTrackInfo_String(
    reaper.GetTrack(created.project,0),'P_NAME','',false)),'Existing track','existing track name')
  assert_equal(select(2,reaper.GetSetMediaTrackInfo_String(
    reaper.GetTrack(created.project,1),'P_NAME','',false)),'CI Fixture','imported track name')
  assert_equal(reaper.CountMediaItems(created.project),1,'media item count')
  assert_equal(reaper.GetMediaItemInfo_Value(created.item,'C_BEATATTACHMODE'),0,'item timebase')
  assert_equal(reaper.GetMediaItemInfo_Value(created.item,'D_POSITION'),1.25,'item position')
  assert_equal(math.floor(reaper.Master_GetTempo()+0.5),137,'unchanged project tempo')
  assert_equal(select(2,reaper.GetSetProjectInfo_String(
    created.project,'RECORD_PATH','',false)),record_path_before,'unchanged recording path')
  assert_equal(created.path,fixture,'original media path')
  write_result('PASS current-project import')
end

local ok,err=xpcall(run,debug.traceback)
if not ok then
  pcall(write_result,'FAIL '..tostring(err))
  reaper.ShowConsoleMsg('Tube2Reaper integration failure:\n'..tostring(err)..'\n')
end

-- Let REAPER finish its current script callback before closing the test instance.
reaper.defer(function() reaper.Main_OnCommand(40004,0) end)
