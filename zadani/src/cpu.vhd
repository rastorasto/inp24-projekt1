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
  signal CNT : std_logic_vector(12 downto 0);
  signal CNT_INC : std_logic;
  signal CNT_DEC : std_logic;

-- TMP
  signal TMP : std_logic_vector(7 downto 0);
  signal TMP_LD : std_logic;

-- PTR
  signal PTR : std_logic_vector(12 downto 0);
  signal PTR_INC : std_logic;
  signal PTR_DEC : std_logic;
  signal PTR_RST : std_logic;

-- PC
  signal PC : std_logic_vector(12 downto 0);
  signal PC_INC : std_logic;
  signal PC_DEC : std_logic;

-- MX1
  signal MX1_SEL : std_logic;

-- MX2
  signal MX2_SEL : std_logic_vector(1 downto 0);

-- IS_ZERO
  signal IS_ZERO : std_logic;

-- DEC
  signal DEC : std_logic_vector(7 downto 0);

-- FSM
  type fsm_state is (
    STATE_START,
    STATE_INIT,
    STATE_PTR_INIT,
    STATE_FETCH,  
    STATE_DECODE,
    STATE_NEXT,
    STATE_INC_PTR,          -- > 0x3E
    STATE_DEC_PTR,          -- < 0x3C
    STATE_INC_PTR_VAL,      -- + 0x2B
    STATE_DEC_PTR_VAL,      -- - 0x2D 
    STATE_CNT_START_WHILE,  -- [ 0x5B
    STATE_CNT_END_WHILE,    -- ] 0x5D
    STATE_SAVE_PTR_TO_TMP,  -- $ 0x24
    STATE_LOAD_TMP_TO_PTR,  -- ! 0x21
    STATE_PUTCHAR,          -- . 0x2E
    STATE_GETCHAR,          -- , 0x2C
    STATE_CODE_DIVIDER,     -- @ 0x40
    STATE_NOP,              -- No operation
    STATE_RETURN
  );
  signal state : fsm_state := STATE_START;
  signal next_state : fsm_state;

