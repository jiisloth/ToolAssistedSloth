extends VBoxContainer

const keymap = {
    "TAS": "WASDGHKL",
    "NES": "ULDRCSBA"
    }



var has_state = false
var tas_state = {
    "status": WAIT,
    "last_update": OS.get_ticks_msec(),
    "do_read": false,
    "status_from_file": {
        "line": -1,
        "char": -1,
        "frame": -1,
        "wait": -1,
        "waitmax": 1,
        "status": "",
        "timestamp": 0,
        "input": ""
       }
   }

enum {
    NOFILE,
    WAIT,
    STOP,
    RUN,
    COULDNOTREAD,
    LOSING,
    LOST,
    PAUSE,
    CRASH,
    END
   }

const states = {
    NOFILE: {"text": "NO FILE", "color": Color("#db4161"), "description": "TAS-player status not found."},
    WAIT: {"text": "", "color": Color("#ffffff"), "description": "Waiting for TAS-player status."},
    STOP: {"text": "STOPPED", "color": Color("#fff392"), "description": "TAS-player stopped from editor."},
    RUN: {"text": "RUNNING", "color": Color("#a2f3a2"), "description": "TAS-player is running."},
    COULDNOTREAD: {"text": "RUNNING", "color": Color("#cbf382"), "description": "Could not read TAS-player status."},
    LOSING: {"text": "RUNNING", "color": Color("#ffdba2"), "description": "TAS-player status not updating."},
    LOST: {"text": "HALTED", "color": Color("#ff7930"), "description": "TAS-player stopped updating."},
    PAUSE: {"text": "PAUSED", "color": Color("#a2baff"), "description": "TAS-player paused by TAS command."},
    CRASH: {"text": "CRASHED", "color": Color("#db4161"), "description": "TAS-player crashed."},
    END: {"text": "FINISHED", "color": Color("#a2ffcb"), "description": "Playing TAS finished succesfully."},
   }

var running = false
var last_command = []

const scriptname = "ToolAssistedSloth"


var load_file_target = "TAS"

func _process(_delta):
    if Input.is_action_pressed("control"):
        if Input.is_action_just_pressed("save"):
            save_file()
        if Input.is_action_just_pressed("run"):
            fillCMDdata()
            _on_CMD_confirmed()
    if has_state:
        get_state()
    update_tas_status()
    if output:
        $Error/ErrorText.text = ""
        var popup = false
        for o in output:
            $Error/ErrorText.text += o
            if o.split("\n")[-1] == "Aborted":
                popup = true
        output = []
        if popup:
            var winsz = get_viewport_rect().size
            $Error.popup(Rect2(50, 50, winsz.x-100,winsz.y-100))
            
    if thread.is_alive():
        $Menu/HBoxContainer/Stop.show()
        $Menu/HBoxContainer/Run.hide()
        $Menu/HBoxContainer/Run.pressed = false
    else:
        $Menu/HBoxContainer/Stop.hide()
        $Menu/HBoxContainer/Run.show()
        $Menu/HBoxContainer/Stop.pressed = true
        

func _on_Load_pressed():
    if settings["autosave"] and $Editor/TextEdit.text != "":
        save_file()
    if $Top/HBoxContainer/Edited/Show.visible:
        var winsz = get_viewport_rect().size
        loading = true
        $Clear.popup(Rect2(200, 200, winsz.x-400,winsz.y-400))
    else:
        if settings["taspath"] != "":
            $Load.current_path = settings["taspath"] 
        load_file_target = "TAS"
        var winsz = get_viewport_rect().size
        $Load.popup(Rect2(50, 50, winsz.x-100,winsz.y-100))


func _on_FileDialog_file_selected(path):
    match load_file_target:
        "TAS":
            settings["taspath"] = path
            save_settings()
            open_file()
        "EMU":
            $CMD/VBoxContainer/EmulatorLoadEditLine/Emulator.text = path
        "ROM":
            $CMD/VBoxContainer/RomLoadEditLine/Rom.text = path
        "LUA":
            $CMD/VBoxContainer/LuaLoadEditLine/Lua.text = path
        "XTR":
            if $CMD/VBoxContainer/ExtraLoadEditLine/Extra.text == "":
                $CMD/VBoxContainer/ExtraLoadEditLine/Extra.text = path
            else:
                $CMD/VBoxContainer/ExtraLoadEditLine/Extra.text += " " + path
        "CFG":
            var conf = get_lua_conf(path, true)
            if conf:
                $CMD/VBoxContainer/LuaConf.text = conf

