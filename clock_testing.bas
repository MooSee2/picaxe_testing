' DS3213 clock from https://picaxeforum.co.uk/threads/ds3231-code-examples.18694/
#PICAXE 28X2
#slot 0
setfreq m8
SYMBOL SQWpin = C.2

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

' Set default time info, but don't in main program, clock should be set and left until battery reset or manual change
let minute = $0
let hour = $12 ' Set hour
setbit hour, 6 ' Set bit 6 in hour to 1 to set 24hr mode in RTC
let day = $1
let date = $28
let month = $8
let year = $22
let control = $12
setbit control, 7 ' Set bit 7 of alarm hour to 1 to enable once per 24 hour sampling.

Initialize:
' Only initialize clock on startup, don't set time or alarm.
HI2Csetup I2Cmaster, %11010000, I2Cslow, I2Cbyte ' Initialize clock
hi2cout $00,($0 , minute, hour, day, date, month, year) ' Set Time
hi2cout $08,($2, control, day, $28) ' Set Alarm
hintsetup %00000010
setint %00000010, %00000010, C

main_menu:
    serTXD (CR, "--- Main Menu ---", CR)
    serTXD (_
        "Command | Action", CR, _
        "----------------", CR, _
        "1       | Return value at b0", CR, _
        "2       | Set Clock/Alarm", CR, _
        "4       | Display Time", CR, _
        "5       | alarm_monitor", CR, _
        "254     | Reset picaxe", CR, CR)
    serTXD ("Enter q<command>:  ")
    serRXD b0
    serTXD (#b0, CR, CR, LF)
    if b0 = 1 then
        serTXD (#b0, CR, LF)
    elseif b0 = 2 then
        gosub set_clock ' Set Time/Alarm
    elseif b0 = 4 then
        gosub display_time ' Display Time/Alarm
    elseif b0 = 5 then
        gosub alarm_monitor ' Display Time/Alarm
    elseif b0 = 254 then
        reset
    else 
        serTXD (CR, "Invalid input:  ", #b0, CR, LF)
    endif
    goto main_menu

alarm_monitor:
    serTXD ("Sleeping", CR, LF)
    sleep 0
    serTXD ("Waking", CR, LF)
    return

rtc_to_ascii:
' Read RTC data from DS3231
    BcdTOASCII year , year_b1, year_b0
    BcdTOASCII month, month_b1, month_b0
    BcdTOASCII date , date_b1, date_b0
    clearbit hour, 6 ' Set bit 6 in hour to 0 to to read correctly from RTC
    clearbit hour, 7 ' Set bit 6 in hour to 0 to to read correctly from RTC
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
        setbit hour, 6 ' Set bit 6 in hour to 1 to set 24hr mode in RTC
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

display_time:
' Display Time/Alarm to terminal
    serTXD ("Display: 1 = Time 2 = Alarm", CR, LF)
    serRXD b0
    ptr = 0
    if b0 = 2 then
        serTXD ("Current alarm is: ")
        HI2Cin  8, (minute, hour, @ptr, date)
    elseif b0 = 1 then
        serTXD ("Current time is: ")
        HI2Cin  1, (minute, hour, @ptr, date, month, year)
    else
        serTXD ("Invalid entry", CR, LF)
        return
    endif
    gosub rtc_to_ascii
    sertxd ("20", year_b1, year_b0, "/", month_b1, month_b0, "/", date_b1, date_b0, " ", hour_b1, hour_b0, ":", minute_b1, minute_b0, CR, LF)
  return

interrupt:
    serTXD ("Interrupted", CR, LF)
    return

;    PAUSE 1000
;    ReadRegisters:
;        HI2Cin  0 , (second, minute, hour, day, date, month, year) ' Read from DS3231
;
;    ClockDisplay:
;        BcdTOASCII year , year_b1, year_b0
;        BcdTOASCII month, month_b1, month_b0
;        BcdTOASCII date , date_b1, date_b0
;        BcdTOASCII hour, hour_b1, hour_b0
;        BcdTOASCII minute , minute_b1, minute_b0
;        sertxd ("20", year_b1, year_b0, "/", month_b1, month_b0, "/", date_b1, date_b0, " ", hour_b1, hour_b0, ":", minute_b1, minute_b0, CR, LF)