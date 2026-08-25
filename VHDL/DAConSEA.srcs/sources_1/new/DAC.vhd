--------------------------------------------------------------------------------
-- Project: DAC7311 Direct Digital Synthesis (DDS) Waveform Generator
-- Description: 
--   Generates periodic waveforms using Block RAM lookup tables (ROM)
--   and transmits samples via a 3-wire serial interface to a DAC7311.
--   - Interrupt generation: 100 kHz signal generated and output by an FPGA_GPIO pin
--   - Frequency control: Managed by the address step / delay prescaler.
--   - Waveform select: Cycles through Sine, Triangle, and Sawtooth.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity DAC is
    Port ( 
        CLK              : in  STD_LOGIC; -- Global system clock (100 MHz)
        RESET            : in  STD_LOGIC; -- Active-low system reset
        SELECT1, SELECT2 : in  STD_LOGIC; -- Active-low pushbuttons (Frequency / Waveform)
        DAC_DIN          : out STD_LOGIC; -- Serial data out to DAC
        DAC_CLK          : out STD_LOGIC; -- Serial clock to DAC
        DAC_SYNC         : out STD_LOGIC;  -- Active-low frame synchronization
        INT_PIN          : out STD_LOGIC  -- FPGA_GPIO pin to generate interrupt for ADC
    );
end DAC;

architecture myDACarch of DAC is

    -- Waveform ROM components (8-bit address, 8-bit amplitude)
    component ROM_Sin 
        port (
            clka  : in  STD_LOGIC;
            ena   : in  STD_LOGIC;
            addra : in  STD_LOGIC_VECTOR(7 downto 0);
            douta : out STD_LOGIC_VECTOR(7 downto 0)
        );
    end component; 

    component ROM_saw
        port (
            clka  : in  STD_LOGIC;
            ena   : in  STD_LOGIC;
            addra : in  STD_LOGIC_VECTOR(7 downto 0);
            douta : out STD_LOGIC_VECTOR(7 downto 0)
        );
    end component;

    component ROM_trig
        port (
            clka  : in  STD_LOGIC;
            ena   : in  STD_LOGIC;
            addra : in  STD_LOGIC_VECTOR(7 downto 0);
            douta : out STD_LOGIC_VECTOR(7 downto 0)
        );
    end component;
 
    -- transmission signals
    signal data_output      : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
    signal DAC_clk_mask     : STD_LOGIC_VECTOR(1 downto 0)  := "01";
    signal DAC_data_counter : integer range 0 to 15         := 0;

    -- Lookup table data and phase accumulator
    signal sin_data, trig_data, saw_data : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal selected_data                 : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal addr_reg                      : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal addr_mask                     : STD_LOGIC_VECTOR(7 downto 0) := "00000001";

    -- Debounce counters and prescalers
    signal select1_counter, select2_counter, reset_counter : integer range 0 to 2097151 := 0; 
    signal wave_mode                                       : STD_LOGIC_VECTOR(1 downto 0) := "00";
    signal buffer_t9: integer range 0 to 511:=0;
    signal int_counter: integer range 0 to 1023:=0;

    -- Transmitter FSM
    type state_type is (WAIT_FOR_SYNC, DATA_MOVING);
    signal state : state_type := WAIT_FOR_SYNC;

