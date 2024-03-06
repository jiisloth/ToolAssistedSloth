extends TextEdit

var linewas = 0
var follow = true
var savecount = 0
var cursor_pos = Vector2(0,0)

enum e {
    WAITTOPAST,
    UNDEFINEDCHAR,
    INPUTON,
    INPUTNOTON,
    INVALIDWAIT,
    INVALIDHOLD,
    INCOMPLETECOMMAND,
    INVALIDBUNDLE,
   }

var errors = {
    e.WAITTOPAST: {"at": [], "description": "Waiting for a frame that is already gone."},
    e.UNDEFINEDCHAR: {"at": [], "description": "Undefined character."},
    e.INPUTON: {"at": [], "description": "Pressing input already on hold."},
    e.INPUTNOTON: {"at": [], "description": "Trying to unhold nonpressed input."},
    e.INCOMPLETECOMMAND: {"at": [], "description": "Incomplete command."},
    e.INVALIDBUNDLE: {"at": [], "description": "Invalid bundle."},
    e.INVALIDWAIT: {"at": [], "description": "Invalid wait."},
    e.INVALIDHOLD: {"at": [], "description": "Invalid hold modifier."}
   }

var line_height = 0
var absolute_line_count = 0

var linestats = []
const default_line = {
    "delay": {"line": 0, "cumulative": 0},
    "errors": [],
    "holds": {
        "W":{"on": false, "set": Vector2()},
        "A":{"on": false, "set": Vector2()},
        "S":{"on": false, "set": Vector2()},
        "D":{"on": false, "set": Vector2()},
        "G":{"on": false, "set": Vector2()},
        "H":{"on": false, "set": Vector2()},
        "K":{"on": false, "set": Vector2()},
        "L":{"on": false, "set": Vector2()}},
    "flags": [],
    "wraps": 0,
    "savecount": 0,
    "marks": {"!": [], "?": [], "X": []},
   }

onready var Bottom = get_parent().get_parent().get_node("Bottom/Bottom")
onready var Top = get_parent().get_parent().get_node("Top/HBoxContainer")
onready var Main = get_parent().get_parent()
onready var Side = get_parent().get_node("ColorRect/Side")

enum mod {
    CANHOLD,
    CANBUNLDE,
    DOFLAG,
    EXTRA,
    DELAY,
    MARK,
    WAITPARAM
    CLEARALLFLAGS
   }

const extraflags = ["-[","+["]
const chartypes = {
    "input": {
        "char": "WASDGHKL", 
        "modifiers":[mod.CANHOLD, mod.CANBUNLDE, mod.DELAY, mod.DOFLAG],
        "actions": {
            "in": {
                "onflag": {
                    "+": {"type": "addhold"},
                    "+[": {"type": "addhold"},
                    "-": {"type": "removehold"},
                    "-[": {"type": "removehold"}
                    }
                }
            }
        },
    "singlewait": {
        "char": ".:;",
        "modifiers":[mod.DELAY],
        "actions": {}
        },
    "multiwait": {
        "char": "@%",
        "modifiers":[mod.DOFLAG, mod.CLEARALLFLAGS],
        "actions": {
            "out": {
                "noflag": {
                    "numerals": {"type": "error", "error": e.INVALIDWAIT}
                    },
                "onflag": {
                    "numerals": {"type": "setwait"}
                    }
                }
            }
        },
    "numerals": {
        "char": "0123456789",
        "modifiers":[mod.DOFLAG, mod.WAITPARAM],
        "actions": {
            "in": {
                "noflag": {
                    "multiwait": {"type": "error", "error": e.INVALIDWAIT}
                    }
                }
            }
        },
    "save": {
        "char": "!?",
        "modifiers":[mod.DELAY, mod.MARK],
        "actions": {}
        },
    "bundleopen": {
        "char": "[",
        "modifiers":[mod.DOFLAG, mod.CANHOLD, mod.CLEARALLFLAGS],
        "actions": {
            "flagneeds": [mod.CANBUNLDE],
            "in": {
                "onflag": {
                    "+": {"type": "addflag", "flag": "+["},
                    "-": {"type": "addflag", "flag": "-["},
                    }
                }
            }
        },
    "bundleclose": {
        "char": "]",
        "modifiers":[mod.DELAY, mod.CLEARALLFLAGS, mod.CANBUNLDE],
        "actions": {
            "in": {
                "noflag": {
                    "bundleopen": {"type": "error", "error": e.INVALIDBUNDLE},
                    "input": {"type": "error", "error": e.INVALIDBUNDLE}
                    }
                }
            }
        },
    "hold": {
        "char": "+-",
        "modifiers":[mod.CANBUNLDE, mod.DOFLAG],
        "actions": {
            "flagneeds": [mod.CANHOLD],
            "in": {
                "onflag": {
                    "+[": {"type": "error", "error": e.INVALIDHOLD},
                    "-[": {"type": "error", "error": e.INVALIDHOLD},
                   }
               },
            "out": {
                "noflags": { 
                    "flags": ["bundleopen", "input", "all"],
                    "do": {"type": "error", "error": e.INVALIDHOLD}
                    }
                }
            }
        },
    "interrupt": {
        "char": "X",
        "modifiers":[mod.MARK],
        "actions": {}
        },
    "all": {
        "char": "$",
        "modifiers":[mod.CANHOLD, mod.DELAY, mod.CANBUNLDE],
        "actions": {
            "in": {
                "noflag": { 
                    "hold": {"type": "error", "error": e.INVALIDHOLD}
                    },
                "onflag": {
                    "+": {"type": "fillhold"},
                    "-": {"type": "clearhold"}
                    }
                }
            }
        },
    "fillers": {
        "char": " ",
        "modifiers":[],
        "actions": {}
        },
    "comment": {
        "char": "#",
        "modifiers":[],
        "actions": {}
        },
   }

