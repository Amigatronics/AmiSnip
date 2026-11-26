;=====================================================================
; AmiSnip image encoders: PNG (deflate), JPEG, BMP, GIF
;
; Input prepared by PrepSource:
;   RGBBuf/RGBStride  24-bit crop (always)
;   IdxBuf            palette indices (native screens, not HAM), HasIdx=1
; Output: OutBuf/OutSize
;=====================================================================

;---------------------------------------------------------------------
; Build the chunky/RGB views of the crop.  d0 = 1 ok
PrepSource:
        movem.l d2-d7/a2-a6,-(sp)
        clr.l   HasIdx
        tst.l   IsRGB
        beq     .planar
        move.l  CropBase,RGBBuf
        move.l  Stride,RGBStride
        bra     .ok
.planar:
        move.l  CropW,d0
        move.l  CropH,d1
        bsr     Mul32
        move.l  d0,d2
        move.l  SysBase,a6
        moveq   #0,d1
        CALL    AllocVec
        move.l  d0,IdxBuf
        beq     .fail
        move.l  d2,d0
        add.l   d2,d0
        add.l   d2,d0
        moveq   #0,d1
        CALL    AllocVec
        move.l  d0,RGBOwn
        beq     .fail
        move.l  d0,RGBBuf
        move.l  CropW,d0
        mulu.w  #3,d0
        move.l  d0,RGBStride
        ; planes -> chunky values
        move.l  IdxBuf,a5
        move.l  TmpBM,a3
        lea     RowPtrs,a2
        moveq   #0,d7
.pr:    moveq   #0,d0
        move.w  (a3),d0
        mulu.w  d7,d0
        moveq   #0,d1
.rp:    move.w  d1,d2
        lsl.w   #2,d2
        move.l  8(a3,d2.w),a0
        add.l   d0,a0
        move.l  a0,(a2,d2.w)
        addq.l  #1,d1
        cmp.l   NDepth,d1
        blt     .rp
        moveq   #0,d3
.px:    move.l  d3,d4
        lsr.l   #3,d4
        move.w  d3,d5
        not.w   d5
        and.w   #7,d5
        moveq   #0,d0
        move.l  NDepth,d2
        subq.w  #1,d2
.pp:    add.b   d0,d0
        move.w  d2,d1
        lsl.w   #2,d1
        move.l  (a2,d1.w),a0
        btst    d5,(a0,d4.l)
        beq     .pz
        addq.b  #1,d0
.pz:    dbra    d2,.pp
        move.b  d0,(a5)+
        addq.l  #1,d3
        cmp.l   CropW,d3
        blt     .px
        addq.l  #1,d7
        cmp.l   CropH,d7
        blt     .pr
        ; chunky -> RGB
        move.l  IdxBuf,a0
        move.l  RGBOwn,a1
        lea     Pal,a2
        tst.l   IsHAM
        bne     .ham
        move.l  #1,HasIdx
        move.l  CropW,d0
        move.l  CropH,d1
        bsr     Mul32
        move.l  d0,d1
.ex:    moveq   #0,d0
        move.b  (a0)+,d0
        mulu.w  #12,d0
        lea     (a2,d0.l),a3
        move.b  (a3),(a1)+
        move.b  4(a3),(a1)+
        move.b  8(a3),(a1)+
        subq.l  #1,d1
        bne     .ex
        bra     .ok
.ham:   ; HAM6/HAM8 decode
        move.l  NDepth,d6
        subq.l  #2,d6                   ; data bits
        moveq   #1,d5
        lsl.l   d6,d5
        subq.l  #1,d5                   ; data mask
        move.l  CropH,d7
        subq.l  #1,d7
.hrow:  move.b  (a2),d2                 ; colour 0 starts every line
        move.b  4(a2),d3
        move.b  8(a2),d4
        move.l  CropW,HamCnt
.hpx:   moveq   #0,d0
        move.b  (a0)+,d0
        moveq   #0,d1
        move.b  d0,d1
        and.l   d5,d1                   ; d1 = data
        lsr.l   d6,d0                   ; d0 = control
        bne     .hmod
        mulu.w  #12,d1
        lea     (a2,d1.l),a3
        move.b  (a3),d2
        move.b  4(a3),d3
        move.b  8(a3),d4
        bra     .hst
.hmod:  cmp.l   #4,d6
        bne     .h8
        mulu.w  #17,d1                  ; 4 bits -> 8 bits
        bra     .hv
.h8:    move.l  d0,-(sp)                ; 6 bits -> 8 bits
        move.w  d1,d0
        lsr.w   #4,d0
        lsl.w   #2,d1
        or.w    d0,d1
        move.l  (sp)+,d0
.hv:    cmp.b   #1,d0
        bne     .hr
        move.b  d1,d4                   ; blue
        bra     .hst
.hr:    cmp.b   #2,d0
        bne     .hg
        move.b  d1,d2                   ; red
        bra     .hst
.hg:    move.b  d1,d3                   ; green
.hst:   move.b  d2,(a1)+
        move.b  d3,(a1)+
        move.b  d4,(a1)+
        subq.l  #1,HamCnt
        bne     .hpx
        subq.l  #1,d7
        bpl     .hrow
.ok:    moveq   #1,d0
        bra     .ret
.fail:  moveq   #0,d0
.ret:   movem.l (sp)+,d2-d7/a2-a6
        rts

; little-endian helpers (a5 = output)
PutLE32:
        move.b  d0,(a5)+
        lsr.l   #8,d0
        move.b  d0,(a5)+
        lsr.l   #8,d0
        move.b  d0,(a5)+
        lsr.l   #8,d0
        move.b  d0,(a5)+
        rts
PutLE16:
        move.b  d0,(a5)+
        lsr.w   #8,d0
        move.b  d0,(a5)+
        rts

; d0 = bytes -> AllocVec into d0 (MEMF_ANY); a6 trashed
Alloc:  move.l  SysBase,a6
        moveq   #0,d1
        CALL    AllocVec
        rts
AllocClear:
        move.l  SysBase,a6
        move.l  #$10000,d1
        CALL    AllocVec
        rts
; a1 = memory (or 0)
Free:   move.l  a1,d0
        beq     .x
        move.l  SysBase,a6
        CALL    FreeVec
.x:     rts

;=====================================================================
; PNG with deflate (LZ77 + fixed Huffman) and adaptive filters
;=====================================================================
BuildPNG:
        movem.l d2-d7/a2-a5,-(sp)
        bsr     FreeOut
        clr.l   RawBuf
        clr.l   ZBuf
        clr.l   FiltBuf
        move.l  CropW,d0
        tst.l   HasIdx
        bne     .p1
        mulu.w  #3,d0
.p1:    move.l  d0,PRowLen
        addq.l  #1,d0
        move.l  CropH,d1
        bsr     Mul32
        move.l  d0,RawSize
        bsr     Alloc
        move.l  d0,RawBuf
        beq     .fail
        move.l  d0,a5
        tst.l   HasIdx
        beq     .rgb
        ; indexed rows, filter None
        move.l  IdxBuf,a0
        move.l  CropH,d7
        subq.l  #1,d7
