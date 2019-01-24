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
-- MIST_*.vhd : MiST-board simple adapter (glue-code)
-- This type of components is only used on my main schematic.
-- see MIST_conf_str.vhd
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


entity MIST_STATUS is
    Port ( status : in  STD_LOGIC_VECTOR (7 downto 0);
	 
           status_0 : out  STD_LOGIC;
			  --megashark_select : out std_logic;
			  --lowerVRAM : out std_logic_vector(1 downto 0);
			  --upperVRAM : out std_logic_vector(1 downto 0);
			  ppi_jumpers : out std_logic_vector(3 downto 0);
			  green_scanlines : out std_logic_vector(1 downto 0);
			  green : out std_logic;
			  crtc_type : out std_logic;
			  ga_shunt: out std_logic;
			  vramORscandb: out std_logic
			  --tv : out std_logic
			  
			 -- leds_select : out  STD_LOGIC_VECTOR (4 downto 0)
			 );
end MIST_STATUS;

architecture Behavioral of MIST_STATUS is

begin
status_0<=status(0);
--leds_select(4 downto 0)<=status(5 downto 1);
--AMSTRAD;DSK;O1,LowerVRAM,1X,0X;O2,LowerVRAM,X0,X1;O3,UpperVRAM,1X,0X;O4,UpperVRAM,1X,0X;O5,Brand name,Schneider,Amstrad;O6,Frequency,50Hz,60Hz;
--lowerVRAM(0)<=status(2);
--lowerVRAM(1)<=not(status(1));
--upperVRAM(0)<=not(status(4));
--upperVRAM(1)<=not(status(3));
--ppi_jumpers<='1' & '1' & status(5) & '1';
--megashark_select<=status(6);
ppi_jumpers<='1' & '1' & status(1) & '1';
crtc_type<=not(status(2));
ga_shunt<=status(3);
vramORscandb<=status(5); -- 1X scandb50Hz
green_scanlines<=status(6) & (not(status(5)) and status(4)); -- 01 scanlines72Hz
green<=status(6);
--megashark_select<=status(7);
--tv<=status(7);
end Behavioral;

