-------------
-- GLOBALS --
-------------


lines = {}
running = false
line = 1
char = 1

saveline = 1
savechar = 1


wait = 0
waitto = 0
last_wait = 0
waittowait = 0
inputkeys =  {up = "U", left = "L", down = "D", right = "R", a = "A", b = "B", select = "C", start = "S"}
input =  {a = false, b = false, select = false, start = false, up = false, down = false, left = false, right = false}
hold = {a = false, b = false, select = false, start = false, up = false, down = false, left = false, right = false}
savehold = {a = false, b = false, select = false, start = false, up = false, down = false, left = false, right = false}
frame = 0

helpmenu = {visible = false, cursor = 1, items={"H","R","E","Q","D","A","F","T","G","W","S"}}
running_minor = false

savestates = {}
currentsave = 0
savestatecount = 1
ssslot = 0

ssslot_was = -1
savestatecount_was = -1

just_loaded = false

set_to_start = false
set_to_save_major = false
set_to_save_minor = false
set_to_load_major = false
set_to_load_minor = false
set_to_load_reset = false
set_to_actually_load = false
state_to_load = ""

-----------------------------------
-- CONFIG VALUES FROM script.cfg --
-----------------------------------

tasfile = ""
basedir = ""
printlog = true
drawonscreen = true
displaymessages = true
onscriptload = -2
exitonfinish = false

---------------------
-- SAVE/LOAD STATE --
---------------------

function start_script()
  lines = lines_from(basedir .. "/" .. tasfile)
  log("Starting TAS")
  if len(lines) <= 0 then
    log("Couldn't find TASfile at: " .. basedir .. "/" .. tasfile)
    if exitonfinish then
      emu.stop(1)
    end
    return
  end
  emu.reset()
  
  hold = {a = false, b = false, select = false, start = false, up = false, down = false, left = false, right = false}
  line = 1
  char = 1
  frame = 0
  wait = 0
  waitto = 0
  waittowait = 0
  last_wait = 0
  currentsave = 0
  running = false
  running_minor = false
  just_loaded = true
  state_to_load = false
  set_to_actually_load = true
end

function continue_script(num)
  if num == 0 and savestates[1].line == 1 and savestates[1].char == 1 then
    start_script()
    return
  end
  running_minor = false
  if num > savestatecount or not savestates[num+1] then
    save_tas_state("NOSTATE")
    log("Couldn't find savestate")
    return
  end
  read_savestate_from_file(num)
  if num == 0 then
    log("Loading quicksave!")
    running_minor = true
  else
    log("Loading state #" .. num)
  end
  lines = lines_from(basedir .. "/" .. tasfile)
  if len(lines) <= 0 then
    save_tas_state("NOSTATE")
    log("Couldn't find TASfile at: " .. basedir .. "/" .. tasfile)
    if exitonfinish then
      emu.stop(1)
    end
    return
  else
    currentsave = num
    hold = orray({a = false, b = false, select = false, start = false, up = false, down = false, left = false, right = false}, savestates[num+1].hold)
    line = savestates[num+1].line
    char = savestates[num+1].char
    frame = savestates[num+1].frame
    wait = 0
    waitto = 0
    waittowait = 0
    last_wait = 0
    running = false
    just_loaded = true
  end
end


function save_state(major)
  if major then
    if ssslot == currentsave then
      ssslot = ssslot + 1
    end
    currentsave = currentsave + 1
    log("Making savestate: #" .. currentsave .. " at: Frame: " .. frame .. " Line: " .. saveline .. " Char: " .. savechar)
    write_savestate_to_file(currentsave)
    savestates[currentsave+1] = {line=saveline, char=savechar, frame=frame, hold=orray({a = false, b = false, select = false, start = false, up = false, down = false, left = false, right = false}, hold)}
    if savestatecount < currentsave then
      savestatecount = currentsave
    end
  else
    log("Making Quicksave at: Frame: " .. frame .. " Line: " .. saveline .. " Char: " .. savechar)
    write_savestate_to_file(0)
    savestates[1] = {line=saveline, char=savechar, frame=frame, hold=orray({a = false, b = false, select = false, start = false, up = false, down = false, left = false, right = false}, hold)}
  end
    
  file = io.open(basedir .. "/" .. "savestates.dat", "w")
  io.output(file)
  local savestring = ""
  for i, ss in ipairs(savestates) do
    for k,v in pairs(ss) do
      if savestring ~= "" and savestring ~= "\n" then
        savestring = savestring .. ","
      end
      if k == "hold" then
        local holdstring = ""
        for hk, hv in pairs(v) do
          if hv then
            holdstring = holdstring .. inputkeys[hk]
          end
        end
        savestring = savestring .. k .. "=" .. holdstring
      else
        savestring = savestring .. k .. "=" .. v
      end
    end
    io.write(savestring)
    savestring = "\n"
  end
  io.close(file)
  return true
