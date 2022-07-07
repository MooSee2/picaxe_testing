

#PICAXE 28X2
#slot 0
'setfreq m8
pause 1000

' Outlet valve open/close positions:  150/250
' Always use sperate 6v for servos as they generate a lot of electrical noise.

' PIN ASSIGNMENTS
symbol I2C_pin = A.0 ' For SERVO, RTC AND 6V LDO
symbol Outlet_IO = B.0
symbol servo_IO = B.1
symbol TB6612_PWM_port = C.2 ' PWMA and PWMB tied together to C.2 PWM
symbol TB6612_enable = C.5
symbol Sample_AIN1 = C.6
symbol Sample_AIN2 = C.7 ' drive Sample pump on C.7 and C.6
symbol pump_runtime = b10
symbol pulse_time = b41
symbol pulse_time_on = b42
symbol pulse_time_off = b43
symbol sample_pulses = b44
symbol counter = b50
symbol slot_num = b45
symbol servo_pos = b46
symbol temp = b47  ' temp var for calculations
symbol i = b48  ' use in counter loops only.

' Valve Servo Positions
' Maybe reduce this to slot_num = 255 - (user_entered_slot*25-5), more math less symboles?
;symbol slot_0 = 255 ' closed position
;symbol slot_1 = 225
;symbol slot_2 = 200
;symbol slot_3 = 175
;symbol slot_4 = 150
;symbol slot_5 = 125
;symbol slot_6 = 100
;symbol slot_7 = 75
;symbol slot_8 = 50

init:
    let pulse_time_ON = 100
    let pulse_time_OFF = 200
    let servo_pos = 255
    pause 500
    'gosub I2C_ON
    ' Move main servo to closed position
    'servo servo_IO, 255
    'servopos servo_IO, 255
    pause 800
    'servo servo_IO, 255
    ' Move outlet valve to closed position
    'servo Outlet_IO, 250
    'servopos Outlet_IO, 250
    pause 800
    'servo Outlet_IO, 250
    'gosub HI2C_init
    'gosub I2C_OFF
    disablebod
    'gosub clear_terminal

clear_terminal:
    SerOut A.4, N9600_8, (CR, CR, CR, CR, CR, CR, CR, CR, CR, CR, CR, CR, CR, CR)
    SerOut A.4, N9600_8, ("------------------------------------------------")

