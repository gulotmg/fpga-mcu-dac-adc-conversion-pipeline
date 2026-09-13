library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.env.all;

entity tb_DAC is
end entity tb_DAC;

architecture tb of tb_DAC is

    signal CLK      : std_logic := '0';
    signal RESET    : std_logic := '1';
    signal SELECT1  : std_logic := '0';
    signal SELECT2  : std_logic := '0';
    signal DAC_DIN  : std_logic;
    signal DAC_CLK  : std_logic;
    signal DAC_SYNC : std_logic;
    signal INT_PIN  : std_logic;

    constant TB_PERIOD            : time := 10 ns;
    constant EXPECTED_INT_PERIOD : time := 2 us;
    constant INT_TOLERANCE       : time := TB_PERIOD;
    constant SAMPLE_INTERVAL     : time := 1 ms;

begin

    dut : entity work.DAC(myDACarch)
    port map (
        CLK      => CLK,
        RESET    => RESET,
        SELECT1  => SELECT1,
        SELECT2  => SELECT2,
        DAC_DIN  => DAC_DIN,
        DAC_CLK  => DAC_CLK,
        DAC_SYNC => DAC_SYNC,
        INT_PIN  => INT_PIN
    );

    clock_generation : process
    begin
        while true loop
            CLK <= '0';
            wait for TB_PERIOD / 2;

            CLK <= '1';
            wait for TB_PERIOD / 2;
        end loop;
    end process;

    stimuli_test : process

        variable sample_before : std_logic_vector(15 downto 0);
        variable sample_after  : std_logic_vector(15 downto 0);

        variable int_sample_b  : integer range 0 to 65535;
        variable int_sample_a  : integer range 0 to 65535;

        variable t_int_1       : time;
        variable t_int_2       : time;
        variable int_period    : time;

        variable t_sample_1    : time;
        variable t_sample_2    : time;

    begin

        RESET   <= '0';
        SELECT1 <= '0';
        SELECT2 <= '0';

        wait for 10 * TB_PERIOD;

        assert INT_PIN = '0' or INT_PIN = '1'
            report "WARNING: INT_PIN is invalid"
            severity failure;

        wait until rising_edge(INT_PIN);
        t_int_1 := now;

        wait until rising_edge(INT_PIN);
        t_int_2 := now;

        int_period := t_int_2 - t_int_1;

        report "Measured INT_PIN period: "
             & time'image(int_period);

        assert abs(int_period - EXPECTED_INT_PERIOD) <= INT_TOLERANCE
            report "WARNING: Incorrect INT_PIN period. Expected: "
                 & time'image(EXPECTED_INT_PERIOD)
                 & ", measured: "
                 & time'image(int_period)
            severity failure;

        report "### INT_PIN FREQUENCY TEST: OK";

        ----------------------------------------------------------------
        -- Capture the first 16-bit sample
        ----------------------------------------------------------------

        sample_before := (others => '0');

        -- Start time of the first sample
        t_sample_1 := now;

        for i in 0 to 15 loop
            wait until rising_edge(DAC_CLK);
            sample_before := sample_before(14 downto 0) & DAC_DIN;
        end loop;

        ----------------------------------------------------------------
        -- Wait until exactly 1 ms after the start of the first sample
        ----------------------------------------------------------------

        wait for (t_sample_1 + SAMPLE_INTERVAL - now);

        ----------------------------------------------------------------
        -- Capture the second 16-bit sample
        ----------------------------------------------------------------
        ----------------------------------------------------------------

        sample_after := (others => '0');

        -- Start time of the second sample
        t_sample_2 := now;

        for i in 0 to 15 loop
            wait until rising_edge(DAC_CLK);
            sample_after := sample_after(14 downto 0) & DAC_DIN;
        end loop;

        ----------------------------------------------------------------
        -- Verify the time interval between the two samples
        ----------------------------------------------------------------

        assert t_sample_2 - t_sample_1 = SAMPLE_INTERVAL
            report "The two samples are not exactly 1 ms apart. Measured interval: "
                 & time'image(t_sample_2 - t_sample_1)
            severity failure;

        report "The two samples are exactly "
             & time'image(t_sample_2 - t_sample_1)
             & " apart";

        ----------------------------------------------------------------
        -- Convert the samples to integer values
        ----------------------------------------------------------------

        int_sample_b := to_integer(unsigned(sample_before));
        int_sample_a := to_integer(unsigned(sample_after));

        ----------------------------------------------------------------
        -- Compare the sample values
        ----------------------------------------------------------------

        assert int_sample_a = int_sample_b
            report "The DAC sample value changed from "
                 & integer'image(int_sample_b)
                 & " to "
                 & integer'image(int_sample_a)
            severity failure;

        report "The DAC sample value remained constant: "
             & integer'image(int_sample_a);

        report "### sample_out TEST: OK";
        report "### DAC SELF-TEST COMPLETED SUCCESSFULLY ###";

        finish;

    end process;

end architecture tb;
