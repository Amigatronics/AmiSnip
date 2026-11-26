;=====================================================================
; Shared prefs data (default values and file names)
;=====================================================================
        cnop    0,4
DefPrefs:
        dc.l    PREFS_MAGIC,PREFS_VERSION
        dc.b    1                       ; enabled
        dc.b    0                       ; format ILBM
        dc.b    0                       ; action: show menu
        dc.b    2                       ; dim medium
        dc.b    0                       ; frame white
        dc.b    0                       ; no beep
        dc.b    85                      ; JPEG quality
        dc.b    0
.hk:    dc.b    "lcommand shift s",0
        dcb.b   HOTKEYLEN-(*-.hk),0
.sd:    dc.b    "RAM:",0
        dcb.b   PATHLEN-(*-.sd),0
.vw:    dc.b    "SYS:Utilities/MultiView",0
        dcb.b   PATHLEN-(*-.vw),0
DefPrefsEnd:

DefHotkey       equ DefPrefs+P_Hotkey

EnvPrefsName:   dc.b "ENV:AmiSnip.prefs",0
ArcPrefsName:   dc.b "ENVARC:AmiSnip.prefs",0
        even
