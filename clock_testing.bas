' DS3213 clock from https://picaxeforum.co.uk/threads/ds3231-code-examples.18694/
#PICAXE 28X2
#slot 0
setfreq m8
SYMBOL SQWpin = C.2

SYMBOL second = b2
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

let second = $0
let minute = $1
let hour = $2
let day = $3
let date = $26
let month = $6
let year = $22
let control = %00010000

Initialize:
HI2Csetup I2Cmaster, %11010000, I2Cslow, I2Cbyte
hi2cout 0,(second , minute, hour, day, date, month, year, control)

main_menu:
    serTXD (CR, "--- Main Menu ---", CR)
    serTXD (_
        "Command | Action", CR, _
        "----------------", CR, _
        "1       | Return value at b0", CR, _
        "3       | Set RTC", CR, _
        "4       | Display RTC time", CR, _
        "5       | Set_alarm", CR, _
        "6       | Display alarm", CR, _
        "254     | Reset picaxe", CR, CR)
    serTXD ("Enter q<command>:  ")
    serRXD b0
    serTXD (#b0, CR, CR, LF)
    if b0 = 1 then
        serTXD (#b0, CR, LF)
    elseif b0 = 3 then
        gosub setup_clock
    elseif b0 = 4 then
        gosub display_time
    elseif b0 = 5 then
        gosub set_alarm
    elseif b0 = 6 then
        gosub display_alarm
    elseif b0 = 254 then
        reset
    else 
        serTXD (CR, "Invalid input:  ", #b0, CR, LF)
    endif
    goto main_menu

set_alarm:
    HI2Csetup I2Cmaster, %11010000, I2Cslow, I2Cbyte
    hi2cout 7,($1 ,$1 ,$1 , $1, $1, $1, $22, control)
    return

display_alarm:
    pause 1000
    HI2Cin  7 , (second, minute, hour, day, date, month, year) ' Read from DS3231
    AlarmDisplay:
        BcdTOASCII year , year_b1, year_b0
        BcdTOASCII month, month_b1, month_b0
        BcdTOASCII date , date_b1, date_b0
        BcdTOASCII hour, hour_b1, hour_b0
        BcdTOASCII minute , minute_b1, minute_b0
        sertxd ("20", year_b1, year_b0, "/", month_b1, month_b0, "/", date_b1, date_b0, " ", hour_b1, hour_b0, ":", minute_b1, minute_b0, CR, LF)
    return

enter_hibernate:
    'setint SQWpin, SQWpin, C
    sleep 0

setup_clock:
    gosub enter_clock_time
    HI2Csetup I2Cmaster, %11010000, I2Cslow, I2Cbyte
    hi2cout 0,(second , minute, hour, day, date, month, year, control)
    return

enter_clock_time:
    serTXD ("q<hour> ex: 09", CR)
    serRXD hour
    serTXD ("q<minute> ex: 05", CR)
    serRXD minute
    serTXD ("q<year> ex: 22", CR)
    serRXD year
    serTXD ("q<month> ex: 01", CR)
    serRXD month
    serTXD ("q<date> ex: 06", CR)
    serRXD date
    serTXD ("q<day> ex: Monday = 2, Tuesday = 3", CR)
    serRXD day
    serTXD ("Is this the correct time?: ", "20", #year, "/", #month, "/", #date, " ", #hour, ":", #minute, "  day = ", #day, CR)
    serTXD ("q< 1 = yes 0 = no >")
    serRXD b0
    if b0 = 0 then
        gosub enter_clock_time
    elseif b0 = 1 then
        hour = bintobcd hour
        minute = bintobcd minute
        year = bintobcd year
        month = bintobcd month
        date = bintobcd date
        day = bintobcd day
        pause 75
        return
    endif

display_time:
    pause 1000
    HI2Cin  0 , (second, minute, hour, day, date, month, year) ' Read from DS3231
    ClockDisplay:
        BcdTOASCII year , year_b1, year_b0
        BcdTOASCII month, month_b1, month_b0
        BcdTOASCII date , date_b1, date_b0
        BcdTOASCII hour, hour_b1, hour_b0
        BcdTOASCII minute , minute_b1, minute_b0
        sertxd ("20", year_b1, year_b0, "/", month_b1, month_b0, "/", date_b1, date_b0, " ", hour_b1, hour_b0, ":", minute_b1, minute_b0, CR, LF)
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