func set_load_filters():
    match load_file_target:
        "TAS":
            $Load.filters = PoolStringArray(["*.tas, *.txt ; TAS-files"])
        "EMU":
            $Load.filters = PoolStringArray(["*.exe ; Emulator"])
        "ROM":
            $Load.filters = PoolStringArray(["*.nes, *.zip, *.7z, *.fds, *.nsf, *.nsfe, *.unf, *.unif, *.studybox, *.ips, *.bps, *.ups ; Supported ROM-files"]) 
        "LUA":
            $Load.filters = PoolStringArray(["*.lua ; Lua TAS script"])
        "XTR":
            $Load.filters = PoolStringArray(["* ; Anything"])
        "CFG":
            $Load.filters = PoolStringArray(["*.cfg ; config giles"])

var default = {
    "taspath": "",
    "runcommand": {
        "pre": "",
        "emulator": "",
        "rom": "",
        "lua": "",
        "luaconf": "",
        "extra": "",
        "speed": "100",
        "headless": false
       },
    "autosave": true,
    "stayontop": true,
    "follow": true,
    "window": OS.window_size
   }

var settings

func open_file():
    var file = File.new()
    if file.file_exists(settings["taspath"]):
        file.open(settings["taspath"], File.READ)
        var txt = file.get_as_text()
        file.close()
        $Editor/TextEdit.text = txt
        $Top/HBoxContainer/File.text = settings["taspath"].get_file()
        $Editor/TextEdit.update_marks()
        get_state_file()
    else:
        settings["taspath"] = ""
        $Editor/TextEdit.text = ""
        $Top/HBoxContainer/File.text = "TASeditor"
        $Editor/TextEdit.update_marks()
        has_state = false
        save_settings()


func save_file():
    if settings["taspath"] == "":
        var winsz = get_viewport_rect().size
        $SaveAs.popup(Rect2(50, 50, winsz.x-100,winsz.y-100))
        return
    $Top/HBoxContainer/Edited/Show.hide()
    var file = File.new()
    file.open(settings["taspath"], File.WRITE)
    file.store_string($Editor/TextEdit.text)
    file.close()
   

func _ready():
    $CMD.get_cancel().connect("pressed", self, "cancelled")
    load_settings()
    if settings["taspath"] != "":
        $Load.current_path = settings["taspath"] 
        $SaveAs.current_path = settings["taspath"] 
    OS.window_size = settings["window"]
    $Menu/HBoxContainer/AutoSave.pressed = settings["autosave"]
    $Menu/HBoxContainer/Follow.pressed = settings["follow"]
    $Editor/TextEdit.follow = settings["follow"]
    $Editor/TextEdit.update_marks()
    update_status_monitor()
    
    
func save_settings():
    var file = File.new()
    file.open("user://settings.json", File.WRITE)
    file.store_var(settings)
    file.close()



func load_settings():
    var file = File.new()
    if file.file_exists("user://settings.json"):
        file.open("user://settings.json", File.READ)
        settings = file.get_var()
        file.close()
        settings = checkdata(default, settings)
                    
        open_file()
    else:
        settings = default.duplicate()

func checkdata(d,s):
    for key in d.keys():
        if not key in s.keys():
            s[key] = d[key]
        else:
            if typeof(d[key]) != typeof(s[key]):
                s[key] = d[key]
            elif typeof(d[key]) == TYPE_DICTIONARY:
                s[key] = checkdata(d[key], s[key])
    return s

func _on_Main_resized():
    if settings:
        settings["window"] = OS.window_size
        save_settings()


func _on_Save_pressed():
    save_file()

func _on_SaveAs_file_selected(path):
    settings["taspath"] = path
    $Top/HBoxContainer/File.text = settings["taspath"].get_file()
    save_settings()
    save_file()
    get_state_file()


func _on_SaveAs_pressed():
    var winsz = get_viewport_rect().size
    $SaveAs.popup(Rect2(50, 50, winsz.x-100,winsz.y-100))



func _on_AutoSave_toggled(button_pressed):
    settings["autosave"] = button_pressed
    save_settings()
    
    