begin

  -- CNT
  process(CLK)
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
  process(CLK)
  begin
    if rising_edge(CLK) then -- Pri nabeznej hrane
      if TMP_LD = '1' then -- Signal na load - nacita sa hodnota z DATA_RDATA do TMP
        TMP <= DATA_RDATA;
      end if;
    end if;
  end process;
  -- END TMP

  -- PTR
  process(CLK, PTR_RST)
  begin
    if PTR_RST = '1' then -- Ak pride reset, tak sa nastavi vsetko na 0
      PTR <= (others => '0');
    elsif rising_edge(CLK) then -- Pri nabeznej hrane
      if PTR_INC = '1' then -- Signal na inkrementaciu - inkrementuje sa PTR
        if PTR = "111111111111" then -- Pri preteceni sa nastavi na same 0
          PTR <= (others => '0');
        else
          PTR <= PTR + 1;
        end if;
      elsif PTR_DEC = '1' then -- Signal na dekrementaciu - dekrementuje sa PTR
        if PTR = "000000000000" then -- Pri preteceni smerom dole, nastavi sa na same 1
          PTR <= (others => '1');
        else
          PTR <= PTR - 1;
        end if;
      end if;
    end if;
    end process;
    -- END PTR

  -- PC
  process(CLK)
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
  process(CLK, MX1_SEL, PTR, PC)
  begin
    if MX1_SEL = '0' then -- Ak je selektor na nule, tak cez MX1 prejde hodnota z PTR
      DATA_ADDR <= PTR;
    else -- if MX1_SEL = '1' then Na selektore je jedna, cez MX1 prejde hodnota z PC
      DATA_ADDR <= PC;
    end if;
  end process;
  -- END MX1

  -- MX2
  process(CLK, MX2_SEL, IN_DATA, TMP, DATA_RDATA)
  begin
    if MX2_SEL = "00" then -- Ak je selektor na nule, tak prejde TMP
      DATA_WDATA <= IN_DATA;
    elsif MX2_SEL = "01" then -- Ak je selektor jedna, prejde TMP
      DATA_WDATA <= TMP;
    elsif MX2_SEL = "10" then -- Ak je selektor jedna, prejde DATA_RDATA -1
      DATA_WDATA <= DATA_RDATA - 1;
    else -- if MX2_SEL = "11" then Ak je selektor dva, prejde DATA_RDATA + 1
      DATA_WDATA <= DATA_RDATA + 1;
    end if;
  end process;
  -- END MX2
 
  -- -- MX1
  -- DATA_ADDR <= PTR when MX1_SEL = '0' else PC;
  -- -- END MX1

  -- -- MX2
  -- DATA_WDATA <= IN_DATA when MX2_SEL = "00" else
  --               TMP when MX2_SEL = "01" else
  --               DATA_RDATA - 1 when MX2_SEL = "10" else
  --               DATA_RDATA + 1;
  
  -- IS_ZERO
  IS_ZERO <= '1' when CNT = 0 else '0';  -- Is zero logic
  -- END IS_ZERO

  -- DEC
  DEC <= DATA_RDATA - 1; -- Decrement logic
  -- END DEC

  -- I/O
  OUT_DATA <= DATA_RDATA; -- Connected as shown in the diagram
  
  -- FSM SETUP
  process(CLK, RESET, EN)
  begin
    if RESET = '1' then
      state <= STATE_START; -- Reset fsm
    elsif rising_edge(CLK) then
      if EN = '1' then
        state <= next_state; -- Go to next state on rising edge if fsm is enabled
      end if;
    end if;
  end process;
  -- FSM END

  -- FSM LOGIC
  process(state, DEC)
  begin
    --  next_state <= STATE_START;    

    -- Initialize all the signals that fsm controls

    -- CNT <= (others => '0');
    CNT_INC <= '0';
    CNT_DEC <= '0';

    -- TMP <= (others => '0');
    TMP_LD <= '0';

    -- PTR <= (others => '0');
    PTR_INC <= '0';
    PTR_DEC <= '0';
    PTR_RST <= '0';

    -- PC <= (others => '0');
    PC_INC <= '0';
    PC_DEC <= '0';

    MX1_SEL <= '0';
    MX2_SEL <= "00";

    DATA_RDWR <= '0';
    DATA_EN <= '0';
    -- READY <= '0';
    -- DONE <= '0';

    IN_REQ <= '0';
    OUT_WE <= '0';
    OUT_INV <= '0';

    case state is
      when STATE_START => -- Start state PC ←0, PTR ←0, CNT ←0, READY ←0, DONE ←0
        CNT <= (others => '0');
        -- PTR <= (others => '0'); -- PTR_RST reset it to zeros
        PC <= (others => '0');

        PTR_RST <= '1';
        READY <= '0';
        DONE <= '0';
        next_state <= STATE_INIT; -- Go to init state
      when STATE_INIT => -- Init state PTR ←x + 1, READY ←1 (mem[x] = '@' nutne vymyslet
        MX1_SEL <= '0';
        DATA_RDWR <= '1';
        DATA_EN <= '1';
        if DEC + 1 = x"40" then -- When there is @ in the memory, its one less in DEC
          READY <= '1';
          PTR_INC <= '1';
          next_state <= STATE_RETURN;
        else
          PTR_INC <= '1';
          next_state <= STATE_INIT;
        end if; 
      -- when STATE_FETCH =>
      --     if EN = '1' then -- When fsm gets EN signal, fetch instruciton
      --       MX1_SEL <= '1'; -- Set multiplexor PC - > DATA_ADDR
      --       DATA_RDWR <= '1'; -- Read from memory
      --       next_state <= STATE_DECODE; -- Go to decode instruction
      --     else
      --       next_state <= STATE_START; -- If there is no instruction go to start
      --     end if;
      -- when STATE_DECODE =>
      --   case DATA_RDATA is -- DEC - 1 doesn't work, therefore i am using DATA_RDATA
      --     when x"3E" =>
      --       next_state <= STATE_INC_PTR; -- Increment pointer >
      --     when x"3C" =>
      --       next_state <= STATE_DEC_PTR; -- Decrement pointer <
      --     when x"2B" =>
      --       next_state <= STATE_INC_PTR_VAL; -- Increment pointer value +
      --     when x"2D" =>
      --       next_state <= STATE_DEC_PTR_VAL; -- Decrement pointer value -
      --     when x"5B" =>
      --       next_state <= STATE_CNT_START_WHILE; -- Start while [
      --     when x"5D" =>
      --       next_state <= STATE_CNT_END_WHILE; -- End while ]
      --     when x"24" =>
      --       next_state <= STATE_SAVE_PTR_TO_TMP; -- Save ptr to tmp $
      --     when x"21" =>
      --       next_state <= STATE_LOAD_TMP_TO_PTR; -- Load tmp to ptr !
      --     when x"2E" =>
      --       next_state <= STATE_PUTCHAR; -- Putchar .
      --     when x"2C" =>
      --       next_state <= STATE_GETCHAR; -- Getchar ,
      --     when x"40" =>
      --       next_state <= STATE_CODE_DIVIDER; -- Code divider @
      --     when others =>
      --       next_state <= STATE_NOP; -- No operation
      --   end case;
      -- when STATE_INC_PTR =>
      --   PTR_INC <= '1';
      --   PC_INC <= '1';
      --   next_state <= STATE_FETCH; 
      when STATE_RETURN =>
        DONE <= '1';
        next_state <= STATE_RETURN;
      when others => null;
    end case;
  end process;
  -- FSM END

end behavioral;

