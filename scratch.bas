#PICAXE 28X2

symbol control = b22
symbol intOccurred = b23
Symbol CTR       = $0E
Symbol STS       = $0F
SYMBOL minute = b3
SYMBOL hour = b4
SYMBOL day = b5
SYMBOL date = b6
SYMBOL month = b7
SYMBOL year = b8
SYMBOL year_b1 = b10
SYMBOL year_b0 = b11
SYMBOL month_b0 = b20
SYMBOL month_b1 = b21
SYMBOL date_b1 = b12
SYMBOL date_b0 = b13
SYMBOL day_b1 = b14
SYMBOL day_b0 = b15
SYMBOL hour_b1 = b16
SYMBOL hour_b0 = b17
SYMBOL minute_b0 = b18
SYMBOL minute_b1 = b19
symbol datain = b20
main:
	HI2cSetup I2CMASTER, $D0, I2CSLOW, I2CBYTE
	setInt %00000100, %00000100, B ;interrupt on pin 2 high
	sertxd ("interrupt set")
	intOccurred = 0
       pause 1000
	hi2cout CTR, (%00000110)  ; set control registers, alarm 2 and INTCN on
    hi2cout STS, (%00001000)  ; Clear status register
	sertxd ("control registers set")
        hi2cout 0, ($01, $00, $12, $3, $25, $7, $22) ;set the time 2022-07-25 Tuesday(3), 12:00:01
        sertxd ("time set")
        hi2cout $0B, (%10000000, %10000000, %10000000);set the alarm
        sertxd ("alarm set")
	
	lop:
		pause 1000
		gosub display_time
        hi2cin CTR, (b0)
        sertxd("CTR: ", bit7, bit6, bit5, bit4, bit3, bit2, bit1, bit0, cr, lf )
    
        hi2cin STS, (b0)
        sertxd("STS: ", bit7, bit6, bit5, bit4, bit3, bit2, bit1, bit0, cr, lf )
		goto lop

rtc_to_ascii:
' Read RTC data from DS3231
    BcdTOASCII year , year_b1, year_b0
    BcdTOASCII month, month_b1, month_b0
    BcdTOASCII date , date_b1, date_b0
    BcdTOASCII hour, hour_b1, hour_b0
    BcdTOASCII minute , minute_b1, minute_b0
    return

display_time:
' Display Time/Alarm to terminal
    ptr = 0
    serTXD ("Current time is: ")
    HI2Cin  1, (minute, hour, @ptr, date, month, year)
    gosub rtc_to_ascii
    sertxd ("20", year_b1, year_b0, "/", month_b1, month_b0, "/", date_b1, date_b0, " ", hour_b1, hour_b0, ":", minute_b1, minute_b0, CR, LF)
  return

interrupt:
	sertxd ("in interrupt loop")
	hi2cout $0F, (%00001000)
	intOccurred = intOccurred + 1
	sertxd ("flash led, intOccurrred: ", intOccurred)
	setInt %00000100, %00000100, B ;turn interrupts on again
    low B.2
	return