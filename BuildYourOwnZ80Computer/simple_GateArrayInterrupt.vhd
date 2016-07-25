--    {@{@{@{@{@{@
--  {@{@{@{@{@{@{@{@  This code is covered by CoreAmstrad synthesis r005
--  {@    {@{@    {@  A core of Amstrad CPC 6128 running on MiST-board platform
--  {@{@{@{@{@{@{@{@
--  {@  {@{@{@{@  {@  CoreAmstrad is implementation of FPGAmstrad on MiST-board
--  {@{@        {@{@   Contact : renaudhelias@gmail.com
--  {@{@{@{@{@{@{@{@   @see http://code.google.com/p/mist-board/
--    {@{@{@{@{@{@     @see FPGAmstrad at CPCWiki
--
--
--------------------------------------------------------------------------------
-- FPGAmstrad_amstrad_motherboard.simple_GateArrayInterrupt
-- VRAM/PRAM write
-- CRTC interrupt, IO_ACK
-- WAIT_n
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_arith.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- https://sourceforge.net/p/jemu/code/HEAD/tree/JEMU/src/jemu/system/cpc/GateArray.java

-- Being clear about address/data :
-- 12/13 : maScreen update, upper to 9 isn't used
-- 0 1 2 3 do run setEvents => strange it seems about HORIZONTALS
-- 7 seem making effects if its value is 0 but it seems a source code erratum
-- 3 does call setReg3(value) which rules under hsyncWidth and vsyncWidth
-- 6 does call setReg6() with some border effect on a demo
-- 8 does call setReg8(value) interlace

-- ink 0,2,20
-- speed ink 1,1
entity simple_GateArrayInterrupt is
	Generic (
	--HD6845S 	Hitachi 	0 HD6845S_WriteMaskTable type 0 in JavaCPC
	--UM6845 	UMC 		0
	--UM6845R 	UMC 		1 UM6845R_WriteMaskTable type 1 in JavaCPC <==
	--MC6845 	Motorola	2 
	--CRTC_TYPE:integer   :=0;
	LATENCE_MEM_WR:integer:=1;
	NB_HSYNC_BY_INTERRUPT:integer:=52; --52; -- 52 sure it's 52
	NB_LINEH_BY_VSYNC:integer:=24+1; --4--5-- VSYNC normally 4 HSYNC
	-- feel nice policy : interrupt at end of HSYNC
	--I have HDISP (external port of original Amstrad 6128) so I can determinate true timing and making a fix time generator
	-- 39*8=312   /40=7.8 /52=6 /32=9.75
  VRAM_HDsp:integer:=800/16; -- words of 16bits, that contains more or less pixels... thinking as reference mode 2, some 800x600 mode 2 (mode 2 is one bit <=> one pixel, that's cool)
  VRAM_VDsp:integer:=600/2;
  VRAM_Hoffset:integer:=10 ; -- 63*16-46*16
  
  -- le raster palette arrive au moment oÃ¹ l'encre est en face du stylo.
  -- si on a un dÃ©calage raster palette alors on lis au mauvais moment, donc au mauvais endroit
  -- hors nous on lit via MA, et on Ã©crit n'importe oÃ¹ via VRAM_Voffset
  -- donc VRAM_Voffset n'a pas d'influence sur le raster palette
  -- Ã§a veut dire que l'adresse mÃ©moire dessous la palette n'est pas bonne
  
  
  -- plus je grandi cette valeur plus l'image va vers le haut.
  VRAM_Voffset:integer:=48;  -- no influence under layer PRAM (raster palette colours ink), because PRAM is time dependant. Here influence is just about image position on screen
 -- output pixels
	-- Amstrad
	 -- 
	 --OFFSET:STD_LOGIC_VECTOR(15 downto 0):=x"C000";
	 -- screen.bas
	 -- CLS
	 -- FOR A=&C000 TO &FFFF
	 -- POKE A,&FF
	 -- NEXT A
	 -- 
	 -- line.bas
	 -- CLS
	 -- FOR A=&C000 TO &C050
	 -- POKE A,&FF
	 -- NEXT A
	 -- 
	 -- lines.bas
	 -- CLS
	 -- FOR A=&C000 TO &C7FF
	 -- POKE A,&FF
	 -- NEXT A
	 -- 
	 -- byte pixels structure :
	 -- mode 1 :
	 --   1 byte <=> 4 pixels
	 --   [AAAA][BBBB] : layering colors [AAAA] and [BBBB]
	 --   A+B=0+0=dark blue (default Amstrad background color)
	 --   A+B=0+1=light blue
	 --   A+B=1+0=yellow
	 --   A+B=1+1=red
	 --  for example [1100][0011] with give 2 yellow pixels followed by 2 light blue pixels &C3
	 -- mode 0 : 
	 --   1 byte <=> 2 pixels
	 --   [AA][BB][CC][DD] : layering colors of AA, BB, CC, DD
	 --   Because it results too many equations for a simple RGB output, they do switch the last equation (alternating at a certain low frequency (INK SPEED))
	 -- mode 2 :
	 --   1 byte <=> 8 pixels
	 --   [AAAAAAAA] : so only 2 colors xD
	 MODE_MAX:integer:=2;
--	 NB_PIXEL_PER_OCTET:integer:=4;--2**(MODE+1);
  	NB_PIXEL_PER_OCTET_MAX:integer:=8;
	NB_PIXEL_PER_OCTET_MIN:integer:=2

  
	);
    Port ( nCLK4_1 : in  STD_LOGIC;
           CLK16MHz : in STD_LOGIC;
           IO_REQ_W : in  STD_LOGIC;
			  IO_REQ_R : in  STD_LOGIC;
           A15_A14_A9_A8 : in  STD_LOGIC_VECTOR (3 downto 0);
			  MODE_select:in STD_LOGIC_VECTOR (1 downto 0);
           D : in  STD_LOGIC_VECTOR (7 downto 0);
			  Dout : out  STD_LOGIC_VECTOR (7 downto 0):= (others=>'1');
			  crtc_VSYNC : out STD_LOGIC:='0';
			  IO_ACK : in STD_LOGIC;
			  crtc_A: out STD_LOGIC_VECTOR (15 downto 0):=(others=>'0');
			  bvram_A:out STD_LOGIC_VECTOR (14 downto 0):=(others=>'0');
			  bvram_W:out STD_LOGIC:='0'; 
			  bvram_D:out std_logic_vector(7 downto 0):=(others=>'0'); -- pixel_DATA
			  crtc_R:out STD_LOGIC:='0'; --ram_A external solve CRTC read scan
           int : out  STD_LOGIC:='0'; -- JavaCPC reset init
			  M1_n : in  STD_LOGIC;
			  MEM_WR:in std_logic;
			  
			  -- Z80 4MHz and CRTC 1MHz are produced by GATE_ARRAY normally
			  -- MA0/CCLK is produced by GATE_ARRAY and does feed Yamaha sound chip.
			  -- WAIT<=WAIT_MEM_n and WAIT_n; -- MEM_WR and M1
			  -- please_wait(4MHz,WAIT)=>4MHz is a clock hack as Z80 does not implement correclty the WAIT purpose (Z80 is encapsulating a Z8080 and so corrupt this purpose)
			  WAIT_MEM_n : out  STD_LOGIC:='1';
           WAIT_n : out  STD_LOGIC:='1';
			  -- YM2149 is using rising_edge(CLK)
			  SOUND_CLK : out  STD_LOGIC; -- calibrated with Sim City/Abracadabra et les voleurs du temps/CPCRulez -CIRCLES demo
			  
			  crtc_D : in  STD_LOGIC_VECTOR (7 downto 0);
			  palette_A: out STD_LOGIC_VECTOR (13 downto 0):=(others=>'0');
			  palette_D: out std_logic_vector(7 downto 0);
			  palette_W: out std_logic;
			  reset:in  STD_LOGIC;
			  
			  RED_out : out  STD_LOGIC_VECTOR (5 downto 0);
           GREEN_out : out  STD_LOGIC_VECTOR (5 downto 0);
           BLUE_out : out  STD_LOGIC_VECTOR (5 downto 0);
			  HSYNC_out : out STD_logic;
			  VSYNC_out : out STD_logic
			  );
end simple_GateArrayInterrupt;

architecture Behavioral of simple_GateArrayInterrupt is
	-- init values are for test bench datasheet !
--	signal RHtot:std_logic_vector(7 downto 0):="00010000";
--	signal RHdisp:std_logic_vector(7 downto 0):="00000111";
--	signal RHsyncpos:std_logic_vector(7 downto 0):="00001001";
--	signal RHwidth:std_logic_vector(3 downto 0):="0100";
--	signal RVwidth:std_logic_vector(4 downto 0):="00011";
--	signal RVtot:std_logic_vector(6 downto 0):="0011000";
--	signal RVtotAdjust:std_logic_vector(4 downto 0):="00010";
--	signal RVdisp:std_logic_vector(6 downto 0):="0001111";
--	signal RVsyncpos:std_logic_vector(6 downto 0):="0010011";
--	signal RRmax:std_logic_vector(4 downto 0):="00011";
	
	-- init values are for test bench javacpc !
	signal RHtot:std_logic_vector(7 downto 0):="00111111";
	signal RHdisp:std_logic_vector(7 downto 0):="00101000";
	signal RHsyncpos:std_logic_vector(7 downto 0):="00101110";
	signal RHwidth:std_logic_vector(3 downto 0):="1101";-- minus 1 "1110";
	signal RVwidth:std_logic_vector(3 downto 0):="0100";-- shift 5 "01000";
	signal RVtot:std_logic_vector(7 downto 0):="00100110";
	signal RVtotAdjust:std_logic_vector(7 downto 0):="00000000";
	signal RVdisp:std_logic_vector(7 downto 0):="00011001";
	signal RVsyncpos:std_logic_vector(7 downto 0):="00011110";
	signal RRmax:std_logic_vector(7 downto 0):="00000111";

	constant DO_NOTHING : STD_LOGIC:='0';
	constant DO_HSYNC : STD_LOGIC:='1';
	constant DO_VSYNC : STD_LOGIC:='1';
	
	signal maScreen:STD_LOGIC_VECTOR(13 downto 0):="110000" & "00000000";--(others=>'0');

	signal LineCounter:std_logic:='1';
	signal RED : STD_LOGIC_VECTOR(1 downto 0);
   signal GREEN : STD_LOGIC_VECTOR(1 downto 0);
   signal BLUE : STD_LOGIC_VECTOR(1 downto 0);
	signal vsync:std_logic:=DO_NOTHING;
	signal hsync:std_logic:=DO_NOTHING;
	signal vsync_int:std_logic;
	signal hsync_int:std_logic;
	
	signal CLK4MHz : STD_LOGIC;
	
	signal SOUND_CLK_i : STD_LOGIC;

	signal crtc_DISP : STD_LOGIC;--alternate 2MHz phase scaled   ===//

	
	type palette_type is array(31 downto 0) of std_logic_vector(5 downto 0); -- RRVVBB
	constant palette:palette_type:=(
		20=>"000000",
		 4=>"000001",
		21=>"000011",
		28=>"010000",
		24=>"010001",
			29=>"010011",
		12=>"110000",
			5=>"110001",
		13=>"110011",
		22=>"000100",
		6=>"000101",
		23=>"000111",
		30=>"010100",
		 0=>"010101",
		31=>"010111",
		14=>"110100",
		 7=>"110101",
		15=>"110111",
		18=>"001100",
		 2=>"001101",
		19=>"001111",
		26=>"011100",
		25=>"011101",
		27=>"011111",
		10=>"111100",
		 3=>"111101",
		11=>"111111",
		
		-- others color >=27
		1=>"010101",
		8=>"110001",
		9=>"111101",
		16=>"000001",
		17=>"001101"
		);
	
	
	type pen_type is array(15 downto 0) of integer range 0 to 31;
	signal pen:pen_type:=(4,12,21,28,24,29,12,5,13,22,6,23,30,0,31,14);
	signal border:integer range 0 to 31;
	
	-- action aZRaEL : disp !
	constant DO_NOTHING_OUT : integer range 0 to 2:=0;
	constant DO_READ : integer range 0 to 2:=1;
	constant DO_BORDER: integer range 0 to 2:=2;
	signal etat_rgb : integer range 0 to 2:=DO_NOTHING_OUT;
	signal DATA_action : std_logic:='0'; -- if rising_edge then DATA just is filled.
	signal DATA : std_logic_vector(7 downto 0):=(others=>'0');
	--signal vsync_delay:std_logic:=DO_NOTHING;
	--signal hsync_delay:std_logic:=DO_NOTHING;
	
	-- wtf solver
	signal palette_A_tictac: STD_LOGIC_VECTOR (13 downto 0):=(others=>'0');
	signal palette_D_tictac: std_logic_vector(7 downto 0);
	signal palette_W_tictac: std_logic;
begin

---- without scandoubler
RED_out<= RED & "0000";
GREEN_out<= GREEN & "0000";
BLUE_out<= BLUE & "0000";
HSYNC_out<= HSYNC;
VSYNC_out<= VSYNC;
-- do scan mirror VRAM (underground way (no way)) via CRTC, and then send data to VRAM buffer
--
-- Z80=>RAM         (read/write at 4MHz)
--    =>mirror_VRAM (mirror : just write at 4MHz)
--
--mirror_VRAM<=CRTC (anarchy_clock read at 4MHz)
--
--CRTC=>VRAM_BUFFER+PRAM (pixels written at 50Hz)
--
--VRAM_BUFFER+PRAM=>VGA (read at 60Hz (that's another anarchy_clock))
--
-- anarchy_clock : see FPGAmstrad on CPCWiki about "magic clock" (a special FPGA RAM using two different clock entries at the same time)
-- mirror_VRAM = bvram_A
-- VRAM_BUFFER = crtc_A

--crtc_CLK<=CLK4_1; --VALIDATED
--bvram_CLK<=not(CLK4_1); --VALIDATED
--palette_CLK<=not(CLK4_1); --VALIDATED

	-- synchronize palette_CLK_tictac with bvram_CLK to provocate clock solver aZRaEL_vram2vgaAmstradMiaow (do win a half of clock time)
	stabilizatorVRAMvsPALETTE:process(reset,nCLK4_1) is
		variable palette_A_mem:std_logic_vector(palette_A'range):=(others=>'0');
		variable palette_D_mem:std_logic_vector(7 downto 0):=(others=>'0');
		variable palette_W_mem:std_logic:='0';
	begin
		if reset='1' then
			palette_A<=(others=>'0');
			palette_D<=(others=>'0');
			palette_W<='0';
		elsif falling_edge(nCLK4_1) then
			palette_A_mem:=palette_A_tictac;
			palette_A<=palette_A_mem;
			palette_D_mem:=palette_D_tictac;
			palette_D<=palette_D_mem;
			palette_W_mem:=palette_W_tictac;
			palette_W<=palette_W_mem;
		end if;
	end process;

	bvramWriter:process(reset,nCLK4_1) is -- transmit
		variable D2:STD_LOGIC_VECTOR (7 downto 0):=(others=>'0');
		variable W2:STD_LOGIC :='0';
	begin
		--problem with D2 and reset !
		if reset='1' then
			crtc_R<='0';
			bvram_D<=(others=>'0'); -- do not loose tempo about D2
			bvram_W<='0';
		else
			-- address is solved
			if falling_edge(nCLK4_1) then
				crtc_R<='1'; -- directly solve external ram_A for CRTC read
				if crtc_DISP='1' then
					D2:=crtc_D; --bug bug
					W2:='1';
				else
					D2:=x"00";
					W2:='0';
				end if;
				bvram_D<=D2; -- tempo D2 !!!
				bvram_W<=W2;
			end if;
		end if;
		
	end process;

ctrcConfig_process:process(reset,nCLK4_1) is
	variable reg_select32 : std_logic_vector(7 downto 0);
	variable reg_select : integer range 0 to 17;
	-- normally 0..17 but 0..31 in JavaCPC
	type registres_type is array(0 to 17) of std_logic_vector(7 downto 0);
	variable registres:registres_type := (others=>(others=>'0'));
		
	variable ink:STD_LOGIC_VECTOR(3 downto 0);
	variable border_ink:STD_LOGIC;
	variable ink_color:STD_LOGIC_VECTOR(4 downto 0);
	
	variable pen_mem:pen_type:=(4,12,21,28,24,29,12,5,13,22,6,23,30,0,31,14);
	variable border_mem:integer range 0 to 31;
begin
	if reset='1' then
		Dout<=(others=>'1');
	elsif rising_edge(nCLK4_1) then
		if IO_REQ_W='1' and A15_A14_A9_A8(3) = '0' and A15_A14_A9_A8(2) = '1' then
			if D(7) ='0' then
				-- ink -- osef
				if D(6)='0' then
					border_ink:=D(4);
					ink:=D(3 downto 0);
				else
					ink_color:=D(4 downto 0);
					if border_ink='0' then
						pen_mem(conv_integer(ink)):=conv_integer(ink_color);
						pen<=pen_mem;
					else
						border_mem:=conv_integer(ink_color);
						border<=border_mem;
					end if;
				end if;
			end if;
		end if;
	
		if (IO_REQ_W or IO_REQ_R)='1' then -- EN port (enable)
			--On type 0 and 1, if a Write Only register is read from, "0" is returned. 
	--type 0		
--			b1 	b0 	Function 	Read/Write
--0 	0 	Select internal 6845 register 	Write Only
--0 	1 	Write to selected internal 6845 register 	Write Only
--1 	0 	- 	-
--1 	1 	Read from selected internal 6845 register 	Read only 

	--type 1
--b1 	b0 	Function 	Read/Write
--0 	0 	Select internal 6845 register 	Write Only
--0 	1 	Write to selected internal 6845 register 	Write Only
--1 	0 	Read Status Register 	Read Only
--1 	1 	Read from selected internal 6845 register 	Read only 
			Dout<=(others=>'1'); -- pull up (no command)
			if A15_A14_A9_A8(2)='0' and A15_A14_A9_A8(1)='0' then -- A9_WRITE
				if A15_A14_A9_A8(0)='0' then
					if IO_REQ_W='1' then
						reg_select32:=D and x"1F";
						if reg_select32<=x"11" then -- < 17
							reg_select:=conv_integer(reg_select32);
						end if;
					else
						-- parasite : pull up
						reg_select32:=x"1F";
					end if;
				elsif reg_select32<=x"11" then
					if IO_REQ_W='1' then
						registres(reg_select):=D;
					else
						-- parasite : pull up
						registres(reg_select):=x"FF";
					end if;
					case reg_select is
						when 0=>
							RHtot<=registres(0);
						when 1=>
							RHdisp<=registres(1);
						when 2=>
							RHsyncpos<=registres(2);
						when 3=>
							--hSyncWidth = value & 0x0f;
							--vSyncWidth = (value >> 4) & 0x0f;
							-- following DataSheet and Arnold emulator (Arnold says it exists a conversion table HSYNC crtc.c.GA_HSyncWidth)
							RHwidth<=registres(3)(3 downto 0); -- DataSheet
							--RVwidth<=conv_std_logic_vector(NB_LINEH_BY_VSYNC,5);-- (24+1) using Arnold formula ctrct.c.MONITOR_VSYNC_COUNT "01111"; -- Arkanoid does use width VSYNC while hurting a monster or firing with bonus gun
							RVwidth<=registres(3)(7 downto 4); -- JavaCPC 2015 puis Renaud
						when 4=>
							RVtot<=registres(4) and x"7f";
						when 5=>
							RVtotAdjust<=registres(5) and x"1f";
						when 6=>
							RVdisp<=registres(6) and x"7f";
						when 7=>
							RVsyncpos<=registres(7) and x"7f";
						when 8=>NULL; -- and x"f3"; and x"03" (type 1)
							-- interlace & skew
						when 9=> -- max raster adress
							RRmax<=registres(9) and x"1f";
						when 10=>NULL; -- and x"7f";
							-- cursor start raster 
						when 11=>NULL; -- and x"1f";
							-- cursor end raster
						when 12=> --NULL;  (read/write type 0) (write only type 1)
							-- start adress H
							--maScreen = (reg[13] + (reg[12] << 8)) & 0x3fff;
							-- and x"3f" donc (5 downto 0)
							maScreen<=registres(12)(5 downto 0) & registres(13);
						when 13=> --NULL;  (read/write type 0) (write only type 1)
							-- start adress L
							--maScreen = (reg[13] + (reg[12] << 8)) & 0x3fff;
							maScreen<=registres(12)(5 downto 0) & registres(13);
						when 14=>NULL; -- and x"3f"
							-- cursor H (read/write)
						when 15=>NULL;
							-- cursor L (read/write)
						when 16=>NULL;
							--light pen H (read only)
						when 17=>NULL;
							--light pen L (read only)
					end case;
				end if;
			elsif A15_A14_A9_A8(2)='0' and A15_A14_A9_A8(1)='1' then-- A9_READ
				-- type 0 : status is not implemented
				if A15_A14_A9_A8(0)='0' then
					--if (LineCounter == 0) {
					--  return (1 << 5); x"20"
					if LineCounter='0' then
						Dout<=x"20";
					else
						Dout<=x"00"; 
					end if;
				else
					-- type 0 : nothing (return x"00")
					-- type 1 : read status
					if reg_select32 = x"0A" then -- R10
						Dout<=registres(10); --type1 and x"1f"; -- type 0
					elsif reg_select32 = x"0B" then -- R11
						Dout<=registres(11) and x"1f"; -- type 0 & 1
					elsif reg_select32 = x"0C" then -- R12
						Dout<=x"00"; -- type 1 registres(12) and x"3f"; -- type 0
					elsif reg_select32 = x"0D" then -- R13
						Dout<=x"00"; -- type 1 registres(13); -- type 0
					elsif reg_select32 = x"0E" then -- R14
						Dout<=registres(14); --registres(14) and x"3f";
					elsif reg_select32 = x"0F" then -- R15	
						Dout<=registres(15); --registres(15);
					elsif reg_select32 = x"0F" then -- R16
						Dout<=registres(16) and x"3f";
					elsif reg_select32 = x"0F" then -- R17
						Dout<=registres(17);
					else
						Dout<=x"00";
					end if;
				end if;
			else
				--JavaCPC readPort() not implemented
			
				-- CS (chip select) OFF
				-- no read : pull-up
				Dout<=x"FF";
			end if;
--		elsif IO_ACK='1' then
--			-- IO_ACK DATA_BUS
--			Dout<=(others=>'1'); -- value to check... cpcwiki seem down at the moment I write this sentence :P
		else
			Dout<=(others=>'1');
		end if;
	end if;
end process ctrcConfig_process;


delta_sound_clk : process(nCLK4_1) is
begin
	if falling_edge(nCLK4_1) then
		SOUND_CLK<=SOUND_CLK_i;
	end if;
end process delta_sound_clk;
	
	-- DANGEROUS WARNING : CRTC PART WAS TESTED AND VALIDATED USING TESTBENCH
simple_GateArray_process : process(reset,nCLK4_1) is
 
 variable compteur1MHz : integer range 0 to 3:=0;
	variable disp:std_logic:='0';
	variable dispH:std_logic:='0'; -- horizontal disp (easier to compute BORDER area)
	-- following Quazar legends, 300 times per second
	-- Following a lost trace in Google about www.cepece.info/amstrad/docs/garray.html I have
	-- "In the CPC the Gate Array generates maskable interrupts, to do this it uses the HSYNC and VSYNC signals from CRTC, a 6-bit internal counter and monitors..."
-- perhaps useful also : http://www.cpcwiki.eu/index.php/Synchronising_with_the_CRTC_and_display 
		-- following http://cpcrulez.fr/coding_amslive04-z80.htm
		-- protected int hCCMask = 0x7f; "char_counter256 HMAX n'est pas une valeur en dur, mais un label comme VT et VS..."
		variable horizontal_counter_hCC : std_logic_vector(7 downto 0):=(others=>'0'); --640/16
		variable vertical_counter_vCC : std_logic_vector(6 downto 0):=(others=>'0'); --600
		--variable etat_rgb : STD_LOGIC:=DO_NOTHING;
		variable etat_hsync : STD_LOGIC:=DO_NOTHING;
		variable etat_monitor_hsync : STD_LOGIC_VECTOR(3 downto 0):=(others=>DO_NOTHING);
		variable etat_vsync : STD_LOGIC:=DO_NOTHING;
		variable etat_monitor_vsync : STD_LOGIC_VECTOR(3 downto 0):=(others=>DO_NOTHING);
		--idem ADRESSE_MA_mem variable MA:STD_LOGIC_VECTOR(13 downto 0):=(others=>'0');
		variable RA:STD_LOGIC_VECTOR(4 downto 0):=(others=>'0'); -- buggy boy has value RRmax=5
		variable ADRESSE_maBase_mem:STD_LOGIC_VECTOR(13 downto 0):=(others=>'0');
		variable ADRESSE_MA_mem:STD_LOGIC_VECTOR(13 downto 0):=(others=>'0');
		--variable ADRESSE_hCC_mem:integer range 0 to 16*1024-1;
		variable crtc_A_mem:std_logic_vector(14 downto 0):=(others=>'0'); -- 16bit memory
		variable bvram_A_mem:std_logic_vector(14 downto 0):=(others=>'0'); -- 16bit memory


		variable was_M1_1:boolean:=false;
		variable waiting:boolean:=false;
		variable waiting_MEMWR:integer range 0 to LATENCE_MEM_WR:=LATENCE_MEM_WR;
		variable was_MEMWR_0:boolean:=false;
		
		--(128*1024)/64 2*1024=2^11
		variable zap_scan:boolean:=true; -- if in last round, has no blank signal, do not scan memory !

		variable vram_vertical_offset_counter:integer:=0;
		variable vram_vertical_counter:integer:=0;
		variable vram_horizontal_offset_counter:integer:=0;
		variable vram_horizontal_counter:integer:=0;
		
		variable palette_A_tictac_mem:std_logic_vector(13 downto 0):=(others=>'0');
		variable palette_D_tictac_mem:std_logic_vector(7 downto 0):=(others=>'0');
		variable last_dispH:std_logic:='0';
		variable palette_horizontal_counter:integer range 0 to 256-1:=0; --640/16
		variable palette_color:integer range 0 to 16-1;
		
		--variable in_800x600:boolean:=false;
		--variable last_CENTER:boolean:=false; -- not in left BORDER, in right BORDER if disp=0, in CENTER if disp=1
		
		variable RVtotAdjust_mem:std_logic_vector(7 downto 0):=(others=>'0');
		variable RVtotAdjust_do:boolean:=false;
		
		variable hSyncCount:std_logic_vector(3 downto 0):=(others=>'0');
		variable vSyncCount:std_logic_vector(3 downto 0):=(others=>'0');
		-- 01 : do nothing 2345 : do VSYNC, 6 : end of VSYNC : 7 : nothing.
		--variable monitor_vsync_counter:integer range 0 to 2+4+1;
		
		
		variable DATA_mem:std_logic_vector(7 downto 0);
		
	begin
		if reset='1' then
			hsync_int<=DO_NOTHING;
			vsync_int<=DO_NOTHING;
			crtc_VSYNC<=DO_NOTHING;
			etat_hsync:=DO_NOTHING;
			etat_monitor_hsync:=(others=>DO_NOTHING);
			etat_vsync:=DO_NOTHING;
			--last_etat_vsync:=DO_NOTHING;
			etat_monitor_vsync:=(others=>DO_NOTHING);
	--it's Z80 time !
		elsif rising_edge(nCLK4_1) then
		
		compteur1MHz:=(compteur1MHz+1) mod 4;
		
crtc_DISP<='0';
palette_W_tictac<='0';

-- Crazy Car II doesn't like little_reset
			-- Asphalt IACK without test in int_mem
			-- counter never upper than  52
			-- z80 mode 1 : the byte need no be sent, as the z80 restarts at logical address x38 regardless(z80 datasheet)
			case compteur1MHz is
			when 0=>

				--setEvents() HSync strange behaviour : part 1
				etat_monitor_hsync:=etat_monitor_hsync(2 downto 0) & etat_monitor_hsync(0);

				if horizontal_counter_hCC=RHsyncpos then
					etat_hsync:=DO_HSYNC;
					hSyncCount:= x"0";
					etat_monitor_hsync(0):=DO_HSYNC;
hsync_int<=DO_HSYNC; -- following javacpc,grimware and arnold
				-- if (inHSync) {
				elsif etat_hsync=DO_HSYNC then
					hSyncCount:=hSyncCount+1;
					if	hSyncCount=RHwidth then
						etat_hsync:=DO_NOTHING;
						etat_monitor_hsync:="0000";
hsync_int<=DO_NOTHING;
					elsif hSyncCount=2+4 then
						etat_monitor_hsync:="0000";
					end if;
				end if;
				
				
				--http://www.phenixinformatique.com/modules/newbb/viewtopic.php?topic_id=4316&forum=9
				--In original CRTC DataSheet, it doesn't have any test about VSync period, and also, bits 4 to 7 of R3 are not taken into account. Some factories shall have reused this free bits to put on it its own features, feel more about somes linked to VSync (like interlaced R8, adding difference between a certain model of CRTC and another).
				--PPI read CRTC.isVSYnc bool
				--if (inVSync && (vSyncCount = (vSyncCount + 1) & 0x0f) == vSyncWidth) {
				if horizontal_counter_hCC = 0 then
					etat_monitor_vsync:=etat_monitor_vsync(2 downto 0) & etat_monitor_vsync(0);

					-- checkVSync() : if (vCC == reg[7] && !inVSync) {
					if RA=0 and vertical_counter_vCC=RVsyncpos then
						--Batman logo rotating still like this... but dislike the !inVSync filter (etat_vsync=DO_NOTHING) here...
						-- Batman city towers does like RA=0 filter here...
						-- CRTC datasheet : if 0000 is programmed for VSync, then 16 raster period is generated.
						vSyncCount:= x"1"; -- pulse ?
						etat_vsync:=DO_VSYNC;
						etat_monitor_vsync(0):=DO_VSYNC;
crtc_VSYNC<=DO_VSYNC; -- it is really '1' by here, because we need an interrupt while vsync=1 or else border is to too faster (border 1,2)
vsync_int<=DO_VSYNC; -- do start a counter permitting 2 hsync failing before interrupt
					elsif etat_vsync=DO_VSYNC then
						if vSyncCount=RVwidth then -- following Grim (forum)
							etat_vsync:=DO_NOTHING;
							etat_monitor_vsync:="0000";
	crtc_VSYNC<=DO_NOTHING;
	vsync_int<=DO_NOTHING; -- useless, except to addition several vsync layering them each others
						else
							if vSyncCount=2+4 then
								etat_monitor_vsync:="0000";
							end if;
							vSyncCount:=vSyncCount+1;
						end if;
					end if;
				end if;
				
				
				

				--setEvents() HSync strange behaviour : part 2
				if zap_scan then
					dispH:='0';
				elsif horizontal_counter_hCC = 0 then -- and vertical_counter_vCC<RVDisp*(RRmax+1) then
					dispH:='1';
				elsif horizontal_counter_hCC = RHdisp then
					dispH:='0';
				end if;
				
				if dispH='1' and "0" & vertical_counter_vCC<RVDisp then
					disp:='1';
					etat_rgb<=DO_READ;
					-- http://quasar.cpcscene.com/doku.php?id=assem:crtc
					-- Have to respect address cut ADRESSE_CONSTANT_mem:=conv_integer(maScreen(13 downto 0)) mod (16*1024);
					
					-- newFrame() :  ma = maBase = maScreen;
					
					-- je suis relatif ÃƒÆ’Ã‚Â  RHdisp, alors qu'ÃƒÆ’Ã‚Â  chaque scanStart() RHdisp est relu et += ADRESSE_maBase_mem
					--ADRESSE_hCC_mem:=conv_integer(horizontal_counter_hCC) mod (16*1024);
					
					-- ma = (maBase + hCC) & 0x3fff;
					--MA:=conv_std_logic_vector(ADRESSE_maBase_mem+ADRESSE_hCC_mem,14);
					--RA:=ligne_carac_v_RA;
					crtc_A_mem(14 downto 0):=ADRESSE_MA_mem(13 downto 12) & RA(2 downto 0) & ADRESSE_MA_mem(9 downto 0);
					--http://cpcrulez.fr/coding_amslive02-balayage_video.htm dit :
					--MA(13 downto 12) & RA(2 downto 0) & MA(9 downto 0) & CCLK
				else
					etat_rgb<=DO_NOTHING_OUT;
					disp:='0';
					crtc_A_mem:=(others=>'0');
				end if;
				-- it's not really 16MHz, but we don't care
				crtc_A(15 downto 0)<=crtc_A_mem(14 downto 0) & '0';

--if etat_vsync=DO_VSYNC and last_etat_vsync=DO_NOTHING then
--	monitor_vsync_counter:=0;
--elsif monitor_vsync_counter<2 and etat_vsync=DO_NOTHING then
--	-- bye bye
--elsif monitor_vsync_counter<2+4 and etat_vsync=DO_NOTHING then
--	-- cut
--	monitor_vsync_counter:=2+4; -- failing_edge
--elsif monitor_vsync_counter<2+4 then
--	monitor_vsync_counter:=monitor_vsync_counter+1;
--else 
--	-- sleeping
--	monitor_vsync_counter:=2+4+1;  -- sleeping
--end if;

-- VRAM_HDsp VRAM_VDsp
-- it's just the begin, do relax...
if etat_monitor_vsync(2)=DO_VSYNC and etat_monitor_vsync(3)=DO_NOTHING then
--vsync (gerald confirmed this to me):
--1. vsync to monitor is 2 HSYNC after the start of vsync from crtc. (2 scanlines delay)
--	=> interrupt wait et wait_wait.
--2. vsync to monitor is max 4 lines
--3. vsync to monitor is cut if crtc vsync length is less than 6.
--	=> vSyncCount = 25; 24|0 donc 4*6
--
--	So VSYNC (@raster-line) :
--	* CRTC 1000000 1100000 1110000 1111000 1111100 1111110 1111111
--	* TV   0000000 0000000 0010000 0011000 0011100 0011110 0011110


	vram_vertical_offset_counter:=0;
	vram_vertical_counter:=0;
end if;
if etat_monitor_hsync(2)=DO_HSYNC and etat_monitor_hsync(3)=DO_NOTHING then
	if vram_vertical_offset_counter<=VRAM_Voffset then
		vram_vertical_offset_counter:=vram_vertical_offset_counter+1;
	elsif vram_vertical_counter<VRAM_VDsp then
		vram_vertical_counter:=vram_vertical_counter+1;
	end if;
	
--hsync:
--1. hsync to monitor starts 2 us after the hsync from crtc.
--2. hsync to monitor is max 4us
--3. if hsync programmed into crtc is less than 6, hsync to monitor is shorter. (e.g. if you write 4 into hsync length in crtc, hsync to monitor is 2us long).
--	So HSYNC (@1MHz)
--	* CRTC 1000000 1100000 1110000 1111000 1111100 1111110 1111111
--	* TV   0000000 0000000 0010000 0011000 0011100 0011110 0011110
	
	vram_horizontal_offset_counter:=0;
	vram_horizontal_counter:=0;
	--in_800x600:=false;
	--last_CENTER:=false;
end if;

-- Here we're scanning 800x600 following VSYNC et HSYNC, so we can write some border...
if vram_horizontal_offset_counter>VRAM_Hoffset then
	if vram_horizontal_counter<VRAM_HDsp then
		if vram_vertical_offset_counter>VRAM_Voffset and vram_vertical_counter<VRAM_VDsp then
			--in_800x600:=true;
			
			if vram_horizontal_counter=0 and vram_vertical_counter= 0 then
				palette_A_tictac_mem:=(others=>'0');
			end if;
			
			
			if dispH='1' and disp='0' then
				-- full VERTICAL BORDER
				--last_CENTER:=true;
				-- filling palette (PRAM)
				if last_dispH='0' then
					palette_horizontal_counter:=0;
					last_dispH:='1';
				else
					palette_horizontal_counter:=palette_horizontal_counter+1;
				end if;
				if palette_horizontal_counter<1 then
					palette_A_tictac<=palette_A_tictac_mem(13 downto 0);
					palette_D_tictac_mem:="00" & conv_std_logic_vector(vram_horizontal_counter,6);
					palette_D_tictac<=palette_D_tictac_mem;
					palette_W_tictac<='1';
					palette_A_tictac_mem:=palette_A_tictac_mem+1;
				elsif palette_horizontal_counter<2 then
					palette_A_tictac<=palette_A_tictac_mem(13 downto 0);
					palette_D_tictac_mem:=conv_std_logic_vector(border,5) & "1" & MODE_select;
					palette_D_tictac<=palette_D_tictac_mem;
					palette_W_tictac<='1';
					palette_A_tictac_mem:=palette_A_tictac_mem+1;
				elsif palette_horizontal_counter<2+16 then
					palette_A_tictac<=palette_A_tictac_mem(13 downto 0);
					if palette_horizontal_counter = 2 then
						palette_color:=0;
					else
						palette_color:=palette_color+1;
					end if;
					palette_D_tictac_mem:=conv_std_logic_vector(pen(palette_color),8);
					palette_D_tictac<=palette_D_tictac_mem;
					palette_W_tictac<='1';
					palette_A_tictac_mem:=palette_A_tictac_mem+1;
				elsif palette_horizontal_counter<2+16+1 then
					palette_A_tictac<=palette_A_tictac_mem(13 downto 0);
					palette_D_tictac_mem:=conv_std_logic_vector(vram_horizontal_counter-(2+16),8);
					palette_D_tictac_mem:=palette_D_tictac_mem+RHdisp;
					palette_D_tictac<=palette_D_tictac_mem;
					palette_W_tictac<='1';
					palette_A_tictac_mem:=palette_A_tictac_mem+1;
				else
					palette_A_tictac<=(others=>'0');
					palette_D_tictac<=(others=>'0');
					palette_W_tictac<='0';
				end if;
			elsif dispH='1' and disp='1' then
				-- DISPLAY
				--last_CENTER:=true;
				-- filling palette (PRAM)
				if last_dispH='0' then
					palette_horizontal_counter:=0;
					last_dispH:='1';
				else
					palette_horizontal_counter:=palette_horizontal_counter+1;
				end if;
				if palette_horizontal_counter<1 then
					palette_A_tictac<=palette_A_tictac_mem(13 downto 0);
					-- compute LEFT BORDER
					palette_D_tictac_mem:=conv_std_logic_vector(vram_horizontal_counter,8);
					palette_D_tictac<=palette_D_tictac_mem;
					palette_W_tictac<='1';
					palette_A_tictac_mem:=palette_A_tictac_mem+1;
				elsif palette_horizontal_counter<2 then
					palette_A_tictac<=palette_A_tictac_mem(13 downto 0);
					palette_D_tictac_mem:=conv_std_logic_vector(border,5) & "0" & MODE_select;
					palette_D_tictac<=palette_D_tictac_mem;
					palette_W_tictac<='1';
					palette_A_tictac_mem:=palette_A_tictac_mem+1;
				elsif palette_horizontal_counter<2+16 then
					palette_A_tictac<=palette_A_tictac_mem(13 downto 0);
					if palette_horizontal_counter = 2 then
						palette_color:=0;
					else
						palette_color:=palette_color+1;
					end if;
					palette_D_tictac_mem:=conv_std_logic_vector(pen(palette_color),8);
					palette_D_tictac<=palette_D_tictac_mem;
					palette_W_tictac<='1';
					palette_A_tictac_mem:=palette_A_tictac_mem+1;
				elsif palette_horizontal_counter<2+16+1 then
					palette_A_tictac<=palette_A_tictac_mem(13 downto 0);
					palette_D_tictac_mem:=conv_std_logic_vector(vram_horizontal_counter-(2+16),8);
					-- compute RIGHT BORDER
					palette_D_tictac_mem:=palette_D_tictac_mem+RHdisp;
					palette_D_tictac<=palette_D_tictac_mem;
					palette_W_tictac<='1';
					palette_A_tictac_mem:=palette_A_tictac_mem+1;
				else
					palette_A_tictac<=(others=>'0');
					palette_D_tictac<=(others=>'0');
					palette_W_tictac<='0';
				end if;
			end if;
			
			bvram_A_mem:=conv_std_logic_vector(vram_vertical_counter*VRAM_HDsp+vram_horizontal_counter,bvram_A_mem'length);
		end if;
		vram_horizontal_counter:=vram_horizontal_counter+1;
	end if;
else
	vram_horizontal_offset_counter:=vram_horizontal_offset_counter+1;
end if;

if dispH='0' then
	-- allow last_dispH to go back to '0'.
	last_dispH:='0';
end if;

				--cycle()

				-- The CRTC component is separated from Gatearray component, so does we have some late ?
				-- Not certain, as this old component was really old ones : using state and no rising_egde...
				-- if (hCC == reg[0]) {
				if horizontal_counter_hCC=RHtot then -- tot-1 ok
					--scanStart()
					horizontal_counter_hCC:=(others=>'0');
					
					
					--if (vtAdj > 0 && --vtAdj == 0) newFrame();
					-- else if ((ra | interlaceVideo) == maxRaster) {
					if ("000" & RA=RRmax and "0" & vertical_counter_vCC=RVtot and RVtotAdjust=0)
						or (RVtotAdjust_do and RVtotAdjust_mem=0) then
						-- on a fini RVtotAdjust (ou sinon on a eu un RVtot fini sans RVtotAdjust)
							RVtotAdjust_do:=false;
							--newFrame()
							-- on commence RVtot
							
							--if (vCC == reg[4] && vtAdj == 0) {
							RA:=(others=>'0');
							zap_scan:=false;
							
							--This method requires careful timing for the CRTC register updates,
							--	it also needs testing on all CRTC because there are differences
							-- of when each will accept and use the values programmed. However,
							--	the result can be made to work on all with more simple ruptures.
							--	Care must also be taken to ensure the timings are setup for a 50Hz screen. 
							
							
							
							--When VCC=0, R12/R13 is re-read at the start of each line. R12/R13 can therefore be changed for each scanline when VCC=0. 
							--ma = maBase = maScreen;
							ADRESSE_maBase_mem:=maScreen(13 downto 0);
							ADRESSE_MA_mem:=ADRESSE_maBase_mem;
							vertical_counter_vCC:=(others=>'0');

							-- RVtot vs RVtotAdjust ? RVtotAdjust ne serait-il pas dynamique par hazard ? NON selon JavaCPC c'est meme le contraire
							
					elsif "000" & RA=RRmax then
						RA:=(others=>'0');
						-- scanStart() : maBase = (maBase + reg[1]) & 0x3fff;
						
						if "0" & vertical_counter_vCC=RVtot then
							RVtotAdjust_mem:=RVtotAdjust-1;
							RVtotAdjust_do:=true;
						elsif RVtotAdjust_do then
							RVtotAdjust_mem:=RVtotAdjust_mem-1;
						end if;
						-- Linear Address Generator
						-- Nhd+0
						ADRESSE_maBase_mem:=ADRESSE_maBase_mem+RHdisp;
						ADRESSE_MA_mem:=ADRESSE_maBase_mem;
						-- vCC = (vCC + 1) & 0x7f;
						vertical_counter_vCC:=vertical_counter_vCC+1;

					else
						-- ra = (ra + scanAdd) & 0x1f;
						RA:=RA+1;
						if RVtotAdjust_do then
							RVtotAdjust_mem:=RVtotAdjust_mem-1;
						end if;
						
						ADRESSE_MA_mem:=ADRESSE_maBase_mem;
					end if;
					
				else
					-- hCCMask : so var is size 256 and mod is 128...
					--protected int hCCMask = 0x7f;
					--hCC = (hCC + 1) & hCCMask;
					horizontal_counter_hCC:=horizontal_counter_hCC+1;
					
					ADRESSE_MA_mem:=ADRESSE_MA_mem+1;
				end if;
				if vertical_counter_vCC = 0 then
					LineCounter<='0';
				else
					LineCounter<='1';
				end if;
				DATA_action<='0';
				
				-- SOUND_CLK : random : 1/4 Sim City OK (1/8 ?)
				-- SOUND_CLK : 1100 et 1001 : 3/4 Sim City OK
				-- SOUND_CLK : 0110 et 0011 : 1/4 Sim City OK
				-- SOUND_CLK_i : 1100i : beep too high frequency
				-- SOUND_CLK_i : 0011i : random sound frequency
				-- SOUND_CLK_i : 1001i : Volume change but frequency sound seems fine
				
				-- Sim City's welcome demo is in VRAM 0011 zone in fact.
				
				-- SOUND_CLK : demo CPCrulez "-CIRCLES" KO
				-- SOUND_CLK : demo CPCrulez "-CIRCLES" OK with 0011pi <= Candidate r005.5, KO with all others
				
				SOUND_CLK_i<='0';
			when 1=>
				bvram_A(14 downto 0)<=bvram_A_mem(13 downto 0) & '0';
				DATA_mem:=crtc_D;
				DATA<=DATA_mem;
				DATA_action<='1';
				SOUND_CLK_i<='0';
			when 2=>
				crtc_A(15 downto 0)<=crtc_A_mem(14 downto 0) & '1';
				DATA_action<='0';
				SOUND_CLK_i<='1';
			when 3=>
				bvram_A(14 downto 0)<=bvram_A_mem(13 downto 0) & '1';
				DATA_mem:=crtc_D;
				DATA_action<='1';
				DATA<=DATA_mem;
				SOUND_CLK_i<='1';
			end case;
			
			crtc_DISP<=disp;
			
			if was_MEMWR_0 and MEM_WR='1' then
				waiting_MEMWR:=0;
			end if;
			
			if waiting_MEMWR<LATENCE_MEM_WR then
				waiting_MEMWR:=waiting_MEMWR+1;
				WAIT_MEM_n<='0';
			else
				WAIT_MEM_n<='1';
				if waiting then
					WAIT_n<='0';
				else
					WAIT_n<='1';
				end if;

				--z80_synchronise	
				if M1_n='0' and was_M1_1 and compteur1MHz=0 then
					-- M---M---M---
					-- 012301230123
					-- cool
					waiting:=false;
					WAIT_n<='1';
				elsif waiting and compteur1MHz=0 then
					waiting:=false;
					WAIT_n<='1';
				elsif waiting then
					-- quand on pose un wait, cet idiot il garde M1_n=0 le tour suivant
				elsif M1_n='0' and was_M1_1 then
					-- M--M---M---
					-- 012301230123
					-- M--MW---M---
					-- 012301230123
					
					-- M-M---M---
					-- 012301230123
					-- M-MWW---M---
					-- 012301230123
				
					-- M----M---M---
					-- 0123012301230123
					-- M----MWWW---M---
					-- 0123012301230123
				
					-- pas cool
					WAIT_n<='0';
					waiting:=true;
				elsif compteur1MHz=0 and not(waiting) then
					-- Some instructions has more than 4 Tstate -- validated
				end if;
			end if;
			if M1_n='1' then
				was_M1_1:=true;
			else
				was_M1_1:=false;
			end if;
			if MEM_WR='0' then
				was_MEMWR_0:=true;
			else
				was_MEMWR_0:=false;
			end if;

			
		end if;
	end process simple_GateArray_process;

	aZRaEL_process : process(CLK16MHz) is
		 --variable compteur1MHz : integer range 0 to 3:=0;
		 variable compteur1MHz_16 : integer range 0 to 7:=0;
		 variable old_DATA_action : std_logic:='0';

		 -- aZRaEL
--		type pen2_type is array(15 downto 0) of std_logic_vector(5 downto 0);
--		variable pen2:pen2_type:=(
--			palette(4),palette(12),palette(21),palette(28),
--			palette(24),palette(29),palette(12),palette(5),
--			palette(13),palette(22),palette(6),palette(23),
--			palette(30),palette(0),palette(31),palette(14)
--		);
--		variable border2:std_logic_vector(5 downto 0);
		
		variable DATA_mem:std_logic_vector(7 downto 0);
		
		
		variable NB_PIXEL_PER_OCTET:integer range NB_PIXEL_PER_OCTET_MIN to NB_PIXEL_PER_OCTET_MAX;
		
		variable cursor_pixel_ref : integer range 0 to NB_PIXEL_PER_OCTET_MAX-1;
		variable cursor_pixel : integer range 0 to NB_PIXEL_PER_OCTET_MAX-1;
		--variable cursor_pixel_retard : integer range 0 to NB_PIXEL_PER_OCTET_MAX-1;

		

		
		variable etat_rgb_mem : integer range 0 to 2:=DO_NOTHING_OUT;
		
		variable color : STD_LOGIC_VECTOR(2**(MODE_MAX)-1 downto 0);
		variable color_patch : STD_LOGIC_VECTOR(2**(MODE_MAX)-1 downto 0);
		 
		variable vsync_mem:std_logic;
		variable hsync_mem:std_logic;
	begin
		if rising_edge(CLK16MHz) then
			-- rising_edge
			compteur1MHz_16:=(compteur1MHz_16+1) mod 8;
			
			--compteur1MHz:=(compteur1MHz+1) mod 4;
		
			if DATA_action='1' and old_DATA_action='0' then
				compteur1MHz_16:=0;
				DATA_mem:=DATA;
				vsync_mem:=not(vsync_int);
				hsync_mem:=not(hsync_int);
				etat_rgb_mem:=etat_rgb;
			end if;
			vsync<=vsync_mem;
			hsync<=hsync_mem;

			-- aZRaEL display pixels
			--no_char:=(h / 8) mod (CHAR_WIDTH/8);
			-- 640x200 pixels with 2 colours ("Mode 2", 80 text columns) so it is really 8 physicals pixels per bytes
			
			--new_h:=h/CHAR_WIDTH; -- really 8 physicals pixels per bytes
			--etat_rgb:=DO_READ;
			
			-- more stable
			--cursor_pixel_retard:=cursor_pixel;
			if etat_rgb_mem = DO_READ then
			
				if MODE_select="10" then
					NB_PIXEL_PER_OCTET:=8;
					cursor_pixel_ref:=(compteur1MHz_16 / 1) mod 8;
					cursor_pixel:=cursor_pixel_ref; -- hide one pixel on both
				elsif MODE_select="01" then
					NB_PIXEL_PER_OCTET:=4;
					cursor_pixel_ref:=(compteur1MHz_16 / 2) mod 8; -- ok
					cursor_pixel:=cursor_pixel_ref; -- target correction... data more slow than address coming : one tic
				else --if MODE_select="00" or MODE_select="11" then
					NB_PIXEL_PER_OCTET:=2;
					cursor_pixel_ref:=(compteur1MHz_16 / 4) mod 8;
					cursor_pixel:=cursor_pixel_ref;
				end if;
			
				color:=(others=>'0');
				for i in 2**(MODE_MAX)-1 downto 0 loop
					if (NB_PIXEL_PER_OCTET=2 and i<=3)
					or (NB_PIXEL_PER_OCTET=4 and i<=1)
					or (NB_PIXEL_PER_OCTET=8 and i<=0) then
						color(3-i):=DATA_mem(i*NB_PIXEL_PER_OCTET+(NB_PIXEL_PER_OCTET-1-cursor_pixel));
					end if;
				end loop;
				if NB_PIXEL_PER_OCTET=8 then
					RED<=palette(pen(conv_integer(color(3))))(5 downto 4);
					GREEN<=palette(pen(conv_integer(color(3))))(3 downto 2);
					BLUE<=palette(pen(conv_integer(color(3))))(1 downto 0);
				elsif NB_PIXEL_PER_OCTET=4 then
					RED<=palette(pen(conv_integer(color(3 downto 2))))(5 downto 4);
					GREEN<=palette(pen(conv_integer(color(3 downto 2))))(3 downto 2);
					BLUE<=palette(pen(conv_integer(color(3 downto 2))))(1 downto 0);
				else --if MODE_select="00" then
					color_patch:=color(3) & color(1) & color(2) & color(0); -- wtf xD
					RED<=palette(pen(conv_integer(color_patch)))(5 downto 4);
					GREEN<=palette(pen(conv_integer(color_patch)))(3 downto 2);
					BLUE<=palette(pen(conv_integer(color_patch)))(1 downto 0);
				--else -- MODE 11
				--	RED<="01";
				--	GREEN<="11";
				--	BLUE<="01";
				end if;
			elsif etat_rgb_mem = DO_BORDER then
				RED<=palette(border)(5 downto 4);
				GREEN<=palette(border)(3 downto 2);
				BLUE<=palette(border)(1 downto 0);
			else
				RED<="00";
				GREEN<="00";
				BLUE<="00";
			end if;
			--etat_rgb_retard:=etat_rgb;
			old_DATA_action:=DATA_action;
		end if;
	end process aZRaEL_process;
	
	
--http://www.cpcwiki.eu/index.php/Synchronising_with_the_CRTC_and_display
--	di                      ;; disable maskable interrupts
--	im 1                    ;; interrupt mode 0 (jump to interrupt handler at &0038)
--
--	ld hl,&c9fb             ;; poke EI,RET to interrupt handler.
--	ld (&0038),hl
--	ei                      ;; enable interrupts
--
--	;; first synchronise with the vsync
--	ld b,&f5
--	.vsync_sync
--	in a,(c)
--	rra
--	jr nc,vsync_sync
--
--	;; wait 3 interrupts so we are close to the position
--	;; we want
--	halt
--	halt
--	halt
--	;; at this point we are synchronised to the monitor draw cycle
--
--	;; now waste some time until we are at the exact point
--	ld b,32
--	.waste_time
--	djnz waste_time
--
--	;; we are now synchronised to exactly the point we want
--	.
--	.
--	.

-- 51/3=17 => @4MHz not a 17 counter instead ?

--Interrupt Generation Facility of the Amstrad Gate Array
--The GA has a counter that increments on every falling edge of the CRTC generated HSYNC signal. Once this counter reaches 52, the GA raises the INT signal and resets the counter to 0.
--A VSYNC triggers a delay action of 2 HSYNCs in the GA, at the completion of which the scan line count in the GA is compared to 32. If the counter is below 32, the interrupt generation is suppressed. If it is greater than or equal to 32, an interrupt is issued. Regardless of whether or not an interrupt is raised, the scan line counter is reset to 0.
--The GA has a software controlled interrupt delay feature. The GA scan line counter will be cleared immediately upon enabling this option (bit 4 of ROM/mode control). It only applies once and has to be reissued if more than one interrupt needs to be delayed.
--Once the Z80 acknowledges the interrupt, the GA clears bit 5 of the scan line counter. 
GAinterrupt : process(reset,nCLK4_1)
	variable r52 : std_logic_vector(5 downto 0):=(others=>'0'); -- a 6-bit counter, reset state is 0
	variable hsync_old:std_logic:=DO_NOTHING;
	variable vsync_old:std_logic:=DO_NOTHING;
	variable vSyncInt:integer range 0 to 2:=2;
begin
	
--http://cpctech.cpc-live.com/docs/ints2.html
--	Furthur details of interrupt timing
--
--Here is some information I got from Richard about the interrupt timing:
--"Just when I finally thought I had the interrupt timing sorted out (from real tests on a 6128 and 6128+), I decided to look at the Arnold V diagnostic cartridge in WinAPE, and the Interrupt Timing test failed.
--After pulling my hair out for a few hours, I checked out some info I found on the Z80 which states something like:
--The Z80 forces 2 wait-cycles (2 T-States) at the start of an interrupt.
--The code I had forced a 1us wait state for an interrupt acknowledge. For the most part this is correct, but it's not necessarily so. Seems the instruction currently being executed when an interrupt occurs can cause the extra CPC forced wait-state to be removed.
--Those instructions are:
--
--INC ss (ss = HL, BC, DE or SP)
--INC IX
--INC IY
--DEC ss
--DEC IX
--DEC IY
--RET cc  (condition not met)
--EX (SP),HL
--EX (SP),IX
--EX (SP),IY
--LD SP,HL
--LD SP,IX
--LD SP,IY
--LD A,I
--LD I,A
--LD A,R
--LD R,A
--LDI      (and both states of LDIR)
--LDD     (and both states of LDDR)
--CPIR    (when looping)
--CPDR   (when looping)
--
--This seems to be related to a combination of the T-States of the instruction, the M-Cycles, and the wait states imposed by the CPC hardware to force each instruction to the 1us boundary.
--Richard" 
	
	
--	Interrupt Generation Facility of the Amstrad Gate Array
--The GA has a counter that increments on every falling edge of the CRTC generated HSYNC signal.
--Once this counter reaches 52, the GA raises the INT signal and resets the counter to 0.
--A VSYNC triggers a delay action of 2 HSYNCs in the GA, at the completion of which the scan line
--count in the GA is compared to 32. If the counter is below 32, the interrupt generation is
--suppressed. If it is greater than or equal to 32, an interrupt is issued. Regardless of whether
--or not an interrupt is raised, the scan line counter is reset to 0.
--The GA has a software controlled interrupt delay feature. The GA scan line counter will be
--cleared immediately upon enabling this option (bit 4 of ROM/mode control). It only applies once
--and has to be reissued if more than one interrupt needs to be delayed.
--Once the Z80 acknowledges the interrupt, the GA clears bit 5 of the scan line counter.

--I think that "suppressed" is falling_edge the INTERRUPT signal (to 0), and I think that "raises" is rising_edge the INTERRUPT signal (to 1)
--At IO_ACK signal certainly we shut down the INTERRUPT signal (to 0)
--INTERRUPT
	
--Following my refactoring of Space Invaders during my MameVHDL project, in fact an IO_ACK do event when an interrupt finally want to start, and during IO_ACK, the DATA_BUS is read (warning several instruction, several consequences...)
	if reset='1' then
		r52:=(others=>'0');
		vSyncInt:=2;
		hsync_old:=DO_NOTHING;
		vsync_old:=DO_NOTHING;
		int<='0';
	elsif rising_edge(nCLK4_1) then
		if IO_ACK='1' then
			--the Gate Array will reset bit5 of the counter
			--Once the Z80 acknowledges the interrupt, the GA clears bit 5 of the scan line counter.
			-- When the interrupt is acknowledged, this is sensed by the Gate-Array. The top bit (bit 5), of the counter is set to "0" and the interrupt request is cleared. This prevents the next interrupt from occuring closer than 32 HSYNCs time. http://cpctech.cpc-live.com/docs/ints.html
			r52(5):= '0'; -- following Grimware legends : When the CPU acknowledge the interrupt (eg. it is going to jump to the interrupt vector), the Gate Array will reset bit5 of the counter, so the next interrupt can't occur closer than 32 HSync.
			--compteur52(5 downto 1):= (others=>'0'); -- following JavaCPC 2015
			-- the interrupt request remains active until the Z80 acknowledges it. http://cpctech.cpc-live.com/docs/ints.html
			int<='0'; -- following JavaCPC 2015
		end if;
		
		if IO_REQ_W='1' and A15_A14_A9_A8(3) = '0' and A15_A14_A9_A8(2) = '1' then
			if D(7) ='0' then
				-- ink -- osef
			else
				if D(6) = '0' then
					-- It only applies once
					if D(4) = '1' then
						r52:=(others=>'0');
						--Grimware : if set (1), this will (only) reset the interrupt counter. --int<='0'; -- JavaCPC 2015
						--the interrupt request is cleared and the 6-bit counter is reset to "0".  -- http://cpctech.cpc-live.com/docs/ints.html
						int<='0';
					end if;
					-- JavaCPC 2015 : always old_delay_feature:=D(4); -- It only applies once ????
				else 
					-- rambank -- osef pour 464
				end if;
			end if;
		end if;
		
		
		--vSyncStart()
		if vsync_old=DO_NOTHING and vsync_int=DO_VSYNC then
			--A VSYNC triggers a delay action of 2 HSYNCs in the GA
			--In both cases the following interrupt requests are synchronised with the VSYNC. 
			-- JavaCPC
			vSyncInt := 0;
			vsync_old:=DO_VSYNC;
		elsif vsync_old=DO_VSYNC and vsync_int=DO_NOTHING then
			vsync_old:=DO_NOTHING;
		end if;
		
		
		--The GA has a counter that increments on every falling edge of the CRTC generated HSYNC signal.
		--hSyncEnd()
		if hsync_int=DO_NOTHING and hsync_old=DO_HSYNC then
		-- It triggers 6 interrupts per frame http://pushnpop.net/topic-452-1.html
		
			-- JavaCPC interrupt style...
		
		
			r52:=r52+1;
			if conv_integer(r52)=NB_HSYNC_BY_INTERRUPT then -- Asphalt ? -- 52="110100"
				--Once this counter reaches 52, the GA raises the INT signal and resets the counter to 0.
				r52:=(others=>'0');
				int<='1';
			end if;
		
		
			if vSyncInt < 2 then
				vSyncInt := vSyncInt + 1;
				if vSyncInt = 2 then
					if conv_integer(r52)>=32 then
						int<='1';
					--else
						--int<='0'; -- Circle- DEMO ? / Markus JavaCPC doesn't have this instruction
					end if;
					r52:=(others=>'0');
				end if;
			end if;
			hsync_old:=DO_NOTHING;
		elsif hsync_int=DO_HSYNC and hsync_old=DO_NOTHING then
			hsync_old:=DO_HSYNC;
		end if;

	end if;
end process;
end Behavioral;
