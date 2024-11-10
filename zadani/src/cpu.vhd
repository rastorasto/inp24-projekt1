-- cpu.vhd: Simple 8-bit CPU (BrainFuck interpreter)
-- Copyright (C) 2024 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): jmeno <login AT stud.fit.vutbr.cz>
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

-- ----------------------------------------------------------------------------
--                        Entity declaration
-- ----------------------------------------------------------------------------
entity cpu is
 port (
   CLK   : in std_logic;  -- hodinovy signal
   RESET : in std_logic;  -- asynchronni reset procesoru
   EN    : in std_logic;  -- povoleni cinnosti procesoru
 
   -- synchronni pamet RAM
   DATA_ADDR  : out std_logic_vector(12 downto 0); -- adresa do pameti
   DATA_WDATA : out std_logic_vector(7 downto 0); -- mem[DATA_ADDR] <- DATA_WDATA pokud DATA_EN='1'
   DATA_RDATA : in std_logic_vector(7 downto 0);  -- DATA_RDATA <- ram[DATA_ADDR] pokud DATA_EN='1'
   DATA_RDWR  : out std_logic;                    -- cteni (1) / zapis (0)
   DATA_EN    : out std_logic;                    -- povoleni cinnosti
   
   -- vstupni port
   IN_DATA   : in std_logic_vector(7 downto 0);   -- IN_DATA <- stav klavesnice pokud IN_VLD='1' a IN_REQ='1'
   IN_VLD    : in std_logic;                      -- data platna
   IN_REQ    : out std_logic;                     -- pozadavek na vstup data
   
   -- vystupni port
   OUT_DATA : out  std_logic_vector(7 downto 0);  -- zapisovana data
   OUT_BUSY : in std_logic;                       -- LCD je zaneprazdnen (1), nelze zapisovat
   OUT_INV  : out std_logic;                      -- pozadavek na aktivaci inverzniho zobrazeni (1)
   OUT_WE   : out std_logic;                      -- LCD <- OUT_DATA pokud OUT_WE='1' a OUT_BUSY='0'

   -- stavove signaly
   READY    : out std_logic;                      -- hodnota 1 znamena, ze byl procesor inicializovan a zacina vykonavat program
   DONE     : out std_logic                       -- hodnota 1 znamena, ze procesor ukoncil vykonavani programu (narazil na instrukci halt)
 );
end cpu;


-- ----------------------------------------------------------------------------
--                      Architecture declaration
-- ----------------------------------------------------------------------------
architecture behavioral of cpu is

-- CNT
  signal CNT : std_logic_vector(12 downto 0) := (others => '0');
  signal CNT_INC : std_logic := '0';
  signal CNT_DEC : std_logic := '0';

-- TMP
  signal TMP : std_logic_vector(12 downto 0) := (others => '0');
  signal TMP_LD : std_logic := '0';

-- PTR
  signal PTR : std_logic_vector(12 downto 0) := (others => '0');
  signal PTR_INC : std_logic := '0';
  signal PTR_DEC : std_logic := '0';
  signal PRT_RST : std_logic := '0';

-- PC
  signal PC : std_logic_vector(12 downto 0) := (others => '0');
  signal PC_INC : std_logic := '0';
  signal PC_DEC : std_logic := '0';

-- MX1
  signal MX1_SEL : std_logic := '0';

-- MX2
  signal MX2_SEL : std_logic_vector(1 downto 0) := (others => '0');

-- IS_ZERO
  signal IS_ZERO : std_logic := '0';

-- FSM
  type fsm_state is (
    STATE_INIT,
    STATE_SAVE_PTR_TO_TMP,
    STATE_SAVE_TMP_TO_PTR,
    STATE_CNT_INC,
    STATE_CNT_DEC,
    STATE_TMP_LD,
    STATE_PTR_INC,
    STATE_PTR_DEC,
    STATE_PTR_RST,
    STATE_PC_INC,
    STATE_PC_DEC,
    STATE_MX1_SEL,
    STATE_MX2_SEL,
    STATE_WHILE_PTR,
    STATE_PUTCHAR_PTR,
    STATE_GETCHAR_PTR,
    STATE_RETURN
  );
  signal state : fsm_state := START_STATE;
  signal next_state : fsm_state;

begin

  -- CNT
  process(CLK, RESET)
  begin
    if rising_edge(CLK) then -- Pri nabeznej hrane
      if CNT_INC = '1' then -- Signal na inkrementaciu - inkrementuje sa CNT
        CNT <= CNT + 1;
      elsif CNT_DEC = '1' then -- Signal na dekrementaciu - dekrementuje sa CNT
        CNT <= CNT - 1;
      end if;
    end if;
  end process;
  -- END CNT

  -- TMP
  process(CLK, RESET)
  begin
    if rising_edge(CLK) then -- Pri nabeznej hrane
      if TMP_LD = '1' then -- Signal na load - nacita sa hodnota z DATA_RDATA do TMP
        TMP <= DATA_RDATA;
      end if;
    end if;
  end process;
  -- END TMP

  -- PTR
  process(CLK, RESET)
  begin
    if PRT_RST = '1' then -- Ak pride reset, tak sa nastavi vsetko na 0
      PTR <= (others => '0');
    elsif rising_edge(CLK) then -- Pri nabeznej hrane
      if PTR_INC = '1' then -- Signal na inkrementaciu - inkrementuje sa PTR
        PTR <= PTR + 1;
      elsif PTR_DEC = '1' then -- Signal na dekrementaciu - dekrementuje sa PTR
        PTR <= PTR - 1;
      end if;
    end if;
  end process;
  -- END PTR

  -- PC
  process(CLK, RESET)
  begin
    if rising_edge(CLK) then -- Pri nabeznej hrane
      if PC_INC = '1' then -- Signal na inkrementaciu - inktrementuje sa PC
        PC <= PC + 1;
      elsif PC_DEC = '1' then -- Signal na dekrementaciu - dekrementuje sa PC
        PC <= PC - 1;
      end if;
    end if;
  end process;
  -- END PC

  -- MX1
  process(CLK, RESET)
  begin
    if rising_edge(CLK) then -- Pri nabeznej hrane
      if MX1_SEL = '0' then -- Ak je selektor na nule, tak cez MX1 prejde hodnota z PTR
        DATA_ADDR <= PTR;
      else -- if MX1_SEL = '1' then Na selektore je jedna, cez MX1 prejde hodnota z PC
        DATA_ADDR <= PC;
      end if;
    end if;
  end process;
  -- END MX1

  -- MX2
  process(CLK, RESET)
  begin
    if rising_edge(CLK) then -- Pri nabeznej hrane
      if MX2_SEL = "00" then -- Ak je selektor na nule, tak prejde TMP
        DATA_WDATA <= IN_DATA;
      elsif MX2_SEL = "01" then -- Ak je selektor jedna, prejde TMP
        DATA_WDATA <= TMP;
      elsif MX2_SEL = "10" then -- Ak je selektor jedna, prejde DATA_RDATA -1
        DATA_WDATA <= DATA_RDATA - 1;
     else -- if MX2_SEL = "11" then Ak je selektor dva, prejde DATA_RDATA + 1
        DATA_WDATA <= DATA_RDATA + 1;
      end if;
    end if;
  end process;
  -- END MX2
  
  
  -- FSM START
  process(CLK, RESET, EN)
  begin
    if RESET = '1' then
      state <= STATE_START;
    elsif rising_edge(CLK) then
      if EN = '1' then
        state <= NEXT_STATE;
      end if;
    end if;
  end process;
  -- FSM END

  


end behavioral;

