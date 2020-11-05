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
PWMLOW	    equ	 76000
PWMHIGH	    equ	 4000   
ALIVELOW    equ	 3200000
ALIVEHIGH   equ	 800000    
DPWM	    equ	 40   
Bignum	    equ	 65536 - 62500  

;;;;;;; Variables ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        cblock  0x000
        WREG_TEMP		; Temp variables used in Low Pri ISR
        STATUS_TEMP
        TMR1X                   ; Eight-bit extension to TMR1
        CCPR1X                  ; Eight-bit extension to CCPR1
	CCPR2X			; Eight-bit extension to CCPR2
        DTIMEX                  ; Delta time variable of half period of square wave
        DTIMEH			; Will copy HalfPeriod constant into these registers
        DTIMEL
	DIR_RPG			; Direction of RPG
	RPG_TEMP		; Temp variable used for RPG state
	OLDPORTD		; Used to hold previous state of RPG
	PWMLOWL
	PWMLOWH
	PWMLOWX
	PWMHIGHL
	PWMHIGHH
	PWMHIGHX
	ALIVELOWL
	ALIVELOWH
	ALIVELOWX
	ALIVEHIGHL
	ALIVEHIGHH
	ALIVEHIGHX
	;DTLOWPWMLOW
	;DTLOWPWMHIGH
	;DTLOWPWMX
	;DTHIGHPWMLOW
	;DTHIGHPWMHIGH
	;DTHIGHPWMX
	;DTLOWALIVELOW
	;DTLOWALIVEHIGH
	;DTLOWALIVEX
	;DTHIGHALIVELOW
	;DTHIGHALIVEHIGH
	;DTHIGHALIVEX
	DPWML
	DPWMH
	DPWMX
	COUNT			; Counter available as local to subroutines
        ALIVECNT		; Counter for blinking "Alive" LED
        BYTE			; Byte to be displayed
        BYTESTR:10		; Display string for binary version of BYTE
	PWMDISP:11		;Display string for pwn value
	endc

;;;;;;; Macro definitions ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

MOVLF   macro   literal,dest
        movlw   literal
        movwf   dest
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
	rcall	RPG
	bra	L1