end



function write_savestate_to_file(num)
  file = io.open(basedir .. "/" .. "savestates/save_" .. num .. ".sav", "w")
  io.output(file)
  io.write(emu.saveSavestate())
  io.close(file)
end

function read_savestate_from_file(num)
  file = io.open(basedir .. "/" .. "savestates/save_" .. num .. ".sav", "r")
  io.output(file)
  state_to_load = file:read('*all')
  io.close(file)
  emu.reset()
  set_to_load_reset = true
end
  

---------------
-- MAIN LOOP --
---------------


function run_tas()
  poll_user_inputs()
  state = emu.getState()
  if running then 
    frame = state.ppu.frameCount
  end
  draw_string("F: " .. frame, 62, 228)
  
  if not running then return end
  
  input = {a = false, b = false, select = false, start = false, up = false, down = false, left = false, right = false}
  local waitf = false
  local waittof = false
  local bundlef = false
  local bundleplusf = false
  local bundleminusf = false
  local plusf = false
  local minusf = false
  local nums = ""
  
  if wait > 0 then
    wait = wait - 1
    goto set_inputs
  end
  if waitto > frame then
    waittowait = waitto-frame
    goto set_inputs
  end
  waittowait = 0
  last_wait = 0
  
  while true do
    local l = lines[line]
    local c = string.sub(l,char,char)
    c = string.upper(c)
    
    
    if bundleplusf == true then
      plusf = true
      minusf = false
    elseif bundleminusf == true then
      minusf = true
    end
    
    if waitf == true or waittof == true then
      if tonumber(c) ~= nil then
        nums = nums .. c
        goto continue
      else
        if waitf == true then
          waitf = false
          wait = tonumber(nums) - 1
          last_wait = wait
        else
          waittof = false
          waitto = tonumber(nums)
          if waitto > frame then
            waittowait = waitto - frame
            last_wait = waittowait
          end
        end
        nums = ""
        break
      end
    elseif c == "X" then
      log("Breaking on X")
      save_tas_state("PAUSE")
      emu.breakExecution()
      goto continue
    elseif c == "!" then
      if not running_minor then
        if just_loaded then
          goto continue
        else
          set_to_save_major = true
          saveline = line
          savechar = char
          next_char()
          break
        end
      else
        next_char()
        break
      end
    elseif c == "?" then
      if just_loaded then
        goto continue
      else
        set_to_save_minor = true
        saveline = line
        savechar = char
        next_char()
        break
      end
      goto continue
    elseif c == "#" then
      char = string.len(l)
      goto continue
    elseif c == "%" then
      waitf = true
      goto continue
    elseif c == "@" then
      waittof = true
      goto continue
    elseif c == "+" then
      plusf = true
      minusf = false
      goto continue
    elseif c == "-" then
      minusf = true
      plusf = false
      goto continue
    end
    if c == " " then
      goto continue
    elseif c == "." or  c == ";" or c == ":" then
      next_char()
      break
    elseif c == "[" then
      -- srtart bundle
      if plusf == true then
        bundleplusf = true
      elseif minusf == true then
        bundleminusf = true
      end
      bundlef = true
      goto continue
    elseif c == "]" then
      -- end bundle
      next_char()
      break
    elseif c == "G" then
      -- press Select
      set_input("select", plusf, minusf)
      goto newinput
    elseif c == "H" then
      -- press Start
      set_input("start", plusf, minusf)
      goto newinput
    elseif c == "K" then
      -- press B
      set_input("b", plusf, minusf)
      goto newinput
    elseif c == "L" then
      -- press A
      set_input("a", plusf, minusf)
      goto newinput
    elseif c == "W" then
      -- press up
      set_input("up", plusf, minusf)
      goto newinput
    elseif c == "A" then
      -- press left
      set_input("left", plusf, minusf)
      goto newinput
    elseif c == "S" then
      -- press down
      set_input("down", plusf, minusf)
      goto newinput
    elseif c == "D" then
      -- press right
      set_input("right", plusf, minusf)
      goto newinput
    else
      log("unknown char " .. c .. " at " .. line .. ":" .. char)
      goto continue
    end
        
    ::newinput::
    plusf = false
    minusf = false
    if bundlef == false then
      next_char()
      break
    end

    ::continue::
    just_loaded = false
    if not next_char() then break end

  end
  ::set_inputs::
  just_loaded = false
  emu.setInput(0, orray(input, hold))
  draw_input_text()
  if running then
   save_tas_state("RUN")
  end
