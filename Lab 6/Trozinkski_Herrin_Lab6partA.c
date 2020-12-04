/****** ASEN 4/5067 Lab 6 ******************************************************
 * Author: Ted Trozinski and Sage Herrin
 * Date Created : Nov 5, 2020
 * Date Modified: Nov 10, 2020
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
// #include <stdbool.h>


#define _XTAL_FREQ 16000000   //Required in XC8 for delays. 16 Mhz oscillator clock
#pragma config FOSC=HS1, PWRTEN=ON, BOREN=ON, BORV=2, PLLCFG=OFF
#pragma config WDTEN=OFF, CCP2MX=PORTC, XINST=OFF

/******************************************************************************
 * Global variables
 ******************************************************************************/
const char LCDRow1[] = {0x80,'T','E','S','T','I','N','G','!',0x00};
unsigned int Alive_count = 0; //
unsigned long ccp1count = 400000; // w/no prescaler, count this many for 100ms wait
unsigned int TMR1X = 0; // timer 1 extension, start at zero, will move in later. 
unsigned int CCPR1X = 0; // 
unsigned int LM35channel = 0b00011;
unsigned int P2channel = 0b00000; 
unsigned int samplecount = 0;
unsigned int ADresult;  // result of AD Conversion
unsigned int LM35result;
float Temp;
float Potential;
unsigned int P2result;
unsigned int wregtemp = 0;  // for lopri isr, holds value of WREG
unsigned int done = 0;
float Cscalefactor = 0.080566; // scale factor for Volts 
float vscalefactor = 0.00080566; //volts per bin
char temperature[10];  // from lecture 14, string is 8 char array
char voltage[10];  // similar to what was in lecture, string for voltage display


/******************************************************************************
 * Function prototypes
 ******************************************************************************/
void Initial(void);         // Function to initialize hardware and interrupts
void TMR0handler(void);     // Interrupt handler for TMR0, typo in main
void sample(void);            // Interrupt handler for CCP1, typo in main
void tempC(void);               // conversion function for lm35 to Celsius
void volts(void);                // conversion function for P2


/******************************************************************************
 * main()
 ******************************************************************************/
