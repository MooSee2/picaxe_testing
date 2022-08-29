#PICAXE 28X2
#slot 0
setfreq m8

' Outlet valve open/close positions:  150/250
' Always use sperate 6v for servos as they generate a lot of electrical noise.
' serRXD = Serial recieve, Get user input
' serTXD = Serial transmit, print to terminal


' Pin assignments
symbol Outlet_IO = B.1
symbol servo_IO = B.3

' Variable assinmends
symbol minute = b3
symbol hour = b4
symbol day = b5
symbol date = b6
symbol month = b7
symbol year = b8
symbol control = b9
symbol year_b1 = b10
symbol year_b0 = b11
symbol month_b0 = b12
symbol month_b1 = b13
symbol date_b1 = b14
symbol date_b0 = b15
symbol day_b1 = b16
symbol day_b0 = b17
symbol hour_b1 = b18
symbol hour_b0 = b19
symbol minute_b0 = b20
symbol minute_b1 = b21
symbol pump_runtime = b22
symbol pulse_time = b23
symbol sample_pulses = b24
symbol slot_num = b25
symbol servo_pos = b26
symbol subsample_count = b27
symbol finish = b28
symbol current_slot = b29
symbol sample_set = b30
symbol temp = b47  ' temp var for calculations
symbol i = b48  ' use in counter loops only.
symbol counter = b50
symbol pulse_time_ON = b42
symbol pulse_time_OFF = w0

init:
    servo Outlet_IO, 250  ' Close outlet
    servo servo_IO, 255  ' Close main servo
    let pump_runtime = 30  ' Default manifold flush time
    let pulse_time_ON = 100
    let pulse_time_OFF = 900
    let sample_pulses = 30
    let minute = $1
    let hour = $20
    let day = $1
    let date = $2
    let month = $6
    let year = $22
    let control = %00010000 ' For RTC
    gosub init_clock
    hi2cout 0,($0 , minute, hour, day, date, month, year, control) ' Set Time
    hi2cout 8,($15, $15, day, $3, control) ' Set Alarm
    pause 500

clear_terminal:
    serTXD (CR, CR, CR, CR, CR, CR, CR, CR, CR, CR, CR, CR, CR, CR)
    serTXD ("----------------")

