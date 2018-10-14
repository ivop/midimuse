
; -----------------------------------------------------------------------------
;
; MIDIMON for the Atari 8-bit w/ MIDI Mate/Max compatible MIDI interface
;
; Public Domain 2017 by Ivo van Poorten
; Credit would be nice, though :)
;
; -----------------------------------------------------------------------------

COLOR0  = $02c4
COLOR1  = $02c5
COLOR2  = $02c6
COLOR3  = $02c7
COLOR4  = $02c8
SAVMSC  = $0058
SDLSTL  = $0230
RTCLOK  = $0012

; -----------------------------------------------------------------------------

    org $00e0

ptr .ds 2

; -----------------------------------------------------------------------------

; Reset and clear screen by closing and reopening E:ditor
; Set default color scheme

    org $2800

    close 0                     ; start fresh, with a clear screen
    open 0, 12, 0, "E:"
    mva #$0f COLOR1
    mva #$00 COLOR2
    mva #$00 COLOR4

    mwa SAVMSC scrmem           ; set our own display list with an extra line
    mwa #dlist SDLSTL           ; at the top; rest is E: handler

    lda RTCLOK+2
wait
    cmp RTCLOK+2
    beq wait

    rts

dlist
    dta $70, $42, a(extraline), $70, $42
scrmem
    dta a(0)
    :23 dta 2
    dta $41, a(dlist)

extraline
    .sb "ACTIVE SENSE: "
activesense
    .sb " "
endactivesense
    .sb "       "
    .sb "SYSTEM CLOCK: "
systemclock
    .sb "    "
endsystemclock

    org $02e2
    dta a($2800)

; -----------------------------------------------------------------------------

; Set font, left margin

    org $2c00

    ins "font.fnt"

    org $3000

    mva #0 LMARGN
    mva #$2c CHBAS
    rts

    org $02e2
    dta a($3000)

; -----------------------------------------------------------------------------

; Initialize M:IDI Handler
; Slightly patched to stay silent and have no delay at start up

    org $6000

handler
    ins "handler.mid",6,1090

    org $02e2
    dta a($6369)

; -----------------------------------------------------------------------------

    icl "cio.s"

LMARGN  = $0052
CHBAS   = $02f4

; -----------------------------------------------------------------------------

    org $3000

main
    print 0, down
    print 0, welcome

    close 1

    prints 0, "Opening MIDI Device" eol
    open 1, 13, 0, "M:"
    cpy #1
    beq openok

    prints 0, "Unable to open MIDI Device M:"
    jmp endl

openok
    prints 0, "Setting concurrent mode"
    xio 40, 1, 0, 0, "M:"
    cpy #1
    beq concurok

    prints 0, "Failed to set concurrent mode"
    jmp endl

concurok

sync
    lda skipfirstdot
    bne next

    mva #0 skipfirstdot

    printsn 0, "."          ; print dots while sync is lost

next
    bget 1, 1, onebyte
    lda onebyte
    bpl sync                ; first, sync to a command byte

nextnoread
loop
    lda onebyte
    and #$f0
    cmp #$80
    bne nonoteoff
    jmp noteoff

nonoteoff
    cmp #$90
    bne nonoteon

    mva onebyte previous
    jmp noteon

nonoteon
    cmp #$a0
    bne noaftertouch

    mva onebyte previous
    jmp aftertouch

noaftertouch
    cmp #$b0
    bne nocontroller

    mva onebyte previous
    jmp controller

nocontroller
    cmp #$c0
    bne nopatchchange

    mva onebyte previous
    jmp patchchange

nopatchchange
    cmp #$d0
    bne nopressure

    mva onebyte previous
    jmp pressure

nopressure
    cmp #$e0
    bne nopitchbend

    mva onebyte previous
    jmp pitchbend

nopitchbend
    jmp systemmessage

endl
    jmp endl

; -----------------------------------------------------------------------------

printchannel
    lda onebyte
    and #$0f
    asl:tax
    mwa channumtab,x channum
    bput 0, endchan-chan, chan
    rts

