;;;;;;; ASEN 4-5067 Lab4 ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Author: Sage Herrin
; Date  : 10/8/20
;
; DESCRIPTION
; On power up execute the following sequence:
; 	RD5 ON for ~1 second then OFF
; 	RD6 ON for ~1 second then OFF
; 	RD7 ON for ~1 second then OFF
; LOOP on the following forever:
; 	Blink "Alive" LED (RD4) ON for ~1sec then OFF for ~1sec
; 	Read input from RPG (at least every 2ms) connected to pins 
;		RD0 and RD1 and mirror the output onto pins RJ2 and RJ3
; 	ASEN5519 ONLY: Read input from baseboard RD3 button and toggle the value 
;		of RD2 such that the switch being pressed and RELEASED causes 
;		RD2 to change state from ON to OFF or OFF to ON
;	NOTE: ~1 second means +/- 100msec
;
;;;;;;; Program hierarchy ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Mainline
; Loop
; Initial 	- 	Initialize ports and perform LED sequence
; WaitXXXms	- 	Subroutine to wait XXXms
; Wait1sec 	- 	Subroutine to wait 1 sec 
; Check_SW 	- 	Subroutine to check the status of RD3 button and change RD2 (ASEN5519 ONLY)
; Check_RPG	- 	Read the values of the RPG from RD0 and RD1 and display on RJ2 and RJ3
;
;;;;;;; Assembler directives ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        LIST  P=PIC18F87K22, F=INHX32, C=160, N=0, ST=OFF, MM=OFF, R=DEC, X=OFF
        #include P18F87K22.inc

;		MPLAB configuration directives
		
		CONFIG	FOSC = HS1, XINST = OFF
		CONFIG	PWRTEN = ON, BOREN = ON, BORV = 1
		CONFIG 	WDTEN = OFF
		
;;;;;;; Hardware notes ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	RPG-A port/pin is RJ2
;	RPG-B port/pin is RJ3

;;;;;;;; Variables ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        cblock  0x000		; Beginning of Access RAM
        COUNT			; Counter available as local to subroutines
        ALIVECNT		; Counter for blinking "Alive" LED
        BYTE			; Byte to be displayed
        BYTESTR:10		; Display string for binary version of BYTE
        endc

;;;;;;; Macro definitions ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; MOVLF is a macro that puts a literal value into a GPR or SFR
MOVLF   macro  literal,dest
        movlw  literal
        movwf  dest
	endm
;; POINT taken from Reference: Peatman CH 7 LCD
POINT   macro  stringname		; Load a string into table pointer
        MOVLF  high stringname, TBLPTRH	; Used to put values in program memory
        MOVLF  low stringname, TBLPTRL
        endm

DISPLAY macro  register         ; Displays a given register in binary on LCD
        movff  register,BYTE
        call  ByteDisplay
        endm

;;;;;;; Vectors ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        org  0x0000             ;Reset vector
        nop			;One instruction cycle delay.
        goto  Mainline		;Redirect code to the Mainline Program

        org  0x0008             ;High priority interrupt vector
        goto  $                 ;Return to current program counter location

        org  0x0018             ;Low priority interrupt vector
        goto  $                 ;Return to current program counter location

;;;;;;; Mainline Program ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

Mainline
        rcall  Initial          ;Jump to initialization routine
Loop
        RCALL	Wait250ms
				; Add operand to finish the use of this macro 
	bra  Loop		; Main loop should run forever after entry

;;;;;;; Initial subroutine ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; This subroutine performs all initializations of variables and registers.

Initial
	MOVLF   B'00000000',INTCON
        MOVLF   B'10000101',T0CON       ; Set up Timer0 for a delay of 1 s
        MOVLF   high Bignum,TMR0H       ; Writing binary 25536 to TMR0H / TMR0L
        MOVLF   low Bignum,TMR0L
	
	MOVLF	B'00001011',TRISD; Set TRISD - check that this and TRISJ are set right 
	MOVLF	B'00000000',LATD; Turn off all LEDS
	RCALL	Wait1s; call subroutine to wait 1 second
	MOVLF	B'00100000',LATD; Turn ON RD5
	RCALL   Wait1s; call subroutine to wait 1 second
	MOVLF	B'00000000',LATD; Turn OFF RD5
	MOVLF	B'01000000',LATD; Turn ON RD6
	RCALL	Wait1s; call subroutine to wait 1 second
	MOVLF	B'00000000',LATD; Turn OFF RD6
	MOVLF	B'10000000',LATD; Turn ON RD7
	RCALL   Wait1s; call subroutine to wait 1 second
	MOVLF	B'00000000',LATD; Turn OFF RD7
	
	
	MOVLF   B'00000000',INTCON
        MOVLF   B'10000011',T0CON       ; Set up Timer0 for a delay of 250 ms
        MOVLF   high Bignum,TMR0H       ; Writing binary 25536 to TMR0H / TMR0L
        MOVLF   low Bignum,TMR0L
	
        return

;;;;;;; Wait1s subroutine ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Subroutine to wait 1 second
		
Bignum  equ     65536-62500		;Used prescalar of 64

Wait1s
        btfss 	INTCON,TMR0IF           ; Read Timer0 rollover flag and ...
        bra     Wait1s                ; Loop if timer has not rolled over
        MOVLF  	high Bignum,TMR0H       ; Then write the timer values into
        MOVLF  	low Bignum,TMR0L        ; the timer high and low registers
        bcf  	INTCON,TMR0IF           ; Clear Timer0 rollover flag
        return

;;;;;;; Wait1sec subroutine ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Subroutine to wait 1 sec based on calling WaitXXXms YYY times or up to 3 nested loops
				
	;Need prescalar of 16

Wait250ms
        btfss 	INTCON,TMR0IF           ; Read Timer0 rollover flag and ...
	return
	BTG	LATD,4
        ;bra     Wait250ms                ; Loop if timer has not rolled over
        MOVLF  	high Bignum,TMR0H       ; Then write the timer values into
        MOVLF  	low Bignum,TMR0L        ; the timer high and low registers
        bcf  	INTCON,TMR0IF           ; Clear Timer0 rollover flag
        return

;;;;;;; Check_SW1 subroutine ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Subroutine to check the status of RD3 button and change RD2 (ASEN5519 ONLY)
				
;Check_SW1
;	BTFSS	PORTD,3	; Add code here
;	BRA	ds
;	BTFSS	on,3
;	RCALL	Debounce
;	MOVLF	B'00001000',on
;ds
;	MOVF	PORTD,0	
;	ANDLW	B'00001000'
;	SUBWF	on,0
;	BTFSC	WREG,3
;	RCALL	onoff
;		return

;;;;;;; Check_RPG subroutine ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Subroutine to read the values of the RPG and display on RJ2 and RJ3
				
;Check_RPG
;	MOVF	PORTD,0
;	RLNCF	WREG
;	RLNCF	WREG
;	ANDLW	B'00001100'
;	MOVWF	LATJ,0	
;		return	; Add code here
;		      		
;Debounce
;loop4
;	RCALL	Wait1ms
;	DECF	reg4,1
;	BNZ	loop4
;		return
		
		
;onoff
;	BTG	LATD,2	 
;	CLRF	on
;		return

        end
