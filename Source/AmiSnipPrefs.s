;=====================================================================
; AmiSnipPrefs 1.1 - preferences editor for the AmiSnip commodity
; by Amigatronics - https://amigatronics.com
;
; Writes ENV:AmiSnip.prefs (Use) and ENVARC:AmiSnip.prefs (Save).
; The running commodity notices the change and reloads it.
;
; Assemble: vasmm68k_mot -Fhunkexe -kick1hunks -nosym -m68000
;=====================================================================

        machine 68000
        include "lvo.i"
        include "about_img.i"

GFLG_SELECTED           equ $80
BACKGROUNDPEN           equ 7
TEXTPEN                 equ 2
HIGHLIGHTTEXTPEN        equ 8

; gadget ids
G_ENABLED               equ 1
G_HOTKEY                equ 2
G_SAVEDIR               equ 3
G_SAVESEL               equ 4
G_FORMAT                equ 5
G_ACTION                equ 6
G_VIEWER                equ 7
G_VIEWSEL               equ 8
G_DIM                   equ 9
G_COLOR                 equ 10
G_BEEP                  equ 11
G_SAVE                  equ 12
G_USE                   equ 13
G_CANCEL                equ 14
G_JPEGQ                 equ 15

MARGIN                  equ 10

;=====================================================================
        section code,code
;=====================================================================

Start:
        move.l  4.w,a6
        move.l  a6,SysBase
        sub.l   a1,a1
        CALL    FindTask
        move.l  d0,a4
        tst.l   172(a4)
        bne     .cli
        lea     92(a4),a0
        CALL    WaitPort
        lea     92(a4),a0
        CALL    GetMsg
        move.l  d0,WBMsg
.cli:   bsr     Main
        move.l  d0,d7
        move.l  WBMsg,d0
        beq     .exit
        move.l  SysBase,a6
        CALL    Forbid
        move.l  WBMsg,a1
        CALL    ReplyMsg
.exit:  move.l  d7,d0
        rts

        dc.b    "$VER: AmiSnipPrefs 1.3 (22.11.2026) by Amigatronics",0
        even

;---------------------------------------------------------------------
Main:
        movem.l d2-d7/a2-a6,-(sp)
        moveq   #20,d0
        move.l  d0,RetCode
        move.l  SysBase,a6
        lea     LibTable,a2
.ol:    move.l  (a2)+,d0
        beq     .libsok
        move.l  d0,a1
        move.l  (a2)+,d0
        move.l  (a2)+,a3
        move.l  (a2)+,d2
        CALL    OpenLibrary
        move.l  d0,(a3)
        bne     .ol
        tst.l   d2
        bne     .cleanup
        bra     .ol
.libsok:
        bsr     LoadPrefs
        bsr     OpenGUI
        tst.l   d0
        beq     .gui
        clr.l   RetCode
        bsr     EventLoop
.gui:   bsr     CloseGUI
.cleanup:
        move.l  FileReq,d0
        beq     .nofr
        move.l  AslBase,a6
        move.l  d0,a0
        CALL    FreeAslRequest
.nofr:  move.l  SysBase,a6
        lea     LibBases,a2
        moveq   #NUMLIBS-1,d2
.cl:    move.l  (a2)+,d0
        beq     .cn
        move.l  d0,a1
        CALL    CloseLibrary
.cn:    dbra    d2,.cl
        move.l  RetCode,d0
        movem.l (sp)+,d2-d7/a2-a6
        rts

;---------------------------------------------------------------------
; a0 = string -> d0 = pixel width in the screen font
TextW:  movem.l d1/a0-a1/a6,-(sp)
        move.l  a0,a1
        moveq   #-1,d0
.l:     addq.l  #1,d0
        tst.b   (a1)+
        bne     .l
        move.l  GfxBase,a6
        move.l  Scr,a1
        lea     84(a1),a1
        CALL    TextLength
        and.l   #$FFFF,d0
        movem.l (sp)+,d1/a0-a1/a6
        rts

; a0 = table of string pointers (0 terminated) -> d0 = widest
MaxTextW:
        movem.l d1/a2,-(sp)
        move.l  a0,a2
        moveq   #0,d1
.l:     move.l  (a2)+,d0
        beq     .e
        move.l  d0,a0
        bsr     TextW
        cmp.l   d1,d0
        ble     .l
        move.l  d0,d1
        bra     .l
.e:     move.l  d1,d0
        movem.l (sp)+,d1/a2
        rts

; y of row d0 -> d0
RowY:   mulu.w  Step+2,d0
        add.l   BordT,d0
        add.l   #MARGIN,d0
        rts

; d0 kind, d1 x, d2 y, d3 w, d4 h, a0 label, d5 flags, d6 id, a2 tags
MakeGad:
        movem.l d0-d7/a0-a6,-(sp)
        lea     NG,a1
        move.w  d1,(a1)
        move.w  d2,2(a1)
        move.w  d3,4(a1)
        move.w  d4,6(a1)
        move.l  a0,8(a1)
        move.l  TA,12(a1)
        move.w  d6,16(a1)
        move.l  d5,18(a1)
        move.l  VI,22(a1)
        clr.l   26(a1)
        move.l  PrevGad,d7
        beq     .fail
        move.l  d7,a0
        move.l  GadBase,a6
        CALL    CreateGadgetA
        move.l  d0,PrevGad
        beq     .fail
        lea     Gads,a0
        move.w  d6,d1
        lsl.w   #2,d1
        move.l  d0,(a0,d1.w)
.fail:  movem.l (sp)+,d0-d7/a0-a6
        rts

;---------------------------------------------------------------------
OpenGUI:
        movem.l d2-d7/a2-a6,-(sp)
        move.l  IntBase,a6
        sub.l   a0,a0
        CALL    LockPubScreen
        move.l  d0,Scr
        beq     .fail
        move.l  GadBase,a6
        move.l  d0,a0
        sub.l   a1,a1
        CALL    GetVisualInfoA
        move.l  d0,VI
        beq     .fail
        move.l  Scr,a2
        move.l  40(a2),a0
        move.l  a0,TA
        moveq   #0,d0
        move.w  4(a0),d0
        move.l  d0,FontH
        addq.l  #6,d0
        move.l  d0,RowH
        addq.l  #3,d0
        move.l  d0,Step
        moveq   #0,d0
        move.b  36(a2),d0
        move.l  d0,BordL
        moveq   #0,d0
        move.b  35(a2),d0
        add.l   FontH,d0
        addq.l  #1,d0
        move.l  d0,BordT
        lea     LeftLabels,a0
        bsr     MaxTextW
        add.l   #12,d0
        move.l  d0,LW
        lea     LSelect,a0
        bsr     TextW
        add.l   #16,d0
        move.l  d0,SBW
        lea     FieldSample,a0
        bsr     TextW
        move.l  d0,FW
        lea     ButtonLabels,a0
        bsr     MaxTextW
        add.l   #32,d0
        move.l  d0,BW
        move.l  BordL,d0
        add.l   #MARGIN,d0
        add.l   LW,d0
        move.l  d0,X0
        move.l  LW,d0
        add.l   FW,d0
        add.l   SBW,d0
        add.l   #MARGIN*2+4,d0
        move.l  BW,d1
        mulu.w  #3,d1
        add.l   #MARGIN*2+20,d1
        cmp.l   d1,d0
        bge     .wok
        move.l  d1,d0
