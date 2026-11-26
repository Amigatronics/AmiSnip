;=====================================================================
; AmiSnip 1.1 - Screen area capture commodity for AmigaOS 3.x
; by Amigatronics - https://amigatronics.com
;
; Hotkey (default LAmiga+Shift+S): the front screen freezes and dims,
; drag a frame, adjust it, press Return or double-click inside.
; A floating menu then offers: copy to clipboard, save as..., open in
; a program, or go back. Settings live in ENV:AmiSnip.prefs and are
; edited with AmiSnipPrefs (reloaded automatically when they change).
;
; Native chipset (OCS/ECS/AGA) and RTG (Picasso96/CyberGraphX).
; Requires AmigaOS 3.0+ (V39).
;
; Assemble: vasmm68k_mot -Fhunkexe -kick1hunks -nosym -m68000
;=====================================================================

        machine 68000
        include "lvo.i"

KEY_ESC                 equ $45
KEY_RETURN              equ $44
KEY_ENTER               equ $43
KEY_F                   equ $23
SELECTDOWN              equ $68
SELECTUP                equ $E8
MENUDOWN                equ $69
WINFLAGS                equ $11B00      ; SMART_REFRESH|BACKDROP|REPORTMOUSE|BORDERLESS|ACTIVATE|RMBTRAP

CXM_IEVENT              equ 32
CXM_COMMAND             equ 64
CXCMD_DISABLE           equ 15
CXCMD_ENABLE            equ 17
CXCMD_APPEAR            equ 19
CXCMD_KILL              equ 23
CXCMD_UNIQUE            equ 25
CX_FILTER               equ 1
CX_SEND                 equ 3
CX_TRANSLATE            equ 5
EVT_HOTKEY              equ 1

BMA_DEPTH               equ 4
BMF_CLEAR               equ 1
BMF_DISPLAYABLE         equ 2
CMD_WRITE               equ 3
CMD_UPDATE              equ 4
BLACK                   equ $000000

ST_IDLE                 equ 0
ST_DRAW                 equ 1
ST_ADJUST               equ 2
ST_RESIZE               equ 3
ST_MOVE                 equ 4

; output actions
ACT_CLIP                equ 1           ; clipboard
ACT_SAVE                equ 2           ; save to the default drawer
ACT_BOTH                equ 3           ; clipboard + save
ACT_SAVEAS              equ 4           ; save to PathBuf (requester)
ACT_OPEN                equ 5           ; save to T: and open in the viewer

;=====================================================================
        section code,code
;=====================================================================

Start:
        move.l  4.w,a6
        move.l  a6,SysBase
        sub.l   a1,a1
        CALL    FindTask
        move.l  d0,MyTask
        move.l  d0,a4
        tst.l   172(a4)                 ; pr_CLI
        bne     .cli
        lea     92(a4),a0               ; pr_MsgPort
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

        dc.b    "$VER: AmiSnip 1.3 (22.11.2026) by Amigatronics",0
        even

;---------------------------------------------------------------------
Main:
        movem.l d2-d7/a2-a6,-(sp)
        moveq   #20,d0
        move.l  d0,RetCode
        move.l  SysBase,a6
        lea     LibTable,a2
.ol:    move.l  (a2)+,d0                ; name
        beq     .libsok
        move.l  d0,a1
        move.l  (a2)+,d0                ; version
        move.l  (a2)+,a3                ; base variable
        move.l  (a2)+,d2                ; required?
        CALL    OpenLibrary
        move.l  d0,(a3)
        bne     .ol
        tst.l   d2
        bne     .cleanup
        bra     .ol
.libsok:
        bsr     InitTables
        bsr     ParseArgs
        tst.l   d0
        beq     .cleanup
        tst.l   QuitFlag
        beq     .run
        bsr     SignalQuit
        clr.l   RetCode
        bra     .cleanup
.run:   bsr     LoadPrefs
        bsr     InitCx
        tst.l   d0
        beq     .cleanup
        bsr     InitPubPort
        bsr     InitNotify
        clr.l   RetCode
        bsr     MainLoop
.cleanup:
        bsr     FreeNotify
        bsr     FreePubPort
        bsr     FreeCx
        move.l  FileReq,d0
        beq     .nofr
        move.l  AslBase,a6
        move.l  d0,a0
        CALL    FreeAslRequest
.nofr:  move.l  RDArgs,d1
        beq     .nora
        move.l  DosBase,a6
        CALL    FreeArgs
.nora:  move.l  DiskObj,d0
        beq     .nodo
        move.l  IconBase,a6
        move.l  d0,a0
        CALL    FreeDiskObject
.nodo:  move.l  SysBase,a6
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
InitTables:
        lea     CrcTable,a0
        moveq   #0,d0
.l1:    move.l  d0,d1
        moveq   #7,d2
.l2:    lsr.l   #1,d1
        bcc     .nc
        eor.l   #$EDB88320,d1
.nc:    dbra    d2,.l2
        move.l  d1,(a0)+
        addq.w  #1,d0
        cmp.w   #256,d0
        bne     .l1
        rts

; dim table from the prefs (P_Dim)
BuildDimTable:
        moveq   #0,d0
        move.b  Prefs+P_Dim,d0
        add.w   d0,d0
        lea     DimMuls,a0
        move.w  (a0,d0.w),d2
        lea     DimTable,a0
        moveq   #0,d0
.l3:    move.l  d0,d1
        mulu.w  d2,d1
        lsr.l   #8,d1
        move.b  d1,(a0)+
        addq.w  #1,d0
        cmp.w   #256,d0
        bne     .l3
        rts

;---------------------------------------------------------------------
; CLI: QUIT/S,CX_PRIORITY/K/N   WB: CX_PRIORITY tooltype
ParseArgs:
        movem.l d2-d7/a2-a6,-(sp)
        clr.l   QuitFlag
        clr.l   CxPri
        tst.l   WBMsg
        bne     .wb
        move.l  DosBase,a6
        move.l  #Template,d1
        move.l  #ArgArray,d2
        moveq   #0,d3
        CALL    ReadArgs
        move.l  d0,RDArgs
        bne     .ok
        move.l  #UsageStr,d1
        CALL    PutStr
        moveq   #0,d0
        bra     .ret
.ok:    lea     ArgArray,a2
        move.l  (a2)+,QuitFlag
        move.l  (a2)+,d0
        beq     .done
        move.l  d0,a0
        move.l  (a0),CxPri
        bra     .done
.wb:    move.l  IconBase,d0
        beq     .done
        move.l  WBMsg,a0
        move.l  36(a0),a0               ; sm_ArgList
        move.l  (a0),d1
        move.l  4(a0),a3
        move.l  DosBase,a6
        CALL    CurrentDir
        move.l  d0,d7
        move.l  IconBase,a6
        move.l  a3,a0
        CALL    GetDiskObject
        move.l  d0,DiskObj
        move.l  d7,d1
        move.l  DosBase,a6
        CALL    CurrentDir
        move.l  DiskObj,d0
        beq     .done
        move.l  d0,a0
        move.l  54(a0),d0               ; do_ToolTypes
        beq     .done
        move.l  d0,a0
        lea     TTPri,a1
        move.l  IconBase,a6
        CALL    FindToolType
        tst.l   d0
        beq     .done
        move.l  d0,d1
        move.l  #CxPri,d2
        move.l  DosBase,a6
        CALL    StrToLong
.done:  moveq   #1,d0
.ret:   movem.l (sp)+,d2-d7/a2-a6
        rts

; "AmiSnip QUIT": tell the running copy to quit
SignalQuit:
        move.l  SysBase,a6
        CALL    Forbid
        lea     PubPortName,a1
        CALL    FindPort
        tst.l   d0
        beq     .np
        move.l  d0,a0
        move.l  16(a0),a1               ; mp_SigTask
        move.l  #$1000,d0               ; SIGBREAKF_CTRL_C
        CALL    Signal
.np:    CALL    Permit
        rts

InitPubPort:
        move.l  SysBase,a6
        CALL    CreateMsgPort
        move.l  d0,PubPort
        beq     .x
        move.l  d0,a1
        move.l  #PubPortName,10(a1)     ; ln_Name
        clr.b   9(a1)                   ; ln_Pri
        CALL    AddPort
.x:     rts

FreePubPort:
        move.l  PubPort,d0
        beq     .x
        move.l  SysBase,a6
        move.l  d0,a1
        CALL    RemPort
        move.l  PubPort,a0
        CALL    DeleteMsgPort
        clr.l   PubPort
.x:     rts

InitNotify:
        move.l  SysBase,a6
        moveq   #-1,d0
        CALL    AllocSignal
        move.b  d0,NotifySig
        bmi     .x
        moveq   #0,d1
        move.b  d0,d1
        moveq   #0,d0
        bset    d1,d0
        move.l  d0,NotifyMask
        lea     NotifyReq,a0
        move.l  #EnvPrefsName,(a0)      ; nr_Name
        move.l  #2,12(a0)               ; NRF_SEND_SIGNAL
        move.l  MyTask,16(a0)           ; nr_Task
        move.b  NotifySig,20(a0)        ; nr_SignalNum
        move.l  DosBase,a6
        move.l  a0,d1
        CALL    StartNotify
        move.l  d0,NotifyOn
.x:     rts

FreeNotify:
        tst.l   NotifyOn
        beq     .ns
        move.l  DosBase,a6
        move.l  #NotifyReq,d1
        CALL    EndNotify
        clr.l   NotifyOn
.ns:    move.b  NotifySig,d0
        bmi     .x
        tst.l   NotifyMask
        beq     .x
        move.l  SysBase,a6
        ext.w   d0
        ext.l   d0
        CALL    FreeSignal
        clr.l   NotifyMask
.x:     rts

;---------------------------------------------------------------------
InitCx:
        movem.l d2-d7/a2-a6,-(sp)
        move.l  SysBase,a6
        CALL    CreateMsgPort
        move.l  d0,CxPort
        beq     .fail
        move.l  d0,a0
        moveq   #0,d1
        move.b  15(a0),d1
        moveq   #0,d0
        bset    d1,d0
        move.l  d0,CxSigMask
        move.l  CxPort,NB_Port
        move.l  CxPri,d0
        move.b  d0,NB_Pri
        move.l  CxBase,a6
        lea     NewBroker,a0
        moveq   #0,d0
        CALL    CxBroker
        move.l  d0,Broker
        beq     .fail
        moveq   #CX_FILTER,d0
        lea     Prefs+P_Hotkey,a0
        sub.l   a1,a1
        CALL    CreateCxObj
        move.l  d0,Filter
        beq     .fail
        move.l  Broker,a0
        move.l  d0,a1
        CALL    AttachCxObj
        moveq   #CX_SEND,d0
        move.l  CxPort,a0
        move.w  #EVT_HOTKEY,a1
        CALL    CreateCxObj
        tst.l   d0
        beq     .fail
        move.l  Filter,a0
        move.l  d0,a1
        CALL    AttachCxObj
        moveq   #CX_TRANSLATE,d0
        sub.l   a0,a0
        sub.l   a1,a1
        CALL    CreateCxObj
        tst.l   d0
        beq     .fail
        move.l  Filter,a0
        move.l  d0,a1
        CALL    AttachCxObj
        bsr     CheckFilter
        bsr     ApplyEnabled
        lea     Prefs+P_Hotkey,a0
        lea     CurHotkey,a1
        bsr     StrCopy80
        moveq   #1,d0
        bra     .ret
.fail:  moveq   #0,d0
.ret:   movem.l (sp)+,d2-d7/a2-a6
        rts

; if the filter description was not valid, use the default hotkey
CheckFilter:
        move.l  CxBase,a6
        move.l  Filter,a0
        CALL    CxObjError
        tst.l   d0
        beq     .ok
        move.l  Filter,a0
        CALL    ClearCxObjError
        move.l  Filter,a0
        lea     DefHotkey,a1
        CALL    SetFilter
        move.l  Filter,a0
        CALL    ClearCxObjError
.ok:    rts

ApplyEnabled:
        move.l  CxBase,a6
        move.l  Broker,a0
        moveq   #0,d0
        tst.b   Prefs+P_Enabled
        beq     .a
        moveq   #1,d0
.a:     CALL    ActivateCxObj
        rts

; prefs file changed
ReloadPrefs:
        movem.l d2-d7/a2-a6,-(sp)
        bsr     LoadPrefs
        lea     Prefs+P_Hotkey,a0
        lea     CurHotkey,a1
.cmp:   move.b  (a0)+,d0
        cmp.b   (a1)+,d0
        bne     .diff
        tst.b   d0
        bne     .cmp
        bra     .same
.diff:  move.l  CxBase,a6
        move.l  Filter,a0
        lea     Prefs+P_Hotkey,a1
        CALL    SetFilter
        bsr     CheckFilter
        lea     Prefs+P_Hotkey,a0
        lea     CurHotkey,a1
        bsr     StrCopy80
.same:  bsr     ApplyEnabled
        movem.l (sp)+,d2-d7/a2-a6
        rts

StrCopy80:
        move.w  #HOTKEYLEN-2,d0
.c:     move.b  (a0)+,(a1)+
        dbeq    d0,.c
        clr.b   (a1)
        rts

FreeCx:
        move.l  Broker,d0
        beq     .np
        move.l  CxBase,a6
        move.l  d0,a0
        CALL    DeleteCxObjAll
        clr.l   Broker
