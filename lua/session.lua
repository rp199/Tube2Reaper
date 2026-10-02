-- Adds one audio track to the active REAPER project without changing project settings.
local M={}

function M.add(r,path,title)
  assert(type(path)=='string' and path~='','Audio path is required')
  local project=assert(r.EnumProjects(-1,''),'No active REAPER project.')
  r.InsertMedia(path,1)
  local item=assert(r.GetSelectedMediaItem(project,0),'REAPER could not import this audio format.')
  r.SetMediaItemInfo_Value(item,'C_BEATATTACHMODE',0)
  local take=r.GetActiveTake(item)
  assert(take and not r.TakeIsMIDI(take),'Choose an audio file.')
  local imported=r.GetMediaItemTrack(item)
  r.GetSetMediaTrackInfo_String(imported,'P_NAME',title or 'Imported audio',true)

  r.TrackList_AdjustWindows(false)
  r.UpdateArrange()
  return {project=project,path=path,item=item,take=take,imported_track=imported}
end

return M