;;;;;;; Initial subroutine ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; This subroutine performs SOME of the initializations of variables and registers.
; YOU will need to add those that are omitted/needed for your specific code
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Initial
	MOVLF  0xC0,PWMDISP ;C0		;Initialize the PWMDISP string to be sent to LCD
	MOVLF  0x50,PWMDISP+1 ;P
	MOVLF  0x57,PWMDISP+2 ;W
	MOVLF  0x3D,PWMDISP+3 ;=
	MOVLF  0x31,PWMDISP+4 ;1
	MOVLF  0x2E,PWMDISP+5 ;.
	MOVLF  0x30,PWMDISP+6 ;0
	MOVLF  0x30,PWMDISP+7; 0
	MOVLF  0x6D,PWMDISP+8 ;m
	MOVLF  0x73,PWMDISP+9 ;s
	MOVLF  0x00,PWMDISP+10; null
	
	MOVLF	B'11000000',TRISB
	MOVLF	B'00001000',TRISD; Set TRISD 
	MOVLF	B'00000000',TRISC; Set TRISC 
	MOVLF	B'00000000',LATD; Turn off all LEDS
	MOVLF	B'00000000',LATC
	MOVLF	B'00000000',LATB
	
	MOVLF   B'00000000',INTCON
        MOVLF   B'00001000',T0CON       ; Set up Timer0 for a delay of 10 ms
        MOVLF   high Bignum10ms,TMR0H       ; Writing binary 25536 to TMR0H / TMR0L
        MOVLF   low Bignum10ms,TMR0L	; Write high byte first, then low!
	bsf	T0CON,7
	
	rcall   InitLCD                 ; Initialize LCD
        rcall   Wait10ms		; 10 ms delay subroutine
	
	POINT   LCDcl                   ; Hello
        rcall   DisplayC		; Display character subroutine
	
	LFSR 0,PWMDISP
	rcall DisplayV
	
	clrf TRISC			; Set I/O for PORTC
	clrf LATC			; Clear lines on PORTC
	
	MOVLF	B'00001011',TRISD	; Set TRISD 
	MOVLF	B'00000000',LATD	; Turn off all LEDS
	MOVLF   B'00000000',INTCON
        MOVLF   B'10000100',T0CON       ; Set up Timer0 for a delay of 0.5 s
        MOVLF   high Bignum,TMR0H       
        MOVLF   low Bignum,TMR0L
	
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
	
        ;MOVLF  low PWMLOW,DTIMEL	; Load DTIME with HalfPeriod constant
        ;MOVLF  high PWMLOW,DTIMEH
	;MOVLF  upper PWMLOW,DTIMEX
	
	;MOVLF  low PWMLOW,DTLOWPWMLOW	; Load initial low timing of pwm
	;MOVLF  high PWMLOW,DTLOWPWMHIGH
	;MOVLF  upper PWMLOW,DTLOWPWMX
	
	;MOVLF  low PWMHIGH,DTHIGHPWMLOW	; Load initial high timing of pwm
	;MOVLF  high PWMHIGH,DTHIGHPWMHIGH
	
	;MOVLF  low ALIVELOW,DTLOWALIVELOW   ; Load initial low timiing of alive led
	;MOVLF  high ALIVELOW,DTLOWALIVEHIGH
	;MOVLF  upper ALIVELOW,DTLOWALIVEX
	
	;MOVLF  low ALIVEHIGH,DTHIGHALIVELOW ; Load initial high timing of alive led
	;MOVLF  high ALIVEHIGH,DTHIGHALIVEHIGH
	;MOVLF  upper ALIVEHIGH,DTHIGHALIVEX
	
	;MOVLF  DPWM,DTIMEPWM	; Load change in pwm for smallest rotation of RPG
	
	MOVLF	low PWMLOW,PWMLOWL
	MOVLF	high PWMLOW,PWMLOWH
	MOVLF	upper PWMLOW,PWMLOWX
	
	MOVLF	low PWMHIGH,PWMHIGHL
	MOVLF	high PWMHIGH,PWMHIGHH
	MOVLF	upper PWMHIGH,PWMHIGHX
	
	MOVLF	low ALIVELOW,ALIVELOWL
	MOVLF	high ALIVELOW,ALIVELOWH
	MOVLF	upper ALIVELOW,ALIVELOWX
	
	MOVLF	low ALIVEHIGH,ALIVEHIGHL
	MOVLF	high ALIVEHIGH,ALIVEHIGHH
	MOVLF	upper ALIVEHIGH,ALIVEHIGHX
	
	MOVLF	low DPWM,DPWML
	MOVLF	high DPWM,DPWMH
	MOVLF	upper DPWM,DPWMX
	
	
        clrf TRISC			; Set I/O for PORTC
	clrf LATC			; Clear lines on PORTC
        MOVLF  B'00000011',T1CON	; 16 bit timer and Turn on TMR1
        MOVLF  B'00001010',CCP1CON	; Select compare mode
	;MOVLF  B'00001000',CCP2CON	; Select compare mode for ccp2
	MOVLB 0X0F				; Set BSR to bank F for SFRs outside of access bank				
        MOVLW  B'00000000'		; NOTE: Macro cannot be used, does not handle when a=1
	MOVWF CCPTMRS0,1		; Set TMR1 for use with ECCP1, a=1!!
	MOVLW  B'00001000'
	MOVWF CCP2CON,1
        bsf  RCON,IPEN			; Enable priority levels
        bcf  IPR1,TMR1IP		; Assign low priority to TMR1 interrupts
        bcf  IPR3,CCP1IP		;  and to ECCP1 interrupts
	bcf  IPR3,CCP2IP		; Assign low priority to ECCP2
        clrf  TMR1X			; Clear TMR1X extension
        ;MOVLF  upper PWMLOW,CCPR1X	; Make first 24-bit compare occur quickly 
	;MOVLF  upper ALIVELOW,CCPR2X	;  16bit+8bit ext Note: 200000 (= 0x30D40)
	MOVFF	PWMLOWX,CCPR1X
	MOVFF	ALIVELOWX,CCPR2X
        bsf  PIE3,CCP2IE		; Enable ECCP1 interrupts
	bsf  PIE3,CCP1IE		; Enable ECCP2 interrupts
        bsf  PIE1,TMR1IE		; Enable TMR1 interrupts
	bcf  PIR3,CCP2IF
        bsf  INTCON,GIEL		; Enable low-priority interrupts to CPU
        bsf  INTCON,GIEH		; Enable all interrupts
	
	clrf TMR1H
	clrf TMR1L
	clrf TMR1X
	
	;MOVLF low ALIVELOW, CCPR2L
	;MOVLF high ALIVELOW,CCPR2H
	MOVFF	ALIVELOWL,CCPR2L
	MOVFF	ALIVELOWH,CCPR2H
	
	
