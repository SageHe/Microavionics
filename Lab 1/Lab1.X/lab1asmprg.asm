;;;;;;; Lab 1 assembly program for ASEN 4519/5519 ;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	Created:    Scott Palo (scott.palo@colorado.edu)
;	Modified:   Doug Weibel (dowe2010@colorado.edu)
;	Modified:   Trudy Schwartz (trudy.schwartz@colorado.edu)
;	Original:   10-Sept-06
;	Modified:   9-Aug-17
;
;	This file provides a basic assembly program
;
;;;;;;; Program hierarchy ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Mainline
;   Initial
;
;;;;;;; Assembler directives ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;		Use mplab help to understand what these directives mean

        list  P=PIC18F87K22, F=INHX32, C=160, N=0, ST=OFF, MM=OFF, R=DEC, X=ON
        #include P18F87K22.inc
		
;		After MPLAB X all configuration bits are set in the code
;		Use the "CONFIG" MPASM assembler directive:	
		CONFIG	FOSC = HS1
		CONFIG	PWRTEN = ON, BOREN = ON, BORV = 1, WDTEN = OFF
		CONFIG	CCP2MX = PORTC, XINST = OFF


;;;;;;; Variables ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        cblock  0x000          	; Beginning of Access RAM
				; A good place to store variables, none here yet
	endc

;;;;;;; Macro definitions ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; MOVLF is a macro that puts a literal value into a GPR or SFR
MOVLF   macro  literal,dest
        movlw  literal
        movwf  dest
	endm

;;;;;;; Vectors ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        org  0x0000             ; Reset vector
        nop			; No operation, wastes one instruction cycle
        goto  Mainline		; Send program to Mainline code

        org  0x0008         	; High priority interrupt vector
        goto  $             	; Goto $ points code to the current program counter
				; Currently this code just returns to where it was in
				; the mainline as a place holder to show code structure.
				; Later this will goto High Priority Interrupt Service Routine code

        org  0x0018         	; Low priority interrupt vector
        goto  $             	; Ditto, this will later point to Low Priority Service Routine code.

;;;;;;; Mainline program ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

Mainline
        rcall  	Initial          ; Call Initial function to initialize everything
Loop
        movf    PORTD,0          ; Read switch value into WREG
        andlw   B'00001000'      ; Bitwise AND operation to isolate RD3
        bz      SWT_ON           ; Branch if switch is on
        bcf     LATB,7           ; Otherwise turn LED RB7 off
        bra     END1		 ; Then branch to the END1 label	
SWT_ON
        bsf     LATB,7           ; Turn LED RB7 on
END1
		bra  	Loop

;;;;;;; Initial subroutine ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; This subroutine performs all initializations of variables and registers.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

Initial
        MOVLF   B'00000000',TRISB   ; Set TRIS B I/O state
		MOVLF   B'00001000',TRISD   ; Set TRIS D I/O state
		MOVLF   B'00000000',LATB    ; Turn off LEDS on PORTB
	return        
	end


