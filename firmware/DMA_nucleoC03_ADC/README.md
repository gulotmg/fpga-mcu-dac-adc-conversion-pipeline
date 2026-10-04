# firmware/ : Bare-metal STM32C031C6 Acquisition and Automation Firmware

Register-level firmware (no HAL, CMSIS device macros only) that acquires
5000 ADC samples at 500 kSPS, hardware-triggered by the FPGA via EXTI line
11, moves them to RAM by DMA, and streams the buffer as ASCII over USART2
to the LabVIEW host. 

The firmware acts as a communication bridge for automated frequency sweeps:
it receives a 4-byte 32-bit phase tuning word from the PC via USART2 RX interrupt,
transmits it to the Spartan-7 FPGA over SPI1, re-arms the DMA channel, and
restarts sampling without requiring manual board resets.

CPU involvement during active sampling is zero: the whole acquisition chain
(EXTI -> ADC -> DMA) runs in hardware; the core sleeps in `__WFI()` until
the DMA Transfer-Complete interrupt fires.

## Modules

| File | Role |
|---|---|
| `main.c` | FSM (`INIT/SAMPLING/UART/HALT`), `DMA1_Channel1_IRQHandler`, `USART2_IRQHandler` |
| `adc.c` | ADC1 / PA1 config: calibration, trigger, sampling time |
| `DMA.c` | DMA1 channel 1, DMAMUX routing, `DMA_rearm()` for automated multi-run sweeps |
| `spi.c` / `spi.h` | SPI1 Master simplex transmit (PA5 SCK, PA7 MOSI, PA6 CS) to FPGA |
| `extiADC.c` | PA11 / EXTI11 rising-edge config + event routing |
| `uart.c` / `uart.h` | USART2 TX/RX init, BRR computation, RXNE interrupt, `__io_putchar` retarget |
| `syscalls.c` / `sysmem.c` | newlib stubs (printf support) |
| `Startup/` + `STM32C031C6TX_FLASH.ld` | vector table, linker script |
| `chip_headers/CMSIS` | ST/ARM device & core headers (Apache-2.0, included for self-contained builds) |

## Acquisition flow

1. `INIT`: uart -> exti -> gpio/spi -> adc -> dma -> `ADSTART`; enter `SAMPLING`.
2. `SAMPLING`: `__WFI()`. Every EXTI11 rising edge: ADC converts, DMA writes
   one sample. CPU stays asleep.
3. After 5001 transfers (sample 0 dummy, 1 to 5000 valid): DMA TC IRQ -> clear `TCIF1` via `IFCR`
   (write-1-to-clear), disable the DMA channel (freeze buffer), stop ADC (`ADSTP`), -> `UART`.
4. `UART`: stream 5000 samples via `printf("%d\n", adc_buffer[counter])` (ASCII decimal, one per line) -> `HALT`.
5. `HALT`:
   - If a 4-byte frequency command is received from the host via USART2 RX interrupt (`USART2_IRQHandler`):
     asserts CS (PA6 low), transmits `phase_inc[4]` over SPI1 to the FPGA, deasserts CS (PA6 high).
     Calls `DMA_rearm()` (reloads CNDTR = 5001, clears ADC status, re-enables DMA channel 1).
     Waits for PA11 synchronization, re-arms ADC (`ADSTART`), clears flag, and returns to `SAMPLING`.
   - If no command is pending: enters `__WFI()` waiting for the next host command or reset.

## Timing summary

| Parameter | Value |
|---|---|
| System / peripheral clock | 48 MHz |
| ADC clock (synchronous) | 24 MHz |
| Conversion time | 12.5 (sampling) + 12.5 (12-bit) = 25 cycles |
| Trigger frequency | (500 kHz)|
| Buffer fill time | 5000 x (1/500 kHz) = 10 ms |
| Host baud rate | 115200 baud |

## Build & flash

1. STM32CubeIDE (tested v1.19.0): *File -> Import -> Existing Projects* -> `firmware/`.
2. Build; flash via on-board ST-LINK/V2-1.
3. UART appears as the ST-LINK Virtual COM Port: 115200 8N1.

## Design notes 

- Synchronous ADC clock mode was chosen to remove async-clock jitter on the
  external trigger path.
- Single-buffer design with automated re-arming: `DMA_rearm()` enables back-to-back acquisitions driven by host commands over UART/SPI, while reset still re-arms the whole chain.
- Buffer size 5001 elements: index 0 acts as dummy sample to eliminate initial conversion settling artifacts.
