We need to quantify how the XTRX clocks walk around relative to eachother, to determine if it is actually critical that we use the clock distribution network in the XYNC to create a coherent phased array.  Although Experiment 2 (#56) will attempt to overcome some of the difficulties in sharing clocks, we really need to measure and verify the amount of phase difference between receive channels on the same board, as well as the difference in phase between XTRXs within the same XYNC.

The experiment is setup as follows:

```

 ┌──────────────┐
 │  XTRX #1     │
 │         rx[1]│ ◄────── ┌────────┐
 │              │         │   RF   │
 │         rx[2]│ ◄────── │splitter│ ◄───┐
 └──────────────┘         └────────┘     │
                                         └─── ┌────────┐        ┌────────┐
 ┌──────────────┐                             │   RF   │ ◄───── │Sinusoid│
 │  XTRX #2     │                        ┌─── │splitter│        └────────┘
 │         rx[1]│ ◄────── ┌────────┐     │    └────────┘
 │              │         │   RF   │ ◄───┘
 │         rx[2]│ ◄────── │splitter│
 └──────────────┘         └────────┘

```

From this setup, we'll get a sinusoid that is applied across four separate RX channels.  Note that it is important that each SMA cable in the above diagram is the same length.  With this experiment, we can determine the following important pieces of information:

1) How true is it that the two channels on a single XTRX are phase-coherent?
2) How true is it that channels on two different XTRXs are not phase-coherent?
3) What is the impact of thermal expansion?  Do we see the expected "exponential tail" of phase offset over time due to thermal effects?
4) Do we think it is possible to calibrate out the phase differences with Experiment 2 (#56) as-is, or must we investigate the XYNC clock distribution network?