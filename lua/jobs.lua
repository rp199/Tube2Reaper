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
  local s = f:read('*a'); f:close()
  if s:sub(1,3) == '\239\187\191' then s=s:sub(4) end
  return s
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
    local rawerr=job.err..'.raw'
    write(path, "$ErrorActionPreference = 'Stop'\n"..
      "$utf8 = New-Object Text.UTF8Encoding -ArgumentList $false\n"..
      "[Console]::OutputEncoding = $utf8\n$OutputEncoding = $utf8\n"..
      "$stdout = @()\n$stderr = @()\n$code = 1\ntry {\n"..
      '$stdout = @(& '..command..' 2> '..quote(rawerr)..")\n$code = $LASTEXITCODE\n"..
      'if (Test-Path -LiteralPath '..quote(rawerr)..') { $stderr = @(Get-Content -LiteralPath '..quote(rawerr)..") }\n"..
      "} catch { $stderr = @($_ | Out-String); $code = 1 }\n"..
      '[IO.File]::WriteAllText('..quote(job.out)..', [string]::Join([Environment]::NewLine, [string[]]$stdout), $utf8)'.."\n"..
      '[IO.File]::WriteAllText('..quote(job.err)..', [string]::Join([Environment]::NewLine, [string[]]$stderr), $utf8)'.."\n"..
      'if (Test-Path -LiteralPath '..quote(rawerr)..') { Remove-Item -LiteralPath '..quote(rawerr)..' -Force }'.."\n"..
      '[IO.File]::WriteAllText('..quote(job.done)..', [string]$code, $utf8)'.."\n")
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
