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

        cblock  0x000		; Beginning of Access RAM
	Bignum1high		;Define variables that can be changed throughout the program
	Bignum1low
	Bignum2high
	Bignum2low
	deltabn1high
	deltabn1low
	deltabn2high
	deltabn2low
	temphigh
	templow
        COUNT			; Counter available as local to subroutines
        ALIVECNT		; Counter for blinking "Alive" LED
        BYTE			; Byte to be displayed
        BYTESTR:10		; Display string for binary version of BYTE
	PWMDISP:11		;Display string for pwn value
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
        RCALL	Wait250ms	;Toggle RD4, i.e. 'alive' LED
	RCALL	lowloop		;Set timer for duration of low portion of PWM	
	RCALL	Check_SW1	;Check if RD3 has been pushed	
        ;DISPLAY WREG
	
				; Add operand to finish the use of this macro 
	bra  Loop		; Main loop should run forever after entry

;;;;;;; Initial subroutine ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; This subroutine performs all initializations of variables and registers.

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
	;MOVLF	low 0x6B90,Bignum1
	;MOVLF	high 0x6B90,Bignum1+1
	;MOVLF	low 0xF060,Bignum2
	;MOVLF	high 0xF060,Bignum2+1
deltabn1    equ	D'400'	
deltabn2    equ	D'800'    
on	equ	0x12			;Define necessary values and place them in proper program memory locations
	MOVLF	D'0',on
pwmcount    equ	0x14
	MOVLF	D'0',pwmcount
;reg4	equ	0x07	
	MOVLF	high Bignum1,Bignum1high
	MOVLF	low Bignum1,Bignum1low
	MOVLF	high Bignum2,Bignum2high
	MOVLF	low Bignum2,Bignum2low
	MOVLF	high deltabn1,deltabn1high
	MOVLF	low deltabn1,deltabn1low
	MOVLF	high deltabn2,deltabn2high
	MOVLF	low deltabn2,deltabn2low
	;MOVF	high Bignum2
	MOVLF   B'00000000',INTCON
        MOVLF   B'10000101',T0CON       ; Set up Timer0 for a delay of 1 s
        MOVLF   high Bignum,TMR0H       ; Writing binary 25536 to TMR0H / TMR0L
        MOVLF   low Bignum,TMR0L
	
	MOVLF	B'11000000',TRISB
	MOVLF	B'00001000',TRISD; Set TRISD 
	MOVLF	B'00000000',TRISC; Set TRISC 
	MOVLF	B'00000000',LATD; Turn off all LEDS
	MOVLF	B'00000000',LATC
	MOVLF	B'00000000',LATB
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
	
	MOVLF   B'00000000',INTCON
        MOVLF   B'10000011',T0CON       ; Set up Timer0 for a delay of 250 ms
        MOVLF   high Bignum,TMR0H       ; Writing binary 25536 to TMR0H / TMR0L
        MOVLF   low Bignum,TMR0L
	
	MOVLF	B'00000000',PIR1	;Set up timers 1,3, and 5 for use in program
	MOVLF	B'00000000',PIR2
	MOVLF	B'00010011',T1CON
	MOVLF	B'00000011',T3CON
	MOVLF	B'00000011',T5CON
	
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
L4
        decf  COUNT,F
        bnz	L4
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
;;;;;;; Wait1s subroutine ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; THIS SUBROUTINE WAS BORROWED FROM THE LAB 4 EXAMPLE CODE
;
; Subroutine to wait 1 second
		
Bignum  equ     65536-62500		;Used prescalar of 64
		    
  
Wait1s
        btfss 	INTCON,TMR0IF           ; Read Timer0 rollover flag and ...
        bra     Wait1s                  ; Loop if timer has not rolled over
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
        ;bra     Wait250ms              ; Loop if timer has not rolled over
        MOVLF  	high Bignum,TMR0H       ; Then write the timer values into
        MOVLF  	low Bignum,TMR0L        ; the timer high and low registers
        bcf  	INTCON,TMR0IF           ; Clear Timer0 rollover flag
        return
Bignum10ms  equ	65536-40000
Wait10ms
        btfss 	INTCON,TMR0IF           ; Read Timer0 rollover flag and ...
        bra     Wait10ms                ; Loop if timer has not rolled over
        MOVLF  	high Bignum10ms,TMR0H       ; Then write the timer values into
        MOVLF  	low Bignum10ms,TMR0L        ; the timer high and low registers
        bcf  	INTCON,TMR0IF           ; Clear Timer0 rollover flag
        return
	
Bignum1 equ	65536-38000
lowloop					;Uses prescalar of 2
	btfss 	PIR1,TMR1IF           ; Read Timer1 rollover flag and ...
	return
	MOVLF	B'00000100',LATC
	MOVFF  	Bignum2high,TMR3H      ; Then write the timer values into
        MOVFF  	Bignum2low,TMR3L       ; the timer high and low registers
	bcf	PIR2,TMR3IF
	rcall	highloop
        ;bra     lowloop                     ; Loop if timer has not rolled over
	;MOVLF	B'00000100',LATC
        ;MOVLF  	high Bignum1,TMR1H      ; Then write the timer values into
        ;MOVLF  	low Bignum1,TMR1L       ; the timer high and low registers
        bcf  	PIR1,TMR1IF           ; Clear Timer1 rollover flag
	;MOVLF	B'00000001',T3CON
	;rcall	highloop
        return