.wok:   move.l  d0,InnerW
        moveq   #10,d0
        mulu.w  Step+2,d0
        add.l   RowH,d0
        add.l   #MARGIN*2+4,d0
        move.l  d0,InnerH
        ; checkbox size
        move.l  FontH,d0
        add.l   d0,d0
        add.l   #10,d0
        move.l  d0,CBW
        move.l  FontH,d0
        addq.l  #3,d0
        move.l  d0,CBH

        move.l  GadBase,a6
        lea     GList,a0
        CALL    CreateContext
        move.l  d0,PrevGad
        beq     .fail

        ; row 0: enabled
        moveq   #0,d0
        move.b  Prefs+P_Enabled,d0
        moveq   #G_ENABLED,d6
        lea     LEnabled,a0
        moveq   #0,d7
        bsr     MakeCheck
        ; row 1: hotkey
        move.l  #Prefs+P_Hotkey,ST_Str
        move.l  #HOTKEYLEN-1,ST_Max
        moveq   #1,d0
        bsr     RowY
        move.l  d0,d2
        move.l  X0,d1
        move.l  FW,d3
        add.l   SBW,d3
        addq.l  #4,d3
        move.l  RowH,d4
        lea     LHotkey,a0
        moveq   #PLACETEXT_LEFT,d5
        moveq   #G_HOTKEY,d6
        lea     StrTags,a2
        moveq   #STRING_KIND,d0
        bsr     MakeGad
        ; row 2: save drawer + select
        move.l  #Prefs+P_SaveDir,ST_Str
        move.l  #PATHLEN-1,ST_Max
        moveq   #2,d0
        moveq   #G_SAVEDIR,d6
        lea     LSaveDir,a0
        bsr     MakeStrSel
        ; row 3: format
        move.l  #FormatLabels,CY_Lab
        moveq   #0,d0
        move.b  Prefs+P_Format,d0
        move.l  d0,CY_Act
        moveq   #3,d0
        moveq   #G_FORMAT,d6
        lea     LFormat,a0
        bsr     MakeCycle
        ; row 4: JPEG quality slider
        moveq   #0,d0
        move.b  Prefs+P_JpegQ,d0
        move.l  d0,SL_Lev
        moveq   #4,d0
        bsr     RowY
        move.l  d0,d2
        move.l  X0,d1
        move.l  FW,d3
        lea     LevelSample,a0
        bsr     TextW
        addq.l  #8,d0
        sub.l   d0,d3
        move.l  RowH,d4
        lea     LJpegQ,a0
        moveq   #PLACETEXT_LEFT,d5
        moveq   #G_JPEGQ,d6
        lea     SlTags,a2
        moveq   #SLIDER_KIND,d0
        bsr     MakeGad
        ; row 5: action
        move.l  #ActionLabels,CY_Lab
        moveq   #0,d0
        move.b  Prefs+P_Action,d0
        move.l  d0,CY_Act
        moveq   #5,d0
        moveq   #G_ACTION,d6
        lea     LAction,a0
        bsr     MakeCycle
        ; row 5: viewer + select
        move.l  #Prefs+P_Viewer,ST_Str
        move.l  #PATHLEN-1,ST_Max
        moveq   #6,d0
        moveq   #G_VIEWER,d6
        lea     LViewer,a0
        bsr     MakeStrSel
        ; row 6: dim
        move.l  #DimLabels,CY_Lab
        moveq   #0,d0
        move.b  Prefs+P_Dim,d0
        move.l  d0,CY_Act
        moveq   #7,d0
        moveq   #G_DIM,d6
        lea     LDim,a0
        bsr     MakeCycle
        ; row 7: frame colour
        move.l  #ColorLabels,CY_Lab
        moveq   #0,d0
        move.b  Prefs+P_Color,d0
        move.l  d0,CY_Act
        moveq   #8,d0
        moveq   #G_COLOR,d6
        lea     LColor,a0
        bsr     MakeCycle
        ; row 8: beep
        moveq   #0,d0
        move.b  Prefs+P_Beep,d0
        moveq   #G_BEEP,d6
        lea     LBeep,a0
        moveq   #9,d7
        bsr     MakeCheck
        ; buttons
        moveq   #10,d0
        bsr     RowY
        addq.l  #4,d0
        move.l  d0,d2
        move.l  BW,d3
        move.l  RowH,d4
        moveq   #PLACETEXT_IN,d5
        lea     NoTags,a2
        move.l  BordL,d1
        add.l   #MARGIN,d1
        lea     LSave,a0
        moveq   #G_SAVE,d6
        moveq   #BUTTON_KIND,d0
        bsr     MakeGad
        move.l  InnerW,d1
        sub.l   BW,d1
        lsr.l   #1,d1
        add.l   BordL,d1
        lea     LUse,a0
        moveq   #G_USE,d6
        moveq   #BUTTON_KIND,d0
        bsr     MakeGad
        move.l  InnerW,d1
        sub.l   BW,d1
        sub.l   #MARGIN,d1
        add.l   BordL,d1
        lea     LCancel,a0
        moveq   #G_CANCEL,d6
        moveq   #BUTTON_KIND,d0
        bsr     MakeGad
        tst.l   PrevGad
        beq     .fail
        ; menus
        move.l  GadBase,a6
        lea     NewMenus,a0
        sub.l   a1,a1
        CALL    CreateMenusA
        move.l  d0,Menu
        beq     .fail
        move.l  d0,a0
        move.l  VI,a1
        lea     MenuLayTags,a2
        CALL    LayoutMenusA
        ; window, centred on the screen
        move.l  Scr,a2
        moveq   #0,d0
        move.w  12(a2),d0
        sub.l   InnerW,d0
        sub.l   BordL,d0
        sub.l   BordL,d0
        asr.l   #1,d0
        bpl     .x
        moveq   #0,d0