var char_actions = {}
var flag_needs = {}

var keymap = {
    "W": "up",
    "A": "left",
    "S": "down",
    "D": "right",
    "G": "select",
    "H": "start",
    "K": "B",
    "L": "A"
   }

var clrs = {
    "up": Color("#92d3ff"),
    "down": Color("#ffbaeb"),
    "left": Color("#c3b2ff"),
    "right": Color("#ffdba2"),
    "A": Color("#71f341"),
    "B": Color("#61d3e3"),
    "start": Color("#ebd320"),
    "select": Color("#ffa200"),
    "stop": Color("#db4161"),
    "comment": Color("#9a2079"),
    "wait": Color("#f361ff"),
    "waitto": Color("#ff7930"),
    "bundle": Color("#61d3e3"),
    "runwait": Color("#9aeb00"),
    "runsave": Color("#f361ff"),
    "runstop": Color("#ff7930"),
    "rundefault": Color("#fff392"),
   }


func make_char_actions():
    for type in chartypes.keys():
        var properties = chartypes[type].duplicate(true)
        properties.erase("char")
        properties["type"] = type
        for c in chartypes[type]["char"]:
            char_actions[c] = properties.duplicate(true)
            
        


func _ready():
    line_height = get_line_height()
    add_keyword_color("W", clrs["up"])
    add_keyword_color("A", clrs["left"])
    add_keyword_color("S", clrs["down"])
    add_keyword_color("D", clrs["right"])
    add_keyword_color("L", clrs["A"])
    add_keyword_color("K", clrs["B"])
    add_keyword_color("X", clrs["stop"])
    add_keyword_color("G", clrs["select"])
    add_keyword_color("H", clrs["start"])
    add_keyword_color("w", clrs["up"])
    add_keyword_color("a", clrs["left"])
    add_keyword_color("s", clrs["down"])
    add_keyword_color("d", clrs["right"])
    add_keyword_color("l", clrs["A"])
    add_keyword_color("k", clrs["B"])
    add_keyword_color("x", clrs["stop"])
    add_keyword_color("g", clrs["select"])
    add_keyword_color("h", clrs["start"])
    add_color_region("#", " ", clrs["comment"], true)
    update_marks()
    for label in Bottom.get_node("Holds").get_children():
        label.add_color_override("font_color", clrs[keymap[label.name]])
    for label in Bottom.get_node("RunHolds").get_children():
        label.add_color_override("font_color", clrs[keymap[label.name]])
    $Runpos.margin_left = $Runpos.margin_right
    



func _on_TextEdit_text_changed():
    $Runpos.margin_left = $Runpos.margin_right
    Top.get_node("Edited/Show").show()
    update_marks()

