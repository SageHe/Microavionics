;;;;;;; ASEN 4-5067 Lab3 ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Author: YOUR NAME HERE
; Date  : DATE HERE
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
; 	ASEN5067 ONLY: Read input from baseboard RD3 button and toggle the value 
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

        LIST  P=PIC18F87K22, F=INHX32, C=160, N=0, ST=OFF, MM=OFF, R=DEC, X=ON
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
; PUT YOUR CODE HERE
        MOVLF			; Add operand to finish the use of this macro 
	bra  Loop		; Main loop should run forever after entry

;;;;;;; Initial subroutine ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; This subroutine performs all initializations of variables and registers.

Initial
		; Set TRISD
		; Set TRISJ
		; Turn off all LEDS
		; call subroutine to wait 1 second
		; Turn ON RD5
		; call subroutine to wait 1 second
		; Turn OFF RD5
		; Turn ON RD6
		; call subroutine to wait 1 second
		; Turn OFF RD6
		; Turn ON RD7
		; call subroutine to wait 1 second
		; Turn OFF RD7
        return

;;;;;;; WaitXXXms subroutine ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Subroutine to wait XXX ms
; NOTE - STUDENTS replace XXX with some value of your choosing
; Choose a suitable value to decrement a counter in a loop structure and 
; not using an excessive amount of program memory - i.e. don't use 100 nop's
		
WaitXXXms
		; Add code here
		return

;;;;;;; Wait1sec subroutine ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Subroutine to wait 1 sec based on calling WaitXXXms YYY times or up to 3 nested loops
				
Wait1sec
		; Add code here
		return

;;;;;;; Check_SW1 subroutine ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Subroutine to check the status of RD3 button and change RD2 (ASEN5067 ONLY)
				
Check_SW1
		; Add code here
		return

;;;;;;; Check_RPG subroutine ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Subroutine to read the values of the RPG and display on RJ2 and RJ3
				
Check_RPG
		; Add code here
		return      
        

        end