void main() {
     Initial();                 // Initialize everything
      while(1) {
        // Sit here for ever
        // 1. Sample LM35
        ADCON0bits.CHS = LM35channel; // 00011 for A03, correct channel chosen for LM35
        sample(); //the AD converter
        LM35result = ADresult;
        // 2. Sample Potentiometer
        ADCON0bits.CHS = P2channel;
        sample();
        P2result = ADresult;
        // 3. Convert Values:
        //      a. Convert LM35 result to Celsius, then to ASCII
        tempC(); // tempC converts the converted binary into temp
        //      b. Convert P2 to ASCII
        volts(); // volts converts bin output from adc to volts
        // 4. Display on LCD
        DisplayC(temperature);
        DisplayC(voltage);
        // repeat. 
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

    // Configure Analog to Digital Converter: pg 361 
    // i. Configure required ADC Pins as analog pins: ANCON0, ANCON1, ANCON2
    //      b. P2->PORTA, set portA to analog (RA0 Orange Capped)
    //ANCON0 = 0b00001000; // all ones, therefore all analog
    ANCON0 = 0x01;
    ANCON1 = 0x00;
    ANCON2 = 0x00; 
    //      c. Now set TRIS for all of these to be inputs
    TRISAbits.TRISA0 = 1;  // Set trisa 0 to input
    TRISAbits.TRISA3 = 1;  //
    // WHAT OTHER TRIS STUFF DO I NEED?
    // ii. set the reference voltage-- ADCON1
    ADCON1 = 0b00000000; // per lecture ADCON1 cleared. 
    // iii. Select the A/D positive and Negative input channels ADCON0 and ADCON1
    //      - can only use one pin at a time, ADCON0 bits 6-2, which one for P2?
    //ADCON0bits.CHS = 0b00011; // 00011 for A03, LM35
    //ADCON0bits.CHS = 0b00000; // selects channel, 0 through 23... P2 is A0
    ADCON0 = 0b00001101; // set up initially for AN3, 
    // set the A/D acquisition time ADCON2
    ADCON2bits.ADFM = 0b1; // sets to right justified.
    // timing: Tacq = Tamp + Tc + Toff
    //         Tacq = 0.2mus + Tc + 0 --> no toff, yet. 
    //         using Tacq = 16tosc 101
    ADCON2bits.ACQT = 0b010; // acquisition time 4Tad
    // iv. Set A/D Conversion clock: ADCON2
    ADCON2bits.ADCS = 0b101; // FOSC/16
    ADCON2 = 0b10010101; // b7: right justified, b5-3: 4tad, b2-0: Tosc/16
    // Set up A/D interrupt:
    PIR1bits.ADIF = 0; // from pg 362 in PIC datasheet. bit6, interrupt flag bit
    PIE1bits.ADIE = 0; // enables interrupts from A/D conversion
    IPR1bits.ADIP = 0; // sets AD conversion interrupt flag to low priority
    
    
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
    LATDbits.LATD5 = 0;// DEBUGGING ONLY
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
    wregtemp = WREG;
    while(1) {
        if( INTCONbits.TMR0IF ) {
            TMR0handler();
            continue;
        }
//        if( PIR1bits.ADIF ) {
//            // is the ADC done? if yes, do this:
//            // sets done variable equal to 1, will break the while loop
//            done = 1;
//            PIR1bits.ADIF = 0; // clear the A/D conversion interrupt flag
//            continue;
//        }
        // Save temp copies of WREG, STATUS and BSR if needed.
            WREG = wregtemp;
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

    
/******************************************************************************
 * sample subroutine performs necessary steps to check value of channel connected to adc
 *
 * Reads whatever comes into the adc, channel selected outside in main function.
 * Some lines, including while loop, come from PIC datasheet pg. 393 (ADC used in an example)
 ******************************************************************************/

void sample()
{
    // go on AD converter 
    for(samplecount = 0; samplecount<3; samplecount++) {
        // delay and wait x microseconds
        __delay_us(50); // allows capacitor to charge (for voltage comparison)
        // 1. start AD Conversion
        ADCON0bits.GO = 1; // set ADCON0 go bit to 1, starts conversion from selected channel.
        // 2. wait for interrupt
        //while(done == 0){
        //while(!PIR1bits.ADIF){}
        while(ADCON0bits.GO);
        __delay_us(50);
        // waits until flag is thrown signaling ADC is done
        // above line was found from datasheet pg 393.    <- not the current iteration
            // do nothing, wait here until interrupt sets done = 1
        // 3. get result
        ADresult = ADRES; // from datasheet pg 393 A/D example
    }
    
}

/******************************************************************************
 * tempC subroutine converts ADC output to Celsius
 *
 * Convert voltage to Celsius
 ******************************************************************************/

void tempC()
{
    // Resolution of 12 bit result: (right justified) 2^12 = 4096
    // ADC volts per bin: 3.3V/4096 bins = 0.00080566V/bin -> ADC
    // adc output = bin#, 
    // want: voltage: 3.3/4096[V/bin] * output[bin] = [V]
    // [V]*1/[V/C_lm35] = output
    // temperature = LM35result * 3.3/4096[V/bin] * 1/((0.01)[V/C]) = 0.0806554
    Temp = Cscalefactor * LM35result;
    // convert type double Temp to 3 strings:
    sprintf(temperature, " T=%0.1fC ", Temp);
    temperature[0] = 0x80;
    // conversion fro float to string based on code found at following 
    // web address:
    // https://stackoverflow.com/questions/8257714/how-to-convert-an-int-to-string-in-c
}

void volts()
{
    //adc output = bin#
    //want: voltage: -> bin# * voltage/bin# -> bin# * (3.3/2^12)
    Potential = P2result * vscalefactor;
    sprintf(voltage," PT=%0.2f",Potential);
    voltage[0] = 0xC0;
}