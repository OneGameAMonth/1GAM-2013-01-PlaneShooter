require "sprite"
require "physics"
require "constants"
require "ScrollingTerrain"
require "GameLoop"
require "LevelDirector"
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

require "services_LoadLevelService"

require "screen_title"



local function initSounds()
	planeShootSound = audio.loadSound("plane_shoot.wav")

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
		player.planeXTarget = event.x
		player.planeYTarget = event.y
		handled = true
	end

	if(event.phase == "began") then
		playerWeapons.enabled = true
		handled = true
	end

	if(event.phase == "ended" or event.phase == "cancelled") then
		playerWeapons.enabled = false
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

function createBoss()
	local boss = BossBigPlane:new(player)
	boss:addEventListener("removeFromGameLoop", onBossDead)
	boss:addEventListener("fireShots", onFireBossShots)
	mainGroup:insert(boss)
	gameLoop:addLoop(boss)
end

function onFireBossShots(event)
	for i,point in ipairs(event.points) do
		local bullet = EnemyBulletSingle:new(point.x, point.y, player)
		mainGroup:insert(bullet)
		bullet:addEventListener("removeFromGameLoop", onRemoveFromGameLoop)
		gameLoop:addLoop(bullet)
	end
end

function onBossDead(event)
	local boss = event.target
	boss:removeEventListener("removeFromGameLoop", onBossDead)
	boss:removeEventListener("fireShots", onFireBossShots)
	gameLoop:removeLoop(boss)
	-- TODO: use correct animation, sucka! In fact, make an epic one!
	local death = EnemySmallShipDeath:new(boss.x, boss.y)
	mainGroup:insert(death)
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
end

function stopGame()
	gameLoop:stop()
	Runtime:removeEventListener("touch", onTouch)
	stopScrollingTerrain()
end

function pauseGame()
	print("pauseGame")
	gameLoop:pause()
	Runtime:removeEventListener("touch", onTouch)
	return true
end

function unpauseGame()
	print("unpauseGame")
	gameLoop:start()
	Runtime:addEventListener("touch", onTouch)
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
end

function initializeGame()
	print("initializeGame")
	
	print("\tstarting physics")
	physics.start()
	--physics.setDrawMode( "hybrid" )
	physics.setGravity( 0, 0 )
	
	print("\initializing MainContext")
	context = require("MainContext").new()
	context:init()
	
	print("\tmain group")
	mainGroup 						= display.newGroup()
	stage = display.getCurrentStage()
	
	--initTerrain()
	--initEnemeyDeath()

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
	--initPlayerDeath()
	
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
	local pauseButton = PauseButton:new(4, stage.height - 40)
	pauseButton:addEventListener("touch", onPauseTouch)

	print("\tparsing level")
	level = LoadLevelService:new("level.json")
	
	print("\tdrawing flight path checkpoints")
	flightPath:drawCheckpoints(level)

	--[[
	moviePlayer = MoviePlayerView:new()
	local t = {}
	function t:movieEnded(event)
		print("movieEnded, event: ", event)
	end
	--]]

	print("\thiding status bar")
	display.setStatusBar( display.HiddenStatusBar )

	print("\tinitializing keys")
	initKeys()
	
	print("\tdone initializeGame!")
end

initializeGame()
startGame()




-- tests
--[[
screenTitle:addEventListener("startGame", onStartGameTouched)
screenTitle:addEventListener("hideComplete", onTitleScreenHideComplete)
screenTitle:show()
]]--

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


