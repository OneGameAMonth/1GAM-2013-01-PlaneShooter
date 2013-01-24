require "com.jessewarden.planeshooter.core.constants"
require "com.jessewarden.planeshooter.sprites.enemies.EnemyBulletSingle"
require "com.jessewarden.planeshooter.sounds.SoundManager"

BossBigPlane = {}

function BossBigPlane:new()
	if(BossBigPlane.bossSheet == nil) then
		local bossSheet = sprite.newSpriteSheet("boss_big_plane_sheet.png", 142, 98)
		local bossSet = sprite.newSpriteSet(bossSheet, 1, 2)
		sprite.add(bossSet, "bossSheetSet1", 1, 2, 100, 0)
		BossBigPlane.bossSheet = bossSheet
		BossBigPlane.bossSet = bossSet
		--BossBigPlane.hitSound = audio.loadSound("boss_hit_sound.mp3")
		--BossBigPlane.railHitSound = audio.loadSound("boss_rail_hit.wav")
		--BossBigPlane.fireSound = audio.loadSound("boss_big_plane_fire.wav")
		-- TODO/FIXME: wrong sound yo
		--BossBigPlane.deathSound = audio.loadSound("enemies/boss_hit_sound.mp3")
	end
	
	local boss = display.newGroup()
	local bossSpriteSheet = sprite.newSprite(BossBigPlane.bossSet)
	boss:insert(bossSpriteSheet)
	--bossSpriteSheet:setReferencePoint(display.TopLeftReferencePoint)
	boss.name = "Boss"
	boss.classType = "BossBigPlane"
	bossSpriteSheet:prepare("bossSheetSet1")
	bossSpriteSheet:play()
	-- TODO: maybe require sprite; not sure
	local stage = display.getCurrentStage()
	local middle = (stage.width / 2) - (boss.width / 2)
	boss.x = middle
	boss.y = -boss.height
	boss.speed = constants.ENEMY_BOSS_BIG_PLANE
	boss.targetX = stage.width / 2 - boss.width / 2
	boss.targetY = boss.height
	--[[
	boss.gunPoint1 = {x = 71, y = 23}
	boss.gunPoint2 = {x = 71, y = 44}
	boss.gunPoint3 = {x = 71, y = 68}
	--]]
	boss.gunPoint1 = {x = 0, y = -33}
	boss.gunPoint2 = {x = 0, y = 0}
	boss.gunPoint3 = {x = 0, y = 34}
	boss.gunPoint1Image = display.newImage("boss_big_plane_turret.png")
	boss.gunPoint2Image = display.newImage("boss_big_plane_turret.png")
	boss.gunPoint3Image = display.newImage("boss_big_plane_turret.png")
	boss:insert(boss.gunPoint1Image)
	boss:insert(boss.gunPoint2Image)
	boss:insert(boss.gunPoint3Image)
	boss.gunPoint1Image.x = boss.gunPoint1.x
	boss.gunPoint1Image.y = boss.gunPoint1.y
	boss.gunPoint2Image.x = boss.gunPoint2.x
	boss.gunPoint2Image.y = boss.gunPoint2.y
	boss.gunPoint3Image.x = boss.gunPoint3.x
	boss.gunPoint3Image.y = boss.gunPoint3.y
	boss.leftGunPoint = {x = -2, y = 0}
	boss.rightGunPoint = {x = 2, y = 0}
	boss.fireSpeed = 1600
	boss.fireCount = 0 -- which gun is firing, cycle through 5
	boss.fireCountMax = 5
	boss.lastTick = 0
	boss.hitPoints = 20
	boss.rot = math.atan2(boss.y -  playerView.x,  boss.x - playerView.y) / math.pi * 180 -90;
	boss.angle = (boss.rot -90) * math.pi / 180;
	boss.hoveringDirection = "right"
	
	
	local halfWidth = boss.width / 2
	local halfHeight = boss.height / 2
	local bossShape = {82-halfWidth,48-halfHeight, 98-halfWidth,94-halfHeight, 45-halfWidth,94-halfHeight, 62-halfWidth,48-halfHeight, 0-halfWidth,30-halfHeight, 0-halfWidth,0-halfHeight, 143-halfWidth,0-halfHeight, 143-halfWidth,30-halfHeight} 

	function boss:init()
		gameLoop:addLoop(boss)
		boss.tick = moveToFiringPosition
		boss.collision = onHit
		boss:addEventListener("collision", boss)
		physics.addBody( boss, { density = 1.0, friction = 0.3, bounce = 0.2, 
								bodyType = "kinematic", 
								isBullet = false, isSensor = true, isFixedRotation = false,
								shape=bossShape,
								filter = { categoryBits = 4, maskBits = 3 }
							} )
		SoundManager.inst:playBossBigPlaneEngineSound()
	end

	function boss:destroy()
		SoundManager.inst:stopBossBigPlaneEngineSound()
		gameLoop:removeLoop(self)
		-- TODO: remove from game loop and handle death dispatch
		self:dispatchEvent({name="enemyDead", target=self})
		self:dispatchEvent({name="onDestroy", target=self})
		self:removeSelf()
	end
	
	function moveToFiringPosition(self, millisecondsPassed)
		local deltaX = self.x - self.targetX
		local deltaY = self.y - self.targetY
		local dist = math.sqrt((deltaX * deltaX) + (deltaY * deltaY))

		local moveX = self.speed * (deltaX / dist) * millisecondsPassed
		local moveY = self.speed * (deltaY / dist) * millisecondsPassed
		
		if (math.abs(moveX) > dist or math.abs(moveY) > dist) then
			self.x = self.targetX
			self.y = self.targetY
			boss.tick = insanityFiringMode
		else
			self.x = self.x - moveX
			self.y = self.y - moveY
		end
	end
	
	function boss:getRotation(target)
		local targetX, targetY = target:localToContent(target.x, target.y)
		local rot = math.atan2(playerView.y - targetY, playerView.x - targetX) / math.pi * 180 - 90
		return rot
	end
	
	function insanityFiringMode(self, millisecondsPassed)
		self.lastTick = self.lastTick + millisecondsPassed
		--[[
		if(BossBigPlane.fireSoundChannel == nil) then
			print("------------ Playing fire sound ----------")
			BossBigPlane.fireSoundChannel = audio.play(BossBigPlane.fireSound, {loops=-1})
		end
		--]]
		
		local gunPoint1Img = boss.gunPoint1Image
		local gunPoint2Img  = boss.gunPoint2Image
		local gunPoint3Img  = boss.gunPoint3Image
		
		gunPoint1Img.rotation = boss:getRotation(gunPoint1Img )
		gunPoint2Img.rotation = boss:getRotation(gunPoint2Img )
		gunPoint3Img.rotation = boss:getRotation(gunPoint3Img )
		
		self:hover(millisecondsPassed)

		if(self.lastTick >= self.fireSpeed) then
			if(boss.fireCount + 1 <= boss.fireCountMax) then
				boss.fireCount = boss.fireCount + 1
			else
				boss.fireCount = 1
			end
			
			local gunPoint1 = self.gunPoint1
			local gunPoint2 = self.gunPoint2
			local gunPoint3 = self.gunPoint3
			local leftGunPoint = self.leftGunPoint
			local rightGunPoint = self.rightGunPoint
			local points = {
				{x=gunPoint1.x + self.x, y=gunPoint1.y + self.y},
				{x=gunPoint2.x + self.x, y=gunPoint2.y + self.y},
				{x=gunPoint3.x + self.x, y=gunPoint3.y + self.y},
				{x=leftGunPoint.x + self.x, y=leftGunPoint.y + self.y}, 
				{x=rightGunPoint.x + self.x, y=rightGunPoint.y + self.y}
			}
			
			local i = 1
			while points[i] do
				local point = points[i]
				local bullet = EnemyBulletSingle:new(point.x, point.y, playerView)
				mainGroup:insert(bullet)
				i = i + 1
			end

			self.lastTick = 0
			SoundManager.inst:playBossBigPlaneShootSound()
		else
			self.lastTick = self.lastTick + millisecondsPassed
		end
	end

	function boss:hover(millisecondsPassed)
		local targetX
		local stage = display.getCurrentStage()
		if self.hoveringDirection == "right" then
			targetX = stage.width - (self.width / 2)
		else
			targetX = self.width / 2
		end

		local deltaX = self.x - targetX
		local deltaY = 0
		local dist = math.sqrt((deltaX * deltaX) + (deltaY * deltaY))

		local moveX = (self.speed / 4) * (deltaX / dist) * millisecondsPassed

		
		--print("moveX: ", moveX, ", dist: ", dist)
		if math.abs(moveX) > dist then
			self.x = targetX
			if self.hoveringDirection == "right" then
				self.hoveringDirection = "left"
			else
				self.hoveringDirection = "right"
			end
		else
			self.x = self.x - moveX
		end
		
	end
	
	function onHit(self, event)
		-- TODO: ensure bullet name is same
		if(event.other.name == "Bullet" or event.other.name == "BulletRail") then
			self.hitPoints = self.hitPoints - 1
			if(event.other.name ~= "BulletRail") then
				event.other:destroy();
			end
			
			if(self.hitPoints <= 0) then
				SoundManager.inst:playBossBigPlaneDeathSound()
				self:dispatchEvent({name="death", target=self})
				self:destroy()
			else
				
				-- FIXME/TODO: I can't hear this play..... WHY NOT!?
				SoundManager.inst:playBossBigPlaneHitSound()
				if(event.other.name ~= "BulletRail") then
					--local chan = audio.play(BossBigPlane.hitSound)
					--audio.setVolume(.2, {channel=chan})
					
					--[[
					if(BossBigPlane.hitSoundChannel ~= nil) then
						audio.stop(BossBigPlane.hitSoundChannel)
						audio.rewind(BossBigPlane.hitSound)
						audio.play(BossBigPlane.hitSound, {channel=BossBigPlane.hitSoundChannel})
					else
						BossBigPlane.hitSoundChannel = audio.play(BossBigPlane.hitSound)
					end
				else
					if(BossBigPlane.railHitSoundChannel ~= nil) then
						audio.stop(BossBigPlane.railHitSoundChannel)
						audio.rewind(BossBigPlane.railHitSound)
						audio.play(BossBigPlane.railHitSound, {channel=BossBigPlane.railHitSoundChannel})
					else
						BossBigPlane.railHitSoundChannel = audio.play(BossBigPlane.railHitSound)
					end
					]]--
				end
				
					
					
				
				-- TODO: handle new event
				--createEnemyDeath(event.other.x, event.other.y)
				
			end
		end
	end
	
	boss:init()
	
	return boss
end

return BossBigPlane