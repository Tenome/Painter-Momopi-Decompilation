# Pseudocode of the main routines

Hand-written C-like summaries of routines that are fully understood. Names are the labels of `src/bank_NN.asm`. Each block says which file and
label it describes; the assembly is the source of truth (it assembles to the original ROM).

## PlayFrame (bank 1, `$4bde`): one frame of play mode

```c
void PlayFrame(void) {
    if (wGameFlags & 1) { RoundCleared(); return; }            // every cell painted
    if ((hSerialByte & 4) && (hSerialByte & 0x88)) { GotoLinkLose(); return; }   // other player lost
    if (wPlayerDir & 0x20) { PlayerDeath(); return; }          // set by an enemy touching the player or by stepping off the path

    PlayerAction();                                            // A button: cast the selected card, or start the next cast step
    if (!(wActiveMagic == CARD_W_IN && (wMagicState & 1))) {   // W.IN lets the painter walk through walls
        PlayerCheckOffPath();                                  // off the path on a grid cell = death
        LoadPlayerXY();
        PlayerComputeBlockedDirs();                            // wPlayerBlocked from the room map
    }
    HoldDirectionUntilAligned();                               // keeps the last direction until the next grid cell
    PlayerSetDirection();                                      // D-pad -> wPlayerDir and velocity
    ClampPlayerPosition();                                     // X $20-$f0, Y $28-$f8
    PaintUnderPlayer();                                        // sets the painted bit of the cell and queues the tile update
    SelectPlayerAnimation();
    ProjectileFrame();
    if (wActiveMagic != 0 && (wMagicState & 1)) {              // a card is running: the painter blinks
        if (!(++c4d3 & 2)) return;                             //   (drawn every other pair of frames)
    }
    AnimatePlayerWalk();
    SetObjPtr(&wPlayer);
    DrawObject();
}
```

## PlayerAction (bank 1, `$4c6f`): the A button

```c
void PlayerAction(void) {
    if (wMagicState & 1) { RunMagicEffect(); return; }         // effect already running: keep it going
    if (!(hJoyNew & A)) return;
    wPlayerDir |= 0x40;                                        // "action" bit
    wMagicState &= ~2;
    if (wActiveMagic == 0) return;                             // no card selected on the magic screen
    if (!(wPlayerStatus & 1)) return;
    wMagicState |= 1;                                          // running
    cost = MagicCostTable[wActiveMagic];
    if (wMagicPoints >= cost)  wMagicPoints -= cost, RunMagicEffect();
    else if (wMagicPointsHi)   { wMagicPoints = wMagicPoints - cost; wMagicPointsHi = 0; RunMagicEffect(); }  // borrow from the high byte
    else CancelMagic();                                        // not enough MP
}
```

## UpdateEnemy loop (bank 0, `$371c`)

```c
for (i = 15; i >= 0; i--) {
    SelectEnemySlot(EnemySlotTable, i);                        // hEnemySlot = &slot
    if (slot->flags & 0x80) {                                  // active
        LoadEnemySlot();                                       // copy 32 bytes slot -> hObject2 (HRAM)
        UpdateEnemy();                                         // jp EnemyBehaviorTable[hEnemyKind]
        StoreEnemySlot();                                      // copy back
    }
}
```

Each kind routine follows the same shape (`EnemyKind1` shown): tick the timer, handle being hit by paint (`EnemyDefeated`), compute the blocked directions
(`EnemyComputeBlockedDirs`, `EnemyEdgeBlockedDirs`), choose a direction (`EnemyChooseDirection`), move, test against the player (`CheckEnemyTouchesPlayer`)
and the paint blob (`CheckPaintHitsEnemy`), select the animation (`SelectEnemyAnimation`) and `DrawObject`. T.STOP (`wActiveMagic == CARD_T_STOP` with
`wMagicState & 1`) turns the direction step into `EnemyRequestTurn`, which freezes the enemy.

## Frame structure (bank 0)

```c
void VBlankHandler(void) {            // $02c0, interrupt
    if (hJoyHeld == 0x0f) { soft reset; }
    if (hVBlankTasks & 2) OamDma();                    // copy the OAM shadow ($c000)
    if (hVBlankTasks & 1) { VramCopyList(); hVBlankTasks &= ~1; }
    if (hVBlankTasks & 4) { VramCopyRows(); hVBlankTasks &= ~4; }
    SCX = wScrollX; SCY = wScrollY;
    if (hVBlankTasks & 2) { hVBlankTasks &= ~2; ClearOamShadowY(); }
    SoundUpdate();                                     // bank 1 $4157
    if ((hVBlankTasks & 0x10) && hTimeSeconds && --hTimeFrames < 0) { hTimeSeconds--; hTimeFrames = 60; }
    hVBlankFlag |= 1; hFrameCounter++;
}
```

## Mode1_Play (bank 0, `$10b5`): setup and main loop

```c
void Mode1_Play(void) {
    SP = wStackTop;  LcdOff();  di();
    FillBackwardsFF(vBGMapLast);  LoadGfxBank2();  ClearOamShadow();
    UnpackRoomMap(RoomMapTable[(wRound - 1) & 15]);              // 2 bit cells -> wRoomMap (16 x 16)
    DrawMetatileMap(vBGMap0, RoomMetatileTable[wRoomIndex], wRoomMap, mask 0x0f);
    RunVramCopyList(RoomVramJobTable[wRoomIndex]);               // static tiles and furniture
    wPaintRemaining = PaintCellCountTable[(wRound - 1) & 15];
    InitMagicScreenState(); InitMagicPoints(); ResetCamera();
    if (!(c51f & 4)) { c51f |= 4; ClearRoundVariables(); }       // once per round
    if (!(wGameFlags & 0x80)) { wGameFlags |= 0x80; InitPlayer(); ClearAllEnemies(); Clear32Bytes(wProjectile); }
    SerialStartTransfer();  scroll = 0;  IE = VBLANK|SERIAL;  LCDC = ON|BG|OBJ;  ei();
    StartRoundMusic();
    hTimeFrames = 60;  hTimeSeconds = RoundTimeTable[wRound / 4];   // 90 s in round 33
    hVBlankTasks |= 0x10;                                        // the VBlank handler now counts the time down
    for (;;) {
        WaitFrameAndSyncOam();  ReadJoypad();
        PlayFrame();  ShowMagicScreen();  UpdateCamera();
        StepEnemySpawnScript();  UpdateAllEnemies();
        TimeUpSpawnEnemy();  CheckExtraLife();
        hFrameCounter2++;
    }
}
```
