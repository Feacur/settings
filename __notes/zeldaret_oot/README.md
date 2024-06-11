# REPOSITORY

project:  
https://zelda.deco.mp/games/oot  
https://github.com/zeldaret/oot  

personal fork:  
https://github.com/Feacur/fork_zeldaret_oot  

contribution notes:  
```
# enable format on save
# enable clang tidy for LSP
# N.B.:
# - some files don't comply with `.clang-format` hierarchy
# - adding enums might break checksum, but Jenkins will offer a diff to fix it
#   - look in the relevant build console for "Jenkins made some fixes to your PR"

# run before commit / push
> python3 tools/check_format.py --verbose --compare-to origin/main
> make setup -j%cpu_count%
> make -j%cpu_count%
```




# Quick Setup

### definitely read the original docs
- `README.md`
	- open `Turn Windows features on or off`, enable `Windows Subsystem for Linux`
	- run `wsl --install`, follow the instructions
	- run `wsl` in the project directory or open it in a Linux terminal
	- follow the instructions
- `docs/vscode.md`

### alternatively, put in the root folder
- `project.code-workspace`
- `project.sublime-project`
- `compile_flags.txt`
	- it's the `"oot-gc-eu-mq-dbg"` config from the `docs/c_cpp_properties.json`
	- any other will do too, but this is the team's default

### get additional tools
- https://github.com/llvm/llvm-project
  - mostly for clangd
- https://github.com/Random06457/Z64Utils
  - a tool to view various data
- https://github.com/queueRAM/Texture64
  - a tool to view textures
- https://www.blender.org/
- https://github.com/Fast-64/fast64
  - a blender plugin to work with models




# Additional Info

## Links
https://www.copetti.org/writings/consoles/nintendo-64  
https://en.wikibooks.org/wiki/N64_Programming  
https://en.wikipedia.org/wiki/64DD  
https://n64brew.dev/wiki/Main_Page  
http://n64devkit.square7.ch/  
https://ultra64.ca/  

## Notes
code lines might be reshuffled in these notes  
```
it's a psudocode
summary blocks might be more informative, but flow blocks allow to see more context
thus, there also are redundancies just to easily unpack the tribal knowledge of the codebase
```



# OS Threads

