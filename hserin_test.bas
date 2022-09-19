#PICAXE 28X2
#slot 0
setfreq m8

' Outlet valve open/close positions:  150/250
' Always use sperate 6v for servos as they generate a lot of electrical noise.


' Pin assignments
' B.0 used for monitoring RTC alarm via interrupts
' B.1 is empty
symbol servo_IO = B.2
symbol outlet_IO = B.3
symbol subsamp = 2 ' Number of subsamples to take.  Subsamples are taken daily

' DS3231 RTC registers
symbol clock_reg = $00 ' Clock register start SS -> MM -> HH -> DAY (Sunday=1) -> Date -> MoMo -> YY
symbol alarm2_reg = $0B ' Alarm2 register start MM -> HH
symbol CTR = $0E ' Control register start
symbol STS = $0F ' Status register start

' Variable assinmends
symbol pulse_time_OFF = w0 ' b0, b1, are w0
symbol enter = b2 ' User inputs for navigating menus

' Time variables
symbol minute = b3
symbol hour = b4
symbol day = b5
symbol date = b6
symbol month = b7
symbol year = b8
symbol control = b9
symbol day_b1 = b10
symbol day_b0 = b11
symbol hour_b1 = b12
symbol hour_b0 = b13
symbol minute_b0 = b14
symbol minute_b1 = b15
symbol a2_hour = b16
symbol a2_minute = b17

' Program variables
symbol pulse_time = b18
symbol sample_pulses = b19
symbol slot_num = b20
symbol subsample_count = b21
symbol sample_set = b22
symbol pulse_time_ON = b23
symbol pump_runtime = w12 ' b24, b25 are w12
symbol servo_pos = w13 ' b26, b27 are w13

' These variables must be in this address order!
' Used in recording timestamp to eeprom
'==============================================
symbol year_b1 = b40
symbol year_b0 = b41
symbol month_b1 = b42
symbol month_b0 = b43
symbol date_b1 = b44
symbol date_b0 = b45
symbol a2hour_b1 = b46
symbol a2hour_b0 = b47
symbol a2minute_b1 = b48
symbol a2minute_b0 = b49
'==============================================

' Temp variables
symbol write_count = b51 ' Number of times save_data has been called.
symbol mem_index2 = b52 ' 10 spaces after first empty eeprom address, upper bound of save data
symbol mem_index1 = b53 ' First empty eeprom address, needed to save data, lower bound of save data
symbol temp = b54  ' temp var for calculations
symbol i = b55  ' use in counter loops only

' Initialize this every time picaxe is turned off/on, reset, or reprogrammed.
init:
    servo outlet_IO, 250  ' Close outlet
    servo servo_IO, 255  ' Close main servo
    let pump_runtime = 1  ' Default manifold flush time
    let pulse_time_ON = 100 ' Pump time on when pulsing
    let pulse_time_OFF = 900 ' pump time off when pulsing
    let sample_pulses = 1 ' How many times to pulse pump when taking sample

    gosub init_clock ' Establish RTC
    'HI2Csetup I2Cmaster, $D0, I2Cslow, I2Cbyte ' $D0 is DS3231 address on picaxe
    'hi2cout CTR, (%00000110) ' Enable INTCN and Alarm2
    'hi2cout STS, (%00001000) ' Clear Status register
    'hi2cout $0D, (%10000000) ' A2M4 bit 7 = 1, Alarm2 active when HH:MM == Clock HH:MM i.e. activate sampler once per day then sleep
    'hintsetup   %00000000 ' Disable interrupts to allow user interface until sampling begins.

    ' REMOVE IN FINAL VERSION!  Only for testing purposes
    let mem_index1 = 246 ' Initial mem_index1 value, Note: 255+10=9, not 265
    let mem_index2 = 0 ' Initial mem_index2 value
    let minute = $1
    let hour = $20
    let day = $1
    let date = $2
    let month = $6
    let year = $22
    hi2cout clock_reg,($01 , minute, hour, day, date, month, year) ' Set Time
    'hi2cout alarm2_reg, (%10000000, %10000000, %10000000) ' Set the alarm to go off every minute regardless of alarm time

clear_terminal:
    serTXD (CR, CR, CR, CR, CR, CR, CR, CR, CR, CR, CR, CR, CR, CR)

