#include "adc.h"
#include "DMA.h"
#include "uart.h"
#include "exti.h"
#include <stdint.h>
#include <stdio.h>

typedef enum {
    INIT_STATE,
    SAMPLING_STATE,
    UART_STATE,
    HALT_STATE
} state_t;

uint16_t adc_buffer[1000];
volatile state_t current_state = INIT_STATE;

int main(void) {

    // The state machine runs indefinitely.
    while (1) {

        switch (current_state) {

            case INIT_STATE:
                // Initialize USART2 at 115200 Baud
                uart_init();

                extiADC_init();

                // Initialize PA1 as ADC (calibration, regulator, trigger config)
                init_pa1_adc();

                // Initialize DMA1 Channel 1
                DMA_init();

                // Arm the ADC to listen for hardware triggers.
                // This MUST be done after DMA is fully configured and enabled.
                ADC1->CR |= ADC_CR_ADSTART;

                // Transition to the next state
                current_state = SAMPLING_STATE;
                break; // Prevent fall-through to the next case

            case SAMPLING_STATE:
                // Wait For Interrupt. The CPU core sleeps here to save power.
                // It will wake up when the DMA Transfer Complete interrupt fires.
                __WFI();
                break; // Prevent fall-through

            case UART_STATE:

                // Transmit the acquired buffer via UART
                for (int counter = 0; counter < 1000; counter++) {
                    printf("%d\n", adc_buffer[counter]);
                }


                // Transition to HALT state to prevent infinite re-printing
                current_state = HALT_STATE;
                break;

            case HALT_STATE:
                // System has completed its one-shot task.
                // Sleep forever or wait for a reset button.
                __WFI();
                break;
        }
    }
}

void DMA1_Channel1_IRQHandler(void) {

    // Check if Transfer Complete Interrupt Flag for Channel 1 is set
    if (DMA1->ISR & DMA_ISR_TCIF1) {

        // Clear the TCIF1 flag.
        // CRITICAL: IFCR is a Write-1-to-Clear (W1C) register.

        DMA1->IFCR = DMA_IFCR_CTCIF1;

        // Disable the DMA channel to prevent buffer overwrite
        DMA1_Channel1->CCR &= ~DMA_CCR_EN;

        // Transition the state machine to the UART transmission phase
        current_state = UART_STATE;
    }
}
