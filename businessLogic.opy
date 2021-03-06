#!mainFile "conquest.opy"

subroutine customRespawn
subroutine shiftTeamSpawns
subroutine refillTeam1SpawnTix
subroutine refillTeam2SpawnTix

playervar selectedSpawnTix
playervar selectedSpawnLocation

#!define currSpawn(player) currTeamSpawns[0 if player.getTeam() == Team.1 else 1]

# Mark a Mercy player as having just resurrected
playervar justRessed
# Mark time of starting rez
playervar timeStartRez

rule "Track when a Mercy player uses rez":
    @Event eachPlayer
    @Hero mercy
    @Condition eventPlayer.isUsingAbility2()

    eventPlayer.timeStartRez = getTotalTimeElapsed()
    waitUntil(not eventPlayer.isUsingAbility2(), 1.5)
    # Detect if ability cancelled early
    if (abs(1.5 - (getTotalTimeElapsed() - eventPlayer.timeStartRez)) > 0.016):
        return
    wait(0.25)
    eventPlayer.justRessed = true
    wait(0.016)
    eventPlayer.justRessed = false


def customRespawn():
    @Name "SUB: Custom Respawn Logic"
    # Immediately abort custom respawn if the map is not initialized
    if not isMapInitialized():
        return
    if eventPlayer.isDead():
        eventPlayer.respawn()
    # If we're using random spawns (aka built-in spawn system), stop here.
    if spawnBehavior == RespawnLocations.RANDOM:
        return
    # Ignore a player who has probably just been resurrected
    if any([p.justRessed and distance(p, eventPlayer) <= 7 for p in getPlayers(eventPlayer.getTeam())]):
        # Secondary check: if they were at a pre-defined spawn point, they probably weren't ressed
        if not any([distance(loc, eventPlayer) < 0.01 for loc in getSpawnPoints(Team.ALL)]):
            return
    # Wait so we can actually affect the player
    wait()
    # Select a spot to respawn at
    eventPlayer.selectedSpawnTix = random.choice(team1SpawnTix if eventPlayer.getTeam() == Team.1 else team2SpawnTix)
    eventPlayer.selectedSpawnLocation = zoneSpawns[currSpawn(eventPlayer)][eventPlayer.selectedSpawnTix]
    # Remove ticket from pool
    if eventPlayer.getTeam() == Team.1:
        team1SpawnTix.remove(eventPlayer.selectedSpawnTix)
    else:
        team2SpawnTix.remove(eventPlayer.selectedSpawnTix)
    # Place the player facing the zone for their spawn
    eventPlayer.teleport(eventPlayer.selectedSpawnLocation)
    eventPlayer.setFacing(directionTowards(eventPlayer.getEyePosition(), zoneLocations[currSpawn(eventPlayer)]) * vect(1,0,1), Relativity.TO_WORLD)
    wait(0.25)

rule "If Team 1 has no more spawn tickets, refill them":
    @Condition isMapInitialized()
    @Condition len(team1SpawnTix) == 0

    refillTeam1SpawnTix()

rule "If Team 2 has no more spawn tickets, refill them":
    @Condition isMapInitialized()
    @Condition len(team2SpawnTix) == 0

    refillTeam2SpawnTix()

rule "Remove respawn buffered marker on respawn and trigger custom respawn logic":
    @Event eachPlayer
    @Condition eventPlayer.hasSpawned()
    @Condition eventPlayer.isAlive()
    # Reset for next death
    eventPlayer.respawnBuffered = false
    eventPlayer.respawnBlocked = false
    if not eventPlayer.isDummy():
        customRespawn()

rule "Main Respawn handler":
    @Event playerDied
    # If the event was a suicide, deduct points equivalent to granting enemy a kill
    if (attacker == eventPlayer):
        addToTeamScore(eventPlayer.getTeam(), -1 * max(len([c for c in zoneControl if c == getOppositeTeam(eventPlayer.getTeam())]), 1))
    # Block respawn until minimum respawn time
    victim.respawnBlocked = true
    # If currently power play, force respawn buffer
    if powerPlayActive:
        victim.respawnBuffered = true
    if spawnTimings == RespawnTimings.WAVES:
        # If needed, start a new respawn wave
        if victim.getTeam() == Team.1 and team1RespawnTimer == 0:
            team1RespawnTimer = maxRespawnTime
            chase(team1RespawnTimer, 0, rate=1, ChaseReeval.NONE)
        elif victim.getTeam() == Team.2 and team2RespawnTimer == 0:
            team2RespawnTimer = maxRespawnTime
            chase(team2RespawnTimer, 0, rate=1, ChaseReeval.NONE)
        # Track time until respawn. Player will match lowest respawn timer on their team while still being above minRespawnTime, but if no other players are dead, they will take maxRespawnTime to respawn.
        victim.timeToRespawn = max(team1RespawnTimer if victim.getTeam() == Team.1 else team2RespawnTimer, minRespawnTime)
    else:
        # Set time until first possible respawn to minRespawnTime
        victim.timeToRespawn = minRespawnTime
    # Begin respawn timer and wait until the timer is done
    chase(victim.timeToRespawn, 0, rate=1, ChaseReeval.NONE)
    wait(victim.timeToRespawn, Wait.RESTART_WHEN_TRUE)
    # Allow manual respawn
    victim.respawnBlocked = false
    # Respawn if they pressed jump while blocked
    if victim.respawnBuffered:
        victim.respawn()
    # Wait until max time before respawn
    waitUntil(victim.isAlive() or victim.isHoldingButton(Button.JUMP), 10)
    if victim.isDead():
        victim.respawn()

