; DS3231 Definition

Symbol DS3231    = $D0 ; I2C Device

Symbol DAT_A1    = $07 ; Alarm 1 Registers
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
Symbol STS_A1IF  = bit0
Symbol STS_A2IF  = bit1
Symbol STS_BSY   = bit2
Symbol STS_EN32K = bit3
Symbol STS_OSF   = bit7

#Macro A2(x,d,h,m)
    ; Disable Alarm 2
    HI2cIn  CTR, (b0)
    CTR_A2IE  = 0
    HI2cOut CTR, (b0)
    ; Clear Alarm 2 Flags
    HI2cIn  STS, (b0)
    STS_A2IF  = 0
    HI2cOut STS, (b0)
    ; Set Alarm 2
    b0 = x
    b1 = m / 10 * 6 + m : b1 = bit0 * $80 | b1
    b2 = h / 10 * 6 + h : b2 = bit1 * $80 | b2
    b3 = d / 10 * 6 + d : b3 = bit2 * $80 | b3 : b3 = bit3 * $40 | b3
    HI2cOut DAT_A2, (b1,b2,b3)
    ; Enable Alarm 2 @ 1HZ
    HI2cIn  CTR, (b0)
    CTR_A2IE  = 1
    CTR_INTCN = 1
    CTR_RS1 = 0
    CTR_RS2 = 0
    HI2cOut CTR, (b0)
#EndMacro

;#Define A2_EVERY_M()     A2(%1111,0,0,0) ; per minute
;#Define A2_M(m)          A2(%1110,0,0,m) ; minutes match
#Define A2_HM(h,m)       A2(%1100,0,h,m) ; hours and minutes match
;#Define A2_DAY_HM(d,h,m) A2(%0000,d,h,m) ; day, hours and minutes match
;#Define A2_DOW_HM(w,h,m) A2(%1000,w,h,m) ; day of week, hours and minutes match

; Example code

HI2cSetup I2CMASTER, DS3231, I2CSLOW, I2CBYTE

A1_MS(10,30) ; Alarm 1 once an hour at xx:10:30
A2_EVERY_M() ; Alarm 2 every minute