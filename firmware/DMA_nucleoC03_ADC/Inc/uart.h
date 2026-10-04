#ifndef UART_H_
#define UART_H_


#include "stm32c031xx.h"
#include <stdint.h>

void uart_init(void);
void uart_start_tx_it(void);
void uart_stop_tx_it(void);


#endif /* UART_H_ */
