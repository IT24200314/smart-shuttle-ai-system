# PP2 Test Cases – Passenger AI & Revenue Dashboard

## Passenger Counting AI

| # | Module | Input / Action | Expected Result | Status |
|---|--------|----------------|----------------|--------|
| 1 | Passenger Counting AI | Run the AI script with a valid prerecorded video file | Video opens, YOLO detection runs, passenger count is processed, and final count is shown at the end | Pending |
| 2 | Passenger Counting AI | Set `VIDEO_PATH` to a missing file and run the script | Script shows a clear video file not found error and stops safely | Pending |
| 3 | Passenger Counting AI | Set `MODEL_PATH` to a missing model file and run the script | Script shows a clear model file not found error and stops safely | Pending |
| 4 | Passenger Counting AI | Remove or rename Firebase credentials and run the script | Script processes the video but warns that Firestore upload is unavailable | Pending |
| 5 | Passenger Counting AI | Use a valid video with visible passengers | Bounding boxes are drawn, visible count updates, and cumulative passenger estimate increases logically | Pending |
| 6 | Passenger Counting AI | Use a video with no detectable passengers | Script finishes safely, logs no detections found, and final passenger count is `0` | Pending |
| 7 | Passenger Counting AI | Use a corrupted video or a video that cannot be opened | Script shows a clear error that the video cannot be opened and exits safely | Pending |
| 8 | Passenger Counting AI | Use a video file that opens but returns no readable frames | Script warns that no frames were processed and exits safely | Pending |
| 9 | Passenger Counting AI | Stop the AI demo early by pressing `q` during playback | Script stops safely, releases the video window, and keeps processed results without crashing | Pending |
| 10 | Passenger Counting AI | Complete video processing with valid Firebase connection | Final passenger count is written to `LIVE-STATUS` successfully | Pending |

## Revenue Dashboard

| # | Module | Input / Action | Expected Result | Status |
|---|--------|----------------|----------------|--------|
| 11 | Revenue Dashboard | Open the dashboard with the `Today` filter selected | Dashboard shows today summary mode with benchmark context and does not show a misleading hourly chart | Pending |
| 12 | Revenue Dashboard | Select `Last 7 Days` filter | Dashboard loads 7-day KPIs, trend chart, break-even chart, and trip ledger for real data in that period | Pending |
| 13 | Revenue Dashboard | Select `Last 30 Days` filter | Dashboard loads 30-day KPIs, trend chart, break-even chart, and trip ledger for real data in that period | Pending |
| 14 | Revenue Dashboard | Select a valid custom date range | Dashboard updates all summary cards, charts, and ledger using only data from the selected range | Pending |
| 15 | Revenue Dashboard | Select a custom range where start date is after end date | Backend normalizes the range safely and dashboard still loads valid results | Pending |
| 16 | Revenue Dashboard | Open the dashboard for a date range with no trip data | Dashboard shows safe empty-state values and does not crash | Pending |
| 17 | Revenue Dashboard | Open the dashboard for a low-data range with only 1–2 trips | Dashboard keeps benchmark context visible and avoids misleading or broken chart rendering | Pending |
| 18 | Revenue Dashboard | Simulate backend timeout or API failure while loading dashboard data | Dashboard shows an error state with retry option instead of crashing | Pending |
| 19 | Revenue Dashboard | Load trip data where AI passengers are `0` | Dashboard normalizes the record so tickets sold and revenue also become `0` | Pending |
| 20 | Revenue Dashboard | End a trip when `LIVE-STATUS` document is missing | Backend uses `ai_count = 0`, finalizes the trip safely, and dashboard remains stable | Pending |
| 21 | Revenue Dashboard | Load trip data with paid and unpaid passengers | Paid percentage and unpaid percentage are calculated correctly and sum to `100%` | Pending |
| 22 | Revenue Dashboard | Load trip data where AI passengers are greater than tickets sold | Leakage is calculated correctly as unpaid passengers and never becomes negative | Pending |
| 23 | Revenue Dashboard | Load trip data with revenue below the fixed cost of `4000` | Break-even logic shows the trip as a loss with correct profit/loss value | Pending |
| 24 | Revenue Dashboard | Load trip data with revenue near the fixed cost of `4000` | Break-even chart shows a near break-even state with correct color and tooltip values | Pending |
| 25 | Revenue Dashboard | Review the break-even chart for multiple empty trips | Empty trips are grouped cleanly and chart labels remain readable without repeated clutter | Pending |
| 26 | Revenue Dashboard | Review the trip ledger for mixed trip outcomes | Ledger shows separate columns for `Date & Type`, `Pax / Tkt`, `Profit/Loss`, and `Status` clearly | Pending |
| 27 | Revenue Dashboard | Review the trip ledger when multiple no-boarding trips exist | Ledger groups them into a single `No Boarding Trips (n)` style row instead of repeating many empty rows | Pending |
| 28 | Revenue Dashboard | Download CSV report for the selected range | CSV file downloads successfully with metadata, summary section, trend data, trip-level rows, and insights section | Pending |
| 29 | Revenue Dashboard | Download CSV report for an empty date range | CSV still downloads successfully with safe empty values and no crash | Pending |
| 30 | Revenue Dashboard | Review AI decision support and low-demand alert area with real trip data | Dashboard shows recommendation and alert output based on aggregated trip performance, not hardcoded text | Pending |
