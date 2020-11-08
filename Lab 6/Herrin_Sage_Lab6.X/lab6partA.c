
/****** ASEN 4/5067 Lab 6 ******************************************************
 * Author: Ted Trozinski and Sage Herrin
 * Date Created : Nov 5, 2020
 * Date Modified: Nov 5, 2020
 *
 * Updated for XC8
 * 
 * Description
 * On power up execute the following sequence:
 *      RD5 ON for 0.5s +/- 10ms then off
 *      RD6 ON for 0.5s +/- 10ms then off
 *      RD7 ON for 0.5s +/- 10ms then off
 * The following then occurs forever:
 *      RD4 blinks: 100ms +/- 10ms ON, then 900ms +/- 10ms OFF
 *      LCD Displays the following lines:
 *          'T=xx.x C'
 *          'PT=x.xxV'
 *      Where the 'x' is replaced by a digit in the measurement.
 *          Temperature data must be calculated / displayed with one digit to
 *          the right of the decimal as shown.  The sensor itself can have
 *          errors up to +/- 5 degrees Celsius.
 *          Potentiometer data must be calculated / displayed with two digits
 *          to the right of the decimal as shown.
 *          These measurements must be refreshed at LEAST at a frequency of 5Hz.
 *      USART Commands are read / executed properly. '\n' is a Line Feed char (0x0A)
 *          ASEN 4067:
 *              'TEMP\n'     - Transmits temperature data in format: 'XX.XC'
 *              'POT\n'      - Transmits potentiometer data in format: X.XXV'
 *          ASEN 5067: Same as ASEN 4067, plus two additional commands
 *              'CONT_ON\n'  - Begins continuous transmission of data over USART
 *              'CONT_OFF\n' - Ends continuous transmission of data over USART
 *
 *              Continuous transmission should output in the following format:
 *                  'T=XX.XC; PT = X.XXV\n'
 *      DAC is used to output analog signal onto RA5 with jumper cables. 
 *          ASEN 4067:
 *              Potentiometer voltage is converted from a digital value to analog 
 *              and output on the DAC. 
 *          ASEN 5067: 
 *              A 0.5 Hz 0-3.3V triangle wave is output on the DAC. 
 *******************************************************************************
 *
 * Program hierarchy 
 *
 * Mainline
 *   Initial
 *
 * HiPriISR (included just to show structure)
 *
 * LoPriISR
 *   TMR0handler
 ******************************************************************************/

#include <xc.h>
#include "LCDroutinesEasyPic.h"
#include <string.h>
#include <stdio.h>
#include <stdlib.h>


#define _XTAL_FREQ 16000000   //Required in XC8 for delays. 16 Mhz oscillator clock
#pragma config FOSC=HS1, PWRTEN=ON, BOREN=ON, BORV=2, PLLCFG=OFF
#pragma config WDTEN=OFF, CCP2MX=PORTC, XINST=OFF

/******************************************************************************
 * Global variables
 ******************************************************************************/
const char LCDRow1[] = {0x80,'T','E','S','T','I','N','G','!',0x00};
unsigned int Alive_count = 0; //
unsigned int TMR1count = 53036; //count with 16 prescale for 100ms

/******************************************************************************
 * Function prototypes
 ******************************************************************************/
void Initial(void);         // Function to initialize hardware and interrupts
void TMR0handler(void);     // Interrupt handler for TMR0, typo in main

/******************************************************************************
 * main()
 ******************************************************************************/
void main() {
     Initial();                 // Initialize everything
      while(1) {
        // Sit here for ever
        // initial:
            // Set ADCON Registers
            // Set timers to determine when to sample each (LM35 and P2)
        // 1. Sample LM35
            // at least 
        // 2. Sample Potentiometer
        // 3. ADC Conversion:
            // a. LM35 Conversion
            // b. Potentiometer Conversion
        // 3. Display on LCD
        //      - set a CCP in compare mode, writes values to LCD 100ms
        //      - if cases for if value has changed
          
        // TO DO:
            // - make timer for 1 micro second (waits for proper ADC readiness)
            // - 
     }
}

/******************************************************************************
 * Initial()
 *
 * This subroutine performs all initializations of variables and registers.
 * It enables TMR0 and sets CCP1 for compare, and enables LoPri interrupts for
 * both.
 ******************************************************************************/
