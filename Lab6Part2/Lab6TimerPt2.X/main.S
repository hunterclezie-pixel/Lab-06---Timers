// Hunter Clezie
// RCET3375
// Lab6TimerPt2
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

    portb_old EQU 0x75 ; Previous RB4/RB5 values
    portb_now EQU 0x76 ; Current RB4/RB5 values
    rise_temp EQU 0x77 ; Stores detected low-to-high edges
 
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
    
    ; Clearing GPRs
    CLRF intersection_state ; Initial state = 00000000
    CLRF count_temp
    CLRF flags_temp
    CLRF portb_old
    CLRF portb_now
    CLRF rise_temp

    BCF 0x03,6      ; Sets Bank 1
    BSF 0x03,5      ; Sets Bank 1
    MOVLW 0xFF
    MOVWF 0x86      ; Setting PORTB as inputs
    CLRF 0x87       ; Setting PORTC as outputs
    MOVLW 0x30      ; Bits 00110000
    MOVWF 0x96      ; Enable IOC on RB4 and RB5
    BSF 0x81,6      ; INTEDG = 1, RB0/INT triggers low-to-high
    BSF 0x81,7      ; Disabling internal PORTB pull-ups
    
    BSF 0x03,6      ; Sets Bank 3
    BSF 0x03,5	    ; Sets Bank 3
    CLRF 0x88	    ; Setting ANSEL LOW for digital I/O
    CLRF 0x89       ; Setting ANSELH LOW for digital I/O
    
    ; Timer1 and Interrupt Setup
    BCF 0x03,6       ; Sets Bank 0
    BCF 0x03,5       ; Sets Bank 0
    MOVF PORTB,W     ; Initial read of PORTB
    ANDLW 0x30       ; Keeping RB4 and RB5
    MOVWF portb_old  ; Saving initial sensor values
    BCF INTCON,0     ; Clearing RBIF
    BCF INTCON,1     ; Clearing INTF
    BSF INTCON,4     ; Enabling external INT interrupt
    BSF INTCON,3     ; Enabling PORTB IOC interrupt
    BSF INTCON,7     ; Enabling global interrupts

    GOTO Main    

Main:
    MOVLW 0x01           ; Bit mask for RA0
    XORWF PORTA,F        ; Toggling RA0 diagnostic output
    GOTO Main		 ; Continuously repeat
    
ISRHandler:
    MOVWF W_TEMP         ; Saving W register
    SWAPF STATUS,W       ; Moving STATUS into W
    MOVWF STATUS_TEMP    ; Saving STATUS register
    
Timer1ISR:
    BANKSEL T1CON
    BCF T1CON,0          ; Stopping Timer1 while reloading
    
    ; Reload Timer1 for next 20 ms period
    MOVLW 0xB1
    MOVWF TMR1H          ; High byte of 0xB1E0
    MOVLW 0xE0
    MOVWF TMR1L          ; Low byte of 0xB1E0

    ; Service Timer1 interrupt flag
    BANKSEL PIR1
    BCF PIR1,0           ; Clearing TMR1IF

    ; Start next timer period
    BANKSEL T1CON
    BSF T1CON,0          ; Restarting Timer1
    BANKSEL PORTA
    BSF PORTA,1          ; Timer diagnostic HIGH
    BCF PORTA,1          ; Timer diagnostic LOW
    GOTO LeaveISR

LeaveISR:
    SWAPF STATUS_TEMP,W ; Restoring saved STATUS value
    MOVWF STATUS
    SWAPF W_TEMP,F	; Preparing saved W value
    SWAPF W_TEMP,W	; Restoring W register
    RETFIE		; Returning from interrupt

END