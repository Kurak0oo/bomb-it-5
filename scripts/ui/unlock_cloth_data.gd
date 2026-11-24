extends RefCounted
## Port of `zlong.bombit5.ui.unlockCloth.UnlockClothData`: which looks a score screen just
## unlocked per player (look numbers 1-8, `GameConfig.UNLOCK_SCORE_n`) and whether the
## unlock tip has shown them yet.

var robot1Id := 0
var robot2Id := 0
var unlockedP1Index: Array = []
var unlockedP2Index: Array = []
var isUsed1 := false
var isUsed2 := false
