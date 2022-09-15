' DS3213 clock from https://picaxeforum.co.uk/threads/ds3231-code-examples.18694/
#PICAXE 28X2
#Terminal 9600
#no_table
#slot 0
setfreq m8
disablebod

SYMBOL minute = b3
SYMBOL hour = b4
SYMBOL day = b5
SYMBOL date = b6
SYMBOL month = b7
SYMBOL year = b8
SYMBOL control = b9
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

Symbol DS3231    = $D0 ; DS3231 I2C Device
Symbol DAT_A2    = $0B ; Alarm 2 Registers
Symbol CTR       = $0E ; Control Register
Symbol CTR_A1IE  = bit0
Symbol CTR_A2IE  = bit1
Symbol CTR_INTCN = bit2
Symbol CTR_RS1   = bit3
Symbol CTR_RS2   = bit4
Symbol CTR_CONV  = bit5
Symbol CTR_BBSQW = bit6
Symbol CTR_EOSC  = bit7
Symbol STS       = $0F ; Status Register
Symbol STS_A1F  = bit0
Symbol STS_A2F  = bit1
Symbol STS_BSY   = bit2
Symbol STS_EN32K = bit3
Symbol STS_OSF   = bit7

' Set default time info, but don't in main program, clock should be set and left until battery reset or manual change
let minute = $0
let hour = $12
let day = $1
let date = $28
let month = $8
let year = $22
let control = $12
'setbit control, 7 ' Set bit 7 of alarm hour to 1 to enable once per 24 hour sampling.

Initialize:
' Only initialize clock on startup, don't set time or alarm.
HI2cSetup I2CMASTER, DS3231, I2CSLOW, I2CBYTE ' Initialize clock
hi2cout $00,($0 , minute, hour, day, date, month, year) ' Set Time, seconds default to 00.
'hi2cout $0A, (%00000000) ' Set DY/DT to 0 for date.  1 = day
'hi2cout $07,($0, $1, $12, %10101000) ' Set Alarm SS, MM, HH, A1M4 register to 1: Alarm when hours, minutes, and seconds match
;hi2cout $0E, (%00001110) ' Set alarm 2 active, interrupts active

; Clear Alarm 1 and 2 Flags
HI2cOut CTR, (%00000110) ' Enable INTCN and Alarm2
HI2cOut STS, (%00001000)
; Set Alarm 2
;:  Need a2M4 a2M3 and A2M2 to be (0)-0-0-1, which are bit7 of register 0B 0C 0D, which is MM, HH, DD so need bit7 of those to be 0 (MM) - 0 (HH) - 1 (DD) otherwise it's gibberish

b23 = $12         ' bit7 = 0
b24 = $1         ' bit7 = 0
b25 = %10000000 ' bit7 = 1

b23 = bintobcd b23
b24 = bintobcd b24
HI2cOut DAT_A2, (b23, b24, b25)
HI2cOut $0B, (%10000000, %10000000, %10000000)

hintsetup   %00000001 ' Int on all 3 pins, INT0, INT1, INT2 = B.0, B.1, B.2
setintflags %00000001,%00000001 ' Int on any pin 0,1,2

