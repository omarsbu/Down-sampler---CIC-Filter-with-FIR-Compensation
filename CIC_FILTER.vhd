----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
-- Name: CIC Integrator
--
-- Description: Output accumulates input data through summation with previous 
--  input data. Uses signed 2's compliment "roll-over" arithmetic logic.
--
-- Inputs:
--    clk : system clock
--    i_reset : Active-high Synchronous reset
--    i_data : Input data sequence
--
-- Outputs:
--    o_data : Output data sequence
--
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE IEEE.NUMERIC_STD.ALL;

entity CIC_INTEGRATOR is
	port (
		clk : in std_logic;
		i_reset : in std_logic; 		
		i_reg_width :  integer range 0 to 111;
		i_data : in signed(111 downto 0);
		o_data : out signed(111 downto 0)
	);
end CIC_INTEGRATOR;

architecture RTL of CIC_INTEGRATOR is
	signal border : integer range 0 to 111;
	signal in_reg, out_reg : signed(111 downto 0);
begin        
	process(clk)
	begin
		if rising_edge(clk) then
		  if i_reset = '1' then		      
		      in_reg <= (others => '0');
		      out_reg <= (others => '0');
		  else		  	  	  
		      in_reg(i_reg_width - 1 downto 0) <= i_data(i_reg_width - 1 downto 0);
		      out_reg(i_reg_width - 1 downto 0) <= in_reg(i_reg_width - 1 downto 0) + out_reg(i_reg_width - 1 downto 0);
		  end if;
	   end if;
	end process;
				
	o_data <= out_reg;
end RTL;

----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
-- Name: CIC Comb
--
-- Description: Output combs the input through subtraction. The input is an 
--  accumulated summation from the integrator and the subtraction operation is
--  performed every R clock cycles to calculate the total change over the
--  interval being averaged. Since the subtraction operation is performed 
--  every R clock cycles, the comb also works as a downsampler
--
-- Inputs:
--    clk : system clock
--    i_reset : Active-high Synchronous reset
--    i_data : Input data sequence
--
-- Outputs:
--    o_data : Output data sequence
--
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE IEEE.NUMERIC_STD.ALL;

entity CIC_COMB is
	port (
		clk : in std_logic;
		i_sample_clk : std_logic;
		i_reset : in std_logic; 
		i_reg_width : integer range 0 to 111;
		i_data : in signed(111 downto 0);
		o_data : out signed(111 downto 0)
	);
end CIC_COMB;

architecture RTL of CIC_COMB is
	signal border : integer range 0 to 111;
	signal in_reg, delay_reg, o_reg : signed(111 downto 0);
    signal reset_flag : std_logic;
begin
	process(clk)
	begin
		if rising_edge(clk) then
		  if i_reset = '1' then
		      reset_flag <= '1';
		  else
		      reset_flag <= '0';
		  end if;
	   end if;
	end process;
	
	process (reset_flag, i_sample_clk)
	begin
	   if reset_flag = '1' then
           delay_reg <= (others => '0');
	       in_reg <= (others => '0');
	       o_reg <= (others => '0');	
	   elsif rising_edge(i_sample_clk) then
		   in_reg(i_reg_width - 1 downto 0) <= i_data(i_reg_width - 1 downto 0);
          delay_reg(i_reg_width - 1 downto 0) <= in_reg(i_reg_width - 1 downto 0);
           o_reg(i_reg_width - 1 downto 0) <= in_reg(i_reg_width - 1 downto 0) - delay_reg(i_reg_width - 1 downto 0);
	   end if;
	end process;
	
	o_data <= o_reg;
end RTL;

----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
-- Name: CIC Filter
--
-- Description: A CIC decimation filter, the output signal is the input signal
--  decimated by a factor of R. The filter performs anti-aliasing by averaging
--  over an interval of R sample. The stopband attenuation is determined by the
--  number of integrator-comb stages N. A compensation FIR can be used to flatten  
--  the passband of the CIC filter. 
--
-- Inputs:
--    clk : system clock
--    i_reset : Active-high Synchronous reset
--    i_data : Input data sequence
--
-- Outputs:
--    o_data : Output data sequence
--
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE IEEE.MATH_REAL.ALL;
USE WORK.ALL;

entity CIC_FILTER is
	generic (data_WIDTH : positive := 8; N : positive := 3);	
	port (
		clk : in std_logic;
		i_sample_clk : std_logic;
		i_reset : in std_logic; 
		log_2_R : std_logic_vector(4 downto 0);
		i_data : in std_logic_vector(data_WIDTH - 1 downto 0);
		o_data : out std_logic_vector(data_WIDTH - 1 downto 0)
	);
end CIC_FILTER;

architecture STRUCTURAL of CIC_FILTER is
    -- Compute the register widths and division factor of the CIC filter 
    signal in_reg, out_reg : signed(data_WIDTH - 1 downto 0);                     
    signal shift_value : integer range 0 to 32*integer(N);
    signal reg_width : integer range 0 to 111;
    
    type pipeline is array (0 to N) of signed(111 downto 0);
    signal integrator_pipeline : pipeline; 
    signal comb_pipeline : pipeline;
begin
    
    shift_value <= integer(N)*to_integer(unsigned(log_2_R));
    reg_width <= integer(data_WIDTH) + shift_value;
    
    process(clk)
    begin
        if rising_edge(clk) then
            in_reg <= signed(i_data);
            integrator_pipeline(0) <= resize(in_reg, 112);      
            comb_pipeline(0) <= integrator_pipeline(N);                                                       
          out_reg <= resize(shift_right(signed(comb_pipeline(N)(reg_width - 1 downto 0)), shift_value), data_WIDTH);
        end if;
    end process;

    o_data <= std_logic_vector(resize(signed(out_reg), data_WIDTH));--(data_WIDTH - 1 downto 0));
    
    INTEGRATOR_STAGE: for i in 0 to N-1 generate
        INTEGRATOR: entity CIC_INTEGRATOR
        port map(
 		  clk => clk,
		  i_reset => i_reset,
		  i_reg_width => reg_width, 
		  i_data => integrator_pipeline(i),
		  o_data => integrator_pipeline(i+1)
        );
    end generate;
   
    COMB_STAGE: for i in 0 to N-1 generate
        COMB: entity CIC_COMB
        port map(
 		  clk => clk,
		  i_reset => i_reset, 
          i_reg_width => reg_width,
          i_sample_clk => i_sample_clk,
		  i_data => comb_pipeline(i),
		  o_data => comb_pipeline(i+1)      
        );
    end generate;
end STRUCTURAL;