void Initial() {
    // Set the BSR, before we forget
    BSR = 0x0F; // for ANCON registers
    // Configure the IO ports
    TRISD  = 0b00001111;
    LATD = 0;
    TRISC  = 0b10010011;
    LATC = 0;
    
    // Configure the LCD pins for output. Defined in LCDRoutines.h
    LCD_RS_TRIS   = 0;              // 
    LCD_E_TRIS    = 0;
    LCD_DATA_TRIS = 0b11000000;     // Note the LCD is only on the upper nibble
                                    // The lower nibble is all inputs
    LCD_DATA_LAT = 0;           // Initialize LCD data LAT to zero


    // Initialize the LCD and print to it
    InitLCD();
    DisplayC(LCDRow1);

    // Configure ADC stuff: pg 361
    // i. Configure required ADC Pins as analog pins: ANCON0, ANCON1, ANCON2
    //      b. P2->PORTA, set portA to analog (RA0 Orange Capped)
    ANCON0 = 0xFF; // all ones, therefore all analog
    ANCON1 = 0xFF;
    ANCON2 = 0xFF; 
    //      c. Now set TRIS for all of these to be inputs
    TRISAbits.TRISA0 = 1;  // Set trisa 0 to input
    TRISAbits.TRISA3 = 1;  //
    // WHAT OTHER TRIS STUFF DO I NEED?
    // ii. set the reference voltage-- ADCON1
    ADCON1bits.VCFG = 0b00; // per lecture (default)
    ADCON1bits.VNCFG = 0b0; // ditto^
    ADCON1bits.CHSN = 0b000; // analog negative channel select bits
    // iii. Select the A/D positive and Negative input channels ADCON0 and ADCON1
    //      - can only use one pin at a time, ADCON0 bits 6-2, which one for P2?
    ADCON0bits.CHS = 0b00011; // 00011 for A03, LM35
    ADCON0bits.CHS = 0b00000; // selects channel, 0 through 23... P2 is A0
    // set the A/D acquisition time ADCON2
    ADCON2bits.ADFM = 0b1; // sets to right justified.
    // timing: Tacq = Tamp + Tc + Toff
    //         Tacq = 0.2mus + Tc + 0 --> no toff, yet. 
    //         using Tacq = 16tosc 101
    ADCON2bits.ACQT = 0b010; // acquisition time 4Tad
    // iv. Set A/D Conversion clock: ADCON2
    ADCON2bits.ADCS = 0b101; // FOSC/16
    
    
    // Initializing TMR0
    T0CON = 0b01001000;             // 8-bit, Fosc / 4, no pre/post scale timer
    TMR0L = 0;                      // Clearing TMR0 registers
    TMR0H = 0;

    // Configuring Interrupts
    RCONbits.IPEN = 1;              // Enable priority levels
    INTCON2bits.TMR0IP = 0;         // Assign low priority to TMR0 interrupt

    INTCONbits.TMR0IE = 1;          // Enable TMR0 interrupts
    INTCONbits.GIEL = 1;            // Enable low-priority interrupts to CPU
    INTCONbits.GIEH = 1;            // Enable all interrupts

    T0CONbits.TMR0ON = 1;           // Turning on TMR0
    
    // configure ccp1 to use tmr1
    T1CON = 0b00000011;
    CCP1CON = 0b00001010;
    CCPTMRS0 = 0b00000000;
    // Enable interrupt priorities
    IPR1bits.TMR1IP = 0;
    IPR3bits.CCP1IP = 0;
    // create extension byte for timer1
    unsigned int TMR1X = 0;
    
    
    
    
    
    
    
}

/******************************************************************************
 * HiPriISR interrupt service routine
 *
 * Included to show form, does nothing
 ******************************************************************************/

void __interrupt() HiPriISR(void) {
    
}	// Supports retfie FAST automatically

/******************************************************************************
 * LoPriISR interrupt service routine
 *
 * Calls the individual interrupt routines. It sits in a loop calling the required
 * handler functions until until TMR0IF and CCP1IF are clear.
 ******************************************************************************/

void __interrupt(low_priority) LoPriISR(void) 
{
    // Save temp copies of WREG, STATUS and BSR if needed.
    while(1) {
        if( INTCONbits.TMR0IF ) {
            TMR0handler();
            // Call CCP other handler
            // 
            
            continue;
        }
        // Save temp copies of WREG, STATUS and BSR if needed.
        break;      // Supports RETFIE automatically
    }
}


/******************************************************************************
 * TMR0handler interrupt service routine.
 *
 * Handles Alive LED Blinking via counter
 ******************************************************************************/
void TMR0handler() {
    if( Alive_count < 4880 ) { Alive_count++; }
    else {
        LATDbits.LATD4 = ~LATDbits.LATD4;
        Alive_count = 0;
    }
    INTCONbits.TMR0IF = 0;      //Clear flag and return to polling routine
}
