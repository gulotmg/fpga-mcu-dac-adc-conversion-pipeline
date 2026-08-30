#include "DMA.h"
#include <stdint.h>

extern uint16_t adc_buffer[5000];

void DMA_init(void) {

    //  Enable DMA1 peripheral clock in the RCC AHBENR register (RM0490 Section 5.4.10)
    RCC->AHBENR |= RCC_AHBENR_DMA1EN;

    //  Ensure the DMA channel is disabled before modifying its configuration registers
    DMA1_Channel1->CCR &= ~DMA_CCR_EN;

    //  Configure Peripheral Address (Source)
    // The source is the ADC1 Data Register
    DMA1_Channel1->CPAR = (uint32_t)&ADC1->DR;

    //  Configure Memory Address (Destination)
    // The destination is the starting address of the RAM buffer array.
    DMA1_Channel1->CMAR = (uint32_t)adc_buffer;

    /* Configure DMAMUX to connect ADC1 request to DMA1_Channel1 (in DMAMUX 0 corresponds to 1 and so on).
     * Avoiding to do so implies that the DMArequests of the ADC never get to the DMAc... which implies silence
     * from the whole system, even if everything else is well configured.
     */

    DMAMUX1_Channel0 -> CCR = (0x05U << 0);

    // Configure the Number of Data to Transfer (NDT)
    // Set to 5000 transfers. The DMA will treat this counter automatically.
    DMA1_Channel1->CNDTR = 5000U;

    //  Clear the entire Channel Configuration Register (CCR) for a clean state
    DMA1_Channel1->CCR = 0U;

    //  Configure Channel Control Register (CCR) Bitfields

    // Set Priority Level to High (PL = 01).
    DMA1_Channel1->CCR |= DMA_CCR_PL_0;

    // Set Memory Data Size to 16-bit (Half-word) -> MSIZE = 01
    DMA1_Channel1->CCR |= DMA_CCR_MSIZE_0;

    // Set Peripheral Data Size to 16-bit (Half-word) -> PSIZE = 01
    DMA1_Channel1->CCR |= DMA_CCR_PSIZE_0;

    // Enable Memory Increment Mode (MINC = 1)
    // This ensures the DMA writes to adc_buffer[0], then adc_buffer[1], etc.
    DMA1_Channel1->CCR |= DMA_CCR_MINC;

    // Peripheral Increment Mode (PINC) remains 0 (Disabled).
    // This is because we always read from the exact same hardware address (&ADC1->DR).

    // Direction (DIR) remains 0 (Peripheral to Memory).
    // Circular Mode (CIRC) remains 0 (Disabled, one-shot acquisition).
    // Memory-to-Memory (MEM2MEM) remains 0 (Disabled).

    //Enable Transfer Complete Interrupt (TCIE = 1)
    DMA1_Channel1->CCR |= DMA_CCR_TCIE;

    //  Enable the DMA Channel Interrupt in the Nested Vectored Interrupt Controller (NVIC)
    // This must be done before enabling the channel to prevent missed initial interrupts.
    NVIC_EnableIRQ(DMA1_Channel1_IRQn);

    //Finally, enable the DMA channel
    DMA1_Channel1->CCR |= DMA_CCR_EN;
}
