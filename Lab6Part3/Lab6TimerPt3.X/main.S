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
    portb_old EQU 0x75 ; Previous RB4/RB5 values
    portb_now EQU 0x76 ; Current RB4/RB5 values
 
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
    MOVLW 0x30      ; Bits 00110000
    MOVWF 0x96      ; Enable IOC on RB4 and RB5
    BSF 0x81,6      ; INTEDG = 1, RB0/INT triggers low-to-high
    BSF 0x81,7      ; Disabling internal PORTB pull-ups
    
    BSF 0x03,6      ; Sets Bank 3
    BSF 0x03,5	    ; Sets Bank 3
    CLRF 0x88	    ; Setting ANSEL LOW for digital I/O
    CLRF 0x89       ; Setting ANSELH LOW for digital I/O
    
    ; Interrupt Setup
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
    ; Display complete packed state on PORTC
    MOVF intersection_state,W
    MOVWF PORTC

    ; Get STATE_COUNT from upper nibble
    SWAPF intersection_state,W
    ANDLW 0x0F
    MOVWF count_temp
    
    ; Is STATE_COUNT = 3?
    MOVF count_temp,W
    XORLW 0x03
    BTFSC STATUS,2  ; Z = 1 if STATE_COUNT = 3
    GOTO State3
    
    ; Is STATE_COUNT = 4?
    MOVF count_temp,W
    XORLW 0x04
    BTFSC STATUS,2  ; Z = 1 if STATE_COUNT = 4
    GOTO State4
    
    GOTO Main	; No state action required
    
State3:
    ; Protect shared intersection_state while Main uses it
    BCF INTCON,7    ; Temporarily disabling interrupts

    ; Recheck STATE_COUNT after interrupts are disabled
    SWAPF intersection_state,W
    ANDLW 0x0F
    XORLW 0x03
    BTFSS STATUS,2  ; Still STATE_COUNT = 3?
    GOTO State3Done

    ; If TRANSITION is already set, do nothing
    BTFSC intersection_state,3
    GOTO State3Done

    ; Check current direction
    BTFSC intersection_state,0
    GOTO CheckEWDirection

CheckNSDirection:
    BTFSS intersection_state,1  ; Is N/S detected?
    GOTO BeginTransition        ; No -> change direction
    BTFSC intersection_state,2  ; Is E/W detected?
    GOTO BeginTransition        ; Yes -> change direction
    GOTO SameDirection          ; NS only -> remain N/S

CheckEWDirection:
    BTFSC intersection_state,1  ; Is N/S detected?
    GOTO BeginTransition        ; Yes -> change direction
    BTFSS intersection_state,2  ; Is E/W detected?
    GOTO BeginTransition        ; No -> change direction
    GOTO SameDirection          ; EW only -> remain E/W
    
SameDirection:
    MOVLW 0x01                  ; Keep only DIRECTION
    ANDWF intersection_state,F  ; Clear count and flags
    GOTO State3Done
    
BeginTransition:
    BSF intersection_state,3    ; Setting TRANSITION = 1
    GOTO State3Done
    
State3Done:
    BSF INTCON,7    ; Re-enable interrupts
    GOTO Main
    
State4:
    ; Protect packed state during update
    BCF INTCON,7    ; Temporarily disabling interrupts

    ; Recheck STATE_COUNT after interrupts are disabled
    SWAPF intersection_state,W
    ANDLW 0x0F
    XORLW 0x04
    BTFSS STATUS,2  ; Still STATE_COUNT = 4?
    GOTO State4Done

    ; Toggle DIRECTION and clear everything else
    MOVF intersection_state,W
    XORLW 0x01	    ; Toggle DIRECTION bit
    ANDLW 0x01      ; Keep only new DIRECTION
    MOVWF intersection_state    ; Clear count, transition, NS detected, and EW detected

State4Done:
    BSF INTCON,7    ; Re-enable interrupts
    GOTO Main
    
ISRHandler:
    MOVWF W_TEMP         ; Saving W register
    SWAPF STATUS,W       ; Moving STATUS into W
    CLRF STATUS		 ; Sets Bank 0
    MOVWF STATUS_TEMP    ; Saving STATUS register
    
    ; Check External INT Interrupt
    BTFSC INTCON,1       ; Is INTF set?
    CALL ExternalINTISR

    ; Check PORTB IOC Interrupt
    BTFSC INTCON,0       ; Is RBIF set?
    CALL PORTBISR
    GOTO LeaveISR
    
ExternalINTISR:
    MOVF intersection_state,W ; Save lower four state flags
    ANDLW 0x0F		; Keeping bits 3:0
    MOVWF flags_temp
    
    ; Extract STATE_COUNT
    SWAPF intersection_state,W  ; Moving upper nibble down
    ANDLW 0x0F          ; Keeping STATE_COUNT only
    MOVWF count_temp
    
    ; Increment STATE_COUNT
    INCF count_temp,F   ; STATE_COUNT + 1
    MOVLW 0x0F
    ANDWF count_temp,F  ; Keeping it as a 4-bit value
    
    ; Put STATE_COUNT back into bits 7:4
    SWAPF count_temp,W  ; Moving count back to upper nibble
    ANDLW 0xF0
    IORWF flags_temp,W  ; Recombine count and lower flags
    MOVWF intersection_state
    BCF INTCON,1        ; Clearing INTF
    RETURN

PORTBISR:
    ; Read current PORTB state and sees if it ends the IOC mismatch condition
    MOVF PORTB,W
    ANDLW 0x30          ; Keeping RB4 and RB5 only
    MOVWF portb_now
    BCF INTCON,0        ; Clearing RBIF

    ; Check N/S car detection on RB4                  
    BTFSS portb_now,4           ; Is RB4 HIGH?          
    GOTO CheckEWCar                                       
    BTFSC portb_old,4           ; Was RB4 already HIGH?
    GOTO CheckEWCar                                       
    BSF intersection_state,1    ; Set NS_DETECTED       

CheckEWCar:                                              
    ; Check E/W car detection on RB5                  
    BTFSS portb_now,5           ; Is RB5 HIGH?          
    GOTO SavePORTB                                        
    BTFSC portb_old,5           ; Was RB5 already HIGH? 
    GOTO SavePORTB                                        
    BSF intersection_state,2    ; Set EW_DETECTED       

SavePORTB:
    MOVF portb_now,W
    MOVWF portb_old              ; Save for next IOC
    RETURN

LeaveISR:
    SWAPF STATUS_TEMP,W ; Restoring saved STATUS value
    MOVWF STATUS
    SWAPF W_TEMP,F	; Preparing saved W value
    SWAPF W_TEMP,W	; Restoring W register
    RETFIE		; Returning from interrupt

END