.ir:    clr.b   (a5)+
        move.l  CropW,d0
.ic:    move.b  (a0)+,(a5)+
        subq.l  #1,d0
        bne     .ic
        dbra    d7,.ir
        bra     .filled
.rgb:   ; work rows: Sub, Up, Paeth, zero row
        move.l  PRowLen,d0
        lsl.l   #2,d0
        bsr     AllocClear
        move.l  d0,FiltBuf
        beq     .fail
        move.l  RGBBuf,a3               ; current row
        move.l  FiltBuf,a4
        move.l  PRowLen,d0
        add.l   d0,a4
        add.l   d0,a4
        add.l   d0,a4                   ; a4 = zero row (previous of row 0)
        move.l  a4,PrevRow
        moveq   #0,d7
.row:   bsr     FilterRow               ; -> d0 filter, a0 bytes
        move.b  d0,(a5)+
        move.l  PRowLen,d1
.cp:    move.b  (a0)+,(a5)+
        subq.l  #1,d1
        bne     .cp
        move.l  a3,PrevRow
        add.l   RGBStride,a3
        addq.l  #1,d7
        cmp.l   CropH,d7
        blt     .row
.filled:
        move.l  RawBuf,a0
        move.l  RawSize,d0
        bsr     Adler32
        move.l  d0,AdlerVal
        move.l  RawSize,d0
        move.l  d0,d1
        lsr.l   #3,d1
        add.l   d1,d0
        add.l   #1024,d0
        bsr     Alloc
        move.l  d0,ZBuf
        beq     .fail
        move.l  RawBuf,a0
        move.l  RawSize,d0
        move.l  ZBuf,a1
        bsr     Deflate
        move.l  d0,ZLen
        beq     .fail
        move.l  RawBuf,a1
        bsr     Free
        clr.l   RawBuf
        move.l  ZLen,d0
        add.l   #8+25+12+2+4+12,d0
        tst.l   HasIdx
        beq     .nopl
        move.l  NumColors,d1
        mulu.w  #3,d1
        add.l   #12,d1
        add.l   d1,d0
.nopl:  move.l  d0,OutSize
        bsr     Alloc
        move.l  d0,OutBuf
        beq     .fail
        move.l  d0,a5
        move.l  #$89504E47,d0
        bsr     PutL
        move.l  #$0D0A1A0A,d0
        bsr     PutL
        move.l  #'IHDR',d0
        bsr     BeginChunk
        move.l  CropW,d0
        bsr     PutL
        move.l  CropH,d0
        bsr     PutL
        move.b  #8,(a5)+
        moveq   #2,d0
        tst.l   HasIdx
        beq     .ct
        moveq   #3,d0
.ct:    move.b  d0,(a5)+
        clr.b   (a5)+
        clr.b   (a5)+
        clr.b   (a5)+
        bsr     EndChunk
        tst.l   HasIdx
        beq     .idat
        move.l  #'PLTE',d0
        bsr     BeginChunk
        lea     Pal,a0
        move.l  NumColors,d1
        subq.w  #1,d1
.pc:    move.b  (a0),(a5)+
        move.b  4(a0),(a5)+
        move.b  8(a0),(a5)+
        lea     12(a0),a0
        dbra    d1,.pc
        bsr     EndChunk
.idat:  move.l  #'IDAT',d0
        bsr     BeginChunk
        move.b  #$78,(a5)+
        move.b  #$9C,(a5)+
        move.l  ZBuf,a0
        move.l  ZLen,d0
.zc:    move.b  (a0)+,(a5)+
        subq.l  #1,d0
        bne     .zc
        move.l  AdlerVal,d0
        bsr     PutL
        bsr     EndChunk
        move.l  #'IEND',d0
        bsr     BeginChunk
        bsr     EndChunk
        moveq   #1,d0
        bra     .ret
.fail:  moveq   #0,d0
.ret:   move.l  d0,-(sp)
        move.l  RawBuf,a1
        bsr     Free
        clr.l   RawBuf
        move.l  ZBuf,a1
        bsr     Free
        clr.l   ZBuf
        move.l  FiltBuf,a1
        bsr     Free
        clr.l   FiltBuf
        move.l  (sp)+,d0
        movem.l (sp)+,d2-d7/a2-a5
        rts

; a3 = current row, PrevRow = previous row (RGB, 3 bytes per pixel)
; -> d0 = best filter type, a0 = filtered bytes (or a3 for None)
FilterRow:
        movem.l d1-d7/a1-a2/a4-a5,-(sp)
        move.l  PRowLen,d7
        ; None
        move.l  a3,a0
        move.l  d7,d1
        moveq   #0,d5
.n:     move.b  (a0)+,d0
        ext.w   d0
        bpl     .n1
        neg.w   d0
.n1:    ext.l   d0
        add.l   d0,d5
        subq.l  #1,d1
        bne     .n
        move.l  d5,BestSum
        clr.l   BestType
        move.l  a3,BestPtr
        ; Sub
        move.l  FiltBuf,a1
        move.l  a3,a0
        moveq   #0,d6                   ; index
        moveq   #0,d5
.s:     move.b  (a0,d6.l),d0
        cmp.l   #3,d6
        blt     .s1
        sub.b   -3(a0,d6.l),d0
.s1:    move.b  d0,(a1,d6.l)
        ext.w   d0
        bpl     .s2
        neg.w   d0
.s2:    ext.l   d0
        add.l   d0,d5
        addq.l  #1,d6
        cmp.l   d7,d6
        blt     .s
        moveq   #1,d0
        bsr     .best
        ; Up
        move.l  FiltBuf,a1
        add.l   d7,a1
        move.l  a3,a0
        move.l  PrevRow,a2
        moveq   #0,d6
        moveq   #0,d5
.u:     move.b  (a0,d6.l),d0
        sub.b   (a2,d6.l),d0
        move.b  d0,(a1,d6.l)
        ext.w   d0
        bpl     .u2
        neg.w   d0
.u2:    ext.l   d0
        add.l   d0,d5
        addq.l  #1,d6
        cmp.l   d7,d6
        blt     .u
        moveq   #2,d0
        bsr     .best
        ; Paeth
        move.l  FiltBuf,a1
        add.l   d7,a1
        add.l   d7,a1
        move.l  a3,a0
        move.l  PrevRow,a2
        moveq   #0,d6
        moveq   #0,d5
.p:     moveq   #0,d1                   ; a
        moveq   #0,d3                   ; c
        cmp.l   #3,d6
        blt     .p0
        move.b  -3(a0,d6.l),d1
        move.b  -3(a2,d6.l),d3
.p0:    moveq   #0,d2
        move.b  (a2,d6.l),d2            ; b
        move.w  d2,d0                   ; pa = |b - c|
        sub.w   d3,d0
        bpl     .pa
        neg.w   d0
