# STM32 + FPGA + DAC7311 — 100 kSPS Acquisition & Analysis Pipeline

Acquisition pipeline built around an STM32 Nucleo-C031C6 and a Spartan-7
SEA/FPGA board. The FPGA design is developed in Vivado as fully custom VHDL
(vendor IP limited to the BRAMs storing the MATLAB-generated .coe waveform
tables): it drives a TI DAC7311, used at 8-bit code resolution, to generate
sine, triangle and sawtooth waveforms and provides a 100 kHz trigger that
hardware-triggers the STM32 ADC via EXTI line 11.

The STM32 firmware is written entirely bare-metal at register level (no HAL), developed in STM32CubeIDE: 
ADC samples are moved by DMA into a 1000-sample buffer and, when the buffer is full, a 
firmware state machine streams it over UART to a LabVIEW (VISA) host that performs
coherent-sampling spectral analysis (SNR / SFDR / SINAD / THD / ENOB).

## System overview

```
SEA/FPGA ──> DAC7311 ──> analog output ──> STM32 ADC input (ADC_INx)
SEA/FPGA ──> 100 kHz trigger ───────────> PA11 / EXTI11 (ADC hw trigger)
STM32: ADC @ 100 kSPS → DMA → 1000-sample buffer → FSM → UART TX
PC: LabVIEW VISA receiver → time/frequency-domain analysis
```

FSM: `IDLE → SAMPLING → TRANSMIT → DONE`

## Features

- FPGA DDS drives the DAC7311 at 8-bit code resolution: sine / triangle / sawtooth;
- 100 kHz external trigger, EXTI line 11 routed as ADC hardware trigger;
- 12-bit ADC sampling at 100 kSPS, DMA-filled buffer (1000 samples);
- UART transmission of the full buffer after acquisition (no DMA needed);
- LabVIEW VISA host: coherent-sampling analysis, harmonic extraction, metric computation;
- Firmware written entirely bare-metal (no HAL): register-level programming using
  only the official reference manuals and the CMSIS libraries;
- FPGA design developed entirely in Vivado for the Xilinx Spartan-7 (SEA board):
  vendor IP blocks used only for the BRAMs; everything else is fully custom,
  synthesizable VHDL, carried through synthesis and implementation down to a
  working bitstream;
- Raw captures committed in `data/` for reproducibility.

## Repository structure

```
├── README.md
├── docs/                         # manuals, references, datasheets
├── firmware/                     # bare-metal STM32C0 (ADC, DMA, EXTI, UART, FSM)
├── VHDL/                         # SEA board: DDS + 100 kHz trigger
├── labview/                      # VISA receiver + analysis VI
├── data/                         # raw acquisitions (CSV)
```

## Requirements (reproducibility)

**Hardware**

- STM32 Nucleo-C031C6;
- Seeed Studio SEA accelerator board (Xilinx Spartan-7) with DAC7311;
- USB cables, jumper wires, common ground between the two boards;
- Oscilloscope;

**Software**

- STM32CubeIDE (developed and tested with v1.19.0);
- Xilinx Vivado ≥ 2019.1 (Spartan-7 toolchain);
- MATLAB or equivalent, to generate the `.coe` waveform files for the BRAMs;
- LabVIEW ≥ 2021 SP1;
- Reference documentation (placed in the appropriate folder of this repo):
  RM0490, UM2953, STM32C031 datasheet, TI DAC7311 datasheet, ARM Cortex-M0+ user guide.

## How to clone this repository

### HTTPS (no SSH key required)

```bash
git clone https://github.com/gulotmg/fpga-mcu-dac-adc-conversion-pipeline-.git
cd fpga-mcu-dac-adc-conversion-pipeline-
```

### SSH (recommended if you already have an SSH key configured on GitHub)

```bash
git clone git@github.com:gulotmg/fpga-mcu-dac-adc-conversion-pipeline-.git
cd fpga-mcu-dac-adc-conversion-pipeline-
```

### GitHub CLI

```bash
gh repo clone gulotmg/fpga-mcu-dac-adc-conversion-pipeline-
cd fpga-mcu-dac-adc-conversion-pipeline-
```

### Download as ZIP

If you don't want to use Git, you can download the source code as a ZIP archive:

