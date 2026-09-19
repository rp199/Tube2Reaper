-- REAPER project/session creation shared by the UI and integration tests.
local M={}

local function copy_file(source,target)
  if source==target then return end
  local input=assert(io.open(source,'rb'),'Cannot read audio')
  local output=io.open(target,'wb')
  if not output then input:close(); error('Cannot create session audio') end
  while true do
    local chunk=input:read(1024*1024)
    if not chunk then break end
    assert(output:write(chunk))
  end
  input:close();output:close()
end

function M.create(r,path,title,directory)
  assert(type(path)=='string' and path~='','Audio path is required')
  assert(type(directory)=='string' and directory~='','Session directory is required')
  r.RecursiveCreateDirectory(directory,0)
  local extension=path:match('%.([%w]+)$') or 'wav'
  local target=directory..'/ImportedAudio.'..extension
  copy_file(path,target)

  r.Main_OnCommand(40859,0) -- New project tab, preserving existing projects.
  local project=r.EnumProjects(-1,'')
  r.RecursiveCreateDirectory(directory..'/Recordings',0)
  r.GetSetProjectInfo_String(project,'RECORD_PATH','Recordings',true)
  r.SetCurrentBPM(project,120,false)
  r.SetEditCurPos(0,false,false)
  r.InsertMedia(target,1)
  local item=assert(r.GetSelectedMediaItem(project,0),'REAPER could not import this audio format.')
  r.SetMediaItemInfo_Value(item,'C_BEATATTACHMODE',0)
  local take=r.GetActiveTake(item)
  assert(take and not r.TakeIsMIDI(take),'Choose an audio file.')
  local imported=r.GetMediaItemTrack(item)
  r.GetSetMediaTrackInfo_String(imported,'P_NAME',title or 'Imported audio',true)

  r.InsertTrackAtIndex(r.CountTracks(project),true)
  local recording=r.GetTrack(project,r.CountTracks(project)-1)
  r.GetSetMediaTrackInfo_String(recording,'P_NAME','Recording',true)
  r.SetOnlyTrackSelected(recording)
  r.TrackList_AdjustWindows(false)
  r.UpdateArrange()
  return {project=project,directory=directory,target=target,item=item,take=take,
    imported_track=imported,recording_track=recording}
end

function M.save(r,project,directory)
  local project_path=directory..'/Tube2Reaper.rpp'
  r.Main_SaveProjectEx(project,project_path,8)
  return project_path
end

return M