end


function set_input(inp, p, m)
  if p == true then
    hold[inp] = true
  elseif m == true then
    hold[inp] = false
  else
    input[inp] = true
  end
end

function draw_input_text()
  if not drawonscreen then
    return
  end
  local inputtxt = {
    {name = "up", color=0x92d3ff, icon="triangle"},
    {name = "left", color=0xc3b2ff, icon="triangle"},
    {name = "down", color=0xffbaeb, icon="triangle"},
    {name = "right", color=0xffdba2, icon="triangle"},
    {name = "a", color=0x71f341, char="A"},
    {name = "b", color=0x61d3e3, char="B"},
    {name = "select", color=0xffa200, char="C"},
    {name = "start", color=0xebd320, char="S"}
  }
  local fade = 0xF8000000
  local startx = 0
  local inp = orray(input,hold)
  for i,button in pairs(inputtxt) do
    if inp[button.name] then
      if button.char then
        emu.drawString(startx + i*6, 228, button.char, button.color + fade, 0xFF000000, 40)
        emu.drawString(startx + i*6, 228, button.char, button.color + fade, 0xFF000000, 30)
        emu.drawString(startx + i*6, 228, button.char, button.color + fade, 0xFF000000, 20)
        emu.drawString(startx + i*6, 228, button.char, button.color + fade, 0xFF000000, 10)
        emu.drawString(startx + i*6, 228, button.char, button.color, 0xFF000000, 1)
      elseif button.icon then
        draw_triangle(button.name, startx +i*6,228,button.color + fade,40)
        draw_triangle(button.name, startx +i*6,228,button.color + fade,30)
        draw_triangle(button.name, startx +i*6,228,button.color + fade,20)
        draw_triangle(button.name, startx +i*6,228,button.color + fade,10)
        draw_triangle(button.name, startx +i*6,228,button.color,1)
      end
    end
  end
end

function draw_triangle(dir,x,y,color,duration)
  local triangle = {{2,1},{1,2},{2,2},{3,2},{1,3},{2,3},{3,3}, {0,4},{1,4},{2,4},{3,4},{4,4}, {0,5},{1,5},{2,5},{3,5},{4,5}}
  for i, point in pairs(triangle) do
    if dir == "up" then
      emu.drawPixel(x+point[1], y+point[2], color, duration)
    elseif dir == "down" then
      emu.drawPixel(x+point[1], y+6-point[2], color, duration)
    elseif dir == "left" then
      emu.drawPixel(x+point[2]-1, y+point[1]+1, color, duration)
    elseif dir == "right" then
      emu.drawPixel(x+5-point[2], y+point[1]+1, color, duration)
    end
  end
end

function next_char()
  char = char + 1
  while char > string.len(lines[line]) do
    if line == len(lines) then
      running = false
      save_tas_state("EOF")
      show_message("TAS EOF REACHED")
      log("EOF. Shutting TAS on frame: ".. state.ppu.frameCount)
      if exitonfinish then
        emu.stop(0)
      end
      return false
    end
    line = line + 1
    char = 1
  end
  return true
end


keys = {
  H = {pressed=false, holdable=false, hold=0, description="Toggle this menu", func="show_help"},
  R = {pressed=false, holdable=false, hold=0, description="Run TAS from start", func="set_global_var", p1="set_to_start", p2=true},
  E = {pressed=false, holdable=false, hold=0, description="Run TAS from slot", func="set_global_var", p1="set_to_load_major", p2=true},
  Q = {pressed=false, holdable=false, hold=0, description="Run TAS from quicksave", func="set_global_var", p1="set_to_load_minor", p2=true},
  D = {pressed=false, holdable=true, hold=0, description="Increment savestate slot", func="change_ss_slot", p1=1},
  A = {pressed=false, holdable=true, hold=0, description="Decrement savestate slot", func="change_ss_slot", p1=-1},
  W = {pressed=false, holdable=true, hold=0, description="Navigate menu up", func="change_menu", p1=-1},
  S = {pressed=false, holdable=true, hold=0, description="Navigate menu down", func="change_menu", p1=1},
  F = {pressed=false, holdable=false, hold=0, description="Refresh savestates", func="check_savestate", p1=-1, p2=true},
  T = {pressed=false, holdable=false, hold=0, description="Stop TAS", func="set_global_var", p1="running", p2=false},
  G = {pressed=false, holdable=false, hold=0, description="Stop Emulator and open debug", func="open_emu_debug"},
  Enter = {pressed=false, holdable=false, hold=0, description="Do menu action", func="do_menu_action"}
}


