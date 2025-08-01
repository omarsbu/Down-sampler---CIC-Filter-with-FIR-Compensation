library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity CLK_DIVIDER is
    Port ( clk : in  STD_LOGIC;
           reset : in  STD_LOGIC;
           timebase : in  STD_LOGIC_VECTOR (5 downto 0);
           clk_out : out  STD_LOGIC);
end CLK_DIVIDER;

architecture BEHAVIORAL of CLK_DIVIDER is
    signal counter_reg : unsigned(31 downto 0);
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                counter_reg <= (others => '0');
            else
                counter_reg <= counter_reg + 1;
            end if;
        end if;		
    end process;
    
    with timebase(5) select
    clk_out <= clk when '1',
                std_logic(counter_reg (to_integer(unsigned(timebase)))) when others;            
    
end BEHAVIORAL;
