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
unsigned int ONcount;
unsigned int OFFcount;
unsigned int LEDcount;
float Temp;
float Potential;
unsigned int P2result;
unsigned int wregtemp = 0;  // for lopri isr, holds value of WREG
unsigned int done = 0;
float Cscalefactor = 0.080566; // scale factor for Volts 
float vscalefactor = 0.00080566; //volts per bin
char temperature[10];  // from lecture 14, string is 8 char array
char voltage[10];  // similar to what was in lecture, string for voltage display
unsigned char throwout; // temporary variable 
char RBuffer[20]; // array to store received letters
char TBuffer[20]; // array to store letters to be sent
unsigned int bcount = 0; // counter for rbuffer
unsigned int tcount = 0; // counter for TBuffer
unsigned int commandready = 0; // global flag indicating command is ready to be understood
unsigned int continuousMode = 0; // indicator for continuous transmission
unsigned int transmittime = 0; // indicates time to transmit cont. message
char garbage;
unsigned int binnum = 0x3000;
char inc = 1;
char dec = 0;



/******************************************************************************
 * Function prototypes
 ******************************************************************************/
void Initial(void);         // Function to initialize hardware and interrupts
void TMR0handler(void);     // Interrupt handler for TMR0, typo in main
void sample(void);          // Interrupt handler for CCP1, typo in main
void tempC(void);           // conversion function for lm35 to Celsius
void volts(void);           // conversion function for P2
void LEDhandler(void);      // function turns on the right LED
void transmit(void);        // function handles transmission over EUSART1
void receive(void);         // function handles reception over EUSART1
void decoder(void);         // function determines the proper message to send back
void SPItransmission(void);


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
        // 5. Check for completed reception:
        if(commandready == 1){
            decoder(); // call decoder function
        }
        // 6. Check to see if continuous is enabled, then check for timer overflow
        if(continuousMode == 1){
            decoder();
        }
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
    TRISC  = 0b10010011; // set for EUSART1 check .
    LATC = 0;
    TRISA = 0b00101001; //changed bit 5 to input as per piazza post 115
    TRISEbits.TRISE0 = 0;
    
    
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
    ANCON0 = 0x0F;
    ANCON0bits.ANSEL4 = 1;
    ANCON1 = 0x00;
    ANCON2 = 0x00; 
    //      c. Now set TRIS for all of these to be inputs
    //TRISAbits.TRISA0 = 1;  // Set trisa 0 to input
    //TRISAbits.TRISA3 = 1;  //
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
    
    
    // Initialize LED blinking stuff:
    LEDcount = 0;
    ONcount = 3036;
    OFFcount = 3036; // initial counts for 32 prescaler
    
    // Initializing TMR0
    T0CON = 0b00000100;             // 16-bit, Fosc / 4, 32 prescale timer
    TMR0L = 0;                      // Clearing TMR0 registers
    TMR0H = 0;
    
    // Initializing TMR1 for SPI comm
    T1CON = 0b00000010;
    PIR1bits.TMR1IF = 0;
    IPR1bits.TMR1IP = 0;
    PIE1bits.TMR1IE = 1;
    TMR1 = 63692;       

    // Configuring Interrupts
    RCONbits.IPEN = 1;              // Enable priority levels
    INTCON2bits.TMR0IP = 0;         // Assign low priority to TMR0 interrupt

    INTCONbits.TMR0IE = 1;          // Enable TMR0 interrupts
    INTCONbits.GIEL = 1;            // Enable low-priority interrupts to CPU
    INTCONbits.GIEH = 1;            // Enable all interrupts

    T0CONbits.TMR0ON = 1;           // Turning on TMR0 COUNT STARTS HERE
    // wait for a few interrupts
    LATD = 0b00000000;
    while( LEDcount < 4){} // do nothing until the LED routine is done. 
    // Once LEDcount has been flipped to above 4, switch to normal timing
    T0CONbits.T0PS = 0b101; // change prescaler to 64 bit
    ONcount = 59300; // for a 0.1 second on
    OFFcount = 9272; // for a 0.9 second off 
    LATDbits.LATD4 = 0b0;
    
    // SPI/USART Initialization EUSART1
    //      TRANSMIT SETUP, TX ON RC6 IS OUTPUT
    //      & RECEIVE SETUP, RX ON RC7 IS INPUT
    // 1. Configure th TXSTAx register properly
    TXSTA1bits.SYNC = 0b0; // clear for asynchronous
    TXSTA1bits.BRGH = 0b1; // high speed or low speed baud rate
    TXSTA1bits.TXEN = 0b1; // set/enable transmit enable bit
    // 2. Configure Baud Rate Generator (SPBRGx):
    SPBRG = 51; // load 51 into SPBRG with high speed mode, 8 bit
    // 3. Configure the RCSTAx register settings
    RCSTA1bits.SPEN = 0b1; // set SPEN, enable the serial port
    RCSTA1bits.CREN = 0b1; // enable continuous receive
    // 4. OPTIONAL, conigure the interrupt priority (IPR) and enable (PIE))
    IPR1bits.RC1IP = 0b0; // select low priority for EUSART receive interrupt
    IPR1bits.TX1IP = 0b0; // select low priority for EUSART transmit interrupt
    PIE1bits.RC1IE = 0b1; // set high, enable EUSART Receive interrupt
    PIE1bits.TX1IE = 0b0; // set high, enable EUSART Transmit interrupt      NEW PHILOSOPHY THIS IS OFF NOW, ONLY WAITS IN A WHILE LOOP
    // 5. Wait till TXxIF flag is set, (polling or interrupt)
    // 6. Load byte to send into TXREG1
    
    // Configure BAUDCON register:
    BAUDCON1bits.BRG16 = 0b0; // set BRG16, baud rate generator uses 8 bit
    // Configure SPI registers
    SSP1CON1 = 0b00100000; // set so clock is Fosc/4 with this config
    SSP1STAT = 0x00; //zero for now, maybe change later?
    SSP1STATbits.SMP = 1; //input data is sampled at end of data output time 
    SSP1STATbits.CKE = 1;
    
    T1CONbits.TMR1ON = 1;
    
    // Send back to main, initialization complete!
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
        if(PIR1bits.RC1IF ) { // message is in the register
            // call the receive function
            receive();
            PIR1bits.RC1IF = 0b0; // Clear the interrupt flag
            continue;
        }
        if(PIR1bits.TMR1IF){
            //LATDbits.LATD7 = ~LATDbits.LATD7;
            SPItransmission();
            PIR1bits.TMR1IF = 0;
            TMR1 = 63692;
            continue;
        }