.pa:    move.w  d1,d4                   ; pb = |a - c|
        sub.w   d3,d4
        bpl     .pb
        neg.w   d4
.pb:    move.l  d5,-(sp)
        move.w  d1,d5                   ; pc = |a + b - 2c|
        add.w   d2,d5
        sub.w   d3,d5
        sub.w   d3,d5
        bpl     .pc
        neg.w   d5
.pc:    cmp.w   d4,d0                   ; pa <= pb && pa <= pc -> a
        bgt     .nb
        cmp.w   d5,d0
        bgt     .nb
        move.b  d1,d0
        bra     .pr
.nb:    cmp.w   d5,d4                   ; pb <= pc -> b, else c
        bgt     .nc
        move.b  d2,d0
        bra     .pr
.nc:    move.b  d3,d0
.pr:    move.l  (sp)+,d5
        move.b  (a0,d6.l),d4
        sub.b   d0,d4
        move.b  d4,(a1,d6.l)
        ext.w   d4
        bpl     .p2
        neg.w   d4
.p2:    ext.l   d4
        add.l   d4,d5
        addq.l  #1,d6
        cmp.l   d7,d6
        blt     .p
        moveq   #4,d0
        bsr     .best
        move.l  BestType,d0
        move.l  BestPtr,a0
        movem.l (sp)+,d1-d7/a1-a2/a4-a5
        rts
.best:  cmp.l   BestSum,d5
        bcc     .bx
        move.l  d5,BestSum
        move.l  d0,BestType
        move.l  a1,BestPtr
.bx:    rts

;---------------------------------------------------------------------
; Deflate: a0 = source, d0 = length, a1 = destination
; -> d0 = compressed size (0 = failure)
; Registers in the loop: a2 src, a3 head, a4 prev, a5 out,
;                        d5 pos, d6 bit buffer, d7 bit count
Deflate:
        movem.l d2-d7/a2-a6,-(sp)
        move.l  a0,a2
        move.l  d0,DLen
        move.l  a1,DOut
        move.l  #32768*4,d0
        bsr     Alloc
        move.l  d0,HeadTab
        beq     .fail
        move.l  #32768*4,d0
        bsr     Alloc
        move.l  d0,PrevTab
        beq     .fail
        move.l  HeadTab,a3
        move.l  PrevTab,a4
        move.l  a3,a0
        move.w  #32768-1,d0
.ih:    move.l  #-1,(a0)+
        dbra    d0,.ih
        move.l  DOut,a5
        moveq   #0,d6
        moveq   #0,d7
        moveq   #3,d0                   ; BFINAL=1, BTYPE=01 (fixed)
        moveq   #3,d1
        bsr     PutBits
        moveq   #0,d5
.loop:  move.l  DLen,d0
        sub.l   d5,d0
        ble     .end
        cmp.l   #3,d0
        blt     .lit
        cmp.l   #258,d0
        bls     .ml
        move.l  #258,d0
.ml:    move.l  d0,DMaxL
        move.l  d5,d0
        bsr     Hash                    ; d0 = h*4
        move.l  d0,DHash
        move.l  (a3,d0.l),d1            ; candidate
        moveq   #0,d3                   ; best length
        moveq   #0,d4                   ; best distance
        moveq   #32,d2                  ; chain depth
.chain: tst.l   d1
        bmi     .cdone
        move.l  d5,d0
        sub.l   d1,d0
        ble     .cdone
        cmp.l   #32768,d0
        bhi     .cdone
        lea     (a2,d1.l),a0
        lea     (a2,d5.l),a1
        move.b  (a0,d3.l),d0
        cmp.b   (a1,d3.l),d0
        bne     .nextc
        moveq   #0,d0
.cmp:   cmp.l   DMaxL,d0
        bcc     .cend
        cmpm.b  (a0)+,(a1)+
        bne     .cend
        addq.l  #1,d0
        bra     .cmp
.cend:  cmp.l   d3,d0
        ble     .nextc
        move.l  d0,d3
        move.l  d5,d4
        sub.l   d1,d4
        cmp.l   DMaxL,d3
        beq     .cdone
.nextc: move.l  d1,d0
        and.l   #$7FFF,d0
        lsl.l   #2,d0
        move.l  (a4,d0.l),d0
        cmp.l   d1,d0
        bge     .cdone
        move.l  d0,d1
        subq.w  #1,d2
        bne     .chain
.cdone: move.l  DHash,d0
        move.l  d5,d1
        bsr     Insert
        cmp.l   #3,d3
        blt     .lit
        ; emit the match, hash the covered positions
        bsr     EmitMatch
        move.l  d5,d2
        add.l   d3,d5
        addq.l  #1,d2
.ins:   cmp.l   d5,d2
        bcc     .loop
        move.l  d2,d0
        addq.l  #2,d0
        cmp.l   DLen,d0
        bcc     .loop
        move.l  d2,d0
        bsr     Hash
        move.l  d2,d1
        bsr     Insert
        addq.l  #1,d2
        bra     .ins
.lit:   moveq   #0,d0
        move.b  (a2,d5.l),d0
        bsr     EmitSym
        addq.l  #1,d5
        bra     .loop
.end:   move.l  #256,d0
        bsr     EmitSym
        tst.w   d7
        beq     .fl
        move.b  d6,(a5)+
.fl:    move.l  a5,d0
        sub.l   DOut,d0
        bra     .ret
.fail:  moveq   #0,d0
.ret:   move.l  d0,-(sp)
        move.l  HeadTab,a1
        bsr     Free
        clr.l   HeadTab
        move.l  PrevTab,a1
        bsr     Free
        clr.l   PrevTab
        move.l  (sp)+,d0
        movem.l (sp)+,d2-d7/a2-a6
        rts

; d0 = position -> d0 = hash*4  (uses a2)
Hash:   movem.l d1-d2,-(sp)
        move.l  d0,d2
        moveq   #0,d0
        move.b  (a2,d2.l),d0
        lsl.l   #5,d0
        moveq   #0,d1
        move.b  1(a2,d2.l),d1
        eor.l   d1,d0
        lsl.l   #5,d0
        moveq   #0,d1
        move.b  2(a2,d2.l),d1
        eor.l   d1,d0
        and.l   #$7FFF,d0
        lsl.l   #2,d0
        movem.l (sp)+,d1-d2
        rts

; d0 = hash*4, d1 = position
Insert: move.l  d2,-(sp)
        move.l  (a3,d0.l),d2
        move.l  d1,(a3,d0.l)
        and.l   #$7FFF,d1
        lsl.l   #2,d1
        move.l  d2,(a4,d1.l)
        move.l  (sp)+,d2
        rts

; d0 = value, d1 = number of bits (LSB first)
PutBits:
        lsl.l   d7,d0
        or.l    d0,d6
        add.w   d1,d7
.fl:    cmp.w   #8,d7
        blt     .x
        move.b  d6,(a5)+
        lsr.l   #8,d6
        subq.w  #8,d7
        bra     .fl
