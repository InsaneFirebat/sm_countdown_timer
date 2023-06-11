
; This patch adds a countdown timer to Super Metroid (NTSC)
; The credits will play when the timer reaches zero
; Only one save file is supported at a time. Starting a new file will reset the timer

lorom

; macros
macro a8() ; A = 8-bit
    SEP #$20
endmacro

macro a16() ; A = 16-bit
    REP #$20
endmacro

macro i8() ; X/Y = 8-bit
    SEP #$10
endmacro

macro i16() ; X/Y = 16-bit
    REP #$10
endmacro

macro ai8() ; A + X/Y = 8-bit
    SEP #$30
endmacro

macro ai16() ; A + X/Y = 16-bit
    REP #$30
endmacro


; - defines
!FREESPACE = $80D000 ; can live anywhere in banks $80-BF
!COUNTDOWN_MAX = 180 ; 1-999 mins for starting countdown timer
!MENU_SCROLL_DELAY = 3 ; frames between inc/dec when input held
!ram_controller_new = $8F
!ram_controller = $8B
!sram_timer_frames = $702000
!sram_timer_seconds = $702002
!sram_timer_minutes = $702004
!ram_tilemap_buffer = $7E5800
!ram_HUD_seconds = $09EC
!ram_HUD_minutes = $09EE
!ram_temp = $09F0
!ram_input_delay = $09F2
!ram_init_minutes = $09F4
!HUD_TILEMAP = $7EC606
!HUD_COLON = $0C58
!HUD_BLANK = $2C0F
!HUD_ZERO = $0C09


; - hijacks
; set SRAM size to 64k
org $00FFD8
    db $05 ; 64kb

; Skip SRAM mapping check
org $808000
    dw $0001

; Skip intro
org $82EEDF
    LDA #$C100

; hijack minimap initialization
org $809AF3
    JSL Start_Game_Hijack

; hijack HUD routine during gameplay
org $809590
    JML NMI_Hijack
NMI_Hijack_Return:

; hijack HUD routine during gameplay
org $828BA0
    JSL HUD_Hijack

; hijack HUD routine while paused
org $8290F6
    JSL HUD_Hijack

; hijack Icon Cancel in title menu
org $82F071
    JSL Icon_Cancel_Hijack
    NOP

; add a colon to HUD graphics, $10 bytes
org $9AB780
incbin colon_HUD.bin


; - free space code/data
org !FREESPACE
print pc, " start of freespace usage"

Start_Game_Hijack:
{
    ; check if loading Ceres or Zebes
    LDA $0998 : CMP #$0006 : BEQ .done

    ; Ceres, init timers for new game
    LDA #$000A : STA !sram_timer_frames
    LDA #$0001 : STA !sram_timer_seconds
    LDA #$FFFF : STA !ram_HUD_seconds
    LDA !ram_init_minutes : BNE +
    LDA #$001E ; default = 30m
+   STA !sram_timer_minutes

  .done
    ; overwritten code
    JML $90A8EF
}

NMI_Hijack:
{
    ; count timers
    LDA !sram_timer_frames : DEC : STA !sram_timer_frames : BPL .done
    LDA #$003B : STA !sram_timer_frames
    LDA !sram_timer_seconds : DEC : STA !sram_timer_seconds : BPL .done
    LDA #$003B : STA !sram_timer_seconds
    LDA !sram_timer_minutes : DEC : STA !sram_timer_minutes

  .done
    JML NMI_Hijack_Return
}

HUD_Hijack:
{
    ; check if time is up
    LDA !sram_timer_minutes : BMI .endgame
    ORA !sram_timer_seconds : ORA !sram_timer_frames : BEQ .endgame

  .recheckMinutes
    ; update minutes
    LDA !sram_timer_minutes : CMP !ram_HUD_minutes : BEQ .updateSeconds
    STA !ram_HUD_minutes
    LDX #$00AA : JSR Draw_Minutes
    LDA #!HUD_COLON : STA !HUD_TILEMAP+$AE

  .updateSeconds
    LDA !sram_timer_seconds : CMP !ram_HUD_seconds : BEQ .checkColon
    STA !ram_HUD_seconds
    LDX #$00B0 : JSR Draw_Seconds

  .checkColon
    LDA !HUD_TILEMAP+$AE : CMP #!HUD_COLON : BEQ .endHUDupdate
    LDA #$FFFF : STA !ram_HUD_minutes : STA !ram_HUD_seconds
    BRA .recheckMinutes

  .endHUDupdate
    JML $809B44 ; Handle HUD tilemap

  .endgame
    LDA $0998 : CMP #$0026 : BEQ .drawRed

    ; set game state to 26h to load credits
    LDA #$0026 : STA $0998

    ; Queue music stop
    LDA #$0000 : JSL $808FC1
    ; Cancel sound effects
    STZ $05F5 : JSL $82BE17

  .drawRed
    ; draw red/orange timer during last frames of fade out
    LDA #!HUD_ZERO|$1000
    STA !HUD_TILEMAP+$AC : STA !HUD_TILEMAP+$B2 : STA !HUD_TILEMAP+$B0
    LDA #!HUD_COLON|$1000 : STA !HUD_TILEMAP+$AE
    JML $809B44 ; Handle HUD tilemap
}