pwmcount    equ	0x30
	MOVLF	D'0',pwmcount
	
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
	;movf PWMDISP+4
	;sublw 0x32
	;bz dechigh
	movf PWMDISP+7
	sublw 0x30
	bz dectp
	movf PWMDISP+7,W
	sublw 0x30
	bz dectp
	decf PWMDISP+7,F
	movf PWMLOWL,0
	addwf DPWML,0
	movwf PWMLOWL,0
	movf PWMLOWH,0
	addwfC DPWMH,0
	movwf PWMLOWH,0
	movf PWMLOWX,0
	addwfC DPWMX,0
	movwf PWMLOWX,0
	
	movf DPWML,0
	subwf PWMHIGHL,0
	movwf PWMHIGHL,0
	movf DPWMH,0
	subwfb PWMHIGHH,0
	movwf PWMHIGHH,0
	movf DPWMX,0
	subwfb PWMHIGHL,0
	movwf PWMHIGHL,0
	LFSR	0,PWMDISP
	rcall	DisplayV
        bra	L8		; Done so branch to return
L11				; CW case 
        incf DIR_RPG,F		; Change DIR_RPG to +1 for CW.
	movf PWMDISP+4,W
	sublw 0x32
	bz	L8
	movf PWMDISP+7,W
	sublw 0x39
	bz inctp
	;movlw D'9'
	;cpfslt pwmcount
	;bra	inctp
	incf PWMDISP+7,F
	movf PWMHIGHL,0
	addwf DPWML,0
	movwf PWMHIGHL,0
	movf PWMHIGHH,0
	addwfC DPWMH,0
	movwf PWMHIGHH,0
	movf PWMHIGHX,0
	addwfC DPWMX,0
	movwf PWMHIGHX,0
	
	movf DPWML,0
	subwf PWMLOWL,0
	movwf PWMLOWL,0
	movf DPWMH,0
	subwfb PWMLOWH,0
	movwf PWMLOWH,0
	movf DPWMX,0
	subwfb PWMLOWL,0
	movwf PWMLOWL,0
	
	;incf pwmcount,F
	LFSR	0,PWMDISP
	rcall	DisplayV
L8
        movff  RPG_TEMP,OLDPORTD       	; Save RPG state as OLDPORTD
        return
