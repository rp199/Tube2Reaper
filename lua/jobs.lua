-- External tools run asynchronously; the REAPER UI polls result files.
local M = {}
local windows = reaper.GetOS():match('Win') ~= nil
local function quote(s)
  assert(not s:find('[\r\n%z]'), 'Invalid newline in command argument')
  return "'" .. s:gsub("'", windows and "''" or "'\\''") .. "'"
end
M.quote = quote
function M.read(path)
  local f = io.open(path, 'rb'); if not f then return nil end
  local s = f:read('*a'); f:close(); return s
end
local function write(path, data)
  local f = assert(io.open(path, 'wb')); assert(f:write(data)); f:close()
end
function M.start(dir, argv)
  reaper.RecursiveCreateDirectory(dir, 0)
  local job = {out=dir..'/stdout', err=dir..'/stderr', done=dir..'/done'}
  local args = {}; for _, arg in ipairs(argv) do args[#args+1] = quote(arg) end
  local command = table.concat(args, ' ')
  if windows then
    local path = dir..'/run.ps1'
    write(path, "$ErrorActionPreference = 'Stop'\n[Console]::OutputEncoding = [Text.UTF8Encoding]::new()\ntry {\n& "..command..
      ' 2> '..quote(job.err)..' | Out-File -Encoding utf8 '..quote(job.out)..
      "\n$code = $LASTEXITCODE\n} catch { $_ | Out-File -Encoding utf8 "..quote(job.err)..
      "\n$code = 1 }\n[IO.File]::WriteAllText("..quote(job.done)..", [string]$code)\n")
    -- Paths are double-quoted for Windows process argument parsing, not cmd.exe.
    assert(not path:find('"'), 'Invalid path')
    reaper.ExecProcess('powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'..path..'"', -2)
  else
    local path = dir..'/run.sh'
    write(path, '#!/bin/sh\n'..command..' > '..quote(job.out)..' 2> '..quote(job.err)..
      '\nresult=$?\nprintf "%s" "$result" > '..quote(job.done)..'\n')
    reaper.ExecProcess('/bin/sh "'..path:gsub('([\\"$`])', '\\%1')..'"', -2)
  end
  job.started = reaper.time_precise()
  return job
end
function M.poll(job)
  local done = M.read(job.done)
  if not done then return nil end
  return tonumber(done) or -1, M.read(job.out) or '', M.read(job.err) or ''
end
return M
