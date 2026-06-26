# STT Engine Benchmark Report

## Aggregate Summary

| Engine | Avg latency ms | Exact match rate |
| --- | ---: | ---: |
| funasr | 297.2 | 0.00 |
| whispercpp | 441.0 | 0.00 |

## Recommendation

Recommendation: whispercpp.

Defaulted to whispercpp because FunASR was not materially better on both quality and latency.

## Known Weak Cases

- funasr / en-001 (english): reference=`open terminal and show git status` transcript=`open terminal and show get status`
- funasr / vi-001 (vietnamese): reference=`mo terminal va hien thi git status` transcript=`moto status`
- funasr / mix-001 (mixed_vi_en): reference=`mo Slack va draft release notes cho sprint nay` transcript=`moose black band ra release nocho three nine`
- funasr / fmt-001 (formatting_command): reference=`new line bullet benchmark summary colon whisper cpp faster` transcript=`new line bullet benchmark summary call and whisper cpp faster`
- whispercpp / en-001 (english): reference=`open terminal and show git status` transcript=`Open Terminal and Show Get Status`
- whispercpp / vi-001 (vietnamese): reference=`mo terminal va hien thi git status` transcript=`Mở tơ mì nấu và hiện thị sụp sây tốt.`
- whispercpp / mix-001 (mixed_vi_en): reference=`mo Slack va draft release notes cho sprint nay` transcript=`Mursorak Vandrak really is not just a finnai.`
- whispercpp / fmt-001 (formatting_command): reference=`new line bullet benchmark summary colon whisper cpp faster` transcript=`New light bullet benchmark summary, colon whisper CPP faster.`

## Next Step Before Native Shell Work

- Start native macOS shell work with `whisper.cpp` as default engine.
- Carry the mixed-language and Vietnamese weak cases into later dictation QA.
- Treat FunASR as optional follow-up, not the MVP default.