.np:    move.l  CxPort,d0
        beq     .x
        move.l  SysBase,a6
.dr:    move.l  CxPort,a0
        CALL    GetMsg
        tst.l   d0
        beq     .del
        move.l  d0,a1
        CALL    ReplyMsg
        bra     .dr
.del:   move.l  CxPort,a0
        CALL    DeleteMsgPort
        clr.l   CxPort
.x:     rts

;---------------------------------------------------------------------
MainLoop:
        movem.l d2-d7/a2-a6,-(sp)
.wait:  moveq   #0,d7                   ; d7 = ignore queued hotkeys
        move.l  SysBase,a6
        move.l  CxSigMask,d0
        or.l    NotifyMask,d0
        or.l    #$1000,d0
        CALL    Wait
        move.l  d0,d4
        btst    #12,d4
        bne     .quit
        and.l   NotifyMask,d4
        beq     .get
        bsr     ReloadPrefs
.get:   move.l  SysBase,a6
        move.l  CxPort,a0
        CALL    GetMsg
        tst.l   d0
        beq     .wait
        move.l  d0,a2
        move.l  CxBase,a6
        move.l  a2,a0
        CALL    CxMsgID
        move.l  d0,d5
        move.l  a2,a0
        CALL    CxMsgType
        move.l  d0,d6
        move.l  SysBase,a6
        move.l  a2,a1
        CALL    ReplyMsg
        cmp.l   #CXM_IEVENT,d6
        bne     .cmd
        tst.l   d7
        bne     .get
        cmp.l   #EVT_HOTKEY,d5
        bne     .get
.snap:  bsr     DoCapture
        moveq   #1,d7
        bra     .get
.cmd:   cmp.l   #CXM_COMMAND,d6
        bne     .get
        cmp.l   #CXCMD_DISABLE,d5
        bne     .c1
        moveq   #0,d0
        bra     .act
.c1:    cmp.l   #CXCMD_ENABLE,d5
        bne     .c2
        moveq   #1,d0
.act:   move.l  CxBase,a6
        move.l  Broker,a0
        CALL    ActivateCxObj
        bra     .get
.c2:    cmp.l   #CXCMD_KILL,d5
        beq     .quit
        cmp.l   #CXCMD_APPEAR,d5        ; "Show" in Exchange -> prefs editor
        bne     .c3
        lea     PrefsCmd,a0
        bsr     RunAsync
        bra     .get
.c3:    cmp.l   #CXCMD_UNIQUE,d5        ; started again -> capture now
        bne     .get
        tst.l   d7
        bne     .get
        bra     .snap
.quit:  movem.l (sp)+,d2-d7/a2-a6
        rts

; a0 = command line, run it in the background with NIL: handles
RunAsync:
        movem.l d2-d7/a2-a6,-(sp)
        move.l  a0,d7
        move.l  DosBase,a6
        move.l  #NilName,d1
        move.l  #MODE_OLDFILE,d2
        CALL    Open
        move.l  d0,d5
        beq     .fail
        move.l  #NilName,d1
        move.l  #MODE_NEWFILE,d2
        CALL    Open
        move.l  d0,d6
        bne     .go
        move.l  d5,d1
        CALL    Close
        bra     .fail
.go:    move.l  d5,RunTags+4
        move.l  d6,RunTags+12
        move.l  d7,d1
        move.l  #RunTags,d2
        CALL    SystemTagList
        cmp.l   #-1,d0
        bne     .ok
        move.l  d5,d1
        CALL    Close
        move.l  d6,d1
        CALL    Close
.fail:  moveq   #0,d0
        bra     .ret
.ok:    moveq   #1,d0
.ret:   movem.l (sp)+,d2-d7/a2-a6
        rts

;=====================================================================
; One capture session
;=====================================================================
DoCapture:
        movem.l d2-d7/a2-a6,-(sp)
        lea     CapVars,a0
        move.w  #(CapVarsEnd-CapVars)/2-1,d0
.clr:   clr.w   (a0)+
        dbra    d0,.clr
        bsr     BuildDimTable
        moveq   #0,d0
        move.b  Prefs+P_Format,d0
        move.l  d0,PopFmt
        moveq   #0,d0
        move.b  Prefs+P_Color,d0
        lsl.w   #2,d0
        lea     FrameColors,a0
        move.l  (a0,d0.w),FrameRGB

        move.l  IntBase,a6
        moveq   #0,d0
        CALL    LockIBase
        move.l  IntBase,a0
        move.l  60(a0),Scr              ; ib_FirstScreen
        move.l  d0,a0
        CALL    UnlockIBase
        move.l  Scr,d0
        beq     .fail
        move.l  d0,a2
        moveq   #0,d0
        move.w  12(a2),d0
        move.l  d0,ScrW
        moveq   #0,d0
        move.w  14(a2),d0
        move.l  d0,ScrH
        lea     84(a2),a0               ; sc_RastPort
        move.l  a0,SrcRP
        move.l  4(a0),SrcBM
        move.l  48(a2),ColorMap         ; sc_ViewPort.ColorMap
        move.l  GfxBase,a6
        lea     44(a2),a0
        CALL    GetVPModeID
        move.l  d0,ModeID
        move.l  SrcBM,a0
        moveq   #BMA_DEPTH,d1
        CALL    GetBitMapAttr
        move.l  d0,SrcDepth
        move.l  CgxBase,d0
        beq     .native
        move.l  d0,a6
        move.l  ModeID,d0
        CALL    IsCyberModeID
        tst.w   d0
        bne     .rtg
.native:
        bsr     SetupNative
        bra     .setup
.rtg:   bsr     SetupRTG
.setup: tst.l   d0
        beq     .fail
        bsr     OpenClone
        tst.l   d0
        beq     .fail
.edit:  bsr     Interact
        tst.l   d0
        beq     .done
        moveq   #0,d0
        move.b  Prefs+P_Action,d0
        bne     .act
        bsr     PopupMenu
        tst.l   d0
        bne     .act
        bsr     RepaintAll
        move.l  #ST_ADJUST,State
        bra     .edit
.act:   move.l  d0,OutAction
        bsr     CloseClone
        bsr     SaveOutput
        tst.l   d0
        beq     .done
        tst.b   Prefs+P_Beep
        beq     .done
        bsr     Beep
        bra     .done
.fail:  bsr     CloseClone
        bsr     Beep
.done:  bsr     CloseClone
        bsr     FreeCapture
        movem.l (sp)+,d2-d7/a2-a6
        rts

Beep:   move.l  IntBase,a6
        sub.l   a0,a0
        CALL    DisplayBeep
        rts

;---------------------------------------------------------------------
SetupNative:
        movem.l d2-d7/a2-a6,-(sp)
        clr.l   IsRGB
        move.l  SrcDepth,d0
        beq     .fail
        cmp.l   #8,d0
        bhi     .fail
        move.l  d0,NDepth
        moveq   #1,d1
        lsl.l   d0,d1
        move.l  d1,NumColors
        lea     Pal,a0
        move.w  #256*3-1,d0
.cp:    clr.l   (a0)+
        dbra    d0,.cp
        move.l  ColorMap,d0
        beq     .nocm
        move.l  d0,a0
        moveq   #0,d0
        move.w  2(a0),d0                ; cm_Count
        move.l  NumColors,d1
        cmp.l   d1,d0
        bls     .c1
        move.l  d1,d0
.c1:    move.l  d0,d1
        beq     .nocm
        move.l  GfxBase,a6
        move.l  ColorMap,a0
        moveq   #0,d0
        lea     Pal,a1
        CALL    GetRGB32
.nocm:  move.l  ModeID,d0
        btst    #11,d0                  ; HAM
        beq     .nh
        move.l  #1,IsHAM
.nh:    btst    #7,d0                   ; EXTRAHALFBRITE
        beq     .ne
        cmp.l   #6,NDepth
        bne     .ne
        move.l  #1,IsEHB
        lea     Pal,a0
        lea     Pal+32*12,a1
        moveq   #32*3-1,d1
.eh:    move.l  (a0)+,d2
        lsr.l   #1,d2
        move.l  d2,(a1)+
        dbra    d1,.eh
.ne:    move.l  NumColors,d0
        tst.l   IsHAM
        beq     .s1
        move.l  NDepth,d1
        subq.l  #2,d1
        moveq   #1,d0
        lsl.l   d1,d0
        bra     .s2
.s1:    tst.l   IsEHB
        beq     .s2
        moveq   #32,d0
.s2:    move.l  d0,SaveColors
        bsr     FindPens
        clr.l   CanDim
        cmp.l   #8,NDepth
        bcc     .nodim
        tst.l   IsHAM
        bne     .nodim
        tst.l   IsEHB
        bne     .nodim
        move.l  ModeID,d0
        btst    #10,d0                  ; DUALPF
        bne     .nodim
        move.l  #1,CanDim
.nodim: moveq   #1,d0
        move.l  NDepth,d1
        lsl.l   d1,d0
        subq.l  #1,d0
        move.l  d0,PlaneMask
        move.l  GfxBase,a6
        move.l  ScrW,d0
        move.l  ScrH,d1
        move.l  NDepth,d2
        add.l   CanDim,d2
        moveq   #BMF_CLEAR|BMF_DISPLAYABLE,d3
        sub.l   a0,a0
        CALL    AllocBitMap
        move.l  d0,BrightBM
        beq     .fail
        move.l  SrcBM,a0
        move.l  BrightBM,a1
        move.l  PlaneMask,d7
        bsr     CopyFull
        move.l  BrightBM,DimBM
        tst.l   CanDim
        beq     .ok
        move.l  ScrW,d0
        move.l  ScrH,d1
        move.l  NDepth,d2
        addq.l  #1,d2
        moveq   #BMF_CLEAR|BMF_DISPLAYABLE,d3
        sub.l   a0,a0
        CALL    AllocBitMap
        tst.l   d0
        bne     .gotdim
        clr.l   CanDim
        bra     .ok
.gotdim:
        move.l  d0,DimBM
        move.l  BrightBM,a0
        move.l  DimBM,a1
        move.l  #$FF,d7
        bsr     CopyFull
        lea     TmpRP,a1
        CALL    InitRastPort
        lea     TmpRP,a0
        move.l  DimBM,4(a0)
        moveq   #1,d0
        move.l  NDepth,d1
        lsl.l   d1,d0
        move.l  d0,d4
        CALL    SetWriteMask
        lea     TmpRP,a1
        move.l  d4,d0
        CALL    SetAPen
        lea     TmpRP,a1
        moveq   #0,d0
        moveq   #0,d1
        move.l  ScrW,d2
        subq.l  #1,d2
        move.l  ScrH,d3
        subq.l  #1,d3
        CALL    RectFill
        CALL    WaitBlit
.ok:    bsr     BuildColors
        moveq   #1,d0
        bra     .ret
.fail:  moveq   #0,d0
.ret:   movem.l (sp)+,d2-d7/a2-a6
        rts

; a0 = source bitmap, a1 = destination, d7 = plane mask
CopyFull:
        moveq   #0,d0
        moveq   #0,d1
        moveq   #0,d2
        moveq   #0,d3
        move.l  ScrW,d4
        move.l  ScrH,d5
        move.l  #$C0,d6
        sub.l   a2,a2
        move.l  GfxBase,a6
        CALL    BltBitMap
        CALL    WaitBlit
        rts

; frame pen = palette entry closest to the chosen colour,
; label = brightest on darkest
FindPens:
        movem.l d2-d7/a2,-(sp)
        lea     Pal,a0
        moveq   #0,d2
        moveq   #-1,d3
        move.l  #$7FFFFFFF,d4
        moveq   #0,d5
        moveq   #0,d6
.l:     moveq   #0,d0
        move.b  (a0),d0
        mulu.w  #3,d0
        moveq   #0,d1
        move.b  4(a0),d1
        mulu.w  #6,d1
        add.l   d1,d0
        moveq   #0,d1
        move.b  8(a0),d1
        add.l   d1,d0
        cmp.l   d3,d0
        ble     .nb
        move.l  d0,d3
        move.l  d2,d5
.nb:    cmp.l   d4,d0
        bge     .nd
        move.l  d0,d4
        move.l  d2,d6
.nd:    lea     12(a0),a0
        addq.l  #1,d2
        cmp.l   SaveColors,d2
        blt     .l
        move.l  d5,LblAPen
        move.l  d6,LblBPen
        move.l  d6,DarkCol
        ; nearest colour to FrameRGB
        lea     Pal,a0
        moveq   #0,d2
        move.l  #$7FFFFFFF,d4
        moveq   #0,d5
.n:     moveq   #0,d7
        moveq   #16,d6
        bsr     .dist
        move.b  4(a0),d0
        moveq   #8,d6
        bsr     .dist2
        move.b  8(a0),d0
        moveq   #0,d6
        bsr     .dist2
        cmp.l   d4,d7
        bge     .nn
        move.l  d7,d4
        move.l  d2,d5
.nn:    lea     12(a0),a0
        addq.l  #1,d2
        cmp.l   SaveColors,d2
        blt     .n
        move.l  d5,FrameCol
        movem.l (sp)+,d2-d7/a2
        rts
