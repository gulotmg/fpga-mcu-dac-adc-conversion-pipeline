#include "uart.h"
#include <stdint.h>


#define TXFNF (1U<<7)

#define PERIPHERAL_CLOCK 	48000000
#define DESIRED_BAUD 	 	115200


static void uart_compute_and_set(uint32_t clock, uint32_t baud){

	// Standard integer division rounding mechanism to prevent baud rate truncation (adding baud/2)
	USART2->BRR = (clock + (baud / 2)) / baud;

}


void uart_init(void){

	//ENABLE CLOCK for GPIOA
	RCC -> IOPENR |= (1U<<0);

	//setting PIN PA2 (alternate function)
	GPIOA -> MODER &= ~(1U<<4); GPIOA -> MODER |= (1U<<5);

	//setting PIN PA3 (alternate function)
	GPIOA -> MODER &= ~(1U<<6); GPIOA -> MODER |= (1U<<7);


	//alternate function AF1 for PA2 (Tx)
	GPIOA -> AFR[0] |= (1U<<8)  ;   GPIOA -> AFR[0] &= ~(1U<<9);
	GPIOA -> AFR[0] &= ~(1U<<10);   GPIOA -> AFR[0] &= ~(1U<<11);

	//alternate function AF1 for PA3 (Rx)
	GPIOA -> AFR[0] |= (1U<<12)  ;   GPIOA -> AFR[0] &= ~(1U<<13);
	GPIOA -> AFR[0] &= ~(1U<<14);   GPIOA -> AFR[0] &= ~(1U<<15);

	//ENABLE CLOCK for uart2
	RCC -> APBENR1 |= (1U<<17);

	/*CONFIG OF USART2*/

	//SET OF BAUDRATE
	uart_compute_and_set(PERIPHERAL_CLOCK, DESIRED_BAUD);

	//enabling Rx interrupts
    USART2->CR1 |= USART_CR1_RXNEIE_RXFNEIE;

	NVIC_EnableIRQ(USART2_IRQn);


	//USART Receiver & Transmitter enabling
	USART2 -> CR1 |= (1U<<2); USART2 -> CR1 |= (1U<<3);

	//USART module enable module
	USART2 -> CR1 |= (1U<<0);



}


//disable transmission interrupt flaG
void uart_stop_tx_it(void)
{
    USART2->CR1 &= ~USART_CR1_TXEIE_TXFNFIE;
}


// Polling write function used by printf/__io_putchar
static void uart_write(uint32_t sample)
{
    // Wait until TX FIFO is not full / TXE is set
    while (!(USART2->ISR & (TXFNF))) {
        // Wait
    }
    // Write packet
    USART2->TDR = (sample & 0xFF);
}



//using standard C function putchar (this is key or it does not work!)
int __io_putchar(uint32_t sample){

	uart_write(sample);
	return sample;

}