Draw_Minutes:
{
    STA $4204
    %a8()

    ; divide by 10
    LDA #$0A : STA $4206
    %a16()
    PEA $0000 : PLA ; wait for CPU math
    LDA $4214 : STA !ram_temp ; tens

    ; Ones digit
    LDA $4216 : ASL : TAX
    LDA.l NumberGFXTable,X : STA !HUD_TILEMAP+$AC

    LDA !ram_temp : BEQ .blankTens
    STA $4204
    %a8()

    ; divide by 10
    LDA #$0A : STA $4206
    %a16()
    PEA $0000 : PLA ; wait for CPU math
    LDA $4214 : STA !ram_temp ; hundreds

    ; Tens digit
    LDA $4216 : ASL : TAX
    LDA.l NumberGFXTable,X : STA !HUD_TILEMAP+$AA

    ; Hundreds digit
    LDA !ram_temp : BEQ .blankHundreds : ASL : TAX
    LDA.l NumberGFXTable,X : STA !HUD_TILEMAP+$A8

  .done
    RTS

  .blankTens
    LDA #!HUD_BLANK : STA !HUD_TILEMAP+$A8 : STA !HUD_TILEMAP+$AA
    RTS

  .blankHundreds
    LDA #!HUD_BLANK : STA !HUD_TILEMAP+$A8
    RTS
}

Draw_Seconds:
{
    STA $4204
    %a8()
    ; divide by 10
    LDA #$0A : STA $4206
    %a16()
    PEA $0000 : PLA ; wait for CPU math
    LDA $4214 : STA !ram_temp ; tens

    ; Ones digit
    LDA $4216 : ASL : TAX
    LDA.l NumberGFXTable,X : STA !HUD_TILEMAP+$B2

    ; Tens digit
    LDA !ram_temp : BEQ .zeroTens : ASL : TAX
    LDA.l NumberGFXTable,X : STA !HUD_TILEMAP+$B0
    RTS

  .zeroTens
    LDA #!HUD_ZERO : STA !HUD_TILEMAP+$B0
    RTS
}

Icon_Cancel_Hijack:
{
    ; Check if we activated menu
    LDA !ram_controller_new : BIT #$1380 : BEQ .return
    LDA $099E : BEQ .menu ; ignore if Moon Walk / End

  .return
    LDA !ram_controller_new : BIT #$1380
    RTL

  .menu
    ; setup tilemap before enabling BG3
    JSR Setup_Tilemap

    ; Setup registers
    %a8()
    STZ $420C
    LDA #$80 : STA $802100 ; enable forced blanking
    LDA #$09 : STA $2105 ; enable BG3 priority
    LDA #$07 : STA $212C ; enable BG3, disable OAM
    LDA #$0F : STA $0F2100 ; disable forced blanking
    %a16()

    ; Setup menu ram
    LDA #$000E : STA !ram_input_delay

    JSR Menu_Loop

    ; restore registers
    %a8()
    LDA #$80 : STA $802100 ; enable forced blanking
    LDA #$01 : STA $2105 ; disable BG3 priority
    LDA #$13 : STA $212C ; disable BG3, enable OAM
    LDA #$0F : STA $0F2100 ; disable forced blanking
    %a16()

    JSR Restore_Tilemap

    ; return zero to keep Icon Cancel disabled
    LDA #$0000
    RTL
}

Setup_Tilemap:
{
    ; start by clearing entire tilemap
    LDA #$2C0F : JSR Draw_Tilemap

    ; draw initial value
    LDA !ram_init_minutes : BNE +
    LDA #$001E : STA !ram_init_minutes
+   JSR Draw_Minutes_Menu
    
    ; tilemap transfer of $80 bytes (two lines)
    JSR Trasfer_Tilemap
    RTS
}

Restore_Tilemap:
{
    LDA #$184E : JSR Draw_Tilemap

    JSR Trasfer_Tilemap
    RTS
}