; -----------------------------------------------------------------------------

printnote
    lda midiaux1
    and #$7f
    :2 asl                  ; times four
    sta ptr
    lda #0
    adc #0                  ; carry bit into high byte
    sta ptr+1

    adw ptr #notetab

    ldy #0

    .rept 4
    mva (ptr),y+ notestr+#
    .endr

    bput 0, 4, notestr
    rts

; -----------------------------------------------------------------------------

printnum
printvelocity
printpressure
    lda midiaux2
    and #$7f
    sta midiaux2
    asl             ; multiply by 2
    sta ptr

    lda ptr
    add midiaux2    ; add once more (i.e. multiply by 3)
    sta ptr
    lda #0
    adc #0
    sta ptr+1

    adw ptr #numtab

    ldy #0

    .rept 3
    mva (ptr),y+ numstr+#
    .endr

    bput 0, 3, numstr
    rts

; -----------------------------------------------------------------------------

printnewline
    prints 0, " "
    rts

; -----------------------------------------------------------------------------

printcontroller
    lda midiaux2
    asl:tay
    ldx #0
    mva #CPBIN ICCOM,x
    mwa controllers,y ICBAL,x
    mwa controllers,y ptr
    ldy #0
findeol
    lda (ptr),y+
    cmp #eol
    bne findeol

    dey
    tya
    sta ICBLL,x
    mva #0 ICBLH,x

    jmp CIOV

; -----------------------------------------------------------------------------

printpatch
    lda midiaux2
    asl:tay
    ldx #0
    mva #CPTXT ICCOM,x
    mwa patches,y ICBAL,x
    mwa #127 ICBLL,x
    jmp CIOV

; -----------------------------------------------------------------------------

noteoff
    bget 1, 1, midiaux1

noteoffagain
    jsr printchannel
    printsn 0, "OFF  "

    jsr printnote

    bget 1, 1, midiaux2
    jsr printvelocity
    jsr printnewline

    bget 1, 1, midiaux1
    lda midiaux1
    jpl noteoffagain         ; same command, next note

    sta onebyte
    jmp nextnoread

; -----------------------------------------------------------------------------

noteon
    bget 1, 1, midiaux1

noteonagain
    jsr printchannel
    printsn 0, "ON  "

    jsr printnote

    bget 1, 1, midiaux2
    jsr printvelocity
    jsr printnewline

    bget 1, 1, midiaux1
    lda midiaux1
    jpl noteonagain          ; same command, next note

    sta onebyte
    jmp nextnoread

; -----------------------------------------------------------------------------

aftertouch
    bget 1, 1, midiaux1

aftertouchagain
    jsr printchannel
    prints 0, "AT  "

    jsr printnote

    bget 1, 1, midiaux2
    jsr printpressure
    jsr printnewline

    bget 1, 1, midiaux1
    lda midiaux1
    jpl aftertouchagain

    sta onebyte
    jmp nextnoread

; -----------------------------------------------------------------------------

controller
    bget 1, 1, midiaux2

controlleragain
    jsr printchannel

    jsr printcontroller
    printsn 0, " "

    bget 1, 1, midiaux2
    jsr printnum
    jsr printnewline

    bget 1, 1, midiaux2
    lda midiaux2
    jpl controlleragain

    sta onebyte
    jmp nextnoread

; -----------------------------------------------------------------------------

patchchange
    bget 1, 1, midiaux2

patchchangeagain
    jsr printchannel
    printsn 0, "PATCH "

    jsr printnum

    printsn 0, " "
    jsr printpatch
;    jsr printnewline

    bget 1, 1, midiaux2
    lda midiaux2
    jpl patchchangeagain

    sta onebyte
    jmp nextnoread

; -----------------------------------------------------------------------------

pressure
    bget 1, 1, midiaux2

pressureagain
    jsr printchannel
    printsn 0, "PRESS "

    jsr printnum
    jsr printnewline

    bget 1, 1, midiaux2
    lda midiaux2
    jpl pressureagain

    sta onebyte
    jmp nextnoread