.x:     move.l  d0,MW_L
        moveq   #0,d0
        move.w  14(a2),d0
        sub.l   InnerH,d0
        sub.l   BordT,d0
        asr.l   #1,d0
        bpl     .y
        moveq   #0,d0
.y:     move.l  d0,MW_T
        move.l  InnerW,MW_IW
        move.l  InnerH,MW_IH
        move.l  Scr,MW_Scr
        move.l  GList,MW_Gad
        move.l  IntBase,a6
        sub.l   a0,a0
        lea     MainWinTags,a1
        CALL    OpenWindowTagList
        move.l  d0,Win
        beq     .fail
        move.l  d0,a0
        move.l  Menu,a1
        CALL    SetMenuStrip
        move.l  GadBase,a6
        move.l  Win,a0
        sub.l   a1,a1
        CALL    GT_RefreshWindow
        moveq   #1,d0
        bra     .ret
.fail:  moveq   #0,d0
.ret:   movem.l (sp)+,d2-d7/a2-a6
        rts

; d0 = checked, d6 = id, a0 = label, d7 = row
MakeCheck:
        move.l  d0,CB_Val
        move.l  d7,d0
        bsr     RowY
        move.l  RowH,d1
        sub.l   CBH,d1
        lsr.l   #1,d1
        add.l   d1,d0
        move.l  d0,d2
        move.l  X0,d1
        move.l  CBW,d3
        move.l  CBH,d4
        moveq   #PLACETEXT_RIGHT,d5
        lea     CBTags,a2
        moveq   #CHECKBOX_KIND,d0
        bra     MakeGad

; d0 = row, d6 = id (string; id+1 = select button), a0 = label
MakeStrSel:
        bsr     RowY
        move.l  d0,d2
        move.l  X0,d1
        move.l  FW,d3
        move.l  RowH,d4
        moveq   #PLACETEXT_LEFT,d5
        move.l  a0,-(sp)
        lea     StrTags,a2
        moveq   #STRING_KIND,d0
        bsr     MakeGad
        move.l  (sp)+,a0
        add.l   FW,d1
        addq.l  #4,d1
        move.l  SBW,d3
        lea     LSelect,a0
        moveq   #PLACETEXT_IN,d5
        addq.l  #1,d6
        lea     NoTags,a2
        moveq   #BUTTON_KIND,d0
        bra     MakeGad

; d0 = row, d6 = id, a0 = label  (CY_Lab/CY_Act set)
MakeCycle:
        bsr     RowY
        move.l  d0,d2
        move.l  X0,d1
        move.l  FW,d3
        move.l  RowH,d4
        moveq   #PLACETEXT_LEFT,d5
        lea     CyTags,a2
        moveq   #CYCLE_KIND,d0
        bra     MakeGad

CloseGUI:
        move.l  IntBase,a6
        move.l  Win,d0
        beq     .nw
        move.l  d0,a0
        CALL    ClearMenuStrip
        move.l  Win,a0
        CALL    CloseWindow
        clr.l   Win
.nw:    move.l  GadBase,a6
        move.l  Menu,d0
        beq     .nm
        move.l  d0,a0
        CALL    FreeMenus
        clr.l   Menu
.nm:    move.l  GList,a0
        CALL    FreeGadgets
        clr.l   GList
        move.l  VI,d0
        beq     .nv
        move.l  d0,a0
        CALL    FreeVisualInfo
        clr.l   VI
.nv:    move.l  Scr,d0
        beq     .ns
        move.l  IntBase,a6
        sub.l   a0,a0
        move.l  d0,a1
        CALL    UnlockPubScreen
        clr.l   Scr
.ns:    rts

;---------------------------------------------------------------------
EventLoop:
        movem.l d2-d7/a2-a6,-(sp)
.wait:  move.l  Win,a0
        move.l  86(a0),a0
        move.l  SysBase,a6
        CALL    WaitPort
.msg:   move.l  Win,a0
        move.l  86(a0),a0
        move.l  GadBase,a6
        CALL    GT_GetIMsg
        tst.l   d0
        beq     .wait
        move.l  d0,a1
        move.l  20(a1),d2
        move.w  24(a1),d3
        move.l  28(a1),a3
        CALL    GT_ReplyIMsg
        cmp.l   #IDCMP_REFRESHWINDOW,d2
        bne     .m1
        move.l  Win,a0
        CALL    GT_BeginRefresh
        move.l  Win,a0
        moveq   #1,d0
        CALL    GT_EndRefresh
        bra     .msg
.m1:    cmp.l   #IDCMP_CLOSEWINDOW,d2
        beq     .quit
        cmp.l   #IDCMP_MENUPICK,d2
        beq     .menu
        cmp.l   #IDCMP_GADGETUP,d2
        bne     .msg
        move.w  38(a3),d0
        cmp.w   #G_FORMAT,d0
        bne     .g1
        move.b  d3,Prefs+P_Format
        bra     .msg
.g1:    cmp.w   #G_ACTION,d0
        bne     .g2
        move.b  d3,Prefs+P_Action
        bra     .msg
.g2:    cmp.w   #G_DIM,d0
        bne     .g3
        move.b  d3,Prefs+P_Dim
        bra     .msg
.g3:    cmp.w   #G_COLOR,d0
        bne     .g4
        move.b  d3,Prefs+P_Color
        bra     .msg
.g4:    cmp.w   #G_SAVESEL,d0
        bne     .g5
        bsr     PickDrawer
        bra     .msg
.g5:    cmp.w   #G_VIEWSEL,d0
        bne     .g6
        bsr     PickViewer
        bra     .msg
.g6:    cmp.w   #G_SAVE,d0
        bne     .g7
        bsr     Collect
        lea     ArcPrefsName,a0
        bsr     WritePrefs
        lea     EnvPrefsName,a0
        bsr     WritePrefs
        bra     .quit
.g7:    cmp.w   #G_USE,d0
        bne     .g8
        bsr     Collect
        lea     EnvPrefsName,a0
        bsr     WritePrefs
        bra     .quit
.g8:    cmp.w   #G_CANCEL,d0
        beq     .quit
        bra     .msg
.menu:  cmp.w   #MENUNULL,d3
        beq     .msg
        move.l  IntBase,a6
        move.l  Menu,a0
        moveq   #0,d0
        move.w  d3,d0
        CALL    ItemAddress
        tst.l   d0
        beq     .msg
        move.l  d0,a0
        move.l  34(a0),d0               ; GTMENUITEM_USERDATA
        cmp.l   #1,d0
        bne     .n1
        bsr     About
        bra     .msg
