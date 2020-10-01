;;;;;;; ASEN 4-5067 Lab3 ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Author: Sage Herrin
; Date  : 9/17/20
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

        cblock  0x000   ;Start constant block values 
	    CNT         ;This sets variable CNT = 0x000 (literal or file location)
	    VAL1        ;This sets variable VAL1 = 0x001 (literal or file location)
        endc

;;;;;;; Macro definitions ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; MOVLF is a macro that puts a literal value into a GPR or SFR
MOVLF   macro  literal,dest
        movlw  literal
        movwf  dest
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
        RCALL	Wait1sec
	BTG	LATD,4
				; Add operand to finish the use of this macro 
	bra  Loop		; Main loop should run forever after entry

;;;;;;; Initial subroutine ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; This subroutine performs all initializations of variables and registers.

Initial
reg1	equ 0x01
reg2	equ 0x02	
	MOVLF	D'2',reg2
reg3	equ 0x03	
reg4	equ 0x07
	MOVLF	D'5',reg4
reg5	equ 0x09
	MOVLF	D'2',reg5
ledrj2	equ 0x04
ledrj3	equ 0x05	
on	equ 0x06	
temp	equ 0x08
	MOVLF	D'0',on
	MOVLF	B'00001011',TRISD; Set TRISD - check that this and TRISJ are set right 
	MOVLF	B'00000000',TRISJ; Set TRISJ
	MOVLF	B'00000000',LATD; Turn off all LEDS
	RCALL	Wait1sec; call subroutine to wait 1 second
	MOVLF	B'00100000',LATD; Turn ON RD5
	RCALL   Wait1sec; call subroutine to wait 1 second
	MOVLF	B'00000000',LATD; Turn OFF RD5
	MOVLF	B'01000000',LATD; Turn ON RD6
	RCALL	Wait1sec; call subroutine to wait 1 second
	MOVLF	B'00000000',LATD; Turn OFF RD6
	MOVLF	B'10000000',LATD; Turn ON RD7
	RCALL   Wait1sec; call subroutine to wait 1 second
	MOVLF	B'00000000',LATD; Turn OFF RD7
	RCALL	Loop
        return

;;;;;;; WaitXXXms subroutine ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Subroutine to wait XXX ms
; NOTE - STUDENTS replace XXX with some value of your choosing
; Choose a suitable value to decrement a counter in a loop structure and 
; not using an excessive amount of program memory - i.e. don't use 100 nop's
		
Wait1ms
loop2		; Add code here - assume for now that this is a 2ms loop, fix later
	MOVLF	D'4',reg1
	
loop1
	DECF	reg1,1
	BNZ	loop1
	DECF	reg2,1
	BNZ	loop2
		return

;;;;;;; Wait1sec subroutine ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Subroutine to wait 1 sec based on calling WaitXXXms YYY times or up to 3 nested loops
				
Wait1sec
loop5
	MOVLF	D'4',reg3	
loop3
	RCALL	Wait1ms	
	RCALL	Check_RPG
	RCALL	Check_SW1
	DECF	reg3,1
	BNZ	loop3
	DECF	reg5,1
	BNZ	loop5; Add code here
		return

;;;;;;; Check_SW1 subroutine ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Subroutine to check the status of RD3 button and change RD2 (ASEN5519 ONLY)
				
Check_SW1
	BTFSS	PORTD,3	; Add code here
	BRA	ds
	BTFSS	on,3
	RCALL	Debounce
	MOVLF	B'00001000',on
ds
	MOVF	PORTD,0	
	ANDLW	B'00001000'
	SUBWF	on,0
	BTFSC	WREG,3
	RCALL	onoff
		return

;;;;;;; Check_RPG subroutine ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Subroutine to read the values of the RPG and display on RJ2 and RJ3
				
Check_RPG
	MOVF	PORTD,0
	RLNCF	WREG
	RLNCF	WREG
	ANDLW	B'00001100'
	MOVWF	LATJ,0	
		return	; Add code here
		      

		
Debounce
loop4
	RCALL	Wait1ms
	DECF	reg4,1
	BNZ	loop4
		return
		
		
onoff
	BTG	LATD,2	 
	CLRF	on
		return

        end