; -----------------------------------------------------------------------------

pitchbend
    bget 1, 1, midiaux2

pitchbendagain
    jsr printchannel
    printsn 0,  "PITCH "

    jsr printnum

    bget 1, 1, midiaux2
    jsr printnum
    jsr printnewline

    bget 1, 1, midiaux2
    lda midiaux2
    jpl pitchbendagain

    sta onebyte
    jmp nextnoread

; -----------------------------------------------------------------------------

systemmessage
    lda onebyte
    cmp #$fe
    bne noactivesense

; show inverting space to indicate activity of FE events

    ldy #endactivesense-activesense-1
invert1
    lda activesense,y
    eor #$80
    sta activesense,y
    dey
    bpl invert1

    jmp next

noactivesense
    lda onebyte
    cmp #$f7
    bne noeox

    prints 0, "EOX"
    jmp next

noeox
    cmp #$f8
    jne noclock

; show four inverting spaces to indicate activity of F8 events
    ldy sysclkindex
invert2
    lda systemclock,y
    eor #$80
    sta systemclock,y
    dey
    bpl noreinit

    ldy #endsystemclock-systemclock-1
noreinit
    sty sysclkindex

; commands can continue after a clock (i.e. no new command byte w/ bit 7 set!)

    bget 1, 1, onebyte
    lda onebyte
    bpl continueprevious

    jmp nextnoread

continueprevious
    sta midiaux1
    sta midiaux2        ; we don't now where it expects it

    mva previous onebyte         ; !!!
    and #$f0
    cmp #$80
    jeq noteoffagain
    cmp #$90
    jeq noteonagain
    cmp #$a0
    jeq aftertouchagain
    cmp #$b0
    jeq controlleragain
    cmp #$c0
    jeq patchchangeagain
    cmp #$d0
    jeq pressureagain
    cmp #$e0
    jeq pitchbendagain

    jmp nextnoread

noclock
    cmp #$fa
    bne nostart

    prints 0, "START"
    jmp next

nostart
    cmp #$fb
    bne nocontinue

    prints 0, "CONTINUE"
    jmp next

nocontinue
    cmp #$fc
    bne nostop

    prints 0, "STOP"
    jmp next

nostop
    cmp #$ff
    bne noreset

    prints 0, "RESET"
    jmp next

noreset
    printsn 0, "SYS "

hexagain
    jsr bintohex
    bput 0, 2, hex

    bget 1, 1, onebyte
    lda onebyte
    bpl hexagain

    jsr printnewline

    jmp nextnoread

; -----------------------------------------------------------------------------

bintohex
    lda onebyte
    :4 lsr
    tax
    mva hextab,x hex
    lda onebyte
    and #$0f
    tax
    mva hextab,x hex+1
    rts

; -----------------------------------------------------------------------------

down
    .by 29 29 29 29 29 29 29 eol
welcome
    .by "MIDIMON v1.0 (C)2017 by Ivo van Poorten" eol

; -----------------------------------------------------------------------------

skipfirstdot
    .by 1

sysclkindex
    .by 3

previous
    .by $80
onebyte
    .by 0
midiaux1
    .by 0
midiaux2
    .by 0

hex
    .by "   "
    .by eol

hextab
    .by "0123456789ABCDEF"

channumtab
    .by " 1 2 3 4 5 6 7 8 910111213141516"

chan
    .by "CH "
channum
    .by "   "
endchan

; -----------------------------------------------------------------------------

notestr
    .by "    "
endnotestr

