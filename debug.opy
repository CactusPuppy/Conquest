#!mainFile "conquest.opy"

rule "DEBUG: Show CPU":
	@Event global
	@Condition createWorkshopSetting(bool, "Debug", "Show Server Load", false, 1)
	hudSubtext(getAllPlayers(), "Server Load: {0}".format(getServerLoad()), HudPosition.LEFT, -100, Color.WHITE, HudReeval.VISIBILITY_AND_STRING)
	hudSubtext(getAllPlayers(), "Server Avg: {0}".format(getAverageServerLoad()), HudPosition.LEFT, -99, Color.WHITE, HudReeval.VISIBILITY_AND_STRING)
	hudSubtext(getAllPlayers(), "Server Peak: {0}".format(getPeakServerLoad()), HudPosition.LEFT, -98, Color.WHITE, HudReeval.VISIBILITY_AND_STRING)

rule "DEBUG: Show Player Position":
	@Event eachPlayer
	@Condition createWorkshopSetting(bool, "Debug", "Show Player Position", false, 2)
	hudText(eventPlayer, eventPlayer.getPosition(), eventPlayer.getVerticalFacingAngle(), eventPlayer.getHorizontalFacingAngle(), HudPosition.LEFT, -0.5, Color.YELLOW, Color.WHITE, Color.AQUA, HudReeval.STRING, SpecVisibility.NEVER)

rule "DEBUG: Shorten assemble heroes":
	@Event global
	@Condition createWorkshopSetting(bool, "Debug", "Shorten Assemble Heroes", false, 3)
	@Condition isAssemblingHeroes()
    setMatchTime(10)

rule "DEBUG: Shorten match to 10 seconds":
	@Event global
	@Condition createWorkshopSetting(bool, "Debug", "Shorten Match Length", false, 4)
	@Condition isGameInProgress()
    setMatchTime(10)

rule "DEBUG: Summon Dummy Bot on Player upon Melee + Interact":
	@Event eachPlayer
	@Condition createWorkshopSetting(bool, "Debug", "Summon Dummy Bots (Manual)", false, 5)
	@Condition eventPlayer.isHoldingButton(Button.INTERACT) and eventPlayer.isHoldingButton(Button.MELEE)
	if eventPlayer.isHoldingButton(Button.CROUCH):
		createDummy(Hero.ASHE, getOppositeTeam(eventPlayer.getTeam()), -1, eventPlayer.getPosition(), vect(0,0,0))
	else:
		createDummy(Hero.ASHE, eventPlayer.getTeam(), -1, eventPlayer.getPosition(), vect(0,0,0))

rule "DEBUG: Summon Dummy Bot from each team in a zone 3 seconds after start":
	@Condition createWorkshopSetting(bool, "Debug", "Summon Dummy Bots (Automatic)", false, 6)
	@Condition isGameInProgress()
	wait(3)
	createDummy(random.choice(getAllHeroes()), Team.1, -1, zoneLocations[0], vect(0,0,0))
	getLastCreatedEntity().startForcingPosition(zoneLocations[0], true)
	createDummy(random.choice(getAllHeroes()), Team.2, -1, zoneLocations[1], vect(0,0,0))
	getLastCreatedEntity().startForcingPosition(zoneLocations[1], true)
	createDummy(random.choice(getAllHeroes()), Team.1, -1, zoneLocations[2], vect(0,0,0))
	getLastCreatedEntity().startForcingPosition(zoneLocations[2], true)
	
rule "DEBUG: Trigger Power Play after holding Interact for 3 seconds (crouch for enemy, default friendly)":
	@Event eachPlayer
	@Condition createWorkshopSetting(bool, "Debug", "Manual Power Play", false, 7)
	@Condition eventPlayer.isHoldingButton(Button.INTERACT)
	wait(0.5, Wait.ABORT_WHEN_FALSE)
	smallMessage(getAllPlayers(), "Forcing Power Play in 3")
	wait(1, Wait.ABORT_WHEN_FALSE)
	smallMessage(getAllPlayers(), "Forcing Power Play in 2")
	wait(1, Wait.ABORT_WHEN_FALSE)
	smallMessage(getAllPlayers(), "Forcing Power Play in 1")
	wait(1, Wait.ABORT_WHEN_FALSE)
	smallMessage(getAllPlayers(), "Forcing Power Play!")
	if eventPlayer.isHoldingButton(Button.CROUCH):
		zoneControl[0] = getOppositeTeam(eventPlayer.getTeam())
		zoneControl[1] = getOppositeTeam(eventPlayer.getTeam())
		zoneControl[2] = getOppositeTeam(eventPlayer.getTeam())
	else:
		zoneControl[0] = eventPlayer.getTeam()
		zoneControl[1] = eventPlayer.getTeam()
		zoneControl[2] = eventPlayer.getTeam()


rule "DEBUG: Show spawn points":
	@Event eachPlayer
	@Condition createWorkshopSetting(bool, "Debug", "Show Spawn Points", false, 8)

	for i in range(0,3):
		for j in range(0,len(zoneSpawns[i])):
			createEffect(getAllPlayers(), Effect.SPHERE, Color.WHITE if getUnusedSpawn() == evalOnce(i) else Color.TEAM_1 if currTeamSpawns[0] == evalOnce(i) else Color.TEAM_2, zoneSpawns[evalOnce(i)][evalOnce(j)], 0.5, EffectReeval.VISIBILITY_AND_COLOR)
			createInWorldText(getAllPlayers(), "{0} {1}".format(evalOnce(i), evalOnce(j)), zoneSpawns[evalOnce(i)][evalOnce(j)], 1, Clip.NONE, WorldTextReeval.VISIBILITY, Color.WHITE, SpecVisibility.DEFAULT)

rule "DEBUG: Prevent time from running out":
	@Condition createWorkshopSetting(bool, "Debug", "Stop Match Time", false, 9)
	@Condition isGameInProgress()
	pauseMatchTime()