.n1:    cmp.l   #2,d0
        beq     .quit
        cmp.l   #3,d0
        bne     .n3
        bsr     DefaultPrefs
        bsr     Refresh
        bra     .msg
.n3:    cmp.l   #4,d0
        bne     .msg
        bsr     DefaultPrefs
        lea     ArcPrefsName,a0
        bsr     ReadPrefsFile
        bsr     Refresh
        bra     .msg
.quit:  movem.l (sp)+,d2-d7/a2-a6
        rts

; gadgets -> Prefs
Collect:
        movem.l d2/a2,-(sp)
        lea     Gads,a2
        moveq   #0,d0
        move.l  G_ENABLED*4(a2),a0
        move.w  12(a0),d1
        and.w   #GFLG_SELECTED,d1
        sne     d0
        and.b   #1,d0
        move.b  d0,Prefs+P_Enabled
        move.l  G_BEEP*4(a2),a0
        move.w  12(a0),d1
        and.w   #GFLG_SELECTED,d1
        sne     d0
        and.b   #1,d0
        move.b  d0,Prefs+P_Beep
        move.l  G_HOTKEY*4(a2),a0
        lea     Prefs+P_Hotkey,a1
        move.w  #HOTKEYLEN-2,d2
        bsr     .str
        move.l  G_SAVEDIR*4(a2),a0
        lea     Prefs+P_SaveDir,a1
        move.w  #PATHLEN-2,d2
        bsr     .str
        move.l  G_VIEWER*4(a2),a0
        lea     Prefs+P_Viewer,a1
        move.w  #PATHLEN-2,d2
        bsr     .str
        move.l  G_JPEGQ*4(a2),a0
        move.l  Win,a1
        move.l  a2,-(sp)
        sub.l   a2,a2
        lea     SlGetTags,a3
        move.l  GadBase,a6
        CALL    GT_GetGadgetAttrsA
        move.l  (sp)+,a2
        move.b  SL_Get+3,Prefs+P_JpegQ
        move.l  #PREFS_MAGIC,Prefs+P_Magic
        move.l  #PREFS_VERSION,Prefs+P_Version
        movem.l (sp)+,d2/a2
        rts
.str:   move.l  34(a0),a0               ; gg_SpecialInfo
        move.l  (a0),a0                 ; si_Buffer
.c:     move.b  (a0)+,(a1)+
        dbeq    d2,.c
        clr.b   (a1)
        rts

; a0 = file name; write Prefs
WritePrefs:
        movem.l d2-d5/a6,-(sp)
        move.l  DosBase,a6
        move.l  a0,d1
        move.l  #MODE_NEWFILE,d2
        CALL    Open
        move.l  d0,d5
        beq     .x
        move.l  d5,d1
        move.l  #Prefs,d2
        move.l  #PREFSIZE,d3
        CALL    Write
        move.l  d5,d1
        CALL    Close
.x:     movem.l (sp)+,d2-d5/a6
        rts

; Prefs -> gadgets
Refresh:
        movem.l d2-d7/a2-a6,-(sp)
        lea     Gads,a4
        moveq   #0,d0
        move.b  Prefs+P_Enabled,d0
        move.l  d0,CB_Val
        move.l  G_ENABLED*4(a4),a0
        lea     CBTags,a3
        bsr     .set
        moveq   #0,d0
        move.b  Prefs+P_Beep,d0
        move.l  d0,CB_Val
        move.l  G_BEEP*4(a4),a0
        lea     CBTags,a3
        bsr     .set
        move.l  #Prefs+P_Hotkey,ST_Str
        move.l  G_HOTKEY*4(a4),a0
        lea     StrTags,a3
        bsr     .set
        move.l  #Prefs+P_SaveDir,ST_Str
        move.l  G_SAVEDIR*4(a4),a0
        lea     StrTags,a3
        bsr     .set
        move.l  #Prefs+P_Viewer,ST_Str
        move.l  G_VIEWER*4(a4),a0
        lea     StrTags,a3
        bsr     .set
        moveq   #0,d0
        move.b  Prefs+P_JpegQ,d0
        move.l  d0,SL_Set
        move.l  G_JPEGQ*4(a4),a0
        lea     SlSetTags,a3
        bsr     .set
        lea     CyclePrefs,a2
.cy:    move.w  (a2)+,d1                ; gadget id
        beq     .done
        move.w  (a2)+,d2                ; prefs offset
        lea     Prefs,a0
        moveq   #0,d0
        move.b  (a0,d2.w),d0
        move.l  d0,CY_Act
        lsl.w   #2,d1
        move.l  (a4,d1.w),a0
        lea     CyActTags,a3
        bsr     .set
        bra     .cy
.done:  movem.l (sp)+,d2-d7/a2-a6
        rts
.set:   move.l  a2,-(sp)
        move.l  GadBase,a6
        move.l  Win,a1
        sub.l   a2,a2
        CALL    GT_SetGadgetAttrsA
        move.l  (sp)+,a2
        rts

;---------------------------------------------------------------------
; ASL requesters
GetReq: move.l  FileReq,d0
        bne     .x
        move.l  AslBase,d0
        beq     .x
        move.l  d0,a6
        moveq   #0,d0
        sub.l   a0,a0
        CALL    AllocAslRequest
        move.l  d0,FileReq
.x:     rts

; a0 = gadget, a1 = new string
SetString:
        movem.l a2-a3/a6,-(sp)
        move.l  a1,ST_Str
        move.l  GadBase,a6
        move.l  Win,a1
        sub.l   a2,a2
        lea     StrTags,a3
        CALL    GT_SetGadgetAttrsA
        movem.l (sp)+,a2-a3/a6
        rts

PickDrawer:
        movem.l d2-d7/a2-a6,-(sp)
        bsr     GetReq
        tst.l   d0
        beq     .x
        move.l  Gads+G_SAVEDIR*4,a0
        move.l  34(a0),a0
        move.l  (a0),DR_Init
        move.l  Win,DR_Win
        move.l  AslBase,a6
        move.l  FileReq,a0
        lea     DrawerTags,a1
        CALL    AslRequest
        tst.l   d0
        beq     .x
        move.l  FileReq,a0
        move.l  8(a0),a1
        move.l  Gads+G_SAVEDIR*4,a0
        bsr     SetString
.x:     movem.l (sp)+,d2-d7/a2-a6
        rts

