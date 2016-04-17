/*
 * main.s - main file of AVR asm program,
 * which shows the level of input analog signal
 * at A0 (PC0) on a ten-level scale (PD3-PD8, PB0-PB4).
 * The button (PD2) push inverses the signal level at a scale.
 * Written by Grigory Chirkov, Gleb Balitsky and Nikolay Kozirskiy.
 * Copyright Grigory Chirkov, Gleb Balitsky and Nikolay Kozirskiy, 2016.
 */

#define __SFR_OFFSET 0
#include <avr/io.h>
#define HIGH(x) ( x >> 8)
#define LOW(x) ( x & 0xff)
#define ADC_vect 0x0054

#define TEMP r16
#define LEVEL r18
#define OUT_LEVEL r19
#define TEMP2 r17
#define ADC_RES r20
#define TIMER1 r21
#define TIMER2 r22
#define TIMER3 r23

#define PORTB_MASK 0b00011111
#define PORTD_MASK 0b11111000
#define PRESCALER 0b111
#define MAX_LEVEL 10

#define BUTTON_PIN 2
#define STATE_PIN 5


/* interrupt vectors */
    jmp reset
    jmp button_push
    .org ADC_vect
    jmp ADC_comp
    jmp reset
    jmp reset
    jmp reset
    jmp reset


reset:
    /*
     * Initializing stack pointer
     * with end of RAM
     */
    ldi TEMP, HIGH(RAMEND)
    out SPH, TEMP
    ldi TEMP, LOW(RAMEND)
    out SPL, TEMP

    /*
     * Initializing as output those
     * pins, which are used for
     * showing signal level
     */
    ldi TEMP, PORTB_MASK
    out DDRB, TEMP
    ldi TEMP, PORTD_MASK
    out DDRD, TEMP

    /* Turning on ADC */

    /*
     * ADMUX - ADC multiplexer - register,
     * controlling ADC params.
     * Here we choose left alignment in ADCH and ADCL,
     * because we don't need two lower bits of result.
     * Also, we choose AVcc as a reference voltage.
     */
    ldi TEMP, ((1 << REFS0) | (1 << ADLAR))
    sts ADMUX, TEMP

    /*
     * ADCSRA - ADC control and status reg - register,
     * which controls ADC conversion. Here we enable ADC,
     * choose 128 as a prescaler for it, enable ADC interrupt,
     * configure ADC to start new conversion automatically,
     * and starting the first one. Our input pin is A0
     */
    ldi TEMP, ((1 << ADEN) | (1 << ADATE) | (1 << ADIE) | PRESCALER | (1 << ADSC))
    sts ADCSRA, TEMP

    /* Turning on INT0, where button is connected */

    /*
     * EIMSK - external interrupt mask register -
     * register, where we choose params of external interrupts.
     * Here we enable external interrupts at INT0 pin (PD2)
     */
    ldi TEMP, (1 << INT0)
    out EIMSK, TEMP

    /*
     * EICRA - external interrupts control register A -
     * register, which controls external interrupts.
     * We choose to enter interrupt on a falling edge
     * of triggering signal.
     */
    ldi TEMP, (1 << ISC01)
    sts EICRA, TEMP

    /* Enabling pull-up resistor */
    sbi PORTD, BUTTON_PIN

    /* Enabling our state-control pin (PB5) */
    sbi DDRB, STATE_PIN

    /* Enabling interrupts */
    sei

    /*
     * Main runs in infinite loop, again and again
     * showing out level of signal.
     */
main:
    call load_level
    call show_level
    rjmp main


    /*
     * Load level - takes current A0 level from ADC_RES (max = 255)
     * and converts it to level, which is shown on scale (max = 10),
     * then puts it in LEVEL reg.
     */
load_level:
    mov LEVEL, ADC_RES
    brtc load_level_state_0
    neg LEVEL
load_level_state_0:
    lsr LEVEL
    lsr LEVEL
    lsr LEVEL
    ldi TEMP, MAX_LEVEL/2
    mul LEVEL, TEMP
    mov LEVEL, r0
    lsr LEVEL
    lsr LEVEL
    lsr LEVEL
    lsr LEVEL
    inc LEVEL
    ret



    /*
     * Show level - takes converted level from level reg
     * and puts it out on the scale. Uses help procedure convert, 
     * which does some bit magic.
     */
show_level:
    cpi LEVEL, MAX_LEVEL/2 + 1
    brsh show_level_PD
    in TEMP, PORTD
    andi TEMP, ~PORTD_MASK
    out PORTD, TEMP
    call convert
    lsr OUT_LEVEL
    lsr OUT_LEVEL
    lsr OUT_LEVEL
    in TEMP, PORTB
    andi TEMP, ~PORTB_MASK
    or OUT_LEVEL, TEMP
    out PORTB, OUT_LEVEL
    ret
show_level_PD:
    subi LEVEL, MAX_LEVEL/2
    in TEMP, PORTB
    ori TEMP, PORTB_MASK
    out PORTB, TEMP
    call convert
    in TEMP, PORTD
    andi TEMP, ~PORTD_MASK
    or OUT_LEVEL, TEMP
    out PORTD, OUT_LEVEL
    ret

convert:
    eor OUT_LEVEL, OUT_LEVEL
convert_cycle:
    tst LEVEL
    breq end_convert_cycle
    sec
    ror OUT_LEVEL
    dec LEVEL
    rjmp convert_cycle
end_convert_cycle:
    ret


    /* Interrupts */

    /*
     * ADC_comp - ADC interrupt handler.
     * Writes result to ADC_RES ( excluding two lower bits )
     */
ADC_comp:
    lds ADC_RES, ADCH
    reti


    /*
     * Button push - INT0 interrupt handler.
     * Checks whether button is pushed indeed
     * and then changes layout of level in scale.
     */
button_push:
    call delay
    sbis PIND, BUTTON_PIN
    call change_state
    reti


    /* 
     * Change state - changes state of layout
     * of level in scale.
     */
change_state:
    clr TEMP2
    bld TEMP2, 0
    com TEMP2
    bst TEMP2, 0
    cbi PORTB, STATE_PIN
    brtc change_state_ret
    sbi PORTB, STATE_PIN
change_state_ret:
    ret


    /* 
     * Delay - works as a timer for button push verification.
     */
delay:
    ldi TIMER1, 0xff
    ldi TIMER2, 0xff
    ldi TIMER3, 0x02
delay_cycle:
    nop
    nop
    nop
    nop
    nop
    dec TIMER1
    brne delay_cycle
    dec TIMER2
    brne delay_cycle
    dec TIMER3
    brne delay_cycle
    ret
