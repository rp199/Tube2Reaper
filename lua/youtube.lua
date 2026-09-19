local M={}
function M.normalize(value)
  return value:gsub('^(https?:)/([^/])','%1//%2')
end
function M.is_url(value)
  value=M.normalize(value)
  local host=value:match('^https?://([^/%?#]+)')
  if not host then return false end
  host=host:lower():gsub('^www%.','')
  return host=='youtube.com' or host:match('%.youtube%.com$')~=nil or host=='youtu.be'
end
function M.target(value)
  value=M.normalize(value)
  return M.is_url(value) and value or ('ytsearch8:'..value)
end
function M.watch_url(id)
  assert(id:match('^[%w_-]+$'),'Invalid YouTube video ID')
  return 'https://www.youtube.com/watch?v='..id
end
function M.open_command(os_name,id)
  local url=M.watch_url(id)
  if os_name:match('Win') then
    return 'powershell.exe -NoProfile -NonInteractive -Command "Start-Process -LiteralPath \''..url..'\'"'
  elseif os_name:match('OSX') or os_name:match('macOS') then
    return "/usr/bin/open '"..url.."'"
  end
  return "/usr/bin/xdg-open '"..url.."'"
end
return M