inctp
	movf PWMDISP+6,W
	sublw 0x39
	bz highcap
	MOVLF 0x30,PWMDISP+7
	incf PWMDISP+6,F
	movf PWMHIGHL,0
	addwf DPWML,0
	movwf PWMHIGHL,0
	movf PWMHIGHH,0
	addwfC DPWMH,0
	movwf PWMHIGHH,0
	movf PWMHIGHX,0
	addwfC DPWMX,0
	movwf PWMHIGHX,0
	
	movf DPWML,0
	subwf PWMLOWL,0
	movwf PWMLOWL,0
	movf DPWMH,0
	subwfb PWMLOWH,0
	movwf PWMLOWH,0
	movf DPWMX,0
	subwfb PWMLOWL,0
	movwf PWMLOWL,0
	;clrf pwmcount
	LFSR	0,PWMDISP
	rcall   DisplayV
	bra	L8
dectp
	movf PWMDISP+6,W
	sublw 0x30
	bz highorlow
	MOVLF 0x39,PWMDISP+7
	decf PWMDISP+6
	movf PWMLOWL,0
	addwf DPWML,0
	movwf PWMLOWL,0
	movf PWMLOWH,0
	addwfC DPWMH,0
	movwf PWMLOWH,0
	movf PWMLOWX,0
	addwfC DPWMX,0
	movwf PWMLOWX,0
	
	movf DPWML,0
	subwf PWMHIGHL,0
	movwf PWMHIGHL,0
	movf DPWMH,0
	subwfb PWMHIGHH,0
	movwf PWMHIGHH,0
	movf DPWMX,0
	subwfb PWMHIGHL,0
	movwf PWMHIGHL,0
	;clrf pwmcount
	LFSR	0,PWMDISP
	rcall	DisplayV
	bra	L8
highcap
	MOVLF 0x32,PWMDISP+4
	MOVLF 0x30,PWMDISP+6
	MOVLF 0x30,PWMDISP+7
	
	LFSR	0,PWMDISP
	rcall	DisplayV
	bra	L8
dechigh
	MOVLF 0x31,PWMDISP+4
	MOVLF 0x39,PWMDISP+6
	MOVLF 0x39,PWMDISP+7
	LFSR	0,PWMDISP
	rcall	DisplayV
	bra	L8
highorlow
	movf PWMDISP+4,W
	sublw 0x31
	bz	L8
	MOVLF 0x31,PWMDISP+4
	MOVLF 0x39,PWMDISP+6
	MOVLF 0x39,PWMDISP+7
	LFSR	0,PWMDISP
	rcall	DisplayV
	bra	L8
	
	
;;;;;;; HiPriISR interrupt service routine ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

HiPriISR                        ; High-priority interrupt service routine
Q2
        btfss PIR3,CCP2IF
        bra	Q3
            rcall  CCP2handler		; Call CCP1handler for generating RC2 output
        bra	Q2
Q3
        btfss PIR1,TMR1IF
        bra	Q4
            rcall TMR1handler		; Call TMR1handler for timing with CCP1
        bra	Q2			;       <execute the handler for interrupt source>
Q4				;       <clear that source's interrupt flag>
        retfie  FAST            ; Return and restore STATUS, WREG, and BSR
                                ; from shadow registers
CCP2handler			; First must test if TMR1IF occurred at the same time
        btfss PIR1,TMR1IF	; If TMR1's overflow flag is set? skip to test CCP bit7
        bra	Q5		; If TMR1F was clear, branch to check extension bytes
        btfsc CCPR2H,7		; Is bit 7 a 0? Then TMR1/CCP just rolled over, need to inc TMR1X
        bra	Q5		; Is bit 7 a 1? Then TMR1/CCP is full, TMR1handler already inc TMR1X 
        incf  TMR1X,F		; TMR1/CCP just rolled over, must increment TMR1 extension
        bcf  PIR1,TMR1IF	; and clear flag (Since TMR1 handler was unable to-arrived here first)