func _notification(what):
    if what == MainLoop.NOTIFICATION_WM_FOCUS_IN:
        pass
    elif what == MainLoop.NOTIFICATION_WM_FOCUS_OUT:
        if settings["autosave"]:
            save_file()
        if settings["stayontop"]:
            OS.set_window_always_on_top(false)
    if what == MainLoop.NOTIFICATION_WM_QUIT_REQUEST or what == MainLoop.NOTIFICATION_WM_GO_BACK_REQUEST:
        clear_script_conf_override(get_conf_path())

func _on_Quit_pressed():
    if settings["autosave"]:
        save_file()
    if $Top/HBoxContainer/Edited/Show.visible:
        var winsz = get_viewport_rect().size
        $AcceptDialog.popup(Rect2(200, 200, winsz.x-400,winsz.y-400))      
    else:
        get_tree().quit()


func _on_AcceptDialog_confirmed():
    get_tree().quit()


func _on_New_pressed():
    if settings["autosave"] and $Editor/TextEdit.text != "":
        save_file()
    if $Top/HBoxContainer/Edited/Show.visible:
        var winsz = get_viewport_rect().size
        loading = false
        $Clear.popup(Rect2(200, 200, winsz.x-400,winsz.y-400))
    else:
        $Editor/TextEdit.text = ""
        var winsz = get_viewport_rect().size
        $SaveAs.popup(Rect2(50, 50, winsz.x-100,winsz.y-100))


var loading = false


func _on_Clear_confirmed():
    if loading:
        if settings["taspath"] != "":
            $Load.current_path = settings["taspath"] 
        load_file_target = "TAS"
        set_load_filters()
        var winsz = get_viewport_rect().size
        $Load.popup(Rect2(50, 50, winsz.x-100,winsz.y-100))
    else:
        $Editor/TextEdit.text = ""
        var winsz = get_viewport_rect().size
        $SaveAs.popup(Rect2(50, 50, winsz.x-100,winsz.y-100))
        

func get_state_file():
    var statepath = settings["taspath"].get_base_dir() + "/state.dat"
    var file = File.new()
    if file.file_exists(statepath):
        has_state = statepath
    else:
        $Bottom/Bottom/Status.text = ""
        has_state = false
        tas_state["status"] = NOFILE
        
func get_state():
    var file = File.new()
    if file.file_exists(has_state):
        var text = ""
        var err = file.open(has_state, File.READ)
        if file.get_len() > 0 and err == 0:
            text = file.get_as_text()
        file.close()
        if text:
            var result_json = JSON.parse(text) 
            if result_json.error == OK: 
                set_running_status(result_json.result)
                return
        
        if tas_state["status"] in [RUN, LOSING]:
            tas_state["status"] = COULDNOTREAD
    else:
        $Bottom/Bottom/Status.text = ""
        has_state = false
        tas_state["status"] = NOFILE


func set_running_status(state):
    for key in tas_state["status_from_file"].keys():
        if not key in state.keys():
            return
    if OS.get_unix_time() - int(state["timestamp"]) > 5:
        return #File is old af.
    var charline = $Editor/TextEdit.get_actual_charline(state["char"],state["line"])
    state["char"] = charline.x
    state["line"] = charline.y
    tas_state["status_from_file"] = state
    tas_state["last_update"] = OS.get_ticks_msec()
    tas_state["do_read"] = true
    
    
func update_tas_status():
    var state = tas_state["status_from_file"] 
    if not state["status"]:
        return #no status yet
    if not tas_state["do_read"]:
        if OS.get_ticks_msec() - tas_state["last_update"] > 100:
            if OS.get_ticks_msec() - tas_state["last_update"] > 500:
                if tas_state["status"] in [RUN, LOSING, COULDNOTREAD]:
                    tas_state["status"] = LOST
                    update_status_monitor()
            else:
                if tas_state["status"] in [RUN]:
                    tas_state["status"] = LOSING
                    update_status_monitor()
        return
    
    tas_state["do_read"] = false
    match state["status"]:
        "NOSTATE":
            tas_state["status"] = CRASH
        "NOQSTATE":
            tas_state["status"] = CRASH
        "CRASH":
            tas_state["status"] = CRASH
        "INIT":
            tas_state["status"] = WAIT
        "RUN":
            tas_state["status"] = RUN
        "PAUSE":
            tas_state["status"] = PAUSE
        "EOF":
            tas_state["status"] = END
    update_status_monitor()
    
    for label in $Bottom/Bottom/RunHolds.get_children():
        if keymap["NES"][keymap["TAS"].find(label.name)] in state["input"]:
            label.modulate = Color("#FFFFFFFF")
        else:
            label.modulate = Color("#99222222")
    $Bottom/Bottom/RunningPos/Line.text = str(state["line"]+1)
    $Bottom/Bottom/RunningPos/Char.text = str(state["char"])
    $Bottom/Bottom/RunningFrame/Frame.text = str(state["frame"])
    if state["wait"] > 0:
        $Bottom/Bottom/Wait.text = str(state["wait"])
        $Bottom/Bottom/Wait/ProgressBar.value = state["waitmax"]-state["wait"]
        $Bottom/Bottom/Wait/ProgressBar.max_value = state["waitmax"]
    else:
        $Bottom/Bottom/Wait.text = ""
        $Bottom/Bottom/Wait/ProgressBar.value = 0
        
    $Editor/TextEdit.set_rolling_line(state["line"], state["char"], state["wait"],state["waitmax"])


