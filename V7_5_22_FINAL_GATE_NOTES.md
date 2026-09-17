# v7.5.22 final gate notes

- Freeze the validated four-mode behavior after compactSchedule r5.
- Final automated gate runs full verification and the four-mode differentiation probe.
- Mode gate requires all four probe outputs, 4/4 distinct orders, minimumWait not worse than balanced wait, minimumWalking not worse than balanced movement, and compactSchedule not worse than balanced for largest free block or block count.
- Existing wait prediction accuracy audit is executed when Python and the audit script are available. Insufficient historical evidence remains explicit and is not converted into a false pass.
- Final tag still requires the representative 10/5 TDL runtime regression: hard wishes 10/10, optional 1/2, fixed-time consistency, and visible delay-stress diagnostics.