Q5
        movf  TMR1X,W		; Check whether extensions are equal
        subwf  CCPR2X,W
        bnz	Q7		; If not, branch to return
	btfss PORTD,4		; If set (end of high part of pwm), add low pwm time dt to ccp
	bra	alivelowtohigh	; Otherwise going from low part of pwm to high part
	;MOVLF  low ALIVELOW,DTIMEL
	;MOVLF  high ALIVELOW,DTIMEH
	;MOVLF  upper ALIVELOW,DTIMEX
	MOVFF	ALIVELOWL,DTIMEL
	MOVFF	ALIVELOWH,DTIMEH
	MOVFF	ALIVELOWX,DTIMEX
	bra	Z1
alivelowtohigh
	;MOVLF  low ALIVEHIGH,DTIMEL
	;MOVLF  high ALIVEHIGH,DTIMEH
	;MOVLF  upper ALIVEHIGH,DTIMEX 
	MOVFF	ALIVEHIGHL,DTIMEL
	MOVFF	ALIVEHIGHH,DTIMEH
	MOVFF	ALIVEHIGHX,DTIMEX
Z1	
        btg  LATD,4		; If zero, they are equal, and toggle control bit H/L
        movf  DTIMEL,W		; and add half period to CCPR1 to add more pulse time
        addwf  CCPR2L,F,1
        movf  DTIMEH,W
        addwfc  CCPR2H,F,1
        movf  DTIMEX,W
        addwfc  CCPR2X,F
Q7
        bcf  PIR3,CCP2IF        ; Clear flag
        return
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
        bra	L6
            rcall TMR1handler		; Call TMR1handler for timing with CCP1
        bra	L2
L6
	btfss  PIR3,CCP2IF
	bra	L4
	    rcall CCP2handler
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
	btfss PORTC,2		; If set (end of high part of pwm), add low pwm time dt to ccp
	bra	lowtohigh	; Otherwise going from low part of pwm to high part
	;MOVLF  low PWMLOW,DTIMEL
	;MOVLF  high PWMLOW,DTIMEH
	;MOVLF  upper PWMLOW,DTIMEX
	MOVFF	PWMLOWL,DTIMEL
	MOVFF	PWMLOWH,DTIMEH
	MOVFF	PWMLOWX,DTIMEX
	bra	c1
lowtohigh
	;MOVLF  low PWMHIGH,DTIMEL
	;MOVLF  high PWMHIGH,DTIMEH
	;MOVLF  upper PWMHIGH,DTIMEX 
	MOVFF	PWMHIGHL,DTIMEL
	MOVFF	PWMHIGHH,DTIMEH
	MOVFF	PWMHIGHX,DTIMEX
c1	
        ;btg  CCP1CON,0		; If zero, they are equal, and toggle control bit H/L
	btg   LATC,2
        movf  DTIMEL,W		; and add half period to CCPR1 to add more pulse time
        addwf  CCPR1L,F
        movf  DTIMEH,W
        addwfc  CCPR1H,F
        movf  DTIMEX,W
        addwfc  CCPR1X,F
L7
        bcf  PIR3,CCP1IF        ; Clear flag
        return
;lowtohigh
	;MOVLF  low PWMHIGH,DTIMEL
	;MOVLF  high PWMHIGH,DTIMEH
	;MOVLF  upper PWMHIGH,DTIMEX  
	;return
;hightolow
	;MOVLF  low PWMLOW,DTIMEL
	;MOVLF  high PWMLOW,DTIMEH
	;MOVLF  upper PWMLOW,DTIMEX
	;return

TMR1handler
        incf  TMR1X,F		;Increment Timer1 extension
        bcf  PIR1,TMR1IF        ;Clear flag and return to service routine
        return
	
Wait1s
        btfss 	INTCON,TMR0IF           ; Read Timer0 rollover flag and ...
        bra     Wait1s                  ; Loop if timer has not rolled over
        MOVLF  	high Bignum,TMR0H       ; Then write the timer values into
        MOVLF  	low Bignum,TMR0L        ; the timer high and low registers
        bcf  	INTCON,TMR0IF           ; Clear Timer0 rollover flag
        return
	