main_menu:
    serTXD (CR, "--- Main Menu ---", CR)
    gosub display_time
    gosub display_alarm2
    serTXD (_
        "Command | Action", CR, _
        "----------------", CR, _
        "1       | Testing menu", CR, _
        "2       | Set Time/Alarm", CR, _
        "3       | Display Time", CR, _
        "4       | Display Alarm", CR, _
        "5       | Load sample data", CR, _
        "6       | Set pulses and flush time", CR, _
        "7       | Read alarm bus", CR, _
        "8       | Save test data", CR, _
        "91      | Begin Sampling", CR, _
        "253     | Reset", CR, _
        "254     | Reprogram picaxe", CR)
    serTXD ("Enter command:  ")
    serRXD enter
    serTXD (#enter, CR, CR, LF)
    if enter = 1 then
        goto testing_menu
    elseif enter = 2 then
        gosub set_clock
    elseif enter = 3 then
        gosub display_time
    elseif enter = 4 then
        gosub display_alarm2
    elseif enter = 5 then
        gosub load_data
    elseif enter = 6 then
        gosub enter_prog_var
    elseif enter = 7 then
        gosub read_alarm_bus
    elseif enter = 8 then
        gosub save_routine
    elseif enter = 91 then
        gosub begin_sampling
    elseif enter = 253 then
        serTXD ("Resetting picaxe now...")
        reset
    elseif enter = 254 then
        serTXD ("Reprogram picaxe now...")
        do
            reconnect
            serin 6, N9600, b2
        loop
    else
        serTXD (CR, "Invalid input:  ", #enter, CR, LF)
    endif
    goto main_menu

testing_menu:
    serTXD (CR, _
        "--- Testing Menu ---", CR, CR, _
        "Command | Action", CR, _
        "----------------", CR, _
        "1       | Manifold flush", CR, _
        "2       | Wet filters", CR, _
        "3       | Manual sample", CR, _
        "4       | Move servo to slot", CR, _
        "5       | Open outlet", CR, _
        "6       | Close outlet", CR, _
        "99      | Return to Main", CR)
    serTXD ("Enter command:  ")
    serRXD enter
    serTXD (#enter, CR)
    if enter = 1 then  ' Manifold flush
        gosub enter_pump_time
        gosub manifold_flush
    elseif enter = 2 then  ' Wet filters
        serTXD ("Wet filters", CR)
        gosub enter_pulses
        gosub wet_filters
    elseif enter = 3 then  ' Manual sample
        serTXD ("Manual sample", CR)
        gosub close_outlet
        gosub enter_slot
        gosub enter_pulses
        gosub pulse_pump
        pause 300
        servopos servo_IO, 255
        pause 750
    elseif enter = 4 then ' Move servo to slot
        do
            ;gosub move_servo_test
            gosub enter_slot
        loop
    elseif enter = 5 then  ' Open outlet
        gosub cpen_outlet
    elseif enter = 6 then  ' Close outlet
        gosub close_outlet
;    elseif enter = 7 then  ' Pulse pump
;        gosub enter_pulses
;        gosub pulse_pump
;    elseif enter = 8 then  ' Run pump
;        gosub enter_pump_time
;        gosub run_pump
    elseif enter = 99 then  ' Return to main menu
        goto main_menu
    else  ' Invalid input
        serTXD (CR, "Invalid input:  ", #enter, CR, LF)
    endif
    goto testing_menu

init_clock:
    ' Initialize RTC for picaxe
    hi2csetup i2cmaster, $D0, i2cslow, i2cbyte ' $D0 is DS3231 address on picaxe
    hi2cout CTR, (%00000110) ' Enable INTCN and Alarm2
    hi2cout STS, (%00001000) ' Clear Status register
    return

set_clock:
    ' User set Time/Alarm
    serTXD ("Program: 1 = Time, 2 = Alarm", CR, LF)
    serRXD enter
    if enter = 1 then
        serTXD ("Programming Time", CR, LF)
        gosub enter_clock_time
        hi2cout clock_reg,($0, minute, hour, day, date, month, year) ' Set Time
    elseif enter = 2 then
        serTXD ("Programming Alarm", CR, LF)
        serTXD ("hour:", CR)
        serRXD a2_hour
        serTXD ("minute", CR)
        serRXD a2_minute
        serTXD ("Alarm2 set to: ", a2_hour, ":", a2_minute, CR)
        a2_hour = bintobcd a2_hour
        a2_minute = bintobcd a2_minute
        hi2cout alarm2_reg,(a2_minute, a2_hour) ' Set Alarm on RTC
    else
        serTXD ("Invalid entry", CR, LF)
        return
    endif
    return

enter_clock_time:
    ' Get input from user to program RTC time.
    serTXD ("hour", CR)
    serRXD hour
    serTXD ("minute", CR)
    serRXD minute
    serTXD ("year", CR)
    serRXD year
    serTXD ("month", CR)
    serRXD month
    serTXD ("date", CR)
    serRXD date
    serTXD ("day Sunday = 1, Monday = 2 ...", CR)
    serRXD day
    serTXD ("Is this the correct time?: ", "20", year, "/", month, "/", date, " ", hour, ":", minute, "  day = ", #day, CR)
    serTXD ("1 = yes 0 = no")
    serRXD enter
    if enter = 0 then
        gosub enter_clock_time
    elseif enter = 1 then
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
' Display current RTC time to terminal
    ptr = 0
    serTXD ("Current time is: ")
    hi2Cin  1, (minute, hour, @ptr, date, month, year)
    BcdTOASCII year , year_b1, year_b0
    BcdTOASCII month, month_b1, month_b0
    BcdTOASCII date , date_b1, date_b0
    BcdTOASCII hour, hour_b1, hour_b0
    BcdTOASCII minute , minute_b1, minute_b0
    sertxd ("20", year_b1, year_b0, "/", month_b1, month_b0, "/", date_b1, date_b0, " ", hour_b1, hour_b0, ":", minute_b1, minute_b0, CR, LF)
    return

display_alarm2:
' Display current alarm2 value to terminal.  Note alarm2 is programmed to go off once per day when Time HH:MM == Alarm2 HH:MM
    hi2Cin  alarm2_reg, (a2_minute, a2_hour)
    clearbit a2_hour, 7
    clearbit a2_minute, 7
    BcdTOASCII a2_hour, a2hour_b1, a2hour_b0
    BcdTOASCII a2_minute , a2minute_b1, a2minute_b0
    sertxd ("Current alarm set to: ", a2hour_b1, a2hour_b0, ":", a2minute_b1, a2minute_b0, CR, LF)
    return

' Get user input subroutines
enter_prog_var:
    ' Get user input for programming sample pulses and pump manifold fluch time.  Note pump needs seconds and serRXD can only receive values from 0-255 so convert minutes to seconds
    serTXD (CR, "---Program picaxe variables---", CR, LF)
    serTXD ("Enter sample pulses: ", CR)
    serRXD sample_pulses
    serTXD ("Enter flush time in minutes: ", CR)
    serRXD pump_runtime
    serTXD ("Sample pulses: ", #sample_pulses, " Flush for:  ", #pump_runtime, "  minutes", CR)
    pump_runtime = pump_runtime*60 
    return

enter_pump_time:
    ' Get user input for pump runtime
    serTXD ("Enter pump time: ", CR)
    serrxd pump_runtime
    serTXD ("Pumping ", #pump_runtime, " seconds", CR)
    return

enter_pulses:
    ' Get user input for number of sample pulses
    serTXD ("Enter pulses:  ")
    serrxd sample_pulses
    serTXD (#sample_pulses, CR)
    return

enter_slot:
    ' Get user input for where to move main servo to
    serTXD ("Move to slot 0-8, 99=exit:")
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
    for i = 1 to pump_runtime
        pause 1000  ' give 1 second pause at 8Hz
    next i
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
    pause 1500 ' Wait for servo to move to closed position
    gosub calc_servo_pos
    serTXD ("At position ", #servo_pos, CR)
    servopos servo_IO, servo_pos ' Move servo to slot_num
    pause 1500 ' Wait for servo to move to slot_num
    return

;move_servo_test:
;    ' Move main servo to slot number.
;    ' Always move to closed position before changing position
;    'serTXD ("Moving main servo to ", #slot_num, CR)
;    'servopos servo_IO, 255 ' Make sure servo is closed
;    'pause 1500 ' Wait for servo to move to closed position
;    'gosub calc_servo_pos
;    serRXD servo_pos
;    serTXD ("At position ", #servo_pos, CR)
;    servopos servo_IO, servo_pos ' Move servo to slot_num
;    'pause 1500 ' Wait for servo to move to slot_num
;    return

cpen_outlet:
    ' Move outlet servo to open position
    serTXD ("Opening outlet", CR)
    servopos Outlet_IO, 150
    pause 500
    return

close_outlet:
    ' Move outlet servo to open position
    ' Closed is default position set in init.
    serTXD ("Closing outlet", CR)
    servopos Outlet_IO, 250
    pause 500
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
    pause 1500
    gosub cpen_outlet
    serTXD ("Flushing manifold", CR)
    gosub run_pump
    gosub close_outlet
    return

'Save/Load subroutines
save_data:
    ' Save sample data to eeprom
    mem_index1 = mem_index1 + 10
    mem_index2 = mem_index2 + 10
    bptr = 40 ' Start pointer at b40
    for i=mem_index1 to mem_index2 ' Save sample data within this range one byte at a time.
        write i, @bptrinc
    next i
    inc write_count
    return

load_data:
    ' Load sample data from eeprom
    if write_count = 0 then
        serTXD (CR, CR, "No sample data recorded.", CR)
        return
    else
        ptr = 0
        for i=0 to mem_index2
            read i, @ptrinc ' read variable at eeprom address 0, copy that value to scratchpad, repeat to  eeprom address n (mem_index2).
        next i
        sertxd (CR, CR, CR)
        ptr = 0
        for i=1 to write_count ' Display data recorded to eeprom
            sertxd ("20", @ptrinc, @ptrinc, "/", @ptrinc, @ptrinc, "/", @ptrinc, @ptrinc, " ", @ptrinc, @ptrinc, ":", @ptrinc, @ptrinc, CR, LF)
        next i
        return
    endif

' Program logic subroutines
collect_sample:
    ' Collect sample logic.  Responsible for collecting 1 sample.
    gosub move_servo ' Move servo to slot_num location
    gosub pulse_pump ' Pulse pump the number in sample_pulses times to collect subsample
    return

collect_subsample:
    ' Collect subsample logic.  Should activate once per day, and collect subsamples in RA and FA vials.
    gosub manifold_flush
    gosub collect_sample ' Collect RA
    inc slot_num
    gosub collect_sample ' Colllect FA
    slot_num = 0
    gosub move_servo ' Return servo to slot 0, closed position.
    return

save_routine:
    gosub display_time
    gosub display_alarm2
    gosub save_data 'RA
    gosub save_data 'FA
    return

read_alarm_bus:
    ' Debug helper function.  Reads busses from RTC to verify control, status, and alarm time
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

begin_sampling:
    ' Begin sampling program
    let subsample_count = subsamp ' 1 subsample = 1 day
    let sample_set = 1 ' 1-4 sets RA/FA
    let mem_index1 = 246 ' Initial mem_index1 value, Note: 255+10=9, not 265
    let mem_index2 = 0 ' Initial mem_index2 value
    let write_count = 0 ' Initial write_count value

    gosub display_time
    serTXD (CR, "--- Enter Start Time ---", CR, LF)
    serTXD ("Enter start Hour", CR)
    serRXD a2_hour
    serTXD ("Enter start Minute", CR)
    serRXD a2_minute
    gosub display_time

    a2_minute = bintobcd a2_minute
    a2_hour = bintobcd a2_hour
    hi2cout alarm2_reg, (a2_minute, a2_hour, %10000000) ' Set Alarm
    gosub display_alarm2

    flag0 = 0
    hintsetup   %00000001 ' Setup watch for interrupt on pin B.0
    setintflags %00000001,%00000001 ' Interrupt conditions: Int on pin B.0 going high
    pause 100
    ' When the RTC alarm activates it interrupts the sleep and goes directly to the interrupt subroutine
    ' After the interrupt routine completes, it returns to this loop and sleeps again until the alarm activates again and repeats
    ' After final sample is taken, the program will sleep until reset by user to download data
    
    do
        serTXD (CR, "Sleeping", CR)
        sleep 0
    loop
    return

interrupt:
' Main sampling program.  When alarm2 activates, enter this subroutine and collect samples
' interrupt is REQUIRED to be the last section of a picaxe program
    ' When RTC alarm2 activates, run sample collection logic
    serTXD ("Waking", CR)
    if subsample_count = 0 then ' If all subsamples have been taken, move to next sample set
        inc sample_set ' Increment sample set by 1
        subsample_count = subsamp ' Reset subsamples
    endif
    if sample_set = 1 then ' First sample set
        if subsample_count = subsamp then
            gosub save_routine ' Save sampling data
        endif
        slot_num = 1 ' Set slot to move to
        gosub collect_subsample ' Collect RA and FA
        dec subsample_count ' Decrease subsample_count by 1
    elseif sample_set = 2 then
        if subsample_count = subsamp then
            gosub save_routine
        endif
        slot_num = 3
        gosub collect_subsample
        dec subsample_count
    elseif sample_set = 3 then
        if subsample_count = subsamp then
            gosub save_routine
        endif
        slot_num = 5
        gosub collect_subsample
        dec subsample_count
    elseif sample_set = 4 then
        if subsample_count = subsamp then
            gosub save_routine
        endif
        slot_num = 7
        gosub collect_subsample
        dec subsample_count
    else ' If sample set >= 5, then end sampling by sleeping, turn off interrupts
        serTXD ("Sampling complete, entering sleep.", CR)
        setintflags %00000001,%00000000
;        gosub main_menu ' Useful line for testing/debugging
    endif

    flag0 = 0 ' Clear flag 0
    setintflags %00000001,%00000001 ' Reset to interrupt on flag0
    hi2cout STS, (%00001000) ' Reset status register.  Resets alarm2 on RTC
    serTXD("Exiting interrupt", CR)
    pause 100
    return