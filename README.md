# Dead Lokomotiv Fantasy Hockey Matchup & Streamer Assistant

An interactive fantasy hockey dashboard and streaming recommendation tool built for ESPN Fantasy Hockey League **82784331** (*New Jersey Fantasy Hockey League*).

## 🚀 Features

- **💡 Move Recommendations**: Dynamic recommendations for short-term daily streaming targets (Monday/off-nights), rest-of-week upgrades, and goalie category stabilization.
- **📅 Day-by-Day Playbook**: Weekly game volume breakdown comparing Dead Lokomotiv vs. your opponent with slate density alerts.
- **⚔️ Head-to-Head Rosters**: Full lineup view with both 2027 preseason projections and actual 2026-27 season production, injury flags, and 7-day schedule chips.
- **🔍 Free Agent & Waiver Finder**: Real-time searchable database of available players with quick filters for position, banger stats, and tonight's games.

## 🛠️ Updating Data

To refresh the league matchups, live player rosters, and available free agents, run the included PowerShell script:

```powershell
.\export_data.ps1
```

This fetches the latest data directly from the ESPN Fantasy API and regenerates `fantasy_hockey_data.js`.
