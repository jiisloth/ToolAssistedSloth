# ToolAssistedSloth

ToolAssistedSloth is a custom TAS tool for Mesen Emulator.

## TASeditor
The TAS editor provided in the releases section is a custom text editor made for creating TAS files.

### Usage
1. Download a suitable version of the editor from the releases section and launch it. 
2. Make new file and write your TAS inputs on the editor.
3. Press RUN and configure the Emulator and the TASplayer settings.
4. Enjoy

## TASplayer
TAS player is the script actually running the TAS.

### Usage (Without the TASeditor) 
1. Download the ToolAssistedSloth.lua from releases section.
2. Run the script on Mesen
3. Look for the script.cfg file in the Mesen folder and configure it properly.

## Syntax
Basic buttons:
```
H - START
G - SELECT

W - UP
A - LEFT
S - DOWN
D - RIGHT

L - A
K - B
```
Holds:
```
Add + before the button to hold it and - for release
```
Timing:
```
Each button operation will use 1 frame of emulation time. To perform multiple action on same frame, add [ brackets ] around the button list.
```
Idle:
```
. - idle 1 frame
%X - idles X frames, for example %23 will idle the next 23 frames
@X - idles until emulation reaches frame X, for example @120 will wait for frame number 120 of the emulation before continuing
```
Savestates:
```
! - create a savestate
? - will create a temporary savestate
```
Misc:
```
X - Pause emualtion and open debug
# - Comment, rest of the line is now a comment.
```