function poll_user_inputs()
  for k,keystate in pairs(keys) do
    if emu.isKeyPressed(k)then
      if not keystate.pressed then
        _G[ keystate.func ](keystate.p1,keystate.p2)
        keys[k].pressed = true
      elseif keystate.holdable then
        keys[k].hold = keys[k].hold + 1
        if keys[k].hold > 40 then
          keys[k].hold = 38
          keys[k].pressed = false
        end
      end
    else
      keys[k].pressed = false
      keys[k].hold = 0
    end
  end
end

function show_help()
  helpmenu.visible = not helpmenu.visible
end

function set_global_var(var, val)
  _G[var] = val
end

function change_ss_slot(c)
  ssslot = ssslot + c
  if ssslot < 0 then
    ssslot = 0
  elseif ssslot > savestatecount then
    ssslot = savestatecount
  end
end

function change_menu(c)
  if helpmenu.visible then
    helpmenu.cursor = helpmenu.cursor + c
    if helpmenu.cursor < 1 then
      helpmenu.cursor = 1
    elseif helpmenu.cursor > len(helpmenu.items) then
      helpmenu.cursor = len(helpmenu.items)
    end
  end
end
  
function open_emu_debug()
  emu.execute(1,0)
end

function do_menu_action()
  if helpmenu.visible then
    local key = keys[ helpmenu.items[ helpmenu.cursor ] ]
    _G[ key.func ](key.p1, key.p2)
  end
end

function draw_help_menu()
  local drawy = 216 - 9 * len(helpmenu.items)
  emu.drawString(-1, drawy, " Control tas state:", 0xFFFFFF, 0x77000000, 1)
  for i, k in ipairs(helpmenu.items) do
    if i == helpmenu.cursor then
      emu.drawString(-1, drawy + i*9, " (" .. k .. ")>" .. keys[k].description, 0xFFFF88, 0x77000088, 1)
    else
      emu.drawString(-1, drawy + i*9, " (" .. k .. ") " .. keys[k].description, 0xFFFFFF, 0x77000000, 1)
    end
  end
end


function check_savestate(num, getcount)
  local check = loop_savestates(num, getcount)
  if currentsave > savestatecount then
    currentsave = savestatecount
  end
  if ssslot > savestatecount then
    ssslot = savestatecount
  end
  if getcount then
    savestatecount = savestatesfound
    if not found_quick then
     log("Quick save not found!")
   end
  end
  return check
end

found_quick = false
savestatesfound = 0