begin

    DAC_CONFIG_and_DATA: process(CLK)
    begin
        if rising_edge(CLK) then
            -- Generate 50 MHz DAC serial clock using a shift ring
            DAC_CLK <= DAC_clk_mask(0);
            DAC_clk_mask(1 downto 0) <= DAC_clk_mask(0) & DAC_clk_mask(1);
            
            -- Debounced Reset handling (~20 ms threshold)
            if (RESET = '0') then 
                if (reset_counter < 2097151) then
                    reset_counter <= reset_counter + 1;
                end if;
            else
                if (reset_counter > 1999999) then 
                    DAC_SYNC         <= '1';
                    DAC_data_counter <= 0;
                    DAC_CLK          <= '0';
                    DAC_clk_mask     <= "01";
                    DAC_DIN          <= '0';
                    data_output      <= (others => '0');
                    reset_counter    <= 0;
                    select1_counter  <= 0;
                    select2_counter  <= 0;
                    state            <= WAIT_FOR_SYNC;
                    addr_reg         <= (others => '0');
                    addr_mask        <= "00000001";
                end if;
            end if;
            
            -- SELECT1: Frequency tuning prescaler
            if (SELECT1 = '0') then
                if (select1_counter < 2097151) then
                    select1_counter <= select1_counter + 1;
                end if;
            else
                select1_counter <= 0;
                if (select1_counter > 1999999) then 
                   if (addr_mask(7 downto 0) = "00000000") then
                        --debouncing
                        addr_mask        <= "00000001"; --wrap around the mask
                   else     
                        addr_mask(7 downto 0) <= addr_mask(6 downto 0) & '0';
                   end if;   
                else 
                    null;  
                end if;
            end if;
            
            -- SELECT2: Waveform mode selection
            if (SELECT2 = '0') then 
                if (select2_counter < 2097151) then
                    select2_counter <= select2_counter + 1;
                end if;
            else
                select2_counter <= 0;
                if (select2_counter > 1999999) then
                    --debouncing
                    wave_mode <= wave_mode + "01";
                end if;
            end if;
                    
            -- Waveform multiplexer
            case (wave_mode) is 
                when "00" => 
                    selected_data <= sin_data;   
                when "01" => 
                    selected_data <= trig_data;
                when "11" => 
                    selected_data <= saw_data;
                when others => 
                    selected_data <= sin_data;
            end case;       
            
            
            
            --Interrupt generator
            if (INT_counter < 999) then
                INT_counter <= INT_counter + 1;
                if (INT_counter = 100) then 
                    INT_PIN <= '0'; --just to see it in oscilloscope and make sure it's read by mcu
                end if;
            else
                INT_PIN <= '1'; 
                INT_counter <= 0;
            end if;
           
            
            
            -- Transmission State Machine
            case (state) is 
                when WAIT_FOR_SYNC => 
                if (buffer_t9 < 358) then 
                    buffer_t9 <= buffer_t9 + 1;
                else
                    DAC_SYNC <= '0';
                    state    <= DATA_MOVING;
                    -- Pack 8-bit sample into 16-bit DAC frame (format: [PD1:PD0][D11:D0][X:X])
                    data_output(15 downto 0) <= "00" & selected_data & "000000";
                end if;
                
                when DATA_MOVING =>
                    buffer_t9 <= 0;
                    -- Update serial data line on clock high (meets setup/hold on falling edge)
                    if (DAC_clk_mask(0) = '1') then
                        DAC_DIN <= data_output(15);
                    else  
                        -- Shift register and bit indexing on clock low
                        if (DAC_data_counter < 15) then    
                            data_output(15 downto 0) <= data_output(14 downto 0) & '0';
                            DAC_data_counter         <= DAC_data_counter + 1;
                        else
                            DAC_DIN          <= data_output(15);
                            DAC_data_counter <= 0;
                            state            <= WAIT_FOR_SYNC;
                            DAC_SYNC         <= '1'; 
                            
                            -- Phase accumulator update at the end of each frame
                             addr_reg  <= addr_reg + addr_mask;
                            -- at the end of every value in the ROM the "step" at which data is taken from the ROM
                            -- is increased accordingly to the "addr_mask". This implies losing resolution in time
                            -- but not in amplitude; yet, it allows for an increase in frequency.
                        end if;  
                    end if;
            end case;
                
        end if;
    end process;
     
    -- Block RAM Look-Up Table Instantiations
    SIN_ROM: ROM_Sin
    port map (
        clka  => CLK,
        ena   => '1',
        addra => addr_reg,
        douta => sin_data
    );

    TRIG_ROM: ROM_trig
    port map (
        clka  => CLK,
        ena   => '1',
        addra => addr_reg,
        douta => trig_data
    );

    SAW_ROM: ROM_saw
    port map (
        clka  => CLK,
        ena   => '1',
        addra => addr_reg,
        douta => saw_data
    );

end myDACarch;