;=====================================================================
; Shared prefs code (needs: DosBase, Prefs, PrefsTmp, DefPrefs,
; EnvPrefsName, ArcPrefsName)
;=====================================================================

; Defaults, then ENV:, then ENVARC:
LoadPrefs:
        movem.l d2-d4/a2/a6,-(sp)
        bsr     DefaultPrefs
        lea     EnvPrefsName,a0
        bsr     ReadPrefsFile
        tst.l   d0
        bne.s   .ok
        lea     ArcPrefsName,a0
        bsr     ReadPrefsFile
.ok:    movem.l (sp)+,d2-d4/a2/a6
        rts

DefaultPrefs:
        lea     DefPrefs,a0
        lea     Prefs,a1
        move.w  #PREFSIZE/4-1,d0
.c:     move.l  (a0)+,(a1)+
        dbra    d0,.c
        rts

; a0 = file name -> d0 = 1 if read and valid
ReadPrefsFile:
        movem.l d2-d5/a2/a6,-(sp)
        move.l  DosBase,a6
        move.l  a0,d1
        move.l  #MODE_OLDFILE,d2
        CALL    Open
        move.l  d0,d5
        beq     .fail
        move.l  d5,d1
        move.l  #PrefsTmp,d2
        move.l  #PREFSIZE,d3
        CALL    Read
        move.l  d0,d4
        move.l  d5,d1
        CALL    Close
        cmp.l   #PREFSIZE,d4
        bne     .fail
        lea     PrefsTmp,a0
        cmp.l   #PREFS_MAGIC,P_Magic(a0)
        bne     .fail
        cmp.l   #PREFS_VERSION,P_Version(a0)
        bne     .fail
        clr.b   P_Hotkey+HOTKEYLEN-1(a0)
        clr.b   P_SaveDir+PATHLEN-1(a0)
        clr.b   P_Viewer+PATHLEN-1(a0)
        cmp.b   #4,P_Format(a0)
        bls.s   .v1
        clr.b   P_Format(a0)
.v1:    cmp.b   #3,P_Action(a0)
        bls.s   .v2
        clr.b   P_Action(a0)
.v2:    cmp.b   #3,P_Dim(a0)
        bls.s   .v3
        move.b  #2,P_Dim(a0)
.v3:    cmp.b   #4,P_Color(a0)
        bls.s   .v4
        clr.b   P_Color(a0)
.v4:    move.b  P_JpegQ(a0),d0
        bne.s   .v5
        move.b  #85,P_JpegQ(a0)         ; files from 1.1
.v5:    cmp.b   #100,P_JpegQ(a0)
        bls.s   .v6
        move.b  #100,P_JpegQ(a0)
.v6:    cmp.b   #10,P_JpegQ(a0)
        bcc.s   .v7
        move.b  #10,P_JpegQ(a0)
.v7:    lea     PrefsTmp,a0
        lea     Prefs,a1
        move.w  #PREFSIZE/4-1,d0
.c:     move.l  (a0)+,(a1)+
        dbra    d0,.c
        moveq   #1,d0
        bra.s   .ret
.fail:  moveq   #0,d0
.ret:   movem.l (sp)+,d2-d5/a2/a6
        rts