rule "If player attempts to respawn while blocked, mark them to respawn":
    @Event eachPlayer
    @Condition eventPlayer.isDead()
    @Condition eventPlayer.isHoldingButton(Button.JUMP)
    if eventPlayer.respawnBlocked:
        eventPlayer.respawnBuffered = true
        return
    eventPlayer.respawn()

rule "Reset on Game Start (Waiting for Players)":
	@Event global
    @Condition isGameInProgress()
    # Stop all zone progress
    stopAllProgress()
    # Reset Zones
    triggerPointReset()
    # Reset Scores
    setTeamScore(Team.1, 0)
    setTeamScore(Team.2, 0)

rule "Upon earning a kill, award points alongside bonuses for zones controlled":
	@Event playerDealtFinalBlow
    # Award points
    addToTeamScore(attacker.getTeam(), max(len([control for control in zoneControl if control == attacker.getTeam()]),1))
    if len([control for control in zoneControl if control == attacker.getTeam()]) >= 2:
        # Mark as valid target for feedback
        victim.validElimTarget = true

rule "Provide feedback on valid elimination":
    @Event playerEarnedElimination
    @Condition victim.validElimTarget
    # Provide visual feedback for bonus points
    smallMessage(attacker, "+{} for Zone Control".format(len([control for control in zoneControl if control == attacker.getTeam()]) - 1))
    # Provide audio feedback for bonus points
    async(playElimSounds, AsyncBehavior.NOOP)

def playElimSounds():
    @Name "SUB: Play sounds for earning elims with zone advantage"
    switch len([control for control in zoneControl if control == eventPlayer.getTeam()]):
        case 3:
            wait(0.5)
            playEffect(eventPlayer, DynamicEffect.BUFF_EXPLOSION_SOUND, Color.WHITE, eventPlayer.getPosition(), 200)
        default:
            wait(0.5)
            playEffect(eventPlayer, DynamicEffect.BUFF_EXPLOSION_SOUND, Color.WHITE, eventPlayer.getPosition(), 200)

rule "Remove validElim marker":
    @Event eachPlayer
    @Condition eventPlayer.validElimTarget
    wait(0.016, Wait.ABORT_WHEN_FALSE)
    eventPlayer.validElimTarget = false

rule "Declare Winner if a team has requisite number of points":
	@Event global
    @Condition isGameInProgress()
    # During overtime, teams do not necessarily need more than scoreToWin points, so we have a separate rule to handle overtime
    @Condition not overtime
    @Condition (teamScore(Team.1) >= scoreToWin or teamScore(Team.2) >= scoreToWin)
    @Condition teamScore(Team.1) != teamScore(Team.2)
    # If ending early requires a power play and there isn't one, reset to below the threshold
    if endRequiresPowerPlay and not all([c == zoneControl[0] for c in zoneControl]):
        if teamScore(Team.1) >= scoreToWin:
            setTeamScore(Team.1, scoreToWin - 1)
        if teamScore(Team.2) >= scoreToWin:
            setTeamScore(Team.2, scoreToWin - 1)
        return
    currScoreComp = teamScore(Team.1) - teamScore(Team.2)
    declareWinner()

rule "Regulation Time End Handler: Trigger Overtime or Declare Victory when regulation time runs out":
	@Event global
    @Condition isGameInProgress()
    @Condition getMatchTime() == 0
    @Condition not powerPlayActive
    @Condition not overtime
    # Cache result before buffer wait
    currScoreComp = teamScore(Team.1) - teamScore(Team.2)
    # Wait for two frames to alleviate potential race conditions
    wait(0.032, Wait.ABORT_WHEN_FALSE)
    # If teams are tied, initiate overtime (or declare draw if overtime not enabled)
    if currScoreComp == 0:
        if not overtimeEnabled:
            declareDraw()
            return
        bigMessage(getAllPlayers(), l"Overtime")
        setMatchTime(0.032)
        overtime = true
        wait(0.016)
        pauseMatchTime()
        setObjectiveDescription(getAllPlayers(), l"Overtime", HudReeval.VISIBILITY_AND_STRING)
    # Otherwise, declare a winner
    else:
        declareWinner()