.dist:  move.b  (a0),d0
.dist2: moveq   #0,d1
        move.b  d0,d1
        move.l  FrameRGB,d0
        lsr.l   d6,d0
        and.w   #$FF,d0
        sub.w   d0,d1
        muls.w  d1,d1
        add.l   d1,d7
        rts

; SA_Colors32 table (plus the dimmed half when CanDim)
BuildColors:
        movem.l d2-d4/a2,-(sp)
        lea     Colors32,a0
        move.l  NumColors,d0
        move.l  d0,d1
        tst.l   CanDim
        beq     .nd
        add.l   d1,d1
.nd:    move.w  d1,(a0)+
        clr.w   (a0)+
        lea     Pal,a1
        move.l  d0,d1
        mulu.w  #3,d1
        subq.w  #1,d1
.c1:    move.l  (a1)+,(a0)+
        dbra    d1,.c1
        tst.l   CanDim
        beq     .end
        lea     Pal,a1
        lea     DimTable,a2
        move.l  d0,d1
        mulu.w  #3,d1
        subq.w  #1,d1
.c2:    moveq   #0,d2
        move.b  (a1),d2
        addq.l  #4,a1
        move.b  (a2,d2.w),d2
        mulu.w  #$0101,d2
        move.w  d2,d3
        swap    d2
        move.w  d3,d2
        move.l  d2,(a0)+
        dbra    d1,.c2
.end:   clr.l   (a0)
        movem.l (sp)+,d2-d4/a2
        rts

;---------------------------------------------------------------------
SetupRTG:
        movem.l d2-d7/a2-a6,-(sp)
        move.l  #1,IsRGB
        move.l  FrameRGB,FrameCol
        move.l  #BLACK,DarkCol
        moveq   #2,d0
        move.l  d0,LblAPen
        moveq   #1,d0
        move.l  d0,LblBPen
        move.l  CgxBase,a6
        move.l  SrcBM,a0
        move.l  #CYBRMATTR_DEPTH,d0
        CALL    GetCyberMapAttr
        move.l  d0,SrcDepth
        move.l  ScrW,d0
        mulu.w  ScrH+2,d0
        move.l  d0,d1
        add.l   d0,d0
        add.l   d1,d0
        move.l  d0,RGBSize
        move.l  SysBase,a6
        moveq   #0,d1
        CALL    AllocVec
        move.l  d0,OrigRGB
        beq     .fail
        move.l  RGBSize,d0
        moveq   #0,d1
        CALL    AllocVec
        move.l  d0,DimRGB
        beq     .fail
        cmp.l   #8,SrcDepth
        bhi     .truecol
        lea     Pal,a0
        move.w  #256*3-1,d0
.cp:    clr.l   (a0)+
        dbra    d0,.cp
        move.l  ColorMap,d0
        beq     .nopal
        move.l  d0,a0
        moveq   #0,d1
        move.w  2(a0),d1
        cmp.l   #256,d1
        bls     .p1
        move.l  #256,d1
.p1:    tst.l   d1
        beq     .nopal
        move.l  GfxBase,a6
        moveq   #0,d0
        lea     Pal,a1
        CALL    GetRGB32
.nopal: move.l  ScrW,d0
        mulu.w  ScrH+2,d0
        move.l  SysBase,a6
        moveq   #0,d1
        CALL    AllocVec
        move.l  d0,Chunky
        beq     .fail
        move.l  CgxBase,a6
        move.l  Chunky,a0
        moveq   #0,d0
        moveq   #0,d1
        move.l  ScrW,d2
        move.l  SrcRP,a1
        moveq   #0,d3
        moveq   #0,d4
        move.l  ScrW,d5
        move.l  ScrH,d6
        moveq   #RECTFMT_LUT8,d7
        CALL    ReadPixelArray
        move.l  Chunky,a0
        move.l  OrigRGB,a1
        lea     Pal,a2
        move.l  ScrW,d1
        mulu.w  ScrH+2,d1
.ex:    moveq   #0,d0
        move.b  (a0)+,d0
        mulu.w  #12,d0
        lea     (a2,d0.l),a3
        move.b  (a3),(a1)+
        move.b  4(a3),(a1)+
        move.b  8(a3),(a1)+
        subq.l  #1,d1
        bne     .ex
        move.l  SysBase,a6
        move.l  Chunky,a1
        CALL    FreeVec
        clr.l   Chunky
        bsr     FindTrueColorMode
        move.l  d0,CloneMode
        beq     .fail
        bra     .common
.truecol:
        move.l  CgxBase,a6
        move.l  OrigRGB,a0
        moveq   #0,d0
        moveq   #0,d1
        move.l  ScrW,d2
        mulu.w  #3,d2
        move.l  SrcRP,a1
        moveq   #0,d3
        moveq   #0,d4
        move.l  ScrW,d5
        move.l  ScrH,d6
        moveq   #RECTFMT_RGB,d7
        CALL    ReadPixelArray
        move.l  ModeID,CloneMode
.common:
        move.l  CgxBase,a6
        move.l  #CYBRIDATTR_DEPTH,d0
        move.l  CloneMode,d1
        CALL    GetCyberIDAttr
        move.l  d0,CloneDepth
        move.l  OrigRGB,a0
        move.l  DimRGB,a1
        lea     DimTable,a2
        move.l  RGBSize,d1
        moveq   #0,d0
.dm:    move.b  (a0)+,d0
        move.b  (a2,d0.w),(a1)+
        subq.l  #1,d1
        bne     .dm
        moveq   #1,d0
        bra     .ret
.fail:  moveq   #0,d0
.ret:   movem.l (sp)+,d2-d7/a2-a6
        rts

FindTrueColorMode:
        movem.l d2-d7/a2-a6,-(sp)
        move.l  ScrW,BT_W
        move.l  ScrH,BT_H
        move.l  ScrW,BT2_W
        move.l  ScrH,BT2_H
        lea     DepthTry,a2
.next:  move.l  (a2)+,d2
        beq     .none
        move.l  d2,BT_D
        move.l  d2,BT2_D
        move.l  CgxBase,a6
        lea     BestTags,a0
        CALL    BestCModeIDTagList
        bsr     ValidTC
        tst.l   d0
        bne     .ret
        move.l  GfxBase,a6
        lea     BestTags2,a0
        CALL    BestModeIDA
        bsr     ValidTC
        tst.l   d0
        bne     .ret
        bra     .next
.none:  moveq   #0,d0
.ret:   movem.l (sp)+,d2-d7/a2-a6
        rts

ValidTC:
        move.l  d0,d3
        cmp.l   #-1,d0
        beq     .bad
        move.l  CgxBase,a6
        CALL    IsCyberModeID
        tst.w   d0
        beq     .bad
        move.l  #CYBRIDATTR_DEPTH,d0
        move.l  d3,d1
        CALL    GetCyberIDAttr
        cmp.l   #8,d0
        bls     .bad
        move.l  d3,d0
        rts
.bad:   moveq   #0,d0
        rts

;---------------------------------------------------------------------
OpenClone:
        movem.l d2-d7/a2-a6,-(sp)
        move.l  ScrW,d0
        move.l  ScrH,d1
        tst.l   IsRGB
        beq     .nat
        lea     ScrTagsRGB,a1
        move.l  CloneMode,STR_Mode
        move.l  d0,STR_W
        move.l  d1,STR_H
        move.l  CloneDepth,STR_D
        bra     .open
.nat:   lea     ScrTagsNat,a1
        move.l  ModeID,STN_Mode
        move.l  d0,STN_W
        move.l  d1,STN_H
        move.l  NDepth,d0
        add.l   CanDim,d0
        move.l  d0,STN_D
.open:  move.l  IntBase,a6
        sub.l   a0,a0
        CALL    OpenScreenTagList
        move.l  d0,CloneScr
        bne     .got
        tst.l   IsRGB
        bne     .fail
        tst.l   CanDim
        beq     .fail
        clr.l   CanDim
        move.l  DimBM,d0
        cmp.l   BrightBM,d0
        beq     .al
        move.l  GfxBase,a6
        CALL    WaitBlit
        move.l  DimBM,a0
        CALL    FreeBitMap
        move.l  BrightBM,DimBM
.al:    bsr     BuildColors
        move.l  NDepth,STN_D
        move.l  IntBase,a6
        sub.l   a0,a0
        lea     ScrTagsNat,a1
        CALL    OpenScreenTagList
        move.l  d0,CloneScr
        beq     .fail
.got:   move.l  d0,WT_Scr
        move.l  ScrW,WT_W
        move.l  ScrH,WT_H
        sub.l   a0,a0
        lea     WinTags,a1
        CALL    OpenWindowTagList
        move.l  d0,Win
        beq     .fail
        move.l  d0,a0
        move.l  50(a0),WinRP
        bsr     PaintAllDim
        move.l  IntBase,a6
        move.l  CloneScr,a0
        CALL    ScreenToFront
        move.l  Win,a0
        CALL    ActivateWindow
        moveq   #1,d0
        bra     .ret
.fail:  moveq   #0,d0
.ret:   movem.l (sp)+,d2-d7/a2-a6
        rts

PaintAllDim:
        moveq   #0,d0
        moveq   #0,d1
        move.l  ScrW,d2
        subq.l  #1,d2
        move.l  ScrH,d3
        subq.l  #1,d3
        moveq   #0,d4
        bra     PaintRect

; back from the menu: discard stray input and redraw everything
RepaintAll:
        movem.l d2-d7/a2-a6,-(sp)
        move.l  Win,a0
        move.l  86(a0),a2
        move.l  SysBase,a6
.d:     move.l  a2,a0
        CALL    GetMsg
        tst.l   d0
        beq     .e
        move.l  d0,a1
        CALL    ReplyMsg
        bra     .d
.e:     bsr     PaintAllDim
        clr.l   DrawnValid
        clr.l   LblValid
        bsr     Redraw
        move.l  IntBase,a6
        move.l  Win,a0
        CALL    ActivateWindow
        movem.l (sp)+,d2-d7/a2-a6
        rts

CloseClone:
        move.l  IntBase,a6
        move.l  Win,d0
        beq     .s
        move.l  d0,a0
        CALL    CloseWindow
        clr.l   Win
.s:     move.l  CloneScr,d0
        beq     .x
        move.l  d0,a0
        CALL    CloseScreen
        clr.l   CloneScr
.x:     rts

FreeCapture:
        move.l  SysBase,a6
        lea     FreeList,a2
.f:     move.l  (a2)+,d0
        beq     .bm
        move.l  d0,a3
        move.l  (a3),d0
        beq     .f
        clr.l   (a3)
        move.l  d0,a1
        CALL    FreeVec
        bra     .f
.bm:    move.l  GfxBase,a6
        CALL    WaitBlit
        move.l  TmpBM,d0
        beq     .b1
        move.l  d0,a0
        CALL    FreeBitMap
        clr.l   TmpBM
.b1:    move.l  DimBM,d0
        beq     .b2
        cmp.l   BrightBM,d0
        beq     .b2
        move.l  d0,a0
        CALL    FreeBitMap
.b2:    clr.l   DimBM
        move.l  BrightBM,d0
        beq     .b3
        move.l  d0,a0
        CALL    FreeBitMap
        clr.l   BrightBM
.b3:    rts

;=====================================================================
; Painting (rectangles inclusive, clipped to the screen)
;=====================================================================

; d0-d3 = x0,y0,x1,y1  d4 = 0 dimmed / 1 bright
PaintRect:
        movem.l d2-d7/a2-a6,-(sp)
        bsr     ClipRect
        beq     .out
        sub.w   d0,d2
        addq.w  #1,d2
        sub.w   d1,d3
        addq.w  #1,d3
        and.l   #$FFFF,d0
        and.l   #$FFFF,d1
        and.l   #$FFFF,d2
        and.l   #$FFFF,d3
        tst.l   IsRGB
        beq     .planar
        move.l  DimRGB,a0
        tst.w   d4
        beq     .r1
        move.l  OrigRGB,a0
.r1:    move.l  d2,d5
        move.l  d3,d6
        move.l  d0,d3
        move.l  d1,d4
        move.l  ScrW,d2
        mulu.w  #3,d2
        move.l  WinRP,a1
        moveq   #RECTFMT_RGB,d7
        move.l  CgxBase,a6
        CALL    WritePixelArray
        bra     .out
.planar:
        move.l  DimBM,a0
        tst.w   d4
        beq     .p1
        move.l  BrightBM,a0
.p1:    move.l  d2,d4
        move.l  d3,d5
        move.l  d0,d2
        move.l  d1,d3
        move.l  #$C0,d6
        move.l  WinRP,a1
        move.l  GfxBase,a6
        CALL    BltBitMapRastPort
.out:   movem.l (sp)+,d2-d7/a2-a6
        rts

; clip d0-d3 to the screen; Z=1 if empty
ClipRect:
        move.l  d5,-(sp)
        tst.w   d0
        bpl     .1
        moveq   #0,d0
.1:     tst.w   d1
        bpl     .2
        moveq   #0,d1
.2:     move.l  ScrW,d5
        subq.w  #1,d5
        cmp.w   d5,d2
        ble     .3
        move.w  d5,d2
.3:     move.l  ScrH,d5
        subq.w  #1,d5
        cmp.w   d5,d3
        ble     .4
        move.w  d5,d3
.4:     move.l  (sp)+,d5
        cmp.w   d0,d2
        blt     .e
        cmp.w   d1,d3
        blt     .e
        andi.b  #$FB,ccr
        rts