notetab
    .by "C0  C#0 D0  D#0 E0  F0  F#0 G0  G#0 A0  A#0 B0  "
    .by "C1  C#1 D1  D#1 E1  F1  F#1 G1  G#1 A1  A#1 B1  "
    .by "C2  C#2 D2  D#2 E2  F2  F#2 G2  G#2 A2  A#2 B2  "
    .by "C3  C#3 D3  D#3 E3  F3  F#3 G3  G#3 A3  A#3 B3  "
    .by "C4  C#4 D4  D#4 E4  F4  F#4 G4  G#4 A4  A#4 B4  "
    .by "C5  C#5 D5  D#5 E5  F5  F#5 G5  G#5 A5  A#5 B5  "
    .by "C6  C#6 D6  D#6 E6  F6  F#6 G6  G#6 A6  A#6 B6  "
    .by "C7  C#7 D7  D#7 E7  F7  F#7 G7  G#7 A7  A#7 B7  "
    .by "C8  C#8 D8  D#8 E8  F8  F#8 G8  G#8 A8  A#8 B8  "
    .by "C9  C#9 D9  D#9 E9  F9  F#9 G9  G#9 A9  A#9 B9  "
    .by "C10 C#10D10 D#10E10 F10 F#10G10 G#10A10 A#10B10 "

numstr
    .by "   "
endnumstr

numtab
    .by "  0  1  2  3  4  5  6  7  8  9"
    .by " 10 11 12 13 14 15 16 17 18 19"
    .by " 20 21 22 23 24 25 26 27 28 29"
    .by " 30 31 32 33 34 35 36 37 38 39"
    .by " 40 41 42 43 44 45 46 47 48 49"
    .by " 50 51 52 53 54 55 56 57 58 59"
    .by " 60 61 62 63 64 65 66 67 68 69"
    .by " 70 71 72 73 74 75 76 77 78 79"
    .by " 80 81 82 83 84 85 86 87 88 89"
    .by " 90 91 92 93 94 95 96 97 98 99"
    .by "100101102103104105106107108109"
    .by "110111112113114115116117118119"
    .by "120121122123124125126127"

controllers
    :128 dta a(ctrl:1)

; ctrl32-ctrl63 are the same as 0-31, but with LSB before it
; They say those are rarely implemented, but my Roland uses them :)

ctrl32  .by "LSB "          ; ctrl32-ctrl63 "fall through"
ctrl0   .by "Bank Select" eol
ctrl33  .by "LSB "
ctrl1   .by "Modulation Wheel" eol
ctrl34  .by "LSB "
ctrl2   .by "Breath Controller" eol

ctrl52
ctrl53
ctrl54
ctrl55
ctrl56
ctrl57
ctrl58
ctrl59
ctrl60
ctrl61
ctrl62
ctrl63
ctrl46
ctrl47
ctrl41
ctrl35  .by "LSB"
ctrl102
ctrl103
ctrl104
ctrl105
ctrl106
ctrl107
ctrl108
ctrl109
ctrl110
ctrl111
ctrl112
ctrl113
ctrl114
ctrl115
ctrl116
ctrl117
ctrl118
ctrl119
ctrl120
ctrl85
ctrl86
ctrl87
ctrl88
ctrl89
ctrl90
ctrl20
ctrl21
ctrl22
ctrl23
ctrl24
ctrl25
ctrl26
ctrl27
ctrl28
ctrl29
ctrl30
ctrl31
ctrl14
ctrl15
ctrl9
ctrl3   .by "Undefined" eol

ctrl36  .by "LSB "
ctrl4   .by "Foot Controller" eol
ctrl37  .by "LSB "
ctrl5   .by "Portamento Time" eol
ctrl38  .by "LSB "
ctrl6   .by "Data Entry MSB" eol
ctrl39  .by "LSB "
ctrl7   .by "Main Volume" eol
ctrl40  .by "LSB "
ctrl8   .by "Balance" eol
ctrl42  .by "LSB "
ctrl10  .by "Pan" eol
ctrl43  .by "LSB "
ctrl11  .by "Expression" eol
ctrl44  .by "LSB "
ctrl12  .by "Effect Control 1" eol
ctrl45  .by "LSB "
ctrl13  .by "Effect Control 2" eol
ctrl48  .by "LSB "
ctrl16  .by "Gen. Purpose 1" eol
ctrl49  .by "LSB "
ctrl17  .by "Gen. Purpose 2" eol
ctrl50  .by "LSB "
ctrl18  .by "Gen. Purpose 3" eol
ctrl51  .by "LSB "
ctrl19  .by "Gen. Purpose 4" eol

