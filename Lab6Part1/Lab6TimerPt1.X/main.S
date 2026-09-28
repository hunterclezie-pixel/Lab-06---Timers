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
    BANKSEL PORTA
    CLRF PORTA           ; Clearing PORTA outputs

    BANKSEL ANSEL
    CLRF ANSEL           ; Disabling analog functions on PORTA
    CLRF ANSELH

    BANKSEL TRISA
    CLRF TRISA           ; Setting PORTA as outputs

    BANKSEL T1CON
    CLRF T1CON           ; Timer1 off, FOSC/4, 1:1 prescaler
    MOVLW 0xB1
    MOVWF TMR1H          ; Loading high byte
    MOVLW 0xE0
    MOVWF TMR1L          ; Loading low byte

    BANKSEL PIR1
    BCF PIR1,0           ; Clearing TMR1IF

    BANKSEL PIE1
    BSF PIE1,0           ; Enabling Timer1 interrupt TMR1IE

    BANKSEL INTCON
    BSF INTCON,6         ; Enabling peripheral interrupts PEIE
    BSF INTCON,7         ; Enabling global interrupts GIE

    BANKSEL T1CON
    BSF T1CON,0          ; Starting Timer1

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