rule "Maintain Overtime Music":
    @Event global
    @Condition isGameInProgress()
    @Condition overtime
    # The end-of-round music only lasts 30 seconds, so we must retrigger it every thirty seconds
    while overtime:
        wait(30, Wait.ABORT_WHEN_FALSE)
        setMatchTime(0)
        wait(0.016)
        setMatchTime(0.032)
        wait(0.016)
        pauseMatchTime()

rule "Overtime End Handler":
	@Event global
    @Condition overtime
    @Condition teamScore(Team.1) != teamScore(Team.2)
    # Update currScoreComp as needed by declare winner
    currScoreComp = teamScore(Team.1) - teamScore(Team.2)
    declareWinner()

def declareWinner():
    @Name "SUB: Declare Winner | UPDATE currScoreComp BEFORE CALLING THIS SUBROUTINE"
    if currScoreComp == 0:
        return
    if currScoreComp > 0:
        # Allow adequate time to process end of game
        wait(0.5)
        declareTeamVictory(Team.1)
    else:
        # Allow adequate time to process end of game
        wait(0.5)
        declareTeamVictory(Team.2)

def shiftTeamSpawns():
    @Name "SUB: Shift where teams spawn if necessary"
    # Don't shift spawns if shifting spawns are disabled
    if spawnBehavior != RespawnLocations.DYNAMIC:
        return
    # Team spawns swap if the swap would result in a more favorable zone control spawn for both teams
    if (zoneControl[currTeamSpawns[0]] == Team.2 and zoneControl[currTeamSpawns[1]] != Team.2) or (zoneControl[currTeamSpawns[0]] == null and zoneControl[currTeamSpawns[1]] == Team.1):
        # These three actions swap the team spawns by moving Team 1 spawn to the open zone, moving Team 2 to the zone Team 1 just vacated, and moving Team 1 to the zone Team 2 just vacated.
        currTeamSpawns[0] = getUnusedSpawn()
        currTeamSpawns[1] = getUnusedSpawn()
        currTeamSpawns[0] = getUnusedSpawn()
        # Refill spawn tickets for teams (new zone spawns)
        refillTeam1SpawnTix()
        refillTeam2SpawnTix()
        return
    # Team 1 spawn shifts to the unused spawn under any of the following conditions:
    # - Current Team 1 spawn controlled by Team 2 and the unused spawn is not controlled by Team 2
    # - Current Team 1 spawn is Neutral and the unused spawn is controlled by Team 1
    if (zoneControl[currTeamSpawns[0]] == Team.2 and zoneControl[getUnusedSpawn()] != Team.2) or (zoneControl[currTeamSpawns[0]] == null and zoneControl[getUnusedSpawn()] == Team.1):
        currTeamSpawns[0] = getUnusedSpawn()
        # Refill Team 1 spawn tickets due to new zone spawn
        refillTeam1SpawnTix()
    # Team 2 spawn shifts to the unused spawn under any of the following conditions:
    # - Current Team 2 spawn controlled by Team 1 and the unused spawn is not controlled by Team 1
    # - Current Team 2 spawn is Neutral and the unused spawn is controlled by Team 2
    # Note that we only want Team 1 or Team 2 spawns to shift at any one time, never both.
    elif (zoneControl[currTeamSpawns[1]] == Team.1 and zoneControl[getUnusedSpawn()] != Team.1) or (zoneControl[currTeamSpawns[1]] == null and zoneControl[getUnusedSpawn()] == Team.2):
        currTeamSpawns[1] = getUnusedSpawn()
        # Refill Team 2 spawn tickets due to new zone spawn
        refillTeam2SpawnTix()

def refillTeam1SpawnTix():
    @Name "SUB: Refill Team 1 Spawn Tickets"

    # Set to an empty array first, to avoid doubling up on initialization
    team1SpawnTix = []
    for i in range(0, len(zoneSpawns[currTeamSpawns[0]])):
        team1SpawnTix.append(i)

def refillTeam2SpawnTix():
    @Name "SUB: Refill Tam 2 Spawn Tickets"

    # Set to an empty array first, to avoid doubling up on initialization
    team2SpawnTix = []
    for i in range(0, len(zoneSpawns[currTeamSpawns[1]])):
        team2SpawnTix.append(i)
