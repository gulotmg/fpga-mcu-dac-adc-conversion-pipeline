################################################################################
# Automatically-generated file. Do not edit!
# Toolchain: GNU Tools for STM32 (13.3.rel1)
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
../Src/DMA.c \
../Src/adc.c \
../Src/extiADC.c \
../Src/main.c \
../Src/syscalls.c \
../Src/sysmem.c \
../Src/uart.c 

OBJS += \
./Src/DMA.o \
./Src/adc.o \
./Src/extiADC.o \
./Src/main.o \
./Src/syscalls.o \
./Src/sysmem.o \
./Src/uart.o 

C_DEPS += \
./Src/DMA.d \
./Src/adc.d \
./Src/extiADC.d \
./Src/main.d \
./Src/syscalls.d \
./Src/sysmem.d \
./Src/uart.d 


# Each subdirectory must supply rules for building sources it contributes
Src/%.o Src/%.su Src/%.cyclo: ../Src/%.c Src/subdir.mk
	arm-none-eabi-gcc "$<" -mcpu=cortex-m0plus -std=gnu11 -g3 -DDEBUG -DNUCLEO_C031C6 -DSTM32 -DSTM32C0 -DSTM32C031C6Tx -c -I../Inc -I"C:/Users/gulot/STM32CubeIDE/workspace_1.19.0/DMA_nucleoC03_ADC/chip_headers/CMSIS/Device/ST/STM32C0xx/Include" -I"C:/Users/gulot/STM32CubeIDE/workspace_1.19.0/DMA_nucleoC03_ADC/chip_headers/CMSIS/Include" -O0 -ffunction-sections -fdata-sections -Wall -fstack-usage -fcyclomatic-complexity -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" --specs=nano.specs -mfloat-abi=soft -mthumb -o "$@"

clean: clean-Src

clean-Src:
	-$(RM) ./Src/DMA.cyclo ./Src/DMA.d ./Src/DMA.o ./Src/DMA.su ./Src/adc.cyclo ./Src/adc.d ./Src/adc.o ./Src/adc.su ./Src/extiADC.cyclo ./Src/extiADC.d ./Src/extiADC.o ./Src/extiADC.su ./Src/main.cyclo ./Src/main.d ./Src/main.o ./Src/main.su ./Src/syscalls.cyclo ./Src/syscalls.d ./Src/syscalls.o ./Src/syscalls.su ./Src/sysmem.cyclo ./Src/sysmem.d ./Src/sysmem.o ./Src/sysmem.su ./Src/uart.cyclo ./Src/uart.d ./Src/uart.o ./Src/uart.su

.PHONY: clean-Src