var set_to_update = false 
func _process(_delta):
    var alc = get_absolute_line_count()
    if alc != absolute_line_count or set_to_update:
        set_to_update = false
        absolute_line_count = alc
        update_side()
        #update_line_stats() #SLOW AS FUCK.
    Side.scroll_to_line(scroll_vertical)


func get_absolute_line_count():
    var lines = 0
    for i in get_line_count():
        lines += 1
        lines += get_line_wrap_count(i)
    return lines

func set_framecounts(total=false):
    var selected = get_selection_text()
    var current_line = get_line(cursor_get_line())
    var l = Top.get_node("Line")
    var s = Top.get_node("Selected")
    var t = Top.get_node("Total")
    if len(selected) > 0:
        set_delay(s, selected)
        s.show()
        l.hide()
    else:
        set_delay(l, current_line)
        l.show()
        s.hide()
    if total:
        set_delay(t, text, total)
        
func set_delay(node, txt, full=false):
    var frames = get_frames(txt, full)
    node.get_child(1).text = "%df" % frames
    node.get_child(2).text = "%.2fs" % (frames/60.098814)

func get_frames(txt, full=false):
    if full:
        pass
    var lines = txt.split("\n")
    var frames = 0
    for line in lines:
        var bundle = false
        var wait = false
        var waitto = false
        var wframes = ""
        for c in line:
            c = c.to_upper()
            if not c in "0123456789":
                if wait:
                    wait = false
                    frames += int(wframes)
                if waitto:
                    wait = false
                    frames = max(int(wframes), frames)
                wframes = ""
            if c == "#":
                break
            if c == "[":
                frames += 1
                bundle = true
            elif c == "]":
                bundle = false
            elif not bundle:
                if c in "WASDGHKL.?!;:":
                    frames += 1
                elif c == "%":
                    wait = true
                elif c == "@":
                    waitto = true
                elif c in "0123456789" and (wait or waitto):
                    wframes += c
        if wframes != "":
            frames += int(wframes)
    return frames
        
var holds = {"W":false,"A":false,"S":false,"D":false,"G":false,"H":false,"K":false,"L":false}

func print_line_data(i):
    if i >= len(linestats):
        return
    var data = linestats[i]
    print("\nLine: " + str(i) + " >" + get_line(i))
    print("Delay: " + str(linestats[i]["delay"]["line"]) + "/" + str(linestats[i]["delay"]["cumulative"]))
    var holdstring = ""
    for k in data["holds"].keys():
        if data["holds"][k]["on"]:
            holdstring += k
        else:
            holdstring += " "
    print("Holds: " + holdstring)
    var flagstring = ""
    for flag in data["flags"]:
        flagstring+= flag["flag"]
    print("Flags: " + flagstring)
    print("Wraps: " + str(data["wraps"]))
    print("Savecount: " + str(data["savecount"]))
    print("Marks: " + str(data["marks"]))
    print("Errors:")
    for error in data["errors"]:
        if "from" in error.keys():
            print("  " + errors[error["type"]]["description"]  + " at: " + str(error["at"]) + "from: " + str(error["from"]))
        else:
            print("  " + errors[error["type"]]["description"] + " at: " + str(error["at"]))
            
    
var calcount = 0
func update_line_stats():
    calcount += 1
    print("called "+ str(calcount))
    linestats = []
    for i in get_line_count():
        linestats.append(get_line_info(i))
        
