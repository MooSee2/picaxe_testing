#PICAXE 28X2
#TERMINAL 9600

; Define alias names for the variables
SYMBOL Seconds	 = b0
SYMBOL Minutes	 = b1
SYMBOL Hours	 = b2
SYMBOL Day	 	 = b3
SYMBOL Date		 = b4
SYMBOL Month	 = b5
SYMBOL Year		 = b6
SYMBOL DataIn	 = b7
SYMBOL Tens		 = b8
SYMBOL Units	 = b9
SYMBOL TempLSB     = b10
SYMBOL TempMSB	 = b11
SYMBOL ControlE	 = b12
SYMBOL ControlF	 = b13
SYMBOL IntOccurred = b14

Init:
	PAUSE 500 		; delay to give Programming Editor terminal window time to open
	HI2Csetup I2Cmaster, %11010000, I2Cslow, I2Cbyte
;			  sec, min, hrs, day. date month year	
; caution, the following line provides some date and time data to demonstrate the time of day alarm
; recommend that the reader try first to observe before setting with the current/actual date and time
;			  secs,mins,hrs, day,date,month,year
        HI2COUT 0, ($45, $53, $23, $01, $31, $03, $13) ;set the time
        SERTXD ("Demo time is now set",CR,LF)

Main:
;	Define the parameters to set up the Control and Control/Status registers at registers $0E and $0F
;			  bit7    bit6    bit5   bit4 & bit3     bit2   bit1    bit0
;                   Osc_En, BBSQW,  Tconv, SQWOut_Rate,    INTCN, A2IEn,  A1IEn
	let ControlE = %00000110 ; ==> alarm 2 on, interrupts on
;			  bit7      bit6    bit5 & bit4  bit3     bit2  bit1    bit0
;                   Osc_StpF, BB32kEn,Tconv_Rate,  EN32kHz, Busy, A2Flag, A1Flag	
	Let ControlF = %00000000

	HI2COUT $0E, (controlE, controlF)		;set control registers
	SERTXD ("Control registers set",CR,LF)

;		    Alm2 A2min, A2Hrs, A2Day/Date	
      HI2COUT $0B,  ($55,   $23,   %01000001)	;set the alarm2 for the required time and day of week
      							; in this demo set for 23:55 hrs or 11:55pm on day of week = 1 (= Sunday)
      SERTXD ("Specific Alarm Time set",CR,LF)

	SETINT %00000000, %10000000 ;set up for an interrupt on pin C.7 going low
	SERTXD ("Interrupt set",CR,LF)
	intOccurred = 0
	
	; now the program goes around in a continuous (never ending) loop fetching and printing the Date and Time every second
	; additional information is displayed when an interrupt occurs and an output is pulsed high briefly which can drive an LED
	; via a series resistor as an indication when an alarm event has occurred.
	DO
		PAUSE 825 ; delay duration - adjusted for an overall loop of approx 1 second
		HI2CIN 0,(Seconds, Minutes, Hours, Day, Date, Month, Year) ;read the current date and time starting from register 0
		; now display the current year, month, date, day, hours, mins, seconds
		DataIn = b6 : GOSUB BCDconv : SERTXD ("Time read: 20", Tens,Units,"/")
		DataIn = b5 : GOSUB BCDconv : SERTXD (Tens,Units,"/")
		DataIn = b4 : GOSUB BCDconv : SERTXD (Tens,Units," - Day=")		
		DataIn = b3 : GOSUB BCDconv : SERTXD (Units," -- ")		
		DataIn = b2 : GOSUB BCDconv : SERTXD (Tens,Units,":")
		DataIn = b1 : GOSUB BCDconv : SERTXD (Tens,Units,":")
		DataIn = b0 : GOSUB BCDconv : SERTXD (Tens,Units,CR,LF)
	LOOP

	END

; ================ Staring of Subroutines ====================
; Interrupt service routine	
Interrupt:
	SERTXD ("Entered the Interrupt service Routine",CR,LF)
	INC IntOccurred 
	DataIn = IntOccurred : GOSUB BCDconv : SERTXD ("Interrupt No: ", Tens,Units,CR,LF)
	IF  IntOccurred = 1 THEN
	;	For demo purposes we will now change the DS3232 TOD2/alarm2 from specific time and day of week
	;	to repeat every minute by setting bit7 in all three Alarm2 byte parameters (See datasheet)
	;              Alm2 A2min, A2Hrs, A2Day/Date	
      	HI2COUT $0B,  ($80,   $80,   $80)	;set the alarm2 to action every minute on the 00 seconds
      	SERTXD ("Specific Alarm Interval set",CR,LF)
	ENDIF

	; The following code will read and display the temperature every alternate alarm period - 2 seconds in this demo
	DataIn = IntOccurred // 2
	IF DataIn = 1 THEN ; after 2 or so minutes - actual first duration depend on how long to first interrupt
		DataIn = ControlE OR %00100000
		HI2COUT $0E, (DataIn)		;send the Do Temp Conversion request
		SERTXD ("Performing Temp Conversion",CR,LF)
		PAUSE 5 ; it takes at least 2 ms for the Busy flag to be set within the DS3232
HoldTillDone:
		HI2CIN $0E, (DataIn)
		DataIn = DataIn AND %00100000
		If DataIn > 0 THEN HoldTillDone	; wait until the conversion is completed	
		HI2CIN  $11, (TempMSB,TempLSB)	; read in the temperature M.S. Byte first
		; we are going to assume here that the temp is positive and ignore the sign bit - something for you to work out!
		DataIn = TempMSB AND %01111111	; get integer/whole part and mask off the sign bit
		SERTXD ("Temp is: ",#DataIn,".")
		DataIn = TempLSB /64 *25 		; calculate the fractional/decimal part in 0.25 degC increments
		SERTXD (#DataIn," degC",CR,LF)
	ENDIF
	
	
	HI2CIN  $0F, (DataIn) ; Fetch the Control/Status register at location $0F
	DataIn = DataIn AND %11111100 ; clear the two alarm bits bit1 and bit0 
	HI2COUT $0F, (DataIn) ;Write back to clear interrupt flag
			; Be aware that changing other bits will also alter the temperature conversion interval, etc (See datasheet)

	HIGH C.6	; Now we flash the LED briefly to indicate Alarm2 interrupt has occurred and been detected by the PICAXE
	PAUSE 500		
	LOW  C.6
	SETINT %00000000, %10000000  ;turn interrupts on again for pinC.7
	RETURN

; subroutine for converting a BCD byte into two ASCII characters for sending to a terminal or display	
BCDconv:
	BCDTOASCII DataIn, Tens, Units
	RETURN
; ================ End of Subroutines ====================