main_menu:
    SerOut 7, N9600, (CR, "--- Main Menu ---", CR)
    SerOut A.4, N9600_8, (_
        "Command | Action", CR, _
        "----------------", CR, _
        "1       | Return value at b0", CR, _
        "2       | Testing menu", CR, _
        "254     | Reset picaxe", CR, CR)
    SerOut A.4, N9600_8, ("Enter q<command>:  ")
    SerIn 6, N9600, ("q"), #b0
    SerOut A.4, N9600_8, (#b0, CR, CR, LF)
    if b0 = 1 then
        SerOut A.4, N9600_8, (#b0, CR, LF)
    elseif b0 = 2 then
        goto testing_menu
    elseif b0 = 254 then
        reset
    else 
        SerOut A.4, N9600_8, (CR, "Invalid input:  ", #b0, CR, LF)
    endif
    goto main_menu

testing_menu:
    SerOut A.4, N9600_8, (_
        "--- Testing Menu ---", CR, CR, _
        "Command | Action", CR, _
        "----------------", CR, _
        "1       | Pump sample", CR, _
        "2       | Manifold flush", CR, _
        "3       | Move servo to slot", CR, _
        "4       | Open outlet", CR, _
        "5       | Close outlet", CR, _
        "99      | Return to Main", CR, _
        "254     | Reset picaxe", CR, CR)
    SerOut A.4, N9600_8, ("Enter q<command>:  ")
    SerIn b.6, N9600_8, ("q"), #b0
    SerOut A.4, N9600_8, (#b0, CR)
    if b0 = 1 then
        SerOut A.4, N9600_8, ("Enter q<pump time>:  ", CR)
        SerIn b.6, N9600_8, ("q"), #pump_runtime
        SerOut A.4, N9600_8, ("Pumping ", #pump_runtime, " seconds", CR)
        gosub run_pump
    elseif b0 = 2 then
        gosub manifold_flush
    elseif b0 = 3 then
        do
            SerOut A.4, N9600_8, ("Move to slot q<0-8, 99=exit>:")
            SerIn b.6, N9600_8, ("q"), #slot_num
            SerOut A.4, N9600_8, (#slot_num, CR)
            if slot_num = 99 then
                goto testing_menu
            elseif slot_num > 8 then
                SerOut A.4, N9600_8, ("Invalid slot!", CR)
            elseif slot_num <= 8 then
                gosub move_servo
            endif
        loop
    elseif b0 = 4 then
        gosub cpen_outlet
    elseif b0 = 5 then
        gosub cpen_outlet
    elseif b0 = 99 then
        goto main_menu
    else 
        SerOut A.4, N9600_8, (CR, "Invalid input:  ", #b0, CR, LF)
    endif
    goto testing_menu


I2C_OFF:
    low I2C_pin
return

HI2C_init:
    ' Initialize servo I2C and turn on 6V LDO_6V
    ' When using the i2cword address length you must also ensure the 'address' used in the hi2cin and hi2cout commands is a word variable.
    HI2cSetup I2CMASTER, 128, I2CSLOW, I2CBYTE
    Hi2COut 0, (48)
    Hi2COut 254, (121)
    Hi2COut 1, (4)
    Hi2COut 0, (32)
return

Servo_ON: ' initialize servo I2C and turn on 6V LDO_6V
    gosub I2C_ON
    HI2cSetup I2CMASTER, $80, I2CSLOW, I2CBYTE
    'Hi2COut MODE1_REG,    ( %00110000 )
    'Hi2COut PRESCALE_REG, ( 121 )
    'Hi2COut MODE2_REG,    ( %00000100 )
    'Hi2COut MODE1_REG,    ( %00100000 )
return

cpen_outlet:
    SerOut A.4, N9600_8, (CR, "Opening outlet", CR)
    gosub I2C_ON
    servopos Outlet_IO, 150 ; initialise servo
    pause 800
    gosub I2C_OFF
    'servopos Outlet_IO,OFF   ' PWM for pump messed up if servopos not turned off, no idea why
    pause 500 ' give extra time to bleed pressure
return

close_outlet:
    ' Closed is default position set in init.
    SerOut A.4, N9600_8, (CR, "Closing outlet", CR)
    gosub I2C_ON
    servopos Outlet_IO, 250
    pause 800
    gosub I2C_OFF
    'servopos Outlet_IO,OFF  ' PWM for pump messed up if servopos not turned off, no idea why
return

run_pump:
    'For Motor on A
    'pin 4 high 5 high = stop
    'pin 4 high 5 low = forward
    high 4
    low 5
    for counter = 1 to pump_runtime
        pause 1000 ' give 1 second pause at 8Hz
    next counter
    high 5
return

pulse_pump:
    SerOut A.4, N9600_8, ("Enter q<pulses>:  ", CR)
    SerIn b.6, N9600_8, ("q"), #Sample_pulses ' Move this line to when asking for user input for sample pulses
    for i = 1 to Sample_pulses
        high 4
        low 5
        pause pulse_time_on ' run pump for pulse time, 100 ms
        high 5
        pause pulse_time_off
    next i
    'turn pump off ' move this line to asking user input about timing?
return

manifold_flush:
    SerOut A.4, N9600_8, ("Flush manifold")
    gosub cpen_outlet
    gosub run_pump
    SerOut A.4, N9600_8, ("Flushing manifold", CR)
    gosub close_outlet
return

move_servo:
    gosub I2C_on
    pause 200
    servo servo_IO, 255
    pause 750
    gosub calc_servo_pos
    servo servo_IO, servo_pos
    pause 750 ' give time for servo to move, MG966R and CS238MG are slow
return

'move_servo:
'    gosub calc_servo_pos
'    servo servo_IO, servo_pos
'return

calc_servo_pos:
    ' Calculates servo position in degrees
    if slot_num = 0 then
        servo_pos = 255
    else
        temp = slot_num*25  ' Math is left to right, not PEMDOS and no ()
        servo_pos = 255-temp-5
    endif
return