func get_line_info(i, to=-1):
    var line = get_line(i).split("#")[0] + " "
    var line_info = default_line.duplicate(true)
    
    
    if i > 0:
        var prev_info = linestats[i-1]
        line_info["holds"] = prev_info["holds"].duplicate(true)
        line_info["savecount"] = prev_info["savecount"]
        line_info["delay"]["cumulative"] = prev_info["delay"]["cumulative"]
    if to == -1:
        to = len(line)
    line_info["wraps"] = get_line_wrap_count(i)
    for j in len(line):
        var pos = Vector2(j,i)
        var c = line[j].to_upper()
        if not c in char_actions.keys():
            line_info["errors"].append({"type": e.UNDEFINEDCHAR, "at": j}) 
            continue
        var ct = char_actions[c]
            
        # Check flag needs
        for f in line_info["flags"]:
            for need in get_action(f["flag"], "flagneeds", []):
                if not need in ct["modifiers"]:
                    line_info["errors"].append({"type": e.INCOMPLETECOMMAND, "at": j, "from": f["set"]})
        # get in actions:
        var actions = get_flag_actions(c, "in", line_info["flags"])
        
        # check hold fails:
        if c in chartypes["input"]["char"]:
            var minus = false
            for f in line_info["flags"]:
                if f["flag"] in ["-", "-["]:
                    minus = true
                    break
            if line_info["holds"][c]["on"] and not minus:
                line_info["errors"].append({"type": e.INPUTON, "at": j, "from": line_info["holds"][c]["set"]})
            elif not line_info["holds"][c]["on"] and minus:
                line_info["errors"].append({"type": e.INPUTNOTON, "at": j, "from": line_info["holds"][c]["set"]})
        

        # Do clears:
        var cleared_flags = []
        for f in line_info["flags"]:
            if f["flag"] in chartypes["hold"]["char"] or mod.CLEARALLFLAGS in ct["modifiers"] or i == len(line)-1 or ((not c in chartypes["numerals"]["char"]) and (f["flag"] in chartypes["multiwait"]["char"] or f["flag"] in chartypes["numerals"]["char"])):
                actions += get_flag_actions(f["flag"], "out", line_info["flags"])
                cleared_flags.append(f)
        for f in cleared_flags:
            line_info["flags"].erase(f)
        
        # Add flags:
        if mod.DOFLAG in ct["modifiers"]:
            line_info["flags"].append({"flag":c,"set":pos})
        # Add delay:
        if mod.DELAY in ct["modifiers"] and not flag_in_flags("[", line_info["flags"]):
            line_info["delay"]["line"] += 1
            line_info["delay"]["cumulative"] += 1
        # Add marks:
        if mod.MARK in ct["modifiers"]:
            line_info["marks"][c].append(i)
                
        # Do actions:
        line_info = do_actions(line_info, actions, pos, c, cleared_flags)
                    
        # done?
        
    line_info["savecount"] += len(line_info["marks"]["!"])
    return line_info
  

func do_actions(line_info, actions, pos, c, cleared):
    for a in actions:
        match a["action"]["type"]:
            "error":
                var etype = a["action"]["error"]
                if "flag" in a["action"].keys():
                    var f = a["action"]["flag"]
                    line_info["errors"].append({"type": etype, "at": pos.x, "from": f["set"]})
                else:
                    line_info["errors"].append({"type": etype, "at": pos.x}) 
            "addhold":
                line_info["holds"][c] = {"on": true, "set": pos}
            "removehold":
                line_info["holds"][c] = {"on": false, "set": pos}
            "addflag":
                line_info["flags"].append({"flag":a["action"]["flag"],"set":pos})
            "fillhold":
                for key in line_info["holds"].keys():
                    line_info["holds"][key] = {"on": true, "set": pos}
            "clearhold":
                for key in line_info["holds"].keys():
                    line_info["holds"][key] = {"on": false, "set": pos}
            "setwait":
                var num = ""
                var type = ""
                for f in cleared:
                    if f["flag"] in chartypes["numerals"]["char"]:
                        num += f["flag"] 
                    if f["flag"] in chartypes["multiwait"]["char"]:
                        type = f["flag"]
                num = int(num)
                match type:
                    "%":
                        line_info["delay"]["line"] += num
                        line_info["delay"]["cumulative"] += num
                    "@":
                        if num > line_info["delay"]["cumulative"]:
                            line_info["delay"]["line"] += num - line_info["delay"]["cumulative"]
                            line_info["delay"]["cumulative"] = num
                    _:
                        print("Error getting the multiwait type")
    return line_info


func flag_in_flags(flag,flags):
    for f in flags:
        if f["flag"] == flag:
            return true
    return false

