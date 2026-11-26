;=====================================================================
; Library offsets and constants shared by AmiSnip and AmiSnipPrefs
;=====================================================================

CALL    macro
        jsr     _LVO\1(a6)
        endm

;--------------------------------------------------------------- exec
_LVOForbid              equ -132
_LVOPermit              equ -138
_LVOFindTask            equ -294
_LVOWait                equ -318
_LVOSignal              equ -324
_LVOAllocSignal         equ -330
_LVOFreeSignal          equ -336
_LVOAddPort             equ -354
_LVORemPort             equ -360
_LVOGetMsg              equ -372
_LVOReplyMsg            equ -378
_LVOWaitPort            equ -384
_LVOFindPort            equ -390
_LVOCloseLibrary        equ -414
_LVOOpenDevice          equ -444
_LVOCloseDevice         equ -450
_LVODoIO                equ -456
_LVORawDoFmt            equ -522
_LVOOpenLibrary         equ -552
_LVOCreateIORequest     equ -654
_LVODeleteIORequest     equ -660
_LVOCreateMsgPort       equ -666
_LVODeleteMsgPort       equ -672
_LVOAllocVec            equ -684
_LVOFreeVec             equ -690
;---------------------------------------------------------------- dos
_LVOOpen                equ -30
_LVOClose               equ -36
_LVORead                equ -42
_LVOWrite               equ -48
_LVOLock                equ -84
_LVOUnLock              equ -90
_LVOCurrentDir          equ -126
_LVOSystemTagList       equ -606
_LVOReadArgs            equ -798
_LVOStrToLong           equ -816
_LVOFreeArgs            equ -858
_LVOFilePart            equ -870
_LVOPathPart            equ -876
_LVOAddPart             equ -882
_LVOStartNotify         equ -888
_LVOEndNotify           equ -894
_LVOPutStr              equ -948
;---------------------------------------------------------- intuition
_LVOClearMenuStrip      equ -54
_LVOCloseScreen         equ -66
_LVOCloseWindow         equ -72
_LVODisplayBeep         equ -96
_LVODoubleClick         equ -102
_LVOItemAddress         equ -144
_LVOScreenToFront       equ -252
_LVOSetMenuStrip        equ -264
_LVOLockIBase           equ -414
_LVOUnlockIBase         equ -420
_LVOActivateWindow      equ -450
_LVOLockPubScreen       equ -510
_LVOUnlockPubScreen     equ -516
_LVOOpenWindowTagList   equ -606
_LVOOpenScreenTagList   equ -612
_LVOGetScreenDrawInfo   equ -690
_LVOFreeScreenDrawInfo  equ -696
_LVOSetWindowPointerA   equ -816
;----------------------------------------------------------- graphics
_LVOBltBitMap           equ -30
_LVOTextLength          equ -54
_LVOText                equ -60
_LVOInitRastPort        equ -198
_LVOWaitBlit            equ -228
_LVOMove                equ -240
_LVORectFill            equ -306
_LVOSetAPen             equ -342
_LVOSetDrMd             equ -354
_LVOBltBitMapRastPort   equ -606
_LVOGetVPModeID         equ -792
_LVOObtainBestPenA      equ -840
_LVOSetABPenDrMd        equ -894
_LVOGetRGB32            equ -900
_LVOAllocBitMap         equ -918
_LVOFreeBitMap          equ -924
_LVOReleasePen          equ -948
_LVOGetBitMapAttr       equ -960
_LVOSetWriteMask        equ -984
_LVOBestModeIDA         equ -1050
_LVOWriteChunkyPixels   equ -1056
;-------------------------------------------------------- commodities
_LVOCreateCxObj         equ -30
_LVOCxBroker            equ -36
_LVOActivateCxObj       equ -42
_LVODeleteCxObjAll      equ -54
_LVOCxObjError          equ -66
_LVOClearCxObjError     equ -72
_LVOAttachCxObj         equ -84
_LVOSetFilter           equ -120
_LVOCxMsgType           equ -138
_LVOCxMsgID             equ -150
;--------------------------------------------------------------- icon
_LVOGetDiskObject       equ -78
_LVOFreeDiskObject      equ -90
_LVOFindToolType        equ -96
;----------------------------------------------------------- gadtools
_LVOCreateGadgetA       equ -30
_LVOFreeGadgets         equ -36
_LVOGT_SetGadgetAttrsA  equ -42
_LVOCreateMenusA        equ -48
_LVOFreeMenus           equ -54
_LVOLayoutMenusA        equ -66
_LVOGT_GetIMsg          equ -72
_LVOGT_ReplyIMsg        equ -78
_LVOGT_RefreshWindow    equ -84
_LVOGT_BeginRefresh     equ -90
_LVOGT_EndRefresh       equ -96
_LVOCreateContext       equ -114
_LVOGetVisualInfoA      equ -126
_LVOFreeVisualInfo      equ -132
;---------------------------------------------------------------- asl
_LVOAllocAslRequest     equ -48
_LVOFreeAslRequest      equ -54
_LVOAslRequest          equ -60
;------------------------------------------------------- cybergraphics
_LVOIsCyberModeID       equ -54
_LVOBestCModeIDTagList  equ -60
_LVOGetCyberMapAttr     equ -96
_LVOGetCyberIDAttr      equ -102
_LVOReadPixelArray      equ -120
_LVOWritePixelArray     equ -126
_LVOFillPixelArray      equ -150

