# v7.5.22 plan-creation completion gates

v7.5.22 is the consolidation release for the remaining 7.5.x plan-creation work. Moving to 7.6 requires all gates below to be verified, not merely implemented.

1. Hard wishes: feasible cases preserve every required occurrence; optional additions never displace them.
2. Temporal validity: no overlap and all fixed performances, meals, operating windows, access rights, movement, entry and exit constraints remain valid.
3. Optimization modes: balanced, minimum wait, minimum walking and compact-free-time remain end-to-end modes. Their outputs must be compared with quantitative metrics before 7.6.
4. Wait accuracy: use the leakage-free audit report (MAE/Bias/RMSE). Do not auto-correct the scheduler without enough historical samples.
5. Robustness: the plan-quality audit surfaces minimum margin, fragmented free time and overlaps. Small margins are warnings, never hard feasibility limits.
6. Explainability: rejected optional additions retain evidence from the actual combination search and remain stored as optional candidates.
7. Regression: the 2026-10-05 TDL representative case remains a required manual regression: original wishes 10/10 and minimum-wait normal queue total 280 minutes.
8. Release quality: flutter analyze, flutter test and Windows runtime confirmation are required before tagging v7.5.22 and before starting 7.6.

The visible free-time amount is never treated as a direct upper bound for adding a facility. Candidate adoption continues to be decided by full-day reoptimization.