.e:     ori.b   #4,ccr
        rts

; d0-d3 = rect, d4 = colour (RGB) or pen (planar)
FillRect:
        movem.l d2-d7/a2-a6,-(sp)
        bsr     ClipRect
        beq     .out
        ext.l   d0
        ext.l   d1
        ext.l   d2
        ext.l   d3
        tst.l   IsRGB
        beq     .planar
        sub.l   d0,d2
        addq.l  #1,d2
        sub.l   d1,d3
        addq.l  #1,d3
        move.l  WinRP,a1
        move.l  CgxBase,a6
        CALL    FillPixelArray
        bra     .out
.planar:
        movem.l d0-d1,-(sp)
        move.l  GfxBase,a6
        move.l  WinRP,a1
        move.l  d4,d0
        CALL    SetAPen
        movem.l (sp)+,d0-d1
        move.l  WinRP,a1
        CALL    RectFill
.out:   movem.l (sp)+,d2-d7/a2-a6
        rts

; a0 = rect A, a1 = rect B (or 0), d4 = mode : paint A minus B
PaintDiff:
        movem.l d2-d7/a2-a3,-(sp)
        move.l  a0,a2
        move.l  a1,a3
        movem.w (a2),d0-d3
        move.l  a3,d5
        beq     .whole
        cmp.w   4(a3),d0
        bgt     .whole
        cmp.w   (a3),d2
        blt     .whole
        cmp.w   6(a3),d1
        bgt     .whole
        cmp.w   2(a3),d3
        blt     .whole
        move.w  2(a3),d5
        cmp.w   d5,d1
        bge     .notop
        move.w  d5,d3
        subq.w  #1,d3
        bsr     PaintRect
.notop: movem.w (a2),d0-d3
        move.w  6(a3),d5
        cmp.w   d5,d3
        ble     .nobot
        move.w  d5,d1
        addq.w  #1,d1
        bsr     PaintRect
.nobot: movem.w (a2),d0-d3
        move.w  2(a3),d5
        cmp.w   d5,d1
        bge     .m1
        move.w  d5,d1
.m1:    move.w  6(a3),d5
        cmp.w   d5,d3
        ble     .m2
        move.w  d5,d3
.m2:    move.w  d1,d6
        move.w  d3,d7
        move.w  (a3),d5
        cmp.w   d5,d0
        bge     .noleft
        move.w  d5,d2
        subq.w  #1,d2
        bsr     PaintRect
.noleft:
        movem.w (a2),d0-d3
        move.w  d6,d1
        move.w  d7,d3
        move.w  4(a3),d5
        cmp.w   d5,d2
        ble     .done
        move.w  d5,d0
        addq.w  #1,d0
        bsr     PaintRect
        bra     .done
.whole: bsr     PaintRect
.done:  movem.l (sp)+,d2-d7/a2-a3
        rts

; a0 = rect A, a1 = rect B, d4 = mode : paint A intersect B
PaintIsect:
        movem.l d2-d5,-(sp)
        movem.w (a0),d0-d3
        move.w  (a1),d5
        cmp.w   d5,d0
        bge     .1
        move.w  d5,d0
.1:     move.w  2(a1),d5
        cmp.w   d5,d1
        bge     .2
        move.w  d5,d1
.2:     move.w  4(a1),d5
        cmp.w   d5,d2
        ble     .3
        move.w  d5,d2
.3:     move.w  6(a1),d5
        cmp.w   d5,d3
        ble     .4
        move.w  d5,d3
.4:     bsr     PaintRect
        movem.l (sp)+,d2-d5
        rts

;---------------------------------------------------------------------
Redraw:
        movem.l d2-d7/a2-a6,-(sp)
        tst.l   DrawnValid
        beq     .fresh
        movem.w Drawn,d0-d3
        subq.w  #4,d0
        subq.w  #4,d1
        addq.w  #4,d2
        addq.w  #4,d3
        movem.w d0-d3,TmpD
        lea     TmpD,a0
        sub.l   a1,a1
        tst.l   SelValid
        beq     .1
        lea     Sel,a1
.1:     moveq   #0,d4
        bsr     PaintDiff
        tst.l   LblValid
        beq     .2
        lea     Lbl,a0
        sub.l   a1,a1
        tst.l   SelValid
        beq     .1b
        lea     Sel,a1
.1b:    moveq   #0,d4
        bsr     PaintDiff
        tst.l   SelValid
        beq     .2
        lea     Lbl,a0
        lea     Sel,a1
        moveq   #1,d4
        bsr     PaintIsect
.2:     tst.l   SelValid
        beq     .nosel
        lea     Sel,a0
        lea     Drawn,a1
        moveq   #1,d4
        bsr     PaintDiff
        bra     .decor
.fresh: tst.l   SelValid
        beq     .nosel
        movem.w Sel,d0-d3
        moveq   #1,d4
        bsr     PaintRect
.decor: bsr     DrawFrame
        bsr     DrawLabel
        bra     .store
.nosel: clr.l   LblValid
.store: move.l  SelValid,DrawnValid
        move.l  Sel,Drawn
        move.l  Sel+4,Drawn+4
        movem.l (sp)+,d2-d7/a2-a6
        rts

DrawFrame:
        movem.l d2-d7/a2-a3,-(sp)
        lea     Coords,a2
        movem.w Sel,d0-d3
        movem.w d0-d3,(a2)
        move.w  d0,d5
        add.w   d2,d5
        asr.w   #1,d5
        move.w  d5,8(a2)
        move.w  d1,d5
        add.w   d3,d5
        asr.w   #1,d5
        move.w  d5,10(a2)
        move.l  FrameCol,d4
        lea     FrameTable,a3
        moveq   #12-1,d7
.lp:    moveq   #0,d5
        move.b  (a3)+,d5
        add.w   d5,d5
        move.w  (a2,d5.w),d0
        move.b  (a3)+,d6
        ext.w   d6
        add.w   d6,d0
        moveq   #0,d5
        move.b  (a3)+,d5
        add.w   d5,d5
        move.w  (a2,d5.w),d1
        move.b  (a3)+,d6
        ext.w   d6
        add.w   d6,d1
        moveq   #0,d5
        move.b  (a3)+,d5
        add.w   d5,d5
        move.w  (a2,d5.w),d2
        move.b  (a3)+,d6
        ext.w   d6
        add.w   d6,d2
        moveq   #0,d5
        move.b  (a3)+,d5
        add.w   d5,d5
        move.w  (a2,d5.w),d3
        move.b  (a3)+,d6
        ext.w   d6
        add.w   d6,d3
        bsr     FillRect
        dbra    d7,.lp
        movem.l (sp)+,d2-d7/a2-a3
        rts

DrawLabel:
        movem.l d2-d7/a2-a6,-(sp)
        movem.w Sel,d0-d3
        sub.w   d0,d2
        addq.w  #1,d2
        sub.w   d1,d3
        addq.w  #1,d3
        and.l   #$FFFF,d2
        and.l   #$FFFF,d3
        move.l  d2,FmtArgs
        move.l  d3,FmtArgs+4
        lea     LabelFmt,a0
        lea     FmtArgs,a1
        lea     PutChProc(pc),a2
        lea     LabelBuf,a3
        move.l  SysBase,a6
        CALL    RawDoFmt
        lea     LabelBuf,a0
        moveq   #-1,d7
.sl:    addq.l  #1,d7
        tst.b   (a0)+
        bne     .sl
        move.l  GfxBase,a6
        move.l  WinRP,a1
        lea     LabelBuf,a0
        move.l  d7,d0
        CALL    TextLength
        and.l   #$FFFF,d0
        move.l  d0,d5
        move.l  WinRP,a0
        moveq   #0,d6
        move.w  58(a0),d6               ; rp_TxHeight
        addq.w  #2,d6
        movem.w Sel,d0-d3
        move.w  d3,d1
        addq.w  #6,d1
        move.w  d1,d4
        add.w   d6,d4
        subq.w  #1,d4
        move.l  ScrH,d2
        subq.w  #1,d2
        cmp.w   d2,d4
        ble     .vy
        movem.w Sel,d0-d3
        move.w  d1,d4
        subq.w  #6,d1
        sub.w   d6,d1
        bpl     .vy
        move.w  d4,d1
        addq.w  #2,d1
.vy:    movem.w Sel,d0
        move.w  d0,d4
        add.w   d5,d4
        subq.w  #1,d4
        move.l  ScrW,d2
        subq.w  #1,d2
        cmp.w   d2,d4
        ble     .vx
        move.l  ScrW,d0
        sub.w   d5,d0
        bpl     .vx
        moveq   #0,d0
.vx:    move.w  d0,d2
        add.w   d5,d2
        subq.w  #1,d2
        move.w  d1,d3
        add.w   d6,d3
        subq.w  #1,d3
        movem.w d0-d3,Lbl
        move.l  #1,LblValid
        move.l  DarkCol,d4
        bsr     FillRect
        move.l  GfxBase,a6
        move.l  WinRP,a1
        move.l  LblAPen,d0
        move.l  LblBPen,d1
        moveq   #1,d2                   ; JAM2
        CALL    SetABPenDrMd
        move.l  WinRP,a1
        moveq   #0,d0
        move.w  Lbl,d0
        moveq   #0,d1
        move.w  Lbl+2,d1
        addq.w  #1,d1
        add.w   62(a1),d1               ; rp_TxBaseline
        CALL    Move
        move.l  WinRP,a1
        lea     LabelBuf,a0
        move.l  d7,d0
        CALL    Text
        movem.l (sp)+,d2-d7/a2-a6
        rts

PutChProc:
        move.b  d0,(a3)+
        rts

;=====================================================================
; Selection editor; returns d0 = 1 confirmed, 0 cancelled
; (state lives in CapVars, so it can be resumed after the menu)
;=====================================================================
Interact:
        movem.l d2-d7/a2-a6,-(sp)
        clr.l   Dirty
        move.l  Win,a0
        move.l  86(a0),a2               ; wd_UserPort
        moveq   #0,d1
        move.b  15(a2),d1
        moveq   #0,d7
        bset    d1,d7
.wait:  move.l  SysBase,a6
        move.l  d7,d0
        CALL    Wait
.next:  move.l  SysBase,a6
        move.l  a2,a0
        CALL    GetMsg
        tst.l   d0
        beq     .batch
        move.l  d0,a1
        move.l  20(a1),d2               ; im_Class
        move.w  24(a1),d3               ; im_Code
        move.w  32(a1),d4               ; im_MouseX
        move.w  34(a1),d5               ; im_MouseY
        move.l  36(a1),MsgSecs
        move.l  40(a1),MsgMicros
        CALL    ReplyMsg
        tst.w   d4
        bpl     .x1
        moveq   #0,d4
.x1:    move.l  ScrW,d0
        subq.w  #1,d0
        cmp.w   d0,d4
        ble     .x2
        move.w  d0,d4
.x2:    tst.w   d5
        bpl     .y1
        moveq   #0,d5
.y1:    move.l  ScrH,d0
        subq.w  #1,d0
        cmp.w   d0,d5
        ble     .y2
        move.w  d0,d5
.y2:    move.w  d4,MX
        move.w  d5,MY
        cmp.l   #IDCMP_MOUSEMOVE,d2
        beq     .mmove
        cmp.l   #IDCMP_MOUSEBUTTONS,d2
        beq     .mbut
        cmp.l   #IDCMP_RAWKEY,d2
        beq     .key
        bra     .next
.batch: tst.l   Dirty
        beq     .bd
        bsr     Redraw
        clr.l   Dirty
.bd:    bra     .wait

.mmove: move.l  State,d0
        cmp.l   #ST_DRAW,d0
        beq     .mdraw
        cmp.l   #ST_RESIZE,d0
        beq     .mresize
        cmp.l   #ST_MOVE,d0
        beq     .mmovesel
        bra     .next
.mdraw: bsr     SelFromAnchor
        bra     .moved
.mresize:
        move.l  Edges,d6
        lea     Sel,a0
        btst    #0,d6
        beq     .r1
        move.w  MX,(a0)
.r1:    btst    #1,d6
        beq     .r2
        move.w  MX,4(a0)
.r2:    btst    #2,d6
        beq     .r3
        move.w  MY,2(a0)
.r3:    btst    #3,d6
        beq     .r4
        move.w  MY,6(a0)
.r4:    move.w  (a0),d0
        move.w  4(a0),d1
        cmp.w   d1,d0
        ble     .r5
        move.w  d1,(a0)
        move.w  d0,4(a0)
        eor.b   #3,d6
.r5:    move.w  2(a0),d0
        move.w  6(a0),d1
        cmp.w   d1,d0
        ble     .r6
        move.w  d1,2(a0)
        move.w  d0,6(a0)
        eor.b   #12,d6
.r6:    move.l  d6,Edges
        bra     .moved
.mmovesel:
        lea     Sel,a0
        move.w  4(a0),d0
        sub.w   (a0),d0
        move.w  MX,d1
        sub.w   OffX,d1
        bpl     .v1
        moveq   #0,d1
.v1:    move.l  ScrW,d2
        subq.w  #1,d2
        sub.w   d0,d2
        cmp.w   d2,d1
        ble     .v2
        move.w  d2,d1