;---------------------------------------------------------- constants
TAG_DONE                equ 0
SA_Width                equ $80000023
SA_Height               equ $80000024
SA_Depth                equ $80000025
SA_Type                 equ $8000002D
SA_DisplayID            equ $80000032
SA_ShowTitle            equ $80000036
SA_Behind               equ $80000037
SA_Quiet                equ $80000038
SA_AutoScroll           equ $80000039
SA_Pens                 equ $8000003A
SA_Draggable            equ $8000003E
SA_Colors32             equ $80000043
CUSTOMSCREEN            equ $000F

WA_Left                 equ $80000064
WA_Top                  equ $80000065
WA_Width                equ $80000066
WA_Height               equ $80000067
WA_IDCMP                equ $8000006A
WA_Flags                equ $8000006B
WA_Gadgets              equ $8000006C
WA_Title                equ $8000006E
WA_CustomScreen         equ $80000070
WA_InnerWidth           equ $80000076
WA_InnerHeight          equ $80000077
WA_PubScreen            equ $80000079
WA_AutoAdjust           equ $8000008F
WA_NewLookMenus         equ $80000092
WA_BusyPointer          equ $80000097

WFLG_DRAGBAR            equ $2
WFLG_DEPTHGADGET        equ $4
WFLG_CLOSEGADGET        equ $8
WFLG_ACTIVATE           equ $1000
WFLG_RMBTRAP            equ $10000

IDCMP_REFRESHWINDOW     equ $4
IDCMP_MOUSEBUTTONS      equ $8
IDCMP_MOUSEMOVE         equ $10
IDCMP_GADGETUP          equ $40
IDCMP_MENUPICK          equ $100
IDCMP_CLOSEWINDOW       equ $200
IDCMP_RAWKEY            equ $400
IDCMP_VANILLAKEY        equ $200000

GA_Disabled             equ $8003000E

BUTTON_KIND             equ 1
CHECKBOX_KIND           equ 2
CYCLE_KIND              equ 7
STRING_KIND             equ 12
PLACETEXT_LEFT          equ $1
PLACETEXT_RIGHT         equ $2
PLACETEXT_IN            equ $10
GTCB_Checked            equ $80080004
GTCY_Labels             equ $8008000E
GTCY_Active             equ $8008000F
GTST_String             equ $8008002D
GTST_MaxChars           equ $8008002E
GT_Underscore           equ $80080040
GTMN_NewLookMenus       equ $80080043
GTCB_Scaled             equ $80080044
GTSL_Min                equ $80080026
GTSL_Max                equ $80080027
GTSL_Level              equ $80080028
GTSL_MaxLevelLen        equ $80080029
GTSL_LevelFormat        equ $8008002A
GTSL_LevelPlace         equ $8008002B
GA_RelVerify            equ $80030016
SLIDER_KIND             equ 11
IDCMP_GADGETDOWN        equ $20
_LVOGT_GetGadgetAttrsA  equ -174

NM_END                  equ 0
NM_TITLE                equ 1
NM_ITEM                 equ 2
MENUNULL                equ $FFFF

ASLFR_TitleText         equ $80080001
ASLFR_Window            equ $80080002
ASLFR_InitialFile       equ $80080008
ASLFR_InitialDrawer     equ $80080009
ASLFR_Screen            equ $80080028
ASLFR_SleepWindow       equ $8008002B
ASLFR_DoSaveMode        equ $8008002C
ASLFR_DrawersOnly       equ $8008002F
ASLFR_RejectIcons       equ $8008003C

SYS_Input               equ $80000021
SYS_Output              equ $80000022
SYS_Asynch              equ $80000023
NP_StackSize            equ $800003F3

OBP_Precision           equ $84000000
PRECISION_IMAGE         equ 0

CYBRMATTR_DEPTH         equ $80000007
CYBRIDATTR_DEPTH        equ $80000004
CYBRBIDTG_Depth         equ $80050000
CYBRBIDTG_NominalWidth  equ $80050001
CYBRBIDTG_NominalHeight equ $80050002
BIDTAG_NominalWidth     equ $80000004
BIDTAG_NominalHeight    equ $80000005
BIDTAG_Depth            equ $80000008
RECTFMT_RGB             equ 0
RECTFMT_LUT8            equ 3

MODE_OLDFILE            equ 1005
MODE_NEWFILE            equ 1006
SHARED_LOCK             equ -2

;------------------------------------------------------------- prefs
; ENV:AmiSnip.prefs  (binary, PREFSIZE bytes)
P_Magic                 equ 0
P_Version               equ 4
P_Enabled               equ 8
P_Format                equ 9           ; 0 ILBM, 1 PNG, 2 JPEG, 3 BMP, 4 GIF
P_Action                equ 10          ; 0 menu, 1 clip, 2 save, 3 both
P_Dim                   equ 11          ; 0 none, 1 light, 2 medium, 3 strong
P_Color                 equ 12          ; 0 white,1 yellow,2 cyan,3 red,4 green
P_Beep                  equ 13
P_JpegQ                 equ 14          ; 10..100 (0 = 85)
P_Hotkey                equ 16
P_SaveDir               equ 96
P_Viewer                equ 352
PREFSIZE                equ 608
HOTKEYLEN               equ 80
PATHLEN                 equ 256
PREFS_MAGIC             equ 'ASNP'
PREFS_VERSION           equ 1