.x:     rts

; d0 = literal/length symbol 0..287
EmitSym:
        lea     LitLen,a0
        moveq   #0,d1
        move.b  (a0,d0.w),d1
        add.w   d0,d0
        lea     LitCode,a0
        move.w  (a0,d0.w),d0
        and.l   #$FFFF,d0
        bra     PutBits

; d3 = length, d4 = distance
EmitMatch:
        movem.l d2-d4,-(sp)
        lea     LenSym,a0
        moveq   #0,d2
        move.b  (a0,d3.w),d2
        move.w  d2,d0
        add.w   #257,d0
        bsr     EmitSym
        lea     LenExtra,a0
        moveq   #0,d1
        move.b  (a0,d2.w),d1
        beq     .nole
        lea     LenBase,a0
        add.w   d2,d2
        move.l  d3,d0
        sub.w   (a0,d2.w),d0
        and.l   #$FFFF,d0
        bsr     PutBits
.nole:  move.l  d4,d0
        subq.l  #1,d0
        cmp.l   #512,d4
        bhi     .hi
        lea     DistLo,a0
        bra     .dc
.hi:    lsr.l   #7,d0
        lea     DistHi,a0
.dc:    moveq   #0,d2
        move.b  (a0,d0.w),d2
        lea     DistCode,a0
        moveq   #0,d0
        move.b  (a0,d2.w),d0
        moveq   #5,d1
        bsr     PutBits
        lea     DistExtra,a0
        moveq   #0,d1
        move.b  (a0,d2.w),d1
        beq     .x
        lea     DistBase,a0
        add.w   d2,d2
        move.l  d4,d0
        sub.w   (a0,d2.w),d0
        and.l   #$FFFF,d0
        bsr     PutBits
.x:     movem.l (sp)+,d2-d4
        rts

;=====================================================================
; JPEG (baseline, 4:4:4, standard Huffman tables)
;=====================================================================
BuildJPEG:
        movem.l d2-d7/a2-a6,-(sp)
        bsr     FreeOut
        ; quality -> scaled quantisation tables
        moveq   #0,d0
        move.b  Prefs+P_JpegQ,d0
        bne     .q1
        moveq   #85,d0
.q1:    cmp.w   #50,d0
        bcc     .q2
        move.l  #5000,d1
        divu.w  d0,d1
        and.l   #$FFFF,d1
        bra     .q3
.q2:    move.l  #200,d1
        sub.w   d0,d1
        sub.w   d0,d1
.q3:    lea     StdLumQ,a0
        lea     JQL,a1
        bsr     .scale
        lea     StdChrQ,a0
        lea     JQC,a1
        bsr     .scale
        ; output buffer
        move.l  CropW,d0
        move.l  CropH,d1
        bsr     Mul32
        lsl.l   #2,d0
        add.l   #8192,d0
        move.l  d0,d2
        bsr     Alloc
        move.l  d0,OutBuf
        beq     .fail
        move.l  d0,a5
        add.l   d2,d0
        sub.l   #600,d0
        move.l  d0,OutEnd
        ; headers
        lea     JpgHead,a0
        moveq   #JPGHEADLEN-1,d0
.h1:    move.b  (a0)+,(a5)+
        dbra    d0,.h1
        ; DQT
        move.b  #$FF,(a5)+
        move.b  #$DB,(a5)+
        move.b  #0,(a5)+
        move.b  #$84,(a5)+
        clr.b   (a5)+
        lea     JQL,a1
        bsr     .dqt
        move.b  #1,(a5)+
        lea     JQC,a1
        bsr     .dqt
        ; SOF0
        lea     JpgSOF,a0
        moveq   #5-1,d0
.h2:    move.b  (a0)+,(a5)+
        dbra    d0,.h2
        move.w  CropH+2,d0
        move.w  d0,d1
        lsr.w   #8,d1
        move.b  d1,(a5)+
        move.b  d0,(a5)+
        move.w  CropW+2,d0
        move.w  d0,d1
        lsr.w   #8,d1
        move.b  d1,(a5)+
        move.b  d0,(a5)+
        moveq   #10-1,d0
.h3:    move.b  (a0)+,(a5)+
        dbra    d0,.h3
        ; DHT
        lea     DHTSeg,a0
        move.w  #DHTSEGLEN-1,d0
.h4:    move.b  (a0)+,(a5)+
        dbra    d0,.h4
        ; SOS
        lea     JpgSOS,a0
        moveq   #14-1,d0
.h5:    move.b  (a0)+,(a5)+
        dbra    d0,.h5
        ; scan
        clr.l   JPred
        clr.w   JPred+4
        moveq   #0,d6
        moveq   #0,d7
        clr.l   JBy
.by:    clr.l   JBx
.bx:    bsr     LoadBlock
        lea     JY,a0
        lea     JQL,a1
        lea     JPred,a2
        lea     DCLCode,a3
        lea     ACLCode,a4
        bsr     EncodeBlock
        lea     JCb,a0
        lea     JQC,a1
        lea     JPred+2,a2
        lea     DCCCode,a3
        lea     ACCCode,a4
        bsr     EncodeBlock
        lea     JCr,a0
        lea     JQC,a1
        lea     JPred+4,a2
        lea     DCCCode,a3
        lea     ACCCode,a4
        bsr     EncodeBlock
        cmp.l   OutEnd,a5
        bcc     .fail
        addq.l  #8,JBx
        move.l  JBx,d0
        cmp.l   CropW,d0
        blt     .bx
        addq.l  #8,JBy
        move.l  JBy,d0
        cmp.l   CropH,d0
        blt     .by
        ; pad the last byte with 1s
        tst.w   d7
        beq     .eoi
        moveq   #8,d1
        sub.w   d7,d1
        moveq   #1,d0
        lsl.l   d1,d0
        subq.l  #1,d0                   ; d1 one-bits
        bsr     PutBitsJ
.eoi:   move.b  #$FF,(a5)+
        move.b  #$D9,(a5)+
        move.l  a5,d0
        sub.l   OutBuf,d0
        move.l  d0,OutSize
        moveq   #1,d0
        bra     .ret
.fail:  bsr     FreeOut
        moveq   #0,d0
.ret:   movem.l (sp)+,d2-d7/a2-a6
        rts
; a0 = standard table (bytes), a1 = words out, d1 = scale
.scale: moveq   #64-1,d3
.sc:    moveq   #0,d0
        move.b  (a0)+,d0
        mulu.w  d1,d0
        add.l   #50,d0
        divu.w  #100,d0
        and.l   #$FFFF,d0
        bne     .s1
        moveq   #1,d0
.s1:    cmp.w   #255,d0
        bls     .s2
        move.w  #255,d0
.s2:    move.w  d0,(a1)+
        dbra    d3,.sc
        rts
; a1 = quant table (natural order) -> 64 bytes in zigzag order
.dqt:   lea     ZigZag,a0
        moveq   #64-1,d3
