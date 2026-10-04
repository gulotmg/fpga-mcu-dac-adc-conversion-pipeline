#include "spi.h"

//macro to cast 8 bit pointer and dereferencing it
#define SPI1_DR_8BIT   (*(volatile uint8_t *)&SPI1->DR)


void gpio_init(void)
{
    // Enable GPIOA clock
    RCC->IOPENR |= RCC_IOPENR_GPIOAEN;

    // Configure Pin Modes:
    // PA6: Output (CS)
    // PA5 (SCK), PA7 (MOSI): Alternate Function

    GPIOA->MODER &= ~(GPIO_MODER_MODE6_Msk | GPIO_MODER_MODE5_Msk | GPIO_MODER_MODE7_Msk);
    GPIOA->MODER |=  (1U << GPIO_MODER_MODE6_Pos) |
                     (2U << GPIO_MODER_MODE5_Pos) |
                     (2U << GPIO_MODER_MODE7_Pos);

    // PA5, PA7 Alternate Function AF0 (SPI1)
    GPIOA->AFR[0] &= ~((0xFU << (5 * 4)) | (0xFU << (7 * 4)));

    // Set CS high initially (inactive)
    cs_disable();
}

void spi1_config(void)
{
    // Enable SPI1 peripheral clock
    RCC->APBENR2 |= RCC_APBENR2_SPI1EN;

    // CR1: Simplex Transmit-Only (BIDIMODE=1, BIDIOE=1) on MOSI
    // Master mode, Software NSS (SSM=1, SSI=1), CPOL=1, CPHA=1, Baud = f_PCLK/4 (BR=001)


    SPI1->CR1 = SPI_CR1_BIDIMODE | SPI_CR1_BIDIOE | (0x05UL << SPI_CR1_BR_Pos)|
                SPI_CR1_MSTR     | SPI_CR1_SSM    | SPI_CR1_SSI |
                SPI_CR1_CPOL     | SPI_CR1_CPHA;

    // CR2: 8-bit Data Size (DS = 0111b -> 7)
    SPI1->CR2 = (7U << SPI_CR2_DS_Pos);

    // Enable SPI1 peripheral
    SPI1->CR1 |= SPI_CR1_SPE;
}

void spi1_transmitter(volatile uint8_t *data, uint32_t size)
{
    for (uint32_t i = 0; i < size; i++) {
        // Wait until TX FIFO has room / TXE is set
        while (!(SPI1->SR & SPI_SR_TXE)) {}

        // Write 8-bit data into DR (directly shifted out on MOSI)

        //forcing 8 bit transmission
        SPI1_DR_8BIT= data[i];
    }

    // Wait until the last byte has physically left the wire: TXE=1 and BSY=0
    while (!(SPI1->SR & SPI_SR_TXE)) {}
    while (SPI1->SR & SPI_SR_BSY) {}
}

void cs_enable(void)
{
	GPIOA -> ODR &= ~(1U<<6);
}

//active low of course


void cs_disable(void)
{
	GPIOA -> ODR |= (1U<<6);
}

