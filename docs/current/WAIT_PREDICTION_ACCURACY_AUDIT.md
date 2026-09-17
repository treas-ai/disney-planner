# Wait Prediction Accuracy Audit

Generated: 2026-09-17T09:39:18+09:00

## Method

- Raw polling is collapsed to one median per facility / local day / time band.
- Each target day is predicted from older occurrences of the same weekday only.
- The latest four matching weekdays use weights 50% / 25% / 15% / 10%, matching HistoricalWaitProfileGenerator.
- Predictions are rounded up to 5 minutes, matching planning behavior.
- The target day is excluded from training, preventing look-ahead leakage.
- At least 2 older matching weekday(s) are required for a scored sample.

## Overall

- Scored samples: 0
- Accuracy cannot be measured from the currently available local history.
- Keep collecting history; this audit will become valid automatically once prior matching weekdays exist.

## tokyo_disneyland

- Local days present: 2 (2026-08-19 to 2026-08-20)
- Daily facility-band medians: 187
- Scored samples: 0

## tokyo_disneysea

- Local days present: 2 (2026-08-19 to 2026-08-20)
- Daily facility-band medians: 199
- Scored samples: 0

## Interpretation

MAE measures typical absolute miss size. Bias above zero means the predictor tends to be conservative (high); below zero means it tends to underpredict. Do not feed these metrics back into scheduling automatically until sample counts are sufficient and stable.