PickViewer:
        movem.l d2-d7/a2-a6,-(sp)
        bsr     GetReq
        tst.l   d0
        beq     .x
        ; split the current path into drawer and file
        move.l  Gads+G_VIEWER*4,a0
        move.l  34(a0),a0
        move.l  (a0),a0
        lea     TmpPath,a1
        move.w  #PATHLEN-2,d0
.c:     move.b  (a0)+,(a1)+
        dbeq    d0,.c
        clr.b   (a1)
        move.l  DosBase,a6
        move.l  #TmpPath,d1
        CALL    FilePart
        move.l  d0,a0
        lea     TmpFile,a1
        moveq   #62,d0
.f:     move.b  (a0)+,(a1)+
        dbeq    d0,.f
        clr.b   (a1)
        move.l  #TmpPath,d1
        CALL    PathPart
        move.l  d0,a0
        clr.b   (a0)
        move.l  Win,VW_Win
        move.l  AslBase,a6
        move.l  FileReq,a0
        lea     ViewerTags,a1
        CALL    AslRequest
        tst.l   d0
        beq     .x
        move.l  FileReq,a2
        move.l  8(a2),a0
        lea     TmpPath,a1
        move.w  #PATHLEN-2,d0
.d:     move.b  (a0)+,(a1)+
        dbeq    d0,.d
        clr.b   (a1)
        move.l  DosBase,a6
        move.l  #TmpPath,d1
        move.l  4(a2),d2
        move.l  #PATHLEN,d3
        CALL    AddPart
        move.l  Gads+G_VIEWER*4,a0
        lea     TmpPath,a1
        bsr     SetString
.x:     movem.l (sp)+,d2-d7/a2-a6
        rts

;=====================================================================
; About window
;=====================================================================
About:
        movem.l d2-d7/a2-a6,-(sp)
        clr.l   AbWin
        clr.l   AbGList
        clr.l   AbBuf
        clr.l   NumPens
        move.l  IntBase,a6
        move.l  Win,a0
        lea     BusyTags,a1
        CALL    SetWindowPointerA
        move.l  Scr,a0
        CALL    GetScreenDrawInfo
        move.l  d0,Dri
        beq     .out
        ; size
        lea     AboutLines,a0
        bsr     MaxTextW
        cmp.l   #ABOUT_W,d0
        bge     .w1
        move.l  #ABOUT_W,d0
.w1:    add.l   #32,d0
        move.l  d0,AbIW
        move.l  FontH,d0
        addq.l  #2,d0
        lsl.l   #2,d0
        add.l   #ABOUT_H+10+10+8+8+8,d0
        add.l   RowH,d0
        move.l  d0,AbIH
        ; OK button
        move.l  GadBase,a6
        lea     AbGList,a0
        CALL    CreateContext
        move.l  d0,d7
        beq     .out
        lea     NG,a1
        move.l  AbIW,d0
        sub.l   BW,d0
        lsr.l   #1,d0
        add.l   BordL,d0
        move.w  d0,(a1)
        move.l  AbIH,d0
        sub.l   RowH,d0
        subq.l  #8,d0
        add.l   BordT,d0
        move.w  d0,2(a1)
        move.w  BW+2,4(a1)
        move.w  RowH+2,6(a1)
        move.l  #LOK,8(a1)
        move.l  TA,12(a1)
        move.w  #1,16(a1)
        move.l  #PLACETEXT_IN,18(a1)
        move.l  VI,22(a1)
        clr.l   26(a1)
        moveq   #BUTTON_KIND,d0
        move.l  d7,a0
        lea     NoTags,a2
        CALL    CreateGadgetA
        tst.l   d0
        beq     .out
        ; window over the prefs window
        move.l  Win,a0
        moveq   #0,d0
        move.w  4(a0),d0
        add.l   #20,d0
        move.l  d0,AW_L
        moveq   #0,d0
        move.w  6(a0),d0
        add.l   #16,d0
        move.l  d0,AW_T
        move.l  AbIW,AW_IW
        move.l  AbIH,AW_IH
        move.l  Scr,AW_Scr
        move.l  AbGList,AW_Gad
        move.l  IntBase,a6
        sub.l   a0,a0
        lea     AboutWinTags,a1
        CALL    OpenWindowTagList
        move.l  d0,AbWin
        beq     .out
        move.l  GadBase,a6
        move.l  d0,a0
        sub.l   a1,a1
        CALL    GT_RefreshWindow
        bsr     DrawAbout
.wait:  move.l  AbWin,a0
        move.l  86(a0),a0
        move.l  SysBase,a6
        CALL    WaitPort
.msg:   move.l  AbWin,a0
        move.l  86(a0),a0
        move.l  GadBase,a6
        CALL    GT_GetIMsg
        tst.l   d0
        beq     .wait
        move.l  d0,a1
        move.l  20(a1),d2
        move.w  24(a1),d3
        CALL    GT_ReplyIMsg
        cmp.l   #IDCMP_REFRESHWINDOW,d2
        bne     .a1
        move.l  AbWin,a0
        CALL    GT_BeginRefresh
        move.l  AbWin,a0
        moveq   #1,d0
        CALL    GT_EndRefresh
        bra     .msg
.a1:    cmp.l   #IDCMP_VANILLAKEY,d2
        bne     .out
        cmp.b   #13,d3
        beq     .out
        cmp.b   #27,d3
        bne     .msg
.out:   move.l  AbWin,d0
        beq     .o1
        move.l  IntBase,a6
        move.l  d0,a0
        CALL    CloseWindow
.o1:    move.l  GadBase,a6
        move.l  AbGList,a0
        CALL    FreeGadgets
        bsr     ReleaseAboutPens
        move.l  SysBase,a6
        move.l  AbBuf,d0
        beq     .o2
        move.l  d0,a1
        CALL    FreeVec
.o2:    move.l  IntBase,a6
        move.l  Dri,d0
        beq     .o3
        move.l  Scr,a0
        move.l  d0,a1
        CALL    FreeScreenDrawInfo
        clr.l   Dri
.o3:    move.l  Win,a0
        lea     NoTags,a1
        CALL    SetWindowPointerA
        movem.l (sp)+,d2-d7/a2-a6
        rts

