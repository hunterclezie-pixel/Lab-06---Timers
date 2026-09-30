// Hunter Clezie
// RCET3375
// Lab6TimerPt3
// https://github.com/hunterclezie-pixel/Lab-06---Timers.git

; PIC16F883 Configuration Bit Settings

; Assembly source line config statements

; CONFIG1
  CONFIG  FOSC = XT             ; Oscillator Selection bits (XT oscillator: Crystal/resonator on RA6/OSC2/CLKOUT and RA7/OSC1/CLKIN)
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
  CONFIG  PWRTE = OFF           ; Power-up Timer Enable bit (PWRT disabled)
  CONFIG  MCLRE = ON            ; RE3/MCLR pin function select bit (RE3/MCLR pin function is MCLR)
  CONFIG  CP = OFF              ; Code Protection bit (Program memory code protection is disabled)
  CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)
  CONFIG  BOREN = OFF           ; Brown Out Reset Selection bits (BOR disabled)
  CONFIG  IESO = OFF            ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
  CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
  CONFIG  LVP = OFF             ; Low Voltage Programming Enable bit (RB3 pin has digital I/O, HV on MCLR must be used for programming)

; CONFIG2
  CONFIG  BOR4V = BOR40V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
  CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)

; config statements should precede project file includes.
#include <xc.inc>  
    ; General Purpose Registers
    W_TEMP EQU 0x70 ; Used as part of the temporary hold for save/restore
    STATUS_TEMP EQU 0x71 ; Used as part of the temporary hold for save/restore
    intersection_state  EQU 0x72 ; Complete packed intersection state
    count_temp EQU 0x73 ; Temporary STATE_COUNT value
    flags_temp EQU 0x74 ; Temporary lower state flags
 
; Reset Vector at 0000h. Execution starts here after reset.
PSECT resetVect,class=CODE,delta=2
ResetVector:
    goto Setup

; Interrupt Vector
PSECT isrVect,class=CODE,delta=2
InterruptVector:
    GOTO ISRHandler

; Main code section starts at 0008h. User code goes here.
PSECT code,class=CODE,delta=2
 
Setup:
    BCF 0x03,6      ; Sets Bank 0
    BCF 0x03,5      ; Sets Bank 0
    CLRF 0x06       ; Clearing PORTB
    CLRF 0x07       ; Clearing PORTC
    CLRF intersection_state ; Initial state = 00000000

    BCF 0x03,6      ; Sets Bank 1
    BSF 0x03,5      ; Sets Bank 1
    MOVLW 0xFF
    MOVWF 0x86      ; Setting PORTB as inputs
    CLRF 0x87       ; Setting PORTC as outputs
    MOVLW 0xC0      ; Bits 7:6 inputs, bits 5:0 outputs        
    MOVWF 0x85      ; TRISA, RA0-RA5 traffic LEDs

    BSF 0x03,6      ; Sets Bank 3
    BSF 0x03,5	    ; Sets Bank 3
    CLRF 0x88	    ; Setting ANSEL LOW for digital I/O
    CLRF 0x89       ; Setting ANSELH LOW for digital I/O
    
    ; Interrupt and Timer Setup
    BCF 0x03,6              ; Sets Bank 0
    BCF 0x03,5              ; Sets Bank 0
    CLRF T1CON              ; Timer1 off while configuring
    MOVLW 0x0B
    MOVWF TMR1H             ; Timer1 preload high byte
    MOVLW 0xDC
    MOVWF TMR1L             ; Timer1 preload low byte
    MOVLW 0x31		    ; 00110001
    MOVWF T1CON		    ; Timer1 prescale = 1:8
    BCF PIR1,0              ; Clearing TMR1IF
    
    BCF 0x03,6              ; Sets Bank 1
    BSF 0x03,5              ; Sets Bank 1
    BSF PIE1,0              ; Enabling Timer1 interrupt
    
    BCF 0x03,6              ; Sets Bank 0
    BCF 0x03,5              ; Sets Bank 0
    BCF INTCON,3            ; PORTB IOC disabled
    BCF INTCON,4            ; External INT disabled
    BSF INTCON,6            ; Enabling peripheral interrupts
    BSF INTCON,7            ; Enabling global interrupts

    GOTO Main    