ctrl64  .by "Sustain" eol
ctrl65  .by "Portamento" eol
ctrl66  .by "Sostenuto" eol
ctrl67  .by "Soft Pedal" eol
ctrl68  .by "Legato Footswitch" eol
ctrl69  .by "Hold 2" eol
ctrl70  .by "SC1: Variation" eol
ctrl71  .by "SC2: Timbre" eol
ctrl72  .by "SC3: Release Time" eol
ctrl73  .by "SC4: Attack Time" eol
ctrl74  .by "SC5: Brightness" eol
ctrl75  .by "Sound Contr. 6" eol
ctrl76  .by "Sound Contr. 7" eol
ctrl77  .by "Sound Contr. 8" eol
ctrl78  .by "Sound Contr. 9" eol
ctrl79  .by "Sound Contr. 10" eol
ctrl80  .by "Gen. Purpose 5" eol
ctrl81  .by "Gen. Purpose 6" eol
ctrl82  .by "Gen. Purpose 7" eol
ctrl83  .by "Gen. Purpose 8" eol
ctrl84  .by "Portamento Control" eol
ctrl91  .by "FX1 Depth" eol
ctrl92  .by "FX2 Depth" eol
ctrl93  .by "FX3 Depth" eol
ctrl94  .by "FX4 Depth" eol
ctrl95  .by "FX5 Depth" eol
ctrl96  .by "Data Increment" eol
ctrl97  .by "Data Decrement" eol
ctrl98  .by "Non-Reg. Param. LSB" eol
ctrl99  .by "Non-Reg. Param. MSB" eol
ctrl100 .by "Reg. Param. LSB" eol
ctrl101 .by "Reg. Param. MSB" eol

; Channel Mode Messages

ctrl121 .by "Reset All Contr." eol
ctrl122 .by "Local Control" eol
ctrl123 .by "All Notes Off" eol
ctrl124 .by "Omni Off" eol
ctrl125 .by "Omni On" eol
ctrl126 .by "Mono On" eol
ctrl127 .by "Poly On" eol

; General MIDI Patches 0-127 bank 0

patches
    :128 dta a(pat:1)

pat0    .by "Acoustic Grand" eol
pat1    .by "Bright Acoustic" eol
pat2    .by "Electric Grand" eol
pat3    .by "Honky-Tonk" eol
pat4    .by "Electric Piano 1" eol
pat5    .by "Electric Piano 2" eol
pat6    .by "Harpsichord" eol
pat7    .by "Clav" eol
pat8    .by "Celesta" eol
pat9    .by "Glockenspiel" eol
pat10   .by "Music Box" eol
pat11   .by "Vibraphone" eol
pat12   .by "Marimba" eol
pat13   .by "Xylophone" eol
pat14   .by "Tubular Bells" eol
pat15   .by "Dulcimer" eol
pat16   .by "Drawbar Organ" eol
pat17   .by "Percussive Organ" eol
pat18   .by "Rock Organ" eol
pat19   .by "Church Organ" eol
pat20   .by "Reed Organ" eol
pat21   .by "Accordion" eol
pat22   .by "Harmonica" eol
pat23   .by "Bandoneon" eol
pat24   .by "Nylon Guitar" eol
pat25   .by "Steel Guitar" eol
pat26   .by "Jazz Guitar" eol
pat27   .by "Clean Guitar" eol
pat28   .by "Muted Guitar" eol
pat29   .by "Overdriven Guitar" eol
pat30   .by "Distortion Guitar" eol
pat31   .by "Guitar Harmonics" eol