DrawAbout:
        movem.l d2-d7/a2-a6,-(sp)
        move.l  AbWin,a0
        move.l  50(a0),AbRP
        moveq   #0,d0
        move.b  54(a0),d0               ; wd_BorderLeft
        move.l  d0,AbBL
        moveq   #0,d0
        move.b  55(a0),d0               ; wd_BorderTop
        move.l  d0,AbBT
        move.l  Dri,a0
        move.l  4(a0),a0                ; dri_Pens
        moveq   #0,d0
        move.w  BACKGROUNDPEN*2(a0),d0
        move.l  d0,BgPen
        move.w  TEXTPEN*2(a0),d0
        move.l  d0,TxPen
        move.w  HIGHLIGHTTEXTPEN*2(a0),d0
        move.l  d0,HiPen
        ; image position
        move.l  AbIW,d0
        sub.l   #ABOUT_W,d0
        lsr.l   #1,d0
        add.l   AbBL,d0
        move.l  d0,ImgX
        move.l  AbBT,d0
        add.l   #10,d0
        move.l  d0,ImgY
        ; screen depth / RTG?
        move.l  CgxBase,d0
        beq     .pal
        move.l  d0,a6
        move.l  Scr,a2
        move.l  GfxBase,a6
        lea     44(a2),a0
        CALL    GetVPModeID
        move.l  CgxBase,a6
        CALL    IsCyberModeID
        tst.w   d0
        beq     .pal
        move.l  Scr,a2
        move.l  84+4(a2),a0             ; sc_RastPort.BitMap
        move.l  #CYBRMATTR_DEPTH,d0
        CALL    GetCyberMapAttr
        cmp.l   #8,d0
        bls     .pal
        bsr     DrawAboutRGB
        bra     .text
.pal:   bsr     DrawAboutPal
.text:  ; text lines centred under the image
        move.l  GfxBase,a6
        move.l  AbRP,a1
        moveq   #1,d0                   ; JAM2? use JAM1
        moveq   #0,d0
        CALL    SetDrMd
        move.l  ImgY,d6
        add.l   #ABOUT_H+10,d6
        lea     AboutLines,a3
        moveq   #0,d5                   ; line number
.ln:    move.l  (a3)+,d0
        beq     .done
        move.l  d0,a2
        move.l  a2,a0
        bsr     TextW
        move.l  AbIW,d4
        sub.l   d0,d4
        lsr.l   #1,d4
        add.l   AbBL,d4
        move.l  TxPen,d0
        cmp.w   #2,d5                   ; "by Amigatronics" highlighted
        bne     .pn
        move.l  HiPen,d0
.pn:    move.l  AbRP,a1
        CALL    SetAPen
        move.l  AbRP,a1
        move.l  d4,d0
        move.l  d6,d1
        add.w   62(a1),d1               ; baseline
        CALL    Move
        move.l  a2,a0
        moveq   #-1,d0
.sl:    addq.l  #1,d0
        tst.b   (a0)+
        bne     .sl
        move.l  a2,a0
        move.l  AbRP,a1
        CALL    Text
        add.l   FontH,d6
        addq.l  #2,d6
        addq.w  #1,d5
        bra     .ln
.done:  movem.l (sp)+,d2-d7/a2-a6
        rts

; true colour: blend the RGBA picture with the window background
DrawAboutRGB:
        movem.l d2-d7/a2-a6,-(sp)
        move.l  GfxBase,a6
        move.l  Scr,a0
        move.l  48(a0),a0               ; ViewPort.ColorMap
        move.l  BgPen,d0
        moveq   #1,d1
        lea     BgRGB,a1
        CALL    GetRGB32
        move.l  SysBase,a6
        move.l  #ABOUT_W*ABOUT_H*3,d0
        moveq   #0,d1
        CALL    AllocVec
        move.l  d0,AbBuf
        beq     .x
        move.l  d0,a1
        lea     AboutRGBA,a0
        move.l  #ABOUT_W*ABOUT_H,d7
.px:    moveq   #0,d6
        move.b  3(a0),d6                ; alpha
        move.l  #255,d5
        sub.l   d6,d5                   ; 255-alpha
        lea     BgRGB,a2
        moveq   #3-1,d4
.ch:    moveq   #0,d0
        move.b  (a0)+,d0
        mulu.w  d6,d0
        moveq   #0,d1
        move.b  (a2),d1
        addq.l  #4,a2
        mulu.w  d5,d1
        add.l   d1,d0
        add.l   #127,d0
        divu.w  #255,d0
        move.b  d0,(a1)+
        dbra    d4,.ch
        addq.l  #1,a0                   ; skip alpha
        subq.l  #1,d7
        bne     .px
        move.l  CgxBase,a6
        move.l  AbBuf,a0
        moveq   #0,d0
        moveq   #0,d1
        move.l  #ABOUT_W*3,d2
        move.l  AbRP,a1
        move.l  ImgX,d3
        move.l  ImgY,d4
        move.l  #ABOUT_W,d5
        move.l  #ABOUT_H,d6
        moveq   #RECTFMT_RGB,d7
        CALL    WritePixelArray
.x:     movem.l (sp)+,d2-d7/a2-a6
        rts

; palette screen: best pens for the 31 colours, then chunky write
DrawAboutPal:
        movem.l d2-d7/a2-a6,-(sp)
        move.l  GfxBase,a6
        cmp.w   #40,20(a6)              ; WriteChunkyPixels needs V40
        blo     .x
        move.l  Scr,a0
        move.l  48(a0),CMap
        lea     AboutPal,a2
        lea     PenMap,a3
        moveq   #0,d7
.op:    cmp.w   #ABOUT_TRANSP,d7
        beq     .bg
        moveq   #0,d1
        move.b  (a2)+,d1
        bsr     .rep
        move.l  d0,d4
        moveq   #0,d1
        move.b  (a2)+,d1
        bsr     .rep
        move.l  d0,d5
        moveq   #0,d1
        move.b  (a2)+,d1
        bsr     .rep
        move.l  d0,d3
        move.l  d4,d1
        move.l  d5,d2
        move.l  CMap,a0
        lea     PenTags,a1
        CALL    ObtainBestPenA
        move.b  d0,(a3)+
        lea     ObtPens,a0
        move.w  d7,d1
        lsl.w   #2,d1
        move.l  d0,(a0,d1.w)
        addq.l  #1,NumPens
        bra     .nx
.bg:    addq.l  #3,a2
        move.b  BgPen+3,(a3)+
.nx:    addq.w  #1,d7
        cmp.w   #ABOUT_NCOL,d7
        blt     .op
        move.l  SysBase,a6
        move.l  #ABOUT_W*ABOUT_H,d0
        moveq   #0,d1
        CALL    AllocVec
        move.l  d0,AbBuf
        beq     .x
        move.l  d0,a1
        lea     AboutIdx,a0
        lea     PenMap,a2
        move.l  #ABOUT_W*ABOUT_H,d1
        moveq   #0,d0