.v2:    move.w  d1,(a0)
        add.w   d0,d1
        move.w  d1,4(a0)
        move.w  6(a0),d0
        sub.w   2(a0),d0
        move.w  MY,d1
        sub.w   OffY,d1
        bpl     .v3
        moveq   #0,d1
.v3:    move.l  ScrH,d2
        subq.w  #1,d2
        sub.w   d0,d2
        cmp.w   d2,d1
        ble     .v4
        move.w  d2,d1
.v4:    move.w  d1,2(a0)
        add.w   d0,d1
        move.w  d1,6(a0)
.moved: move.l  #1,Moved
        move.l  #1,Dirty
        bra     .next

.mbut:  cmp.w   #SELECTDOWN,d3
        beq     .sdown
        cmp.w   #SELECTUP,d3
        beq     .sup
        cmp.w   #MENUDOWN,d3
        beq     .cancel
        bra     .next
.sdown: clr.l   Moved
        cmp.l   #ST_ADJUST,State
        bne     .newsel
        bsr     InsideSel
        tst.l   d0
        beq     .nodbl
        move.l  IntBase,a6
        move.l  LastSecs,d0
        move.l  LastMicros,d1
        move.l  MsgSecs,d2
        move.l  MsgMicros,d3
        CALL    DoubleClick
        tst.w   d0
        bne     .capture
.nodbl: move.l  MsgSecs,LastSecs
        move.l  MsgMicros,LastMicros
        bsr     HitTest
        tst.l   d0
        beq     .nohit
        move.l  d0,Edges
        move.l  #ST_RESIZE,State
        bra     .next
.nohit: bsr     InsideSel
        tst.l   d0
        beq     .newsel
        move.w  MX,d0
        sub.w   Sel,d0
        move.w  d0,OffX
        move.w  MY,d0
        sub.w   Sel+2,d0
        move.w  d0,OffY
        move.l  #ST_MOVE,State
        bra     .next
.newsel:
        move.l  MsgSecs,LastSecs
        move.l  MsgMicros,LastMicros
        move.w  MX,AnchorX
        move.w  MY,AnchorY
        bsr     SelFromAnchor
        move.l  #1,SelValid
        move.l  #ST_DRAW,State
        move.l  #1,Dirty
        bra     .next
.sup:   move.l  State,d0
        cmp.l   #ST_DRAW,d0
        bne     .sup2
        lea     Sel,a0
        move.w  4(a0),d0
        sub.w   (a0),d0
        cmp.w   #2,d0
        bge     .big
        move.w  6(a0),d0
        sub.w   2(a0),d0
        cmp.w   #2,d0
        bge     .big
        clr.l   SelValid
        clr.l   State
        move.l  #1,Dirty
        bra     .clrm
.big:   move.l  #ST_ADJUST,State
        bra     .clrm
.sup2:  cmp.l   #ST_RESIZE,d0
        beq     .toadj
        cmp.l   #ST_MOVE,d0
        bne     .next
.toadj: move.l  #ST_ADJUST,State
.clrm:  tst.l   Moved
        beq     .next
        clr.l   LastSecs
        clr.l   LastMicros
        clr.l   Moved
        bra     .next

.key:   cmp.w   #KEY_ESC,d3
        beq     .cancel
        cmp.w   #KEY_RETURN,d3
        beq     .enter
        cmp.w   #KEY_ENTER,d3
        beq     .enter
        cmp.w   #KEY_F,d3
        beq     .full
        bra     .next
.enter: tst.l   SelValid
        bne     .capture
.full:  lea     Sel,a0
        clr.w   (a0)
        clr.w   2(a0)
        move.l  ScrW,d0
        subq.w  #1,d0
        move.w  d0,4(a0)
        move.l  ScrH,d0
        subq.w  #1,d0
        move.w  d0,6(a0)
        move.l  #1,SelValid
        bsr     Redraw
.capture:
        tst.l   SelValid
        beq     .next
        tst.l   Dirty
        beq     .cap2
        bsr     Redraw
        clr.l   Dirty
.cap2:  moveq   #1,d0
        bra     .exit
.cancel:
        moveq   #0,d0
.exit:  movem.l (sp)+,d2-d7/a2-a6
        rts

SelFromAnchor:
        move.w  AnchorX,d0
        move.w  MX,d1
        cmp.w   d1,d0
        ble     .1
        exg     d0,d1
.1:     move.w  d0,Sel
        move.w  d1,Sel+4
        move.w  AnchorY,d0
        move.w  MY,d1
        cmp.w   d1,d0
        ble     .2
        exg     d0,d1
.2:     move.w  d0,Sel+2
        move.w  d1,Sel+6
        rts

InsideSel:
        movem.l d1-d5,-(sp)
        moveq   #0,d0
        tst.l   SelValid
        beq     .no
        movem.w Sel,d1-d4
        move.w  MX,d5
        cmp.w   d1,d5
        blt     .no
        cmp.w   d3,d5
        bgt     .no
        move.w  MY,d5
        cmp.w   d2,d5
        blt     .no
        cmp.w   d4,d5
        bgt     .no
        moveq   #1,d0
.no:    movem.l (sp)+,d1-d5
        rts

HitTest:
        movem.l d1-d7,-(sp)
        moveq   #0,d6
        tst.l   SelValid
        beq     .done
        movem.w Sel,d0-d3
        move.w  MX,d4
        move.w  MY,d5
        move.w  d1,d7
        subq.w  #5,d7
        cmp.w   d7,d5
        blt     .noyb
        move.w  d3,d7
        addq.w  #5,d7
        cmp.w   d7,d5
        bgt     .noyb
        move.w  d0,d7
        subq.w  #5,d7
        cmp.w   d7,d4
        blt     .nol
        move.w  d0,d7
        addq.w  #2,d7
        cmp.w   d7,d4
        bgt     .nol
        bset    #0,d6
.nol:   move.w  d2,d7
        subq.w  #2,d7
        cmp.w   d7,d4
        blt     .noyb
        move.w  d2,d7
        addq.w  #5,d7
        cmp.w   d7,d4
        bgt     .noyb
        bset    #1,d6
.noyb:  move.w  d0,d7
        subq.w  #5,d7
        cmp.w   d7,d4
        blt     .noxb
        move.w  d2,d7
        addq.w  #5,d7
        cmp.w   d7,d4
        bgt     .noxb
        move.w  d1,d7
        subq.w  #5,d7
        cmp.w   d7,d5
        blt     .not
        move.w  d1,d7
        addq.w  #2,d7
        cmp.w   d7,d5
        bgt     .not
        bset    #2,d6
.not:   move.w  d3,d7
        subq.w  #2,d7
        cmp.w   d7,d5
        blt     .noxb
        move.w  d3,d7
        addq.w  #5,d7
        cmp.w   d7,d5
        bgt     .noxb
        bset    #3,d6
.noxb:  move.b  d6,d7
        and.b   #3,d7
        cmp.b   #3,d7
        bne     .lr
        and.b   #$FC,d6
        move.w  d0,d7
        add.w   d2,d7
        asr.w   #1,d7
        cmp.w   d7,d4
        bgt     .chr
        bset    #0,d6
        bra     .lr
.chr:   bset    #1,d6
.lr:    move.b  d6,d7
        and.b   #12,d7
        cmp.b   #12,d7
        bne     .done
        and.b   #$F3,d6
        move.w  d1,d7
        add.w   d3,d7
        asr.w   #1,d7
        cmp.w   d7,d5
        bgt     .chb
        bset    #2,d6
        bra     .done
.chb:   bset    #3,d6
.done:  move.l  d6,d0
        movem.l (sp)+,d1-d7
        rts

;=====================================================================
; Floating menu after a capture
; returns d0 = 0 back to editing, ACT_CLIP, ACT_SAVEAS or ACT_OPEN
;=====================================================================
PopupMenu:
        movem.l d2-d7/a2-a6,-(sp)
        clr.l   PopChoice
        clr.l   PopWin
        clr.l   GList
        clr.l   VisInfo
        move.l  GadBase,a6
        move.l  CloneScr,a0
        sub.l   a1,a1
        CALL    GetVisualInfoA
        move.l  d0,VisInfo
        beq     .fallback
        move.l  CloneScr,a2
        move.l  40(a2),a0               ; sc_Font
        move.l  a0,PopTA
        moveq   #0,d0
        move.w  4(a0),d0                ; ta_YSize
        move.l  d0,FontH
        ; "_Open in <program>"
        lea     OpenLabel,a1
        lea     OpenPrefix,a0
.op:    move.b  (a0)+,(a1)+
        bne     .op
        subq.l  #1,a1
        move.l  a1,a3
        tst.b   Prefs+P_Viewer
        beq     .nov
        move.l  DosBase,a6
        move.l  #Prefs+P_Viewer,d1
        CALL    FilePart
        move.l  d0,a0
        moveq   #40-1,d0
.oc:    move.b  (a0)+,(a3)+
        dbeq    d0,.oc
.nov:   clr.b   (a3)
        ; widest label
        moveq   #0,d6
        lea     PopMeasure,a3
        moveq   #5-1,d5
.ml:    move.l  (a3)+,a0
        move.l  a0,a1
        moveq   #-1,d0
.ln:    addq.l  #1,d0
        tst.b   (a1)+
        bne     .ln
        move.l  GfxBase,a6
        lea     84(a2),a1
        CALL    TextLength
        and.l   #$FFFF,d0
        cmp.l   d6,d0
        ble     .mn
        move.l  d0,d6
.mn:    dbra    d5,.ml
        add.l   #24,d6
        move.l  d6,BtnW
        move.l  FontH,d0
        addq.l  #6,d0
        move.l  d0,BtnH
        ; borders
        moveq   #0,d0
        move.b  36(a2),d0               ; WBorLeft
        move.l  d0,BordL
        moveq   #0,d0
        move.b  35(a2),d0               ; WBorTop
        add.l   FontH,d0
        addq.l  #1,d0
        move.l  d0,BordT
        moveq   #0,d0
        move.b  37(a2),d0
        add.l   BordL,d0
        add.l   #16,d0
        add.l   BtnW,d0
        move.l  d0,PopW
        move.l  BtnH,d0
        mulu.w  #5,d0
        add.l   #6+16+6,d0
        add.l   BordT,d0
        moveq   #0,d1
        move.b  38(a2),d1
        add.l   d1,d0
        move.l  d0,PopH
        ; position next to the selection
        moveq   #0,d0
        move.w  Sel+4,d0
        add.l   #12,d0
        move.l  d0,d1
        add.l   PopW,d1
        cmp.l   ScrW,d1
        ble     .px
        moveq   #0,d0
        move.w  Sel,d0
        sub.l   #12,d0
        sub.l   PopW,d0
        bpl     .px
        move.l  ScrW,d0
        sub.l   PopW,d0
        bpl     .px
        moveq   #0,d0
.px:    move.l  d0,PW_L
        moveq   #0,d0
        move.w  Sel+2,d0
        move.l  d0,d1
        add.l   PopH,d1
        cmp.l   ScrH,d1
        ble     .py
        move.l  ScrH,d0
        sub.l   PopH,d0
        bpl     .py
        moveq   #0,d0
.py:    move.l  d0,PW_T
        move.l  PopW,PW_W
        move.l  PopH,PW_H
        move.l  CloneScr,PW_Scr
        ; gadgets
        move.l  GadBase,a6
        lea     GList,a0
        CALL    CreateContext
        tst.l   d0
        beq     .fallback
        move.l  d0,a4                   ; previous gadget
        lea     PopLabels,a3
        moveq   #0,d5                   ; index
.mk:    lea     NG,a1
        move.l  BordL,d0
        addq.l  #8,d0
        move.w  d0,(a1)                 ; ng_LeftEdge
        move.l  BtnH,d0
        addq.l  #4,d0
        mulu.w  d5,d0
        add.l   BordT,d0
        addq.l  #6,d0
        move.w  d0,2(a1)                ; ng_TopEdge
        move.w  BtnW+2,4(a1)
        move.w  BtnH+2,6(a1)
        move.l  (a3)+,8(a1)             ; ng_GadgetText
        move.l  PopTA,12(a1)            ; ng_TextAttr
        move.w  d5,d0
        addq.w  #1,d0
        move.w  d0,16(a1)               ; ng_GadgetID
        move.l  #PLACETEXT_IN,18(a1)
        move.l  VisInfo,22(a1)
        clr.l   26(a1)
        moveq   #BUTTON_KIND,d0
        lea     UnderTags,a2
        cmp.w   #3,d5
        bne     .nc
        move.l  PopFmt,PCY_Act
        lea     PopCyTags,a2
        moveq   #CYCLE_KIND,d0
        bra     .tg
.nc:    cmp.w   #2,d5
        bne     .tg
        tst.b   Prefs+P_Viewer
        bne     .tg
        lea     DisabledTags,a2
.tg:    move.l  a4,a0
        CALL    CreateGadgetA
        tst.l   d0
        beq     .fallback
        move.l  d0,a4
        cmp.w   #3,d5
        bne     .ng
        move.l  d0,PopCyc
.ng:    addq.w  #1,d5
        cmp.w   #5,d5
        blt     .mk
        move.l  GList,PW_Gad
        move.l  IntBase,a6
        sub.l   a0,a0
        lea     PopWinTags,a1
        CALL    OpenWindowTagList
        move.l  d0,PopWin
        beq     .fallback
        move.l  GadBase,a6
        move.l  d0,a0
        sub.l   a1,a1
        CALL    GT_RefreshWindow