.dq:    moveq   #0,d0
        move.b  (a0)+,d0
        add.w   d0,d0
        move.w  (a1,d0.w),d0
        move.b  d0,(a5)+
        dbra    d3,.dq
        rts

; 8x8 pixels at (JBx,JBy) -> JY, JCb, JCr (signed, centred)
LoadBlock:
        movem.l d2-d7/a2-a4,-(sp)
        lea     JY,a2
        lea     JCb,a3
        lea     JCr,a4
        moveq   #0,d6                   ; j
.j:     move.l  JBy,d0
        add.l   d6,d0
        cmp.l   CropH,d0
        blt     .y1
        move.l  CropH,d0
        subq.l  #1,d0
.y1:    move.l  RGBStride,d1
        bsr     Mul32
        add.l   RGBBuf,d0
        move.l  d0,a1                   ; row
        moveq   #0,d7                   ; i
.i:     move.l  JBx,d0
        add.l   d7,d0
        cmp.l   CropW,d0
        blt     .x1
        move.l  CropW,d0
        subq.l  #1,d0
.x1:    move.l  d0,d1
        add.l   d0,d0
        add.l   d1,d0
        lea     (a1,d0.l),a0
        moveq   #0,d2
        move.b  (a0)+,d2                ; R
        moveq   #0,d3
        move.b  (a0)+,d3                ; G
        moveq   #0,d4
        move.b  (a0),d4                 ; B
        ; Y
        move.l  d2,d0
        mulu.w  #19595,d0
        move.l  d3,d1
        mulu.w  #38470,d1
        add.l   d1,d0
        move.l  d4,d1
        mulu.w  #7471,d1
        add.l   d1,d0
        add.l   #32768,d0
        swap    d0
        sub.w   #128,d0
        move.w  d0,(a2)+
        ; Cb
        move.l  d2,d0
        muls.w  #-11059,d0
        move.l  d3,d1
        muls.w  #-21709,d1
        add.l   d1,d0
        move.l  d4,d1
        moveq   #15,d5
        lsl.l   d5,d1
        add.l   d1,d0
        add.l   #32768,d0
        swap    d0
        move.w  d0,(a3)+
        ; Cr
        move.l  d2,d0
        lsl.l   d5,d0
        move.l  d3,d1
        muls.w  #-27439,d1
        add.l   d1,d0
        move.l  d4,d1
        muls.w  #-5329,d1
        add.l   d1,d0
        add.l   #32768,d0
        swap    d0
        move.w  d0,(a4)+
        addq.l  #1,d7
        cmp.l   #8,d7
        blt     .i
        addq.l  #1,d6
        cmp.l   #8,d6
        blt     .j
        movem.l (sp)+,d2-d7/a2-a4
        rts

; a0 = samples (64 words), a1 = quant table, a2 = DC predictor,
; a3 = DC code table, a4 = AC code table.  Keeps a5/d6/d7 (bit writer).
EncodeBlock:
        movem.l d0-d5/a0-a4/a6,-(sp)
        ; forward DCT, pass 1 (rows) -> JTmp
        lea     DCTM,a6
        lea     JTmp,a1
        moveq   #0,d4                   ; y
.r1:    moveq   #0,d5                   ; u
.r2:    move.w  d5,d0
        lsl.w   #4,d0
        lea     (a6,d0.w),a2            ; DCTM row u
        move.w  d4,d0
        lsl.w   #4,d0
        lea     (a0,d0.w),a3            ; sample row y
        moveq   #0,d2
        moveq   #8-1,d3
.r3:    move.w  (a2)+,d0
        muls.w  (a3)+,d0
        add.l   d0,d2
        dbra    d3,.r3
        add.l   #256,d2
        asr.l   #8,d2
        asr.l   #1,d2
        move.w  d2,(a1)+
        addq.w  #1,d5
        cmp.w   #8,d5
        blt     .r2
        addq.w  #1,d4
        cmp.w   #8,d4
        blt     .r1
        ; pass 2 (columns) -> JCoef
        lea     JTmp,a3
        lea     JCoef,a1
        moveq   #0,d5                   ; v
.c1:    moveq   #0,d4                   ; u
.c2:    move.w  d5,d0
        lsl.w   #4,d0
        lea     (a6,d0.w),a2            ; DCTM row v
        move.w  d4,d0
        add.w   d0,d0
        lea     (a3,d0.w),a0            ; JTmp column u
        moveq   #0,d2
        moveq   #8-1,d3
.c3:    move.w  (a2)+,d0
        muls.w  (a0),d0
        add.l   d0,d2
        lea     16(a0),a0
        dbra    d3,.c3
        add.l   #16384,d2
        moveq   #15,d0
        asr.l   d0,d2
        move.w  d5,d0
        lsl.w   #3,d0
        add.w   d4,d0
        add.w   d0,d0
        move.w  d2,(a1,d0.w)
        addq.w  #1,d4
        cmp.w   #8,d4
        blt     .c2
        addq.w  #1,d5
        cmp.w   #8,d5
        blt     .c1
        ; quantise into zigzag order -> JZZ
        movem.l (sp),d0-d5/a0-a4        ; original arguments
        lea     JCoef,a0
        lea     ZigZag,a6
        lea     JZZ,a3
        moveq   #64-1,d3
.qz:    moveq   #0,d1
        move.b  (a6)+,d1
        add.w   d1,d1
        move.w  (a0,d1.w),d0            ; coefficient
        move.w  (a1,d1.w),d2            ; q
        move.w  d2,d4
        lsr.w   #1,d4
        tst.w   d0
        bmi     .neg
        and.l   #$FFFF,d0
        add.w   d4,d0
        divu.w  d2,d0
        bra     .qs
.neg:   neg.w   d0
        and.l   #$FFFF,d0
        add.w   d4,d0
        divu.w  d2,d0
        neg.w   d0
.qs:    move.w  d0,(a3)+
        dbra    d3,.qz
        ; Huffman
        movem.l (sp),d0-d5/a0-a4
        lea     JZZ,a0
        move.w  (a0),d0
        move.w  d0,d2
        sub.w   (a2),d0                 ; DC difference
        move.w  d2,(a2)
        move.l  a3,a6                   ; DC table
        moveq   #0,d4
        bsr     EmitCoef
        moveq   #1,d3                   ; k
        moveq   #0,d4                   ; zero run
.ac:    move.w  d3,d1
        add.w   d1,d1
        move.w  (a0,d1.w),d0
        bne     .nz
        addq.w  #1,d4
        bra     .acn
.nz:    cmp.w   #15,d4
        ble     .rl
        move.w  d0,-(sp)
        move.l  a4,a6
        move.w  #$F0,d0
        bsr     EmitSymJ
        move.w  (sp)+,d0
        sub.w   #16,d4
        bra     .nz
.rl:    move.l  a4,a6
        bsr     EmitCoef
        moveq   #0,d4
