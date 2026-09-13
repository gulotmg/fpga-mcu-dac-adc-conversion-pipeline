
library ieee;
use ieee.std_logic_1164.all;

entity tb_DAC is
end tb_DAC;

architecture tb of tb_DAC is

    component DAC
        port (CLK      : in std_logic;
              RESET    : in std_logic;
              SELECT1  : in std_logic;
              SELECT2  : in std_logic;
              DAC_DIN  : out std_logic;
              DAC_CLK  : out std_logic;
              DAC_SYNC : out std_logic;
              INT_PIN  : out std_logic);
    end component;

    signal CLK      : std_logic;
    signal RESET    : std_logic;
    signal SELECT1  : std_logic;
    signal SELECT2  : std_logic;
    signal DAC_DIN  : std_logic;
    signal DAC_CLK  : std_logic;
    signal DAC_SYNC : std_logic;
    signal INT_PIN  : std_logic;

    constant TbPeriod : time := 10 ns; 
    signal TbClock : std_logic := '0';
    signal TbSimEnded : std_logic := '0';

begin

    dut : DAC
    port map (CLK      => CLK,
              RESET    => RESET,
              SELECT1  => SELECT1,
              SELECT2  => SELECT2,
              DAC_DIN  => DAC_DIN,
              DAC_CLK  => DAC_CLK,
              DAC_SYNC => DAC_SYNC,
              INT_PIN  => INT_PIN);

    -- Clock generation
    TbClock <= not TbClock after TbPeriod/2 ;

    CLK <= TbClock;

    stimuli : process
    begin
        SELECT1 <= '0';
        SELECT2 <= '0';

        RESET <= '1';
        wait for 100 ns;
        RESET <= '0';
        wait for 100 ns;

        wait for 100 * TbPeriod;

        TbSimEnded <= '1';
        wait;
    end process;

end tb;


configuration cfg_tb_DAC of tb_DAC is
    for tb
    end for;
end cfg_tb_DAC;