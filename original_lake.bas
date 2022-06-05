'The PCA9685 has a single 8-bit clock pre-scaler ( register $FE ) and, according to the datasheet, its value should be set as -

'pre-scaler value = ( clock / ( 4096 * update frequency ) ) - 1

'For a 25MHz clock and 50Hz frequency -

'pre-scaler value = ( 25MHz / ( 4096 * 50Hz ) ) - 1 = 121

'Note that the pre-scaler can only be written when in sleep mode, so it's probably the first register which needs to be set, or at least set before taking the chip out of sleep mode.

'So, if a 'PWM value' of 0 to 4095 gives an on period of 0ms to 20ms it should then be a simple matter of converting a servo position of 50 to 250 into a suitable off times to write to the LED control values -

'offTime = servoPosition * 4095 / 2000

'Untested, but I would guess something like -

'Hippy Servo code

'Symbol MODE1_REG     = $00
'Symbol MODE2_REG     = $01
'Symbol LED0_REG      = $06
'Symbol PRESCALE_REG  = $FE

'Symbol offTime       = w0 ; 0 to 4095
'Symbol offTime.lsb   = b0
'Symbol offTime.msb   = b1

'Symbol register      = b2

'Symbol servoNumber   = b3 ; 0 to 15
'Symbol servoPosition = b4 ; 50 to 250

'PowerOnReset:
'  HI2cSetup I2CMASTER, $84, I2CSLOW, I2CBYTE
'  Hi2COut MODE1_REG,    ( %00110000 )
'  For servoNumber = 0 To 15
'    servoPosition = 150
'    Gosub SetServo
'  Next
'  Hi2COut PRESCALE_REG, ( 121 )
'  Hi2COut MODE2_REG,    ( %00000100 )
'  Hi2COut MODE1_REG,    ( %00100000 )

'MainLoop:
'  Do
'    servoNumber = 0
'    For ServoPosition = 100 To 199
'      Gosub SetServo
'      Pause 20
'    Next
'    For ServoPosition = 200 To 101 Step -1
'      Gosub SetServo
'      Pause 20
'    Next
'  Loop

'SetServo:
'  register = servoNumber * 4 + LED0_REG
'  servoPosition = servoPosition Min 50 Max 250
'  offTime = servoPosition * 2
'  offTime = servoPosition ** 3112 + offTime
'  HI2cOut register, ( 0,0, offTime.lsb,offTime.msb )
'  Return

'Hippy added "Fixed maths overflow of 250 * 4095" , not sure where this is


 'SLOT#0 USED FOR MAIN PROGRAM
' USING SLOT#1 AS SETUP MENU AND TESTING SECTION
'
' AXE020 board with DS3231 RTC+EEPROM
'
' Li-ion batt voltage ADC on A.3

'IMPORTANT STEPPER MOTOR AND DC PUMP CONNECTIONS
' C.7 to AN2 Black to A0
' C.6 to AN1 Red to A1  
' C.5 to STDBY
' C.2 is PWM   PWMA & PWMB connected together
' C.1 to BN1 Green to B1
' C.0 to BN2 Green to B1

'A.0 is Servo_I2C-6V LDO switch

' Dual Lift Pumps running on TB6612- B channels

' Pulsing vial fill Kamoer small pump on TB6612 A channels
'

#PICAXE 28X2
 
#slot 0    
 
setfreq m8
pause 1000 ' give pause so terminal window can catch up

Symbol Servo_address = $80     ' Base address is 0x80 (not 0x40 !!!) , set I2C address for Servo board

Symbol MODE1_REG     = $00
Symbol MODE2_REG     = $01
Symbol LED0_REG      = $06
Symbol PRESCALE_REG  = $FE

Symbol RTC_address = $D0 ' set RTC address same for DS3231 or DS1340
Symbol EEPROM_address = $AE   ' set EEPROM address: $A0 for DS1340, $AE for DS3231
Symbol EEPROM_ptr_step = 32   ' set eeprom step, must be 8,16, or 32 for eeprom page length

'Symbol I2C_ON = C.0    ' power to I2C bus, has to match Servo I2C

'///// PIN ASSIGNMENTS ////////

symbol I2C_SERVO_RTC_LDO = A.0 ' turn on I2C FOR SERVO AND RTC AND 6V LDO

 symbol Outlet_IO = B.7   ' servo control for outlet valve
' TB6612 peristaltic and stepper motor driver control pin settings

symbol Sample_AIN2 = C.7 ' drive Sample pump on C.7 and C.6
symbol Sample_AIN1 = C.6
symbol TB6612_enable = C.5

symbol TB6612_PWM_port = C.2 ' PWMA and PWMB tied together to C.2 PWM
symbol PWM_period = 24   ' runs at 80KHz, if duty = 100 then should give ~100% of V2


symbol Sample_Stop = 8 ' max number of samples

Symbol MemMax = 64000   ' DS3231 with 512K bit 64000 data bytes = 4000 data lines for 16 byte increment


symbol Outlet_Servo = B.7   ' servo control for outlet valve

