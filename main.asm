; Copyright 2023-2024 Stefan Jakobsson
; 
; Redistribution and use in source and binary forms, with or without modification, 
; are permitted provided that the following conditions are met:
;
; 1. Redistributions of source code must retain the above copyright notice, this 
;    list of conditions and the following disclaimer.
;
; 2. Redistributions in binary form must reproduce the above copyright notice, 
;    this list of conditions and the following disclaimer in the documentation 
;    and/or other materials provided with the distribution.
;
;    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” 
;    AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
;    IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
;    ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS 
;    BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
;    CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
;    SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
;    INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
;    CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
;    ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF 
;    THE POSSIBILITY OF SUCH DAMAGE.

; Definitions
.include "tn861def.inc"
.include "pins.inc"
.include "registers.inc"

; Macros
.include "command.inc"

.cseg

.org 0xf00

;******************************************************************************
; Bootloader jump table
rjmp main                   ; Byte address: 0x1e00
rjmp update_firmware        ; Byte address: 0x1e02

;******************************************************************************
; Function...: main
; Description: Bootloader main entry
; In.........: Nothing
; Out........: Nothing
main:
    ; Disable interrupts
    cli
    
    ; Disable watchdog timer
    wdr
    ldi r16, 0
    out MCUSR, r16
    in r16, WDTCSR
    ori r16, (1<<WDCE) | (1<<WDE)
    out WDTCSR, r16
    ldi r16, 0
    out WDTCSR, r16

    ; Configure Reset button pin (PB4) as input pullup
    cbi DDRB, RESET_BTN
    sbi PORTB, RESET_BTN
    
    ; Short delay, approx 48 us
    ldi r16, 0xff
main2:
    dec r16
    brne main2
    
    ; Jump to firmware start vector, stored in EE_RDY (=ERDYaddr),
    ; if Reset button is not pressed (high)
    sbic PINB, RESET_BTN
    rjmp ERDYaddr
    
    ; Else fallthrough to power_on_seq

;******************************************************************************
; Function...: power_on_seq
; Description: System power on sequence
; In.........: Nothing
; Out........: Nothing
power_on_seq:
    ; Assert RESB
    sbi DDRA, RESB
    cbi PORTA, RESB

    ; Turn on PSU
    sbi DDRA, PWR_ON
    cbi PORTA, PWR_ON

    ; RESB hold time 500 ms
    ldi r18, 0x29
    ldi r17, 0xff
    ldi r16, 0xff
resb_hold_delay:
    dec r16
    brne resb_hold_delay
    dec r17
    brne resb_hold_delay
    dec r18
    brne resb_hold_delay

    ; Deassert RESB
    cbi DDRA, RESB

    ; Fallthrough to update_firmware

;******************************************************************************
; Function...: update_firmware
; Description: Starts firmare update procedure
; In.........: Nothing
; Out........: Nothing
update_firmware:
    ; Disable interrupts
    cli

    ; Set stack pointer to end of SRAM
    ldi r16, low(RAMEND)
    out SPL, r16
    ldi r16, high(RAMEND)
    out SPH, r16

    ; Setup
    clr zeroL
    clr zeroH
    rcall flash_clear_buf
    movw checksum:packet_size, zeroH:zeroL
    movw target_addrH:target_addrL, zeroH:zeroL
    clr packet_count
    clr chip_erased

    ; Start I2C
    rjmp i2c_main

.include "flash.asm"
.include "i2c.asm"
.include "version.asm"
