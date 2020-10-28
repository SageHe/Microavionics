;;;;;;; ASEN 4-5067 Lab 5 ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Generate a jitterfree 10 Hz square wave on CCP1 output using compare mode
; with 24bit extension bytes.
; Use 16 MHz crystal and 4 MHz internal clock rate.
;
;;;;;;; Program hierarchy ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;Mainline
;  Initial
;
;HiPriISR 
;  (Consider using for other timing events)
;LoPriISR
;  CCP1handler
;  TMR1handler
;
;;;;;;; Assembler directives ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        LIST  P=PIC18F87K22, F=INHX32, C=160, N=0, ST=OFF, MM=OFF, R=DEC, X=ON
        #include P18F87K22.inc

;		MPLAB configuration directives

		CONFIG	FOSC = HS1, XINST = OFF
		CONFIG	PWRTEN = ON, BOREN = ON, BORV = 1
		CONFIG 	WDTEN = OFF
		CONFIG	CCP2MX = PORTC	

        errorlevel -311	        ; Turn off message when 3-byte variable is loaded (24bit)

HalfPeriod  equ  200000         ; Number of 250 ns instruction cycles in 0.05 sec (Half of 10 Hz)

;;;;;;; Variables ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        cblock  0x000
        WREG_TEMP		; Temp variables used in Low Pri ISR
        STATUS_TEMP
        TMR1X                   ; Eight-bit extension to TMR1
        CCPR1X                  ; Eight-bit extension to CCPR1
        DTIMEX                  ; Delta time variable of half period of square wave
        DTIMEH			; Will copy HalfPeriod constant into these registers
        DTIMEL
	DIR_RPG			; Direction of RPG
	RPG_TEMP		; Temp variable used for RPG state
	
	OLDPORTD		; Used to hold previous state of RPG
	endc

;;;;;;; Macro definitions ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

MOVLF   macro   literal,dest
        movlw   literal
        movwf   dest
        endm

;;;;;;; Vectors ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        org  0x0000                    ; Reset vector
        goto  Mainline

        org  0x0008                    ; High priority interrupt vector
        goto  HiPriISR		       ; Send to HiPriISR subroutine handler	

        org  0x0018                    ; Low priority interrupt vector
        goto  LoPriISR		       ; Send to LoPriISR subroutine handler	

;;;;;;; Mainline program ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

Mainline
        rcall  Initial                 ;Initialize everything
L1
	bra	L1


;;;;;;; Initial subroutine ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; This subroutine performs SOME of the initializations of variables and registers.
; YOU will need to add those that are omitted/needed for your specific code
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Initial
        MOVLF  low HalfPeriod,DTIMEL	; Load DTIME with HalfPeriod constant
        MOVLF  high HalfPeriod,DTIMEH
	MOVLF  upper HalfPeriod,DTIMEX
	
        clrf TRISC			; Set I/O for PORTC
	clrf LATC			; Clear lines on PORTC
        MOVLF  B'00000011',T1CON	; 16 bit timer and Turn on TMR1
        MOVLF  B'00001000',CCP1CON	; Select compare mode
	MOVLB 0X0F				; Set BSR to bank F for SFRs outside of access bank				
        MOVLW  B'00000000'		; NOTE: Macro cannot be used, does not handle when a=1
	MOVWF CCPTMRS0,1		; Set TMR1 for use with ECCP1, a=1!!
        bsf  RCON,IPEN			; Enable priority levels
        bcf  IPR1,TMR1IP		; Assign low priority to TMR1 interrupts
        bcf  IPR3,CCP1IP		;  and to ECCP1 interrupts
        clrf  TMR1X			; Clear TMR1X extension
        MOVLF  upper HalfPeriod,CCPR1X	; Make first 24-bit compare occur quickly 
					;  16bit+8bit ext Note: 200000 (= 0x30D40)
        bsf  PIE3,CCP1IE		; Enable ECCP1 interrupts
        bsf  PIE1,TMR1IE		; Enable TMR1 interrupts
        bsf  INTCON,GIEL		; Enable low-priority interrupts to CPU
        bsf  INTCON,GIEH		; Enable all interrupts
        return

