# firmware/ — Bare-metal STM32C031C6 Acquisition Firmware

Register-level firmware (no HAL, CMSIS device macros only) that acquires
5000 ADC samples at 500 kSPS, hardware-triggered by the FPGA via EXTI line
11, moves them to RAM by DMA, and streams the buffer as ASCII over USART2
to the LabVIEW host. CPU involvement during sampling is zero: the whole
acquisition chain (EXTI → ADC → DMA) runs in hardware; the core sleeps in
`__WFI()` until the DMA Transfer-Complete interrupt fires.

## Modules

| File | Role |
|---|---|
| `main.c` | FSM (`INIT/SAMPLING/UART/HALT`) + `DMA1_Channel1_IRQHandler` |
| `adc.c` | ADC1 / PA1 config: calibration, trigger, sampling time |
| `DMA.c` | DMA1 channel 1 + DMAMUX routing |
| `extiADC.c` | PA11 / EXTI11 rising-edge config + event routing |
| `uart.c` | USART2 TX init, BRR computation, `__io_putchar` retarget |
| `syscalls.c` / `sysmem.c` | newlib stubs (printf support) |
| `Startup/` + `STM32C031C6TX_FLASH.ld` | vector table, linker script |
| `chip_headers/CMSIS` | ST/ARM device & core headers (Apache-2.0, included for self-contained builds) |

## Peripheral configuration

- **ADC1 (`adc.c`)** : PA1 analog, channel 1; synchronous clock `CKMODE=01`
  (PCLK/2, deterministic trigger latency); regulator on + calibration
  (`ADCAL`, ADEN=0); `DMAEN=1/DMACFG=0` (one DMA request per conversion);
  external trigger `EXTSEL=111` (EXTI11), `EXTEN=01` (rising edge), `CONT=0`;
  sampling time 12.5 cycles; enabled and armed (`ADSTART`) **after** DMA.
- **DMA1_CH1 (`DMA.c`)** : source `ADC1->DR`, destination `adc_buffer`,
  `CNDTR=1000`, 16-bit/16-bit, memory-increment, priority high;
  **DMAMUX channel 0 = request 0x05 (ADC1)** — without this routing the ADC
  DMA requests never reach the DMA and the system stays silent; TC interrupt
  enabled in NVIC before channel enable.
- **EXTI (`extiADC.c`)** : PA11 digital input, pull-down; line 11 mapped to
  port A (`EXTICR[2]`); rising edge (`RTSR1`); event unmasked (`EMR1`) for
  hardware routing to the ADC trigger (no EXTI NVIC IRQ used: conversion
  start is fully hardware).
- **USART2 (`uart.c`)** : PA2 AF1, TX only; `BRR = (clk + baud/2)/baud`
  (rounded integer division) @ 48 MHz → 115200; `__io_putchar` retarget so
  `printf` works; TX waits on `TXE_TXFNF`.

## Acquisition flow

1. `INIT`: uart → exti → adc → dma → `ADSTART`; enter `SAMPLING`.
2. `SAMPLING`: `__WFI()`. Every EXTI11 rising edge: ADC converts, DMA writes
   one sample. CPU stays asleep.
3. After 1000 transfers: DMA TC IRQ → clear `TCIF1` via `IFCR`
   (write-1-to-clear), disable the DMA channel (freeze buffer), → `UART`.
4. `UART`: `printf("%d\n")` per sample (ASCII decimal, one per line) → `HALT`.
5. `HALT`: `__WFI()` forever; press reset to re-run.

## Timing summary

| Parameter | Value |
|---|---|
| System / peripheral clock | 48 MHz |
| ADC clock (synchronous) | 24 MHz |
| Conversion time | 12.5 (sampling) + 12.5 (12-bit) = 25 cycles |
| Trigger frequency | (500 kHz)|
| Buffer fill time | 5000 × (1/500 kHz) = 10 ms |

## Build & flash

1. STM32CubeIDE (tested v1.19.0): *File → Import → Existing Projects* → `firmware/`.
2. Build; flash via on-board ST-LINK/V2-1.
3. UART appears as the ST-LINK Virtual COM Port: 115200 8N1.

## Design notes 
- Synchronous ADC clock mode was chosen to remove async-clock jitter on the
  external trigger path.
- Single-buffer, one-shot design by choice: reset re-arms the whole chain.
