-- REAPER-native drawing only: no UI extension or runtime dependencies.
local M = {}
local previous_mouse, scroll = 0, 0
local focused, cursor, anchor, dragging = true, 0, nil, false
local function characters(s)
  local out={}
  for _,code in utf8.codes(s) do out[#out+1]=utf8.char(code) end
  return out
end
local function selection()
  if anchor==nil or anchor==cursor then return nil end
  return math.min(anchor,cursor),math.max(anchor,cursor)
end
local function selected_text(chars)
  local first,last=selection()
  return first and table.concat(chars,'',first+1,last) or ''
end
local function delete_selection(chars)
  local first,last=selection()
  if not first then return false end
  for _=first+1,last do table.remove(chars,first+1) end
  cursor=first;anchor=nil
  return true
end
function M.handle_key(state,key,actions)
  state.query=state.query or ''
  local primary=gfx and gfx.mouse_cap and gfx.mouse_cap&4~=0
  if primary then
    local shortcuts={[65]=1,[97]=1,[67]=3,[99]=3,[86]=22,[118]=22,[88]=24,[120]=24}
    key=shortcuts[key] or key
  end
  if key==9 then focused=not focused; anchor=nil; return end
  if key==27 then focused=false; anchor=nil; return end
  if not focused then
    if key==115 or key==83 then focused=true; cursor=utf8.len(state.query); anchor=0 end
    if key==108 or key==76 then actions.local_file() end
    return
  end
  local chars=characters(state.query)
  cursor=math.min(cursor,#chars)
  if key==13 then scroll=0; actions.search(); return end
  if key==1 then anchor=0;cursor=#chars;return end -- Cmd/Ctrl+A
  if key==3 then local value=selected_text(chars);if value~='' and actions.copy then actions.copy(value) end;return end
  if key==24 then
    local value=selected_text(chars)
    if value~='' and actions.copy then actions.copy(value);delete_selection(chars);state.query=table.concat(chars) end
    return
  end
  if key==22 then
    local value=actions.paste and actions.paste() or nil
    if value and value~='' then
      value=value:gsub('[\r\n]+',' ')
      delete_selection(chars)
      for _,part in ipairs(characters(value)) do
        if #chars>=300 then break end
        table.insert(chars,cursor+1,part);cursor=cursor+1
      end
      state.query=table.concat(chars);anchor=nil
    end
    return
  end
  local shift=gfx and gfx.mouse_cap and gfx.mouse_cap&8~=0
  local function move(to)
    if shift then anchor=anchor or cursor else anchor=nil end
    cursor=math.max(0,math.min(#chars,to))
  end
  if key==1818584692 then move(cursor-1);return end -- left
  if key==1919379572 then move(cursor+1);return end -- right
  if key==1752132965 then move(0);return end -- home
  if key==6647396 then move(#chars);return end -- end
  local code=key
  if key>>24==117 then code=key&0xffffff end
  local printable=(code>=32 and code<=126) or (code>=160 and code<=255) or
    (key>>24==117 and code>=160 and code<=0x10ffff)
  if key==8 or key==127 or key==6579564 or printable then
    local deleted=delete_selection(chars)
    if not deleted and (key==8 or key==127) then
      if cursor>0 then table.remove(chars,cursor);cursor=cursor-1 end
    elseif not deleted and key==6579564 and cursor<#chars then table.remove(chars,cursor+1) end
    if printable and #chars<300 then
      table.insert(chars,cursor+1,utf8.char(code));cursor=cursor+1
    end
    anchor=nil
    state.query=table.concat(chars)
  end
end
local colors = {
  background={0.055,0.07,0.09}, panel={0.09,0.115,0.145},
  hover={0.14,0.18,0.22}, text={0.91,0.94,0.95}, muted={0.55,0.64,0.69},
  accent={0.36,0.86,0.68}, dark={0.04,0.16,0.12}, line={0.17,0.22,0.26},
}
local function color(c) gfx.set(table.unpack(colors[c])) end
local function rect(x,y,w,h,c) color(c); gfx.rect(x,y,w,h) end
local function text(x,y,s,c,size,width)
  gfx.setfont(1,'Arial',size or 16); color(c or 'text')
  if width and gfx.measurestr(s)>width then
    -- Remove entire UTF-8 characters while ellipsizing.
    while #s>0 and gfx.measurestr(s..'...')>width do
      s=s:gsub('[%z\1-\127\194-\244][\128-\191]*$','')
    end
    s=s..'...'
  end
  gfx.x=x; gfx.y=y; gfx.drawstr(s)
end
local function centered_text(x,y,w,h,s,c,size)
  gfx.setfont(1,'Arial',size or 16);color(c or 'text')
  local tw,th=gfx.measurestr(s)
  gfx.x=x+(w-tw)/2;gfx.y=y+(h-th)/2;gfx.drawstr(s)
end
local function inside(x,y,w,h)
  return gfx.mouse_x>=x and gfx.mouse_x<x+w and gfx.mouse_y>=y and gfx.mouse_y<y+h
end
local function button(x,y,w,h,label,click,fn,disabled,selected)
  local hover=inside(x,y,w,h) and not disabled
  rect(x,y,w,h,selected and 'accent' or hover and 'hover' or 'panel')
  text(x+14,y+(h-16)/2,label,selected and 'dark' or disabled and 'muted' or 'text',16,w-28)
  if hover and click then fn() end
end
function M.duration(value)
  local seconds=tonumber(value)
  if not seconds then return '--:--' end
  return string.format('%d:%02d',math.floor(seconds/60),math.floor(seconds%60))
end
function M.draw(state, actions)
  local w,h=gfx.w,gfx.h
  rect(0,0,w,h,'background')
  if w<520 or h<340 then
    text(16,20,'Enlarge the window to use Tube2Reaper.','text',16,w-32); return
  end
  local click=gfx.mouse_cap&1==1 and previous_mouse&1==0
  previous_mouse=gfx.mouse_cap
  local busy=state.job~=nil or state.analysis~=nil
  text(24,20,'Tube2Reaper','text',28)
  text(24,56,'Your next session starts here.','muted',16)
  local field_width=w-170
  rect(24,91,field_width,44,'panel')
  if focused and not busy then rect(24,133,field_width,2,'accent') end
  local query=state.query or ''
  gfx.setfont(1,'Arial',16)
  local chars=characters(query)
  local first=1
  while first<=cursor and gfx.measurestr(table.concat(chars,'',first,cursor))>field_width-32 do
    first=first+1
  end
  local shown=table.concat(chars,'',first)
  local function index_at(mouse_x)
    local target=math.max(0,mouse_x-38)
    local index=first-1
    for i=first,#chars do
      local width=gfx.measurestr(chars[i])
      if target<width/2 then return index end
      target=target-width;index=i
    end
    return #chars
  end
  if click and not busy then
    focused=inside(24,91,field_width,44)
    if focused then cursor=index_at(gfx.mouse_x);anchor=cursor;dragging=true
    else anchor=nil;dragging=false end
  end
  if dragging and gfx.mouse_cap&1==1 and focused then cursor=index_at(gfx.mouse_x) end
  if gfx.mouse_cap&1==0 then dragging=false end
  local selection_first,selection_last=selection()
  if selection_first and focused then
    local visible_first=math.max(selection_first,first-1)
    local visible_last=math.max(visible_first,selection_last)
    local before=table.concat(chars,'',first,visible_first)
    local chosen=table.concat(chars,'',visible_first+1,visible_last)
    rect(38+gfx.measurestr(before),102,gfx.measurestr(chosen),23,'hover')
  end
  text(38,105,query=='' and 'Song, artist, or direct YouTube link...' or shown,
    query=='' and 'muted' or 'text',16,field_width-28)
  if focused and not busy and reaper.time_precise()%1<0.6 then
    local caret=38+gfx.measurestr(table.concat(chars,'',first,cursor))
    rect(caret,104,1,20,'accent')
  end
  button(w-134,91,110,44,'Search',click,function() scroll=0;actions.search() end,
    busy or query:match('^%s*$')~=nil,true)
  button(24,149,210,32,'Choose local audio',click,actions.local_file,busy)
  text(24,198,'TEMPO','muted',12)
  local modes={{'auto','Automatic'},{'review','Review BPM'},{'skip','Off'}}
  local mw=(w-64)/3
  for i,mode in ipairs(modes) do
    button(24+(i-1)*(mw+8),221,mw,36,mode[2],click,
      function() actions.mode(mode[1]) end,busy,state.tempo_mode==mode[1])
  end
  local descriptions={auto='Detect BPM and save automatically. No confirmation needed.',
    review='Detect BPM, then let you check or edit it before saving.',
    skip='Skip tempo analysis. Create the session at 120 BPM.'}
  text(24,269,descriptions[state.tempo_mode],'muted',14,w-48)
  rect(24,300,w-48,1,'line')
  text(24,318,#state.results>0 and 'CHOOSE A TRACK' or 'IMPORT AUDIO','muted',12)
  local top,bottom=346,h-78
  if state.error then
    rect(24,top,w-48,138,'panel')
    text(38,top+12,state.error.title,'accent',18,w-76)
    text(38,top+40,state.error.description,'text',14,w-76)
    text(38,top+64,state.error.help,'muted',14,w-76)
    button(38,top+96,105,30,'Details',click,actions.error_details,false)
    button(155,top+96,105,30,'Dismiss',click,actions.dismiss_error,false)
    top=top+150
  end
  local visible=math.max(0,math.floor((bottom-top)/48))
  if gfx.mouse_wheel~=0 then
    scroll=scroll-(gfx.mouse_wheel>0 and 1 or -1); gfx.mouse_wheel=0
  end
  scroll=math.max(0,math.min(scroll,math.max(0,#state.results-visible)))
  if #state.results==0 and bottom>top+60 then
    text(24,top+20,'Find a song, or bring your own audio.','text',20,w-48)
    text(24,top+55,'Start a project with your audio and an empty recording track.','muted',14,w-48)
  end
  for row=1,visible do
    local result=state.results[row+scroll]; if not result then break end
    local y=top+(row-1)*48
    rect(24,y,w-48,42,'panel')
    text(36,y+13,string.format('%02d',row+scroll),'muted',14)
    text(72,y+12,result.title,busy and 'muted' or 'text',16,w-430)
    text(w-344,y+13,M.duration(result.duration),'muted',14)
    local browser_x,browser_y,browser_w,browser_h=w-272,y+5,132,32
    local import_x,import_y,import_w,import_h=w-132,y+5,96,32
    local browser_hover=inside(browser_x,browser_y,browser_w,browser_h) and not busy
    local import_hover=inside(import_x,import_y,import_w,import_h) and not busy
    rect(browser_x,browser_y,browser_w,browser_h,browser_hover and 'hover' or 'background')
    centered_text(browser_x,browser_y,browser_w,browser_h,'Open in browser',
      browser_hover and 'text' or 'muted',13)
    rect(import_x,import_y,import_w,import_h,import_hover and 'accent' or 'hover')
    centered_text(import_x,import_y,import_w,import_h,'Import',import_hover and 'dark' or 'text',14)
    if click and browser_hover then actions.open(result)
    elseif click and import_hover then actions.download(result) end
  end
  rect(0,h-65,w,65,'panel')
  text(24,h-46,state.status,busy and 'accent' or 'text',14,w-48)
  if busy then
    local fraction=state.analysis and state.analysis.position/math.max(state.analysis.finish,0.001)
    rect(24,h-16,w-48,3,'line')
    if fraction then rect(24,h-16,(w-48)*math.min(1,fraction),3,'accent')
    else
      local length=(w-48)*0.18
      local x=24+(w-48-length)*((math.sin(reaper.time_precise()*2)+1)/2)
      rect(x,h-16,length,3,'accent')
    end
  end
end
return M
