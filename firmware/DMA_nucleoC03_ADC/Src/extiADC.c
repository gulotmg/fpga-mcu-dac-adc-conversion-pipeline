#include "exti.h"

void extiADC_init(void)
{
    /* Enable GPIOA and SYSCFG clocks */
    RCC->IOPENR  |= RCC_IOPENR_GPIOAEN;
    RCC->APBENR2 |= RCC_APBENR2_SYSCFGEN;

    /* Configure PA11 as digital input with pull-down */
    GPIOA->MODER &= ~(3U << (11 * 2));   /* 00: Digital Input */
    GPIOA->PUPDR &= ~(3U << (11 * 2));
    GPIOA->PUPDR |=  (2U << (11 * 2));   /* 10: Pull-down */

    /* Map EXTI Line 11 to Port A (0x00: Port A in EXTICR3 / index 2) */
    EXTI->EXTICR[2] &= ~(0xFFU << 24);   /* 0x00 = Port A */

    /* Configure rising edge detection on Line 11 */
    EXTI->RTSR1 |= (1U << 11);

    /* Unmask Event and Interrupt generation for INTERNAL routing (not through ISR) */
    EXTI->EMR1  |= (1U << 11);
}
