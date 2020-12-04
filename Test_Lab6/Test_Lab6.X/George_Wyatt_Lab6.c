
/****** ASEN 4/5519 Lab 6 ******************************************************
 * Author: YOUR NAME HERE
 * Date  : DATE HERE
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
 *          ASEN 4519:
 *              'TEMP\n'     - Transmits temperature data in format: 'XX.XC'
 *              'POT\n'      - Transmits potentiometer data in format: X.XXV'
 *          ASEN 5519: Same as ASEN 4519, plus two additional commands
 *              'CONT_ON\n'  - Begins continuous transmission of data over USART
 *              'CONT_OFF\n' - Ends continuous transmission of data over USART
 *
 *              Continuous transmission should output in the following format:
 *                  'T=XX.XC; PT = X.XXV\n'
 *      DAC is used to output analog signal onto RA5 with jumper cables. 
 *          ASEN 4519:
 *              Potentiometer voltage is converted from a digital value to analog 
 *              and output on the DAC. 
 *          ASEN 5519: 
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
#include <math.h>


#define _XTAL_FREQ 16000000   //Required in XC8 for delays. 16 Mhz oscillator clock
#define DAC_CS LATEbits.LATE0
#pragma config FOSC=HS1, PWRTEN=ON, BOREN=ON, BORV=2, PLLCFG=OFF
#pragma config WDTEN=OFF, CCP2MX=PORTC, XINST=OFF

/******************************************************************************
 * Global variables
 ******************************************************************************/
const char LCDRow1[] = {0x80,'T','E','S','T','I','N','G','!',0x00};
const char testString[] = "Testing!";
char commandString[10];
unsigned int Alive_count = 0;
char USART_BUFFER[10];
unsigned int INDEX = 0;
unsigned int OLD_INDEX = 0;
int analogResult;
float temperature;
float voltage;
char potString[10];
char temperatureString[10];  
char command[16] = {0x80};

/******************************************************************************
 * Function prototypes
 ******************************************************************************/
void Initial(void);         // Function to initialize hardware and interrupts
void TMR0handler(void);     // Interrupt handler for TMR0, typo in main
void sendChars(const char *);
void checkCommand(const char *);
void dispTemp(void);
void dispPot(void);
void TMR1handler(void);
/******************************************************************************
 * main()
 ******************************************************************************/
