DEVICE = atmega328p

CLOCK = 8000000

AVRDUDE = /Applications/Arduino.app/Contents/Java/hardware/tools/avr/bin/avrdude -C/Applications/Arduino.app/Contents/Java/hardware/tools/avr/etc/avrdude.conf -v -patmega328p -carduino -P/dev/cu.usbmodem1411 -b115200 -D 

OBJECTS = main.o # asm.o

COMPILE = avr-gcc -std=c99 -Wall -O2 -DF_CPU=$(CLOCK) -mmcu=$(DEVICE)
LINK = avr-ld

all: main.hex

.c.o:
		$(COMPILE) -c $< -o $@

.S.o:
		$(COMPILE) -c $< -o $@

.c.s:
		$(COMPILE) -S $< -o $@

flash: all
		$(AVRDUDE) -U flash:w:main.hex:i

clean:
		rm -f main.hex main.elf $(OBJECTS)

main.elf: $(OBJECTS)
		$(LINK) -o main.elf $(OBJECTS)

main.hex: main.elf
		rm -f main.hex
		avr-objcopy -j .text -j .data -O ihex main.elf main.hex
		avr-size --format=avr --mcu=$(DEVICE) main.elf
