--------------------------------------------------------------------------------
-- Project: DAC7311 Direct Digital Synthesis (DDS) Waveform Generator
-- Description: 
--   Generates periodic waveforms using Block RAM lookup tables (ROM)
--   and transmits samples via a 3-wire serial interface to a DAC7311.
--   - Interrupt generation: 100 kHz signal generated and output by an FPGA_GPIO pin
--   - Frequency control: 32-bit Phase Accumulator DDS.
--   - Waveform select: Cycles through Sine, Triangle, and Sawtooth.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL; 

entity DAC is
    Port ( 
        CLK              : in  STD_LOGIC; -- Global system clock (100 MHz)
        RESET            : in  STD_LOGIC; -- Active-low system reset
        SELECT1, SELECT2 : in  STD_LOGIC; -- Active-low pushbuttons (Frequency / Waveform)
        DAC_DIN          : out STD_LOGIC; -- Serial data out to DAC
        DAC_CLK          : out STD_LOGIC; -- Serial clock to DAC
        DAC_SYNC         : out STD_LOGIC; -- Active-low frame synchronization
        INT_PIN          : out STD_LOGIC  -- FPGA_GPIO pin to generate interrupt for ADC
    );
end DAC;

architecture myDACarch of DAC is

    ----------------------------------------------------------------------------
    -- Hardware & Timing Constants (Macros)
    ----------------------------------------------------------------------------
    -- Debouncer timing 
    constant C_DEBOUNCE_LIMIT    : integer := 2**20;
    constant C_DEBOUNCE_THRESH   : integer := 1_000_000;

    -- Interrupt generator timing (100 kHz rate = 1000 cycles, 1 us pulse = 100 cycles)
    constant C_INT_BUFFER_LIMIT  : integer := 2**10;
    constant C_INT_PERIOD_CYCLES : integer := 1000;
    constant C_INT_PULSE_CYCLES  : integer := 100;

    -- ROM & sample dimensions
    constant C_RAM_WIDTH         : integer := 256; -- 8-bit amplitude (0 to 255)
    constant C_RAM_DEPTH         : integer := 256; -- 256 samples per cycle
    constant C_ADDR_WIDTH        : integer := 8;   -- Address bus width (MSBs of phase accumulator)
    constant C_SAMPLE_WIDTH      : integer := 8;   -- Sample data bit-width

    -- 32-bit DDS Phase Accumulator constants
    constant C_PHASE_ACC_WIDTH   : integer := 32;
    -- Tuning word for exactly 1000.00 Hz (f_clk=100MHz, 42 cycles/sample, 2^32 accumulator)
    constant C_PHASE_INC_1KHZ    : unsigned(C_PHASE_ACC_WIDTH-1 downto 0) := to_unsigned(1803886, C_PHASE_ACC_WIDTH);

    -- Waveform mode selection codes
    constant C_MODE_WIDTH        : integer := 2;
    constant C_MODE_SINE         : unsigned(C_MODE_WIDTH-1 downto 0) := "00";
    constant C_MODE_TRIG         : unsigned(C_MODE_WIDTH-1 downto 0) := "01";
    constant C_MODE_SAW          : unsigned(C_MODE_WIDTH-1 downto 0) := "10";

    -- DAC7311 16-bit frame layout
    constant C_DAC_FRAME_WIDTH   : integer := 16;
    constant C_DAC_PD_BITS       : std_logic_vector(1 downto 0) := "00";             -- Normal operation (PD1=0, PD0=0)
    constant C_DAC_PAD_BITS      : std_logic_vector(5 downto 0) := (others => '0');  -- Sub-LSB padding
    constant C_SYNC_DELAY_LIMIT  : integer := 2**9;
    constant C_SYNC_DELAY_CYCLES : integer := 9;                                    -- Inter-frame quiet period

    ----------------------------------------------------------------------------
    -- Internal Signals
    ----------------------------------------------------------------------------
    -- Serial transmitter signals
    signal data_output      : STD_LOGIC_VECTOR(C_DAC_FRAME_WIDTH-1 downto 0) := (others => '0');
    signal DAC_clk_mask     : STD_LOGIC_VECTOR(1 downto 0)                  := "01";
    signal DAC_data_counter : integer range 0 to C_DAC_FRAME_WIDTH-1         := 0;

    -- 32-bit Phase Accumulator & Phase Increment (Tuning Word)
    signal phase_acc : unsigned(C_PHASE_ACC_WIDTH-1 downto 0) := (others => '0');
    signal phase_inc : unsigned(C_PHASE_ACC_WIDTH-1 downto 0) := C_PHASE_INC_1KHZ;

    -- Debounce counters and prescalers
    signal select1_counter, select2_counter, reset_counter : integer range 0 to C_DEBOUNCE_LIMIT-1 := 0; 
    signal wave_mode                                       : unsigned(C_MODE_WIDTH-1 downto 0)    := C_MODE_SINE;
    signal buffer_t9                                       : integer range 0 to C_SYNC_DELAY_LIMIT-1 := 0;
    signal int_counter                                     : integer range 0 to C_INT_BUFFER_LIMIT-1 := 0;

    -- Transmitter FSM
    type state_type is (WAIT_FOR_SYNC, DATA_MOVING);
    signal state : state_type := WAIT_FOR_SYNC;

    -- ROM definition (256 samples)
    type ram_type is array (0 to C_RAM_DEPTH-1) of integer range 0 to C_RAM_WIDTH-1;       
    
    constant sin_data : ram_type := (
        128, 131, 134, 137, 140, 143, 146, 149, 152, 155, 158, 162, 165, 167, 170, 173, 
        176, 179, 182, 185, 188, 190, 193, 196, 198, 201, 203, 206, 208, 211, 213, 215, 
        218, 220, 222, 224, 226, 228, 230, 232, 234, 235, 237, 238, 240, 241, 243, 244, 
        245, 246, 248, 249, 250, 250, 251, 252, 253, 253, 254, 254, 254, 255, 255, 255, 
        255, 255, 255, 255, 254, 254, 254, 253, 253, 252, 251, 250, 250, 249, 248, 246, 
        245, 244, 243, 241, 240, 238, 237, 235, 234, 232, 230, 228, 226, 224, 222, 220, 
        218, 215, 213, 211, 208, 206, 203, 201, 198, 196, 193, 190, 188, 185, 182, 179, 
        176, 173, 170, 167, 165, 162, 158, 155, 152, 149, 146, 143, 140, 137, 134, 131, 
        128, 124, 121, 118, 115, 112, 109, 106, 103, 100,  97,  93,  90,  88,  85,  82, 
         79,  76,  73,  70,  67,  65,  62,  59,  57,  54,  52,  49,  47,  44,  42,  40, 
         37,  35,  33,  31,  29,  27,  25,  23,  21,  20,  18,  17,  15,  14,  12,  11, 
         10,   9,   7,   6,   5,   5,   4,   3,   2,   2,   1,   1,   1,   0,   0,   0, 
          0,   0,   0,   0,   1,   1,   1,   2,   2,   3,   4,   5,   5,   6,   7,   9, 
         10,  11,  12,  14,  15,  17,  18,  20,  21,  23,  25,  27,  29,  31,  33,  35, 
         37,  40,  42,  44,  47,  49,  52,  54,  57,  59,  62,  65,  67,  70,  73,  76, 
         79,  82,  85,  88,  90,  93,  97, 100, 103, 106, 109, 112, 115, 118, 121, 124
    );
                                    
    constant trig_data : ram_type := (
          0,   2,   4,   6,   8,  10,  12,  14,  16,  18,  20,  22,  24,  26,  28,  30, 
         32,  34,  36,  38,  40,  42,  44,  46,  48,  50,  52,  54,  56,  58,  60,  62, 
         64,  66,  68,  70,  72,  74,  76,  78,  80,  82,  84,  86,  88,  90,  92,  94, 
         96,  98, 100, 102, 104, 106, 108, 110, 112, 114, 116, 118, 120, 122, 124, 126, 
        128, 129, 131, 133, 135, 137, 139, 141, 143, 145, 147, 149, 151, 153, 155, 157, 
        159, 161, 163, 165, 167, 169, 171, 173, 175, 177, 179, 181, 183, 185, 187, 189, 
        191, 193, 195, 197, 199, 201, 203, 205, 207, 209, 211, 213, 215, 217, 219, 221, 
        223, 225, 227, 229, 231, 233, 235, 237, 239, 241, 243, 245, 247, 249, 251, 253, 
        255, 253, 251, 249, 247, 245, 243, 241, 239, 237, 235, 233, 231, 229, 227, 225, 
        223, 221, 219, 217, 215, 213, 211, 209, 207, 205, 203, 201, 199, 197, 195, 193, 
        191, 189, 187, 185, 183, 181, 179, 177, 175, 173, 171, 169, 167, 165, 163, 161, 
        159, 157, 155, 153, 151, 149, 147, 145, 143, 141, 139, 137, 135, 133, 131, 129, 
        128, 126, 124, 122, 120, 118, 116, 114, 112, 110, 108, 106, 104, 102, 100,  98, 
         96,  94,  92,  90,  88,  86,  84,  82,  80,  78,  76,  74,  72,  70,  68,  66, 
         64,  62,  60,  58,  56,  54,  52,  50,  48,  46,  44,  42,  40,  38,  36,  34, 
         32,  30,  28,  26,  24,  22,  20,  18,  16,  14,  12,  10,   8,   6,   4,   2
    );
                                  
    constant saw_data : ram_type := (
          0,   1,   2,   3,   4,   5,   6,   7,   8,   9,  10,  11,  12,  13,  14,  15, 
         16,  17,  18,  19,  20,  21,  22,  23,  24,  25,  26,  27,  28,  29,  30,  31, 
         32,  33,  34,  35,  36,  37,  38,  39,  40,  41,  42,  43,  44,  45,  46,  47, 
         48,  49,  50,  51,  52,  53,  54,  55,  56,  57,  58,  59,  60,  61,  62,  63, 
         64,  65,  66,  67,  68,  69,  70,  71,  72,  73,  74,  75,  76,  77,  78,  79, 
         80,  81,  82,  83,  84,  85,  86,  87,  88,  89,  90,  91,  92,  93,  94,  95, 
         96,  97,  98,  99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 
        112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 
        128, 128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 
        143, 144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 
        159, 160, 161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 
        175, 176, 177, 178, 179, 180, 181, 182, 183, 184, 185, 186, 187, 188, 189, 190, 
        191, 192, 193, 194, 195, 196, 197, 198, 199, 200, 201, 202, 203, 204, 205, 206, 
        207, 208, 209, 210, 211, 212, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222, 
        223, 224, 225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 235, 236, 237, 238, 
        239, 240, 241, 242, 243, 244, 245, 246, 247, 248, 249, 250, 251, 252, 253,   0
    );
     
    -- Current selected sample value
    signal selected_sample : integer range 0 to C_RAM_WIDTH-1 := 0;