main_menu:
    serTXD (CR, "--- Main Menu ---", CR)
    serTXD (_
        "Command | Action", CR, _
        "----------------", CR, _
        "1       | Return value at b0", CR, _
        "2       | Testing menu", CR, _
        "3       | Set Time/Alarm", CR, _
        "4       | Display Time/Alarm", CR, _
        "5       | Begin Sampling", CR, _
        "254     | Reset picaxe", CR, CR)
    serTXD ("Enter <command>:  ")
    serRXD b0
    serTXD (#b0, CR, CR, LF)
    if b0 = 1 then
        serTXD (#b0, CR, LF)
    elseif b0 = 2 then
        goto testing_menu
    elseif b0 = 3 then
        gosub set_clock
    elseif b0 = 4 then
        gosub display_time
    elseif b0 = 5 then
        gosub begin_sampling
    elseif b0 = 254 then
        reset
    else 
        serTXD (CR, "Invalid input:  ", #b0, CR, LF)
    endif
    goto main_menu

begin_sampling:
    serTXD (CR, "---Begin Sampling---", CR, LF)
    serTXD ("Enter start Hour ex: 09", CR)
    serRXD hour
    serTXD ("Enter start Minute ex: 05", CR)
    serRXD minute
    minute = bintobcd minute
    hour = bintobcd hour
    gosub init_clock
    hi2cout 7,($0, minute, hour, day, date, month, year, control) ' Set Alarm

    let subsample_count = 7 ' days
    let slot_num = 0 ' 0-8 slots
    let sample_set = 1 ' 1-4 sets RA/FA
    let finish = 0 ' Finish = 1 means sampling is complete and program sleeps.
    Low C.2 ' Set C.2 off, i.e. Alarm not active, program should sleep
    
    Do while finish = 0
        if pinC.2 = 0 then ' Alarm OFF, so sleep
            sleep 0
        elseif pinC.2 = 1 AND sample_set = 1 then
            if subsample_count > 0 then
                gosub collect_subsample
            elseif subsample_count <= 0 then
                sample_set = 2
            endif            
            low C.2
        elseif pinC.2 = 1 AND sample_set = 2 then
            if subsample_count > 0 then
                gosub collect_subsample
            elseif subsample_count <= 0 then
                sample_set = 3
            endif            
            low C.2
        elseif pinC.2 = 1 AND sample_set = 3 then
            if subsample_count > 0 then
                gosub collect_subsample
            elseif subsample_count <= 0 then
                sample_set = 4
            endif            
            low C.2
        elseif pinC.2 = 1 AND sample_set = 4 then
            if subsample_count > 0 then
                gosub collect_subsample
            elseif subsample_count <= 0 then
                sample_set = 99
            endif            
            low C.2
        else ' If sample set >= 5, then end sampling
            sleep 0
        endif
    loop

collect_sample:
    gosub move_servo
    gosub cpen_outlet
    gosub run_pump
    gosub close_outlet
    gosub pulse_pump
    return

collect_subsample:
    inc slot_num
    gosub collect_sample
    inc slot_num
    gosub collect_sample
    slot_num = 0
    gosub move_servo
    dec subsample_count

init_clock:
    HI2Csetup I2Cmaster, %11010000, I2Cslow, I2Cbyte
    return

testing_menu:
    serTXD (CR, _
        "--- Testing Menu ---", CR, CR, _
        "Command | Action", CR, _
        "----------------", CR, _
        "2       | Manifold flush", CR, _
        "7       | Wet filters", CR, _
        "8       | Manual sample", CR, _
        "3       | Move servo to slot", CR, _
        "4       | Open outlet", CR, _
        "5       | Close outlet", CR, _
        "6       | Pulse pump", CR, _
        "1       | Run pump", CR, _
        "99      | Return to Main", CR, _
        "254     | Reset picaxe", CR, CR)
    serTXD ("Enter <command>:  ")
    serRXD b0
    serTXD (#b0, CR)
    if b0 = 1 then  ' Run pump
        gosub enter_pump_time
        gosub run_pump
    elseif b0 = 2 then  ' Manifold flush
        gosub enter_pump_time
        gosub manifold_flush
    elseif b0 = 3 then ' Move servo to slot
        do
            gosub enter_slot
        loop
    elseif b0 = 4 then  ' Open outlet
        pause 300
        gosub cpen_outlet
    elseif b0 = 5 then  ' Close outlet
        pause 300
        gosub close_outlet
    elseif b0 = 6 then  ' Pulse pump
        gosub enter_pulses
        gosub pulse_pump
    elseif b0 = 7 then  ' Wet filters
        serTXD ("Wet filters", CR)
        gosub enter_pulses
        gosub wet_filters
    elseif b0 = 8 then  ' Manual sample
        serTXD ("Manual sample", CR)
        gosub close_outlet
        gosub enter_slot
        gosub enter_pulses
        gosub pulse_pump
        pause 300
        servopos servo_IO, 255
        pause 750
    elseif b0 = 99 then  ' Return to main menu
        goto main_menu
    else  ' Invalid input
        serTXD (CR, "Invalid input:  ", #b0, CR, LF)
    endif
    goto testing_menu

'  Clock subroutines

rtc_to_ascii:
' Read RTC data from DS3231
    BcdTOASCII year , year_b1, year_b0
    BcdTOASCII month, month_b1, month_b0
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
        hi2cout 0,($0, minute, hour, day, date, month, year, control) ' Set Time
    elseif b0 = 2 then
        serTXD ("Programming Alarm", CR, LF)
        gosub enter_clock_time
        hi2cout 7,($0, minute, hour, day, date, month, year, control) ' Set Alarm
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

enter_pump_time:
    serTXD ("Enter q<pump time>:  ", CR)
    serrxd pump_runtime
    serTXD ("Pumping ", #pump_runtime, " seconds", CR)
    return

enter_pulses:
    serTXD ("Enter q<pulses>:  ")
    serrxd sample_pulses
    serTXD (#sample_pulses, CR)
    return

enter_slot:
    serTXD ("Move to slot q<0-8, 99=exit>:")
    serRXD slot_num
    serTXD (#slot_num, CR)
    if slot_num = 99 then
        gosub testing_menu
    elseif slot_num > 8 then
        serTXD ("Invalid slot!", CR)
    elseif slot_num <= 8 then
        gosub move_servo
    endif
    return

'  Pump subroutines
run_pump:
    ' Activate main pump on "Motor A," generally for flushing manifold
    ' For Motor on A:
        ' pin 4 high 5 high = stop
        ' pin 4 high 5 low = forward
    high 4
    low 5
    for counter = 1 to pump_runtime
        pause 1000  ' give 1 second pause at 8Hz
    next counter
    high 5
return

pulse_pump:
    ' Pulse pump, generally used for sampling
    serTXD ("Pulsing pump for ", #sample_pulses, " pulses", CR)
    for i = 1 to sample_pulses
        high 4
        low 5
        pause pulse_time_ON
        high 5
        pause pulse_time_OFF
    next i
return

'  Servo manipulation subroutines
calc_servo_pos:
    ' Calculates servo position in degrees
    ' Slot 0 is closed position
    if slot_num = 0 then
        servo_pos = 255
    else
        temp = slot_num*25  ' Math is left to right, not PEMDOS and no ()
        servo_pos = 255-temp-5
    endif
return

move_servo:
    ' Move main servo to slot number.
    ' Always move to closed position before changing position
    serTXD ("Moving main servo to ", #slot_num, CR)
    servopos servo_IO, 255 ' Make sure servo is closed
    'servo servo_IO, 255
    pause 750 ' Wait for servo to move to closed position
    gosub calc_servo_pos
    serTXD ("At position ", #servo_pos, CR)
    'servo servo_IO, servo_pos
    servopos servo_IO, servo_pos ' Move servo to slot_num
    pause 750 ' Wait for servo to move to slot_num
return

cpen_outlet:
    ' Move outlet servo to open positoion
    serTXD (CR, "Opening outlet", CR)
    servopos Outlet_IO, 150
    'servopos Outlet_IO,OFF   ' PWM for pump messed up if servopos not turned off, no idea why
    pause 500
return

close_outlet:
    ' Move outlet servo to open positoion
    ' Closed is default position set in init.
    serTXD (CR, "Closing outlet", CR)
    servopos Outlet_IO, 250
    pause 500
    ' servopos Outlet_IO,OFF  ' PWM for pump messed up if servopos not turned off, no idea why
return

' User testing subroutines
wet_filters:
    ' Wet filters with n amount of sample pulses
    gosub close_outlet
    for slot_num = 1 to 8 STEP 1
        gosub move_servo
        gosub pulse_pump
    next slot_num
    servopos servo_IO, 255
    return

manifold_flush:
    ' Flush manifold
    servo servo_IO, 255  ' Close main servo
    gosub cpen_outlet
    serTXD ("Flushing manifold", CR)
    gosub run_pump
    gosub close_outlet
return


' DS3213 clock from https://picaxeforum.co.uk/threads/ds3231-code-examples.18694/
