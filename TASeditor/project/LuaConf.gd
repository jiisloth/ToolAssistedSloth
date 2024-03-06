extends TextEdit


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

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
    "bundle": Color("#61d3e3")
   }
# Called when the node enters the scene tree for the first time.
func _ready():
    add_keyword_color("BASEDIR", clrs["start"])
    add_keyword_color("TASFILE", clrs["start"])
    add_keyword_color("PRINTLOG", clrs["start"])
    add_keyword_color("DRAWONSCREEN", clrs["start"])
    add_keyword_color("DISPLAYMESSAGES", clrs["start"])
    add_keyword_color("ONSCRIPTLOAD", clrs["start"])
    add_color_region("#", " ", clrs["comment"], true)
    add_color_region("=", " ", clrs["select"], true)
    
