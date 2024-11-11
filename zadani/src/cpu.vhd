-- cpu.vhd: Simple 8-bit CPU (BrainFuck interpreter)
-- Copyright (C) 2024 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): Rastislav Uhliar xuhliar00@stud.fit.vutbr.cz
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
  signal CNT_INC : std_logic;
  signal CNT_DEC : std_logic;

-- TMP
  signal TMP : std_logic_vector(7 downto 0) := (others => '0');
  signal TMP_LD : std_logic;

-- PTR
  signal PTR : std_logic_vector(12 downto 0) := (others => '0');
  signal PTR_INC : std_logic;
  signal PTR_DEC : std_logic;

-- PC
  signal PC : std_logic_vector(12 downto 0) := (others => '0');
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
    STATE_INIT_CMP,
    STATE_PTR_INIT,
    STATE_FETCH,  
    STATE_DECODE,
    STATE_INC_PTR,          -- > 0x3E
    STATE_DEC_PTR,          -- < 0x3C
    STATE_INC_PTR_VAL_READ, -- + 0x2B
    STATE_INC_PTR_VAL_WRITE,
    STATE_DEC_PTR_VAL_READ, -- - 0x2D 
    STATE_DEC_PTR_VAL_WRITE,
    STATE_START_WHILE,  -- [ 0x5B
    STATE_START_WHILE_CMP,
    STATE_START_FIND_END,
    STATE_START_FIND_END_CMP,
    STATE_END_WHILE,    -- ] 0x5D
    STATE_END_FIND_START,
    STATE_SAVE_PTR_TO_TMP,  -- $ 0x24
    STATE_SAVE_PTR_TO_TMP_WRITE,
    STATE_LOAD_TMP_TO_PTR,  -- ! 0x21
    STATE_PUTCHAR,          -- . 0x2E
    STATE_PUTCHAR_PRINT,    
    STATE_GETCHAR,          -- , 0x2C
    STATE_GETCHAR_READ,     
    STATE_CODE_DIVIDER,     -- @ 0x40
    STATE_NOP               -- No operation
  );
  signal state : fsm_state := STATE_START;
  signal next_state : fsm_state;