see also the [flow](#os-threads-flow)  
```
Boot ............................. stops
  Idle ........................... idles
    Main ......................... works until NULL OS message
      Direct Memory Access ....... works until NULL OS message
      Crash Handler .............. works
      Interrupt Request Manager .. works until IRQ_PRENMI500_MSG
      Cooperative Scheduler ...... works
      Audio Driver ............... works
      Gamepads Manager ........... works until OS_SC_NMI_MSG
      Game Logic ................. works until NULL game state or Main destroys it

?? 64DD - a magnetic floppy disk drive peripheral
?? DDMSG - interface for the 64DD


@notes:
what is the "Idle" thread purpose?
what is the "Main" thread creation reason when "Boot" thread exists?
is "Boot" thread the "OS" thread, so that's why we don't want to clutter it?

"Game Logic" is originally known as "Graphic Thread", but besides
the actual rendering the thread also handles audio and logic too
```




# Game States

see also the [flow](#game-states-flow)  
see also the [opening](#opening-sequence)  
```
Initializer
  Nintendo Logo
    Title Loader ............. set GAMEMODE_TITLE_SCREEN, LINK_AGE_ADULT, `Save.cutsceneIndex = 0xFFF3`
      Play Mode .............. set GAMEMODE_TITLE_SCREEN

Play Mode
  if ENTR_LOAD_OPENING
    Title Loader
  if GAMEMODE_FILE_SELECT
    File Loader
  Play Mode

File Loader
  #OOT_DEBUG
    Debug Loader ............. set GAMEMODE_NORMAL
  #els
    Play Mode ................ set GAMEMODE_NORMAL

#OOT_DEBUG
  Debug Loader ............... set GAMEMODE_NORMAL
    Nintendo Logo
    Play Mode
  Reset Mode ................. not quite a state, no overlay

Title Screen Manager & Logo .. not a state, ACTOR_EN_MAG, no calling site
  set GAMEMODE_FILE_SELECT

Kaleidoscope ................. not a state, unknown purpose, no calling site
  Title Loader

Press Start .................. not quite a state, no overlay, no calling site
  Play Mode


@notes:
"Reset Mode" launches with a "PRE-NMI causes the system to transition to reset mode" message
```




# Opening Sequence

see also the [states](#game-states)  
see also the [commands](#cutscenes-commands)  
```
Initializer
  Nintendo Logo
    [N] NINTENDO64®

Title Loader
  Play Mode
    // i.e. CS_DEST_TITLE_SCREEN_DEMO, the opening cutscene
    Moon goes down, static green fields, Link on a horse
    Camera pans over the grassy ground

    "THE LEGEND OF ZELDA® OCARINA OF TIME™"
    "PRESS START" and "©1998 Nintendo"
    Screen fades to black

Play Mode
  Title Loader // i.e. pressed back / cancel
  File Loader
    "Please select a file."
    "Name?"
    "Please select a file."
    "Open this file?"
    Screen fades to black

Play Mode
  "In the vast, deep forest of Hyrule...", etc.
  Navi the fairy listens to the Deku Tree, etc.
  Hello, Link! Wake up!

  Kokiri Forest
  A green girl greets Link

  Player gets controls
```




# Cutscenes Bytecode

see also the [flow](#cutscenes-flow)  
see also the [commands](#cutscenes-commands)  
```
s32 totalEntries
s32 csFrameCount

[
  s32 cmdType

  if CS_CAM_STOP
    return // looks more like a break 

  or s32 cmdEntries
    or [] union CsCmdMisc .......... cmdEntries times
    or [] union CsCmdLightSetting .. cmdEntries times
    or [] union CsCmdStartSeq ...... cmdEntries times
    or [] union CsCmdStopSeq ....... cmdEntries times
    or [] union CsCmdFadeOutSeq .... cmdEntries times
    or [] union CsCmdRumble ........ cmdEntries times
    or [] union CsCmdTime .......... cmdEntries times
    or [] union CsCmdActorCue ...... cmdEntries times
    or union CsCmdDestination ...... once
    or [] union CsCmdText .......... cmdEntries times
    or union CsCmdTransition ....... once
    or [] 0x30 bytes ............... cmdEntries times

  or union CsCmdCam
    or [] union CutsceneCameraPoint .. until `CutsceneCameraPoint.continueFlag == CS_CAM_STOP`
    or union CutsceneCameraPoint ..... once, for `CS_CMD_CAM_EYE || CS_CMD_CAM_AT`
]


@notes:
"cmdType" is a s32 and "CutsceneCameraPoint.continueFlag" is a s8
CS_CAM_STOP is a `-1`, so technically it all checks out; probably
"union CutsceneCameraPoint" actually plays a dual role as a s32
```




# Scene Entrances

```
gEntranceTable[] @ `z_scene_table.c`
  populated with `entrance_table.h`

enum SceneLayer @ `z64save.h`
  child day
  child night
  adult day
  adult night
  cutscene // as zero offset

addressing method is `gEntranceTable[ base + offset ]` where
  base
    Save.entranceIndex
    PlayState.nextEntranceIndex
  offset
    SaveContext.sceneLayer
    based on LINK_IS_CHILD and IS_DAY
    `SCENE_LAYER_CUTSCENE_FIRST + (Save.cutsceneIndex & 0xF)` when `Save.cutsceneIndex >= 0xFFF0`

set PlayState.nextEntranceIndex sites
  CutsceneCmd_Destination ...... @ `z_demo.c`
  Environment_WarpSongLeave() .. @ `z_kankyo.c`
  Interface_Update() ........... @ `z_parameter.c`
  Interface_Draw() ............. @ `z_parameter.c`
  Play_TriggerVoidOut() ........ @ `z_play.c`
  Play_LoadToLastEntrance() .... @ `z_play.c`
  funtions ..................... @ `src/overlay/actors`

set Save.entranceIndex sites
  Cutscene_HandleConditionalTriggers() .. @ `z_demo.c`
  Play_Init() ........................... @ `z_play.c`
  Play_Update() ......................... @ `z_play.c`
  Sram_InitDebugSave() .................. @ `z_sram.c`
  Sram_OpenSave() ....................... @ `z_sram.c`
  Sram_InitSave() ....................... @ `z_sram.c`
  MapSelect_LoadGame() .................. @ `z_select.c`
  KaleidoScope_Update() ................. @ `z_kaleido_scope.c`


@notes:
there are lots of "custom", non-systemic, code. and it's OK! but it does give
you an urge to reuse and refactor. obviously, reverse engineering process is a
culprit here too, as compilers their settings are free to rearrange code as they
see fit. no defines or enums in sight, only numbers

still, the code gives the insight, that the topmost goal is to ship great experience,
not the "cleanest" source files. besides, there are cool tricks to learn still
```




# Save System

see also [flow](#save-system-flow)  
```
SRAM: 32kB
  header: 32B
  3 save slots
    slot: sizeof(SaveContext) + 40
      save: sizeof(Save)
      ...
  3 backup slots

file read: SRAM
file write: SRAM or slot

slot load: sizeof(Save)
slot save: sizeof(SaveContext) + 40

checksum: sum of Save's u16 words


@note:
the very first thing to notice is that there's alway a runtime save struct present,
which can be easily written as a buffer to a save file. so simple yet so brilliant!
```




# OS Threads Flow

see also the [summary](#os-threads)  

## `entry.s` -> bootproc() @ `boot_main.c`
	// ROM, ASM

## `boot_main.c` -> bootproc()
	// ROM, C
	-> osInitialize(), osCartRomInit(), osDriveRomInit() 
	-> Locale_Init() @ `z_locale.c`
	-> osCreateThread( Idle_ThreadEntry ) @ `idle.c`
	-> *stops*

## `idle.c` -> Idle_ThreadEntry()
	-> osCreateViManager() + osViSetMode() + osViBlack()
	-> osCreateThread( Main_ThreadEntry ) -> Main_ThreadEntry()
		-> DmaMgr_Init() @ `z_std_dma.c`
		-> Main() @ `main.c`
	-> *idles*

## `z_std_dma.c` -> DmaMgr_Init()
	// Direct Memory Access
	-> osCreateThread( DmaMgr_ThreadEntry ) -> DmaMgr_ThreadEntry()
		-> *works* until `osRecvMesg() yields NULL`
	-> back to Main_ThreadEntry @ `idle.c`

## `main.c` -> Main()
	-> Fault_Init() @ `fault_gc.c` or `fault_n64.c`
	-> IrqMgr_Init() @ `irqmgr.c`
	-> Sched_Init() @ `sched.c`
	-> AudioMgr_Init() @ `audio_thread_manager.c`
	-> PadMgr_Init() @ `padmgr.c`
	-> wait for Audio
	-> osCreateThread( Graph_ThreadEntry ) @ `graph.c`
	-> *works* until `osRecvMesg() yields NULL`
	-> osDestroyThread( sGraphThread )
	-> back to Main_ThreadEntry @ `idle.c`

## `fault_gc.c` or `fault_n64.c` -> Fault_Init()
	// Crash Handler
	-> osCreateThread( Fault_ThreadEntry ) -> Fault_ThreadEntry()
		-> *works*
	-> back to Main @ `main.c`

## `irqmgr.c` -> IrqMgr_Init()
	// Interrupt Request Manager, libultra part
	-> osCreateThread( IrqMgr_ThreadEntry ) -> IrqMgr_ThreadEntry()
		-> *works* until IRQ_PRENMI500_MSG

## `sched.c` -> Sched_Init()
	// Cooperative Scheduler, libultra part
	-> osCreateThread( Sched_ThreadEntry ) -> Sched_ThreadEntry()
		-> *works*

## `audio_thread_manager.c` -> AudioMgr_Init()
	// Audio Driver
	-> osCreateThread( AudioMgr_ThreadEntry ) -> AudioMgr_ThreadEntry()
		-> Audio_Init()
		-> *works*
	-> back to Main @ `main.c`

## `padmgr.c` -> PadMgr_Init()
	// Gamepads Manager
	-> osCreateThread( PadMgr_ThreadEntry ) -> PadMgr_ThreadEntry()
		-> *works* until OS_SC_NMI_MSG

## `graph.c` -> Graph_ThreadEntry()
	// Game Logic
	// starts with `gGameStateOverlayTable[ GAMESTATE_SETUP ]`
	-> Graph_Init()
	-> *works* until `Graph_GetNextGameState() == NULL`
		-> GameState_Init() @ `game.c`
		-> *works* while GameState_IsRunning() do Graph_Update()
			-> GameState_ReqPadData() @ `game.c`
			-> GameState_Update() @ `game.c`
			-> Audio_Update() @ `general.c`
			#OOT_DEBUG
				-> if BTN_Z
					-> SET_NEXT_GAMESTATE( MapSelect_Init ) @ `z_select.c`
				-> if PreNmiBuff_IsResetting()
					-> SET_NEXT_GAMESTATE( PreNMI_Init ) @ `z_prenmi.c`
		-> GameState_Destroy() @ `game.c`
	-> Graph_Destroy()




# Game States Flow

see also the [summary](#game-states)  

## `game.c` -> GameState_Init()
	-> init GameState fields
		-> `GameState.init = NULL` // *next* init, see SET_NEXT_GAMESTATE
		-> `GameState.size = 0`    // *next* size, see SET_NEXT_GAMESTATE
	-> GameAlloc_Init() @ `gamealloc.c`
	-> GameState_InitArena( 1mB )
	-> callback GameStateOverlay.init( gameState ), via gGameStateOverlayTable[].init
	-> SpeedMeter_Init() @ `speed_meter.c`
	-> Rumble_Init() @ `z_rumble.c`

## `game.c` -> GameState_Update()
	-> callback GameState.main( gameState )

## `game.c` -> GameState_Destroy()
	-> callback GameState.destroy( gameState )

## `title_setup.c` -> Setup_Init()
	// GAMESTATE_SETUP, Initializer
	-> set `GameState.destroy = Setup_Destroy`
	-> Setup_InitImpl()
		-> SaveContext_Init()
		-> SET_NEXT_GAMESTATE( ConsoleLogo_Init ) @ `z_title.c`

## `z_title.c` -> ConsoleLogo_Init()
	// GAMESTATE_CONSOLE_LOGO, Nintendo Logo
	-> set `GameState.main = ConsoleLogo_Main`
		-> if `state.exit`
			-> SET_NEXT_GAMESTATE( TitleSetup_Init ) @ `z_opening.c`
	-> set `GameState.destroy = ConsoleLogo_Destroy`
		-> Sram_InitSram() @ `z_sram.c`

## `z_opening.c` -> TitleSetup_Init()
	// GAMESTATE_TITLE_SETUP, Title Loader
	-> set `GameState.main = TitleSetup_Main`
		-> TitleSetup_SetupTitleScreen()
			-> set GAMEMODE_TITLE_SCREEN
			-> set LINK_AGE_ADULT
			-> Sram_InitDebugSave() @ `z_sram.c`
			-> set `Save.cutsceneIndex = 0xFFF3`
			-> set `SaveContext.sceneLayer = SCENE_LAYER_CUTSCENE_FIRST + 0xFFF3 & 0xF`
				// it's redundant, because "Play Mode" will set it anyway
			-> SET_NEXT_GAMESTATE( Play_Init ) @ `z_play.c`
	-> set `GameState.destroy = TitleSetup_Destroy`

## `z_play.c` -> Play_Init()
	// GAMESTATE_PLAY, Play Mode
	-> if `ENTR_LOAD_OPENING`
		-> SET_NEXT_GAMESTATE( TitleSetup_Init )
		-> return
	-> GameState_Realloc( 1.83mB ) @ `game.c`
	-> KaleidoManager_Init() @ `z_kaleido_manager.c`
	-> View_Init() @ `z_view.c`
	-> Camera_Init() @ `z_camera.c`
	-> Message_Init() @ `z_construct.c`
	-> GameOver_Init() @ `z_game_over.c`
	-> Cutscene_InitContext() @ `z_demo.c`
	-> Cutscene_HandleConditionalTriggers() @ `z_demo.c`
	-> if `SaveContext.sceneLayer < SCENE_LAYER_CUTSCENE_FIRST`
		-> LINK_IS_CHILD
			if IS_DAY
				-> set `SaveContext.sceneLayer = SCENE_LAYER_CHILD_DAY`
			-> else
				-> set `SaveContext.sceneLayer = SCENE_LAYER_CHILD_NIGHT`
		-> else
			-> if IS_DAY
				-> set `SaveContext.sceneLayer = SCENE_LAYER_ADULT_DAY`
			-> else
				-> set `SaveContext.sceneLayer = SCENE_LAYER_ADULT_NIGHT`
	-> else
		-> set `SaveContext.sceneLayer = SCENE_LAYER_CUTSCENE_FIRST + (Save.cutsceneIndex & 0xF)`
	// set `baseSceneLayer = SaveContext.sceneLayer` for later use
	-> if `SaveContext.sceneLayer < SCENE_LAYER_CUTSCENE_FIRST`
		-> LINK_IS_ADULT
			-> if SCENE_KOKIRI_FOREST
				-> if unknown flag from Save.info.eventChkInf
					-> set `SaveContext.sceneLayer = SCENE_LAYER_ADULT_NIGHT`
				-> else
					-> set `SaveContext.sceneLayer = SCENE_LAYER_ADULT_DAY`
		-> else
			-> if SCENE_HYRULE_FIELD
				if QUEST_KOKIRI_EMERALD && QUEST_GORON_RUBY && QUEST_ZORA_SAPPHIRE
					-> set `SaveContext.sceneLayer = SCENE_LAYER_CHILD_NIGHT`
				-> else
					-> set `SaveContext.sceneLayer = SCENE_LAYER_CHILD_DAY`
	-> Play_SpawnScene()
		// with `gEntranceTable[ Save.entranceIndex + SaveContext.sceneLayer ]`
		-> Play_InitScene()
			-> Object_InitContext() @ `z_scene.c`
			-> LightContext_Init() @ `z_lights.c`
			-> Room_Init() @ `z_room.c`
			-> Scene_ExecuteCommands() @ `z_scene.c`
			-> Play_InitEnvironment()
				-> Skybox_Init() @ `z_vr_box.c`
				-> Environment_Init() `z_kankyo.c`
		-> Room_SetupFirstRoom() `z_room.c`
	-> Cutscene_HandleEntranceTriggers() @ `z_demo.c`
	-> KaleidoScopeCall_Init() @ `z_kaleido_scope.c`
	-> Interface_Init() @ `z_construct.c`
	-> Matrix_Init() @ `sys_martrix.c`
	// might use baseSceneLayer here
	-> Letterbox_Init() @ `shrink_window.c`
	-> TransitionFade_Init() @ `z_fbdemo_fade.c`
	-> set `GameState.main = Play_Main`
		-> DebugDisplay_Init() @ `z_debug_display.c`
		-> Play_Update()
		-> Play_Draw()
			-> if !OOT_DEBUG || (R_HREG_MODE != HREG_MODE_PLAY) || R_PLAY_DRAW_OVERLAY_ELEMENTS
				-> Play_DrawOverlayElements()
					-> if IS_PAUSED()
						-> KaleidoScopeCall_Draw() @ `z_kaleido_scope_call.c`
					-> if GAMEMODE_NORMAL
						-> Interface_Draw() @ `z_parameter.c`
					-> Message_Draw() @ `z_message.c`
					-> if !GAMEOVER_INACTIVE
						-> GameOver_FadeInLights() @ `z_game_over.c`
	-> set `GameState.destroy = Play_Destroy`
		-> Interface_Destroy() @ `z_construct.c`
		-> KaleidoScopeCall_Destroy() @ `z_kaleido_scope_call.c`
		-> KaleidoManager_Destroy() @ `z_kaleido_manager.c`

## `z_play.c` -> Play_Update()
	// GAMESTATE_PLAY, Play Mode
	-> if FrameAdvance_Update()
		-> switch transitionMode
			-> case TRANS_MODE_INSTANCE_RUNNING
				-> if GAMEMODE_FILE_SELECT
					-> SET_NEXT_GAMESTATE( FileSelect_Init ) `z_file_choose.c`
				-> else
					-> SET_NEXT_GAMESTATE( Play_Init ) @ `z_play.c`
			-> case TRANS_MODE_FILL_IN
				-> SET_NEXT_GAMESTATE( Play_Init )
			-> case TRANS_MODE_INSTANT
				-> if !TRANS_TRIGGER_END
					-> SET_NEXT_GAMESTATE( Play_Init )
			-> case TRANS_MODE_SANDSTORM
				-> if !TRANS_TRIGGER_END
					-> SET_NEXT_GAMESTATE( Play_Init )
			-> case ...
		-> if !TRANS_TILE_READY
			-> if GAMEMODE_NORMAL && MSGMODE_NONE && GAMEOVER_INACTIVE
				KaleidoSetup_Update() @ `z_kaleido_setup.c`
			-> if !IS_PAUSED()
				-> Cutscene_UpdateManual() @ `z_demo.c`
				-> Cutscene_UpdateScripted() @ `z_demo.c`
			-> Skybox_Update() @ `z_vr_box_draw.c`
			-> if IS_PAUSED()
				-> KaleidoScopeCall_Update() @ `z_kaleido_scope_call.c`
			-> else if !GAMEOVER_INACTIVE
				-> GameOver_Update() @ `z_game_over.c`
			-> else
				-> Message_Update() @ `z_message.c`
			-> Interface_Update() @ `z_parameter.c`
			-> AnimTaskQueue_Update() @ `z_skeleanime.c`
			-> SfxSource_UpdateAll() @ `z_sfx_source.c`
			-> Letterbox_Update() @ `shrink_window.c`
			-> TransitionFade_Update() @ `z_fbdemo_fade.c`
	-> if !IS_PAUSED()
		-> Camera_Update() @ `z_camera.c`
	-> Environment_Update() @ `z_kankyo.c`




# Cutscenes Flow

see also the [bytecode](#cutscenes-bytecode)  

## `z_demo.c` -> Cutscene_InitContext()
	-> CS_STATE_IDLE
	-> CutsceneContext.timer = 0

## `z_demo.c` -> Cutscene_HandleEntranceTriggers()
	-> iterate sEntranceCutsceneTable
		-> if `requiredAge == 2`
			// effectively this means "no age restriction"
			-> set `requiredAge == Save.linkAge`
		-> if `Save.entranceIndex == EntranceCutscene.entrance`
			// && `Save.cutsceneIndex < 0xFFF0` && `SaveContext.respawnFlag <= 0`
			// && `Save.linkAge == requiredAge` && ...
			Cutscene_SetScript( EntranceCutscene.script )

## `z_demo.c` -> Cutscene_HandleConditionalTriggers()
	-> if GAMEMODE_NORMAL
		// && `Save.cutsceneIndex < 0xFFF0` && `SaveContext.respawnFlag <= 0`
		-> if ENTR_DESERT_COLOSSUS_1 && ...
			set ENTR_DESERT_COLOSSUS_0
			set `Save.cutsceneIndex = 0xFFF0`
		-> if ENTR_KAKARIKO_VILLAGE_0 && LINK_IS_ADULT && ...
			set `Save.cutsceneIndex = 0xFFF0`
		-> if ENTR_LOST_WOODS_9 && ...
			set ENTR_LOST_WOODS_0
			set `Save.cutsceneIndex = 0xFFF0`
		-> if `gEntranceTable[ Save.entranceIndex ].sceneId == SCENE_TEMPLE_OF_TIME` && ..
			// && QUEST_MEDALLION_SPIRIT && QUEST_MEDALLION_SHADOW && LINK_IS_ADULT
			set ENTR_TEMPLE_OF_TIME_0
			set `Save.cutsceneIndex = 0xFFF8`
		-> if `gEntranceTable[ Save.entranceIndex ].sceneId == SCENE_GANON_BOSS` && ..
			set ENTR_GANON_BOSS_0
			set `Save.cutsceneIndex = 0xFFF0`

## `z_demo.c` -> Cutscene_SetScript()
	// for the brevity, here are other Cutscene_SetScript calling sites
	// - `z_bg_breakwall.c` - Bombable Wall
	// - `z_en_ik.c`        - Iron Knuckle
	// - `z_en_xc.c`        - Sheik
	-> set `CutsceneContext.script = script`
		// it's a bytecode

## `z_demo.c` -> Cutscene_UpdateScripted()
	-> if `Save.cutsceneIndex >= 0xFFF0`
		// it seems, range [0xFFF0 .. 0xFFFF] means a scripted cutscene
		-> Cutscene_SetupScripted()
			-> might set `Save.cutsceneIndex = 0xFFFD`
			-> if CS_STATE_IDLE
				// the `Save.cutsceneIndex >= 0xFFF0` comparison is redundant
				-> set CS_STATE_START // actually increment CutsceneContext.state
				-> if CS_STATE_START
					-> if `SaveContext.cutsceneTrigger == 0`
						-> Interface_ChangeHudVisibilityMode( HUD_VISIBILITY_NOTHING )
					-> CutsceneHandler_RunScript()
				-> set `SaveContext.cutsceneTrigger = 0`
		-> callback sScriptedCutsceneHandlers[ CutsceneContext.state ]
			-> or CutsceneHandler_StartScript() when CS_STATE_START
			-> or CutsceneHandler_RunScript()   when CS_STATE_RUN
			-> or CutsceneHandler_StopScript()  when CS_STATE_STOP
			-> or CutsceneHandler_RunScript()   when CS_STATE_RUN_UNSTOPPABLE

## `z_demo.c` -> CutsceneHandler_StartScript()
	-> CutsceneHandler_RunScript()
	-> Interface_ChangeHudVisibilityMode( HUD_VISIBILITY_NOTHING )
	-> if Cutscene_StepTimer()
		-> set CS_STATE_RUN // actually increment CutsceneContext.state

## `z_demo.c` -> CutsceneHandler_RunScript()
	if `Save.cutsceneIndex >= 0xFFF0`
		#OOT_DEBUG && R_USE_DEBUG_CUTSCENE
			-> use gDebugCutsceneScript instead
		-> Cutscene_ProcessScript()
			-> if `CutsceneContext.curFrame > csFrameCount` && !CS_STATE_RUN_UNSTOPPABLE
				-> set CS_STATE_STOP;
				-> return
			#OOT_DEBUG && BTN_DRIGHT
				-> set CS_STATE_STOP
			-> run bytecode

## `z_demo.c` -> CutsceneHandler_StopScript()
	if Cutscene_StepTimer()
		-> set `CutsceneContext.playerCue = NULL`
		-> set `Save.cutsceneIndex = 0`
		-> set GAMEMODE_NORMAL
		-> set CS_STATE_IDLE

## `z_demo.c` -> Cutscene_StartManual()
	// for the brevity, it's called from a bunch of `src/overlays/actors`
	-> set CS_STATE_START
	-> set `CutsceneContext.playerCue = NULL`

## `z_demo.c` -> Cutscene_UpdateManual()
	-> if `Save.cutsceneIndex < 0xFFF0`
		// it seems, range [0x0000 .. 0xFFEF] means a manual cutscene
		-> callback sManualCutsceneHandlers[ CutsceneContext.state ]
			-> or CutsceneHandler_StartManual() when CS_STATE_START
			-> or CutsceneHandler_StopManual()  when CS_STATE_STOP

## `z_demo.c` -> CutsceneHandler_StartManual()
	-> Interface_ChangeHudVisibilityMode(HUD_VISIBILITY_NOTHING)
	-> if Cutscene_StepTimer()
		-> set CS_STATE_RUN // actually increment CutsceneContext.state

## `z_demo.c` -> CutsceneHandler_StopManual()
	-> if Cutscene_StepTimer()
		-> set CS_STATE_IDLE

## `z_demo.c` -> Cutscene_StopManual()
	// for the brevity, it's called from a bunch of `src/overlays/actors`
	-> if !CS_STATE_RUN_UNSTOPPABLE
		-> set CS_STATE_STOP




# Cutscenes Commands

see also the [bytecode](#cutscenes-bytecode)  

## `z_demo.c` -> CutsceneCmd_Misc()
	// CsCmdMisc, CS_CMD_MISC

## `z_demo.c` -> CutsceneCmd_SetLightSetting()
	// CsCmdLightSetting, CS_CMD_LIGHT_SETTING

## `z_demo.c` -> CutsceneCmd_StartSequence()
	// CsCmdStartSeq, CS_CMD_START_SEQ

## `z_demo.c` -> CutsceneCmd_StopSequence()
	// CsCmdStopSeq, CS_CMD_STOP_SEQ

## `z_demo.c` -> CutsceneCmd_FadeOutSequence()
	// CsCmdFadeOutSeq, CS_CMD_FADE_OUT_SEQ

## `z_demo.c` -> CutsceneCmd_RumbleController()
	// CsCmdRumble, CS_CMD_RUMBLE_CONTROLLER

## `z_demo.c` -> CutsceneCmd_Misc()
	// CsCmdMisc, CS_CMD_MISC

## `z_demo.c` -> CutsceneCmd_SetTime()
	// CsCmdTime, CS_CMD_TIME

## `z_demo.c` -> CutsceneCmd_Destination()
	// CsCmdDestination, CS_CMD_DESTINATION
	-> set `s32 titleDemoSkipped = false`
	-> if `!GAMEMODE_NORMAL && !GAMEMODE_END_CREDITS && !SCENE_HYRULE_FIELD && (BTN_A || BTN_B || BTN_START)` && `CutsceneContext.curFrame > 20`
		// it's the GAMEMODE_TITLE_SCREEN with "PRESS START"
		-> set `titleDemoSkipped = true`
	if various conditions
		-> set CS_STATE_RUN_UNSTOPPABLE
		-> set `Save.cutsceneIndex = 0`
		-> switch CsCmdDestination.destination
			-> case CS_DEST_TITLE_SCREEN_DEMO
				// it's the opening cutscene
				-> switch sTitleDemoDestination
					-> case TITLE_DEMO_SPIRIT_TEMPLE
						-> set ENTR_SPIRIT_TEMPLE_BOSS_0
							// age 0, script gSpiritBossNabooruKnuckleIntroCs
						-> set `Save.cutsceneIndex = 0xFFF2`
					-> case TITLE_DEMO_DEATH_MOUNTAIN_CRATER
						-> set ENTR_DEATH_MOUNTAIN_CRATER_0
							// age 2, script gDeathMountainCraterIntroCs
						-> set `Save.cutsceneIndex = 0xFFF1`
					-> case TITLE_DEMO_GANONDORF_HORSE
						-> set ENTR_CUTSCENE_MAP_0
							// ??, but it might be
							// age 2, script gHyruleFieldIntroCs, ENTR_HYRULE_FIELD_3
							// although sEntranceCutsceneTable doesn't contain ENTR_CUTSCENE_MAP_0 itself
						-> set `Save.cutsceneIndex = 0xFFF6`
							// might be linked to SCENE_HYRULE_FIELD, probably
				// as a tiny liberty, unlike the code, put this lines out of the switch
				-> set TRANS_TRIGGER_START
				-> cycle sTitleDemoDestination
			-> case ...

## `z_demo.c` -> CutsceneCmd_Text()
	// CsCmdText, CS_CMD_TEXT

## `z_demo.c` -> CutsceneCmd_Transition()
	// CsCmdTransition, CS_CMD_TRANSITION

## `z_demo.c` -> CutsceneCmd_UpdateCamEyeSpline()
	// CsCmdCam, CS_CMD_CAM_EYE_SPLINE || CS_CMD_CAM_EYE_SPLINE_REL_TO_PLAYER

## `z_demo.c` -> CutsceneCmd_UpdateCamAtSpline()
	// CsCmdCam, CS_CMD_CAM_AT_SPLINE || CS_CMD_CAM_AT_SPLINE_REL_TO_PLAYER

## `z_demo.c` -> CutsceneCmd_SetCamEye()
	// CsCmdCam, CS_CMD_CAM_EYE

## `z_demo.c` -> CutsceneCmd_SetCamAt()
	// CsCmdCam, CS_CMD_CAM_AT




# Player Routines

see also [gave over](#game-over-flow)  

## `z_player.h`
	// whoa `struct Player` is huge, love it
	`struct Player`
		`struct Actor actor` @ `z64actor.h`
		...

## `z_player.c` -> func_80843AE8()
	-> if GAMEOVER_DEATH_WAIT_GROUND
		-> set GAMEOVER_DEATH_DELAY_MENU




# Actors Table

## `z_en_mag.c` -> EnMag_Init()
	// Title Screen Manager & Logo

## `z_en_mag.c` -> EnMag_Update()
	// Title Screen Manager & Logo
		-> set GAMEMODE_FILE_SELECT
		// there's a note: "only instance type transitions swap to file select"
		// meaning that ACTOR_EN_MAG is an "instance type transition"




# Save System Flow

see also [summary](#save-system)  
see also [pause menu](#pause-menu)  

## `z_file_choose.c` -> FileSelect_Init()
	// GAMESTATE_FILE_SELECT, File Loader
	-> set `GameState.main = FileSelect_Main`
		-> sFileSelectUpdateFuncs[ menuMode ]()
			-> or FileSelect_InitModeUpdate()
				#OOT_PAL_N64
					-> if FS_MENU_MODE_INIT
						-> Sram_VerifyAndLoadAllSaves() @ `z_sram.c`
				#else
					-> if CM_FADE_IN_START
						-> Sram_VerifyAndLoadAllSaves() @ `z_sram.c`
			-> or FileSelect_ConfigModeUpdate()
				-> sConfigModeUpdateFuncs[ GameState.configMode ]()
					-> or FileSelect_EraseAnim1() @ `z_file_copy_erase.c`
					-> or FileSelect_CopyConfirm() @ `z_file_copy_erase.c`
					-> or ...
			-> or FileSelect_SelectModeUpdate()
				-> sSelectModeUpdateFuncs[ selectMode ]()
					-> or FileSelect_LoadGame()
						-> set GAMEMODE_NORMAL
						-> set `SaveContext.buttonIndex = FileSelectState.buttonIndex`
						-> Sram_OpenSave() @ `z_sram.c`
						#OOT_DEBUG && FS_BTN_SELECT_FILE_1
							-> SET_NEXT_GAMESTATE( MapSelect_Init ) @ `z_select.c`
						#else
							-> SET_NEXT_GAMESTATE( Play_Init ) @ `z_play.c`
						-> set `SaveContext.nextCutsceneIndex = 0xFFEF`
					-> or ...
		-> sFileSelectDrawFuncs[ menuMode ]()
			-> or FileSelect_InitModeDraw()
			-> or FileSelect_ConfigModeDraw()
			-> or FileSelect_SelectModeDraw()
	-> set `GameState.destroy = FileSelect_Destroy`

## `z_file_copy_erase.c` -> FileSelect_EraseAnim1()
	-> if `--sEraseDelayTimer == 0` && `--GameState.actionTimer == 0`
		-> Sram_EraseSave() @ `z_sram.c`

## `z_file_copy_erase.c` -> FileSelect_CopyConfirm()
	-> if FS_BTN_CONFIRM_YES && (BTN_A || BTN_START)
		-> Sram_CopySave() @ `z_sram.c`

## `z_file_nameset.c` -> FileSelect_DrawNameEntry()
	-> ... 2 spots
		-> Sram_InitSave() @ `z_sram.c`

## `z_sram.c` -> Sram_InitSram()
	-> SsSram_ReadWrite( SramContext.readBuff, SRAM_SIZE, OS_READ ) @ `z_ss_sram.c`
	// read header

## `z_sram.c` -> Sram_VerifyAndLoadAllSaves()
	-> SsSram_ReadWrite( SramContext.readBuff, SRAM_SIZE, OS_READ ) @ `z_ss_sram.c`
	// verify
	-> SsSram_ReadWrite( SramContext.readBuff, SRAM_SIZE, OS_READ ) @ `z_ss_sram.c`
	// populate FileSelectState

## `z_sram.c` -> Sram_InitSave()
	// for SaveContext.fileNum
	-> Sram_InitNewSave()
	-> copy `SaveContext.save` into `SramContext.readBuff + offset`
	-> copy `SaveContext.save` into `SramContext.readBuff + backup`
	-> SsSram_ReadWrite( SramContext.readBuff, SRAM_SIZE, OS_WRITE ) @ `z_ss_sram.c`

## `z_sram.c` -> Sram_InitDebugSave()
	-> set `Save.info.horseData.sceneId SCENE_HYRULE_FIELD`
	-> set ENTR_HYRULE_FIELD_0

## `z_sram.c` -> Sram_WriteSave()
	// for SaveContext.fileNum
	-> copy `SaveContext.save` into `SramContext.readBuff + offset`
	-> SsSram_ReadWrite( SramContext.readBuff + offset, SLOT_SIZE, OS_WRITE ) @ `z_ss_sram.c`
	-> copy `SaveContext.save` into `SramContext.readBuff + backup`
	-> SsSram_ReadWrite( SramContext.readBuff + backup, SLOT_SIZE, OS_WRITE ) @ `z_ss_sram.c`

## `z_sram.c` -> Sram_EraseSave()
	// for FileSelectState.selectedFileIndex
	-> Sram_InitNewSave()
	-> copy `SaveContext.save` into `SramContext.readBuff + offset`
	-> SsSram_ReadWrite( SramContext.readBuff + offset, SLOT_SIZE, OS_WRITE ) @ `z_ss_sram.c`
	-> copy `SaveContext.save` into `SramContext.readBuff + backup`
	-> SsSram_ReadWrite( SramContext.readBuff + backup, SLOT_SIZE, OS_WRITE ) @ `z_ss_sram.c`

## `z_sram.c` -> Sram_CopySave()
	// for FileSelectState.selectedFileIndex and FileSelectState.copyDestFileIndex
	-> copy `SramContext.readBuff + from` into `SaveContext.save`
	-> copy `SaveContext.save` into `SramContext.readBuff + offset`
	-> copy `SaveContext.save` into `SramContext.readBuff + backup`
	-> SsSram_ReadWrite( SramContext.readBuff, SRAM_SIZE, OS_WRITE ) @ `z_ss_sram.c`

## `z_sram.c` -> Sram_OpenSave()
	// for SaveContext.fileNum
	-> copy `SramContext.readBuff + offset` into `SaveContext.save`
	// post-process




# Pause Menu Flow

see also [flow](#save-system-flow)  
see also [gave over](#game-over-flow)  

## `z_kaleido_manager.c` -> KaleidoManager_Init()
	//

## `z_kaleido_manager.c` -> KaleidoManager_Destroy()
	//

## `z_kaleido_scope_call.c` -> KaleidoScopeCall_Init()
	-> set `sKaleidoScopeUpdateFunc = KaleidoManager_GetRamAddr( KaleidoScope_Update )` from `z_kaleido_scope.c`
	-> set `sKaleidoScopeDrawFunc = KaleidoManager_GetRamAddr( KaleidoScope_Draw )` from `z_kaleido_scope.c
	-> KaleidoSetup_Init()

## `z_kaleido_scope_call.c` -> KaleidoScopeCall_Update()
	-> if IS_PAUSED()
		-> switch PauseContext.state
			-> case PAUSE_STATE_GAME_OVER_REQUEST
				-> set PAUSE_BG_PRERENDER_SETUP
				-> set PAUSE_MAIN_STATE_IDLE
				-> set PAUSE_SAVE_PROMPT_STATE_APPEARING
					// redundant for game over 
				-> set PAUSE_STATE_GAME_OVER_WAIT_BG_PRERENDER // actually increment PauseContext.state, masked
			-> case PAUSE_STATE_GAME_OVER_WAIT_BG_PRERENDER && PAUSE_BG_PRERENDER_READY
				-> set PAUSE_STATE_GAME_OVER_INIT // actually increment PauseContext.state
		-> if !PAUSE_STATE_OFF
			-> if `gKaleidoMgrCurOvl == kaleidoScopeOvl`
				-> callback KaleidoScope_Update() @ `z_kaleido_scope.c` // via sKaleidoScopeUpdateFunc

## `z_kaleido_scope_call.c` -> KaleidoScopeCall_Draw()
	-> if PAUSE_BG_PRERENDER_READY && ...
		-> callback KaleidoScope_Draw() @ `z_kaleido_scope.c` // via sKaleidoScopeDrawFunc

## `z_kaleido_scope_call.c` -> KaleidoScopeCall_Destroy()
	-> KaleidoSetup_Destroy() @ `z_kaleido_setup.c`

## `z_kaleido_setup.c` -> KaleidoSetup_Init()
	//

## `z_kaleido_setup.c` -> KaleidoSetup_Update()
	//

## `z_kaleido_scope.c` -> KaleidoScope_Update()
	-> switch PauseContext.state
		-> case PAUSE_STATE_SAVE_PROMPT
			-> switch PauseContext.savePromptState
				-> case PAUSE_SAVE_PROMPT_STATE_WAIT_CHOICE && BTN_A
					-> if `PauseContext.promptChoice == 0`
						-> Sram_WriteSave() @ `z_sram.c`
						-> set PAUSE_SAVE_PROMPT_STATE_SAVED
					-> else
						-> set PAUSE_SAVE_PROMPT_STATE_CLOSING

		// case PAUSE_STATE_GAME_OVER_REQUEST isn't handled here
		// case PAUSE_STATE_GAME_OVER_WAIT_BG_PRERENDER isn't handled here
		-> case PAUSE_STATE_GAME_OVER_INIT
			// "GAME OVER", animation
			-> Interface_ChangeHudVisibilityMode( HUD_VISIBILITY_NOTHING )
			-> set PAUSE_STATE_GAME_OVER_SHOW // actually increment PauseContext.state
		-> case PAUSE_STATE_GAME_OVER_SHOW
			// "GAME OVER", animation
			-> if `--D_8082B260 == 0`
				-> set PAUSE_STATE_GAME_OVER_DELAY // actually increment PauseContext.state
		-> case PAUSE_STATE_GAME_OVER_DELAY
			// "GAME OVER", animation
			-> if `--sD_8082B260 == 0`
				-> set PAUSE_STATE_GAME_OVER_FRAME // actually increment PauseContext.state
		-> case PAUSE_STATE_GAME_OVER_FRAME
			// "GAME OVER", animation
			-> wait for animation
				-> set PAUSE_STATE_GAME_OVER_SAVE_PROMPT

		-> case PAUSE_STATE_GAME_OVER_SAVE_PROMPT && BTN_A
			// "GAME OVER", "Would you like to save?"
			-> `PauseContext.promptChoice == 0`, prompt
				-> Sram_WriteSave() @ `z_sram.c`
				-> set PAUSE_STATE_GAME_OVER_SAVE_YES
			-> else
				if `--sDelayTimer == 0` || BTN_A || BTN_START
					-> set PAUSE_STATE_GAME_OVER_CONTINUE_PROMPT
		-> case PAUSE_STATE_GAME_OVER_SAVE_YES
			// "GAME OVER", "Would you like to save?", choice
			-> set PAUSE_STATE_GAME_OVER_CONTINUE_PROMPT

		-> case PAUSE_STATE_GAME_OVER_CONTINUE_PROMPT && BTN_A || BTN_START
			// "GAME OVER", "Continue playing?", prompt
			-> if `PauseContext.promptChoice == 0`
				-> set Save.entranceIndex
			-> else
				-> Audio_PlaySfxGeneral() @ `sfx.c`
		-> case PAUSE_STATE_GAME_OVER_CONTINUE_CHOICE && ...
			// "GAME OVER", "Continue playing?", choice
			-> if `PauseContext.promptChoice == 0`
				-> set `SaveContext.respawnFlag = -2`
			-> else
				-> SET_NEXT_GAMESTATE( TitleSetup_Init ) @ `z_opening.c`

		-> case ...

## `z_kaleido_scope.c` -> KaleidoScope_Draw()
	-> if `PauseContext.debugState == 0`
		-> KaleidoScope_DrawPages()
			-> if !IS_PAUSE_STATE_GAMEOVER()
				-> switch PauseContext.pageIndex
					-> case ...
			-> if PAUSE_STATE_SAVE_PROMPT || IS_PAUSE_STATE_GAMEOVER()
				-> if IS_PAUSE_STATE_GAMEOVER()
					-> KaleidoScope_DrawPageSections( sGameOverTexs )
				-> else
					-> KaleidoScope_DrawPageSections( SaveContext.language )
			-> PAUSE_STATE_SAVE_PROMPT && !PAUSE_SAVE_PROMPT_STATE_SAVED || PAUSE_STATE_GAME_OVER_SAVE_PROMPT
				-> KaleidoScope_QuadTextureIA8( sSavePromptMessageTexs[gSaveContext.language], PROMPT_QUAD_MESSAGE )
				-> KaleidoScope_QuadTextureIA8( sPromptChoiceTexs[gSaveContext.language][0], PROMPT_QUAD_CHOICE_YES ) // PauseContext.promptChoice -> 0
				-> KaleidoScope_QuadTextureIA8( sPromptChoiceTexs[gSaveContext.language][1], PROMPT_QUAD_CHOICE_NO )  // PauseContext.promptChoice -> 4
			-> PAUSE_STATE_SAVE_PROMPT && PAUSE_SAVE_PROMPT_STATE_SAVED || PAUSE_STATE_GAME_OVER_SAVE_YES
				-> KaleidoScope_QuadTextureIA8( sSaveConfirmationTexs[gSaveContext.language], PROMPT_QUAD_MESSAGE )
			-> PAUSE_STATE_GAME_OVER_CONTINUE_PROMPT || PAUSE_STATE_GAME_OVER_CONTINUE_CHOICE
				-> KaleidoScope_QuadTextureIA8( sContinuePromptTexs[gSaveContext.language], PROMPT_QUAD_MESSAGE )
				-> KaleidoScope_QuadTextureIA8( sPromptChoiceTexs[gSaveContext.language][0], PROMPT_QUAD_CHOICE_YES ) // PauseContext.promptChoice -> 0
				-> KaleidoScope_QuadTextureIA8( sPromptChoiceTexs[gSaveContext.language][1], PROMPT_QUAD_CHOICE_NO )  // PauseContext.promptChoice -> 4
		-> if !IS_PAUSE_STATE_GAMEOVER()
			-> KaleidoScope_DrawInfoPanel()
	-> if `PauseContext.state >= PAUSE_STATE_GAME_OVER_SHOW` && `PauseContext.state <= PAUSE_STATE_GAME_OVER_CONTINUE_CHOICE`
		-> KaleidoScope_DrawGameOver()
	-> if `PauseContext.debugState == 1` || `PauseContext.debugState == 2`
		-> KaleidoScope_DrawDebugEditor()

## `z_kaleido_setup.c` -> KaleidoSetup_Destroy()
	//

## `z_kaleido_prompt.c` -> KaleidoScope_UpdatePrompt()
	-> if PAUSE_STATE_SAVE_PROMPT && PAUSE_SAVE_PROMPT_STATE_WAIT_CHOICE || PAUSE_STATE_GAME_OVER_SAVE_PROMPT || PAUSE_STATE_GAME_OVER_CONTINUE_PROMPT
		-> if `PauseContext.promptChoice == 0` && `stickAdjX >= 30`
			-> set `PauseContext.promptChoice == 4` // no
		-> if `PauseContext.promptChoice != 0` && `stickAdjX <= -30`
			-> set `PauseContext.promptChoice == 0` // yes




# Game Over Flow

see also [pause menu](#pause-menu-flow)  
see also [player](#player-routines)  

## `z_game_over.c` -> GameOver_Init()
	//

## `z_game_over.c` -> GameOver_Update()
	-> switch GameOverContext.state
		-> case GAMEOVER_DEATH_START
			-> set GAMEOVER_DEATH_WAIT_GROUND
		-> case GAMEOVER_DEATH_DELAY_MENU && `--sGameOverTimer == 0`
				-> set PAUSE_STATE_GAME_OVER_REQUEST
		-> ...




# Unknown Source

## `z_sample.c` -> Sample_Init()
	// ??, Press Start
	// see CS_DEST_TITLE_SCREEN_DEMO instead
	-> set `GameState.main = Sample_Main`
		-> Sample_Draw()
		-> Sample_HandleStateChange()
			-> if BTN_START
				-> SET_NEXT_GAMESTATE( Play_Init ) @ `z_play.c`
	-> set `GameState.destroy = Sample_Destroy`




# Debug Code

## `z_select.c` -> MapSelect_Init()
	// GAMESTATE_MAP_SELECT, Debug Loader
	-> set `GameState.main = MapSelect_Main`
		-> MapSelect_UpdateMenu()
			-> if BTN_A || BTN_START
				-> sScenes[ currentScene ].loadFunc()
					-> or MapSelect_LoadGame()
						-> SET_NEXT_GAMESTATE( Play_Init ) @ `z_play.c`
					-> or MapSelect_LoadTitle()
						-> SET_NEXT_GAMESTATE( ConsoleLogo_Init ) @ `z_title.c`
			-> if BTN_B
				-> cycle `Save.linkAge` in [LINK_AGE_CHILD, LINK_AGE_ADULT]
			-> if BTN_R and BTN_Z
				-> cycle `Save.cutsceneIndex` in [0x0000, 0xFFF0 .. 0xFFFA, 0x8000]
		-> MapSelect_Draw()
	-> set `GameState.destroy = MapSelect_Destroy`
	-> set `Save.cutsceneIndex = 0x8000`
		// in the `z_demo.c` it is related to the CS_DEST_DEATH_MOUNTAIN_TRAIL
	-> set `Save.linkAge = LINK_AGE_CHILD`

## `z_select.c` -> MapSelect_PrintCutsceneSetting()
	-> Save.cutsceneIndex
		// seems to bear more of a debug meaning
		case 0x0000 "Stage: night"    CLOCK_TIME(  0, 0 )
		case 0x8000 "Stage: day"      CLOCK_TIME( 12, 0 )
		case 0xFFF0 "Stage: demo 00"  CLOCK_TIME( 12, 0 )
		case 0xFFF1 "Stage: demo 01"
		case 0xFFF2 "Stage: demo 02"
		case 0xFFF3 "Stage: demo 03"
		case 0xFFF4 "Stage: demo 04"
		case 0xFFF5 "Stage: demo 05"
		case 0xFFF6 "Stage: demo 06"
		case 0xFFF7 "Stage: demo 07"
		case 0xFFF8 "Stage: demo 08"
		case 0xFFF9 "Stage: demo 09"
		case 0xFFFA "Stage: demo 0A"

## `z_prenmi.c` -> PreNMI_Init()
	// Pre Non-Maskable Interrupt, Reset Mode
	-> set `GameState.main = PreNMI_Main`
		-> PreNMI_Update()
		-> PreNMI_Draw()
	-> set `GameState.destroy = PreNMI_Destroy`




# Framework Code

## `general.c` -> Audio_Update()
	// audio logic

## `z_sfx_source.c` -> SfxSource_UpdateAll()
	// audio logic

## `gamealloc.c` -> GameAlloc_Init()
	// memory routines

## `speed_meter.c` -> SpeedMeter_Init()
	// (?) time routines

## `z_locale.c` -> Locale_Init()
	// initializes JP/US/EU locale

## `z_rumble.c` -> Rumble_Init()
	// gamepads rumble handler
	-> RumbleMgr_Init() @ `sys_rumble.c`

## `sys_rumble.c` -> RumbleMgr_Init()
	// gamepads rumble handler

## `z_skeleanime.c` -> AnimTaskQueue_Update()
	// skeletal animation

## `z_view.c` -> View_Init()
	// viewport routines

## `z_camera.c` -> Camera_Init()
	// camera routines

## `z_camera.c` -> Camera_Update()
	// camera routines

## `z_kankyo.c` -> Environment_Init()
	// environment routines

## `z_kankyo.c` -> Environment_Update()
	// environment routines

## `Skybox_Init.c` -> Skybox_Init()
	// skybox routines

## `z_vr_box_draw.c` -> Skybox_Update()
	// skybox routines




# UI Code

## `z_construct.c` -> Message_Init()
	//

## `z_construct.c` -> Interface_Init()
	//

## `z_message.c` -> Message_Update()
	//

## `z_parameter.c` -> Interface_Update()
	//

## `shrink_window.c` -> Letterbox_Init()
	//

## `shrink_window.c` -> Letterbox_Update()
	//

## `z_fbdemo_fade.c` -> TransitionFade_Init()
	//

## `z_fbdemo_fade.c` -> TransitionFade_Update()
	//




# Temporary

warnings
```
Warningsrc/overlays/actors/ovl_Boss_Va/z_boss_va.c:1149:46: warning: comparison is always false due to limited range of data type [-Wtype-limits]
 1149 |                 if (this->invincibilityTimer > 160) {
      |                                              ^

src/code/z_kankyo.c:967:84: warning: comparison is always false due to limited range of data type [-Wtype-limits]
  967 |             (((void)0, gSaveContext.save.dayTime) < CLOCK_TIME(1, 0) || gTimeSpeed < 0))
      |                                                                                    ^

src/code/z_actor.c:4035:20: warning: comparison is always false due to limited range of data type [-Wtype-limits]
 4035 |     if ((colorFlag == COLORFILTER_COLORFLAG_GRAY) && !(colorIntensityMax & COLORFILTER_INTENSITY_FLAG)) {
      |                    ^~

src/code/z_camera.c:615:12: warning: variable ‘playerPosRot’ set but not used [-Wunused-but-set-variable]
  615 |     PosRot playerPosRot;
      |            ^~~~~~~~~~~~

src/code/z_camera.c:2350:12: warning: variable ‘playerhead’ set but not used [-Wunused-but-set-variable]
 2350 |     PosRot playerhead;
      |            ^~~~~~~~~~

src/code/z_camera.c:2493:12: warning: variable ‘atToEyeDir’ set but not used [-Wunused-but-set-variable]
 2493 |     VecGeo atToEyeDir;
      |            ^~~~~~~~~~

src/code/z_camera.c:3476:12: warning: variable ‘playerPosRot’ set but not used [-Wunused-but-set-variable]
 3476 |     PosRot playerPosRot;
      |            ^~~~~~~~~~~~

src/code/z_camera.c:3470:12: warning: variable ‘atToEyeDir’ set but not used [-Wunused-but-set-variable]
 3470 |     VecGeo atToEyeDir;
      |            ^~~~~~~~~~

src/code/z_camera.c:3656:12: warning: variable ‘spB0’ set but not used [-Wunused-but-set-variable]
 3656 |     VecGeo spB0;
      |            ^~~~

src/code/z_camera.c:4191:12: warning: variable ‘eyeAtOffset’ set but not used [-Wunused-but-set-variable]
 4191 |     VecGeo eyeAtOffset;
      |            ^~~~~~~~~~~

src/code/z_camera.c:4349:11: warning: variable ‘sp8C’ set but not used [-Wunused-but-set-variable]
 4349 |     Vec3f sp8C;
      |           ^~~~

src/code/z_camera.c:4744:12: warning: variable ‘playerhead’ set but not used [-Wunused-but-set-variable]
 4744 |     PosRot playerhead;
      |            ^~~~~~~~~~

src/code/z_camera.c:6978:12: warning: variable ‘sp64’ set but not used [-Wunused-but-set-variable]
 6978 |     VecGeo sp64;
      |            ^~~~

src/code/z_camera.c:7180:12: warning: variable ‘eyeAtOffset’ set but not used [-Wunused-but-set-variable]
 7180 |     VecGeo eyeAtOffset;
      |            ^~~~~~~~~~~
```

rematch example 1
```
// before
if ((value != const1) && (value != const2)) {
	if (value == const3) {
		statement1
	}
} else {
	statement2
}

// after
switch (value) {
	case const3:
		statement1
		break;

	case const2:
	case const1:
		statement2
		break;
}
```

rematch example 2
```
// before
if (value != const1 && value != const2) {
	statement1
} else if ((value == const1) && !cond1) {
	statement2
} else {
	statement3
}

// after
if (value != const1) {
	if (value != const2) {
		statement1
		return
	}
}
if (value == const1) {
	if (!cond1) {
		statement2
	}
}
statement3
```

rematch example 3
```
// before
if (value != const1) {
	if ((value == const2) && cond1) {
		statement1
		return;
	}
} else if (cond2) {
	statement2
	return;
}

// after
switch (value) {
	case const2:
		if (cond1) {
			statement1
			return;
		}
		break;
	case const1:
		if (cond2) {
			statement2
			return;
		}
		break;
}
```
