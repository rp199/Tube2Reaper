local files={}
local launched
local function fake_open(path,mode)
  if mode=='wb' then
    files[path]=''
    return {
      write=function(_,value) files[path]=files[path]..value;return true end,
      close=function() end,
    }
  end
  if mode=='rb' and files[path]~=nil then
    return {read=function() return files[path] end,close=function() end}
  end
end

reaper={
  GetOS=function() return 'Win64' end,
  RecursiveCreateDirectory=function() end,
  time_precise=function() return 42 end,
  ExecProcess=function(command)
    launched=command
    return '0\nclipboard text\r\n'
  end,
}

local original_open=io.open
io.open=fake_open

local jobs=dofile('lua/jobs.lua')
assert(jobs.quote("a'b")=="'a''b'",'PowerShell single-quote escaping')
assert(not pcall(jobs.quote,'bad\nargument'),'Windows arguments reject newlines')
local job=jobs.start("C:/Users/O'Brien/jobs/1",{
  'C:/Program Files/Tube2Reaper/bin/yt-dlp.exe',
  "song & artist's live version",
})
local script=assert(files["C:/Users/O'Brien/jobs/1/run.ps1"])
assert(script:match("& 'C:/Program Files/Tube2Reaper/bin/yt%-dlp.exe'"),'Executable path is quoted')
assert(script:match("'song & artist''s live version'"),'Argument is PowerShell-escaped')
assert(script:match('UTF8Encoding %-ArgumentList %$false'),'Job output uses UTF-8 without a BOM')
assert(script:match('%[Console%]::OutputEncoding = %$utf8'),'Native output is read as UTF-8')
assert(script:match('stderr%.raw'),'Native stderr is normalized before Lua reads it')
assert(not script:match('Out%-File'),'PowerShell 5 BOM-producing output is not used')
assert(launched:match('powershell%.exe.*ExecutionPolicy Bypass.*run%.ps1'),'Job starts through PowerShell')

files[job.done]='\239\187\1910'
files[job.out]='\239\187\191result'
files[job.err]=''
local code,output=jobs.poll(job)
assert(code==0 and output=='result','UTF-8 BOM is ignored when polling jobs')

local clipboard=dofile('lua/clipboard.lua')
assert(clipboard.paste()=='clipboard text','Windows clipboard paste')
assert(clipboard.copy("it's text","C:/Users/O'Brien/Tube2Reaper"),'Windows clipboard copy')
assert(launched:match('Set%-Clipboard'),'Windows clipboard uses PowerShell')
assert(launched:match("O''Brien"),'Clipboard file path is PowerShell-escaped')

io.open=original_open
print('Windows paths passed: quoting, UTF-8 jobs, and clipboard')
