> Imported Dots supplemental record; assertions are retained as delivered. Read the [integration assessment](../../../edition-5-play-observations.md) for confidence, corrections and remaining limits. Source-relative paths in code spans refer to the [unaltered original](../../../../../.scratch/edition-5-research/observations/swf-v1.6.1-followup/task2_mapping/README.md).

# Task 2: item and weapon map (help screen + XML + classes + sprite), and a behaviour search for bouncer, magic carpet and heavy bomb

Tags: [O] observed, [S] decompiled source or embedded XML, [I] inferred, [U] unknown.
Method: every class that sets `_propNum`. The icon a class shows is frame `_propNum` of the library sprite "prop" (character 6093), via `AbstractItem.setProp: gotoAndStop(_propNum)` [S].
The sprite's 50 frames were exported with FFDec (evidence/prop_sprite_*; derived from the SWF, **NOT FOR RELEASE**).
Help labels come from the in-game help page (evidence/help_POWERUPS_WEAPONS_VEHICLES_f601.png) [O].
Drop weights come from GameConfig.xml [S].

## Map of reachable items (menu modes: Arcade, Battle Royale, Pac-Man, Green Zone)
| Sprite frame / propNum | Class | Help label | Kind | Arcade weight | BR weight | Seen in play |
|---|---|---|---|---|---|---|
| 1 | NumProp | BOMB +1 | power-up | .28 | | yes [O] |
| 2 | PowProp | POWER BLAST +1 | power-up | .24 | | yes, potion f1882 session A [O] |
| 3 | SpeedProp | SPEED +10% | power-up | .22 | | |
| 4 | LifeProp | LIFE +1 | power-up | .005 | | |
| 22 | ShieldProp | SHIELD | power-up | .01 | | |
| 6 | BombShoesProp | PUSH THE BOMB (white hand) | power-up, kick | .10 | 0 | yes, pickup and kick (task 1) [O] |
| 7 | InvincibilityProp | INVINCIBILITY | power-up | .005 | | |
| 38 | BoxingProp ("boxing") | BOXING GLOVE | weapon | .01 | .15 | yes, pickup and 2 punches (task 1) [O] |
| 39 | LandmineProp ("mine") | LANDMINE | weapon | .01 | | icon on a floor in session C [O] |
| 21 | FlamerProp ("thrower") | FLAMETHROWER | weapon | .01 | | |
| 20 | LaserGunProp ("lasergun") | LIGHTNING GUN | weapon | .01 | | |
| 15 | HammerProp ("sinker"); KillModeWeapon extends it | HAMMER | weapon (melee, 1 cell) | .005 | default weapon in BR | yes, BR default (task 1) [O] |
| 50 | TripleShootGunProp ("shotgun") | MACHINE GUN | weapon | .01 | | |
| 49 | ShotGunProp ("fireball") | FIREBALL LAUNCHER | weapon | .01 | .15 | |
| 46 | HorseProp (vehicle "_forg") | FROG | vehicle; jumps one cell when blocked by an obstacle that is not a box or bomb | Vehicle .03 | .05 | yes, P1 mounted f1050 BR, jump animation seen [O] |
| 45 | CarProp ("_Car", speed x1.6) | SPORT CAR | vehicle | (Vehicle) | | |
| 47 | DragonProp ("_Elephant", x0.8) | MAMMOTH | vehicle; crashes through boxes | (Vehicle) | | |
| 48 | MotoCycleProp ("_Skateboard", x1.3) | SKATEBOARD | vehicle | (Vehicle) | | yes, ridden by the black AI in BR [O] |
| 36 | CoinProp | (none) | coin, mode item | | | |

Icon to label matches are by matching icon pictures plus the weaponName strings. The match TripleShootGunProp = MACHINE GUN is [I]; the others are strong [S+O].
Classes with no help label that only modes absent from the menu use (Water, Collect, Painting, Speed) [S]:
- GrenadeProp 26
- LauncherProp 16
- WaterGunProp 25
- the propNum-8 speed-mode rides: CarInSpeedMode, HooverCraftInSpeedMode "_Hoovercraft", HorseInSpeedMode "_Frog", MotoCycleInSpeedMode "_Plane"

**Sprite frames no class uses.** No class sets propNum 5, 9, 10, 12, 13, 23, 24, 27–33, 37 or 40–44, and nothing else assigns `_propNum` [S]. Those frames still hold icons:
- #27: a large black bowling-ball-like bomb
- #37: a shuriken
- #40: a **flying carpet**
- #31–33: sheep
- #43–44: masks
- #9, #12, #13, #28 (motorbike), #29 (horse), #30, #41, #42

## Behaviour-based search
| Wanted | Candidates (by behaviour) | Confidence | Verdict |
|---|---|---|---|
| **Bouncer** (bomb that bounces or is thrown) | (a) GrenadeProp: aimed throw over a 2-cell shot distance that lands a GrenadeBomb [S]; only in Water, Collect and Painting modes, which have no menu entry [S]. (b) BombShoesProp kick: a slide that stops on impact and does not bounce [O]. (c) ToyHand platform (BirthdayParty maps) pushes bombs [S]. (d) JumpTable redirects a kicked bomb at speed 10 [S], but no map data places a JumpTable [S] | low (none bounces) | **UNIDENTIFIED** as a bouncing bomb. Grenade is the closest "thrown bomb" and cannot be reached from the menu |
| **Magic carpet** (vehicle, flying) | (a) sprite frame #40 is a carpet icon, but no class uses frame 40 [S]. That does not prove the frame is never reached, because name and number searches do not cover every possible code path. (b) MotoCycleInSpeedMode, vehicle "_Plane", flying, speed mode only, no menu entry [S]. (c) HorseProp FROG hops over obstacles (seen, reachable) [O] | carpet art: high that it exists; usable item: none found | **UNIDENTIFIED as a usable item.** The art exists in the SWF but nothing reachable spawns it |
| **Heavy bomb** (large, maybe unkickable) | (a) sprite frame #27 is a large black ball icon, and no class uses frame 27 [S]. (b) bomb classes are Bomb, FireballBomb, FlamerFire, GrenadeBomb, LandmineBomb, Laser, LauncherBomb, TripleShootGunBomb and WaterBomb, and none is "heavy" or has a no-kick rule; kickBomb kicks every bomb on the cell [S]. (c) LandmineBomb is excluded from the AI's danger rays, but that is about visibility, not weight [S] | low | **UNIDENTIFIED** |

Demonstrated in play: FROG (mount, ride, jump animation, lost when hit) and SKATEBOARD (on an AI). Bouncer, carpet and heavy bomb: nothing to demonstrate, because none was found reachable.
Not proven absent: these verdicts mean "not identified with the evidence above". They are not proof of absence.
