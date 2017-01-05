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
-- This type of component is only used on my main schematic.
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_arith.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity MIST_SCART is
    Port ( RED_in : in  STD_LOGIC_VECTOR (5 downto 0);
           GREEN_in : in  STD_LOGIC_VECTOR (5 downto 0);
           BLUE_in : in  STD_LOGIC_VECTOR (5 downto 0);
			  HSYNC_in : in STD_logic;
			  VSYNC_in : in STD_logic;
           RED_out : out  STD_LOGIC_VECTOR (5 downto 0);
           GREEN_out : out  STD_LOGIC_VECTOR (5 downto 0);
           BLUE_out : out  STD_LOGIC_VECTOR (5 downto 0);
			  HSYNC_out : out STD_logic;
			  VSYNC_out : out STD_logic;
			  
			  RED_TV_in : in  STD_LOGIC_VECTOR (5 downto 0);
           GREEN_TV_in : in  STD_LOGIC_VECTOR (5 downto 0);
           BLUE_TV_in : in  STD_LOGIC_VECTOR (5 downto 0);
			  HSYNC_TV_in : in STD_logic;
			  VSYNC_TV_in : in STD_logic;
			  
			  mode : in std_logic;
			  rgb_or_g : in std_logic;
  			  pclk_in : in std_logic;
			  pclk_TV_in : in std_logic;
			  pclk_out : out std_logic

			  );
end MIST_SCART;

architecture Behavioral of MIST_SCART is

signal canal_red:STD_LOGIC_VECTOR (5 downto 0);
signal canal_green:STD_LOGIC_VECTOR (5 downto 0);
signal canal_blue:STD_LOGIC_VECTOR (5 downto 0);
signal canal_redTV:STD_LOGIC_VECTOR (5 downto 0);
signal canal_greenTV:STD_LOGIC_VECTOR (5 downto 0);
signal canal_blueTV:STD_LOGIC_VECTOR (5 downto 0);

-- for delta time purpose
signal canal_vsync:std_logic;
signal canal_hsync:std_logic;
--signal canal_clk:std_logic;
signal canal_vsyncTV:std_logic;
signal canal_hsyncTV:std_logic;
--signal canal_clkTV:std_logic;



--public class GreenScreen {
--
--	static final int MAX=2+2+2;
--	static final int MAX_TOP=64; // 6bits => 2^6=64.
--	static final int STEP=11; //MAX_TOP/MAX;
--
--	public static void main(String[] args) {
--		for (int red=0; red<4; red++) {
--			for (int green=0; green<4; green++) {
--				for (int blue=0; blue<4; blue++) {
--					try {
--						int r= value(red);
--						int g= value(green);
--						int b= value(blue);
--						int green_screen = r+g+b;
--						green_screen*=STEP;
--						// System.out.println(green_screen);
--						System.out.println("\""+max2flat(green_screen+MAX_TOP - MAX*STEP - 1)+"\", --"+r+","+g+","+b);
--					} catch (Exception e) {
--						// not mapped value !
--						System.out.println("\"000000\", --X,X,X");
--					}
--				}
--			}
--		}
--	}
--	
--	static int value(int color) throws Exception {
--		if (color==0) return 0;
--		if (color==1) return 1;
--		if (color==3) return 2;
--		throw new Exception("out of range");
--	}
--
--	static String max2flat(int sum) {
--		return fill(Integer.toBinaryString(sum),6);
--	}
--	
--	static String fill(String binary,int c) {
--		String out=binary;
--		while (out.length()<c) {
--			out="0"+out;
--		}
--		return out;
--	}
--}


-- manual calibration :
-- 111111 : 60/((2+2+2)/(2+2+2))=60 111100
-- 110100 : 60/((2+2+2)/(1+2+2))=50 110010
-- 101001 : 60/((2+2+2)/(0+2+2))=40 101000
-- 011110 : 60/((2+2+2)/(0+1+2))=30 011110
-- 010011 : 60/((2+2+2)/(0+0+2))=20 010100
-- 001000 : 60/((2+2+2)/(0+0+1))=10 001010
-- 000000 : 60/((2+2+2)/(0+0+0))=0  000000


