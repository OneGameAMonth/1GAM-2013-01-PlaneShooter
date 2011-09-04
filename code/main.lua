require "sprite"
require "physics"
require "constants"
require "ScrollingTerrain"
require "game_GameLoop"
require "game_LevelDirector"

require "player_PlayerWeapons"
require "player_Player"
require "player_PlayerBulletSingle"
require "player_PlayerRailGun"
require "enemies_EnemySmallShip"
require "enemies_EnemySmallShipDeath"
require "enemies_EnemyBulletSingle"
require "gamegui_DamageHUD"
require "enemies_BossBigPlane"
require "enemies_EnemyMissileJet"
require "enemies_EnemyMissile"

require "gamegui_animations_HeadNormalAnime"
require "gamegui_buttons_PauseButton"
require "gamegui_ScoreView"
require "gamegui_DialogueView"
require "gamegui_MoviePlayerView"
require "gamegui_FlightPathCheckpoint"
require "gamegui_FlightPath"
require "gamegui_LevelCompleteOverlay"

require "services_LoadLevelService"

require "screen_title"



local function initSounds()
--	planeShootSound = {}
	audio.reserveChannels(2)
	planeShootSound = audio.loadSound("plane_shoot.mp3")
	planeShootSoundChannel = 1
	audio.setVolume(.1, {channel=planeShootSoundChannel})
end

function startScrollingTerrain()
	--addLoop(terrainScroller)
end

function stopScrollingTerrain()
	--removeLoop(terrainScroller)
end

function onTouch(event)
	--print("onTouch, event.phase: ", event.phase)
	local handled = false
	if(event.phase == "began" or event.phase == "moved") then
		player:setDestination(event.x, event.y - 40)
		handled = true
	end

	if(event.phase == "began") then
		playerWeapons.enabled = true
		audio.play(planeShootSound, {channel=planeShootSoundChannel, loops=-1})
		handled = true
	end

	if(event.phase == "ended" or event.phase == "cancelled") then
		playerWeapons.enabled = false
		if planeShootSoundChannel ~= nil then
			audio.stop(planeShootSoundChannel)
		end
		handled = true
	end
	
	return handled
end

function startBossFight()
	if(fightingBoss == false) then
		fightingBoss = true
		local delayTable = {}
		function delayTable:timer(event)
		   createBoss()
        end
        timer.performWithDelay(200, delayTable)
	end
end

function initKeys()

	local function onKeyEvent( event )
	        local phase = event.phase
	        local keyName = event.keyName
	        print("phase: ", phase, ", keyName: ", keyName)

	        -- we handled the event, so return true.
	        -- for default behavior, return false.
	        return true
	end

	Runtime:addEventListener( "key", onKeyEvent );
end


function startGame()
	-- TOOD: use director, pause it
	gameLoop:reset()
	gameLoop:start()
	Runtime:addEventListener("touch", onTouch)
	startScrollingTerrain()
	levelDirector:start()
end

function stopGame()
	gameLoop:pause()
	Runtime:removeEventListener("touch", onTouch)
	stopScrollingTerrain()
	levelDirector:pause()
	playerWeapons.enabled = false
	if planeShootSoundChannel ~= nil then
		audio.stop(planeShootSoundChannel)
	end
end

function onMovieStarted(event)
	pauseGame()
	moviePlayer:startMovie(event.movie)
	return true
end

function onMovieEnded(event)
	unpauseGame()
	return true
end

function onLevelProgress(event)
	flightPath:setProgress(event.progress, 1)
end

function onLevelComplete(event)
	--gameLoop:pause()
	Runtime:removeEventListener("touch", onTouch)
	stopScrollingTerrain()
	levelDirector:pause()
	playerWeapons.enabled = false
	if planeShootSoundChannel ~= nil then
		audio.stop(planeShootSoundChannel)
	end
	
	levelCompleteOverlay = LevelCompleteOverlay:new(stage.width, stage.height)
	levelCompleteOverlay:addEventListener("onDone", onDone)
	return true
end

function onDone(event)
	
end

function pauseGame()
	print("pauseGame")
	gameLoop:pause()
	Runtime:removeEventListener("touch", onTouch)
	levelDirector:pause()
	playerWeapons.enabled = false
	if planeShootSoundChannel ~= nil then
		audio.stop(planeShootSoundChannel)
	end
	return true
end

function unpauseGame()
	print("unpauseGame")
	gameLoop:start()
	Runtime:addEventListener("touch", onTouch)
	levelDirector:start()
	playerWeapons.enabled = true
	return true
end

function togglePause()
	if(gameLoop.paused == true) then
		return unpauseGame()
	else
		return pauseGame()
	end
end

function onPauseTouch(event)
	print("onPauseTouch")
	if(event.phase == "began") then
		togglePause()
	end
	
	return true
end

function onKeyEvent( event )
	if(event.keyName == "menu") then
		if(gameLoop.paused == true) then
			unpauseGame()
		else
			pauseGame()
		end
	end
end

function onStartGameTouched(event)
	screenTitle:hide()
end

function onTitleScreenHideComplete()
	screenTitle:removeEventListener("screenTitle", onStartGameTouched)
	screenTitle:removeEventListener("hideComplete", onTitleScreenHideComplete)
	screenTitle:destroy()
	initializeGame()
	startGame()
end

function onSystemEvent(event)
	if event.type == "applicationExit" or event.type == "applicationSuspend" then
		os.exit()
	end

	--elseif event.type == "applicationResume"
end