//        else{
//            // do nothing, I guess?
//        }
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
    LEDhandler(); // toggles LED4, so this next portion will be backwards
    if( !LATDbits.LATD4){ // led4 has just been turned on, use oncount
        TMR0L = ONcount&0xFF; // load low byte of ONcount
        TMR0H = (ONcount>>8)&0xFF; // load high byte of ONcount
        if(continuousMode == 1){
            transmittime = 1; // indicate its time to transmit the message
        }
    }
    else{ //!LATDbits.LATD4){ // led4 has just been turned off, use offcount
        TMR0L = OFFcount&0xFF; // load low byte of ONcount
        TMR0H = (OFFcount>>8)&0xFF; // load high byte of ONcount
    }
    INTCONbits.TMR0IF = 0; // clear timer flag
}

/******************************************************************************
 * SPI interrupt service routine.
 *
 * Handles timing of SPI communication to DAC Click
 ******************************************************************************/
void SPItransmission(){
    // set CS low so command can be sent to DAC 
    //LATDbits.LATD7 = ~LATDbits.LATD7;
    //unsigned int binnum = (unsigned int)(Potential);
    LATEbits.LATE0 = 0;
    //mask upper byte of Potential with config nibble for SPI comm register (0011)
    SSP1BUF = (binnum>>8)|0b00110000;
    //SSP1BUF = 0b00111111;
    while(!SSP1STATbits.BF){}       // wait for upper byte of potential to be sent to DAC 
    // have to read this, but ADC is 1 way so ignore!
    garbage = SSP1BUF;              // read garbage out of SSP1buf so it is cleared
    
    SSP1BUF = binnum;               // put lower byte of potential into SSP1BUF to be sent to DAC
    //SSP1BUF = 0b11111111;   // for debugging (maxval test)
    while(!SSP1STATbits.BF){}       // wait for lower byte of potential to be sent
    garbage = SSP1BUF;              // read garbage out of SSP1buf so it is cleared
    LATEbits.LATE0 = 1;             // set CS high so transmission stops
    //LATDbits.LATD7 = ~LATDbits.LATD7;  // DEBUGGING
    if(inc & (binnum >= 0x3FFE)){
        inc = 0;
        dec = 1;
}
    if(dec & (binnum <= 0x3000)){
        inc = 1;
        dec = 0;
    }
    if(inc){ // increase mode, so increase the bin number (to increase voltage)
        binnum += 2;
    }
    if(dec){ // we're in decrease mode, so decrement the number!
        binnum -= 2;
    }
}


/******************************************************************************
 * LEDhandler blinks the proper LED
 *
 * 
 ******************************************************************************/

void LEDhandler(){
    if ( LEDcount > 3){
        LATDbits.LATD4 = ~LATDbits.LATD4; // toggle Latd4
    }
    else if ( LEDcount == 3){
        LATD = 0b00010000; // start the alive timing count, turn on 4
        LEDcount = 7; // make LEDcount big so it definitely leaves
    }
    else if ( LEDcount == 2){
        LATD = 0b10000000; // turn on Led7
        LEDcount++;
    }
    else if ( LEDcount == 1){
        LATD = 0b01000000; // turn on Led6, off 7
        LEDcount++;
    }
    else if ( LEDcount == 0){
        LATD = 0b00100000; // turn on LED 5, 6 off
        LEDcount++;
    }
    else { // we have a problem if it gets here...
        LATD = 0b11110000; // will turn on all LEDs on left half of portd
    }
        
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
    // conversion from float to string based on code found at following 
    // web address:
    // https://stackoverflow.com/questions/8257714/how-to-convert-an-int-to-string-in-c
}