👉 [Download ZIP](https://github.com/gulotmg/fpga-mcu-dac-adc-conversion-pipeline-/archive/refs/heads/main.zip)

### Repository link

🔗 https://github.com/gulotmg/fpga-mcu-dac-adc-conversion-pipeline-

### After cloning

1. Refer to the **Requirements** section above to install the required toolchains
   (STM32CubeIDE, Vivado, LabVIEW, MATLAB).
2. Open `firmware/` in STM32CubeIDE to build and flash the STM32 firmware.
3. Open `VHDL/` in Vivado to synthesize, implement and program the bitstream on
   the SEA board.
4. Open `labview/` in LabVIEW to run the host receiver and analysis VI.
5. See the **Hardware setup** section below for the exact wiring between the two boards.

## Hardware setup

| Signal | MCU pin | Connector (UM2953) | Firmware configuration | Note |
|---|---|---|---|---|
| DAC7311 analog output | PA1 — ADC_IN1, CH1 | Arduino A1 / morpho 12 | Analog mode; sampling time 12.5 ADC cycles | Waveform under test |
| 100 kHz trigger (FPGA) | PA11 — EXTI line 11 | Arduino A4 / morpho 33 | Digital input, pull-down, rising edge; routed as ADC hardware trigger (EXTSEL = 111, EXTEN = 01) | SEA board output |
| UART TX → PC | PA2 — USART2_TX | morpho 13 (VCP, SB27 ON) | AF1, 115200 8N1, BRR computed @ 12 MHz PCLK | One-way link (RX unused) |
| GND | common | — | — | Shared between SEA board and Nucleo |

Note: PA11 is used only as the digital trigger (EXTI11); the analog
acquisition channel is PA1 / CH1.

<img width="2500" height="1800" alt="bench_setup" src="https://github.com/user-attachments/assets/7d9d5d16-b238-4372-9cce-a08e3662744b" />

<img width="1397" height="745" alt="oscilloscope_im" src="https://github.com/user-attachments/assets/6236c916-e7bf-4264-8c2c-e9353ee7b843" />

Test bench: Nucleo-C031C6 (left), SEA/FPGA board (right), DAC7311 output probed on CH2; common ground via breadboard. The scope displays the DAC-generated sine wave at 1 kHz acquired by the pipeline.

## How to run

1. Flash the firmware and power the Nucleo.
2. Power the SEA board, program the FPGA bitstream following the instructions
   in `VHDL/`, and connect the boards according to the pinout described above.
3. Open the LabVIEW VI, select the COM port and the baud rate, and run the VI.
4. Press the Nucleo reset button: the board acquires 1000 samples and transmits
   the buffer; LabVIEW plots and analyzes it.

## Measurement methodology

- Coherent sampling: `N = 10 · fs / f_sig` (integer number of periods →
  rectangular window, no leakage), `fs = 100 kSPS`.
- `N ∈ {125, 250, 500, 1000}` → `f_sig ∈ {8, 4, 2, 1 kHz}`; 15 harmonics
  extracted, when possible.
- Metrics: `SNR = 20log(Vfund/Vnoise_rms)`, `SFDR = 20log(Vfund/Vspur_max_rms)`,
  `SINAD = 20log(Vfund/√(ΣVh² + Vnoise²))`, `THD = 20log(√(ΣVh²)/Vfund)`,
  `ENOB = (SINAD − 1.76)/6.02`.
- All metrics refer to the **complete chain**: DAC7311 + interconnect + STM32 ADC.

## Results (sine wave, system-level)

| N | f_sig | SNR (dB) | SFDR (dB) | SINAD (dB) | THD (dB) | ENOB (bit) |
|---|---|---|---|---|---|---|
| 125 | 8 kHz | 40.94 | 30.21 | 38.51 | −42.19 | 6.10 |
| 250 | 4 kHz | 45.81 | 32.27 | 43.73 | −44.93 | 6.97 |
| 500 | 2 kHz | 50.73 | 32.88 | 45.19 | −46.61 | 7.21 |
| 1000 | 1 kHz | 54.37 | 33.85 | 46.98 | −47.85 | 7.51 |

<img width="1547" height="840" alt="Results_8_bit_1000hz_DAC" src="https://github.com/user-attachments/assets/d6c85194-d09e-46d8-bf90-08033b55ffaf" />

Image of "Front Panel" for one instance (for demonstration and brevity)

## Known limitations and interpretation of results

- The "DAC-limited" statement is valid only in the low-frequency regime;
  at 8 kHz the limit is very likely a timing error (trigger jitter).
- No reconstruction low-pass filter between DAC and ADC.
- Single-buffer acquisition after reset; continuous streaming is not
  implemented; not a real limitation, as it is easily implementable and
  simply not needed for this use case.
- Truly characterizing either the DAC or the ADC alone would require a strong
  reference provided by high-quality instrumentation. For this reason, this is
  not a characterization of the single DAC or ADC components, but rather a
  characterization of the performance of the whole pipeline, since it is not
  easy to tell which element is responsible for the observed degradation.

## References

- RM0490 — STM32C0x1/C0x3 reference manual (ADC, DMA, EXTI, USART)
- UM2953 — NUCLEO-C031C6 / NUCLEO-C051C8 user manual
- STM32C031 datasheet
- TI DAC7311 datasheet
- ARM Cortex-M0+ user guide
- Spartan 7 datasheet
- Spartan Edge Accelerator (SEA) user and experimental manuals and schematics

## License

MIT