function loop_savestates(num, getcount)
  lines = lines_from(basedir .. "/" .. tasfile)
  if len(lines) <= 0 then
    log("Couldn't find TASfile at: " .. basedir .. "/" .. tasfile)
    if exitonfinish then
      emu.stop(1)
    end
    return false
  end
  
  ss = lines_from(basedir .. "/" .. "savestates.dat")
  
  savestates = {}
  for _k, s in pairs(ss) do
    
    local sstate = {}
    for _kk, v in pairs(split(s,",")) do
      local kv = split(v,"=")
      if kv[1] == "hold" then
        local holdload = {a = false, b = false, select = false, start = false, up = false, down = false, left = false, right = false}
        if kv[2] then
          for inp, inps in pairs(inputkeys) do
            if string.find(kv[2], inps, 1, true) then
              holdload[inp] = true
            end
          end
        end
        sstate[ kv[1] ] = holdload
      else
        sstate[ kv[1] ] = tonumber(kv[2])
      end
    end
    savestates[#savestates+1] = sstate
  end
  found_quick = false
  if len(savestates) == 0 then
    savestates = {
      {line=1, char=1, frame=0, hold={a = false, b = false, select = false, start = false, up = false, down = false, left = false, right = false}}
    }
  end
  local last_save_line = 1
  local last_save_char = 1
  local ln = 1
  local cn = 1
  local frames = 0
  local wframes = "0"
  local w = false
  local wto = false
  local bundle = false
  local holds = {a = false, b = false, select = false, start = false, up = false, down = false, left = false, right = false}
  local statenum = 1
  if getcount then
    savestatesfound = 0
  end
  while true do
    if not savestates[statenum+1] and num > 0 then
      return false or getcount
    end
    local l = lines[ln]
    local c = string.sub(l,cn,cn)
    c = string.upper(c)

    if not string.find("0123456789", c, 1, true) and w then
      w = false
      frames = frames + tonumber(wframes)
      wframes = "0"
    elseif not string.find("0123456789", c, 1, true) and wto then
      wto = false
      if frames < tonumber(wframes) then
        frames = tonumber(wframes)
      end
      wframes = "0"
    end
    
    if c == "#" then
      cn = string.len(l)
      goto nextchar
    elseif c == "[" then
      frames = frames + 1
      bundle = true
    elseif c == "]" then
      bundle = false
    elseif not bundle then
      if string.find("WASDGHKL.?!;:", c, 1, true) then
        frames = frames + 1
      elseif c == "%" then
        w = true
      elseif c == "@" then
        wto = true
      elseif string.find("0123456789", c, 1, true) and (w or wto) then
        wframes = wframes .. c
      end
    end
    
    if c == "!" then
      holds = get_holds(last_save_line, last_save_char, ln, cn, holds)
      last_save_line = ln
      last_save_char = cn
      if not file_exists(basedir .. "/" .. "savestates/save_" .. statenum .. ".sav") then
        log("File: savestates/save_" .. statenum .. ".sav' not found!")
        return false or getcount
      end
      if getcount then
        log("Found state: #" .. statenum .. " at: Frame: " .. frames-1 .. " Line: " .. ln .. " Char: " .. cn)
      end
      if savestates[statenum+1].line == ln and savestates[statenum+1].char == cn and savestates[statenum+1].frame == frames-1 and arraycompare(savestates[statenum+1].hold, holds) then
        if statenum == num then
          return true
        end
      else
        if getcount then
          log("State: #" .. statenum .. " differs from disk. " .. "(F: " .. savestates[statenum+1].frame .. " L: " .. savestates[statenum+1].line .. " C: " .. savestates[statenum+1].char .. ")")
        end
        return false or getcount
      end
      if getcount then
        savestatesfound = statenum
      end
      statenum = statenum + 1
    end
    
    if c == "?" and (ln > 1 or cn > 1) then
      holds = get_holds(last_save_line, last_save_char, ln, cn, holds)
      last_save_line = ln
      last_save_char = cn
      if savestates[1].line == ln and savestates[1].char == cn and savestates[1].frame == frames-1 and arraycompare(savestates[1].hold, holds) then
        if num == 0 then
          return true
        elseif getcount then
          found_quick = true
          log("Quicksave found at: Frame: " .. frames-1 .. " Line: " .. ln .. " Char: " .. cn)
        end
      end
    end
    
    ::nextchar::
    cn = cn + 1
    while cn > string.len(lines[ln]) do
      if ln == len(lines) then
        if not getcount then
          log("Save #" .. num .. " not found!")
          if exitonfinish then
            emu.stop(1)
          end
        else
          log("No changes to saves.")
        end
        return false or getcount
      end
      ln = ln + 1
      cn = 1
    end
  end
end


function get_holds(froml, fromc, tol, toc, h)
  local holds = {a = false, b = false, select = false, start = false, up = false, down = false, left = false, right = false}
  if h then
    holds = orray(holds, h)
  end
  local p = false
  local m = false
  local bp = false
  local bm = false
  while true do
    if froml == tol and fromc == toc then
      return holds
    end
      
    local l = lines[froml]
    local c = string.sub(l,fromc,fromc)
    c = string.upper(c)
    
    if p or m or bp or bm then
      local act = true
      if m or bm then
        act = false
      end
      
      if c == "W" then
        holds.up = act
      elseif c == "A" then
        holds.left = act
      elseif c == "S" then
        holds.down = act
      elseif c == "D" then
        holds.right = act
      elseif c == "G" then
        holds.select = act
      elseif c == "H" then
        holds.start = act
      elseif c == "K" then
        holds.b = act
      elseif c == "L" then
        holds.a = act
      end
    end
    if c == "#" then
      fromc = string.len(l)
    elseif c == "[" then
      bp = p
      bm = m
    elseif c == "]" then
      bp = false
      bm = false
    end
    p = false
    m = false
    if c == "+" then
      p = true
    elseif c == "-" then
      m = true
    end
      
    fromc = fromc + 1
    while fromc > string.len(lines[froml]) do
      if froml == len(lines) then
        log(fromc .. " - " .. froml .. " _ " .. toc .. " - " .. tol)
        log("Ran out of lines on hold check")
        return holds
      end
      froml = froml + 1
      fromc = 1
    end
  end
end

last_saved_frame = -1

function save_tas_state(status)
  local inputstring = ""
  for ik, iv in pairs(input) do
    if iv or hold[ik] then
      inputstring = inputstring .. inputkeys[ik]
    end
  end
  if not file_exists(basedir) then return end
  file = io.open(basedir .. "/" .. "state.dat", "w")
  io.output(file)
  io.write('{"line": ' .. line .. ', "char": ' .. char .. ', "frame": ' .. frame .. ', "wait": ' .. waittowait + wait  .. ', "waitmax": ' .. last_wait  .. ', "status": "' .. status .. '", "timestamp": ' .. os.time() .. ', "input": "' .. inputstring .. '"}')
  io.close(file)
end


function file_exists(file)
  local f = io.open(file, "rb")
  if f then f:close() end
  return f ~= nil
end

function lines_from(file)
  if not file_exists(file) then return {} end
  local lines = {}
  for line in io.lines(file) do
    lines[#lines + 1] = line
  end
  return lines
end

----------------------
-- FUCK LUA SECTION --
----------------------

function orray(t1,t2)
    for k,v in pairs(t2) do
        if v == true then
          t1[k] = true
        end
    end
    return t1
end

function len(t)
  return len_fucking_lua(t)
end
  
function len_fucking_lua(t)
    local n = 0
    for _ in pairs(t) do
        n = n + 1
    end
    return n
end

function bool_to_int(value)
  return value and 1 or 0
end
  
function split(inputstr, sep)
   if sep == nil then
      sep = "%s"
   end
   local t={}
   for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
      table.insert(t, str)
   end
   return t
end

function arraycompare(a,b)
  for k,v in pairs(a) do
    if b[k] ~= v then
      return false
    end
  end
  return true
end


function all_trim(s)
   return s:match( "^%s*(.-)%s*$" )
end

------------------
-- VIS SETTINGS --
------------------

function log(s)
  if printlog then
    emu.log(s)
  end
end

function draw_string(s, x, y, color, bg, duration)
  if not duration then
    duration = 1
  end
  if not color then
    color = 0xFFFFFF
  end
  if not bg then
    bg = 0xFF000000
  end
  if drawonscreen then
    emu.drawString(x, y, s, color, bg, duration)
  end
end 

function show_message(s)
  if displaymessages then
    emu.displayMessage("TAS", s)
  end
end 
--------------------
-- ON FRAME START --
--------------------

function reset()
  if set_to_load_reset then
    set_to_load_reset = false
    set_to_actually_load = true
  end
end

function start_frame()
  if set_to_actually_load then
    if state_to_load then
      emu.loadSavestate(state_to_load)
    end
    set_to_actually_load = false
    running = true
  end
  draw_string("S:" .. string.format("% 3i", ssslot) .. "/" .. savestatecount, 120, 228)
  if set_to_start then
    start_script()
    set_to_start = false
  end
  if set_to_save_major then
    set_to_save_major = false
    save_state(true)
  end
  if set_to_save_minor then
    set_to_save_minor = false
    save_state(false)
  end
  if set_to_load_major then
    if ssslot == 0 then
      start_script()
    else
      if check_savestate(ssslot) then
        continue_script(ssslot)
      else
        save_tas_state("NOSTATE")
        show_message("Error loading save #" .. ssslot)
        if exitonfinish then
          emu.stop(1)
        end
        check_savestate(-1, true)
      end
    end
    set_to_load_major = false
  end
  if set_to_load_minor then
    if check_savestate(0) then
      continue_script(0)
    else
      save_tas_state("NOQSTATE")
      show_message("Error getting the quick save")
      log("Error getting the quick save")
      if exitonfinish then
        emu.stop(1)
      end
      check_savestate(-1, true)
    end
    set_to_load_minor = false
  end
  if helpmenu.visible then
    draw_help_menu()
  end
end


--------------
-- init tas --
--------------


function get_config()
  if load_conf_file("script_override.cfg") then
    log("Override config loaded")
  elseif load_conf_file("script.cfg") then
    log("Config loaded")
  else
    write_default_config()
    if load_conf_file("script.cfg") then
      log("Default config loaded.")
      log("Config TAS at " .. emu.getScriptDataFolder() .. "/" .. "script.cfg")
    else
      show_message("TAS config failed! Check script window console.")
      log("Config could not be loaded!")
      log("Please config TAS at " .. emu.getScriptDataFolder() .. "/" .. "script.cfg")
      return false
    end
  end
  return true
end
  
function write_default_config()
  file = io.open(emu.getScriptDataFolder() .. "/" .. "script.cfg", "w")
  io.output(file)
  io.write(
    "BASEDIR=MyFirstTas\n"..
    "# Path to tas folder containing TASfile, savestates etc.\n"..
    "TASFILE=MyTAS.txt\n"..
    "# TASfilename\n"..
    "PRINTLOG=1\n"..
    "# Print log to emulator console\n"..
    "DRAWONSCREEN=1\n"..
    "# Draw debug/control strings on screen\n"..
    "DISPLAYMESSAGES=1\n"..
    "# Display popup messages about script status\n"..
    "ONSCRIPTLOAD=-2\n"..
    "# -2  Do not run TAS on load.\n"..
    "# -1: Load latest Quicksave.\n"..
    "# 0: Start TAS from start.\n"..
    "# 1-N load savestate X")
  io.close(file)
end
  
function load_conf_file(f)
  conf = lines_from(emu.getScriptDataFolder() .. "/" .. f)
  if conf then
    local settings_found = false 
    for i,line in ipairs(conf) do
      if string.find(line, "=", 1, true) then
        local kv = split(line, "=")
        if all_trim(kv[1]) == "BASEDIR" then
          if kv[2] then
            basedir = all_trim(kv[2])
          end
          settings_found = true
        elseif all_trim(kv[1]) == "TASFILE" then
          if kv[2] then
            tasfile = all_trim(kv[2])
          end
          settings_found = true
        elseif all_trim(kv[1]) == "PRINTLOG" then
          printlog = (tonumber(kv[2]) == 1)
          settings_found = true
        elseif all_trim(kv[1]) == "DRAWONSCREEN" then
          drawonscreen = (tonumber(kv[2]) == 1)
          settings_found = true
        elseif all_trim(kv[1]) == "DISPLAYMESSAGES" then
          displaymessages = (tonumber(kv[2]) == 1)
          settings_found = true
        elseif all_trim(kv[1]) == "ONSCRIPTLOAD" then
          if kv[2] then
            onscriptload = tonumber(kv[2])
          end
          settings_found = true
        elseif all_trim(kv[1]) == "HEADLESS" then
          extitonfinish = (tonumber(kv[2]) == 1)
          settings_found = true
        end
      end
    end
    return settings_found
  else
    return false
  end
end


function init()
  local status = "INIT"
  if not get_config() then
    status = "CRASH"
    if exitonfinish then
      emu.stop(1)
    end
    return
  end
  if not check_savestate(-1, true) then
     save_tas_state("CRASH")
    return
  end
  log("Saves loaded: " .. savestatecount)
  if savestatecount == 0 then
    show_message("Run TAS [R] to add savepoints.")
  end
  if file_exists(basedir) then
    if not file_exists(basedir .. "/" .. "savestates") then
      os.execute("mkdir " .. basedir .. "/" .. "savestates")
      log("Created directory for savestates")
    end
  end
  if onscriptload == -1 then
    set_to_load_minor = true
  elseif onscriptload == 0 then
    set_to_start = true
  elseif onscriptload > 0 then
    if onscriptload <= savestatecount then
      currentsave = onscriptload
      ssslot = onscriptload
      set_to_load_major = true
    else
      log("No such savestate!")
      status = "NOSTATE"
      if exitonfinish then
        emu.stop(1)
      end
    end
  end
  
  save_tas_state(status)
  
  emu.addEventCallback(run_tas, emu.eventType.inputPolled)
  emu.addEventCallback(start_frame, emu.eventType.startFrame)
  emu.addEventCallback(reset, emu.eventType.reset)
  show_message("TAS active!")
  show_message("Press H for help.")
end
  

state = emu.getState()

init()