func update_status_monitor():
    if tas_state["status"] in [WAIT, NOFILE]:
        $Bottom/Bottom/RunningPos.modulate = Color("#666666")
        $Bottom/Bottom/RunningFrame.modulate = Color("#666666")
    elif tas_state["status"] == CRASH:
        $Bottom/Bottom/RunningPos.modulate = Color("#FF6666")
        $Bottom/Bottom/RunningFrame.modulate = Color("#FF6666")
    else:
        $Bottom/Bottom/RunningPos.modulate = Color("#FFFFFF")
        $Bottom/Bottom/RunningFrame.modulate = Color("#FFFFFF")
    var s = states[tas_state["status"]]
    $Bottom/Bottom/Status.text = s["text"]
    $Bottom/Bottom/Status.add_color_override("font_color", s["color"])
    $Bottom/Bottom/Status/Tooltip.text = s["description"]
    

func _on_Follow_toggled(button_pressed):
    $Editor/TextEdit.follow = button_pressed
    if button_pressed:
        $Editor/TextEdit.go_to_rolling()
    settings["follow"] = button_pressed
    save_settings()


func _on_MajorSaveTogle_toggled(button_pressed):
    if button_pressed:
        $Editor/TextEdit.replace_non_comment("!",":")
    else:
        $Editor/TextEdit.replace_non_comment(":","!")



func _on_MinorSaveTogle_toggled(button_pressed):
    if button_pressed:
        $Editor/TextEdit.replace_non_comment("?",";")
    else:
        $Editor/TextEdit.replace_non_comment(";","?")




func get_emu_folder():
    if settings["runcommand"]["emulator"] == "":
        var mpos = settings["taspath"].to_lower().find_last("mesen")
        if mpos >= 0:
            var spos = settings["taspath"].to_lower().find("/", mpos)
            if spos >= 0:
                return settings["taspath"].substr(0,spos) + "/"
    else:
        return settings["runcommand"]["emulator"].get_base_dir() + "/"
    return ""
    
func look_for_lua(weak=false):
    for path in [settings["taspath"], settings["runcommand"]["emulator"], settings["runcommand"]["rom"], settings["runcommand"]["lua"]]:
        var dir = Directory.new()
        if "ToolAssistedSloth/" in path:
            var luapath = path.split("ToolAssistedSloth/")[0] + "ToolAssistedSloth/"
            if dir.dir_exists(luapath):
                if dir.dir_exists(luapath + "TASplayer/"):
                    luapath += "TASplayer/"
                    if dir.file_exists(luapath + scriptname + ".lua"):
                        luapath += scriptname + ".lua"
                        return luapath
                    elif weak:
                        return luapath + " >INSERT LUA FILE PATH ("+ scriptname + ".lua ?)<"
                elif dir.file_exists(luapath + scriptname + ".lua"):
                    luapath += scriptname + ".lua"
                    return luapath
                elif weak:
                    return luapath + " >INSERT LUA FILE PATH ("+ scriptname + ".lua ?)<"
        if "TASplayer/" in path:
            var luapath = path.split("TASplayer/")[0] + "TASplayer/"
            if dir.dir_exists(luapath):
                if dir.file_exists(luapath + scriptname + ".lua"):
                    luapath += scriptname + ".lua"
                    return luapath
                elif weak:
                    return luapath + " >INSERT LUA FILE PATH ("+ scriptname + ".lua ?)<"
    if not weak:
        look_for_lua(true)        
    return ""

