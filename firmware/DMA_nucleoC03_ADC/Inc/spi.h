#ifndef SPI_H_
#define SPI_H_

#include "stm32c031xx.h"
#include <stdio.h>

void gpio_init(void);
void spi1_config (void);
void spi1_transmitter(volatile uint8_t *data, uint32_t size);
void cs_enable(void);
void cs_disable(void);


#endif /* SPI_H_ */