.acn:   addq.w  #1,d3
        cmp.w   #64,d3
        blt     .ac
        tst.w   d4
        beq     .done
        move.l  a4,a6
        moveq   #0,d0                   ; EOB
        bsr     EmitSymJ
.done:  movem.l (sp)+,d0-d5/a0-a4/a6
        rts


; d0 = value, d4 = zero run (AC) , a6 = table: emit (run<<4|size) + bits
EmitCoef:
        movem.l d2-d3,-(sp)
        move.w  d0,d2                   ; value
        move.w  d0,d3
        bpl     .p
        neg.w   d3
        subq.w  #1,d2                   ; negative: one's complement bits
.p:     moveq   #0,d1                   ; size
.sz:    tst.w   d3
        beq     .sd
        lsr.w   #1,d3
        addq.w  #1,d1
        bra     .sz
.sd:    move.w  d4,d0
        lsl.w   #4,d0
        add.w   d1,d0
        move.w  d1,-(sp)
        bsr     EmitSymJ
        move.w  (sp)+,d1
        tst.w   d1
        beq     .x
        moveq   #1,d0
        lsl.l   d1,d0
        subq.l  #1,d0
        and.w   d2,d0
        and.l   #$FFFF,d0
        bsr     PutBitsJ
.x:     movem.l (sp)+,d2-d3
        rts

; d0 = symbol, a6 = table (256 code words followed by 256 sizes)
EmitSymJ:
        move.l  a0,-(sp)
        and.l   #$FF,d0
        lea     512(a6),a0
        moveq   #0,d1
        move.b  (a0,d0.w),d1            ; size
        add.w   d0,d0
        move.w  (a6,d0.w),d0            ; code
        move.l  (sp)+,a0
        bra     PutBitsJ


; d0 = bits (right aligned), d1 = count; MSB first with FF stuffing
PutBitsJ:
        move.l  d2,-(sp)
        lsl.l   d1,d6
        or.l    d0,d6
        add.w   d1,d7
.l:     cmp.w   #8,d7
        blt     .x
        subq.w  #8,d7
        move.l  d6,d2
        lsr.l   d7,d2
        move.b  d2,(a5)+
        cmp.b   #$FF,d2
        bne     .l
        clr.b   (a5)+
        bra     .l
.x:     moveq   #1,d2
        lsl.l   d7,d2
        subq.l  #1,d2
        and.l   d2,d6                   ; keep only the pending bits
        move.l  (sp)+,d2
        rts

;=====================================================================
; BMP (8-bit indexed or 24-bit, bottom-up)
;=====================================================================
BuildBMP:
        movem.l d2-d7/a2-a5,-(sp)
        bsr     FreeOut
        tst.l   HasIdx
        beq     .t24
        move.l  CropW,d0
        moveq   #8,d5                   ; bpp
        move.l  NumColors,d4            ; colours
        bra     .rs
.t24:   move.l  CropW,d0
        mulu.w  #3,d0
        moveq   #24,d5
        moveq   #0,d4
.rs:    addq.l  #3,d0
        and.l   #-4,d0
        move.l  d0,d6                   ; padded row size
        move.l  CropH,d1
        bsr     Mul32
        move.l  d0,d7                   ; image size
        move.l  d4,d3
        lsl.l   #2,d3
        add.l   #54,d3                  ; offset to the pixels
        move.l  d3,d0
        add.l   d7,d0
        move.l  d0,OutSize
        bsr     Alloc
        move.l  d0,OutBuf
        beq     .fail
        move.l  d0,a5
        move.b  #'B',(a5)+
        move.b  #'M',(a5)+
        move.l  OutSize,d0
        bsr     PutLE32
        moveq   #0,d0
        bsr     PutLE32
        move.l  d3,d0
        bsr     PutLE32
        moveq   #40,d0
        bsr     PutLE32
        move.l  CropW,d0
        bsr     PutLE32
        move.l  CropH,d0
        bsr     PutLE32
        moveq   #1,d0
        bsr     PutLE16
        move.l  d5,d0
        bsr     PutLE16
        moveq   #0,d0
        bsr     PutLE32
        move.l  d7,d0
        bsr     PutLE32
        move.l  #2835,d0
        bsr     PutLE32
        move.l  #2835,d0
        bsr     PutLE32
        move.l  d4,d0
        bsr     PutLE32
        moveq   #0,d0
        bsr     PutLE32
        ; palette (B,G,R,0)
        tst.l   d4
        beq     .pix
        lea     Pal,a0
        move.l  d4,d0
        subq.w  #1,d0
.pl:    move.b  8(a0),(a5)+
        move.b  4(a0),(a5)+
        move.b  (a0),(a5)+
        clr.b   (a5)+
        lea     12(a0),a0
        dbra    d0,.pl
.pix:   move.l  CropH,d2
.row:   subq.l  #1,d2
        bmi     .ok
        move.l  a5,a4
        tst.l   HasIdx
        beq     .r24
        move.l  d2,d0
        move.l  CropW,d1
        bsr     Mul32
        move.l  IdxBuf,a0
        add.l   d0,a0
        move.l  CropW,d0
.c8:    move.b  (a0)+,(a5)+
        subq.l  #1,d0
        bne     .c8
        bra     .pad
.r24:   move.l  d2,d0
        move.l  RGBStride,d1
        bsr     Mul32
        move.l  RGBBuf,a0
        add.l   d0,a0
        move.l  CropW,d0
.c24:   move.b  2(a0),(a5)+
        move.b  1(a0),(a5)+
        move.b  (a0),(a5)+
        addq.l  #3,a0
        subq.l  #1,d0
        bne     .c24
.pad:   move.l  a5,d0
        sub.l   a4,d0
.pd:    cmp.l   d6,d0
        bcc     .row
        clr.b   (a5)+
        addq.l  #1,d0
        bra     .pd
.ok:    moveq   #1,d0
        bra     .ret
.fail:  moveq   #0,d0
.ret:   movem.l (sp)+,d2-d7/a2-a5
        rts

;=====================================================================
; GIF89a (LZW).  RGB sources: exact palette if <= 256 colours,
; otherwise a 6x7x6 colour cube with ordered dithering.
;=====================================================================
BuildGIF:
        movem.l d2-d7/a2-a6,-(sp)
        bsr     FreeOut
        clr.l   GIdx
        clr.l   LZBuf
        clr.l   GHtab
        clr.l   GCtab
        move.l  CropW,d0
        move.l  CropH,d1
        bsr     Mul32
        move.l  d0,GPix
        tst.l   HasIdx
        beq     .quant
        move.l  IdxBuf,GSrc
        move.l  NumColors,GNCol
        lea     Pal,a0
        lea     GPal,a1
        move.w  #256-1,d0
.cpal:  move.b  (a0),(a1)+
        move.b  4(a0),(a1)+
        move.b  8(a0),(a1)+
        lea     12(a0),a0
        dbra    d0,.cpal
        bra     .lzw
.quant: move.l  GPix,d0
        bsr     Alloc
        move.l  d0,GIdx
        beq     .fail
        move.l  d0,GSrc
        bsr     QuantExact
        tst.l   d0
        bne     .lzw
        bsr     QuantCube