void main() {
    int c;
    int firstResult = 1;
    int temp;
    char tempString[10];
    
    Initial();                 // Initialize everything
      while(1) {
          
          //USART COMMAND HANDLING
          OLD_INDEX = INDEX;
          for (int i=0;i<sizeof(commandString);i++){commandString[i]=0;}
        
          //AD CONVERSION FOR POTENTIOMETER
          ADCON0 = 0b00000001; //AN0 (RA0) and set to ON
          firstResult = 0;
          for(int convCount = 0; convCount<5; convCount++){
            ADCON0bits.GO = 1;
            while (ADCON0bits.GO == 1){}
            LATDbits.LATD5 = ~LATDbits.LATD5;
            PIR1bits.ADIF = 0;  
            if (firstResult == 1){
                temp = ADRES;
                  firstResult = 0;
            }else{
                analogResult = ADRES;
                voltage = 0.001 * analogResult * 0.8168;
                sprintf(potString, "%.2f", voltage);
                strcpy(tempString,potString);
                for(int i = 4; i <= sizeof(potString); i++){
                    potString[i] = tempString[i-4];
                }
                potString[0] = 0xC0;
                potString[1] = 'P';
                potString[2] = 'T';
                potString[3] = '=';
                potString[8] = 'V';
                potString[9] = 0x00;
                DisplayC(potString);
            }
          }
          //AD CONVERSION FOR TEMPERATURE SENSOR
          ADCON0 = 0b00001101; //AN3 (RA3) and set to ON
          firstResult = 0;
          for(int convCount = 0; convCount<5; convCount++){
            ADCON0bits.GO = 1;
            while (ADCON0bits.GO == 1){}
            LATDbits.LATD5 = ~LATDbits.LATD5;
            PIR1bits.ADIF = 0;
            if (firstResult == 1){
                temp = ADRES;
                  firstResult = 0;
            }else{

                analogResult = ADRES;
                temperature = analogResult/13.0; //value of '13.0' calibrated to room temp
                sprintf(temperatureString, "%.1f", temperature);
                strcpy(tempString,temperatureString);
                for(int i = 3; i <= sizeof(temperatureString); i++){
                    temperatureString[i] = tempString[i-3];
                }
                temperatureString[0] = 0x80;
                temperatureString[1] = 'T';
                temperatureString[2] = '=';
                temperatureString[7] = 'C';
                temperatureString[8] = 0x00;
                DisplayC(temperatureString);
            }
          }
          
          
          //Final Command Handling
          if (OLD_INDEX != INDEX){
            c = 0;
            for(int i = OLD_INDEX; i <= INDEX; i++){
                commandString[c] = USART_BUFFER[i];
                c++;
            }
            INDEX = 0;
            for (int i=0;i<sizeof(USART_BUFFER);i++){USART_BUFFER[i]=0;}
            checkCommand(commandString);
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
    // Configure the IO ports
    TRISD  = 0b00001111;
    LATD = 0;
    TRISC  = 0b10010011;
    LATC = 0;
    TRISF = 0xFF;
    TRISAbits.TRISA5 = 1;
    TRISAbits.TRISA4 = 0;
    TRISEbits.TRISE0 = 0;
    
    // Configure the LCD pins for output. Defined in LCDRoutines.h
    LCD_RS_TRIS   = 0;              // 
    LCD_E_TRIS    = 0;
    LCD_DATA_TRIS = 0b11000000;     // Note the LCD is only on the upper nibble
                                    // The lower nibble is all inputs
    LCD_DATA_LAT = 0;           // Initialize LCD data LAT to zero


    // Initialize the LCD and print to it
    InitLCD();
    //DisplayC(LCDRow1);

    // Initializing TMR0
    T0CON = 0b01001000;             // 8-bit, Fosc / 4, no pre/post scale timer
    TMR0L = 0;                      // Clearing TMR0 registers
    TMR0H = 0;
    
    T1CON = 0b00000010;
    TMR1 = 61536;
    // Configuring Interrupts
    RCONbits.IPEN = 1;              // Enable priority levels
    INTCON2bits.TMR0IP = 0;         // Assign low priority to TMR0 interrupt
    IPR1bits.TMR1IP = 0;
    
    IPR1bits.RC1IP = 1;

    
    INTCONbits.TMR0IE = 1;          // Enable TMR0 interrupts
    PIE1bits.TMR1IE = 1;
    PIE1bits.RC1IE = 1;             // Enable RC interrupts
    INTCONbits.GIEL = 1;            // Enable low-priority interrupts to CPU
    INTCONbits.GIEH = 1;            // Enable all interrupts

    T0CONbits.TMR0ON = 1;           // Turning on TMR0
    T1CONbits.TMR1ON = 1;
    //Configure EUSART1
    RCSTA1bits.SPEN = 1;
    RCSTA1bits.CREN = 1;
    //TRISC.7 already set
    //TRISC.6 already clear
    SPBRG1 = 12;
    SPBRGH1 = 0;
    BAUDCON1 = 0;
    TXSTA1 = 0;
    TXSTA1bits.TXEN = 1;
    TXSTA1bits.TRMT = 1;
    
    //Configure ADC
    ANCON0 = 0b00000001; //RA0 set to AN0
    TRISA =  0b00101001; //Set RA3 to input
    ADCON0 = 0b00000001; //AN3 (RA3) and set to ON
    ADCON1 = 0b00000000; //AVss is selected as negative channel
    ADCON2 = 0b10010101; //Right justified, 4 TA, FOSC/16
    
    PIR1bits.ADIF = 0;
    PIE1bits.ADIE = 0;
    
    //SPI Initialization
    
    SSPCON1 = 0b00100000;
    SSP1STAT = 0x00;
    SSP1STATbits.SMP = 1;
    SSP1STATbits.CKE = 0;
    SSP1CON1bits.CKP = 1;
    SSP1CON1bits.SSPM = 0001;
    

}

/******************************************************************************
 * HiPriISR interrupt service routine
 *
 * Included to show form, does nothing
 ******************************************************************************/

void __interrupt() HiPriISR(void) {
    char letter;
    char LCDOUT[18] = {0x80};
          letter = RCREG1;
          USART_BUFFER[INDEX] = letter;
          if (INDEX<=sizeof(USART_BUFFER)){
              INDEX++;
          }else{INDEX = 0;}
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
            continue;
        }
        
        if( PIR1bits.TMR1IF ) {
            TMR1handler();
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

void TMR1handler() {
    //SEND AD DATA TO DAC
    char trash;
    float VperBin = 3.3/4096;
    int bins = (int)(voltage/VperBin);
    bins += 0x3000; 
    unsigned char bins_upper = bins >> 8;
    unsigned char bins_lower = bins & 0xFF;
    
    DAC_CS = 0;
          
    SSP1BUF = bins_upper;
    while (!SSP1STATbits.BF){}
    trash = SSP1BUF;
          
    SSP1BUF = bins_lower;
    while (!SSP1STATbits.BF){}
    trash = SSP1BUF;
          
    DAC_CS = 1;
    //LATAbits.LATA4 = PORTAbits.RA5;
    //PORTDbits.RD5 = !PORTDbits.RD5;
    PIR1bits.TMR1IF = 0;
    TMR1 = 63000;
    
    return;
}

//Transmits the characters sent to it in the "letters" array
void sendChars(const char * letters){
    int count = 0;
    while(count<strlen(letters)){
        while(PIR1bits.TX1IF==0){}
                TXREG1 = letters[count];
                __delay_us(1);
                count++;
    }
}


void checkCommand(const char * cmd){
    if(!strcmp(cmd,"TEMP")){
        dispTemp();
        return;
    }else{
        if(!strcmp(cmd,"POT")){
            dispPot();
            return;}
    }
    sendChars("NOT A VALID COMMAND!");
}

void dispTemp(){
    char temp[sizeof(temperatureString)];
    for(int i = 0; i < sizeof(temperatureString)-1; i++){
        temp[i] = temperatureString[i+3];
    }
    sendChars(temp);
}

void dispPot(){
    char temp[sizeof(potString)];
    for(int i = 0; i < sizeof(potString)-1; i++){
        temp[i] = potString[i+4];
    }
    sendChars(temp);
}