begin

    DAC_CONFIG_and_DATA: process(CLK)
    begin
        if rising_edge(CLK) then
            -- Generate 50 MHz DAC serial clock using a shift ring
            DAC_CLK <= DAC_clk_mask(0);
            DAC_clk_mask(1 downto 0) <= DAC_clk_mask(0) & DAC_clk_mask(1);
            
            -- Debounced Reset handling
            if (RESET = '0') then 
                if (reset_counter < C_DEBOUNCE_LIMIT-1) then
                    reset_counter <= reset_counter + 1;
                end if;
            else
                if (reset_counter > C_DEBOUNCE_THRESH) then
                    DAC_SYNC         <= '1';
                    DAC_data_counter <= 0;
                    DAC_CLK          <= '0';
                    DAC_clk_mask     <= "01";
                    DAC_DIN          <= '0';
                    data_output      <= (others => '0');
                    select1_counter  <= 0;
                    select2_counter  <= 0;
                    state            <= WAIT_FOR_SYNC;
                    phase_acc        <= (others => '0');
                    phase_inc        <= C_PHASE_INC_1KHZ;
                    wave_mode        <= C_MODE_SINE;
                end if;
                reset_counter <= 0;
            end if;
            
            -- SELECT1: Frequency tuning (doubles frequency on each press: 1 kHz, 2 kHz, 4 kHz...)
            if (SELECT1 = '0') then
                if (select1_counter < C_DEBOUNCE_LIMIT-1) then
                    select1_counter <= select1_counter + 1;
                end if;
            else
                if (select1_counter > C_DEBOUNCE_THRESH) then
                    -- Left shift doubles frequency; wrap around if bit 24 is set (~32 kHz), performance is very bad after 16 kHz
                    if (phase_inc(24) = '1') then
                        phase_inc <= C_PHASE_INC_1KHZ; -- Reset to 1.000 kHz base
                    else     
                        phase_inc <= phase_inc(C_PHASE_ACC_WIDTH-2 downto 0) & '0'; -- Double step
                    end if;   
                end if;
                select1_counter <= 0;
            end if;
            
            -- SELECT2: Waveform mode selection (debounced on release)
            if (SELECT2 = '0') then 
                if (select2_counter < C_DEBOUNCE_LIMIT-1) then
                    select2_counter <= select2_counter + 1;
                end if;
            else
                if (select2_counter > C_DEBOUNCE_THRESH) then
                    wave_mode <= wave_mode + 1; -- Mode counter increment
                end if;
                select2_counter <= 0;
            end if;
                    
            -- Waveform multiplexer: top 8 bits [31 downto 24] index the 256-sample ROM (integer part)
            case (wave_mode) is 
                when C_MODE_SINE => 
                    selected_sample <= sin_data(to_integer(phase_acc(31 downto 24)));   
                when C_MODE_TRIG => 
                    selected_sample <= trig_data(to_integer(phase_acc(31 downto 24)));
                when C_MODE_SAW => 
                    selected_sample <= saw_data(to_integer(phase_acc(31 downto 24)));
                when others => 
                    selected_sample <= sin_data(to_integer(phase_acc(31 downto 24)));
            end case;       
            
            -- Interrupt generator (100 kHz, 1 us active-low pulse)
            if (int_counter < C_INT_PERIOD_CYCLES-1) then
                int_counter <= int_counter + 1;
                if (int_counter = C_INT_PULSE_CYCLES) then 
                    INT_PIN <= '0';
                end if;
            else
                INT_PIN     <= '1'; 
                int_counter <= 0;
            end if;
           
            -- Transmission State Machine
            case (state) is 
                when WAIT_FOR_SYNC => 
                    if (buffer_t9 < C_SYNC_DELAY_CYCLES) then
                        buffer_t9 <= buffer_t9 + 1;
                    else
                        DAC_SYNC <= '0';
                        state    <= DATA_MOVING;
                        -- Pack 8-bit sample into 16-bit DAC frame
                        data_output <= C_DAC_PD_BITS & std_logic_vector(to_unsigned(selected_sample, C_SAMPLE_WIDTH)) & C_DAC_PAD_BITS;
                    end if;
                
                when DATA_MOVING =>
                    buffer_t9 <= 0;
                    -- Update serial data line on clock high
                    if (DAC_clk_mask(0) = '1') then
                        DAC_DIN <= data_output(C_DAC_FRAME_WIDTH-1);
                    else  
                        -- Shift register and bit indexing on clock low
                        if (DAC_data_counter < C_DAC_FRAME_WIDTH-1) then    
                            data_output      <= data_output(C_DAC_FRAME_WIDTH-2 downto 0) & '0';
                            DAC_data_counter <= DAC_data_counter + 1;
                        else
                            DAC_DIN          <= data_output(C_DAC_FRAME_WIDTH-1);
                            DAC_data_counter <= 0;
                            state            <= WAIT_FOR_SYNC;
                            DAC_SYNC         <= '1'; 
                            
                            -- 32-bit Phase accumulator update at frame completion
                            -- The logic behind this is fairly simple: instead of using 8 bit phase accumulator, we use 32 along with FIXED point arithmetic. 
                            -- This allows to add a phase increment that can be very precisely calculated. Since addressing of the data in the ROM is done
                            -- with the first 8 bits (integer part), if we sum a decimal part we can achieve basically any allowed frequency.
                   
                            phase_acc <= phase_acc + phase_inc;
                        end if;  
                    end if;
            end case;
        end if;
    end process;

end myDACarch;