var iter = 0                    
func get_flag_actions(c, at, flags):
    iter += 1
    var actions = []
    var ct = get_chartype(c)
    if not ct:
        return []
    var acts = get_action(c, at)
    for atype in acts.keys():
        var flaglist = []
        var single
        match atype:
            "onflag", "noflag":
                flaglist = acts[atype].keys()
            "onflags", "noflags":
                flaglist = acts[atype]["flags"]
        var found = 0
        for fs in flaglist:
            if atype in ["onflag", "noflag"]:
                found = 0
            for flag in get_flags_from_string(fs):
                for f in flags:
                    if flag == f["flag"]:
                        found += 1
                        if atype == "onflag":
                            actions.append({"type": atype, "flag": f.duplicate(true), "action": acts[atype][fs]})
                        if atype in ["onflag", "noflag", "noflags"]:
                            break
                if found > 0 and atype in ["onflag", "noflag", "noflags"]:
                    break
            if atype == "noflag" and found == 0:
                actions.append({"type": atype, "flagstring": fs, "action": acts[atype][fs]})
            if found > 0 and atype == "noflags":
                break
        if atype == "noflags" and found == 0:
            pass
            #actions.append({"type": atype, "action": acts[atype]["do"]})
        if atype == "onflags" and found == len(flaglist):
            actions.append({"type": atype, "action": acts[atype]["do"]})
    return actions
    

func get_action(c, act, ret={}):
    var ct = get_chartype(c)
    if not ct:
        return ret
    if act in ct["actions"].keys():
        return ct["actions"][act]
    return ret

func get_chartype(c):
    if c in chartypes.keys():
        return (chartypes[c])
    for ctk in chartypes.keys():
        if c in chartypes[ctk]["char"]:
            return chartypes[ctk]
    return false

func get_flags_from_string(f):
    var flags = []
    if f in chartypes.keys():
        for i in chartypes[f]["char"]:
            flags.append(i)
        return flags
    return [f]
    
func update_marks():
    update_saves()
    update_side()
    set_to_update = true
    set_framecounts(true)
    
func update_saves():
    savecount = 0
    
    for i in get_line_count():
        var line = get_line(i)
        set_line_as_bookmark(i, false)
        set_line_as_breakpoint(i, false)
        for c in line:
            if c == "#":
                break
            if c == "!" or c == "?":
                set_line_as_bookmark(i, true)
                if c == "!":
                    savecount += 1
            if c == "X":
                set_line_as_breakpoint(i, true)

func replace_non_comment(a,b):
    for i in get_line_count():
        var line = get_line(i)
        for c in line:
            if c == "#":
                break
            if c == a:
                line = b.join(line.split(a, true, 1))
                set_line(i, line) 

func get_holds(to, from=Vector2(0,0), holds=false):
    if not holds:
        holds = {"W":false,"A":false,"S":false,"D":false,"G":false,"H":false,"K":false,"L":false, "at":Vector2(0,0)}
    var plus = false
    var minus = false
    var bundleplus = false
    var bundleminus = false
    var bundle = false
    for i in get_line_count()-from.y:
        var line = get_line(i+from.y)
        for j in len(line)-from.x:
            if i >= to.y-from.y and j >= to.x-from.x and not (plus or minus or bundleminus or bundleplus or bundle):
                holds["at"] = Vector2(j+from.x,i+from.y)
                return holds
            var c = line[j+from.x].to_upper()
            if c == "#":
                break
            match c:
                "+":
                    plus = true
                "-":
                    minus = true
                "[":
                    bundle = true
                    if plus:
                        bundleplus = true
                    if minus:
                        bundleminus = true
                "]":
                    bundle = false
                    bundleplus = false
                    bundleminus = false
                "W","A","S","D","G","H","K","L":
                    if minus or bundleminus:
                        holds[c] = false
                    elif holds[c]:
                        print("Double hold at: " +str(i+from.y)+" "+str(j+from.x))
                    if plus or bundleplus:
                        holds[c] = true
                    plus = false
                    minus = false
                _:
                    plus = false
                    minus = false
        from.x = 0
    holds["at"] = Vector2(0,get_line_count())
    return holds
    
func update_side():
    Side.text = ""
    var save = 1
    var max_size = 0
    for i in get_line_count():
        var abslines = get_line_wrapped_text(i)
        for line in abslines:
            var sflag = false
            var qflag = false
            var xflag = false
            line = line.split("#")[0]
            var sideline = ""
            if "X" in line and not xflag:
                sideline += "X"
                xflag = true
            if "?" in line and not qflag:
                if sideline != "":
                    sideline += " "
                sideline += "Q"
                qflag = true
            if "!" in line:
                if not sflag:
                    if sideline != "":
                        sideline += " "
                    sideline += str(save)
                    sflag = true
                save += 1
            max_size = max(len(sideline), max_size)
            sideline = "%10s" % sideline
            Side.text += sideline + "\n"
    get_parent().get_parent().get_node("Editor/ColorRect").rect_min_size.x = max_size*8 + 6
            
        