Draw_Tilemap:
{
    LDX #$007E
  .write_loop
    STA !ram_tilemap_buffer,X
    STA !ram_tilemap_buffer+$80,X
    STA !ram_tilemap_buffer+$100,X
    STA !ram_tilemap_buffer+$180,X
    STA !ram_tilemap_buffer+$200,X
    STA !ram_tilemap_buffer+$280,X
    STA !ram_tilemap_buffer+$300,X
    STA !ram_tilemap_buffer+$380,X
    STA !ram_tilemap_buffer+$400,X
    STA !ram_tilemap_buffer+$480,X
    STA !ram_tilemap_buffer+$500,X
    STA !ram_tilemap_buffer+$580,X
    STA !ram_tilemap_buffer+$600,X
    STA !ram_tilemap_buffer+$680,X
    STA !ram_tilemap_buffer+$700,X
    STA !ram_tilemap_buffer+$780,X
    DEX #2 : BPL .write_loop
    RTS
}

Trasfer_Tilemap:
{
    JSR Wait_for_NMI

    %i8()
    LDX #$80 : STX $2100 ; enable forced blanking
    LDA #$5C00 : STA $2116 ; VRAM addr
    LDA #$1801 : STA $4310 ; VRAM write
    LDA.w #!ram_tilemap_buffer : STA $4312 ; src addr
    LDA.w #!ram_tilemap_buffer>>16 : STA $4314 ; src bank
    LDA #$0800 : STA $4315 ; size
    STZ $4317 : STZ $4319 ; clear HDMA registers
    LDX #$80 : STX $2115 ; INC mode
    LDX #$02 : STX $420B ; enable DMA, channel 1
    LDX #$0F : STX $2100 ; disable forced blanking
    %ai16()
    RTS
}

Wait_for_NMI:
{
    %a8()
    LDA $05B8
-   CMP $05B8 : BEQ -
    %ai16()
    RTS
}

Menu_Loop:
{
    JSR Wait_for_NMI

    LDA !ram_input_delay : BEQ .read_inputs
    DEC : STA !ram_input_delay
    BRA Menu_Loop

  .read_inputs
    JSL $809459 ; Read controller input
    LDA !ram_controller : BIT #$0900 : BNE .up_right
    BIT #$0600 : BNE .down_left
    BIT #$8080 : BEQ Menu_Loop

    ; exit
    RTS

  .up_right
    LDA.w #!MENU_SCROLL_DELAY : STA !ram_input_delay
    LDA !ram_init_minutes : INC : STA !ram_init_minutes
    CMP.w #!COUNTDOWN_MAX+1 : BMI .draw
    LDA #$0001 : STA !ram_init_minutes
    BRA .draw

  .down_left
    LDA.w #!MENU_SCROLL_DELAY : STA !ram_input_delay
    LDA !ram_init_minutes : DEC : STA !ram_init_minutes
    BEQ + : BPL .draw
+   LDA.w #!COUNTDOWN_MAX : STA !ram_init_minutes

  .draw
    JSR Draw_Minutes_Menu
    JSR Trasfer_Tilemap
    BRA Menu_Loop
}

Draw_Minutes_Menu:
{
    STA $4204
    %a8()

    ; divide by 10
    LDA #$0A : STA $4206
    %a16()
    PEA $0000 : PLA ; wait for CPU math
    LDA $4214 : STA !ram_temp ; tens

    ; Ones digit
    LDA $4216 : ASL : TAX
    LDA.l NumberGFXTable,X : STA !ram_tilemap_buffer+$2A0

    LDA !ram_temp : BEQ .blankTens
    STA $4204
    %a8()

    ; divide by 10
    LDA #$0A : STA $4206
    %a16()
    PEA $0000 : PLA ; wait for CPU math
    LDA $4214 : STA !ram_temp ; hundreds

    ; Tens digit
    LDA $4216 : ASL : TAX
    LDA.l NumberGFXTable,X : STA !ram_tilemap_buffer+$29E

    ; Hundreds digit
    LDA !ram_temp : BEQ .blankHundreds : ASL : TAX
    LDA.l NumberGFXTable,X : STA !ram_tilemap_buffer+$29C

  .done
    RTS

  .blankTens
    LDA #!HUD_BLANK : STA !ram_tilemap_buffer+$29C : STA !ram_tilemap_buffer+$29E
    RTS

  .blankHundreds
    LDA #!HUD_BLANK : STA !ram_tilemap_buffer+$29C
    RTS
}

NumberGFXTable:
    dw #$2C09, #$2C00, #$2C01, #$2C02, #$2C03, #$2C04, #$2C05, #$2C06, #$2C07, #$2C08

print pc, " end of freespace usage"