'/// Valve Servo Positions
symbol Servo_Move_time = 1500 ' msec pause time to allow servo to move, MG996R is slow
symbol Valve_0 = 255 ' closed position
symbol Valve_1 = 225
symbol Valve_2 = 200
symbol Valve_3 = 175
symbol Valve_4 = 150
symbol Valve_5 = 125
symbol Valve_6 = 100
symbol Valve_7 = 75
symbol Valve_8 = 50 ' some servos won't respond to 50


symbol Outlet_Open_position = 150 ' setting of
symbol Outlet_Close_position = 250
                                                               

'/// Peristaltic Pump fixed settings
symbol Pump_pulse_OFF_time = 900 ' peristaltic pulse = 800 ms
symbol Pump_pulse_ON_time = 100
'symbol Pump_pulse_duty = 100

'symbol Pump_pulse_Reverse_time = 25 ' reverse pump to decrease pressure

symbol Reservoir_Refill = 10 'top off reservoir if using
'symbol Reservoir_Refill = 60

'//SERVO variables////

Symbol offTime       = w0 ; 0 to 4095
Symbol offTime.lsb   = b0
Symbol offTime.msb   = b1

Symbol register      = b2

Symbol Servo_number   = b3 ; 0 to 15
Symbol Valve_number = b4 ; 1-8
'symbol Servo_position = b5 ; 50 to 255
symbol Servo_position = w3 ' allows to go to 260?
'symbol ServoLoops    = b5
'symbol Outlet_close_position    = b5
'symbol Outlet_open_position      = b6
'symbol                 = b7


'/// Peristaltic pump variables///
symbol Pump_time = w3
'symbol Pump_Pulses = w3

symbol Sample_pulses = w4 ' 100 pulses ~20 mL
symbol Sample_pump_time = b8
symbol Sample_pump_duty = b9

'symbol Pump_pulse_ON_time = w5 ' peristaltic pulse = 200 ms
'symbol Pump_pulse_OFF_time = w6 ' peristaltic pulse = 500 ms

'symbol Pump_pulse_Reverse_time = 25 ' reverse pump to decrease pressure
'symbol Filter_pump_time = w5
symbol Manifold_Flush_Time = w6
symbol Lift_Pump_time = w7

symbol Pump_duty = b17
symbol Peristaltic_mode = b18   ' set peristaltic to lift or drain
symbol Filter_pump_duty= b19

'symbol Sample_time = b15
'symbol DI_Rinse_time = b13
'symbol Slow_Drain_time = b15

'symbol Pump_OFF_time = w7
'symbol Pump_ON_time = b16

'symbol Fast_duty = b18
'symbol Slow_duty = b19


'/// SENSOR VARIABLES W10-W13
symbol Temp = w10
symbol Temp_lsb = b20
symbol Temp_msb = b21
symbol Picaxe_Batt  = w11
symbol Li_Batt  = w12
symbol Li_Batt_divider = b28

symbol CALVDD = 52378   ; 1023*1.024*1000/20  (DAC steps * Ref V / Resolution in mV)  
symbol Batt = w0
symbol Batt_sum = w1
symbol Batt_correction = w2   ' only need during BATTcalc
symbol Batt_remainder = w27   ' only need during BATT calc
      'ADC channel for Batt voltage

'//// COUNTERS AND FLAGS  W15-W25 /////

symbol Second = b30 ' need unique variable or else countdown messes up
symbol Minute = b31
symbol Hour  = b2
symbol Last_minute = b33
symbol Sleep_end = w17
symbol Minute_counter = w18
symbol Countdown = w19
symbol RTC_flag = b32

'///// SAMPLE TIMING, COUNTERS AND FLAGS  W20-W25 ///////////
symbol SAM_1_interval = w20
symbol SAM_2_interval = w21
'symbol BigBubble_count = b44
symbol Subsample_count = b45
symbol SAM_1_number = b46
symbol Number_subsamples = b47
symbol Sample_count = w24
symbol EEPROM_ptr = w25

symbol Total_Sample_pulses = w0
symbol Total_Sample_time = w27


'/// GENERAL USE VARIABLES
symbol I = b52     '
symbol J = b53
symbol Z = w27

' goto Main_Menu

Load_Default_Parameters:

'Let Lift_pump_time = 10
Let Manifold_flush_time = 300 '60 for 3m
Let Sample_pulses = 30 '45
Let SAM_1_interval = 1440     ' 1440 min/day, 10080 min/week, 14400 min/10 days
'Let SAM_2_interval = 120         '120 min for sampling every 2 hours
Let SAM_1_number = 8
Let Number_subsamples = 7   'setting up for daily subsampling and weekly composite
if Li_Batt_divider = 0 then   ' use stored batt-divider unless it's zero
let Li_Batt_divider = 60
 else
read 26, Li_Batt_divider
endif

gosub Store_Variables

'return

Main_Menu:

disablebod
gosub Read_Memory
' if Sample_Pulses = 0 then goto Load_Default_Parameters

     gosub Low_Power_Setup   ' turn  off ADCs and have background low power

gosub Reset_Minute_Counter

' gosub Get_Picaxe_batt
' gosub Get_Li_Batt

let RTC_flag = 0   ' reset flags
sertxd (CR,LF,CR,LF,"ServoSipper-Koocanusa-Slot#0-Weekly Integrated-RTCFail-April5-2022",CR,LF)