begin

  -- CNT
  process(CLK, RESET)
  begin
    if RESET = '1' then -- When reset signal comes, set everything to 0
      CNT <= (others => '0');
    elsif rising_edge(CLK) then -- At rising edge
      if CNT_INC = '1' then -- Increment signal - CNT gets incremented
        CNT <= CNT + 1;
      elsif CNT_DEC = '1' then -- Decrement signal - CNT gets decremented
        CNT <= CNT - 1;
      end if;
    end if;
  end process;
  -- END CNT

  -- TMP
  process(CLK, RESET)
  begin
    if RESET = '1' then -- When reset signal comes, set everything to 0
      TMP <= (others => '0');
    elsif rising_edge(CLK) then -- At rising edge
      if TMP_LD = '1' then -- Load signal - Get data from DATA_RDATA to TMP
        TMP <= DATA_RDATA;
      end if;
    end if;
  end process;
  -- END TMP

  -- PTR
  process(CLK, RESET)
  begin
    if RESET = '1' then -- When reset signal comes, set everything to 0
      PTR <= (others => '0');
    elsif rising_edge(CLK) then -- At rising edge
      if PTR_INC = '1' then -- Increment signal - PTR gets incremented
        if PTR = "1111111111111" then -- On overflow, set to all 0s
          PTR <= (others => '0');
        else
          PTR <= PTR + 1;
        end if;
      elsif PTR_DEC = '1' then -- Decrement signal - PTR gets decremented
        if PTR = "0000000000000" then -- On underflow, set to all 1s
          PTR <= (others => '1');
        else
          PTR <= PTR - 1;
        end if;
      end if;
    end if;
  end process;
    -- END PTR

  -- PC
  process(CLK, RESET)
  begin
    if RESET = '1' then -- When reset signal comes, set everything to 0
      PC <= (others => '0');
    elsif rising_edge(CLK) then -- At rising edge
      if PC_INC = '1' then -- Increment signal - PC gets incremented
        PC <= PC + 1;
      elsif PC_DEC = '1' then -- Decrement signal - PC gets decremented
        PC <= PC - 1;
      end if;
    end if;
  end process;
  -- END PC

  -- MX1
  process(MX1_SEL, PTR, PC)
  begin
    if MX1_SEL = '0' then -- If the selector is zero, the value from PTR passes through MX1
      DATA_ADDR <= PTR;
    else -- If the selector is one, the value from PC passes through MX1
      DATA_ADDR <= PC;
    end if;
  end process;
  -- END MX1

  -- MX2
  process(MX2_SEL, IN_DATA, TMP, DATA_RDATA)
  begin
    if MX2_SEL = "00" then -- If the selector is zero, IN_DATA passes through MX2
      DATA_WDATA <= IN_DATA;
    elsif MX2_SEL = "01" then -- If the selector is one, TMP passes through MX2
      DATA_WDATA <= TMP;
    elsif MX2_SEL = "10" then -- If the selector is two, DATA_RDATA - 1 passes through MX2
      DATA_WDATA <= DATA_RDATA - 1;
    else -- If the selector is three, DATA_RDATA + 1 passes through MX2
      DATA_WDATA <= DATA_RDATA + 1;
    end if;
  end process;
  -- END MX2
 
  -- IS_ZERO
  IS_ZERO <= '1' when CNT = 0 else '0';  -- Is zero logic
  -- END IS_ZERO

  
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
  process(state, DEC, DATA_RDATA, IS_ZERO, EN, OUT_BUSY, IN_VLD)
  begin
    next_state <= STATE_START;    

    -- Initialize all the signals that fsm controls
    CNT_INC <= '0';
    CNT_DEC <= '0';

    TMP_LD <= '0';

    PTR_INC <= '0';
    PTR_DEC <= '0';

    PC_INC <= '0';
    PC_DEC <= '0';

    MX1_SEL <= '0';
    MX2_SEL <= "00";

    DATA_RDWR <= '0';
    DATA_EN <= '0';

    IN_REQ <= '0';
    OUT_WE <= '0';
    OUT_INV <= '0';

    DEC <= DATA_RDATA;

    OUT_DATA <= DATA_RDATA;

    case state is
      when STATE_START => -- Start state PC ←0, PTR ←0, CNT ←0, READY ←0, DONE ←0
        READY <= '0';
        DONE <= '0';
        next_state <= STATE_INIT; -- Go to init state

      when STATE_INIT => -- Init state PTR ←x + 1, READY ←1 (mem[x] = '@' nutne vymyslet
        MX1_SEL <= '0'; -- Set multiplexor PTR -> DATA_ADDR
        DATA_RDWR <= '1';
        DATA_EN <= '1';
        next_state <= STATE_INIT_CMP;

      WHEN STATE_INIT_CMP =>
        if DEC = x"40" then -- When there is @ in the memory
          READY <= '1';
          PTR_INC <= '1';
          next_state <= STATE_FETCH; -- Go to fetch instruction
        else
          PTR_INC <= '1';
          next_state <= STATE_INIT;
        end if; 

      when STATE_FETCH =>
          if EN = '1' then -- When fsm gets EN signal, fetch instruciton
            MX1_SEL <= '1'; -- Set multiplexor PC - > DATA_ADDR
            DATA_RDWR <= '1'; -- Read from memory
            DATA_EN <= '1';
            next_state <= STATE_DECODE; -- Go to decode instruction
          else
            next_state <= STATE_NOP; -- If there is no instruction go to start
          end if;

      when STATE_DECODE =>
        case DEC is -- Decode value
          when x"3E" =>
            next_state <= STATE_INC_PTR; -- Increment pointer >
          when x"3C" =>
            next_state <= STATE_DEC_PTR; -- Decrement pointer <
          when x"2B" =>
            next_state <= STATE_INC_PTR_VAL_READ; -- Increment pointer value +
          when x"2D" =>
            next_state <= STATE_DEC_PTR_VAL_READ; -- Decrement pointer value -
          when x"5B" =>
            next_state <= STATE_START_WHILE; -- Start while [
          when x"5D" =>
            next_state <= STATE_END_WHILE; -- End while ]
          when x"24" =>
            next_state <= STATE_SAVE_PTR_TO_TMP; -- Save ptr to tmp $
          when x"21" =>
            next_state <= STATE_LOAD_TMP_TO_PTR; -- Load tmp to ptr !
          when x"2E" =>
            next_state <= STATE_PUTCHAR; -- Putchar .
          when x"2C" =>
            next_state <= STATE_GETCHAR; -- Getchar ,
          when x"40" =>
            next_state <= STATE_CODE_DIVIDER; -- Code divider @
          when others =>
            next_state <= STATE_NOP; -- No operation
        end case;

      when STATE_INC_PTR => -- Increment pointer and moves to the next instruction
        PTR_INC <= '1';
        PC_INC <= '1';
        next_state <= STATE_FETCH;

      when STATE_DEC_PTR => -- Decrements pointer and moves to the next instruction
        PTR_DEC <= '1';
        PC_INC <= '1';
        next_state <= STATE_FETCH;

      when STATE_INC_PTR_VAL_READ => -- Data from memory is on the line
        MX1_SEL <= '0'; -- Set multiplexor PTR -> DATA_ADDR
        DATA_RDWR <= '1'; -- Prepare to read from memory
        DATA_EN <= '1';
        PC_INC <= '1'; -- Increment PC
        next_state <= STATE_INC_PTR_VAL_WRITE;

      when STATE_INC_PTR_VAL_WRITE => -- Data from memory is still on the line and gets written
        MX1_SEL <= '0'; -- Set multiplexor PTR -> DATA_ADDR
        DATA_RDWR <= '0'; -- Prepare to write to memory
        DATA_EN <= '1';
        MX2_SEL <= "11"; -- Set multiplexor DATA_RDATA + 1
        next_state <= STATE_FETCH;

      when STATE_DEC_PTR_VAL_READ => -- Data from memory is on the line
        MX1_SEL <= '0'; -- Set multiplexor PTR -> DATA_ADDR
        DATA_RDWR <= '1'; -- Prepare to read from memory
        DATA_EN <= '1';
        PC_INC <= '1'; -- Increment PC
        next_state <= STATE_DEC_PTR_VAL_WRITE;

      when STATE_DEC_PTR_VAL_WRITE => -- Data from memory is still on the line and gets written
        MX1_SEL <= '0'; -- Set multiplexor PTR -> DATA_ADDR
        DATA_RDWR <= '0'; -- Prepare to write to memory
        DATA_EN <= '1';
        MX2_SEL <= "10"; -- Set multiplexor DATA_RDATA - 1
        next_state <= STATE_FETCH;
     
      when STATE_PUTCHAR => -- Putchar
        MX1_SEL <= '0'; -- Set multiplexor PTR -> DATA_ADDR
        PC_INC <= '1'; -- Increment PC
        DATA_RDWR <= '1'; -- Prepare to read from memory
        DATA_EN <= '1';
        next_state <= STATE_PUTCHAR_PRINT;

      when STATE_PUTCHAR_PRINT => -- Putchar print
        if OUT_BUSY = '0' then -- If output is not busy
          OUT_WE <= '1'; -- Enable output
          -- OUT_DATA <= DATA_RDATA; -- Write data to output ( DATA_RDATA is always connected to OUT_DATA therefore i commented this line )
          next_state <= STATE_FETCH;
        else
          next_state <= STATE_PUTCHAR_PRINT;
        end if;

      when STATE_GETCHAR => -- Getchar
        IN_REQ <= '1'; -- Enable input
        if IN_VLD = '1' then -- Input valid, can read
          next_state <= STATE_GETCHAR_READ;
        else
          next_state <= STATE_GETCHAR;
        end if;

      when STATE_GETCHAR_READ => -- Getchar read
        MX1_SEL <= '0'; -- Set multiplexor PTR -> DATA_ADDR
        MX2_SEL <= "00"; -- Set multiplexor IN_DATA -> DATA_WDATA
        DATA_RDWR <= '0'; -- Prepare to write to memory
        DATA_EN <= '1';
        PC_INC <= '1'; -- Increment PC
        next_state <= STATE_FETCH;
        
      when STATE_SAVE_PTR_TO_TMP => -- Save ptr to tmp
        MX1_SEL <= '0'; -- Set multiplexor PTR -> DATA_ADDR
        DATA_RDWR <= '1'; -- Prepare to read from memory
        DATA_EN <= '1';
        PC_INC <= '1'; -- Increment PC
        next_state <= STATE_SAVE_PTR_TO_TMP_WRITE;
        
      when STATE_SAVE_PTR_TO_TMP_WRITE =>
        TMP_LD <= '1'; -- Load TMP
        next_state <= STATE_FETCH;

      when STATE_LOAD_TMP_TO_PTR => -- Load tmp to ptr
        MX1_SEL <= '0'; -- Set multiplexor PTR -> DATA_ADDR
        MX2_SEL <= "01"; -- Set multiplexor TMP -> DATA_WDATA
        DATA_RDWR <= '0'; -- Prepare to write to memory
        DATA_EN <= '1';
        PC_INC <= '1'; -- Increment PC
        next_state <= STATE_FETCH;

      when STATE_START_WHILE => -- Prepares multiplexor and memory to check if it should go to the loop
        MX1_SEL <= '0'; -- Set multiplexor PTR -> DATA_ADDR
        DATA_RDWR <= '1'; -- Prepare to read from memory
        DATA_EN <= '1';
        next_state <= STATE_START_WHILE_CMP;

      when STATE_START_WHILE_CMP => -- Checks if it should go to the loop, if not, finds the end and goes there
        if DEC = x"00" then -- Go to the end if PTR is zero
          next_state <= STATE_START_FIND_END;
        else
          PC_INC <= '1'; -- Increment PC
          next_state <= STATE_FETCH;
        end if;

      when STATE_START_FIND_END => -- If loop condition it not met, find the end of the loop
        MX1_SEL <= '1'; -- Set multiplexor PC -> DATA_ADDR
        DATA_RDWR <= '1'; -- Prepare to read from memory
        DATA_EN <= '1';
        next_state <= STATE_START_FIND_END_CMP;
        
      when STATE_START_FIND_END_CMP => -- Loops until it find end of the loop
        if DEC = x"5D" then -- If the end is found
          PC_INC <= '1'; -- Increment PC
          next_state <= STATE_FETCH;
        else
          PC_INC <= '1'; -- Increment PC
          next_state <= STATE_START_FIND_END;
        end if;

      when STATE_END_WHILE => -- If it gets to the end of the loop, it goes back to the start
        MX1_SEL <= '1'; -- Set multiplexor PC -> DATA_ADDR
        DATA_RDWR <= '1'; -- Prepare to read from memory
        DATA_EN <= '1';
        next_state <= STATE_END_FIND_START;

      when STATE_END_FIND_START => -- Loops until it finds the start
        if DEC = x"5B" then -- If the start is found
          next_state <= STATE_FETCH;
        else
          PC_DEC <= '1'; -- Increment PC
          next_state <= STATE_END_WHILE;
        end if;

      when STATE_CODE_DIVIDER => -- Code divider
        DONE <= '1'; -- Done
        next_state <= STATE_CODE_DIVIDER;

      when STATE_NOP => -- No operation
        PC_INC <= '1'; -- Increment PC
        next_state <= STATE_FETCH;

      when others => null;
    end case;
  end process;
  -- FSM END

end behavioral;

