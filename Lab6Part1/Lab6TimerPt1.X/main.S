// Hunter Clezie
// RCET3375
// Lab6TimerPt1
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
    W_TEMP	EQU 0x70 ; Used as part of the temporary hold for save/restore
    STATUS_TEMP EQU 0x71 ; Used as part of the temporary hold for save/restore
 
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
    CLRF 0x05       ; Clearing PORTA
    CLRF 0x06       ; Clearing PORTB
    CLRF 0x07       ; Clearing PORTC
    CLRF 0x0E       ; Clearing TMR1L
    CLRF 0x0F       ; Clearing TMR1H
    CLRF 0x10       ; Clearing T1CON / Timer1 off

    BCF 0x03,6      ; Sets Bank 1
    BSF 0x03,5      ; Sets Bank 1
    CLRF 0x85       ; Setting PORTA as outputs
    CLRF 0x87       ; Setting PORTC as outputs
    BSF 0x8C,0      ; Enabling Timer1 interrupt TMR1IE
    
    BSF 0x03,6      ; Sets Bank 3
    BSF 0x03,5	    ; Sets Bank 3
    CLRF 0x88	    ; Setting ANSEL LOW for digital I/O
    CLRF 0x89       ; Setting ANSELH LOW for digital I/O
    
    ; Timer1 and Interrupt Setup
    BCF 0x03,6       ; Sets Bank 0
    BCF 0x03,5       ; Sets Bank 0
    MOVLW 0xB1       ; Loading Timer1 high byte
    MOVWF 0x0F       ; TMR1H = 0xB1
    MOVLW 0xE0       ; Loading Timer1 low byte
    MOVWF 0x0E       ; TMR1L = 0xE0
    BCF 0x0C,0       ; Clearing Timer1 interrupt flag TMR1IF
    BSF 0x0B,6       ; Enabling peripheral interrupts PEIE
    BSF 0x0B,7       ; Enabling global interrupts GIE
    BSF 0x10,0       ; Starting Timer1

    GOTO Main    

Main:
    MOVLW 0x01           ; Bit mask for RA0
    XORWF PORTA,F        ; Toggling RA0 diagnostic output
    GOTO Main		 ; Continuously repeat
    
ISRHandler:
    MOVWF W_TEMP         ; Saving W register
    SWAPF STATUS,W       ; Moving STATUS into W
    MOVWF STATUS_TEMP    ; Saving STATUS register

    ; Check Timer1 interrupt flag
    BANKSEL PIR1
    BTFSC PIR1,0         ; Did Timer1 overflow?
    GOTO Timer1ISR
    GOTO LeaveISR
    
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