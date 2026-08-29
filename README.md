# STM32 + FPGA + DAC7311 — 100 kSPS Acquisition & Analysis Pipeline

Acquisition pipeline built around an STM32 Nucleo-C031C6 and a Spartan-7
SEA/FPGA board. The FPGA design is developed in Vivado as fully custom VHDL
(vendor IP limited to the BRAMs storing the MATLAB-generated `.coe` waveform
tables): it drives a TI DAC7311, used at 8-bit code resolution, to generate
sine, triangle and sawtooth waveforms and provides a 100 kHz trigger that
hardware-triggers the STM32 ADC via EXTI line 11.

The STM32 firmware is written entirely bare-metal at register level (no HAL),
developed in STM32CubeIDE: ADC samples are moved by DMA into a 1000-sample
buffer and, when the buffer is full, a firmware state machine streams it over
UART to a LabVIEW (VISA) host that performs coherent-sampling spectral
analysis (SNR / SFDR / SINAD / THD / ENOB).

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
├── data/                         # raw acquisitions (.COE)
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
git clone https://github.com/gulotmg/fpga-mcu-dac-adc-conversion-pipeline.git
cd fpga-mcu-dac-adc-conversion-pipeline
```

### SSH (recommended if you already have an SSH key configured on GitHub)

```bash
git clone git@github.com/gulotmg/fpga-mcu-dac-adc-conversion-pipeline.git
cd fpga-mcu-dac-adc-conversion-pipeline
```

### GitHub CLI

```bash
gh repo clone gulotmg/fpga-mcu-dac-adc-conversion-pipeline
cd fpga-mcu-dac-adc-conversion-pipeline
```

### Download as ZIP

If you don't want to use Git, you can download the source code as a ZIP archive:

 [Download ZIP](https://github.com/gulotmg/fpga-mcu-dac-adc-conversion-pipeline/archive/refs/heads/main.zip)

 Repository link: https://github.com/gulotmg/fpga-mcu-dac-adc-conversion-pipeline

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

### Coherent sampling

The spectral analysis relies on **coherent sampling**: the record length $N$
is chosen so that each acquisition contains an **integer number of periods**
(exactly 10) of the generated sine wave. This makes the rectangular window
exact and completely eliminates spectral leakage.

$$N = 10 \cdot \frac{f_s}{f_{sig}} \qquad \text{with} \quad f_s = 100 \ \mathrm{kSPS}$$

Sweeping $N$ over the available record lengths yields the following test
frequencies (10 periods per record in every case):

| $N$ (samples) | $f_{sig}$ (kHz) | Periods in record |
|---|---|---|
| 125  | 8 | 10 |
| 250  | 4 | 10 |
| 500  | 2 | 10 |
| 1000 | 1 | 10 |

For each acquisition, up to **15 harmonics** are extracted, when possible
(i.e., while they fall below the Nyquist frequency $f_s/2$).

### Performance metrics

$$\mathrm{SNR} = 20 \log_{10}\\left(\frac{V_{fund}}{V_{noise,\mathrm{rms}}}\right) \quad [\mathrm{dB}]$$

$$\mathrm{SFDR} = 20 \log_{10}\\left(\frac{V_{fund}}{V_{spur,\mathrm{max}}}\right) \quad [\mathrm{dB}]$$

$$\mathrm{SINAD} = 20 \log_{10}\\left(\frac{V_{fund}}{\sqrt{\sum_{h=2}^{15} V_{h}^{2} + V_{noise,\mathrm{rms}}^{2}}}\right) \quad [\mathrm{dB}]$$

$$\mathrm{THD} = 20 \log_{10}\\left(\frac{\sqrt{\sum_{h=2}^{15} V_{h}^{2}}}{V_{fund}}\right) \quad [\mathrm{dB}]$$

$$\mathrm{ENOB} = \frac{\mathrm{SINAD} - 1.76}{6.02} \quad [\mathrm{bit}]$$

where:

- $V_{fund}$ : RMS amplitude of the fundamental at $f_{sig}$;
- $V_{noise,\mathrm{rms}}$ : RMS noise floor, excluding the fundamental and the extracted harmonics;
- $V_{spur,\mathrm{max}}$ : RMS amplitude of the largest spurious component;
- $V_{h}$ : RMS amplitude of the $h$-th harmonic, $h = 2 \dots 15$.

All metrics refer to the **complete chain**: DAC7311 + interconnect + STM32 ADC.

## Results (sine wave, system-level)

| $N$ | $f_{sig}$ (kHz) | SNR (dB) | SFDR (dB) | SINAD (dB) | THD (dB) | ENOB (bit) |
|---|---|---|---|---|---|---|
| 125  | 8 | 40.94 | 30.21 | 38.51 | −42.19 | 6.10 |
| 250  | 4 | 45.81 | 32.27 | 43.73 | −44.93 | 6.97 |
| 500  | 2 | 50.73 | 32.88 | 45.19 | −46.61 | 7.21 |
| 1000 | 1 | 54.37 | 33.85 | 46.98 | −47.85 | 7.51 |

<img width="1547" height="840" alt="Results_8_bit_1000hz_DAC" src="https://github.com/user-attachments/assets/d6c85194-d09e-46d8-bf90-08033b55ffaf" />

*Image of "Front Panel" for one instance (for demonstration and brevity)*

## Known limitations and interpretation of results

- **8-bit DAC Resolution and ADC Bottleneck**: The DAC was intentionally restricted to 8-bit resolution in an attempt to characterize its specific baseline performance. Increasing the DAC's code resolution would hypothetically reduce its quantization noise, potentially shifting the system's bottleneck to the Nucleo's 12-bit SAR ADC, which specifies an ENOB of up to 10.2 bits under specific datasheet conditions. However, this assumes that the DAC's Total Harmonic Distortion (THD) and non-linearities remain below the ADC's noise floor. Therefore, it would be ideal to develop a separate testbench to evaluate the independent performance of each component, thus validating the assumptions regarding the former statement and the ones that follow.

- **Frequency-Dependent Performance and Phase Increment**: Under these conditions, the DAC is highly likely to be the primary bottleneck for the system's overall performance. As signal degradation becomes more pronounced at higher frequencies, the primary limiting factor in this specific implementation is plausibly the "Phase Increment" logic defined in the VHDL entity.

- **System-Level vs. Component-Level Characterization**: Without a suitable "golden reference", the individual contributions of the ADC and DAC cannot be independently isolated. Therefore, this experiment is closer to characterizing the cascade performance of the entire signal chain rather than the independent performance of each component. Nevertheless, it can provide an indicative estimate of the DAC's performance at 8-bit resolution.
  
- **Missing Reconstruction Filter**: No low-pass reconstruction filter is placed between the DAC and the ADC. Consequently, the ADC directly samples the DAC's high-frequency spectral components, which may alias into the baseband and lower the overall measured system ENOB.

  
## References

- RM0490 : STM32C0x1/C0x3 reference manual (ADC, DMA, EXTI, USART)
- UM2953 : NUCLEO-C031C6 / NUCLEO-C051C8 user manual
- STM32C031 datasheet
- TI DAC7311 datasheet
- ARM Cortex-M0+ user guide
- Spartan 7 datasheet
- Spartan Edge Accelerator (SEA) user and experimental manuals and schematics

## License

MIT
