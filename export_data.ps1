$leagueId = "82784331"
$seasonId = "2027"

Write-Host "Fetching League and Schedule..."
$leagueUrl = "https://lm-api-reads.fantasy.espn.com/apis/v3/games/fhl/seasons/${seasonId}/segments/0/leagues/${leagueId}?view=mTeam&view=mRoster&view=mMatchup&view=mSettings&view=mScoreboard"
$leagueData = Invoke-RestMethod -Uri $leagueUrl -Headers @{"User-Agent"="Mozilla/5.0"}

$schedRes = Invoke-RestMethod -Uri "https://lm-api-reads.fantasy.espn.com/apis/v3/games/fhl/seasons/${seasonId}?view=proTeamSchedules" -Headers @{"User-Agent"="Mozilla/5.0"}
$proTeams = $schedRes.settings.proTeams

$proTeamMap = @{
    0="FA"; 1="BOS"; 2="BUF"; 3="CGY"; 4="CHI"; 5="DET"; 6="EDM"; 7="CAR"; 8="LA"; 9="DAL"; 10="MTL"; 11="NJ"; 12="NYI"; 13="NYR"; 14="OTT"; 15="PHI"; 16="PIT"; 17="COL"; 18="SJ"; 19="STL"; 20="TB"; 21="TOR"; 22="VAN"; 23="WSH"; 25="ANA"; 26="FLA"; 27="NSH"; 28="WPG"; 29="CBJ"; 30="MIN"; 37="VGK"; 124292="SEA"; 129764="UTA"
}

$posMap = @{ 1="C"; 2="LW"; 3="RW"; 4="D"; 5="G" }
$slotMap = @{ 0="C"; 1="LW"; 2="RW"; 4="D"; 5="G"; 6="UTIL"; 7="BENCH"; 8="IR" }

# Weekly SPs: 21 (Mon Oct 19) to 27 (Sun Oct 25)
$spDays = [ordered]@{ "21"="Mon"; "22"="Tue"; "23"="Wed"; "24"="Thu"; "25"="Fri"; "26"="Sat"; "27"="Sun" }

# Team schedules this week
$nhlSchedule = @{}
foreach ($pt in $proTeams) {
    if ($pt.id -eq 0) { continue }
    $tAbbr = $proTeamMap[[int]$pt.id]
    $daysObj = [ordered]@{}
    $count = 0
    foreach ($sp in 21..27) {
        $spStr = $sp.ToString()
        $dayName = $spDays[$spStr]
        if ($pt.proGamesByScoringPeriod.psobject.properties[$spStr]) {
            $g = $pt.proGamesByScoringPeriod.psobject.properties[$spStr].Value[0]
            $oppId = if ($g.homeProTeamId -eq $pt.id) { $g.awayProTeamId } else { $g.homeProTeamId }
            $isHome = ($g.homeProTeamId -eq $pt.id)
            $oppAbbr = $proTeamMap[[int]$oppId]
            $vsStr = if ($isHome) { "vs $oppAbbr" } else { "@ $oppAbbr" }
            $daysObj[$dayName] = $vsStr
            $count++
        } else {
            $daysObj[$dayName] = ""
        }
    }
    $nhlSchedule[$tAbbr] = [ordered]@{
        Team = $tAbbr
        GamesCount = $count
        Days = $daysObj
    }
}

# Roster extraction helper
function Extract-Roster($tObj) {
    $roster = @()
    foreach ($entry in $tObj.roster.entries) {
        $p = $entry.playerPoolEntry.player
        $ptAbbr = $proTeamMap[[int]$p.proTeamId]
        $pos = $posMap[[int]$p.defaultPositionId]
        $slot = $slotMap[[int]$entry.lineupSlotId]
        
        # 2027 Projections (102027) & Actual (002027)
        $pProj = $p.stats | Where-Object { $_.id -eq "102027" }
        $pAct = $p.stats | Where-Object { $_.id -eq "002027" }
        
        $projPts = if ($pProj -and $pProj.appliedTotal -ne $null) { [math]::Round([double]$pProj.appliedTotal, 1) } else { 0 }
        $projAvg = if ($pProj -and $pProj.appliedAverage -ne $null) { [math]::Round([double]$pProj.appliedAverage, 2) } else { 0 }
        
        $actPts = if ($pAct -and $pAct.appliedTotal -ne $null) { [math]::Round([double]$pAct.appliedTotal, 1) } else { 0 }
        $actAvg = if ($pAct -and $pAct.appliedAverage -ne $null) { [math]::Round([double]$pAct.appliedAverage, 2) } else { 0 }
        
        $sched = if ($nhlSchedule.ContainsKey($ptAbbr)) { $nhlSchedule[$ptAbbr] } else { $null }

        $roster += [ordered]@{
            id = $p.id
            name = $p.fullName
            pos = $pos
            slot = $slot
            slotId = $entry.lineupSlotId
            team = $ptAbbr
            injury = $p.injuryStatus
            projPts = $projPts
            projAvg = $projAvg
            actPts = $actPts
            actAvg = $actAvg
            gamesCount = if ($sched) { $sched.GamesCount } else { 0 }
            schedule = if ($sched) { $sched.Days } else { @{} }
        }
    }
    return $roster
}

$myTeamObj = $leagueData.teams | Where-Object { $_.id -eq 7 }
$oppTeamObj = $leagueData.teams | Where-Object { $_.id -eq 10 }

$myRoster = Extract-Roster $myTeamObj
$oppRoster = Extract-Roster $oppTeamObj

Write-Host "Dead Lokomotiv players: $($myRoster.Count)"
Write-Host "Bay Ridge Icelanders players: $($oppRoster.Count)"

