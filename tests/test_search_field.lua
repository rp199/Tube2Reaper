local ui=dofile('lua/ui.lua')
local state={query=''}
gfx={mouse_cap=0}
local searched,opened,copied=0,0,nil
local actions={search=function() searched=searched+1 end,
  local_file=function() opened=opened+1 end,
  paste=function() return 'https://youtu.be/test\n' end,
  copy=function(value) copied=value;return true end}
local function key(k) ui.handle_key(state,k,actions) end
for c in ('solo'):gmatch('.') do key(c:byte()) end
assert(state.query=='solo' and opened==0 and searched==0,'Typing must not trigger shortcuts')
key(1818584692);key(8)
assert(state.query=='soo','Backspace should edit at cursor')
key(6579564)
assert(state.query=='so','Delete should remove next character')
key(1);key(0xe9);key((117<<24)|0x65e5)
assert(state.query=='é日','Selection replacement and Unicode input')
key(8);assert(state.query=='é','Backspace must remove a whole Unicode character')
key(30064);assert(state.query=='é','Special keys must not become text')
key(13);assert(searched==1,'Enter submits')
key(27);key(108);assert(opened==1,'Local shortcut works outside input')
key(115);key(22);assert(state.query=='https://youtu.be/test ','Paste replaces selection and removes newlines')
key(1);key(3);assert(copied==state.query,'Copy returns selected text')
key(24);assert(state.query=='','Cut removes selected text')
key(22);key(1818584692);gfx.mouse_cap=8;key(1818584692);gfx.mouse_cap=0;key(97)
assert(state.query=='https://youtu.be/tesa ',
  'Shift selection is replaced by typing; got '..state.query)
gfx.mouse_cap=4;key(97);key(118);gfx.mouse_cap=0
assert(state.query=='https://youtu.be/test ','Printable Cmd/Ctrl shortcuts are normalized')
print('Inline search field passed: editing, Unicode, selection, clipboard, shortcuts, submit')
