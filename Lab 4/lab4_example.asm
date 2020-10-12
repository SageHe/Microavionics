;;;;;;; ASEN 4-5519 Lab 4 Example code ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   ____ THIS IS **NOT** A TEMPLATE TO USE FOR LAB 4 _____
;
;   .... THIS CODE PROVIDES EXAMPLE FUNCTIONALITY ....
;
;   .... THE TIMING IN THIS CODE IS DIFFERENT THAN REQUIRED FOR LAB 4 ....
;
;   .... USE YOUR LAB 3 SOURCE FILE AS A STARTING POINT FOR LAB 4 ...
; 
;   .... YOU MAY REUSE PARTS OF THIS CODE (ESPECIALLY THE LCD FUNCTIONS!)
;	 IF THEY SUIT YOUR PURPOSE, BUT GIVE CREDIT IN YOUR COMMENTS FOR 
;	 ANY CODE YOU USE FROM HERE
;        FOR EXAMPLE (;   This subroutine is copied (or a modified version) of 
;                     ;   the subroutine XXX in the lab4_example.asm file)
;
; 
;
; NOTES:
;   ~1 second means +/- 10msec, ~250 ms means +/- 10msec
;   Use Timer 0 for looptime timing requirements
;;;;;;; Program hierarchy ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Mainline
;   Initial
;      BlinkAlive
;      LoopTime
;
;;;;;;; Assembler directives ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        LIST  P=PIC18F87K22, F=INHX32, C=160, N=0, ST=OFF, MM=OFF, R=DEC, X=ON
        #include P18F87K22.inc

;		MPLAB 7.20 and later configuration directives
;		Select "Configuration Bits set in code" to use the following configuration
		CONFIG	FOSC = HS1, XINST = OFF
		CONFIG	PWRTEN = ON, BOREN = ON, BORV = 1
		CONFIG 	WDTEN = OFF
		CONFIG	CCP2MX = PORTC

;;;;;;; Variables ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        cblock  0x000		; Beginning of Access RAM
        COUNT			; Counter available as local to subroutines
        ALIVECNT		; Counter for blinking "Alive" LED
        BYTE			; Byte to be displayed
        BYTESTR:10		; Display string for binary version of BYTE
        endc

;;;;;;; Macro definitions ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

MOVLF   macro  literal,dest		; Move literal to file macro
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

        org  0x0000                    ; Reset vector
        nop 
        goto  Mainline

        org  0x0008                    ; High priority interrupt vector
        goto  $                        ; Return to current program counter

        org  0x0018                    ; Low priority interrupt vector
        goto  $                        ; Return to current program counter

;;;;;;; Mainline program ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

Mainline
        rcall   Initial			; Initialize everything
Loop
        btg LATC,RC2			; Toggle pin, to support measuring loop time
        rcall BlinkAlive		; Blink "Alive" LED
        movlw B'10101111'		
        DISPLAY WREG
        rcall   Wait10ms                ; Delay ten milliseconds
        bra     Loop

;;;;;;; Initial subroutine ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; This subroutine performs all initializations of variables and registers.
;
; NOTE: When setting up Ports, always initialize the respective Lat register
;       to a known value!
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

Initial
        MOVLF   B'11000000',TRISB       ; Set I/O for PORTB
        MOVLF   B'00000000',LATB        ; Initialize PORTB
        MOVLF   B'00000000',TRISC       ; Set I/0 for PORTC
        MOVLF   B'00000000',LATC        ; Initialize PORTC
	MOVLF   B'00000000',TRISD	; Set I/O for PORTD
	MOVLF   B'00000000',LATD	; Initialize PORTD

        MOVLF   B'00000000',INTCON
        MOVLF   B'00001000',T0CON       ; Set up Timer0 for a delay of 10 ms
        MOVLF   high Bignum,TMR0H       ; Writing binary 25536 to TMR0H / TMR0L
        MOVLF   low Bignum,TMR0L	; Write high byte first, then low!

        MOVLF   D'250',ALIVECNT         ; Initializing Alive counter
        bsf     T0CON,7                 ; Turn on Timer0

        rcall   InitLCD                 ; Initialize LCD
        rcall   Wait10ms		; 10 ms delay subroutine

        POINT   LCDs                    ; Hello
        rcall   DisplayC		; Display character subroutine
        POINT   LCDs2                   ; World!
        rcall   DisplayC

        return

;;;;;;; InitLCD subroutine ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
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
	

;;;;;;; T50 subroutine ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
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

;;;;;;;;DisplayC subroutine;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
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
	
;;;;;;; DisplayV subroutine ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
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

        
;;;;;;; BlinkAlive subroutine ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; This subroutine briefly blinks the LED RD4 every two-and-a-half
; seconds.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

BlinkAlive
        bcf     LATD,RD4       ; Turn off LED
        decf    ALIVECNT,F      ; Decrement loop counter and ...
        bnz     END1            ; return if not zero
        MOVLF   250,ALIVECNT    ; Reinitialize BLNKCNT
        bsf     LATD,RD4       ; Turn on LED for ten milliseconds every 2.5 sec
END1
        return

;;;;;;; LoopTime subroutine ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; This subroutine waits for Timer0 to complete its ten millisecond count
; sequence. It does so by waiting for sixteen-bit Timer0 to roll over. To obtain
; a period of 10ms/250ns = 40000 clock periods, it needs to remove
; 65536-40000 or 25536 counts from the sixteen-bit count sequence.  
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

Bignum  equ     65536-40000

Wait10ms
        btfss 	INTCON,TMR0IF           ; Read Timer0 rollover flag and ...
        bra     Wait10ms                ; Loop if timer has not rolled over
        MOVLF  	high Bignum,TMR0H       ; Then write the timer values into
        MOVLF  	low Bignum,TMR0L        ; the timer high and low registers
        bcf  	INTCON,TMR0IF           ; Clear Timer0 rollover flag
        return

;;;;;;; ByteDisplay subroutine ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Display whatever is in BYTE as a binary number.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	
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