.lzw:   ; bits for the palette
        moveq   #1,d0
.bt:    moveq   #1,d1
        lsl.l   d0,d1
        cmp.l   GNCol,d1
        bcc     .bd
        addq.l  #1,d0
        bra     .bt
.bd:    move.l  d0,GBits
        cmp.l   #2,d0
        bcc     .m2
        moveq   #2,d0
.m2:    move.l  d0,GMcs
        ; LZW into LZBuf
        move.l  GPix,d0
        move.l  d0,d1
        lsr.l   #1,d1
        add.l   d1,d0
        add.l   #1024,d0
        bsr     Alloc
        move.l  d0,LZBuf
        beq     .fail
        bsr     LZWEncode
        tst.l   d0
        beq     .fail
        move.l  d0,LZLen
        ; output
        moveq   #1,d1
        move.l  GBits,d0
        lsl.l   d0,d1
        move.l  d1,GTabN                ; table entries
        mulu.w  #3,d1
        add.l   #13+10+1+1+1+16,d1
        move.l  LZLen,d0
        add.l   d0,d1
        divu.w  #255,d0
        and.l   #$FFFF,d0
        add.l   d0,d1
        addq.l  #2,d1
        move.l  d1,d0
        bsr     Alloc
        move.l  d0,OutBuf
        beq     .fail
        move.l  d0,a5
        lea     GifSig,a0
        moveq   #6-1,d0
.sg:    move.b  (a0)+,(a5)+
        dbra    d0,.sg
        move.l  CropW,d0
        bsr     PutLE16
        move.l  CropH,d0
        bsr     PutLE16
        move.l  GBits,d0
        subq.l  #1,d0
        move.l  d0,d1
        lsl.b   #4,d1
        or.b    d1,d0
        or.b    #$80,d0
        move.b  d0,(a5)+
        clr.b   (a5)+
        clr.b   (a5)+
        lea     GPal,a0
        move.l  GTabN,d0
        mulu.w  #3,d0
        subq.w  #1,d0
        move.l  GNCol,d1
        mulu.w  #3,d1
.gp:    tst.l   d1
        beq     .gz
        move.b  (a0)+,(a5)+
        subq.l  #1,d1
        bra     .gn
.gz:    clr.b   (a5)+
.gn:    dbra    d0,.gp
        move.b  #$2C,(a5)+
        moveq   #0,d0
        bsr     PutLE16
        moveq   #0,d0
        bsr     PutLE16
        move.l  CropW,d0
        bsr     PutLE16
        move.l  CropH,d0
        bsr     PutLE16
        clr.b   (a5)+
        move.b  GMcs+3,(a5)+
        move.l  LZBuf,a0
        move.l  LZLen,d2
.blk:   move.l  d2,d0
        cmp.l   #255,d0
        bls     .bl
        move.l  #255,d0
.bl:    move.b  d0,(a5)+
        sub.l   d0,d2
        subq.w  #1,d0
.bc:    move.b  (a0)+,(a5)+
        dbra    d0,.bc
        tst.l   d2
        bne     .blk
        clr.b   (a5)+
        move.b  #$3B,(a5)+
        move.l  a5,d0
        sub.l   OutBuf,d0
        move.l  d0,OutSize
        moveq   #1,d0
        bra     .ret
.fail:  bsr     FreeOut
        moveq   #0,d0
.ret:   move.l  d0,-(sp)
        move.l  GIdx,a1
        bsr     Free
        clr.l   GIdx
        move.l  LZBuf,a1
        bsr     Free
        clr.l   LZBuf
        move.l  GHtab,a1
        bsr     Free
        clr.l   GHtab
        move.l  GCtab,a1
        bsr     Free
        clr.l   GCtab
        move.l  (sp)+,d0
        movem.l (sp)+,d2-d7/a2-a6
        rts

; exact palette (<= 256 colours) -> d0 = 1 ok
QuantExact:
        movem.l d2-d7/a2-a5,-(sp)
        move.l  #4096*4,d0
        bsr     AllocClear
        move.l  d0,GHtab
        beq     .no
        move.l  #4096,d0
        bsr     AllocClear
        move.l  d0,GCtab
        beq     .no
        move.l  GHtab,a3
        move.l  GCtab,a4
        lea     GPal,a2
        moveq   #0,d5                   ; colours found
        move.l  GSrc,a5
        moveq   #0,d7                   ; y
.y:     move.l  d7,d0
        move.l  RGBStride,d1
        bsr     Mul32
        add.l   RGBBuf,d0
        move.l  d0,a0
        move.l  CropW,d6
.x:     moveq   #0,d0
        move.b  (a0)+,d0
        swap    d0
        move.b  (a0)+,d1
        lsl.w   #8,d1
        move.b  (a0)+,d1
        move.w  d1,d0
        addq.l  #1,d0                   ; key (never 0)
        move.l  d0,d2
        move.l  d0,d3
        swap    d3
        eor.w   d3,d2
        move.l  d0,d3
        lsr.l   #7,d3
        eor.w   d3,d2
        and.w   #4095,d2
.pr:    move.w  d2,d3
        lsl.w   #2,d3
        move.l  (a3,d3.w),d1
        beq     .new
        cmp.l   d0,d1
        beq     .hit
        addq.w  #1,d2
        and.w   #4095,d2
        bra     .pr
.new:   cmp.w   #256,d5
        bcc     .no
        move.l  d0,(a3,d3.w)
        move.b  d5,(a4,d2.w)
        subq.l  #1,d0
        move.l  d0,d1
        swap    d1
        move.b  d1,(a2)+
        move.w  d0,d1
        lsr.w   #8,d1
        move.b  d1,(a2)+
        move.b  d0,(a2)+
        addq.w  #1,d5
.hit:   move.b  (a4,d2.w),(a5)+
        subq.l  #1,d6
        bne     .x
        addq.l  #1,d7
        cmp.l   CropH,d7
        blt     .y
        and.l   #$FFFF,d5
        move.l  d5,GNCol
        moveq   #1,d0
        bra     .ret
.no:    moveq   #0,d0
.ret:   move.l  d0,-(sp)
        move.l  GHtab,a1
        bsr     Free
        clr.l   GHtab
        move.l  GCtab,a1
        bsr     Free
        clr.l   GCtab
        move.l  (sp)+,d0
        movem.l (sp)+,d2-d7/a2-a5
        rts

; 6x7x6 cube with 4x4 ordered dither
QuantCube:
        movem.l d2-d7/a2-a5,-(sp)
        lea     GPal,a2
        moveq   #0,d2