.mp:    move.b  (a0)+,d0
        move.b  (a2,d0.w),(a1)+
        subq.l  #1,d1
        bne     .mp
        move.l  GfxBase,a6
        move.l  AbRP,a0
        move.l  ImgX,d0
        move.l  ImgY,d1
        move.l  d0,d2
        add.l   #ABOUT_W-1,d2
        move.l  d1,d3
        add.l   #ABOUT_H-1,d3
        move.l  AbBuf,a2
        move.l  #ABOUT_W,d4
        CALL    WriteChunkyPixels
.x:     movem.l (sp)+,d2-d7/a2-a6
        rts
.rep:   mulu.w  #$0101,d1               ; byte -> 32-bit left justified
        move.l  d1,d0
        swap    d0
        move.w  d1,d0
        rts

ReleaseAboutPens:
        move.l  NumPens,d0
        beq     .x
        move.l  GfxBase,a6
        lea     ObtPens,a2
        moveq   #0,d2
.l:     cmp.w   #ABOUT_TRANSP,d2
        beq     .n
        move.w  d2,d1
        lsl.w   #2,d1
        move.l  (a2,d1.w),d0
        bmi     .n
        move.l  CMap,a0
        CALL    ReleasePen
.n:     addq.w  #1,d2
        cmp.w   #ABOUT_NCOL,d2
        blt     .l
        clr.l   NumPens
.x:     rts

        include "prefs_code.i"

;=====================================================================
        section data,data
;=====================================================================
        cnop    0,4
LibBases:
DosBase:        dc.l 0
IntBase:        dc.l 0
GfxBase:        dc.l 0
GadBase:        dc.l 0
AslBase:        dc.l 0
CgxBase:        dc.l 0
NUMLIBS         equ 6

LibTable:
        dc.l    DosName,39,DosBase,1
        dc.l    IntName,39,IntBase,1
        dc.l    GfxName,39,GfxBase,1
        dc.l    GadName,39,GadBase,1
        dc.l    AslName,38,AslBase,0
        dc.l    CgxName,40,CgxBase,0
        dc.l    0

CBTags: dc.l    GTCB_Checked
CB_Val: dc.l    0
        dc.l    GTCB_Scaled,1
        dc.l    TAG_DONE
StrTags:
        dc.l    GTST_String
ST_Str: dc.l    0
        dc.l    GTST_MaxChars
ST_Max: dc.l    255
        dc.l    TAG_DONE
CyTags: dc.l    GTCY_Labels
CY_Lab: dc.l    0
CyActTags:
        dc.l    GTCY_Active
CY_Act: dc.l    0
        dc.l    TAG_DONE
NoTags: dc.l    TAG_DONE
SlTags: dc.l    GTSL_Min,10
        dc.l    GTSL_Max,100
        dc.l    GTSL_Level
SL_Lev: dc.l    85
        dc.l    GTSL_MaxLevelLen,3
        dc.l    GTSL_LevelFormat,SlFmt
        dc.l    GTSL_LevelPlace,PLACETEXT_RIGHT
        dc.l    GA_RelVerify,1
        dc.l    TAG_DONE
SlSetTags:
        dc.l    GTSL_Level
SL_Set: dc.l    85
        dc.l    TAG_DONE
SlGetTags:
        dc.l    GTSL_Level,SL_Get
        dc.l    TAG_DONE
BusyTags:
        dc.l    WA_BusyPointer,1
        dc.l    TAG_DONE
PenTags:
        dc.l    OBP_Precision,PRECISION_IMAGE
        dc.l    TAG_DONE
MenuLayTags:
        dc.l    GTMN_NewLookMenus,1
        dc.l    TAG_DONE

; cycle gadget id, prefs offset
CyclePrefs:
        dc.w    G_FORMAT,P_Format
        dc.w    G_ACTION,P_Action
        dc.w    G_DIM,P_Dim
        dc.w    G_COLOR,P_Color
        dc.w    0

MainWinTags:
        dc.l    WA_Left
MW_L:   dc.l    0
        dc.l    WA_Top
MW_T:   dc.l    0
        dc.l    WA_InnerWidth
MW_IW:  dc.l    0
        dc.l    WA_InnerHeight
MW_IH:  dc.l    0
        dc.l    WA_PubScreen
MW_Scr: dc.l    0
        dc.l    WA_Gadgets
MW_Gad: dc.l    0
        dc.l    WA_Title,WinTitle
        dc.l    WA_Flags,WFLG_DRAGBAR|WFLG_DEPTHGADGET|WFLG_CLOSEGADGET|WFLG_ACTIVATE
        dc.l    WA_IDCMP,IDCMP_GADGETUP|IDCMP_GADGETDOWN|IDCMP_MOUSEMOVE|IDCMP_CLOSEWINDOW|IDCMP_MENUPICK|IDCMP_REFRESHWINDOW
        dc.l    WA_NewLookMenus,1
        dc.l    WA_AutoAdjust,1
        dc.l    TAG_DONE

AboutWinTags:
        dc.l    WA_Left
AW_L:   dc.l    0
        dc.l    WA_Top
AW_T:   dc.l    0
        dc.l    WA_InnerWidth
AW_IW:  dc.l    0
        dc.l    WA_InnerHeight
AW_IH:  dc.l    0
        dc.l    WA_PubScreen
AW_Scr: dc.l    0
        dc.l    WA_Gadgets
AW_Gad: dc.l    0
        dc.l    WA_Title,AboutTitle
        dc.l    WA_Flags,WFLG_DRAGBAR|WFLG_DEPTHGADGET|WFLG_CLOSEGADGET|WFLG_ACTIVATE|WFLG_RMBTRAP
        dc.l    WA_IDCMP,IDCMP_GADGETUP|IDCMP_CLOSEWINDOW|IDCMP_REFRESHWINDOW|IDCMP_VANILLAKEY
        dc.l    WA_AutoAdjust,1
        dc.l    TAG_DONE

DrawerTags:
        dc.l    ASLFR_Window
DR_Win: dc.l    0
        dc.l    ASLFR_SleepWindow,1
        dc.l    ASLFR_TitleText,TDrawer
        dc.l    ASLFR_DrawersOnly,1
        dc.l    ASLFR_InitialDrawer
DR_Init:
        dc.l    0
        dc.l    TAG_DONE

ViewerTags:
        dc.l    ASLFR_Window
VW_Win: dc.l    0
        dc.l    ASLFR_SleepWindow,1
        dc.l    ASLFR_TitleText,TViewer
        dc.l    ASLFR_RejectIcons,1
        dc.l    ASLFR_InitialDrawer,TmpPath
        dc.l    ASLFR_InitialFile,TmpFile
        dc.l    TAG_DONE