Bignum2 equ	65536-4000	
highloop
	btfss	PIR2,TMR3IF
	bra	highloop
	MOVLF	B'00000000',LATC        ; Read Timer3 rollover flag and ...
		                        ; Loop if timer has not rolled over
        MOVFF  	Bignum1high,TMR1H      ; Then write the timer values into
        MOVFF  	Bignum2low,TMR1L       ; the timer high and low registers
			                ; Clear Timer3 rollover flag
        return
	;btfss	PIR2,TMR3IF
	;bra	highloop
	;MOVLF	B'00000000',LATC        ; Read Timer3 rollover flag and ...
		                        ; Loop if timer has not rolled over
        ;MOVLF  	high Bignum1,TMR1H      ; Then write the timer values into
        ;MOVLF  	low Bignum1,TMR1L       ; the timer high and low registers
			                ; Clear Timer3 rollover flag
        ;return
	
Check_SW1
	;BRA	pwmc
	BTFSS	PORTD,3	; Add code here
	BRA	ds
	BTFSC	on,3
	BRA	ds
	MOVLF  	high Bignum3,TMR5H       ; Then write the timer values into
        MOVLF  	low Bignum3,TMR5L   
	RCALL	Debounce
	MOVLF	B'00001000',on
ds
	MOVF	PORTD,0	
	ANDLW	B'00001000'
	SUBWF	on,0
	BTFSC	WREG,3
	RCALL	pwmc
		return
Bignum3	equ	65536-60000		
Debounce
	btfss 	PIR5,TMR5IF           ; Read Timer0 rollover flag and ...
	bra Debounce
			              ; Loop if timer has not rolled over
        ;MOVLF  	high Bignum3,TMR5H       ; Then write the timer values into
        ;MOVLF  	low Bignum3,TMR5L        ; the timer high and low registers
        bcf  	PIR5,TMR5IF           ; Clear Timer0 rollover flag
        return
		;return

;Subroutine to increase duty cycle of PWM by adding 0.2ms to the high portion and subtracting 0.2ms from the low portion to keep the 
;period constant at 20ms		
pwmc
	BTG	LATD,2		    ;If RD3 is pressed and released, increment the high portion of pwm by 0.2ms
	;MOVLW	B'00000100'	    ;and decrement low portion of pwm by 0.2ms
	;cpfslt	pwmcount,0
	;bra	qr
	;clrf	WREG
	;MOVLW	B'00000101'
	;cpfslt	pwmcount,0
	;bra	ps
	MOVF	Bignum1low,0
	ADDWF	deltabn1low,0
	MOVWF	Bignum1low,0
	MOVF	Bignum1high,0
	ADDWFC	deltabn1high,0
	MOVWF	Bignum1high,0
	MOVF	deltabn2low,0
	SUBWF	Bignum2low,0
	MOVWF	Bignum2low,0
	MOVF	Bignum2high,0
	SUBFWB	deltabn2high,0
	MOVWF	Bignum2high,0
	MOVLW	B'00000100'	    ;Check if the pwm is ready to be reset to high for 1ms and low for 19ms yet
	cpfslt	pwmcount,0
	bra	qr
	INCF	PWMDISP+6,F
	INCF	PWMDISP+6,F
	LFSR	0,PWMDISP
	rcall	DisplayV
	INCF	pwmcount,1
	CLRF	on
	return
	
qr
	cpfseq	pwmcount,0	    ;Adusting LCD to change from 1.80 to 2.00 when appropriate
	bra	ps
	INCF	PWMDISP+4
	MOVLF	0x30,PWMDISP+6
	MOVLF	0x30,PWMDISP+6
	LFSR	0,PWMDISP
	rcall	DisplayV
	INCF	pwmcount,1
	clrf	on
	return
ps
	MOVLF	high Bignum1,Bignum1high    ;Reset pwm to 1ms high and 19ms low from 2ms high and 18ms low
	MOVLF	low Bignum1,Bignum1low
	MOVLF	high Bignum2,Bignum2high
	MOVLF	low Bignum2,Bignum2low
	MOVLF	0x31,PWMDISP+4
	LFSR	0,PWMDISP   
	rcall	DisplayV
	clrf	pwmcount
	clrf	on
	return
										;THIS SUBROUTINE WAS BORROWED FROM THE LAB 4 EXAMPLE CODE
ByteDisplay
        POINT   LCDcl                 ;Display "BYTE="
        rcall   DisplayC
        lfsr    0,BYTESTR+8
L10
          clrf  WREG
          rrcf  BYTE,F                 ;Move bit into carry
          rlcf  WREG,F                 ;and from there into WREG
          iorlw 0x30                   ;Convert to ASCII
          movwf POSTDEC0               ; and move to string
          movf  FSR0L,W                ;Done?
          sublw low BYTESTR
        bnz	L10

        lfsr    0,BYTESTR              ;Set pointer to display string
        MOVLF   0xc0,BYTESTR           ;Add cursor-positioning code
        clrf    BYTESTR+9              ;and end-of-string terminator
        rcall   DisplayV
        return
;;;;;;; Constant strings ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
LCDstr  db  0x33,0x32,0x28,0x01,0x0c,0x06,0x00  ;Initialization string for LCD
BYTE_1  db  "\x80BYTE=   \x00"         ;Write "BYTE=" to first line of LCD
LCDcl   db  "\x80ASEN 5067   \x00"
LCDs    db  "\x80Hello\x00"
LCDs2   db  "\xC0World!\x00"
;;;;;;; End of Program ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        end