main_menu:
    serTXD (CR, "--- Main Menu ---", CR)
    serTXD (_
        "Command | Action", CR, _
        "----------------", CR, _
        "1       | Return value at b0", CR, _
        "2       | Set Clock/Alarm", CR, _
        "4       | Display Alarm", CR, _
        "5       | alarm_monitor", CR, _
        "6       | Display alarm bus", CR, _
        "254     | Reset picaxe", CR, CR)
    serTXD ("Enter q<command>:  ")
    serRXD b0
    serTXD (#b0, CR, CR, LF)
    if b0 = 1 then
        serTXD (#b0, CR, LF)
    elseif b0 = 2 then
        gosub set_clock ' Set Time/Alarm
    elseif b0 = 4 then
        gosub display_alarm2 ' Display Time/Alarm
    elseif b0 = 5 then
        gosub alarm_monitor
    elseif b0 = 6 then
        gosub read_alarm_bus
    elseif b0 = 254 then
        reset
    else 
        serTXD (CR, "Invalid input:  ", #b0, CR, LF)
    endif
    goto main_menu

alarm_monitor:
    serTXD ("Sleeping", CR, LF)
    HI2cOut STS, (%00001000)
    sleep 0
    serTXD ("Waking", CR, LF)
    return

read_alarm_bus:
    hi2cin CTR, (b0)
    sertxd("CTR: ", bit7, bit6, bit5, bit4, bit3, bit2, bit1, bit0, cr, lf )
    
    hi2cin STS, (b0)
    sertxd("STS: ", bit7, bit6, bit5, bit4, bit3, bit2, bit1, bit0, cr, lf )

    hi2cin $0B, (b0)
    sertxd("MM: ", bit7, bit6, bit5, bit4, bit3, bit2, bit1, bit0, cr, lf )

    hi2cin $0C, (b0)
    sertxd("HH: ", bit7, bit6, bit5, bit4, bit3, bit2, bit1, bit0, cr, lf )

    hi2cin $0D, (b0)
    sertxd("DD: ", bit7, bit6, bit5, bit4, bit3, bit2, bit1, bit0, cr, lf )
    
    return

rtc_to_ascii:
' Read RTC data from DS3231
    BcdTOASCII year , year_b1, year_b0
    BcdTOASCII month, month_b1, month_b0
    clearbit date, 7
    BcdTOASCII date , date_b1, date_b0
    BcdTOASCII hour, hour_b1, hour_b0
    BcdTOASCII minute , minute_b1, minute_b0
    return

set_clock:
' Set Time/Alarm
    serTXD ("Program: 1 = Time, 2 = Alarm", CR, LF)
    serRXD b0
    if b0 = 1 then
        serTXD ("Programming Time", CR, LF)
        gosub enter_clock_time
        hi2cout 0,($0, minute, hour, day, date, month, year) ' Set Time
    elseif b0 = 2 then
        serTXD ("Programming Alarm", CR, LF)
        gosub enter_clock_time
        hi2cout 7,($0, minute, hour, day, date, month, year) ' Set Alarm
    else
        serTXD ("Invalid entry", CR, LF)
        return
    endif
    return

enter_clock_time:
' Get input from user to enter Time/Alarm.
    serTXD ("hour ex: 09", CR)
    serRXD hour
    serTXD ("minute ex: 05", CR)
    serRXD minute
    serTXD ("year ex: 22", CR)
    serRXD year
    serTXD ("month ex: 01", CR)
    serRXD month
    serTXD ("date ex: 06", CR)
    serRXD date
    serTXD ("day ex: Monday = 2, Tuesday = 3", CR)
    serRXD day
    serTXD ("Is this the correct time?: ", "20", #year, "/", #month, "/", #date, " ", #hour, ":", #minute, "  day = ", #day, CR)
    serTXD ("1 = yes 0 = no")
    serRXD b0
    if b0 = 0 then
        gosub enter_clock_time
    elseif b0 = 1 then
        'setbit hour, 6 ' Set bit 6 in hour to 1 to set 24hr mode in RTC
        hour = bintobcd hour
        minute = bintobcd minute
        year = bintobcd year
        month = bintobcd month
        date = bintobcd date
        day = bintobcd day
        pause 75
        return
    else
        serTXD ("Invalid entry", CR, LF)
        return
    endif

display_alarm2: 
    hi2cin DAT_A2, (minute, hour)
    sertxd (#minute, ":", #hour)
    return

interrupt:
    serTXD ("Interrupted", CR, LF)
    flag0 = 0
    flag1 = 0
    flag2 = 0
    setintflags %00000100,%00000100
    'HI2CIN  $0F, (DataIn) ; Fetch the Control/Status register at location $0F
    'datain = DataIn AND %11111100 ; clear the two alarm bits bit1 and bit0 
    'HI2COUT $0F, (DataIn) ;Write back to clear interrupt flag
    return