func fillCMDdata():
    $CMD/VBoxContainer/Command.text = settings["runcommand"]["pre"]
    var mesenfolder = get_emu_folder() 
    if settings["runcommand"]["emulator"] == "":
        if OS.get_name() == "X11" and settings["runcommand"]["pre"] == "":
            $CMD/VBoxContainer/Command.text = "mono"
        if mesenfolder != "":
            var dir = Directory.new()
            if dir.file_exists(mesenfolder + "Mesen.exe"):
                $CMD/VBoxContainer/EmulatorLoadEditLine/Emulator.text = mesenfolder + "Mesen.exe"
            else:
                $CMD/VBoxContainer/EmulatorLoadEditLine/Emulator.text = mesenfolder + " >INSERT EMULATOR PATH<"
        else:
            $CMD/VBoxContainer/EmulatorLoadEditLine/Emulator.text = ""
    else:
        $CMD/VBoxContainer/EmulatorLoadEditLine/Emulator.text = settings["runcommand"]["emulator"]
    if settings["runcommand"]["rom"] == "":
        if mesenfolder != "":
            $CMD/VBoxContainer/RomLoadEditLine/Rom.text = mesenfolder + " >INSERT ROM PATH<"
        else:
            $CMD/VBoxContainer/RomLoadEditLine/Rom.text = ""
    else:
        $CMD/VBoxContainer/RomLoadEditLine/Rom.text = settings["runcommand"]["rom"]
    if settings["runcommand"]["lua"] == "":
        $CMD/VBoxContainer/LuaLoadEditLine/Lua.text = look_for_lua()
    else:
        $CMD/VBoxContainer/LuaLoadEditLine/Lua.text = settings["runcommand"]["lua"]
    if settings["runcommand"]["luaconf"] == "":
        $CMD/VBoxContainer/LuaConf.text = get_lua_conf(get_conf_path())
    else:
        $CMD/VBoxContainer/LuaConf.text = settings["runcommand"]["luaconf"]
    $CMD/VBoxContainer/States.text = "Current TAS file contains " + str($Editor/TextEdit.savecount) + " states"
    $CMD/VBoxContainer/ExtraLoadEditLine/Extra.text = settings["runcommand"]["extra"]
    $CMD/VBoxContainer/Speed.value = int(settings["runcommand"]["speed"])
    $CMD/VBoxContainer/Headless/Headless.pressed = settings["runcommand"]["headless"]

func get_conf_path():
    return get_emu_folder() + "LuaScriptData/" + settings["runcommand"]["lua"].get_file().split(".lua")[0] + "/script.cfg"

            
func get_lua_conf(confpath, weak=false):
    var file = File.new()
    if file.file_exists(confpath):
        print("found conf")
        file.open(confpath, File.READ)
        var txt = file.get_as_text()
        file.close()
        txt = txt.strip_edges()
        if weak:
            return txt
        var newtxt = ""
        for line in txt.split("\n"):
            if "TASFILE=" in line:
                var end = line.split("#", true, 1)
                if len(end) == 2:
                    end = "#" + end[1]
                else:
                    end = ""
                newtxt += "TASFILE="+settings["taspath"].get_file()+end +"\n"
            elif "BASEDIR=" in line:
                var end = line.split("#", true, 1)
                if len(end) == 2:
                    end = "#" + end[1]
                else:
                    end = ""
                newtxt += "BASEDIR="+settings["taspath"].get_base_dir()+end +"\n"
            else:
                newtxt += line + "\n"
        return newtxt
    elif weak:
        return false
    else:
        return "BASEDIR=" + settings["taspath"].get_base_dir() + "\n# Path to tas folder containing TASfile, savestates etc.\nTASFILE=" + settings["taspath"].get_file() + "\n# TASfilename\nPRINTLOG=1\n# Print log to emulator console\nDRAWONSCREEN=1\n# Draw debug/control strings on screen\nDISPLAYMESSAGES=1\n# Display popup messages about script status\nONSCRIPTLOAD=0\n# -2  Do not run TAS on load.\n# -1: Load latest Quicksave.\n# 0: Start TAS from start.\n# 1-N load savestate X"

var thread = Thread.new()
var output = []

