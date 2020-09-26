;;;;;;; Lab 2 template for ASEN 4067/5067 ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	Created:	Scott Palo (scott.palo@colorado.edu)
;	original:	10-SEP-06
;	Updated:	Trudy.Schwartz@colorado.edu	
;	Modified:	1-SEP-20
;
;	This file provides a basic assembly programming template
;
;;;;;;; Program hierarchy ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Mainline
;   Initial
;
;;;;;;; Assembler directives ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        list  P=PIC18F87K22, F=INHX32, C=160, N=0, ST=OFF, MM=OFF, R=DEC, X=ON
        #include p18f87k22.inc
;		After MPLAB X all configuration bits are set in the code
;		Use mplab help to understand what these directives mean
		CONFIG	FOSC = HS1
		CONFIG	PWRTEN = ON, BOREN = ON, BORV = 1, WDTEN = OFF
		CONFIG	CCP2MX = PORTC, XINST = OFF

;;;;;;; Variables ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        cblock  0x000       ;
        endc		    ; A good place to store variables, none here yet

;;;;;;; Macro definitions ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;;;;;; Vectors ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        org  0x0000         ; Reset vector
        nop		    ; No operation, wastes one instruction cycle
        goto  Mainline	    ; Send program to Mainline code

        org  0x0008         ; High priority interrupt vector
        goto  $             ; $ returns code to the current program counter

        org  0x0018	    ; Low priority interrupt vector
        goto  $             ; Returns. Only here to show code structure.

;;;;;;; Mainline program ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

Mainline
        rcall  	Initial     ; Initialize everything
Loop
        btg  	LATD,0      ; Toggle pin, to support measuring loop time
	bra  	Loop

;;;;;;; Initial subroutine ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; This subroutine performs all initializations of variables and registers.

Initial
        movlw  	B'11000000' ; Move I/O values for PORTD into WREG
	movwf  	TRISD	    ; Set I/O (TRISD)for PORTD
	clrf  	LATD	    ; Drive all OUTPUTS on port D to zero
        return

        end