;;;;;;; InitLCD subroutine ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	;THIS SUBROUTINE WAS BORROWED FROM THE LAB 4 EXAMPLE CODE
;
; InitLCD - modified version of subroutine in Reference: Peatman CH7 LCD
; Initialize the LCD.
; First wait for 0.1 second, to get past display's power-on reset time.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        
InitLCD
        MOVLF  10,COUNT	    ; Wait 0.1 second for LCD to power up
Loop3
        rcall  Wait10ms     ; Call wait10ms 10 times to 0.1 second
        decf  COUNT,F
        bnz	Loop3
        bcf     LATB,4	    ; RS=0 for command mode to LCD
        POINT   LCDstr      ; Set up table pointer to initialization string
        tblrd*              ; Get first byte from string into TABLAT
Loop4
	clrf LATB	    ; First set LATB to all zero	
        bsf   LATB,5	    ; Drive E high - enable LCD
	movf TABLAT,W	    ; Move byte from program memory into working register
	andlw 0xF0	    ; Mask to get only upper nibble
	swapf WREG,W	    ; Swap so that upper nibble is in right position to move to LATB (RB0:RB3)
	iorwf PORTB,W	    ; Mask with the rest of PORTB to retain existing RB7:RB4 states
	movwf LATB	    ; Update LATB to send upper nibble
        bcf   LATB,5        ; Drive E low so LCD will process input
        rcall Wait10ms      ; Wait ten milliseconds
	
	clrf LATB	    ; Reset LATB to all zero	    
        bsf  LATB,5         ; Drive E high
        movf TABLAT,W,0	    ; Move byte from program memory into working register
	andlw 0x0F	    ; Mask to get only lower nibble
	iorwf PORTB,W,0	    ; Mask lower nibble with the rest of PORTB
	movwf LATB,0	    ; Update LATB to send lower nibble
        bcf   LATB,5        ; Drive E low so LCD will process input
        rcall Wait10ms      ; Wait ten milliseconds
        tblrd+*             ; Increment pointer and get next byte
        movf  TABLAT,F      ; Check if we are done, is it zero?
        bnz	Loop4
        return
	
;;;;;;; T50 subroutine ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;THIS SUBROUTINE WAS BORROWED FROM THE LAB 4 EXAMPLE CODE
;
; T50 modified version of T40 taken from Reference: Peatman CH 7 LCD
; Pause for 50 microseconds or 50/0.25 = 200 instruction cycles.
; Assumes 16/4 = 4 MHz internal instruction rate (250 ns)
; rcall(2) + movlw(1) + movwf(1) + COUNT*3 - lastBNZ(1) + return(2) = 200 
; Then COUNT = 195/3
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        
T50
        movlw  195/3          ;Each loop L4 takes 3 ins cycles
        movwf  COUNT		    
A4
        decf  COUNT,F
        bnz	A4
        return
;;;;;;;;DisplayC subroutine;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; THIS SUBROUTINE WAS BORROWED FROM THE LAB 4 EXAMPLE CODE
; 
; DisplayC taken from Reference: Peatman CH7 LCD
; This subroutine is called with TBLPTR containing the address of a constant
; display string.  It sends the bytes of the string to the LCD.  The first
; byte sets the cursor position.  The remaining bytes are displayed, beginning
; at that position hex to ASCII.
; This subroutine expects a normal one-byte cursor-positioning code, 0xhh, and
; a null byte at the end of the string 0x00
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

DisplayC
        bcf   LATB,4		;Drive RS pin low for cursor positioning code
        tblrd*			;Get byte from string into TABLAT
        movf  TABLAT,F          ;Check for leading zero byte
        bnz	Loop5
        tblrd+*                 ;If zero, get next byte