Main:
    ; Display complete packed state on PORTC
    MOVF intersection_state,W
    MOVWF PORTC

    ; Update actual traffic-light LEDs on PORTA
    CALL UpdateLights

    ; Get STATE_COUNT from upper nibble
    SWAPF intersection_state,W
    ANDLW 0x0F
    MOVWF count_temp

    ; Check TRANSITION bit
    BTFSC intersection_state,3
    GOTO CheckYellowTime
    GOTO CheckGreenTime
    
UpdateLights:
    BTFSC intersection_state,0	    ; Check DIRECTION
    GOTO EWDirection

NSDirection:
    BTFSC intersection_state,3     ; Check TRANSITION
    GOTO NSYellow

NSGreen:
    MOVLW 0x0C	    ; 001100
    MOVWF PORTA
    RETURN

NSYellow:
    MOVLW 0x0A     ; 001010
    MOVWF PORTA
    RETURN

EWDirection:
    BTFSC intersection_state,3     ; Check TRANSITION
    GOTO EWYellow

EWGreen:
    MOVLW 0x21	   ; 100001
    MOVWF PORTA
    RETURN

EWYellow:
    MOVLW 0x11     ; 010001
    MOVWF PORTA
    RETURN
    
CheckGreenTime:
    MOVF count_temp,W
    XORLW 0x0A              ; Is STATE_COUNT = 10?
    BTFSC STATUS,2
    GOTO BeginTransition
    GOTO Main

BeginTransition:
    ; Protect intersection_state while Main modifies it
    BCF INTCON,7            ; Temporarily disabling interrupts

    ; Keep DIRECTION and set TRANSITION
    MOVF intersection_state,W
    ANDLW 0x01              ; Keeping DIRECTION only
    IORLW 0x08              ; Setting TRANSITION = 1
    MOVWF intersection_state

    BSF INTCON,7            ; Re-enabling interrupts
    GOTO Main

CheckYellowTime:
    MOVF count_temp,W
    XORLW 0x02              ; Is STATE_COUNT = 2?
    BTFSC STATUS,2
    GOTO FinishTransition
    GOTO Main

FinishTransition:
    ; Protect intersection_state while Main modifies it
    BCF INTCON,7            ; Temporarily disabling interrupts

    ; Toggle DIRECTION and clear everything else
    MOVF intersection_state,W
    XORLW 0x01           ; Toggle DIRECTION
    ANDLW 0x01           ; Keep only new DIRECTION
    MOVWF intersection_state

    BSF INTCON,7         ; Re-enabling interrupts
    GOTO Main
    
ISRHandler:
    MOVWF W_TEMP         ; Saving W register
    SWAPF STATUS,W       ; Moving STATUS into W
    CLRF STATUS		 ; Sets Bank 0
    MOVWF STATUS_TEMP    ; Saving STATUS register
    
   ; Check Timer1 Interrupt
    BTFSC PIR1,0         ; Is TMR1IF set?
    CALL Timer1ISR
    GOTO LeaveISR
    
Timer1ISR:
    ; Reload Timer1 for another 500 ms
    MOVLW 0x0B
    MOVWF TMR1H
    MOVLW 0xDC
    MOVWF TMR1L
    BCF PIR1,0		  ; Clear Timer1 interrupt flag

    ; Save lower four intersection-state flags
    MOVF intersection_state,W
    ANDLW 0x0F            ; Keeping bits 3:0
    MOVWF flags_temp

    ; Extract STATE_COUNT
    SWAPF intersection_state,W
    ANDLW 0x0F            ; Keeping STATE_COUNT only
    MOVWF count_temp

    ; Increment STATE_COUNT
    INCF count_temp,F     ; STATE_COUNT + 1
    MOVLW 0x0F
    ANDWF count_temp,F    ; Keeping it as a 4-bit value

    ; Put STATE_COUNT back into bits 7:4
    SWAPF count_temp,W
    ANDLW 0xF0
    IORWF flags_temp,W      ; Recombining count and lower flags
    MOVWF intersection_state
    RETURN

LeaveISR:
    SWAPF STATUS_TEMP,W ; Restoring saved STATUS value
    MOVWF STATUS
    SWAPF W_TEMP,F	; Preparing saved W value
    SWAPF W_TEMP,W	; Restoring W register
    RETFIE		; Returning from interrupt

END