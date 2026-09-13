#include "adc.h"
#include <stdint.h>

void init_pa1_adc(void)
{

    /* Enable GPIOA and ADC1 peripheral clocks */
    RCC->IOPENR  |= RCC_IOPENR_GPIOAEN;
    RCC->APBENR2 |= RCC_APBENR2_ADCEN;

    /*  Configure PA1 in analog mode (ADC_IN1) */
    GPIOA->MODER |= (3U << (1 * 2));

    /*  Set synchronous ADC clock: PCLK/2 (eliminates jitter on external trigger) */
    ADC1->CFGR2 &= ~ADC_CFGR2_CKMODE;
    ADC1->CFGR2 |= ADC_CFGR2_CKMODE_0;

    /* Enable voltage regulator and wait for stabilization (~20us) */
    ADC1->CR |= ADC_CR_ADVREGEN;
    for (volatile int i = 0; i < 1000; i++) {
    }

    /*  Start ADC self-calibration (must be executed with ADEN = 0) */
    ADC1->CR |= ADC_CR_ADCAL;
    while (ADC1->CR & ADC_CR_ADCAL);

    /*  After calibration phase DMA mode is enabled for ADC in single mode
     *  This implies that ADC shall send DMA requests that will have to be
     *  through DMAMUX (otherwise complete silence would follow) (See DMA.c)
     * */
    ADC1 -> CFGR1 |= (ADC_CFGR1_DMAEN);
    ADC1 -> CFGR1 &= ~(ADC_CFGR1_DMACFG);


    /*  Configure EXTERNAL trigger: EXTSEL = 111 (EXTI11), EXTEN = 01 (Rising Edge), Single mode (CONT = 0) */
    ADC1->CFGR1 &= ~(ADC_CFGR1_CONT | ADC_CFGR1_EXTSEL | ADC_CFGR1_EXTEN);
    ADC1->CFGR1 |= (7U << ADC_CFGR1_EXTSEL_Pos) | (1U << ADC_CFGR1_EXTEN_Pos);

    /*  Configure sampling time: 12.5 ADC clock cycles on SMP1, select SMP1 for CH1 */
    ADC1->SMPR &= ~ADC_SMPR_SMP1;
    ADC1->SMPR |= (3U << ADC_SMPR_SMP1_Pos);
    ADC1->SMPR &= ~ADC_SMPR_SMPSEL1;

    /*  Select Channel 1 (PA1) and wait for CCRDY */
    ADC1->CHSELR |= ADC_CHSELR_CHSEL1;
    while (!(ADC1->ISR & ADC_ISR_CCRDY));
    ADC1->ISR |= ADC_ISR_CCRDY;

    /*  Enable ADC and wait for ADRDY flag */
    ADC1->ISR |= ADC_ISR_ADRDY;
    ADC1->CR  |= ADC_CR_ADEN;
    while (!(ADC1->ISR & ADC_ISR_ADRDY));

    /* Arming ADC to listen for incoming hardware trigger pulses MUST be done after DMA is enabled
     * See main.c
     * */
}