// Converts to volts from bin #
void volts()
{
    //adc output = bin#
    //want: voltage: -> bin# * voltage/bin# -> bin# * (3.3/2^12)
    Potential = P2result * vscalefactor;
    sprintf(voltage," PT=%0.2fV",Potential);
    voltage[0] = 0xC0;
}

/******************************************************************************
 * transmit function 
 *
 * Transmits the data!
 ******************************************************************************/
void transmit(){
    LATDbits.LATD7 = 0b1; // 
    while(tcount <= 18){
        while(PIR1bits.TX1IF == 0){} // set when empty, wait till empty
        if(TBuffer[tcount] != 0x00){
            TXREG1 = TBuffer[tcount];
            // increment tcount
            __delay_us(2); // two microsecond delay, just incase TX1IF flag hasnt been set yet
        }
        if(TBuffer[tcount] == 0x00){
            tcount = 18; // will stop the transmission
        }
        tcount++;
    }
    
    
    // Convert byte to 
    // load byte into TXREG1
}

/******************************************************************************
 * receive function 
 *
 * Receives the data!
 ******************************************************************************/
void receive(){
    // interrupt flag has been set, grab a letter!
    // if commandready is greater than zero, reset:
    if( commandready > 0){
        commandready = 0; // means message is not done transmitting
        // reset RBuffer to all zeros
        memset(RBuffer, 0, sizeof(RBuffer)); 
    }
    if( RCSTA1bits.FERR == 1){ // framing error, ignore
        throwout = RCREG1; // throw away this byte
        return;
    }
    if( RCSTA1bits.OERR == 1){ // if overrun error, reset USART1
        RCSTA1bits.CREN = 0; // toggle CREN bit (continuous receive)
        RCSTA1bits.CREN = 1;
        return;
    }
    // take byte from RCREG1
    RBuffer[bcount] = RCREG1; // grab this letter, 
    if(RBuffer[bcount] == 0x0A){
        //LATDbits.LATD6 = 0b1; // turn on latd6 to mak sure we've made it this far
        bcount = 0; // reset bcount, word is done
        commandready++; // increment commandready to 1 to indicate the entire word has been received
    }
    else {
        bcount ++;
    }
    //LATDbits.LATD5 = 0b1; // 
}


/******************************************************************************
 * Message Decoder Function
 *
 * takes the data that was received, and determines the next transmit
 ******************************************************************************/
void decoder(){
    // check the RBuffer bytes, 
    // determine output based on those
    memset(TBuffer, 0, sizeof(TBuffer)); 
    if(strncmp(RBuffer,"TEMP",4)==0){
        // send back the temperature:
        TBuffer[0] = temperature[3];
        TBuffer[1] = temperature[4];
        TBuffer[2] = temperature[5];
        TBuffer[3] = temperature[6];
        TBuffer[4] = temperature[7];
        TBuffer[5] = 0x00;
        TBuffer[6] = 0x00;
        TBuffer[7] = 0x00;
        TBuffer[8] = 0x00;
        TBuffer[9] = 0x00;
    }
    if(strncmp(RBuffer,"POT",3)==0){
        // Send back the potential
        TBuffer[0] = voltage[4];
        TBuffer[1] = voltage[5];
        TBuffer[2] = voltage[6];
        TBuffer[3] = voltage[7];
        TBuffer[4] = voltage[8];
        TBuffer[5] = 0x00;
        TBuffer[6] = 0x00;
        TBuffer[7] = 0x00;
        TBuffer[8] = 0x00; // extra zeros just in case there was leftover stuff,
        TBuffer[9] = 0x00; // memclear function doesnt seem to be doing it.
    }
    //      - load TBuffer w correct send data if cases(?)
    // call transmit()
    tcount = 0;
    if(strncmp(RBuffer,"CONT_ON",7)==0){
        continuousMode = 1; // turns on continuous mode
    }
    if(strncmp(RBuffer,"CONT_OFF",8)==0){
        continuousMode = 0; // turns off continuous mode
    }
    if(transmittime==1){
        // transmit continuous message
        TBuffer[0] = temperature[1];
        TBuffer[1] = temperature[2];
        TBuffer[2] = temperature[3];
        TBuffer[3] = temperature[4];
        TBuffer[4] = temperature[5];
        TBuffer[5] = temperature[6];
        TBuffer[6] = temperature[7];
        TBuffer[7] = 0x3B;
        TBuffer[8] = 0x20;
        TBuffer[9] = voltage[1];
        TBuffer[10] = voltage[2];
        TBuffer[11] = voltage[3];
        TBuffer[12] = voltage[4];
        TBuffer[13] = voltage[5];
        TBuffer[14] = voltage[6];
        TBuffer[15] = voltage[7];
        TBuffer[16] = voltage[8];
        TBuffer[17] = 0x0A;
        TBuffer[18] = 0x00; // tells our transmit function to stop
        transmittime = 0; // turn back off the thing, clear TMR1X
    }
    transmit(); // will transmit whatever is in TBuffer
    // Finally, clear commandready
    commandready = 0;
}