.loop:  move.l  PopWin,a0
        move.l  86(a0),a0
        move.l  SysBase,a6
        CALL    WaitPort
.msg:   move.l  PopWin,a0
        move.l  86(a0),a0
        move.l  GadBase,a6
        CALL    GT_GetIMsg
        tst.l   d0
        beq     .loop
        move.l  d0,a1
        move.l  20(a1),d2
        move.w  24(a1),d3
        move.l  28(a1),a3
        CALL    GT_ReplyIMsg
        cmp.l   #IDCMP_REFRESHWINDOW,d2
        bne     .m1
        move.l  PopWin,a0
        CALL    GT_BeginRefresh
        move.l  PopWin,a0
        moveq   #1,d0
        CALL    GT_EndRefresh
        bra     .msg
.m1:    cmp.l   #IDCMP_CLOSEWINDOW,d2
        beq     .back
        cmp.l   #IDCMP_GADGETUP,d2
        bne     .m2
        move.w  38(a3),d0               ; gg_GadgetID
        cmp.w   #1,d0
        beq     .clip
        cmp.w   #2,d0
        beq     .saveas
        cmp.w   #3,d0
        beq     .open
        cmp.w   #4,d0
        bne     .back
        moveq   #0,d0                   ; format cycle
        move.w  d3,d0
        move.l  d0,PopFmt
        bra     .msg
.m2:    cmp.l   #IDCMP_VANILLAKEY,d2
        bne     .msg
        move.b  d3,d0
        cmp.b   #27,d0
        beq     .back
        cmp.b   #13,d0
        beq     .clip
        or.b    #$20,d0
        cmp.b   #'c',d0
        beq     .clip
        cmp.b   #'s',d0
        beq     .saveas
        cmp.b   #'f',d0
        beq     .nextfmt
        cmp.b   #'o',d0
        bne     .msg
.open:  tst.b   Prefs+P_Viewer
        beq     .msg
        move.l  PopFmt,ExplFmt
        move.l  #ACT_OPEN,PopChoice
        bra     .close
.clip:  move.l  #ACT_CLIP,PopChoice
        bra     .close
.nextfmt:
        move.l  PopFmt,d0
        addq.l  #1,d0
        cmp.l   #5,d0
        blt     .nf
        moveq   #0,d0
.nf:    move.l  d0,PopFmt
        move.l  d0,PCY_Set
        move.l  PopCyc,a0
        move.l  PopWin,a1
        sub.l   a2,a2
        lea     PopCySetTags,a3
        move.l  GadBase,a6
        CALL    GT_SetGadgetAttrsA
        bra     .msg
.saveas:
        bsr     SaveAsRequester
        tst.l   d0
        beq     .msg
        move.l  #ACT_SAVEAS,PopChoice
        bra     .close
.back:  clr.l   PopChoice
        bra     .close
.fallback:
        move.l  #ACT_BOTH,PopChoice
.close: move.l  PopWin,d0
        beq     .c1
        move.l  IntBase,a6
        move.l  d0,a0
        CALL    CloseWindow
        clr.l   PopWin
.c1:    move.l  GadBase,a6
        move.l  GList,a0
        CALL    FreeGadgets
        clr.l   GList
        move.l  VisInfo,d0
        beq     .c2
        move.l  d0,a0
        CALL    FreeVisualInfo
        clr.l   VisInfo
.c2:    move.l  PopChoice,d0
        movem.l (sp)+,d2-d7/a2-a6
        rts

; ASL save requester on the overlay screen -> PathBuf, ExplPNG
SaveAsRequester:
        movem.l d2-d7/a2-a6,-(sp)
        move.l  AslBase,d0
        beq     .fail
        move.l  d0,a6
        move.l  FileReq,d0
        bne     .have
        moveq   #0,d0                   ; ASL_FileRequest
        sub.l   a0,a0
        CALL    AllocAslRequest
        move.l  d0,FileReq
        beq     .fail
.have:  ; suggested name: next free AmiSnip_NNN in the default drawer
        move.l  PopFmt,d0
        bsr     ExtFor
        lea     Prefs+P_SaveDir,a1
        bsr     NextFreeName
        move.l  CloneScr,AT_Scr
        move.l  PopWin,AT_Win
        move.l  AslBase,a6
        move.l  FileReq,a0
        lea     AslTags,a1
        CALL    AslRequest
        tst.l   d0
        beq     .fail
        move.l  FileReq,a0
        move.l  4(a0),a2                ; fr_File
        tst.b   (a2)
        beq     .fail
        move.l  8(a0),a0                ; fr_Drawer
        lea     PathBuf,a1
        move.w  #255,d0
.cd:    move.b  (a0)+,(a1)+
        dbeq    d0,.cd
        clr.b   (a1)
        move.l  DosBase,a6
        move.l  #PathBuf,d1
        move.l  a2,d2
        move.l  #300,d3
        CALL    AddPart
        tst.l   d0
        beq     .fail
        ; format from the extension, or add the default one
        lea     ExtMatch,a2
.em:    move.l  (a2)+,d0
        beq     .noext
        move.l  d0,a1
        move.l  (a2)+,d2
        bsr     EndsWith
        tst.l   d0
        beq     .em
        move.l  d2,ExplFmt
        bra     .ok
.noext: move.l  PopFmt,d0
        move.l  d0,ExplFmt
        bsr     ExtFor
        lea     PathBuf,a1
.e:     tst.b   (a1)+
        bne     .e
        move.b  #'.',-1(a1)
.ea:    move.b  (a0)+,(a1)+
        bne     .ea
.ok:    moveq   #1,d0
        bra     .ret
.fail:  moveq   #0,d0
.ret:   movem.l (sp)+,d2-d7/a2-a6
        rts

; d0 = format 0..4 -> a0 = extension
ExtFor: move.l  d0,-(sp)
        lsl.w   #2,d0
        lea     ExtTable,a0
        move.l  (a0,d0.w),a0
        move.l  (sp)+,d0
        rts

; does PathBuf end with a1 (lower case)?  d0 = 1/0
EndsWith:
        movem.l d1-d3/a0-a2,-(sp)
        lea     PathBuf,a0
        move.l  a0,a2
.l1:    tst.b   (a0)+
        bne     .l1
        subq.l  #1,a0                   ; a0 = end of PathBuf
        move.l  a1,d3
.l2:    tst.b   (a1)+
        bne     .l2
        subq.l  #1,a1
        move.l  a1,d2
        sub.l   d3,d2                   ; suffix length
        move.l  a0,d1
        sub.l   a2,d1
        cmp.l   d2,d1
        blt     .no
        sub.l   d2,a0
        move.l  d3,a1
        subq.w  #1,d2
.l3:    move.b  (a0)+,d0
        cmp.b   #'A',d0
        blt     .lc
        cmp.b   #'Z',d0
        bgt     .lc
        or.b    #$20,d0
.lc:    cmp.b   (a1)+,d0
        bne     .no
        dbra    d2,.l3
        moveq   #1,d0
        bra     .ret
.no:    moveq   #0,d0
.ret:   movem.l (sp)+,d1-d3/a0-a2
        rts

; a0 = extension, a1 = drawer -> FileNameBuf, PathBuf = first free
; "AmiSnip_NNN.ext" in that drawer.  d0 = 1 ok
NextFreeName:
        movem.l d2-d7/a2-a6,-(sp)
        move.l  a0,d6
        move.l  a1,a4
        moveq   #1,d7
.try:   move.l  d7,FmtArgs
        move.l  d6,FmtArgs+4
        lea     NameFmt,a0
        lea     FmtArgs,a1
        lea     PutChProc(pc),a2
        lea     FileNameBuf,a3
        move.l  SysBase,a6
        CALL    RawDoFmt
        move.l  a4,a0
        lea     PathBuf,a1
        move.w  #255,d0
.cs:    move.b  (a0)+,(a1)+
        dbeq    d0,.cs
        clr.b   (a1)
        move.l  DosBase,a6
        move.l  #PathBuf,d1
        move.l  #FileNameBuf,d2
        move.l  #300,d3
        CALL    AddPart
        tst.l   d0
        beq     .fail
        move.l  #PathBuf,d1
        moveq   #SHARED_LOCK,d2
        CALL    Lock
        tst.l   d0
        beq     .free
        move.l  d0,d1
        CALL    UnLock
        addq.l  #1,d7
        cmp.l   #1000,d7
        blt     .try
.fail:  moveq   #0,d0
        bra     .ret
.free:  moveq   #1,d0
.ret:   movem.l (sp)+,d2-d7/a2-a6
        rts

;=====================================================================
; Output (OutAction) -> d0 = 1 success
;=====================================================================
SaveOutput:
        movem.l d2-d7/a2-a6,-(sp)
        move.l  #1,OutOK
        move.l  SysBase,a6
        move.l  DimRGB,d0
        beq     .nd
        move.l  d0,a1
        CALL    FreeVec
        clr.l   DimRGB
.nd:    movem.w Sel,d0-d3
        sub.w   d0,d2
        addq.w  #1,d2
        sub.w   d1,d3
        addq.w  #1,d3
        and.l   #$FFFF,d0
        and.l   #$FFFF,d1
        and.l   #$FFFF,d2
        and.l   #$FFFF,d3
        move.l  d0,CropX
        move.l  d1,CropY
        move.l  d2,CropW
        move.l  d3,CropH
        move.l  d2,d0
        add.l   #15,d0
        lsr.l   #4,d0
        add.l   d0,d0
        move.l  d0,RowBytes
        tst.l   IsRGB
        beq     .planar
        move.l  CropY,d0
        mulu.w  ScrW+2,d0
        add.l   CropX,d0
        move.l  d0,d1
        add.l   d0,d0
        add.l   d1,d0
        add.l   OrigRGB,d0
        move.l  d0,CropBase
        move.l  ScrW,d0
        mulu.w  #3,d0
        move.l  d0,Stride
        bra     .go
.planar:
        move.l  GfxBase,a6
        move.l  CropW,d0
        move.l  CropH,d1
        move.l  NDepth,d2
        moveq   #BMF_CLEAR,d3
        sub.l   a0,a0
        CALL    AllocBitMap
        move.l  d0,TmpBM
        beq     .err
        move.l  BrightBM,a0
        move.l  CropX,d0
        move.l  CropY,d1
        move.l  TmpBM,a1
        moveq   #0,d2
        moveq   #0,d3
        move.l  CropW,d4
        move.l  CropH,d5
        move.l  #$C0,d6
        move.l  PlaneMask,d7
        sub.l   a2,a2
        CALL    BltBitMap
        CALL    WaitBlit
.go:    ; what to do
        move.l  OutAction,d7
        moveq   #0,d0                   ; file format
        cmp.l   #ACT_SAVEAS,d7
        beq     .f0
        cmp.l   #ACT_OPEN,d7
        bne     .f1
.f0:    move.l  ExplFmt,d0
        bra     .f3
.f1:    move.b  Prefs+P_Format,d0
.f3:    move.l  d0,FileFmt
        tst.l   d0
        beq     .src
        bsr     PrepSource
        tst.l   d0
        beq     .err
.src:   ; clipboard (always IFF ILBM)
        cmp.l   #ACT_CLIP,d7
        beq     .doclip
        cmp.l   #ACT_BOTH,d7
        bne     .noclip
.doclip:
        bsr     BuildILBM
        tst.l   d0
        beq     .err
        bsr     WriteClip
        tst.l   d0
        bne     .cok
        clr.l   OutOK
.cok:   cmp.l   #ACT_CLIP,d7
        beq     .done
        tst.l   FileFmt
        beq     .havebuf
        bsr     FreeOut
.noclip:
        move.l  FileFmt,d0
        lsl.w   #2,d0
        lea     Builders,a0
        move.l  (a0,d0.w),a0
        jsr     (a0)
        tst.l   d0
        beq     .err
.havebuf:
        ; target name
        cmp.l   #ACT_SAVEAS,d7
        beq     .write
        move.l  FileFmt,d0
        bsr     ExtFor
        lea     Prefs+P_SaveDir,a1
        cmp.l   #ACT_OPEN,d7
        bne     .nf
        lea     TDir,a1
.nf:    bsr     NextFreeName
        tst.l   d0
        beq     .err
.write: bsr     WriteOut
        tst.l   d0
        beq     .err
        cmp.l   #ACT_OPEN,d7
        bne     .done
        move.l  #Prefs+P_Viewer,FmtArgs
        move.l  #PathBuf,FmtArgs+4
        lea     CmdFmt,a0
        lea     FmtArgs,a1
        lea     PutChProc(pc),a2
        lea     CmdBuf,a3
        move.l  SysBase,a6
        CALL    RawDoFmt
        lea     CmdBuf,a0
        bsr     RunAsync
        tst.l   d0
        bne     .done
.err:   clr.l   OutOK
        bsr     Beep
.done:  bsr     FreeOut
        move.l  OutOK,d0
        movem.l (sp)+,d2-d7/a2-a6
        rts

FreeOut:
        move.l  SysBase,a6
        move.l  OutBuf,d0
        beq     .x
        move.l  d0,a1
        CALL    FreeVec
        clr.l   OutBuf
.x:     rts