pat32   .by "Acoustic Bass" eol
pat33   .by "Fingered Bass" eol
pat34   .by "Picked Bass" eol
pat35   .by "Fretless Bass" eol
pat36   .by "Slap Bass 1" eol
pat37   .by "Slap Bass 2" eol
pat38   .by "Synth Bass 1" eol
pat39   .by "Synth Bass 2" eol
pat40   .by "Violin" eol
pat41   .by "Viola" eol
pat42   .by "Cello" eol
pat43   .by "Contrabass" eol
pat44   .by "Tremelo Strings" eol
pat45   .by "Pizzicato Strings" eol
pat46   .by "Orchestral Harp" eol
pat47   .by "Timpani" eol
pat48   .by "String Ensemble 1" eol
pat49   .by "String Ensemble 2" eol
pat50   .by "Synth Strings 1" eol
pat51   .by "Synth Strings 2" eol
pat52   .by "Choir Aahs" eol
pat53   .by "Voice Oohs" eol
pat54   .by "Synth Voice" eol
pat55   .by "Orchestral Hit" eol
pat56   .by "Trumpet" eol
pat57   .by "Trombone" eol
pat58   .by "Tuba" eol
pat59   .by "Muted Trumpet" eol
pat60   .by "French Horn" eol
pat61   .by "Brass Section" eol
pat62   .by "Synth Brass 1" eol
pat63   .by "Synth Brass 2" eol

pat64   .by "Soprano Sax" eol
pat65   .by "Alto Sax" eol
pat66   .by "Tenor Sax" eol
pat67   .by "Baritone Sax" eol
pat68   .by "Oboe" eol
pat69   .by "English Horn" eol
pat70   .by "Bassoon" eol
pat71   .by "Clarinet" eol
pat72   .by "Piccolo" eol
pat73   .by "Flute" eol
pat74   .by "Recorder" eol
pat75   .by "Pan Flute" eol
pat76   .by "Blown Bottle" eol
pat77   .by "Shakuhachi" eol
pat78   .by "Whistle" eol
pat79   .by "Ocarina" eol
pat80   .by "Lead Square" eol
pat81   .by "Lead Saw" eol
pat82   .by "Lead Calliope" eol
pat83   .by "Lead Chiff" eol
pat84   .by "Lead Charang" eol
pat85   .by "Lead Voice" eol
pat86   .by "Lead Fifths" eol
pat87   .by "Lead Bass" eol
pat88   .by "Pad New Age" eol
pat89   .by "Pad Warm" eol
pat90   .by "Pad Polysynth" eol
pat91   .by "Pad Choir" eol
pat92   .by "Pad Bowed" eol
pat93   .by "Pad Metallic" eol
pat94   .by "Pad halo" eol
pat95   .by "Pad Sweep" eol

pat96   .by "FX Rain" eol
pat97   .by "FX Soundtrack" eol
pat98   .by "FX Crystal" eol
pat99   .by "FX Atmosphere" eol
pat100  .by "FX Brightness" eol
pat101  .by "FX Goblins" eol
pat102  .by "FX Echoes" eol
pat103  .by "FX Sci-Fi" eol
pat104  .by "Sitar" eol
pat105  .by "Banjo" eol
pat106  .by "Shamisen" eol
pat107  .by "Koto" eol
pat108  .by "Kalimba" eol
pat109  .by "Bagpipe" eol
pat110  .by "Fiddle" eol
pat111  .by "Shanai" eol
pat112  .by "Tinkle Bell" eol
pat113  .by "Agogo" eol
pat114  .by "Steel Drums" eol
pat115  .by "Woodblock" eol
pat116  .by "Taiko Drum" eol
pat117  .by "Melodic Tom" eol
pat118  .by "Synth Drum" eol
pat119  .by "Reverse Cymbal" eol
pat120  .by "Guitar Fret Noise" eol
pat121  .by "Breath Noise" eol
pat122  .by "Seashore" eol
pat123  .by "Birds" eol
pat124  .by "Telephone" eol
pat125  .by "Helicopter" eol
pat126  .by "Applause" eol
pat127  .by "Gunshot" eol

; -----------------------------------------------------------------------------

    org $02e0

    dta a(main)