func _on_TextEdit_breakpoint_toggled(row):
    if row >= get_line_count():
        return
    set_line_as_breakpoint(row, !is_line_set_as_breakpoint(row))

var rolling_line = -1

func set_rolling_line(l,c,w,wm):
    if not l:
        return
    l = int(l)
    if l == -1:
        if rolling_line < get_line_count() and rolling_line >= 0:
            set_line_as_safe(rolling_line, false)
    if rolling_line != l and l < get_line_count() and l >= 0:
        if rolling_line < get_line_count() and rolling_line >= 0:
            set_line_as_safe(rolling_line, false)
        set_line_as_safe(l, true)
        rolling_line = l
        if follow:
            go_to_rolling()
    var pos = get_pos_at_line_column(l,c)
    if pos.x >= 0 and pos.y >= 0:
        var command = get_command_at(l,c)
        $Runpos.margin_top = pos.y - 21
        $Runpos.margin_bottom = pos.y
        $Runpos.margin_left = pos.x - 8*len(command) + 7
        $Runpos.margin_right = pos.x + 9
        if wm == 0:
            $Runpos/Wait.anchor_top = 1
        else:
            $Runpos/Wait.anchor_top = (wm - w)/wm
        if command[0] in "@%.:;":
            $Runpos.color = clrs["runwait"]
        elif command[0] in "!?":
            $Runpos.color = clrs["runsave"]
        elif command[0] in "X":
            $Runpos.color = clrs["runstop"]
        else:
            $Runpos.color = clrs["rundefault"]
        $Runpos.color.a = 0.2
    else:
        $Runpos.margin_left = $Runpos.margin_right
        
func get_command_at(l,end):
    var line = get_line(l).split("#")[0]
    var word = ""
    var bundle = false
    var wait = false
    var extra = false
    for s in len(line):
        var c = line[s].to_upper()
        if wait and not c in "1234567890":
            wait = false
            if s > end:
                break
        match c:
            "[":
                bundle = true
                if extra:
                    extra = false
                else:
                    word = ""
            "]":
                word += c
                bundle = false
        if bundle:
            word += c
            continue
        match c:
            "+", "-":
                word = c
                extra = true
            "W","A","S","D","G","H","K","L":
                if extra:
                    extra = false
                else:
                    word = ""
                word += c
            _:
                extra = false
        match c:
            ".",":",";","!","?","X":
                word = c
            " ":
                if s >= end:
                    break
                word = " "
        match c:
            "%","@":
                word = c
                wait = true
            "1","2","3","4","5","6","7","8","9","0":
                if wait:
                    word += c
                else:
                    word = c
                    
        if s >= end and not extra and not wait:
            break
    return word
            
        
func go_to_rolling():
    if rolling_line <= get_line_count() and rolling_line > 0:
        var rl = rolling_line-1
        var view_min = scroll_vertical + 3
        var view_max = scroll_vertical + 3 + int((get_visible_rows()-3)/4.0)
        if rl < view_min:
            scroll_vertical = max(0, rl - 3)
        elif rl > view_max:
            scroll_vertical = min(get_line_count(), rl - 3 - int((get_visible_rows()-3)/4.0))


func set_cursor_info():
    cursor_pos = Vector2(cursor_get_column(), cursor_get_line())
    print_line_data(cursor_pos.y)
    Bottom.get_node("Cursor/Line").text = str(cursor_pos.y+1)
    Bottom.get_node("Cursor/Char").text = str(cursor_pos.x)
    holds = get_holds(cursor_pos)
    for label in Bottom.get_node("Holds").get_children():
        if holds[label.name]:
            label.modulate = Color("#FFFFFFFF")
        else:
            label.modulate = Color("#99222222")
             
func get_actual_charline(c,l):
    c -= 1
    l -= 1 #UNLUA
    if l >= 0 and c >= 0:
        if c > 1:
            return Vector2(c-1,l)
        else:
            if l > 1:
                var line = get_line(l-1).split("#")[0]
                if line[-1] == " ":
                    return Vector2(c-1,l)
                else:
                    return Vector2(len(line)-1,l-1)
    return Vector2.ZERO

func _on_TextEdit_cursor_changed():
    set_framecounts()
    set_cursor_info()
