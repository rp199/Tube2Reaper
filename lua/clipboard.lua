local M={}
local os_name=reaper.GetOS()
local windows=os_name:match('Win')~=nil
local mac=os_name:match('OSX')~=nil or os_name:match('macOS')~=nil

local function output(command)
  local result=reaper.ExecProcess(command,5000)
  if not result then return nil end
  local code,body=result:match('^(-?%d+)\n(.*)$')
  if tonumber(code)~=0 then return nil end
  return (body or ''):gsub('[\r\n]+$','')
end

function M.paste()
  if mac then return output('/usr/bin/pbpaste') end
  if windows then
    return output('powershell.exe -NoProfile -NonInteractive -Command "Get-Clipboard -Raw"')
  end
  return output('/usr/bin/wl-paste --no-newline') or
    output('/usr/bin/xclip -selection clipboard -o') or
    output('/usr/bin/xsel --clipboard --output')
end

function M.copy(text,workspace)
  local path=workspace..'/clipboard.txt'
  reaper.RecursiveCreateDirectory(workspace,0)
  local file=io.open(path,'wb'); if not file then return false end
  file:write(text);file:close()
  local safe=path:gsub("'","'\\''")
  local command
  if mac then command="/bin/sh -c '/usr/bin/pbcopy < '\"'\"'"..safe.."'\"'\"''"
  elseif windows then
    local ps=path:gsub("'","''")
    command='powershell.exe -NoProfile -NonInteractive -Command "Set-Clipboard -Value (Get-Content -Raw -LiteralPath \''..ps..'\')"'
  else
    command="/bin/sh -c '(command -v wl-copy >/dev/null && wl-copy || "..
      "command -v xclip >/dev/null && xclip -selection clipboard || "..
      "command -v xsel >/dev/null && xsel --clipboard --input) < '\"'\"'"..safe.."'\"'\"''"
  end
  local result=reaper.ExecProcess(command,5000)
  return result and result:match('^0\n')~=nil
end
return M
