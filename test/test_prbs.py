#!/usr/bin/env python3

class PRBS15Model:
    def __init__(self, n_state=15, taps=[13, 14]):
        self.n_state = n_state
        self.taps = taps
        self.state = 0b100000000000001

    def getbit(self):
        feedback = 0
        for tap in self.taps:
            feedback = feedback ^ (self.state >> tap) & 0x1
        self.state = (self.state << 1) & (2**self.n_state-1) | feedback
        return feedback

    def getbits(self, n):
        v = 0
        for i in range(n):
            v <<= 1
            v |= self.getbit()
        return v

prbs15 = PRBS15Model()
print("AI   AQ   BI   BQ")
for i in range(2**15-1):
    prbs15_value = prbs15.getbits(15)
    r  = f"{prbs15_value           & 0x0fff:04x} " # AI: Twelve LSBs of LFSR
    r += f"{(~prbs15_value)        & 0x0fff:04x} " # AQ: Twelve inverted LSBs of LFSR.
    r += f"{(prbs15_value    >> 4) & 0x0fff:04x} " # BI: Twelve MSBs of LFSR.
    r += f"{((~prbs15_value) >> 4) & 0x0fff:04x}"  # BQ: Twelve inverted MSBs of LFSR.
    print(r)
