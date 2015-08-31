--    {@{@{@{@{@{@
--  {@{@{@{@{@{@{@{@  This code is covered by CoreAmstrad synthesis r004
--  {@    {@{@    {@  A core of Amstrad CPC 6128 running on MiST-board platform
--  {@{@{@{@{@{@{@{@
--  {@  {@{@{@{@  {@  CoreAmstrad is implementation of FPGAmstrad on MiST-board
--  {@{@        {@{@   Contact : renaudhelias@gmail.com
--  {@{@{@{@{@{@{@{@   @see http://code.google.com/p/mist-board/
--    {@{@{@{@{@{@     @see FPGAmstrad at CPCWiki
--
--
--------------------------------------------------------------------------------
-- FPGAmstrad_amstrad_motherboard.simple_GateArray
-- RAM bank select
-- MODE
-- lower/upper ROM enabler
-- see AmstradRAMROM.vhd
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_arith.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity simple_GateArray is
    Port ( CLK:in STD_LOGIC;
				reset:in STD_LOGIC;
			  IO_REQ_W : in STD_LOGIC;
			  A15_A14 : in  STD_LOGIC_VECTOR (1 downto 0);
           D : in  STD_LOGIC_VECTOR (7 downto 0);
           lowerROMen : out  STD_LOGIC:='1';
           upperROMen : out  STD_LOGIC:='1';
           MODE : out  STD_LOGIC_VECTOR (1 downto 0):="00";
			  RAMbank:out STD_LOGIC_VECTOR(2 downto 0):="000";
			  RAMbank512:out STD_LOGIC_VECTOR(2 downto 0):="000"
			  );
end simple_GateArray;

architecture Behavioral of simple_GateArray is
begin
	--http://quasar.cpcscene.com/doku.php?id=iassem:interruptions
	simple_GateArray_process : process(reset,CLK) is
		variable MODE_mem:STD_LOGIC_VECTOR (1 downto 0):=('0','0');
		variable lowerROMen_mem:STD_LOGIC:='1'; -- init fail :='1';
		variable upperROMen_mem:STD_LOGIC:='1'; -- init fail :='1'; -- perhaps ^^
		variable RAMbank_mem:STD_LOGIC_VECTOR(2 downto 0):=(others=>'0');
		variable RAMbank512_mem:STD_LOGIC_VECTOR(2 downto 0):=(others=>'0');
	begin
		
		
		if reset='1' then
			RAMbank<=(others=>'0');
			lowerROMen<='1';
			upperROMen<='1';
			MODE<="00";
		elsif rising_edge(CLK) then
			if IO_REQ_W='1' and A15_A14(1) = '0' and A15_A14(0) = '1' then --7Fxx gate array --
				if D(7) ='0' then
					-- ink -- osef (osef = "on s'en fou" = "we don't care about it")
				else
					--http://www.cpctech.org.uk/docs/garray.html
					if D(6) = '0' then --RMR
						lowerROMen_mem:=not(D(2));
						upperROMen_mem:=not(D(3));
						lowerROMen<=lowerROMen_mem;
						upperROMen<=upperROMen_mem;
						MODE_mem:=D(1 downto 0);
						if MODE_mem="11" then
							MODE_mem:="00";
						end if;
						MODE<=MODE_mem;
					--http://www.cpctech.org.uk/docs/mem.html
					elsif D(6) = '1' then -- MMR
						-- rambank problem pushed into next component : AmstradRAMROM.vhd ;)
						-- cpcwiki doesn't care about : if D(4 downto 2)="001" or D(4 downto 2)="000" then
						RAMbank512_mem:=D(5 downto 3);
						RAMbank512<=RAMbank512_mem;
						RAMbank_mem:=D(2 downto 0);
						RAMbank<=RAMbank_mem;
					end if;
				end if;
			end if;
		end if;	
		
	end process simple_GateArray_process;

end Behavioral;

