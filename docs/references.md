# References & Documentation

External resources consulted during the development of this project.
All documents are referenced by link only; no third-party PDF is
redistributed in this repository.

## FPGA — Seeed Studio Spartan Edge Accelerator (SEA) board

- [Seeed Studio Wiki — Spartan Edge Accelerator Board](https://wiki.seeedstudio.com/Spartan-Edge-Accelerator-Board/)
  Official wiki of the SEA board: hardware overview, XC7S15 (Spartan-7)
  pinout/GPIO map, power options and programming guide.

- [DigiKey — Spartan Edge Accelerator Board resources](https://www.digikey.de/en/product-highlight/s/seeed/spartan-edge-accelerator-board-resources)
  Product highlight aggregating the official resources (documentation,
  schematics, accessories) for the board. Navigate to documentation.

- [GitHub — spartan-edge-esp32-boot](https://github.com/Pillar1989/spartan-edge-esp32-boot)
  Community Arduino library showing how the on-board ESP32 loads the FPGA
  bitstream from an SD card into the XC7S15; used as a reference for the
  SEA board boot/configuration flow.

## MCU — STM32 Nucleo-C031C6

- [STM32C031C6 datasheet (mirror)](https://www.alldatasheet.com/datasheet-pdf/pdf/1570836/STMICROELECTRONICS/STM32C031C6.html)
  Device datasheet: electrical characteristics, pinout and ADC dynamic
  performance (source of the typical ENOB figure used in the bottleneck
  analysis).

- [RM0490 — STM32C0 series Reference Manual](https://www.st.com/resource/en/reference_manual/rm0490-stm32c0-series-advanced-armbased-32bit-mcus-stmicroelectronics.pdf)
  Register-level description of every peripheral used by the firmware:
  RCC, GPIO, EXTI, ADC, DMA/DMAMUX, USART.

- [MB1717-C031C6-B02 schematic pack](https://www.st.com/resource/en/schematic_pack/mb1717-c031c6-b02_schematic.pdf)
  Official Nucleo-C031C6 board schematics; used to verify the pin
  assignments, the VCP solder-bridge configuration (SB27/SB32 ON →
  USART2 on PA2/PA3) and the default jumper settings.

## DAC — TI DAC7311

- [TI DAC7311 datasheet](https://www.ti.com/lit/ds/symlink/dac7311.pdf)
  12-bit voltage-output DAC with 3-wire SPI-compatible serial interface;
  its timing diagram (SYNC / CLK / DATA, 16-bit frame, power-down bits)
  drove the design of the VHDL serial master.

## ARM core

- [ARM Cortex-M0+ Devices Generic User Guide (DUI0662B)](https://support.arm.com/documentation/dui0662/b/)
  Core-level documentation for the Cortex-M0+: programmers model,
  exception/NVIC behavior, power management (`WFI`) and instruction set,
  used for the bare-metal firmware development.