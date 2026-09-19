local M={}
function M.download(details)
  local lower=(details or ''):lower()
  if lower:find('not a bot',1,true) or lower:find('confirm you',1,true) then
    return {title='YouTube needs verification',
      description='YouTube blocked this download. Search can still work.',
      help='Try another result or import a local file. See README for sign-in options.'}
  elseif lower:find('private video',1,true) or lower:find('sign in',1,true) then
    return {title='This video requires sign-in',
      description='Tube2Reaper currently downloads without a YouTube account.',
      help='Choose a public result or import an audio file you already have.'}
  elseif lower:find('unavailable',1,true) or lower:find('not available',1,true) then
    return {title='Video unavailable',description='YouTube could not provide this video.',
      help='Choose another result or import a local audio file.'}
  end
  return {title='Could not complete the request',
    description='The download helper reported an error.',
    help='Check Details and the helper setup instructions in README.'}
end
return M