; OutBuf -> PathBuf ; d0 = 1 ok
WriteOut:
        movem.l d2-d5/a6,-(sp)
        move.l  DosBase,a6
        move.l  #PathBuf,d1
        move.l  #MODE_NEWFILE,d2
        CALL    Open
        move.l  d0,d5
        beq     .fail
        move.l  d5,d1
        move.l  OutBuf,d2
        move.l  OutSize,d3
        CALL    Write
        move.l  d0,d4
        move.l  d5,d1
        CALL    Close
        cmp.l   OutSize,d4
        bne     .fail
        moveq   #1,d0
        bra     .ret
.fail:  moveq   #0,d0
.ret:   movem.l (sp)+,d2-d5/a6
        rts

Mul32:
        movem.l d2-d3,-(sp)
        move.l  d0,d2
        swap    d2
        mulu.w  d1,d2
        move.l  d1,d3
        swap    d3
        mulu.w  d0,d3
        add.l   d3,d2
        swap    d2
        clr.w   d2
        mulu.w  d1,d0
        add.l   d2,d0
        movem.l (sp)+,d2-d3
        rts

;---------------------------------------------------------------------
BuildILBM:
        movem.l d2-d7/a2-a5,-(sp)
        bsr     FreeOut
        tst.l   IsRGB
        beq     .pl
        moveq   #24,d0
        moveq   #0,d1
        bra     .c
.pl:    move.l  NDepth,d0
        move.l  SaveColors,d1
.c:     move.l  d0,ILPlanes
        move.l  d1,ILCmap
        move.l  RowBytes,d0
        mulu.w  ILPlanes+2,d0
        move.l  CropH,d1
        bsr     Mul32
        move.l  d0,ILBody
        add.l   #48,d0
        move.l  ILCmap,d1
        beq     .nocm
        mulu.w  #3,d1
        add.l   d1,d0
        add.l   #8+12,d0
.nocm:  move.l  d0,OutSize
        move.l  SysBase,a6
        moveq   #0,d1
        CALL    AllocVec
        move.l  d0,OutBuf
        beq     .fail
        move.l  d0,a5
        move.l  #'FORM',(a5)+
        move.l  OutSize,d0
        subq.l  #8,d0
        move.l  d0,(a5)+
        move.l  #'ILBM',(a5)+
        move.l  #'BMHD',(a5)+
        moveq   #20,d0
        move.l  d0,(a5)+
        move.w  CropW+2,(a5)+
        move.w  CropH+2,(a5)+
        clr.l   (a5)+
        move.b  ILPlanes+3,(a5)+
        clr.b   (a5)+
        clr.b   (a5)+
        clr.b   (a5)+
        clr.w   (a5)+
        move.b  #1,(a5)+
        move.b  #1,(a5)+
        move.w  ScrW+2,(a5)+
        move.w  ScrH+2,(a5)+
        move.l  ILCmap,d1
        beq     .body
        move.l  #'CMAP',(a5)+
        move.l  d1,d0
        mulu.w  #3,d0
        move.l  d0,(a5)+
        lea     Pal,a0
        subq.w  #1,d1
.cm:    move.b  (a0),(a5)+
        move.b  4(a0),(a5)+
        move.b  8(a0),(a5)+
        lea     12(a0),a0
        dbra    d1,.cm
        move.l  #'CAMG',(a5)+
        moveq   #4,d0
        move.l  d0,(a5)+
        move.l  ModeID,(a5)+
.body:  move.l  #'BODY',(a5)+
        move.l  ILBody,(a5)+
        tst.l   IsRGB
        beq     .bp
        bsr     BodyRGB
        bra     .ok
.bp:    bsr     BodyPlanar
.ok:    moveq   #1,d0
        bra     .ret
.fail:  moveq   #0,d0
.ret:   movem.l (sp)+,d2-d7/a2-a5
        rts

BodyRGB:
        move.l  CropBase,a4
        move.l  CropH,d7
        subq.l  #1,d7
.row:   moveq   #0,d3
.comp:  moveq   #0,d4
.bit:   lea     (a4,d3.l),a1
        move.l  CropW,d1
        subq.l  #1,d1
        move.l  RowBytes,d2
        lsl.l   #3,d2
        sub.l   CropW,d2
        moveq   #8,d6
        moveq   #0,d5
.px:    move.b  (a1),d0
        addq.l  #3,a1
        lsr.b   d4,d0
        lsr.b   #1,d0
        addx.b  d5,d5
        subq.b  #1,d6
        bne     .nx
        move.b  d5,(a5)+
        moveq   #8,d6
.nx:    dbra    d1,.px
        tst.w   d2
        beq     .bd
        subq.w  #1,d2
.pd:    add.b   d5,d5
        subq.b  #1,d6
        bne     .pn
        move.b  d5,(a5)+
        moveq   #8,d6
.pn:    dbra    d2,.pd
.bd:    addq.w  #1,d4
        cmp.w   #8,d4
        blt     .bit
        addq.w  #1,d3
        cmp.w   #3,d3
        blt     .comp
        add.l   Stride,a4
        dbra    d7,.row
        rts

BodyPlanar:
        move.l  TmpBM,a3
        moveq   #0,d7
.row:   moveq   #0,d0
        move.w  (a3),d0
        mulu.w  d7,d0
        moveq   #0,d3
.pl:    move.w  d3,d1
        lsl.w   #2,d1
        move.l  8(a3,d1.w),a0
        add.l   d0,a0
        move.l  RowBytes,d2
        subq.w  #1,d2
.cp:    move.b  (a0)+,(a5)+
        dbra    d2,.cp
        addq.l  #1,d3
        cmp.l   NDepth,d3
        blt     .pl
        addq.l  #1,d7
        cmp.l   CropH,d7
        blt     .row
        rts

;---------------------------------------------------------------------
PutL:   rol.l   #8,d0
        move.b  d0,(a5)+
        rol.l   #8,d0
        move.b  d0,(a5)+
        rol.l   #8,d0
        move.b  d0,(a5)+
        rol.l   #8,d0
        move.b  d0,(a5)+
        rts

BeginChunk:
        move.l  d0,-(sp)
        moveq   #0,d0
        bsr     PutL
        move.l  a5,ChunkStart
        move.l  (sp)+,d0
        bra     PutL

EndChunk:
        move.l  a5,d0
        sub.l   ChunkStart,d0
        subq.l  #4,d0
        move.l  ChunkStart,a0
        subq.l  #4,a0
        rol.l   #8,d0
        move.b  d0,(a0)+
        rol.l   #8,d0
        move.b  d0,(a0)+
        rol.l   #8,d0
        move.b  d0,(a0)+
        rol.l   #8,d0
        move.b  d0,(a0)+
        move.l  ChunkStart,a0
        move.l  a5,d0
        sub.l   a0,d0
        bsr     Crc32
        bra     PutL

Crc32:  move.l  d2,-(sp)
        moveq   #-1,d1
        lea     CrcTable,a1
.l:     subq.l  #1,d0
        bmi     .e
        moveq   #0,d2
        move.b  (a0)+,d2
        eor.b   d1,d2
        add.w   d2,d2
        add.w   d2,d2
        move.l  (a1,d2.w),d2
        lsr.l   #8,d1
        eor.l   d2,d1
        bra     .l
.e:     not.l   d1
        move.l  d1,d0
        move.l  (sp)+,d2
        rts

Adler32:
        movem.l d2-d4,-(sp)
        moveq   #1,d1
        moveq   #0,d2
.outer: tst.l   d0
        beq     .end
        move.l  #4096,d3
        cmp.l   d3,d0
        bcc     .c
        move.l  d0,d3
.c:     sub.l   d3,d0
        subq.w  #1,d3
.in:    moveq   #0,d4
        move.b  (a0)+,d4
        add.l   d4,d1
        add.l   d1,d2
        dbra    d3,.in
        divu.w  #65521,d1
        swap    d1
        and.l   #$FFFF,d1
        divu.w  #65521,d2
        swap    d2
        and.l   #$FFFF,d2
        bra     .outer
.end:   move.l  d2,d0
        swap    d0
        move.w  d1,d0
        movem.l (sp)+,d2-d4
        rts

;---------------------------------------------------------------------
; OutBuf -> clipboard.device unit 0 ; d0 = 1 ok
WriteClip:
        movem.l d2-d7/a2-a6,-(sp)
        moveq   #0,d4
        move.l  SysBase,a6
        CALL    CreateMsgPort
        move.l  d0,d6
        beq     .x
        move.l  d0,a0
        moveq   #52,d0
        CALL    CreateIORequest
        move.l  d0,d7
        beq     .np
        lea     ClipName,a0
        moveq   #0,d0
        move.l  d7,a1
        moveq   #0,d1
        CALL    OpenDevice
        tst.l   d0
        bne     .nd
        move.l  d7,a1
        move.w  #CMD_WRITE,28(a1)
        move.l  OutBuf,40(a1)
        move.l  OutSize,36(a1)
        clr.l   44(a1)
        clr.l   48(a1)
        CALL    DoIO
        move.l  d7,a1
        tst.b   31(a1)                  ; io_Error
        bne     .wr
        moveq   #1,d4
.wr:    move.w  #CMD_UPDATE,28(a1)
        clr.l   36(a1)
        CALL    DoIO
        move.l  d7,a1
        CALL    CloseDevice
.nd:    move.l  d7,a0
        CALL    DeleteIORequest
.np:    move.l  d6,a0
        CALL    DeleteMsgPort
.x:     move.l  d4,d0
        movem.l (sp)+,d2-d7/a2-a6
        rts

        include "encoders.i"
        include "prefs_code.i"

;=====================================================================
        section data,data
;=====================================================================
        cnop    0,4
LibBases:
DosBase:        dc.l 0
IntBase:        dc.l 0
GfxBase:        dc.l 0
CxBase:         dc.l 0
GadBase:        dc.l 0
IconBase:       dc.l 0
CgxBase:        dc.l 0
AslBase:        dc.l 0
NUMLIBS         equ 8

; name, version, base, required
LibTable:
        dc.l    DosName,39,DosBase,1
        dc.l    IntName,39,IntBase,1
        dc.l    GfxName,39,GfxBase,1
        dc.l    CxName,37,CxBase,1
        dc.l    GadName,39,GadBase,1
        dc.l    IconName,37,IconBase,0
        dc.l    CgxName,40,CgxBase,0
        dc.l    AslName,38,AslBase,0
        dc.l    0

FreeList:       dc.l OrigRGB,DimRGB,Chunky,RawBuf,OutBuf,IdxBuf,RGBOwn,0

DimMuls:        dc.w 256,170,105,50
FrameColors:    dc.l $FFFFFF,$FFE000,$00D0FF,$FF3030,$30FF30

NewBroker:
        dc.b    5,0                     ; NB_VERSION
        dc.l    CxNameStr
        dc.l    CxTitleStr
        dc.l    CxDescrStr
        dc.w    3                       ; NBU_UNIQUE|NBU_NOTIFY
        dc.w    4                       ; COF_SHOW_HIDE
NB_Pri: dc.b    0,0
NB_Port:
        dc.l    0
        dc.w    0

ScrTagsNat:
        dc.l    SA_DisplayID
STN_Mode:
        dc.l    0
        dc.l    SA_Width
STN_W:  dc.l    0
        dc.l    SA_Height
STN_H:  dc.l    0
        dc.l    SA_Depth
STN_D:  dc.l    0
        dc.l    SA_Colors32,Colors32
        dc.l    SA_Type,CUSTOMSCREEN
        dc.l    SA_ShowTitle,0
        dc.l    SA_Quiet,1
        dc.l    SA_Behind,1
        dc.l    SA_AutoScroll,1
        dc.l    SA_Draggable,0
        dc.l    SA_Pens,PensArr
        dc.l    TAG_DONE

ScrTagsRGB:
        dc.l    SA_DisplayID
STR_Mode:
        dc.l    0
        dc.l    SA_Width
STR_W:  dc.l    0
        dc.l    SA_Height
STR_H:  dc.l    0
        dc.l    SA_Depth
STR_D:  dc.l    0
        dc.l    SA_Type,CUSTOMSCREEN
        dc.l    SA_ShowTitle,0
        dc.l    SA_Quiet,1
        dc.l    SA_Behind,1
        dc.l    SA_AutoScroll,1
        dc.l    SA_Draggable,0
        dc.l    SA_Pens,PensArr
        dc.l    TAG_DONE

WinTags:
        dc.l    WA_CustomScreen
WT_Scr: dc.l    0
        dc.l    WA_Left,0
        dc.l    WA_Top,0
        dc.l    WA_Width
WT_W:   dc.l    0
        dc.l    WA_Height
WT_H:   dc.l    0
        dc.l    WA_Flags,WINFLAGS
        dc.l    WA_IDCMP,IDCMP_MOUSEBUTTONS|IDCMP_MOUSEMOVE|IDCMP_RAWKEY
        dc.l    TAG_DONE

PopWinTags:
        dc.l    WA_Left
PW_L:   dc.l    0
        dc.l    WA_Top
PW_T:   dc.l    0
        dc.l    WA_Width
PW_W:   dc.l    0
        dc.l    WA_Height
PW_H:   dc.l    0
        dc.l    WA_CustomScreen
PW_Scr: dc.l    0
        dc.l    WA_Gadgets
