# Contraband Airways ✈

Cartoon, Roblox-safe tycoon management game.  
Four fictional cargo types drive a **Prepare → Launch → Chaos → Reward → Upgrade** loop across a stylised global map, scaling from a single island airstrip to an intercontinental smuggling empire.

---

## What this repo is

This is the **Luau source code** for a Roblox game, structured for [Rojo](https://rojo.space/) (sync to Studio) and [Wally](https://wally.run/) (package management).  
It does **not** contain a pre-built `.rbxl` place file — you build the place in Roblox Studio using Rojo after installing packages.

---

## Architecture: combining three existing patterns into one new loop

| Pattern | Where it comes from | How it's used here |
|---|---|---|
| **Knit** (`sleitnick/knit`) | Roblox framework kit | Service/Controller split; clean RemoteEvent handling |
| **ProfileService** (`madstudioroblox/profileservice`) | Industry-standard DataStore wrapper | Shared empire save + per-player stats; session locking |
| **Tycoon income loop** | Defaultio/loleris tycoon kits | Earn money → buy upgrades → reduce risk → earn more |
| **Fusion** (`elttob/fusion`) | Reactive UI framework | Overhead map overlay, cargo panel, Heat bar — no polling |
| **TweenService flight arc** | Roblox vehicle/tycoon kits | Plane flies along waypoint chain automatically |

None of these repos already do "planes + global routes + tycoon + co-op" — **this codebase combines them into one new loop**.

---

## File structure

```
default.project.json   ← Rojo wiring: Server / Client / Shared
wally.toml             ← Knit, ProfileService, Fusion, Signal

src/
├── Shared/
│   ├── ProfileTemplate.lua       ← empire + per-player default data shape
│   └── Data/
│       ├── CargoData.lua         ← 5 cartoon cargo types with full stats
│       ├── RouteData.lua         ← 13 air + sea routes across 3 tiers
│       └── UpgradeData.lua       ← 16 hub buildings + 3 global upgrades
│
├── Server/
│   ├── init.server.lua           ← Knit bootstrap (loads all services)
│   └── Services/
│       ├── PlaneService.lua      ← spawn / load / tween / destroy planes
│       ├── RouteService.lua      ← waypoint flight loop, risk + payout calc
│       ├── HeatService.lua       ← global + per-hub Heat, decay, escalation
│       ├── EventManager.lua      ← chaos events (leak, patrol, rival, weather…)
│       ├── CargoService.lua      ← server-side cargo validation + tier gates
│       ├── UpgradeService.lua    ← purchase / level buildings, defence bonus
│       └── EmpireService.lua     ← ProfileService glue + LaunchRun loop
│
└── Client/
    ├── init.client.lua           ← Knit bootstrap (loads all controllers)
    └── Controllers/
        ├── CameraController.lua  ← overhead pan / zoom camera (WASD + scroll)
        ├── MapController.lua     ← Fusion-reactive world map + alert banners
        └── CargoController.lua   ← drag-to-load cargo panel + route selector
```

---

## The feedback loop (how the pieces connect)

```
Player clicks plane on map
        │
        ▼
CargoController  ──(LoadCargo RemoteFunction)──►  CargoService (validates tier + slots)
        │                                                │
        │                                               ▼
        │                                         PlaneService (stores manifest)
        │
Player picks route + clicks Launch
        │
        ▼
EmpireService:LaunchRun
        │
        ├─► RouteService:StartFlight
        │       │
        │       ├── per waypoint: EventManager:TriggerChaosEvent  ──► HeatService:AddHeat
        │       │       └── client alert via EventManager.Client.ChaosEventFired
        │       │
        │       ├── per waypoint: bust roll (risk vs defence bonus)
        │       │
        │       ├── onBust  ──► HeatService:AddHeat (bust penalty)
        │       │           └─► EmpireService.Client.RunCompleted (isSuccess=false)
        │       │
        │       └── onComplete ──► EmpireService:AddMoney(payout)
        │                      ├─► HeatService:AddHeat (success heat)
        │                      ├─► Tier unlock check → new hubs / routes
        │                      └─► EmpireService.Client.RunCompleted (isSuccess=true)
        │
        └── MapController / CargoController update reactively via Fusion
```

---

## Cargo types

| ID | Display name | Slots | Payout ★ | Base risk | Chaos event | Unlock tier |
|---|---|---|---|---|---|---|
| `ShinyRocks` | Shiny Rocks | 1 | ★★★★★ | 40% | RivalTheft | 1 |
| `MysteryPowder` | Mystery Powder | 2 | ★★★★ | 60% | LeakSpill | 1 |
| `HeavyToolkits` | Heavy Toolkits | 3 | ★★★★★ | 75% | MilitaryPatrol | 2 |
| `GlowDisks` | Glow-Disks | 1 | ★★★ | 30% | DigitalTrace | 1 |
| `ExoticGoods` | Exotic Goods | 2 | ★★★½ | 45% | PetEscape | 3 |

---

## Routes

### Tier 1 — Regional (home base + 3 routes)
| Route | Best cargo | Payout | Risk |
|---|---|---|---|
| Caribbean Shadow Hop | MysteryPowder / ShinyRocks | 500 | 35% |
| Andes Express | MysteryPowder / HeavyToolkits | 800 | 60% |
| Border Blitz | Any | 600 | 50% |

### Tier 2 — Continental (unlock at 50k ₿)
| Route | Best cargo | Payout | Risk | Type |
|---|---|---|---|---|
| Atlantic Crossing | HeavyToolkits / ShinyRocks | 2 000 | 80% | Air |
| Sahel Sparkle Run | ShinyRocks | 1 600 | 65% | Air |
| Golden Triangle Dash | GlowDisks / MysteryPowder | 1 400 | 55% | Air |
| West Africa Sea Lane | ShinyRocks / ExoticGoods | 1 200 | 40% | 🚢 Sea |

### Tier 3 — Global (unlock at 500k ₿)
| Route | Best cargo | Payout | Risk | Type |
|---|---|---|---|---|
| Pacific Rim Orbit | GlowDisks | 2 500 | 45% | Air |
| Mediterranean Run | GlowDisks / ShinyRocks | 1 800 | 60% | Air |
| Northern Passage | HeavyToolkits | 3 000 | 70% | Air |
| Southern Cross | ShinyRocks / GlowDisks | 3 500 | 30% | Air |
| Indian Ocean Arc | ExoticGoods / ShinyRocks | 2 200 | 35% | 🚢 Sea |
| Silk Sea Lane | GlowDisks / ExoticGoods | 2 800 | 40% | 🚢 Sea |
| Trans-Pacific Freighter | ExoticGoods / ShinyRocks | 3 200 | 25% | 🚢 Sea |

---

## SimCity-style upgrades

### Per-hub buildings (Tier 1–2)
`PerimeterFence` · `Watchtowers` · `FakeCargoDepots` · `LaunderingOffice` · `CamouflageLandscaping` · `Cleaners` · `JammingTower` · `UndergroundHangar` · `CommandBunker` · `BribeOffice` · `ReputationPRBuilding` · `RadarTower` · `FakeTerminal`

### Global / empire-wide upgrades (Tier 2–3)
`DecoyFleet` · `SatelliteJammingNetwork` · `InternationalLaunderingWeb`

---

## Quickstart

### Prerequisites
- [Rojo](https://rojo.space/) ≥ 7.x  
- [Wally](https://wally.run/)  
- Roblox Studio  

### Steps

```bash
# 1. Install Wally packages (creates ./Packages for Rojo)
wally install

# 2. Start Rojo server
rojo serve default.project.json

# 3. In Roblox Studio → Rojo plugin → Connect
# 4. Play-test — server and client bootstrap automatically via init scripts
```

---

## Getting a tester-ready build (no Rojo plugin needed)

### Option A — Download a prebuilt place from GitHub Actions (recommended)
- Go to the repo’s **Actions** tab → open the latest **Build Roblox place** run
- Download the artifact named `ContrabandAirways-place`
- You’ll get `ContrabandAirways.rbxlx` (a ready-to-open Roblox Studio place file)

### Option B — Build locally

If you have [Aftman](https://github.com/LPGhatguy/aftman) installed, this is one command:

```bash
./scripts/build-place.sh
```

That produces `build/ContrabandAirways.rbxlx`.

### Uploading to Roblox for testers
1. Open `ContrabandAirways.rbxlx` in Roblox Studio.
2. **File → Publish to Roblox As…** (create a new experience if needed).
3. In **Game Settings**:
   - Set **Privacy** to **Private** or **Unlisted**
   - Add your testers under **Permissions**
4. Use Roblox Studio **Test** / **Start Server** to run multiplayer playtests.

### Adding a new route
1. Add an entry to `src/Shared/Data/RouteData.lua` following the `RouteDef` type.  
2. Add `SpawnPad` and `LandingPad` BaseParts under `workspace.Hubs.<HubName>` in Studio.  
3. No other code changes needed — `RouteService` and the UI pick it up automatically.

### Adding a new upgrade
1. Add an entry to `src/Shared/Data/UpgradeData.lua` following the `UpgradeDef` type.  
2. `UpgradeService` and the client UI pick it up automatically.

---

## Multiplayer co-op notes
- One **shared empire profile** (ProfileService) for the whole server — all players write to the same `BlackMoney`, `GlobalHeat`, and `HubLayouts`.  
- **Per-player stats** (contribution, badges, favourite cargo) are stored in a separate per-UserId profile.  
- Up to 4 planes can be prepped and in-flight simultaneously with no structural changes.  
- Friends divide roles naturally: one loads ShinyRocks, another handles HeavyToolkits, a third watches the Heat bar and buys decoy upgrades.

---

## Roblox TOS / moderation notes
All cargo types use fictional placeholder names and cartoon visual styles.  
No real-world goods, textures, or instructional content is included.  
Targeting age 9+ (same as most tycoon games on Roblox).

