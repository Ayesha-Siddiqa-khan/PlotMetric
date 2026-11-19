# Manual OCR comparison checklist

Use the three supplied schedules (the 52 Kanal schedule, the 91 Kanal 16 Marla schedule, the Al-Khair block schedule) and any new one. Do this on each device you care about. Tick only what you actually saw.

## Before you start

* [ ] Note the device, Android or Windows version, and the app build.
* [ ] Windows only: an OCR language is installed (Settings > Time & language > Language).
* [ ] Airplane mode or no internet, to confirm the offline engines work without it.
* [ ] Write down the correct table by hand: description, K, M, S, square feet for every row.

## One engine at a time

1. [ ] Scan page > Choose image (or Take photo).
2. [ ] Drag the four corners around the table only. Rotate if the photo is sideways. Optionally adjust brightness, contrast, grayscale or sharpen. Press **Use crop**.
3. [ ] **View crop** shows exactly the area you chose.
4. [ ] Pick an engine in **Select OCR Engine**. Disabled engines show why.
5. [ ] **Scan with Selected Engine**. Record the time shown.
6. [ ] Rows: is each description on one row, including wrapped descriptions?
7. [ ] Columns: are K, M, S, square feet and % each in their own column (no numbers in the wrong column)?
8. [ ] Rows marked **Needs review** are really the unclear or damaged ones.
9. [ ] Nothing was invented: cells that could not be read are empty, not guessed.
10. [ ] Open a row's edit icon: scanned square feet and scanned K/M/S are both shown; a disagreement asks you to choose.

## Same crop, every offline engine

1. [ ] Press **Run All Available Offline Engines** (no re-crop between engines).
2. [ ] The compare screen lists every engine that ran, with time, word count, whether it reports confidence, warnings and raw text.
3. [ ] No engine is marked as the winner.
4. [ ] **Testing mode**: type the correct table, then record each engine's rows recognised, cells correct, cells in the wrong column, missing and incorrect cells, and time.
5. [ ] **Use this result** for one engine, take single cells from another, retype one cell. The working table shows the source under every cell.
6. [ ] **Use the working table on the Scan page**: the rows appear, and your corrections are still there after switching back and forth.

## Azure (only if a proxy is set up)

1. [ ] **Online OCR setup** accepts an https address and rejects anything else.
2. [ ] Choosing Azure and pressing Scan shows the exact crop and asks for consent. **Do not upload** sends nothing.
3. [ ] After agreeing, the result arrives; with the network off, a clear error appears.
4. [ ] The app is fully usable with no proxy address and no internet.

## Saving

1. [ ] Save, close the page, reopen the colony: rows, ticks, transferred amount and the crop come back.
2. [ ] Re-scan a colony that has recorded transfers: its worksheet rows are kept and a message says so.
3. [ ] Land Calculator, Records, PDF/Word/CSV export and backup/restore still work.

## Record

| Engine | Image | Time | Rows right | Cells right | Wrong column | Missing | Wrong | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