PW_Gad: dc.l    0
        dc.l    WA_Title,PopTitle
        dc.l    WA_Flags,WFLG_DRAGBAR|WFLG_DEPTHGADGET|WFLG_CLOSEGADGET|WFLG_ACTIVATE|WFLG_RMBTRAP
        dc.l    WA_IDCMP,IDCMP_GADGETUP|IDCMP_CLOSEWINDOW|IDCMP_VANILLAKEY|IDCMP_REFRESHWINDOW
        dc.l    TAG_DONE

UnderTags:
        dc.l    GT_Underscore,'_'
        dc.l    TAG_DONE
DisabledTags:
        dc.l    GT_Underscore,'_'
        dc.l    GA_Disabled,1
        dc.l    TAG_DONE

AslTags:
        dc.l    ASLFR_Screen
AT_Scr: dc.l    0
        dc.l    ASLFR_Window
AT_Win: dc.l    0
        dc.l    ASLFR_SleepWindow,1
        dc.l    ASLFR_TitleText,AslTitle
        dc.l    ASLFR_DoSaveMode,1
        dc.l    ASLFR_RejectIcons,1
        dc.l    ASLFR_InitialDrawer,Prefs+P_SaveDir
        dc.l    ASLFR_InitialFile,FileNameBuf
        dc.l    TAG_DONE

RunTags:
        dc.l    SYS_Input,0
        dc.l    SYS_Output,0
        dc.l    SYS_Asynch,1
        dc.l    NP_StackSize,32768
        dc.l    TAG_DONE

ExtTable:       dc.l ExtIFF,ExtPNG,ExtJPG,ExtBMP,ExtGIF
ExtMatch:       dc.l ExtPNGDot,1,ExtJPGDot,2,ExtJPEGDot,2,ExtBMPDot,3
                dc.l ExtGIFDot,4,ExtIFFDot,0,ExtILBMDot,0,0
Builders:       dc.l BuildILBM,BuildPNG,BuildJPEG,BuildBMP,BuildGIF

PopLabels:
        dc.l    PL_Clip,PL_Save,OpenLabel,0,PL_Cancel
PopMeasure:
        dc.l    PL_Clip,PL_Save,OpenLabel,PL_Cancel,PL_CycW
PopCyTags:
        dc.l    GTCY_Labels,FmtCycLabels
        dc.l    GTCY_Active
PCY_Act:
        dc.l    0
        dc.l    TAG_DONE
PopCySetTags:
        dc.l    GTCY_Active
PCY_Set:
        dc.l    0
        dc.l    TAG_DONE
FmtCycLabels:
        dc.l    FC0,FC1,FC2,FC3,FC4,0

BestTags:
        dc.l    CYBRBIDTG_Depth
BT_D:   dc.l    24
        dc.l    CYBRBIDTG_NominalWidth
BT_W:   dc.l    0
        dc.l    CYBRBIDTG_NominalHeight
BT_H:   dc.l    0
        dc.l    TAG_DONE

BestTags2:
        dc.l    BIDTAG_NominalWidth
BT2_W:  dc.l    0
        dc.l    BIDTAG_NominalHeight
BT2_H:  dc.l    0
        dc.l    BIDTAG_Depth
BT2_D:  dc.l    24
        dc.l    TAG_DONE

DepthTry:
        dc.l    24,16,15,32,0

PensArr:
        dc.w    -1

FrameTable:
        dc.b    0,-1, 1,-1, 2,1, 1,-1   ; top line
        dc.b    0,-1, 3,1,  2,1, 3,1    ; bottom line
        dc.b    0,-1, 1,0,  0,-1, 3,0   ; left line
        dc.b    2,1,  1,0,  2,1, 3,0    ; right line
        dc.b    0,-4, 1,-4, 0,-1, 1,-1  ; top-left
        dc.b    2,1,  1,-4, 2,4, 1,-1   ; top-right
        dc.b    0,-4, 3,1,  0,-1, 3,4   ; bottom-left
        dc.b    2,1,  3,1,  2,4, 3,4    ; bottom-right
        dc.b    4,-2, 1,-4, 4,1, 1,-1   ; top
        dc.b    4,-2, 3,1,  4,1, 3,4    ; bottom
        dc.b    0,-4, 5,-2, 0,-1, 5,1   ; left
        dc.b    2,1,  5,-2, 2,4, 5,1    ; right

DosName:        dc.b "dos.library",0
IntName:        dc.b "intuition.library",0
GfxName:        dc.b "graphics.library",0
CxName:         dc.b "commodities.library",0
GadName:        dc.b "gadtools.library",0
IconName:       dc.b "icon.library",0
CgxName:        dc.b "cybergraphics.library",0
AslName:        dc.b "asl.library",0
ClipName:       dc.b "clipboard.device",0
NilName:        dc.b "NIL:",0
PubPortName:    dc.b "AmiSnip",0
CxNameStr:      dc.b "AmiSnip",0
CxTitleStr:     dc.b "AmiSnip 1.3 by Amigatronics",0
CxDescrStr:     dc.b "Capture a screen area. Show = preferences",0
Template:       dc.b "QUIT/S,CX_PRIORITY/K/N",0
UsageStr:       dc.b "AmiSnip 1.3 by Amigatronics",10
                dc.b "Usage: AmiSnip [QUIT] [CX_PRIORITY=<n>]",10,0
TTPri:          dc.b "CX_PRIORITY",0
PrefsCmd:       dc.b "SYS:Prefs/AmiSnipPrefs",0
LabelFmt:       dc.b " %ld x %ld ",0
NameFmt:        dc.b "AmiSnip_%03ld.%s",0
CmdFmt:         dc.b 34,"%s",34," ",34,"%s",34,0
TDir:           dc.b "T:",0
ExtIFF:         dc.b "iff",0
ExtPNG:         dc.b "png",0
ExtJPG:         dc.b "jpg",0
ExtBMP:         dc.b "bmp",0
ExtGIF:         dc.b "gif",0
ExtIFFDot:      dc.b ".iff",0
ExtILBMDot:     dc.b ".ilbm",0
ExtPNGDot:      dc.b ".png",0
ExtJPGDot:      dc.b ".jpg",0
ExtJPEGDot:     dc.b ".jpeg",0
ExtBMPDot:      dc.b ".bmp",0
ExtGIFDot:      dc.b ".gif",0
GifSig:         dc.b "GIF89a"
JpgHead:        dc.b $FF,$D8,$FF,$E0,0,16,"JFIF",0,1,1,0,0,1,0,1,0,0
JPGHEADLEN      equ *-JpgHead
JpgSOF:         dc.b $FF,$C0,0,17,8
                dc.b 3,1,$11,0,2,$11,1,3,$11,1
JpgSOS:         dc.b $FF,$DA,0,12,3,1,$00,2,$11,3,$11,0,63,0
PopTitle:       dc.b "AmiSnip",0
AslTitle:       dc.b "Save capture as",0
PL_Clip:        dc.b "_Copy to clipboard",0
PL_Save:        dc.b "_Save as...",0
PL_Cancel:      dc.b "Back",0
PL_CycW:        dc.b "MMM Format: JPEG",0
FC0:            dc.b "Format: IFF",0
FC1:            dc.b "Format: PNG",0
FC2:            dc.b "Format: JPEG",0
FC3:            dc.b "Format: BMP",0
FC4:            dc.b "Format: GIF",0
OpenPrefix:     dc.b "_Open in ",0
        even

        include "prefs_data.i"
        include "tables.i"

;=====================================================================
        section bss,bss
;=====================================================================
        cnop    0,4
SysBase:        ds.l 1
MyTask:         ds.l 1
WBMsg:          ds.l 1
RetCode:        ds.l 1
RDArgs:         ds.l 1
ArgArray:       ds.l 2
DiskObj:        ds.l 1
QuitFlag:       ds.l 1
CxPri:          ds.l 1
CxPort:         ds.l 1
CxSigMask:      ds.l 1
Broker:         ds.l 1
Filter:         ds.l 1
PubPort:        ds.l 1
NotifyMask:     ds.l 1
NotifyOn:       ds.l 1
FileReq:        ds.l 1
NotifyReq:      ds.l 12
NotifySig:      ds.b 2
CurHotkey:      ds.b HOTKEYLEN
        cnop    0,4
Prefs:          ds.b PREFSIZE
PrefsTmp:       ds.b PREFSIZE

; cleared for every capture
CapVars:
Scr:            ds.l 1
ScrW:           ds.l 1
ScrH:           ds.l 1
SrcRP:          ds.l 1
SrcBM:          ds.l 1
ColorMap:       ds.l 1
ModeID:         ds.l 1
SrcDepth:       ds.l 1
IsRGB:          ds.l 1
NDepth:         ds.l 1
NumColors:      ds.l 1
SaveColors:     ds.l 1
PlaneMask:      ds.l 1
IsHAM:          ds.l 1
IsEHB:          ds.l 1
CanDim:         ds.l 1
FrameRGB:       ds.l 1
FrameCol:       ds.l 1
DarkCol:        ds.l 1
LblAPen:        ds.l 1
LblBPen:        ds.l 1
BrightBM:       ds.l 1
DimBM:          ds.l 1
TmpBM:          ds.l 1
OrigRGB:        ds.l 1
DimRGB:         ds.l 1
Chunky:         ds.l 1
RawBuf:         ds.l 1
OutBuf:         ds.l 1
OutSize:        ds.l 1
RGBSize:        ds.l 1
CloneMode:      ds.l 1
CloneDepth:     ds.l 1
CloneScr:       ds.l 1
Win:            ds.l 1
WinRP:          ds.l 1
State:          ds.l 1
SelValid:       ds.l 1
DrawnValid:     ds.l 1
LblValid:       ds.l 1
Dirty:          ds.l 1
Moved:          ds.l 1
Edges:          ds.l 1
MsgSecs:        ds.l 1
MsgMicros:      ds.l 1
LastSecs:       ds.l 1
LastMicros:     ds.l 1
OutAction:      ds.l 1
OutOK:          ds.l 1
FileFmt:        ds.l 1
PopFmt:         ds.l 1
ExplFmt:        ds.l 1
IdxBuf:         ds.l 1
RGBOwn:         ds.l 1
CropX:          ds.l 1
CropY:          ds.l 1
CropW:          ds.l 1
CropH:          ds.l 1
CropBase:       ds.l 1
Stride:         ds.l 1
RowBytes:       ds.l 1
ILPlanes:       ds.l 1
ILCmap:         ds.l 1
ILBody:         ds.l 1
PRowLen:        ds.l 1
RawSize:        ds.l 1
ZLen:           ds.l 1
AdlerVal:       ds.l 1
ChunkStart:     ds.l 1
Sel:            ds.w 4
Drawn:          ds.w 4
Lbl:            ds.w 4
TmpD:           ds.w 4
Coords:         ds.w 6
MX:             ds.w 1
MY:             ds.w 1
AnchorX:        ds.w 1
AnchorY:        ds.w 1
OffX:           ds.w 1
OffY:           ds.w 1
CapVarsEnd:

; floating menu
PopChoice:      ds.l 1
PopCyc:         ds.l 1
PopWin:         ds.l 1
GList:          ds.l 1
VisInfo:        ds.l 1
PopTA:          ds.l 1
FontH:          ds.l 1
BtnW:           ds.l 1
BtnH:           ds.l 1
BordL:          ds.l 1
BordT:          ds.l 1
PopW:           ds.l 1
PopH:           ds.l 1
NG:             ds.b 30
OpenLabel:      ds.b 64

        cnop    0,4
; encoders
RGBBuf:         ds.l 1
RGBStride:      ds.l 1
HasIdx:         ds.l 1
HamCnt:         ds.l 1
PrevRow:        ds.l 1
BestSum:        ds.l 1
BestType:       ds.l 1
BestPtr:        ds.l 1
FiltBuf:        ds.l 1
ZBuf:           ds.l 1
HeadTab:        ds.l 1
PrevTab:        ds.l 1
DLen:           ds.l 1
DOut:           ds.l 1
DMaxL:          ds.l 1
DHash:          ds.l 1
OutEnd:         ds.l 1
JBx:            ds.l 1
JBy:            ds.l 1
GIdx:           ds.l 1
LZBuf:          ds.l 1
GHtab:          ds.l 1
GCtab:          ds.l 1
GPix:           ds.l 1
GSrc:           ds.l 1
GNCol:          ds.l 1
GBits:          ds.l 1
GMcs:           ds.l 1
LZLen:          ds.l 1
GTabN:          ds.l 1
GInit:          ds.l 1
GNBits:         ds.l 1
GMaxCode:       ds.l 1
GClear:         ds.l 1
GEOF:           ds.l 1
GFree:          ds.l 1
GClrFlg:        ds.l 1
JPred:          ds.w 4
JQL:            ds.w 64
JQC:            ds.w 64
JY:             ds.w 64
JCb:            ds.w 64
JCr:            ds.w 64
JTmp:           ds.w 64
JCoef:          ds.w 64
JZZ:            ds.w 64
GPal:           ds.b 768
        cnop    0,4
FmtArgs:        ds.l 2
RowPtrs:        ds.l 8
TmpRP:          ds.b 100
LabelBuf:       ds.b 32
FileNameBuf:    ds.b 64
PathBuf:        ds.b 304
CmdBuf:         ds.b 600
        cnop    0,4
CrcTable:       ds.l 256
DimTable:       ds.b 256
Pal:            ds.l 256*3
Colors32:       ds.l 1+256*3+1