func run_emu():
    if settings["autosave"]:
        save_file()
    
    if thread.is_alive():
        kill_emulator()
        var _r = thread.wait_to_finish()

    if thread.is_alive():
        print("thread still alive..")
    write_script_conf_override(get_conf_path())
    $ClearConf.start()
    last_command = settings["runcommand"]
    
    if settings["stayontop"]:
        OS.set_window_always_on_top(true)
    thread = Thread.new()
    thread.start(self, "run_emu_thread")


func run_emu_thread():   
    var com = settings["runcommand"]
    
    var prog
    var params = [com["emulator"], com["rom"], com["lua"], com["extra"], "--testrunner", "--EmulationSpeed=" + com["speed"]]
    
    if not com["headless"]:
        params.erase("--testrunner")
        
    if com["pre"] != "":
        prog = com["pre"]
    else:
        prog = com["emulator"]
        params.erase(com["emulator"])
    
    var o = []
    running = OS.execute(prog, params, true, o, true, true)
    output = o


func write_script_conf_override(confpath):
    var conf = settings["runcommand"]["luaconf"]
    if settings["runcommand"]["headless"]:
        conf += "\nHEADLESS=1"
    var file = File.new()
    file.open(confpath, File.WRITE)
    file.store_string(conf)
    file.close()
    

func kill_emulator():
    var o = []
    var grep = last_command["emulator"] + " " + last_command["rom"] + " " + last_command["lua"]
    var _r = OS.execute("ps", ["aux"], true, o)
    for out in o:
        for line in out.split("\n"):
            if grep in line:
                var _k = OS.kill(int(line.split(" ", false)[1]))

   
func clear_script_conf_override(confpath):
    var file = File.new()
    file.open(confpath, File.WRITE)
    file.store_string("# DO NOT USE THIS FOR CONFIG")
    file.close()
    

func _on_CMD_confirmed():
    var command = $CMD/VBoxContainer/Command.text.strip_edges()
    var emulatorpath = $CMD/VBoxContainer/EmulatorLoadEditLine/Emulator.text
    var rompath = $CMD/VBoxContainer/RomLoadEditLine/Rom.text
    var luapath = $CMD/VBoxContainer/LuaLoadEditLine/Lua.text
    var luaconf = $CMD/VBoxContainer/LuaConf.text
    var extra = $CMD/VBoxContainer/ExtraLoadEditLine/Extra.text
    var speed = $CMD/VBoxContainer/Speed.value
    var headless = $CMD/VBoxContainer/Headless/Headless.pressed
    var error = false
    var file = File.new()
    if file.file_exists(emulatorpath):
        $CMD/VBoxContainer/EmulatorLabel/Error.hide()
    else:
        $CMD/VBoxContainer/EmulatorLabel/Error.show()
        error = true
    if file.file_exists(rompath):
        $CMD/VBoxContainer/RomLabel/Error.hide()
    else:
        $CMD/VBoxContainer/RomLabel/Error.show()
        error = true
    if file.file_exists(luapath):
        $CMD/VBoxContainer/LuaLabel/Error.hide()
    else:
        $CMD/VBoxContainer/LuaLabel/Error.show()
        error = true
    error = error or !check_luaconf(headless, luaconf)
    if error:
        var winsz = get_viewport_rect().size
        $CMD.popup(Rect2(50, 50, winsz.x-100,winsz.y-100))
    else:
        settings["runcommand"] = {
            "pre": command,
            "emulator": emulatorpath,
            "rom": rompath,
            "lua": luapath,
            "luaconf": luaconf,
            "extra": extra,
            "speed": str(speed),
            "headless": headless
            }
        save_settings()
        run_emu()
        
func check_luaconf(h, conf):
    $CMD/VBoxContainer/LuaConfLabel/Error2.hide()
    if h:
        for line in conf:
            if "ONSCRIPTLOAD" in line:
                var num = int(line.split("=")[1])
                if num == -2:
                    $CMD/VBoxContainer/LuaConfLabel/Error2.show()
                    return false
    return true

func _on_ClearConf_timeout():
    OS.set_window_always_on_top(false)


func _on_Run_toggled(button_pressed):
    if button_pressed:
        fillCMDdata()
        var winsz = get_viewport_rect().size
        $CMD.popup(Rect2(50, 50, winsz.x-100,winsz.y-100))
        $Menu/HBoxContainer/Run.hide()
        $Menu/HBoxContainer/Stop.show()
        $Menu/HBoxContainer/Stop.pressed = true

        


