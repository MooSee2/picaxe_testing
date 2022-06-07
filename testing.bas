

#PICAXE 28X2
#slot 0

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
symbol counter = b50
symbol slot_num = b45
symbol servo_pos = b46

' Valve Servo Positions
' Maybe reduce this to slot_num = 255 - (user_entered_slot*25-5), more math less symboles?
symbol slot_0 = 255 ' closed position
symbol slot_1 = 225
symbol slot_2 = 200
symbol slot_3 = 175
symbol slot_4 = 150
symbol slot_5 = 125
symbol slot_6 = 100
symbol slot_7 = 75
symbol slot_8 = 50

init:
    pause 500
    gosub I2C_ON
    ' Move main servo to closed position
    servo servo_IO, 255
    servopos servo_IO, 255
    pause 800
    servo servo_IO, 255
    ' Move outlet valve to closed position
    servo Outlet_IO, 250
    servopos Outlet_IO, 250
    pause 800
    servo Outlet_IO, 250
    gosub HI2C_init
    gosub I2C_OFF
    gosub clear_terminal

clear_terminal:
    SerOut b.7, N9600_8, (CR, CR, CR, CR, CR, CR, CR, CR, CR, CR)

main_menu:
    SerOut b.7, N9600_8, (CR, "--- Main Menu ---", CR)
    SerOut b.7, N9600_8, (_
        "Command | Action", CR, _
        "----------------", CR, _
        "1       | Return value at b0", CR, _
        "2       | Testing menu", CR, _
        "254     | Reset picaxe", CR, CR)
    SerOut b.7, N9600_8, ("Enter q<command>:  ")
    SerIn b.6, N9600_8, ("q"), #b0
    if b0 = 1 then
        SerOut b.7, N9600_8, (#b0, CR, LF)
    elseif b0 = 2 then
        SerOut b.7, N9600_8, (#b0, CR, LF, "Entering Testing Menu", CR)
        goto testing_menu
    elseif b0 = 254 then
        SerOut b.7, N9600_8, (#b0, CR, LF, "Entering Testing Menu", CR)
        reset
    else 
        SerOut b.7, N9600_8, (CR, "Invalid input:  ", #b0, CR, LF)
    endif
    goto main_menu

testing_menu:
    SerOut b.7, N9600_8, (CR, _
        "--- Testing Menu ---", CR, CR, _
        "Command | Action", CR, _
        "----------------", CR, _
        "1       | Pump sample", CR, _
        "2       | Manifold flush", CR, _
        "3       | Move servo to slot", CR, _
        "4       | Open outlet", CR, _
        "5       | Close outlet", CR, _
        "254     | Reset picaxe", CR, CR)
    SerOut b.7, N9600_8, ("Enter q<command>:  ")
    SerIn b.6, N9600_8, ("q"), #b0
    if b0 = 1 then
        SerOut b.7, N9600_8, (#b0, CR)
        gosub run_pump
    elseif b0 = 2 then
        SerOut b.7, N9600_8, (#b0, CR)
        gosub manifold_flush
    elseif b0 = 3 then
        SerOut b.7, N9600_8, (#b0, CR)
        gosub user_move_servo
    elseif b0 = 4 then
        SerOut b.7, N9600_8, (#b0, CR)
        gosub cpen_outlet
    elseif b0 = 5 then
        SerOut b.7, N9600_8, (#b0, CR)
        gosub cpen_outlet
    elseif b0 = 99 then
        SerOut b.7, N9600_8, (#b0, CR, " Returning to Main menu!", CR, LF)
        goto main_menu
    else 
        SerOut b.7, N9600_8, (CR, "Invalid input:  ", #b0, CR, LF)
    endif
    goto testing_menu

I2C_ON:     'turn on I2C, +V pin defined by symbol at top of program
    high I2C_pin
    pause 100
return

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

cpen_outlet:
    SerOut b.7, N9600_8, (CR, "Opening outlet", CR)
    gosub I2C_ON
    servopos Outlet_IO, 150 ; initialise servo
    pause 800
    gosub I2C_OFF
    'servopos Outlet_IO,OFF   ' PWM for pump messed up if servopos not turned off, no idea why
    pause 500 ' give extra time to bleed pressure
return

close_outlet:
    ' Closed is default position set in init.
    SerOut b.7, N9600_8, (CR, "Closing outlet", CR)
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
    SerOut b.7, N9600_8, ("Enter q<pump time>:  ", CR)
    SerIn b.6, N9600_8, ("q"), #b10
    SerOut b.7, N9600_8, ("Pumping ", #b10, " seconds", CR)
    high 4
    low 5
    for counter = 1 to b10
        pause 1000 ' give 1 second pause at 8Hz
    next counter
    high 5

return

manifold_flush:
    SerOut b.7, N9600_8, ("Flush manifold")
    gosub cpen_outlet
    gosub run_pump
    SerOut b.7, N9600_8, ("Flushing manifold", CR)
    gosub close_outlet

return

user_move_servo:
    Do
        gosub I2C_on
        SerOut b.7, N9600_8, ("Move to slot q<0-8, 99=exit>:")
        SerIn b.6, N9600_8, ("q"), #slot_num
        SerOut b.7, N9600_8, (#slot_num, CR)
        if slot_num = 99 then
            gosub I2C_OFF
            goto testing_menu
        elseif slot_num > 8 then
            SerOut b.7, N9600_8, ("Invalid slot!", CR)
            gosub user_move_servo
        endif
        servo_pos = slot_num * 25 - 5
        servo servo_IO, servo_pos
        pause 750 ' give time for servo to move, MG966R and CS238MG are slow

    Loop

move_servo:
        servo_pos = slot_num * 25 - 5
        servo servo_IO, servo_pos