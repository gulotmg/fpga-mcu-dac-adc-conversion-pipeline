#include "uart.h"
#include <stdint.h>


#define TXFNF (1U<<7)

#define PERIPHERAL_CLOCK 	12000000
#define DESIRED_BAUD 	 	115200



static void uart_compute_and_set(uint32_t clock, uint32_t baud){

	// Standard integer division rounding mechanism to prevent baud rate truncation (adding baud/2)
	USART2->BRR = (clock + (baud / 2)) / baud;

}





void uart_init(void){

	//ENABLE CLOCK for GPIOA
	RCC -> IOPENR |= (1U<<0);

	//setting PIN PA2 (alternate function)

	GPIOA -> MODER &= ~(1U<<4);
	GPIOA -> MODER |= (1U<<5);

	//alternate function AF1 for PA2 according to datasheet//

	//AFR[0] is AFRL, AFR[1] is AFRH
	GPIOA -> AFR[0] |= (1U<<8);
	GPIOA -> AFR[0] &= ~(1U<<9);
	GPIOA -> AFR[0] &= ~(1U<<10);
	GPIOA -> AFR[0] &= ~(1U<<11);

	//ENABLE CLOCK for uart2

	RCC -> APBENR1 |= (1U<<17);

	//CONFIG OF USART2//

	//SET OF BAUDRATE

	uart_compute_and_set(PERIPHERAL_CLOCK, DESIRED_BAUD);

	//USART Transmitter enable

	USART2 -> CR1 |= (1U<<3);

	//USART enable module

	USART2 -> CR1 |= (1U<<0);

}


static void uart_write (int sample){

	//check SR to see status of USART2 and send when done

	while (! (USART2 -> ISR & (TXFNF) )) {/*if not full wait until full, else write packet*/}

	//write packet//

	//using a mask (exadecimal 0xFF) to write the byte corresponding to sample using "and"
	USART2 -> TDR = (sample & 0xFF);


}


//using standard C function putchar (this is key or it does not work!)
int __io_putchar(int sample){

	uart_write(sample);

	return sample;
}



