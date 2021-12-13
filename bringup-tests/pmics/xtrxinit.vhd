-------------------------------------------------------------------------------
-- Title      : xtrx power init sequencer
-- Project    : 
-------------------------------------------------------------------------------
-- File       : xtrxinit.vhd
-- Author     : mazsi-on-xtrx <@>
-- Company    : 
-- Created    : 2019-01-22
-- Last update: 2019-02-23
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2019 GPLv2 (no later versions)
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Author  Description
-- 2019-01-22  mazsi   Created
-- 2019-02-21  mazsi   simplified version: no support for i2c clock streching
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;





entity xtrxinit is

  generic (
    CLKFREQ : integer := 65_000_000;    -- CLK freq in Hz
    I2CFREQ : integer := 100_000        -- i2c CLK (SCL) freq in Hz
    );

  port (
    ---------------------------------------------------------------------------
    CLK          : in  std_logic;
    RST          : in  std_logic := '0';
    BUSY         : out std_logic;
    OK           : out std_logic;
    ---------------------------------------------------------------------------
    SDA0T, SCL0T : out std_logic := '1';
    SDA0I, SCL0I : in  std_logic := '1';
    --
    SDA1T, SCL1T : out std_logic := '1';
    SDA1I, SCL1I : in  std_logic := '1'
   ---------------------------------------------------------------------------
    );

end entity xtrxinit;





architecture imp of xtrxinit is

  constant CLKDIV : integer := CLKFREQ / I2CFREQ / 4;

  signal divcntr : integer range 0 to CLKDIV - 1 := 0;
  signal tick    : std_logic;

  signal addr                      : unsigned(11 downto 0) := (others => '0');
  signal data                      : std_logic_vector(3 downto 0);
  signal bussel, sclt, sdat, check : std_logic;

  signal sdapicked, oki : std_logic := '1';

begin



  -----------------------------------------------------------------------------
  -- baud generator
  -----------------------------------------------------------------------------

  process (CLK) is
  begin
    if CLK'event and CLK = '1' then
      if divcntr = CLKDIV - 1 then
        tick    <= '1';
        divcntr <= 0;
      else
        tick    <= '0';
        divcntr <= divcntr + 1;
      end if;
    end if;
  end process;



  -----------------------------------------------------------------------------
  -- address generator: continously increment (with overflow) lower bits,
  -- increment upper bits only if transaction succeeded (oki = '1')
  -----------------------------------------------------------------------------

  process (CLK) is
    constant ADDRMAX : unsigned(addr'range) := (others => '1');
    alias addrhi     : unsigned(11 downto 8) is addr(11 downto 8);
    alias addrlo     : unsigned(7 downto 0) is addr(7 downto 0);
  begin
    if CLK'event and CLK = '1' then

      if RST = '1' then
        addrlo <= (others => '0');
      elsif tick = '1' and addr /= ADDRMAX then
        addrlo <= addrlo + 1;
      end if;

      if RST = '1' then
        addrhi <= (others => '0');
      elsif tick = '1' and addrlo = 255 and addr /= ADDRMAX and oki = '1' then
        addrhi <= addrhi + 1;
      end if;

      if addr /= ADDRMAX then
        BUSY <= '1';
      else
        BUSY <= '0';
      end if;

    end if;
  end process;



  -----------------------------------------------------------------------------
  -- waveform ROM
  -----------------------------------------------------------------------------

  rom : entity work.xtrxinitrom port map (CLK => CLK, A => std_logic_vector(addr), Q => data);

  bussel <= data(3);
  sclt   <= data(2);
  sdat   <= data(1);
  check  <= data(0);



  -----------------------------------------------------------------------------
  -- drive output: pull down SDA/SCL to '0' on selected bus
  -----------------------------------------------------------------------------

  process (CLK) is
  begin
    if CLK'event and CLK = '1' then

      if oki = '1' and bussel = '0' then
        SDA0T <= sdat or check;         -- don't driver when reading
        SCL0T <= sclt;
      else
        SDA0T <= '1';
        SCL0T <= '1';
      end if;

      if oki = '1' and bussel = '1' then
        SDA1T <= sdat or check;         -- don't drive when reading
        SCL1T <= sclt;
      else
        SDA1T <= '1';
        SCL1T <= '1';
      end if;

    end if;
  end process;



  -----------------------------------------------------------------------------
  -- check sda: deassert sticky 'oki' bit if input is not matching expected value
  -- reset it to '1' at the beginning of each transaction
  -----------------------------------------------------------------------------

  process (CLK) is
  begin
    if CLK'event and CLK = '1' then

      if bussel = '0' then
        sdapicked <= SDA0I;
      else
        sdapicked <= SDA1I;
      end if;

      if RST = '1' then
        oki <= '1';
      elsif addr(7 downto 0) = 0 then
        oki <= '1';
      --elsif tick = '1' and addr(1 downto 0) = "10" and check = '1' and sdapicked /= sdat then
      --  oki <= '0';
      end if;

      OK <= oki;                        -- extra reg, but it's ok

    end if;
  end process;



end architecture imp;