# Fetch Top Free Agents with live stats
Write-Host "Fetching live Free Agent pool..."
$filterObj = [ordered]@{
    players = [ordered]@{
        filterStatus = [ordered]@{ value = @("FREEAGENT", "WAIVERS") }
        filterSlotIds = [ordered]@{ value = [int[]](0..13) }
        filterStatsForTopScoringPeriodIds = [ordered]@{
            value = 5
            additionalValue = [string[]]@("102027","002027","002026","102026")
        }
        sortAppliedStatId = [ordered]@{ sortAsc = $false; sortPriority = 1; value = "102027" }
        sortDraftRanks = [ordered]@{ sortPriority = 100; sortAsc = $true; value = "STANDARD" }
        limit = [int]100
        offset = [int]0
    }
}
$filterJson = $filterObj | ConvertTo-Json -Depth 5 -Compress
$headers = @{ "User-Agent"="Mozilla/5.0"; "x-fantasy-filter"=$filterJson }
$faRes = Invoke-RestMethod -Uri "https://lm-api-reads.fantasy.espn.com/apis/v3/games/fhl/seasons/${seasonId}/segments/0/leagues/${leagueId}?view=kona_player_info" -Headers $headers

$freeAgents = @()
foreach ($item in $faRes.players) {
    $p = $item.player
    $ptAbbr = $proTeamMap[[int]$p.proTeamId]
    $pos = $posMap[[int]$p.defaultPositionId]
    
    $eligList = @()
    if ($p.eligibleSlots) {
        foreach ($sId in $p.eligibleSlots) {
            $sIdInt = [int]$sId
            if ($slotMap.ContainsKey($sIdInt) -and $sIdInt -le 5) {
                $posName = $slotMap[$sIdInt]
                if ($eligList -notcontains $posName) { $eligList += $posName }
            }
        }
    }
    $eligStr = if ($eligList.Count -gt 0) { $eligList -join "/" } else { $pos }
    
    $pProj = $p.stats | Where-Object { $_.id -eq "102027" }
    $pAct = $p.stats | Where-Object { $_.id -eq "002027" }
    
    $projPts = if ($pProj -and $pProj.appliedTotal -ne $null) { [math]::Round([double]$pProj.appliedTotal, 1) } else { 0 }
    $projAvg = if ($pProj -and $pProj.appliedAverage -ne $null) { [math]::Round([double]$pProj.appliedAverage, 2) } else { 0 }
    $actPts = if ($pAct -and $pAct.appliedTotal -ne $null) { [math]::Round([double]$pAct.appliedTotal, 1) } else { 0 }
    $actAvg = if ($pAct -and $pAct.appliedAverage -ne $null) { [math]::Round([double]$pAct.appliedAverage, 2) } else { 0 }
    $gp = if ($pAct -and $pAct.stats -and $pAct.stats.psobject.properties["30"]) { [double]$pAct.stats.psobject.properties["30"].Value } else { 0 }

    $sched = if ($nhlSchedule.ContainsKey($ptAbbr)) { $nhlSchedule[$ptAbbr] } else { $null }

    $freeAgents += [ordered]@{
        id = $p.id
        name = $p.fullName
        pos = $pos
        elig = $eligStr
        team = $ptAbbr
        status = $item.status
        injury = $p.injuryStatus
        projPts = $projPts
        projAvg = $projAvg
        actPts = $actPts
        actAvg = $actAvg
        actGP = $gp
        ownedPct = if ($p.ownership) { [math]::Round($p.ownership.percentOwned, 1) } else { 0 }
        gamesCount = if ($sched) { $sched.GamesCount } else { 0 }
        schedule = if ($sched) { $sched.Days } else { @{} }
    }
}

# Also ensure Tim Washe and Jack Roslovic are included if not already
$hasWashe = $freeAgents | Where-Object { $_.name -eq "Tim Washe" }
if (-not $hasWashe) {
    # Add Washe
    $schedW = $nhlSchedule["ANA"]
    $freeAgents += [ordered]@{
        id = 4996085
        name = "Tim Washe"
        pos = "C"
        elig = "C"
        team = "ANA"
        status = "FREEAGENT"
        injury = "ACTIVE"
        projPts = 0
        projAvg = 0
        actPts = 23.7
        actAvg = 3.39
        actGP = 7
        ownedPct = 0
        gamesCount = if ($schedW) { $schedW.GamesCount } else { 4 }
        schedule = if ($schedW) { $schedW.Days } else { @{} }
    }
}

$dataExport = [ordered]@{
    matchupPeriod = 4
    weekName = "Week 4 (Oct 19 - Oct 25, 2026)"
    myTeam = [ordered]@{
        name = "Dead Lokomotiv"
        abbrev = "DEAD"
        id = 7
        record = "2-1"
        roster = $myRoster
    }
    oppTeam = [ordered]@{
        name = "Bay Ridge Icelanders"
        abbrev = "ICE"
        id = 10
        record = "2-1"
        roster = $oppRoster
    }
    nhlSchedule = $nhlSchedule
    freeAgents = $freeAgents
}

$dataJson = $dataExport | ConvertTo-Json -Depth 6
$dest1 = "c:\Users\Andrew\Desktop\Projects\fantasy_hockey_data.js"
$dest2 = Join-Path $PSScriptRoot "fantasy_hockey_data.js"
"const fantasyData = $dataJson;" | Out-File -FilePath $dest1 -Encoding utf8
"const fantasyData = $dataJson;" | Out-File -FilePath $dest2 -Encoding utf8
Write-Host "Exported fantasy data to $dest1 and $dest2"