.cr:    moveq   #0,d3
.cg:    moveq   #0,d4
.cb:    move.w  d2,d0
        mulu.w  #51,d0
        move.b  d0,(a2)+
        move.w  d3,d0
        mulu.w  #255,d0
        divu.w  #6,d0
        move.b  d0,(a2)+
        move.w  d4,d0
        mulu.w  #51,d0
        move.b  d0,(a2)+
        addq.w  #1,d4
        cmp.w   #6,d4
        blt     .cb
        addq.w  #1,d3
        cmp.w   #7,d3
        blt     .cg
        addq.w  #1,d2
        cmp.w   #6,d2
        blt     .cr
        move.l  #252,GNCol
        move.l  GSrc,a5
        moveq   #0,d7
.y:     move.l  d7,d0
        move.l  RGBStride,d1
        bsr     Mul32
        add.l   RGBBuf,d0
        move.l  d0,a0
        moveq   #0,d6                   ; x
.x:     move.w  d7,d0
        and.w   #3,d0
        lsl.w   #2,d0
        move.w  d6,d1
        and.w   #3,d1
        add.w   d1,d0
        lea     Bayer4,a1
        moveq   #0,d5
        move.b  (a1,d0.w),d5
        add.w   d5,d5
        sub.w   #15,d5                  ; -15..15
        moveq   #51,d1
        moveq   #5,d4
        bsr     .q
        mulu.w  #42,d0
        move.w  d0,d3
        moveq   #42,d1
        moveq   #6,d4
        bsr     .q
        mulu.w  #6,d0
        add.w   d0,d3
        moveq   #51,d1
        moveq   #5,d4
        bsr     .q
        add.w   d0,d3
        move.b  d3,(a5)+
        addq.l  #1,d6
        cmp.l   CropW,d6
        blt     .x
        addq.l  #1,d7
        cmp.l   CropH,d7
        blt     .y
        movem.l (sp)+,d2-d7/a2-a5
        rts
; next component from (a0)+ ; d1 = step, d4 = levels-1, d5 = dither
.q:     moveq   #0,d0
        move.b  (a0)+,d0
        move.w  d5,d2
        muls.w  d1,d2
        asr.w   #5,d2
        add.w   d2,d0
        bpl     .q1
        moveq   #0,d0
.q1:    cmp.w   #255,d0
        ble     .q2
        move.w  #255,d0
.q2:    mulu.w  d4,d0
        add.l   #127,d0
        divu.w  #255,d0
        and.l   #$FFFF,d0
        rts

; GSrc (GPix bytes) -> LZBuf ; d0 = length (0 = failure)
; classic GIF LZW (compress-style hashing, HSIZE 5003)
HSIZE   equ 5003
LZWEncode:
        movem.l d2-d7/a2-a6,-(sp)
        move.l  #HSIZE*4,d0
        bsr     Alloc
        move.l  d0,GHtab
        beq     .fail
        move.l  #HSIZE*2,d0
        bsr     Alloc
        move.l  d0,GCtab
        beq     .fail
        move.l  GHtab,a3
        move.l  GCtab,a4
        bsr     .clrhash
        move.l  LZBuf,a5
        moveq   #0,d6
        moveq   #0,d7
        move.l  GMcs,d0
        addq.l  #1,d0
        move.l  d0,GInit                ; init_bits
        move.l  d0,GNBits
        moveq   #1,d1
        lsl.l   d0,d1
        subq.l  #1,d1
        move.l  d1,GMaxCode
        moveq   #1,d1
        move.l  GMcs,d0
        lsl.l   d0,d1
        move.l  d1,GClear
        addq.l  #1,d1
        move.l  d1,GEOF
        addq.l  #1,d1
        move.l  d1,GFree
        clr.l   GClrFlg
        move.l  GClear,d0
        bsr     .out
        move.l  GSrc,a2
        move.l  GPix,d5
        moveq   #0,d4
        move.b  (a2)+,d4                ; ent
        subq.l  #1,d5
        beq     .end
.next:  moveq   #0,d3
        move.b  (a2)+,d3                ; c
        move.l  d3,d2
        moveq   #12,d0
        lsl.l   d0,d2
        add.l   d4,d2                   ; fcode
        move.l  d3,d1
        lsl.l   #4,d1
        eor.l   d4,d1                   ; i = (c << 4) ^ ent
        move.l  d1,d0
        lsl.l   #2,d0
        cmp.l   (a3,d0.l),d2
        beq     .found
        tst.l   (a3,d0.l)
        bmi     .nomatch
        move.l  #HSIZE,d0
        sub.l   d1,d0                   ; disp
        tst.l   d1
        bne     .probe
        moveq   #1,d0
.probe: sub.l   d0,d1
        bpl     .p1
        add.l   #HSIZE,d1
.p1:    move.l  d1,a0
        add.l   a0,a0
        add.l   a0,a0
        cmp.l   (a3,a0.l),d2
        beq     .found
        tst.l   (a3,a0.l)
        bpl     .probe
        bra     .nomatch
.found: move.l  d1,d0
        add.l   d0,d0
        moveq   #0,d4
        move.w  (a4,d0.l),d4
        bra     .cont
.nomatch:
        move.l  d4,d0
        bsr     .out
        move.l  d3,d4
        cmp.l   #4096,GFree
        bcc     .clblk
        move.l  d1,d0
        add.l   d0,d0
        move.w  GFree+2,(a4,d0.l)
        add.l   d0,d0
        move.l  d2,(a3,d0.l)
        addq.l  #1,GFree
        bra     .cont
.clblk: bsr     .clrhash
        move.l  GClear,d0
        addq.l  #2,d0
        move.l  d0,GFree
        move.l  #1,GClrFlg
        move.l  GClear,d0
        bsr     .out
.cont:  subq.l  #1,d5
        bne     .next
.end:   move.l  d4,d0
        bsr     .out
        move.l  GEOF,d0
        bsr     .out
        tst.w   d7
        beq     .fl
        move.b  d6,(a5)+
.fl:    move.l  a5,d0
        sub.l   LZBuf,d0
        bra     .ret
.fail:  moveq   #0,d0
.ret:   movem.l (sp)+,d2-d7/a2-a6
        rts
.clrhash:
        move.l  a3,a0
        move.w  #HSIZE-1,d0
.ch:    move.l  #-1,(a0)+
        dbra    d0,.ch
        rts
; output code d0 with GNBits, then adjust the code size
.out:   move.l  d1,-(sp)
        move.l  GNBits,d1
        bsr     PutBits
        tst.l   GClrFlg
        beq     .o1
        move.l  GInit,d0
        move.l  d0,GNBits
        moveq   #1,d1
        lsl.l   d0,d1
        subq.l  #1,d1
        move.l  d1,GMaxCode
        clr.l   GClrFlg
        bra     .ox
.o1:    move.l  GFree,d0
        cmp.l   GMaxCode,d0
        ble     .ox
        addq.l  #1,GNBits
        move.l  GNBits,d0
        cmp.l   #12,d0
        bne     .o2
        move.l  #4096,GMaxCode
        bra     .ox
.o2:    moveq   #1,d1
        lsl.l   d0,d1
        subq.l  #1,d1
        move.l  d1,GMaxCode
.ox:    move.l  (sp)+,d1
        rts