function initializeGame()
	print("initializeGame")
	print("\tstarting physics")
	physics.start()
	physics.setDrawMode( "hybrid" )
	physics.setGravity( 0, 0 )

	print("\initializing MainContext")
	context = require("MainContext").new()
	context:init()

	print("\tmain group")
	mainGroup 						= display.newGroup()
	stage = display.getCurrentStage()

	print("\tdamaged hud")
	damageHUD = DamageHUD:new()
	context:createMediator(damageHUD)
	damageHUD.x = stage.width - 30
	damageHUD.y = 0

	print("\tscore view")
	scoreView = ScoreView:new()
	context:createMediator(scoreView)
	scoreView.x = scoreView.width / 2
	scoreView.y = damageHUD.y

	print("\tflight path")
	flightPath = FlightPath:new()
	flightPath:setProgress(1, 10)
	flightPath.x = (stage.width / 2) - (flightPath.width / 2)

	print("\tinit sounds")
	initSounds()

	print("\tPlayer")
	player = Player.new()
	mainGroup:insert(player)
	context:createMediator(player)
	--plane:addEventListener("hitPointsChanged", )

	print("\tgame loop")
	gameLoop = GameLoop:new()
	gameLoop:addLoop(player)

	print("\tbullet regulator")
	playerWeapons = PlayerWeapons:new(player, mainGroup, gameLoop)
	playerWeapons:setPowerLevel(1)


	print("\tplane targeting")
	player.planeXTarget = stage.width / 2
	player.planeYTarget = stage.height / 2
	player:move(player.planeXTarget, player.planeYTarget)
	--[[

	headAnime = HeadNormalAnime:new(4, stage.height - 104)
	mainGroup:insert(headAnime)
	--]]

	print("\tpause button")
	--local pauseButton = PauseButton:new(4, stage.height - 40)
--	pauseButton:addEventListener("touch", onPauseTouch)

	print("\tparsing level")
	level = LoadLevelService:new("level2.json")

	print("\tdrawing flight path checkpoints")
	flightPath:drawCheckpoints(level)

	print("\tlevel director")
	levelDirector = LevelDirector:new(level, player, mainGroup, gameLoop)
	assert(levelDirector ~= nil, "Level Director is null, yo!")
	levelDirector:initialize()
	print("levelDirector: ", levelDirector)
	print("levelDirector.addEventListener: ", levelDirector.addEventListener)
	levelDirector:addEventListener("onMovie", onMovieStarted)
	levelDirector:addEventListener("onLevelProgress", onLevelProgress)
	levelDirector:addEventListener("onLevelComplete", onLevelComplete)

	print("\tmovie player")
	moviePlayer = MoviePlayerView:new()
	moviePlayer:addEventListener("movieEnded", onMovieEnded)

	print("\thiding status bar")
	display.setStatusBar( display.HiddenStatusBar )

	print("\tinitializing keys")
	initKeys()
	
	Runtime:addEventListener("system", onSystemEvent)

	print("\tdone initializeGame!")
end

function debug(o)
	print(o)
	debugText.text = o
end


--initializeGame()
--startGame()

function startThisMug()
	local stage = display.getCurrentStage()
	screenTitle = ScreenTitle:new(stage.width, stage.height)
	screenTitle.x = 0
	screenTitle.y = 0
	screenTitle:addEventListener("startGame", onStartGameTouched)
	screenTitle:addEventListener("hideComplete", onTitleScreenHideComplete)
	screenTitle:show()
end

--startThisMug()

display.setStatusBar( display.HiddenStatusBar )

local fortressSheet = sprite.newSpriteSheet("npc_FlyingFortress_sheet.png", 295, 352)
local fortressSheetSet = sprite.newSpriteSet(fortressSheet, 1, 6)
sprite.add(fortressSheetSet, "fortress", 1, 6, 700, 0)
local fortress = sprite.newSprite(fortressSheetSet)
fortress:setReferencePoint(display.TopLeftReferencePoint)
fortress:prepare("fortress")
fortress:play()
fortress.x = 0
fortress.y = 0


-- tests
--[[
local dialogue = DialogueView:new()
dialogue:setText("Hello, G funk era!")
dialogue:setCharacter(constants.CHARACTER_JESTERXL)
dialogue:show()
]]--



--moviePlayer:addEventListener("movieEnded", t)
--moviePlayer:startMovie(movie)



--point = FlightPathCheckpoint:new()
--[[
path = FlightPath:new()
path:drawCheckpoints(level)
print("level.totalTime: ", level.totalTime)
path:setProgress(10, 10)
local stage = display.getCurrentStage()
path.x = (stage.width / 2) - (path.width / 2)
  ]]--

--[[
local group = display.newGroup()
--group:setReferencePoint(display.TopLeftReferencePoint)
group.x = 100
group.y = 100

--local subGroup = display.newGroup()


local rect = display.newRect(0, 0, 100, 100)
rect:setReferencePoint(display.TopLeftReferencePoint)
rect:setFillColor(255, 255, 255, 100) 
rect:setStrokeColor(255, 0, 0) 
rect.strokeWidth = 4
rect.x = group.x
rect.y = group.y
rect.isVisible = false

local greenRect = display.newRect(50, 50, 100, 100)
greenRect:setReferencePoint(display.TopLeftReferencePoint)
greenRect:setFillColor(255, 255, 255, 100) 
greenRect:setStrokeColor(0, 255, 0) 
greenRect.strokeWidth = 4
group:insert(greenRect)
]]--