Loop5
	movlw 0xF0
	andwf LATB,F		;Clear RB0:RB3, which are used to send LCD data
        bsf   LATB,5            ;Drive E pin high
        movf TABLAT,W		;Move byte from table latch to working register
	andlw 0xF0		;Mask to get only upper nibble
	swapf WREG,W		;swap so that upper nibble is in right position to move to LATB (RB0:RB3)
	iorwf PORTB,W		;Mask to include the rest of PORTB
	movwf LATB		;Send upper nibble out to LATB
        bcf   LATB,5            ;Drive E pin low so LCD will accept nibble
	
	movlw 0xF0
	andwf LATB,F		;Clear RB0:RB3, which are used to send LCD data
        bsf   LATB,5            ;Drive E pin high again
        movf TABLAT,W		;Move byte from table latch to working register
	andlw 0x0F		;Mask to get only lower nibble
	iorwf PORTB,W		;Mask to include the rest of PORTB
	movwf LATB		;Send lower nibble out to LATB
        bcf   LATB,5            ;Drive E pin low so LCD will accept nibble
        rcall T50               ;Wait 50 usec so LCD can process
	
        bsf   LATB,4            ;Drive RS pin high for displayable characters
        tblrd+*                 ;Increment pointer, then get next byte
        movf  TABLAT,F          ;Is it zero?
        bnz	Loop5
        return
	
;;;;;;; DisplayV subroutine ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; THIS SUBROUTINE WAS BORROWED FROM THE LAB 4 EXAMPLE CODE
;
; DisplayV taken from Reference: Peatman CH7 LCD
; This subroutine is called with FSR0 containing the address of a variable
; display string.  It sends the bytes of the string to the LCD.  The first
; byte sets the cursor position.  The remaining bytes are displayed, beginning
; at that position.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	

DisplayV
        bcf     LATB,4          ;Drive RS pin low for cursor positioning code
Loop6
	movlw 0xF0
	andwf LATB,F		;Clear RB0:RB3, which are used to send LCD data
        bsf   LATB,5            ;Drive E pin high
        movf INDF0,W		;Move byte from table latch to working register
	andlw 0xF0		;Mask to get only upper nibble
	swapf WREG,W		;swap so that upper nibble is in right position to move to LATB (RB0:RB3)
	iorwf PORTB,W		;Mask to include the rest of PORTB
	movwf LATB		;Send upper nibble out to LATB
        bcf   LATB,5            ;Drive E pin low so LCD will accept nibble
	
	movlw 0xF0
	andwf LATB,F		;Clear RB0:RB3, which are used to send LCD data
        bsf   LATB,5            ;Drive E pin high again
        movf INDF0,W		;Move byte from table latch to working register
	andlw 0x0F		;Mask to get only lower nibble
	iorwf PORTB,W		;Mask to include the rest of PORTB
	movwf LATB		;Send lower nibble out to LATB
        bcf   LATB,5            ;Drive E pin low so LCD will accept nibble
        rcall T50               ;Wait 50 usec so LCD can process
	  
        bsf   LATB,4            ;Drive RS pin high for displayable characters
        movf  PREINC0,W         ;Increment pointer, then get next byte
        bnz	Loop6
        return	
	
Bignum10ms  equ	65536-40000
Wait10ms
        btfss 	INTCON,TMR0IF           ; Read Timer0 rollover flag and ...
        bra     Wait10ms                ; Loop if timer has not rolled over
        MOVLF  	high Bignum10ms,TMR0H       ; Then write the timer values into
        MOVLF  	low Bignum10ms,TMR0L        ; the timer high and low registers
        bcf  	INTCON,TMR0IF           ; Clear Timer0 rollover flag
        return
;;;;;;; Constant strings ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
LCDstr  db  0x33,0x32,0x28,0x01,0x0c,0x06,0x00  ;Initialization string for LCD
BYTE_1  db  "\x80BYTE=   \x00"         ;Write "BYTE=" to first line of LCD
LCDcl   db  "\x80ASEN 5067   \x00"
LCDs    db  "\x80Hello\x00"
LCDs2   db  "\0xC0World!\0x00"
;;;;;;; End of Program ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        end
