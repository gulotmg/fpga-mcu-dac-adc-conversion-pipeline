#include "adc.h"
#include "DMA.h"
#include "uart.h"
#include "exti.h"
#include "spi.h"
#include <stdint.h>
#include <stdio.h>


typedef enum {
    INIT_STATE,
    SAMPLING_STATE,
    UART_STATE,
    HALT_STATE
} state_t;

uint16_t adc_buffer[5001];
uint8_t volatile rx_counter = 0;
volatile uint8_t phase_inc[4];
volatile uint8_t  new_frequency_cmd_ready = 0;

volatile state_t current_state = INIT_STATE;

void SystemClock_Config_48MHz(void){

    // Configure Flash Latency to 1 Wait State
    // This MUST be done before increasing the clock frequency to prevent CPU crashes.
    FLASH->ACR |= FLASH_ACR_LATENCY_1;

    // Verify that the new latency setting has been correctly applied
    while ((FLASH->ACR & FLASH_ACR_LATENCY) != FLASH_ACR_LATENCY_1)
    {
        // Wait until the flash controller acknowledges the new wait state
    }

    // Modify the HSI48 clock division factor in RCC_CR
    // This changes SYSCLK from 12 MHz to 48 MHz.
    RCC->CR &= ~RCC_CR_HSIDIV;

}

int main(void) {

    SystemClock_Config_48MHz();

    // The state machine runs indefinitely.
    while (1) {

        switch (current_state) {

            case INIT_STATE:
                // Initialize USART2 at 115200 Baud with RX interrupt enabled
                uart_init();

                extiADC_init();

                gpio_init();
                spi1_config();
                // Initialize PA1 as ADC (calibration, regulator, trigger config)
                init_pa1_adc();

                // Initialize DMA1 Channel 1
                DMA_init();

                // Arm the ADC to listen for hardware triggers.
                // This MUST be done after DMA is fully configured and enabled.


                /* making sure PA11 is low before arming ADC */
                while (!(GPIOA->IDR & (1U << 11)));
                while (GPIOA->IDR & (1U << 11));

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
                // Transmit the acquired buffer via UART using printf for LabVIEW ASCII compatibility


                for (uint32_t volatile counter = 1; counter <= 5000; counter++) {
                    printf("%d\n", adc_buffer[counter]);
                }

                // Transition to HALT state to prevent infinite re-printing
                current_state = HALT_STATE;
                break;

            case HALT_STATE:
                // If a new frequency command arrived from PC via RX interrupt, re-arm the acquisition
                if (new_frequency_cmd_ready) {

                	//sending data through SPI to fpga
                    cs_enable();
                    spi1_transmitter(phase_inc, 4);
                    cs_disable();

                    for (volatile int d = 0; d < 8000; d++);

                    /* Re-arming DMA and ADC for the next coherent sampling run at new frequency */
                    DMA_rearm();
                    while (!(GPIOA->IDR & (1U << 11)));
                    while (GPIOA->IDR & (1U << 11));
                    ADC1->CR |= ADC_CR_ADSTART;

                    /* switching state and clearing condition */
                    new_frequency_cmd_ready = 0;
                    current_state = SAMPLING_STATE;

                } else {
                    /* Sleep and wait for next interrupt (e.g. UART RX new frequency command or reset) */
                    __WFI();
                }
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

        //emptying and stopping ADC
        ADC1->CR |= ADC_CR_ADSTP;
        while (ADC1->CR & ADC_CR_ADSTP);
        (void)ADC1->DR;
        ADC1->ISR |= ADC_ISR_EOC | ADC_ISR_EOS | ADC_ISR_OVR;

        // Transition the state machine to the UART transmission phase
        current_state = UART_STATE;
    }
}

// USART2 Interrupt Handler
void USART2_IRQHandler(void) {

    /* Check if Read data register not empty flag (RXNE) and its interrupt enable are set;
	   note that at each interrupt all the code that follows restarts*/

    if ((USART2->ISR & USART_ISR_RXNE_RXFNE) && (USART2->CR1 & USART_CR1_RXNEIE_RXFNEIE)) {

    	uint8_t rx_byte = (uint8_t)(USART2 -> RDR & 0xFF);

    	phase_inc[rx_counter] = rx_byte;

    	rx_counter++;

    	if ((rx_counter == 4)) {

    	    rx_counter = 0; 			//resetting to default values
    		rx_byte = 0;
    		new_frequency_cmd_ready = 1;
    		current_state = HALT_STATE; //moving FSM to halt state so that it sends data to fpga

    	}
    }
}