type T_GREEN is array (0 to 63) --(63 downto 0)
        of STD_LOGIC_VECTOR(5 downto 0);
  constant GREEN_SCREEN : T_GREEN :=
            ("000000", --"11111111111111111111111111111101", --0,0,0
"001010", --0,0,1
"000000", --X,X,X
"010100", --0,0,2
"001010", --0,1,0
"010100", --0,1,1
"000000", --X,X,X
"011110", --0,1,2
"000000", --X,X,X
"000000", --X,X,X
"000000", --X,X,X
"000000", --X,X,X
"010100", --0,2,0
"011110", --0,2,1
"000000", --X,X,X
"101000", --0,2,2
"001010", --1,0,0
"010100", --1,0,1
"000000", --X,X,X
"011110", --1,0,2
"010100", --1,1,0
"011110", --1,1,1
"000000", --X,X,X
"101000", --1,1,2
"000000", --X,X,X
"000000", --X,X,X
"000000", --X,X,X
"000000", --X,X,X
"011110", --1,2,0
"101000", --1,2,1
"000000", --X,X,X
"110010", --1,2,2
"000000", --X,X,X
"000000", --X,X,X
"000000", --X,X,X
"000000", --X,X,X
"000000", --X,X,X
"000000", --X,X,X
"000000", --X,X,X
"000000", --X,X,X
"000000", --X,X,X
"000000", --X,X,X
"000000", --X,X,X
"000000", --X,X,X
"000000", --X,X,X
"000000", --X,X,X
"000000", --X,X,X
"000000", --X,X,X
"010100", --2,0,0
"011110", --2,0,1
"000000", --X,X,X
"101000", --2,0,2
"011110", --2,1,0
"101000", --2,1,1
"000000", --X,X,X
"110010", --2,1,2
"000000", --X,X,X
"000000", --X,X,X
"000000", --X,X,X
"000000", --X,X,X
"101000", --2,2,0
"110010", --2,2,1
"000000", --X,X,X
"111100" --2,2,2
);

type T_COLOR is array (0 to 3) --(63 downto 0)
        of STD_LOGIC_VECTOR(5 downto 0);
  constant COLOR_SCREEN : T_COLOR :=
            ("000000",
"011110",
"011110",
"111100"
);

begin

RED_out<=canal_red when mode='0' else canal_redTV;
GREEN_out<=canal_green when mode='0' else canal_greenTV;
BLUE_out<=canal_blue when mode='0' else canal_blueTV;

green_color_vga : process(pclk_in) is
begin
		if rising_edge(pclk_in) then
			if rgb_or_g='0' then
				canal_red<= COLOR_SCREEN(conv_integer(RED_in(5 downto 4)));
				canal_green<= COLOR_SCREEN(conv_integer(GREEN_in(5 downto 4)));
				canal_blue<= COLOR_SCREEN(conv_integer(BLUE_in(5 downto 4)));
			else
				canal_red<= "000000";
				canal_green<= GREEN_SCREEN(conv_integer(RED_in(5 downto 4) & GREEN_in(5 downto 4) & BLUE_in(5 downto 4)));
				canal_blue<= "000000";
			end if;
			canal_hsync<=HSYNC_in;
			canal_vsync<=VSYNC_in;
			--canal_clk<=pclk_in;
		end if;
end process green_color_vga;

green_color_tv : process(pclk_TV_in) is
begin
		if rising_edge(pclk_TV_in) and mode='1' then
			if rgb_or_g='0' then
				canal_redTV<= COLOR_SCREEN(conv_integer(RED_TV_in(5 downto 4)));
				canal_greenTV<= COLOR_SCREEN(conv_integer(GREEN_TV_in(5 downto 4)));
				canal_blueTV<= COLOR_SCREEN(conv_integer(BLUE_TV_in(5 downto 4)));
			else
				canal_redTV<= "000000";
				canal_greenTV<= GREEN_SCREEN(conv_integer(RED_TV_in(5 downto 4) & GREEN_TV_in(5 downto 4) & BLUE_TV_in(5 downto 4)));
				canal_blueTV<= "000000";
			end if;
			canal_hsyncTV<=HSYNC_TV_in;
			canal_vsyncTV<=VSYNC_TV_in;
			--canal_clkTV<=pclk_TV_in;
		end if;
end process green_color_tv;

HSYNC_out<=canal_hsync when mode='0' else canal_hsyncTV;
VSYNC_out<=canal_vsync when mode='0' else canal_vsyncTV;
--pclk_out<=canal_clk when mode='0' else canal_clkTV;
--HSYNC_out<=HSYNC_in when mode='0' else HSYNC_TV_in;
--VSYNC_out<=VSYNC_in when mode='0' else VSYNC_TV_in;
pclk_out<=pclk_in when mode='0' else pclk_TV_in;


end Behavioral;