;;;;;;; RPG subroutine ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Credit: This subroutine modified from Peatman book Chapter 8 - RPG
; This subroutine deciphers RPG changes into values of DIR_RPG of 0, +1, or -1.
; DIR_RPG = +1 for CW change, 0 for no change, and -1 for CCW change.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	
RPG
        clrf   DIR_RPG          ; Clear for "no change" return value.
        movf   PORTD,W          ; Copy PORTD into W.
        movwf  RPG_TEMP         ;  and RPG_TEMP.
        xorwf  OLDPORTD,W       ; Check for any change?
        andlw  B'00000011'      ; Masks just the RPG pins          
        bz	L8		; If zero, RPG has not moved, ->return
        ; But if the two bits have changed then...
	; Form what a CCW change would produce.          	
	rrcf OLDPORTD,W		; Rotate right once into carry bit   
	bnc L9			; If no carry, then bit 0 was a 0 -> branch to L9
        bcf  WREG,1		; Otherwise, bit 0 was a 1. Then clear bit 1
				; to simulate what a CCW change would produce
        bra L10			; Branch to compare if RPG actually matches new CCW pattern in WREG
L9
        bsf  WREG,1		; Set bit 1 since there was no carry
				; again to simulate what CCW would produce
L10				; Test direction of RPG
        xorwf  RPG_TEMP,W       ; Did the RPG actually change to this output?
        andlw  B'00000011'      ; Masks the RPG pins  
        bnz L11			; If not zero, then branch to L11 for CW case
        decf DIR_RPG,F          ; If zero then change DIR_RPG to -1, must be CCW. 
        bra	L8		; Done so branch to return
L11				; CW case 
        incf DIR_RPG,F		; Change DIR_RPG to +1 for CW.
L8
        movff  RPG_TEMP,OLDPORTD       	; Save RPG state as OLDPORTD
        return

;;;;;;; HiPriISR interrupt service routine ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

HiPriISR                        ; High-priority interrupt service routine
;       <execute the handler for interrupt source>
;       <clear that source's interrupt flag>
        retfie  FAST            ; Return and restore STATUS, WREG, and BSR
                                ; from shadow registers

;;;;;;; LoPriISR interrupt service routine ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LoPriISR				; Low-priority interrupt service routine
        movff  STATUS,STATUS_TEMP	; Set aside STATUS and WREG
        movwf  WREG_TEMP

L2
        btfss PIR3,CCP1IF
        bra	L3
            rcall  CCP1handler		; Call CCP1handler for generating RC2 output
        bra	L2
L3
        btfss PIR1,TMR1IF
        bra	L4
            rcall TMR1handler		; Call TMR1handler for timing with CCP1
        bra	L2
L4
        movf  WREG_TEMP,W		; Restore WREG and STATUS
        movff  STATUS_TEMP,STATUS
        retfie				; Return from interrupt, reenabling GIEL

CCP1handler			; First must test if TMR1IF occurred at the same time
        btfss PIR1,TMR1IF	; If TMR1's overflow flag is set? skip to test CCP bit7
        bra	L5		; If TMR1F was clear, branch to check extension bytes
        btfsc CCPR1H,7		; Is bit 7 a 0? Then TMR1/CCP just rolled over, need to inc TMR1X
        bra	L5		; Is bit 7 a 1? Then TMR1/CCP is full, TMR1handler already inc TMR1X 
        incf  TMR1X,F		; TMR1/CCP just rolled over, must increment TMR1 extension
        bcf  PIR1,TMR1IF	; and clear flag (Since TMR1 handler was unable to-arrived here first)
L5
        movf  TMR1X,W		; Check whether extensions are equal
        subwf  CCPR1X,W
        bnz	L7		; If not, branch to return
        btg  CCP1CON,0		; If zero, they are equal, and toggle control bit H/L
        movf  DTIMEL,W		; and add half period to CCPR1 to add more pulse time
        addwf  CCPR1L,F
        movf  DTIMEH,W
        addwfc  CCPR1H,F
        movf  DTIMEX,W
        addwfc  CCPR1X,F
L7
        bcf  PIR3,CCP1IF        ; Clear flag
        return

TMR1handler
        incf  TMR1X,F		;Increment Timer1 extension
        bcf  PIR1,TMR1IF        ;Clear flag and return to service routine
        return

        end