func _on_Stop_toggled(button_pressed):
    if not button_pressed:
        if thread.is_alive():
            kill_emulator()
            var _r = thread.wait_to_finish()
        clear_script_conf_override(get_conf_path())
        $Menu/HBoxContainer/Stop.hide()
        $Menu/HBoxContainer/Run.show()
        $Menu/HBoxContainer/Run.pressed = false
        

        
func _on_LoadEmulator_pressed():
    var current = $CMD/VBoxContainer/EmulatorLoadEditLine/Emulator.text.split(">")[0]
    var dir = Directory.new()
    if current != "" and (dir.file_exists(current) or dir.dir_exists(current)):
        $Load.current_path = current 
    elif settings["runcommand"]["emulator"] != "":
        $Load.current_path = settings["runcommand"]["emulator"]  
    elif settings["taspath"] != "" and $Load.current_path == "":
        $Load.current_path = settings["taspath"].get_base_dir() 
    load_file_target = "EMU"
    set_load_filters()
    var winsz = get_viewport_rect().size
    $Load.popup(Rect2(50, 50, winsz.x-100,winsz.y-100))


func _on_LoadRom_pressed():
    var current = $CMD/VBoxContainer/RomLoadEditLine/Rom.text.split(">")[0]
    var dir = Directory.new()
    if current != "" and (dir.file_exists(current) or dir.dir_exists(current)):
        $Load.current_path = current 
    elif settings["runcommand"]["rom"] != "":
        $Load.current_path = settings["runcommand"]["rom"]  
    elif settings["taspath"] != "" and $Load.current_path == "":
        $Load.current_path = settings["taspath"].get_base_dir() 
    load_file_target = "ROM"
    set_load_filters()
    var winsz = get_viewport_rect().size
    $Load.popup(Rect2(50, 50, winsz.x-100,winsz.y-100))


func _on_LoadLua_pressed():
    var current = $CMD/VBoxContainer/LuaLoadEditLine/Lua.text.split(">")[0]
    var dir = Directory.new()
    if current != "" and (dir.file_exists(current) or dir.dir_exists(current)):
        $Load.current_path = current 
    elif settings["runcommand"]["lua"] != "":
        $Load.current_path = settings["runcommand"]["lua"]  
    elif settings["taspath"] != "" and $Load.current_path == "":
        $Load.current_path = settings["taspath"].get_base_dir() 
    load_file_target = "LUA"
    set_load_filters()
    var winsz = get_viewport_rect().size
    $Load.popup(Rect2(50, 50, winsz.x-100,winsz.y-100))


func _on_LoadExtra_pressed():
    if settings["runcommand"]["lua"] != "":
        $Load.current_path = settings["runcommand"]["lua"].get_base_dir() 
    elif settings["taspath"] != "" and $Load.current_path == "":
        $Load.current_path = settings["taspath"].get_base_dir() 
    load_file_target = "XTR"
    set_load_filters()
    var winsz = get_viewport_rect().size
    $Load.popup(Rect2(50, 50, winsz.x-100,winsz.y-100))


func _on_LoadConf_pressed():
    var p = ""
    if settings["runcommand"]["lua"] != "":
        p = get_conf_path()
    elif $CMD/VBoxContainer/LuaLoadEditLine/Lua.text != "":
        p= get_emu_folder() + "LuaScriptData/" + $CMD/VBoxContainer/LuaLoadEditLine/Lua.text.get_file().split(".lua")[0] + "/script.cfg"
    elif settings["taspath"] != "" and $Load.current_path == "":
        p = settings["taspath"].get_base_dir() 
    var dir = Directory.new()
    if p != "" and (dir.file_exists(p) or dir.dir_exists(p)):
        $Load.current_path = p
    load_file_target = "CFG"
    set_load_filters()
    var winsz = get_viewport_rect().size
    $Load.popup(Rect2(50, 50, winsz.x-100,winsz.y-100))

func cancelled():
    $Menu/HBoxContainer/Run.pressed = false





func _on_Status_mouse_entered():
    if $Bottom/Bottom/Status/Tooltip.text == "":
        $Bottom/Bottom/Status/Tooltip.show()


func _on_Tooltip_mouse_exited():
    $Bottom/Bottom/Status/Tooltip.hide()