NewMenus:
        dc.b    NM_TITLE,0
        dc.l    MProject,0
        dc.w    0
        dc.l    0,0
        dc.b    NM_ITEM,0
        dc.l    MAbout,KeyA
        dc.w    0
        dc.l    0,1
        dc.b    NM_ITEM,0
        dc.l    -1,0                    ; NM_BARLABEL
        dc.w    0
        dc.l    0,0
        dc.b    NM_ITEM,0
        dc.l    MQuit,KeyQ
        dc.w    0
        dc.l    0,2
        dc.b    NM_TITLE,0
        dc.l    MEdit,0
        dc.w    0
        dc.l    0,0
        dc.b    NM_ITEM,0
        dc.l    MDefaults,KeyD
        dc.w    0
        dc.l    0,3
        dc.b    NM_ITEM,0
        dc.l    MLastSaved,KeyL
        dc.w    0
        dc.l    0,4
        dc.b    NM_END,0
        dc.l    0,0
        dc.w    0
        dc.l    0,0

LeftLabels:
        dc.l    LHotkey,LSaveDir,LFormat,LJpegQ,LAction,LViewer,LDim,LColor,0
ButtonLabels:
        dc.l    LSave,LUse,LCancel,0
FormatLabels:
        dc.l    CF0,CF1,CF2,CF3,CF4,0
ActionLabels:
        dc.l    CA0,CA1,CA2,CA3,0
DimLabels:
        dc.l    CD0,CD1,CD2,CD3,0
ColorLabels:
        dc.l    CC0,CC1,CC2,CC3,CC4,0
AboutLines:
        dc.l    AL1,AL2,AL3,AL4,0

DosName:        dc.b "dos.library",0
IntName:        dc.b "intuition.library",0
GfxName:        dc.b "graphics.library",0
GadName:        dc.b "gadtools.library",0
AslName:        dc.b "asl.library",0
CgxName:        dc.b "cybergraphics.library",0
WinTitle:       dc.b "AmiSnip Preferences",0
AboutTitle:     dc.b "About AmiSnip",0
TDrawer:        dc.b "Select the save drawer",0
TViewer:        dc.b "Select a program",0
LEnabled:       dc.b "AmiSnip enabled",0
LHotkey:        dc.b "Hotkey",0
LSaveDir:       dc.b "Save drawer",0
LFormat:        dc.b "File format",0
LAction:        dc.b "After capture",0
LViewer:        dc.b "Open with",0
LDim:           dc.b "Dimming",0
LColor:         dc.b "Frame colour",0
LBeep:          dc.b "Beep after capture",0
LSelect:        dc.b "Select...",0
LSave:          dc.b "Save",0
LUse:           dc.b "Use",0
LCancel:        dc.b "Cancel",0
LOK:            dc.b "OK",0
FieldSample:    dc.b "Copy to clipboard + save",0
CF0:            dc.b "IFF ILBM",0
CF1:            dc.b "PNG",0
CF2:            dc.b "JPEG",0
CF3:            dc.b "BMP",0
CF4:            dc.b "GIF",0
LJpegQ:         dc.b "JPEG quality",0
LevelSample:    dc.b "100",0
SlFmt:          dc.b "%3ld",0
CA0:            dc.b "Show menu",0
CA1:            dc.b "Copy to clipboard",0
CA2:            dc.b "Save to drawer",0
CA3:            dc.b "Copy to clipboard + save",0
CD0:            dc.b "None",0
CD1:            dc.b "Light",0
CD2:            dc.b "Medium",0
CD3:            dc.b "Strong",0
CC0:            dc.b "White",0
CC1:            dc.b "Yellow",0
CC2:            dc.b "Cyan",0
CC3:            dc.b "Red",0
CC4:            dc.b "Green",0
MProject:       dc.b "Project",0
MAbout:         dc.b "About...",0
MQuit:          dc.b "Quit",0
MEdit:          dc.b "Edit",0
MDefaults:      dc.b "Reset to defaults",0
MLastSaved:     dc.b "Last saved",0
KeyA:           dc.b "?",0
KeyQ:           dc.b "Q",0
KeyD:           dc.b "D",0
KeyL:           dc.b "L",0
AL1:            dc.b "AmiSnip 1.3",0
AL2:            dc.b "Screen area capture commodity",0
AL3:            dc.b "by Amigatronics",0
AL4:            dc.b "https://amigatronics.com",0
        even

        include "prefs_data.i"

        cnop    0,4
AboutRGBA:      incbin "about_rgba.bin"
        cnop    0,4
AboutIdx:       incbin "about_idx.bin"
AboutPal:       incbin "about_pal.bin"
        even

;=====================================================================
        section bss,bss
;=====================================================================
        cnop    0,4
SysBase:        ds.l 1
WBMsg:          ds.l 1
RetCode:        ds.l 1
FileReq:        ds.l 1
Scr:            ds.l 1
VI:             ds.l 1
TA:             ds.l 1
Win:            ds.l 1
GList:          ds.l 1
Menu:           ds.l 1
PrevGad:        ds.l 1
FontH:          ds.l 1
RowH:           ds.l 1
Step:           ds.l 1
BordL:          ds.l 1
BordT:          ds.l 1
LW:             ds.l 1
SBW:            ds.l 1
FW:             ds.l 1
BW:             ds.l 1
X0:             ds.l 1
InnerW:         ds.l 1
InnerH:         ds.l 1
CBW:            ds.l 1
CBH:            ds.l 1
Gads:           ds.l 16
SL_Get:         ds.l 1
; about
AbWin:          ds.l 1
AbGList:        ds.l 1
AbBuf:          ds.l 1
AbRP:           ds.l 1
AbIW:           ds.l 1
AbIH:           ds.l 1
AbBL:           ds.l 1
AbBT:           ds.l 1
Dri:            ds.l 1
BgPen:          ds.l 1
TxPen:          ds.l 1
HiPen:          ds.l 1
ImgX:           ds.l 1
ImgY:           ds.l 1
CMap:           ds.l 1
NumPens:        ds.l 1
BgRGB:          ds.l 3
ObtPens:        ds.l ABOUT_NCOL
PenMap:         ds.b ABOUT_NCOL
NG:             ds.b 30
        cnop    0,4
Prefs:          ds.b PREFSIZE
PrefsTmp:       ds.b PREFSIZE
TmpPath:        ds.b PATHLEN+4
TmpFile:        ds.b 68
