-- top.vhd : Demo pro desku PYNQ-Z2
--   Konfiguraci pro FPGA (bitstream) ziskanou prikazem make bitstream a ulozenou v souboru top.bit 
--   lze nahrat a vyzkouset na adrese https://pcl307-fpga.fit.vutbr.cz
-- Copyright (C) 2024 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): Zdenek Vasicek <vasicek AT fit.vutbr.cz>
--
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

entity top is
    port (
        SYSCLK : in STD_LOGIC;
        ROW : out STD_LOGIC_VECTOR (7 downto 0);
        COL : out STD_LOGIC_VECTOR (7 downto 0));
end top;

architecture beh of top is

    component sys_driver is
        port (
            CLK : in STD_LOGIC;
            OUT_DATA : in STD_LOGIC_VECTOR(7 downto 0);
            OUT_BUSY : out STD_LOGIC;
            OUT_INV : in STD_LOGIC;
            OUT_WE : in STD_LOGIC;
            EN : out STD_LOGIC;
            RST : out STD_LOGIC;
            ROW : out STD_LOGIC_VECTOR (7 downto 0);
            COL : out STD_LOGIC_VECTOR (7 downto 0));
    end component;

    signal cpu_rst : STD_LOGIC;
    signal cpu_en : STD_LOGIC;

    signal ram_addr : STD_LOGIC_VECTOR(12 downto 0);
    signal ram_rdata : STD_LOGIC_VECTOR(7 downto 0);
    signal ram_wdata : STD_LOGIC_VECTOR(7 downto 0);
    signal ram_rdwr : STD_LOGIC;
    signal ram_en : STD_LOGIC;

    signal in_data : STD_LOGIC_VECTOR(7 downto 0) := "00000000";
    signal in_req : STD_LOGIC;
    signal in_vld : STD_LOGIC := '0';

    signal out_data : STD_LOGIC_VECTOR(7 downto 0);
    signal out_we, out_inv : STD_LOGIC;
    signal out_busy : STD_LOGIC;

begin

    -- =================================================
    -- Pamet programu a pamet dat
    -- =================================================
    ram_mem : entity work.ram
        generic map(
            -- Inicializace obsahu pameti RAM
            -- [1] Vypis textu 11,12,13,... na displej 
            --INIT => "+++++++++++++++++>-[<.+>>-[>-[>++++++++++++++++[-]<-]<-]<]@"
            INIT => ">-[<.+>>-[>-[>++++++++++++++++[-]<-]<-]<]@" & CHARACTER'VAL(17)
        )
        port map(
            CLK => SYSCLK,
            -- RAM
            ADDR => ram_addr,
            RDATA => ram_rdata,
            WDATA => ram_wdata,
            EN => ram_en,
            RDWR => ram_rdwr
        );

    -- =================================================
    -- Procesor
    -- =================================================
    bfcpu : entity work.cpu
        port map(
            --Ridici signaly
            CLK => SYSCLK, -- Hodiny
            RESET => cpu_rst, -- Reset
            EN => cpu_en, -- povoleni cinnosti

            --RAM
            DATA_ADDR => ram_addr,
            DATA_RDATA => ram_rdata,
            DATA_WDATA => ram_wdata,
            DATA_RDWR => ram_rdwr,
            DATA_EN => ram_en,

            --INPUT
            IN_DATA => in_data,
            IN_VLD => in_vld,
            IN_REQ => in_req,

            --OUTPUT
            OUT_DATA => out_data,
            OUT_BUSY => out_busy,
            OUT_WE => out_we,
            OUT_INV => out_inv
        );

    -- =================================================
    -- Radic displeje
    -- =================================================
    drv : sys_driver
    port map(
        CLK => SYSCLK,
        ROW => ROW,
        COL => COL,

        OUT_DATA => out_data,
        OUT_BUSY => out_busy,
        OUT_WE => out_we,
        OUT_INV => out_inv,

        EN => cpu_en,
        RST => cpu_rst
    );

end beh;