gosub Show_Parameters

sertxd (CR,LF,"1)Pump & Timing Setup 4)Load Default Parameters")  
sertxd (CR,LF,"5)Pump_Servo Test 6)Read/Retrieve data")  
sertxd (CR,LF,"7)Set RTC 9)Start Sampling")  
      gosub Get_Counters_Voltages
     
sertxd (CR,LF,"ENTER number ")     'Get input
 

'      if RTC_flag = 0 then
     
      gosub Display_Time
      serrxd [65000,Main_Menu],#J   ' gives 15 second wait if connected to computer

if J = 1 then gosub Pump_Timing_Menu

if J = 4 THEN     gosub Load_Default_Parameters

if J = 5 THEN     goto Pump_Servo_Test
if J = 6 THEN     gosub Read_Data
IF J=7 THEN    
pause 100   ' need slight pause or program hangs up
run 1
endif

IF J = 9 THEN     goto Start_Delay  

goto Main_Menu

Show_Parameters:
Total_Sample_time = SAM_1_interval * Number_subsamples
sertxd (CR,LF,"Manifold_Flush(sec) SAM_pulses Pulse_ON Pulse_OFF",CR,LF)
sertxd (" ",#Manifold_Flush_time," ",#Sample_pulses," ",#Pump_pulse_ON_time," ",#Pump_pulse_OFF_time,CR,LF)
sertxd ("SAM_interval(min)  #Subsamples TotalCompositeTime",CR,LF)
sertxd ("   ",#SAM_1_interval," ",#Number_subsamples," ",#Total_Sample_time)

return
Get_Counters_Voltages:
gosub Get_Picaxe_batt
gosub Get_Li_Batt
gosub Read_Memory
  SerTxd (CR,LF,CR,LF,"EEPROM=",#EEPROM_ptr,", LastSAM=",#Sample_count,"-",#Subsample_count,", Pic_Volts= ",#Picaxe_Batt,", Li_Volts= ",#Li_Batt,CR,LF)
return

Start_Deployment:
' gosub Load_Default_Parameters
EEPROM_ptr = 0     ' reset EEPROM_ptr
gosub Get_Time
RTC_flag = 0 ' reset RTC_flag
Sample_count = 1   ' reset Sample_count
Subsample_count = 0
Let Servo_number = 0 ' start sampling with valve = 0
Let Valve_number = 1
write 3, Servo_number
write 4, Valve_number
goto Servo_Sipper_Sampling
return

Servo_Sipper_Sampling:   ' #Subsamples = 1 is discrete, #Subsample > 1 is integrated sampling
sertxd (CR,LF,CR,LF,"Servo Sampling",CR,LF)
write 48, word Sample_count  
for Subsample_count = 1 to Number_subsamples
gosub Reset_Minute_Counter
if RTC_flag = 0 then
  gosub Get_Time
else
  sertxd(CR,LF,CR,LF,"RTC FAIL SMAPLING",CR,LF)
endif
if Subsample_count = 1 then
gosub Store_Data ' store beginning of sample integration  
 else
gosub Display_data ' display subsample data
endif
write 45, Subsample_count ' save subsample count for RTC fail sampling indicator

gosub Manifold_Flush

gosub Filtered_Unfiltered_Sampling
' gosub Manifold_Drain
  RTC_Fail_return: ' Get_Time subroutine return point if RTC fail
gosub Sleep_Setup
next Subsample_count

gosub Get_Servo_Valve_number
Sample_count = Sample_count + 2 ' increment sample# to next sample set of 2
Valve_number = Valve_Number + 2 ' increment valve 2 positions for next sample set
if Valve_number < 8 then ' increment valve number and keep servo number same

Servo_number = Servo_number
Valve_number = Valve_Number  
else ' increment servo number and reset valve number
    Servo_number = Servo_number + 1 ' select next servo number
    Valve_number = 1 ' reseet to valve1 for new servo sample set
    Subsample_count = 1 ' reset subsample to 1
endif
write 3, Servo_number 'store new servo number
write 4, Valve_Number 'store new valve number
if Sample_count > Sample_stop then goto Shutdown
goto Servo_Sipper_Sampling     ' repeat sampling

return

Get_Servo_Valve_number:
read 3, Servo_number ' get stored servo#
read 4, Valve_number ' get stored valve#
return

Filtered_Unfiltered_Sampling:

gosub Get_Servo_Valve_number
gosub Sample_Fill
pause 1000
gosub Get_Servo_Valve_number
Let Valve_number = Valve_number + 1 ' move to next valve for unfiltered sample

gosub Sample_Fill

return

Sample_Fill:
gosub Close_outlet_valve
gosub Get_Valve_position

gosub Move_Servo
gosub Pulsed_Sample_Pump_Run
gosub Open_Outlet_valve ' open outlet valve to take pressure out of system, then move 8 valve to home
gosub Close_Servo_Valve ' move servo to home, all valves closed

return
Pump_Servo_Test:

gosub I2C_OFF
SerTxd (CR,LF,CR,LF,"TESTS 99=exit")
SerTxd (CR,LF,"1)Move Servo")
SerTxd (CR,LF,"3)Sample Pump")
SerTxd (CR,LF,"5)Open/Close Outlet")
SerTxd (CR,LF,"7)Wet Filters")
SerTxd (CR,LF,"8)Sample Fill")
SerRxd [65535,Pump_Servo_Test], #J
if J = 99 then goto Main_Menu
if J = 1 then
Repeat_Servo:
gosub Select_Servo_Valve
gosub Move_Servo
gosub I2C_OFF
goto Repeat_Servo
endif

if J = 3 then
gosub Open_Outlet_valve
gosub Enter_pump_time_duty
gosub Sample_Pump_Run
J=0
endif

if J = 5 then
    SerTxd (CR,LF,"0=Open, 1=Close")
    SerRxd [65535,Pump_Servo_Test], #J
If J = 0 then
    gosub Open_Outlet_valve
else
gosub Close_Outlet_valve
endif
endif

if J = 7 then
    gosub Enter_Pump_pulses
    gosub Close_Outlet_valve
    Servo_number = 0
    for Valve_number = 1 to 8
    gosub Get_Valve_position
    gosub Move_Servo
    gosub Pulsed_Sample_Pump_Run
    next Valve_number
    gosub Close_Servo_valve
    gosub Open_Outlet_Valve
    gosub I2C_OFF
endif

if J = 8 then
gosub Close_Outlet_valve
gosub Select_Servo_valve
gosub Move_Servo
gosub Enter_Pump_pulses
gosub Pulsed_Sample_Pump_Run
gosub Open_Outlet_valve ' open outlet to drop pressure before moving 8 valve to home
gosub Close_Servo_Valve
endif
if J = 9 then
Repeat_Servo_Position:
gosub Select_Servo_Position
gosub Move_Servo
gosub I2C_OFF
goto Repeat_Servo_Position
endif

goto Pump_Servo_Test
return

'/// SERVO OPERATIONS /////////////////////////////////////////////////

Get_Valve_position:
lookup Valve_number,(Valve_0,Valve_1,Valve_2,Valve_3,Valve_4,Valve_5,Valve_6,Valve_7,Valve_8),Servo_position
return


Servo_ON: ' initialize servo I2C and turn on 6V LDO_6V
gosub I2C_ON
HI2cSetup I2CMASTER, Servo_address, I2CSLOW, I2CBYTE
      Hi2COut MODE1_REG,    ( %00110000 )

Hi2COut PRESCALE_REG, ( 121 )
Hi2COut MODE2_REG,    ( %00000100 )
Hi2COut MODE1_REG,    ( %00100000 )
return

Move_Servo: ' make sure turn servo off after pumping
gosub Servo_ON

sertxd (CR,LF,"Servo# ",#Servo_number,", Valve# ",#Valve_number,", position= ",#Servo_position)
register = Servo_number * 4 + LED0_REG
Servo_position = Servo_position 'Min 0 Max 255
offTime = Servo_position * 2
offTime = Servo_position ** 3112 + offTime
' offTime = Servo_position ** offTime_Offset + offTime

' sertxd (CR,LF,"Offtime= ",#Offtime)
HI2cOut register, (0,0, offTime.lsb,offTime.msb)
' pause 100
' HI2cOut register, (0,0, offTime.lsb,offTime.msb) ' send signal twice
pause Servo_Move_time ' give time for servo to move, MG966R and CS238MG are slow
gosub I2C_OFF ' turn off servo after
Return

Select_Servo_Valve:

sertxd (CR,LF,CR,LF,"Enter Servo (0-15)")      ' Get input
gosub Exit_99
Servo_number = Z
sertxd (CR,LF,CR,LF,"Enter Valve# (1-8, 0=closed, 4=middle)")      ' Get input
serrxd [65535,Pump_Servo_Test], #Valve_number
gosub Get_Valve_position
return

Select_Servo_position:

sertxd (CR,LF,CR,LF,"Enter Servo (0-15)")      ' Get input
gosub Exit_99
Servo_number = Z
sertxd (CR,LF,CR,LF,"Enter Position (50=left, 150=center, 250=right)")      ' Get input
serrxd [65535,Pump_Servo_Test], #Servo_position
' sertxd (CR,LF,CR,LF,"Servo# ",#Servo_number,", position= ",#Servo_position)
' gosub Move_Servo
return

Open_Outlet_Valve:
sertxd (CR,LF,CR,LF,"Open outlet")
gosub Servo_ON
servo Outlet_IO,Outlet_open_position ; initialise servo
servopos Outlet_IO,Outlet_open_position ; initialise servo
pause 800
gosub I2C_OFF
servopos Outlet_IO,OFF   ' PWM for pump messed up if servopos not turned off, no idea why
pause 500 ' give extra time to bleed pressure
return

Close_Outlet_Valve:    
sertxd (CR,LF,CR,LF,"Close Outlet")
' serrxd [65535,Main_Menu], #Outlet_close_position

gosub Servo_ON
servo Outlet_IO,Outlet_close_position ; initialise servo
servopos Outlet_IO,Outlet_close_position ; initialise servo
pause 800
gosub I2C_OFF
      servopos Outlet_IO,OFF   ' PWM for pump messed up if servopos not turned off, no idea why
 '    setfreq m8
return

Move_Outlet_Valve:

' sertxd (CR,LF,CR,LF,"Select Position (50=left, 150=center, 250=right) (99=exit)")      ' Get input
' serrxd [65535,Pump_Servo_Test], #Servo_position
' if Servo_position = 99 then goto Pump_Servo_Test

' gosub Servo_ON
' setfreq m8   ' Servo command only works at 8MHz
' servo Outlet_IO,Outlet_close_position ; initialise servo
' pause 1000
' sertxd (CR,LF,"Move to 250 then move position= ",#Servo_position)
' servopos Outlet_IO,Servo_position ; initialise servo
' pause 1000
' goto Move_Outlet_Valve
' gosub I2C_OFF
return

Close_Servo_Valve:
    sertxd (CR,LF,CR,LF,"Close valve")      
' for J = 1 to 2 ' multiple close valves if get stuck
Valve_number = 0
gosub Get_Valve_position
Gosub Move_Servo    
' next J
return

I2C_ON:     'turn on I2C, +V pin defined by symbol at top of program
high I2C_SERVO_RTC_LDO
pause 100
return

I2C_OFF:
low I2C_SERVO_RTC_LDO
return

'////////// PERISTALTIC PUMP ROUTINES ////////////////////////////////////////
Pulsed_Sample_Pump_Run:

high TB6612_enable ' high C.5    ' enable STDBY
SerTxd (CR,LF,CR,LF,"Pulses= ",#Sample_pulses,CR,LF)             ' Get input
  SerTxd (CR,LF,"Pulse# ")
for Z = 1 to Sample_pulses
SerTxd (#Z,",")             ' Get input
 
pwmout TB6612_PWM_port, PWM_period, 100 ' Pulse peristaltic set at 100% duty
low Sample_AIN1         ' low C.6  
high Sample_AIN2        'high C.7          ' forward TB6612
pause Pump_pulse_ON_time ' run pump for pulse time, 100 ms

pwmout TB6612_PWM_port, PWM_period, 0 ' pause pumping

Pause Pump_Pulse_OFF_time ' Pulse relaxation time

next Z
gosub Pumps_OFF
return

Sample_Pump_Run:
' setfreq m8
SerTxd (CR,LF,"Pump time= ",#Pump_time,", Duty= ",#Pump_duty)

high TB6612_enable ' high C.5       ' enable STDBY
pause 50
pwmout TB6612_PWM_port, PWM_period, Pump_duty


low Sample_AIN1         ' low C.6  
high Sample_AIN2        'high C.7          ' forward TB6612
for Z = 1 to Pump_time  
pause 1000 ' give 1 second pause at 8Hz

next Z
gosub Pumps_OFF


return

Manifold_Flush:
gosub Open_Outlet_Valve
' pause 500

SERTXD (CR,LF,CR,LF,"Manifold flush")
Pump_duty = 100  
Pump_time = Manifold_Flush_time
Peristaltic_mode = 0     ' set to lift
gosub Sample_Pump_Run

return

Pumps_OFF:   ' make sure all B ports off
let pinsB = %00000000   ' switch all B outputs off, including 3 way valve
let pinsC = %00000000   ' switch all C outputs off
pwmout TB6612_PWM_port, 0, 0   ' turn off PWM    

gosub I2C_OFF ' turn off servos

return

Enter_pump_time_duty:
SerTxd (CR,LF,CR,LF,"Enter Pump time")
gosub Exit_99
Pump_time = Z
SerTxd (CR,LF,"Enter Pump_duty")         ' Get input
SerRxd [65535,Pump_Servo_Test], #Pump_duty

return

Enter_pump_pulses:
SerTxd (CR,LF,CR,LF,"Enter Pulse#")             ' Get input
gosub Exit_99
Sample_pulses = Z
SerTxd ("Pulses= ",#Sample_pulses)

return

Exit_99:
 sertxd("(99=Exit)") ' exits out of test loops
 SerRxd [65535,Pump_Servo_Test], #Z
 if Z = 99 then goto Pump_Servo_Test
return


'/////// ' SUBROUTINES /////////////////////////////

Sleep_Setup:
' sertxd (CR,LF,"SleepSetup")
if RTC_flag = 0 then

gosub Get_Time

Sleep_end = SAM_1_interval - Minute_counter ' uses minute_counter to count elapsed pump run time
if Sleep_end > SAM_1_interval then   'reset sleep end if roll over barf
Sleep_end = SAM_1_interval
endif
' sertxd (CR,LF,"Sleep end= ",#Sleep_end,CR,LF)

gosub Deep_Sleep

 else ' goes to RTC fail if RTC_flag = 1
 
     gosub RTC_Fail_Sleep

endif


return

Low_Power_Setup:

disablebod   ' make sure disablebod on,
let adcsetup = %000000000000000     ' make sure ADCs OFF

let dirsA = %1111   'switch A ports pn 28X2 board to outputs for lowest powersleep
let dirsB = %11111111
let dirsC = %11111111

let pinsA = %0000 ' make sure all pins OFF
let pinsB = %00000000 ' make sure all pins OFF
let pinsC = %00000000 ' make sure all pins OFF

return


RTC_FAIL_Sleep:  

sertxd (CR,LF,"RTC-fail Sleep, Countdown= ",#Countdown)
Z = Manifold_flush_time + Sample_pulses ' Get sample run time in seconds
Z = Z/60 ' convert sample run time to minutes
sertxd (CR,LF,"Sample_duration (min)= ",#Z)
Sleep_end = SAM_1_interval - Z

sertxd (CR,LF,"RTC-fail Sleep (min)= ",#Sleep_end)

Sleep_end = Countdown * 28    ' computes sleep end minutes (minutes * 29  sleepticks/minute

sleep Sleep_end   ' goes to sleep and bypasses RTC

return

Deep_Sleep:

gosub Low_Power_Setup

if Sample_count => Sample_stop then goto Shutdown     'goto Shutdown at end of run

gosub Reset_Minute_Counter    ' restart minute counter for deep sleep
Countdown = Sleep_end        
gosub Minute_Countdown
gosub Subminute_Countdown
gosub Zero_Countdown
setfreq m8   ' make sure power up back to m8 for sample runs
return

Minute_Countdown:

sertxd (CR,LF,"Countdown= ",#Countdown,CR,LF)

do while Countdown > 1   ' exits countdown 1 minute before wakeup
sertxd (#Countdown,", ")
sleep 20     ' sleep 20 ~45 secs

gosub Get_Time

Countdown = Sleep_end - Minute_counter

if Countdown > Sleep_end then ' failsafe for sleep end, resets countdown if sleep_end-minute_counter returns negative number and rolls over to >65000
Countdown = Sleep_end
endif
loop


return

Subminute_Countdown:    
do while Second < 50     ' needs to wakeup a few sec sec before 0 seconds so sample start is exactly on time
 sleep 4   ' sleeps 8-9 seconds
 gosub Get_Time
loop
return

Zero_Countdown:

do while Second <> 0     ' finish sleep loop when get to 0 seconds
pause 200
gosub Get_Time
'     sertxd ("sec = ",#Second,CR,LF)
loop  
return

Get_Time:

gosub I2C_ON ' turn on I2C bus board
ptr = 0     'reset pointer to scrachpad address 0 for time values
hi2csetup i2cmaster,RTC_address,i2cslow,i2cbyte ' set i2c for DS1340/DS3231
 for I = 5 to 0 step -1       ' MD, read from registers 5,4
if I=3 then       ' skip register 3 (DOW), read register 6 (year)
           let I=6     ' HMS, read from registers 2,1,0
      endif

hi2cin I,(b0)     ' get time from RTC, position I
bcdtoascii b0,b1,b2     ' convert BCD to ASCII
@ptr=b1     ' write to scratchpad
inc ptr
@ptr=b2
inc ptr
if I = 6 then
let I = 3   ' reset J after reading year to read HH:MM:SS
endif
 next I
 
hi2cin 0,(Second, Minute, Hour)     ' get second,minute, hour, day for various counters, skips #3 DOW
pause 50
hi2cin $11,(Temp_msb, Temp_lsb)     ' get Temp off DS3231
pause 50
Temp = Temp **25600     ' convert Temp to ascii *100, 1875 = 18.75oC
gosub I2C_OFF     ' turn off I2C bus

Second = BCDTOBIN Second ' convert second to ascii for subminute and zero countdown
Minute = BCDTOBIN Minute ' convert minute to ascii for minute countdown  
Hour   = BCDTOBIN Hour   ' convert hour to ascii for subminute and zero countdown
'Day   = BCDTOBIN Day   ' convert day to ascii for day delay start
'Month  = BCDTOBIN Month
if Minute = Last_minute then  
Minute_counter = Minute_counter
endif  

if Minute <> Last_minute then ' properly increments minute counter and deals with 59 to 0 top of minute second change
if Minute < Last_minute then
Minute_counter = Minute_counter + Minute + 60 - Last_minute
 else

      Minute_counter = Minute_counter + Minute - Last_minute
endif
endif
Last_minute = Minute     ' store last minute for minute counter calcs
IF Second < 0 OR Second > 59 then   ' check for proper RTC operation

RTC_flag = 1

write 34, RTC_flag
    Sertxd (CR,LF,"RTC FAIL_flag= ",#RTC_flag,CR,LF)
'    gosub RTC_FAIL_Sleep    ' restart MiniSipper sampling without RTC time
'    goto Servo_Sipper_Sampling    
goto RTC_Fail_return ' returns to sampling program and redoes sleep setup and goes to RTC fail sleep
else
     RTC_flag = 0 ' normal RTC function
'     Sertxd (CR,LF,"RTC_flag = ",#RTC_flag,CR,LF)

endif
Return

Display_Ptr:
ptr = 0           'set pointer to beginning of clock data at scratchpad address 192, write data to terminal
sertxd (@ptrinc,@ptrinc,"/",@ptrinc,@ptrinc,"/20",@ptrinc,@ptrinc," ",@ptrinc,@ptrinc,":",@ptrinc,@ptrinc,":",@ptrinc,@ptrinc)
return

Display_Time:
sertxd ("Time= ")
gosub Get_Time
gosub Display_Ptr
return

Reset_Minute_Counter:
Minute_counter = 0 ' reset minute counter to 0 to keep track of sleeps
return

Shutdown:   ' go to low power sleep after stop sample
sertxd (CR,LF,"SHUTDOWN")
sleep 288   ' sleep ~10 minutes
goto Shutdown
return


'////// START DELAY ROUTINES //////////////////////////////////////////////

Start_Delay:
' sertxd (CR,LF,CR,LF,"! MAKE SURE PUMP PULSES & TIMES ARE CORRECT !")
gosub Show_Parameters

Sample_count = 0   ' reset sample count so start delay doesn't trip Event Sampling
sertxd (CR,LF,"0=NOW",CR,LF)
sertxd ("1=Set MINUTE",CR,LF)
'      sertxd ("2= start HOUR",CR,LF)
'     sertxd ("Enter 3 to set start DAY",CR,LF,CR,LF)
      sertxd ("9=exit",CR,LF)

gosub Display_Time

serrxd [65535,Start_Delay], #J

if J = 0 then goto Start_Deployment
if J = 1 then goto Minute_Hour_Delay
' if J = 2 then goto Minute_Hour_Delay
'     If J = 3 then goto Day_Delay
if J = 9 then goto Main_Menu

Minute_Hour_Delay:

sertxd (CR,LF,CR,LF)
gosub Display_Time
 
      if J = 1 then
      sertxd (CR,LF,CR,LF,"Set start minute (60=0)",CR,LF)
serrxd [65535,Start_Delay], #J
if J < Minute then       ' error trap when start minute < current minute
J = J +60
endif

gosub Get_Time

Sleep_end = J - Minute   ' set up minute and second counters for countdown

else   ' goto hour delay
'     sertxd (CR,LF,"Set UTC start hour (enter 24 for 00)",CR,LF)
'     serrxd [65535,Start_Delay], #J
'     if J < Hour then   ' error trap when start hour < current hour
'     J = J + 24
'     endif
'     gosub Get_Time

'     Sleep_end = J-Hour*60-Minute   ' set sleep end minute
endif

gosub Deep_Sleep

goto Start_Deployment

return

'/// DATA SUBROUTINES ////////////////////////////////////////////
Store_Data:

'1024Kbit chip = 128K bytes, on two 64K pages, just using page 1, = 2000 32 byte data lines
'need ~22 bytes of data but increment data 32 bytes so
'don't overflow page length of 128 bytes length, datafile increment needs to be exact division of 128 (i.e. 8,16,32, 64)
'wastes a lot of EEPROM data slots but retrieving datafile much easier  

gosub Get_Li_Batt 'uses internal calib Vref
gosub Get_Picaxe_Batt   'uses internal calib Vref

Z = EEPROM_ptr     ' set Z to stored EEPROM data pointer value

      If Z < MemMax then ' if hit memmax, then shutdown

gosub I2C_ON ' turn on I2C bus board

hi2csetup i2cmaster,EEPROM_address,i2cfast,i2cword    ' set slave address for EEPROM

pause 50     'need short delay or program barfs

'///////// have to load and read EEPROM data in bytes, can't use words/////////////////////

ptr = 0     ' reset ptr to start of time records
   
      if RTC_flag = 0 then
      hi2cout Z, (b48,b49,@ptrinc,@ptrinc,@ptrinc,@ptrinc,@ptrinc,@ptrinc,@ptrinc,@ptrinc,@ptrinc,@ptrinc,@ptrinc,@ptrinc,b20,b21,b22,b23,b24,b25)     'write data to EEPROM (Sam-ID is word variables divided into b24/25)
' else
' b0 = 0
'       hi2cout Z, (b48,b49,b0,b0,b0,b0,b0,b0,b0,b0,b0,b0,b0,b20,b21,b22,b23,b24,b25) 'send 0s if RTC messed up     'write data to EEPROM (Sam-ID is word variables divided into b24/25)
endif
sertxd (CR,LF)

gosub Display_Data

gosub I2C_OFF     ' turn off I2C bus board


Z = Z + EEPROM_ptr_step 'increment dataptr 20/32 bytes so don't run into page barrier

EEPROM_ptr = Z

write 50, word EEPROM_ptr     ' write eeprom-ptr byte to 28x2 onboard eeprom (not i2c memory)
else

sertxd (CR,LF,"MEM FULL",CR,LF)
end   ' stop program when hit memmax

      endif
return
 
Read_Data: ' READ EEPROM OFF SLOT#1 to save space

' sertxd (CR,LF,"EEPROM_ptr =",#EEPROM_ptr,",     Last Sample = ",#Sample_count,CR,LF)

gosub I2C_ON ' turn on I2C bus board

hi2csetup i2cmaster,EEPROM_address,i2cfast,i2cword     ' set i2c for EEPROM at address 0

EEPROM_ptr = EEPROM_ptr - EEPROM_ptr_step ' last store data added fields to counter, must remove them

sertxd (CR,LF,"Read#, SAM-ID, Date-Time, Temp, Li-Batt, Pic-Batt",CR,LF)

Z = 0 ' reset Z ptr
Read_Data_Loop:
for J = 1 to 5   ' only have 4 timestamps for Koocanusa

'///////// have to load and read EEPROM data in bytes, can't use words/////////////////////
ptr = 0     ' reset scratchpad to 0

     hi2cin Z, (b48,b49,@ptrinc,@ptrinc,@ptrinc,@ptrinc,@ptrinc,@ptrinc,@ptrinc,@ptrinc,@ptrinc,@ptrinc,@ptrinc,@ptrinc,b20,b21,b22,b23,b24,b25) 'write data to EEPROM (Sam-IDis word variable divided into b24/25)

      gosub Display_Data
     
Z = Z + EEPROM_ptr_step ' increment ptr 32 bytes so don't run into page barrier for 19 fields

next J

'     sertxd (CR,LF," Enter 1 to continue data download, (9 to exit)", CR,LF)
'     serrxd [65535,Main_Menu], #J
'     if J = 1 then goto Read_Data_Loop
'     if J = 9 then goto Main_Menu

gosub I2C_OFF     ' turn off I2C bus board
return

Display_Data:
read 3, Servo_number
read 4, Valve_number

      SerTxD (CR,LF,"SAM=",#Sample_count,"-",#Subsample_count,",")
'     pause 500

gosub Display_Ptr

sertxd (",",#Temp,",",#Picaxe_Batt,",",#Li_Batt,CR,LF)

return

Reset_EEPROM:     ' reset external EEPROM and internal 28X2 EEPROM to zero

  EEPROM_ptr = 0   ' reset datafile to record 0
  write 50, b50   ' write eeprom-ptr byte to 28x2 onboard eeprom (not i2c memory)
  write 51, b51   ' write eeprom-ptr byte to 28x2 onboard eeprom (not i2c memory)

  let b0 = 0
  for I = 60 to 255     ' clear picaxe eeprom for RTC fail sampling data
      write I, b0
  next I

return

'////////// PUMP ROUTINES ////////////////////////////////////////

Get_Picaxe_Batt:   ' calibadc only works with F25K22 chip, will return 0V with F2520 chip

w0 = 0
calibadc10 w0     ; Measure FVR (nominal 1.024 v) relative to Vdd (1024 steps)
w1 = w0 / 2 + CALVDD    ; Effectively round up CALVDD by half a (result) bit
w1 = w1 / w0 ; Take the reciprocal to calculate (half) Vdd (tens of mV)
calibadc10 w0     ; Read the value again because noise may be present :)
w0 = CALVDD / w0 + w1   ; Calculate Vdd/2 again and add in the first value
Picaxe_Batt = w0
return

Get_Li_Batt: 'ADC has 256 steps from 0-5V, each step is ~0.02V

Li_Batt = 0 'clear value before calculation
read 26, Li_Batt_divider

     let dirsA = %0000   ' make sure A.3 pin as input

      let adcsetup = %0000000000001000    'set ADC 3 (A.3) as input pin
Batt_sum = 0

for I = 1 to 3     'All DS3231 and DS1340 boards set up so Batt V read on A.3
readadc10 3, Batt ' read Li-ion on ADC pin A.3
pause 150   ' give delay to read ADC
'     SerTxd (CR,LF,"readadc BATT on ADC 0= ",#Li_BATT,CR,LF)
BATT_remainder = Batt*10//Li_Batt_divider
Batt = Batt*10/Li_Batt_divider

Batt_correction = Batt_remainder*10/Li_Batt_divider
'     SerTxd ("correction = ",#Batt_correction,CR,LF)
Batt = BATT*10 + Batt_correction
'     SerTxd ("BATT = ",#Li_Batt,CR,LF)

Batt_sum = BATT + Batt_sum
next I
Li_Batt = Batt_sum/3
'     sertxd ("Li_Batt = ",#Li_Batt,CR,LF)

let dirsA = %0000   ' sets portA pins as input so don't float

return
'///////Pump and Timing Menus
Pump_Timing_Menu:
  sertxd (CR,LF,"Manifold_flush_time (s)") ' Get input
  serrxd [65535,Pump_Timing_Menu],#Manifold_Flush_time

sertxd (CR,LF,CR,LF,"SAM pulses") ' Get input
  serrxd [65535,Pump_Timing_Menu],#Sample_pulses
' sertxd (CR,LF,"Lift_Pump_time",CR,LF) ' Get input
' serrxd [65535,Pump_Timing_Menu],#Lift_Pump_time

  sertxd (CR,LF,"SAM Interval (min)") ' Get input
  serrxd [65535,Pump_Timing_Menu],#SAM_1_Interval
gosub Store_Variables
return


'////// RELOAD PARAMETERS ROUTINES ////////////////////////////////////////  

Store_Variables:

write 8, word Sample_pulses
'write 10, word Pump_pulse_ON_time
'write 12, word Pump_pulse_OFF_time
write 12, word Manifold_Flush_time
'write 14, word Lift_pump_time

write 26, Li_Batt_divider
write 40, word SAM_1_interval

'write 42, word SAM_2_interval
write 46, SAM_1_number
write 47, Number_subsamples
return

Read_Memory:

     read 8, word Sample_pulses
     read 12, word Manifold_Flush_time
     read 40, word SAM_1_interval 'read sam1 interval
     read 45, Subsample_count
     read 46, SAM_1_number 'read sam1 number
     read 47, Number_subsamples ' read number_subsamples
     read 48, word Sample_count
     read 50, word EEPROM_ptr ' read saved eeprom ptr location byte into variable on reset
return