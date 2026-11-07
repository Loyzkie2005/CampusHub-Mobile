# Seller Sales Overview: in-place period refresh

## 1. Cause / reason

Changing the sales period previously called `_load()`, which set `_loading=true` and replaced the seller section with a full loading/error state. That unmounted its content and could reset its controls and scroll position. A period change needs an analytics update, while pull-to-refresh, product/order actions and access rechecks still need the existing full workspace reload.

## 2. Files and code anchors

| File | Current line / anchor | Change |
| --- | --- | --- |
| `lib/module_app/screens/seller_dashboard_page.dart` | 92 `_load`, 157 `_changePeriod`, 165 `_readAnalytics`, 183 `_refreshSales` | Separate sales request/loading/error state; validate and merge analytics only; ignore stale responses and clear data on authorization failure. |
| `lib/module_app/screens/seller_workspace_content.dart` | 32 optional refresh properties, 1745 `_salesOverviewBanner`, 1824 `_salesRefreshFeedback` | Small loading indicator inside the existing banner; local error/retry. Keep the current full-width navy KPI, three normal-width order cards, white rounded period selector and section order. |
| `test/seller_sales_refresh_test.dart` | `period refresh preserves mounted Home`, full refresh and 401/403 cases | Delayed/out-of-order replies, retained state/data/scroll, local retry, full-refresh supersession and stale authorization denial. |
| `test/seller_sales_overview_test.dart` | real bearer transport workflow | Expect the banner to remain mounted during ordinary period loading/failure; preserve its successful caption. |
| Existing seller layout/workspace/Home tests | section order, selector geometry, Home pull-to-refresh | Retain the requested existing seller layout and interactions. |

## 3. Changes made

`_refreshSales(period)` uses separate `_salesLoading`, `_salesError` and request-generation state. It calls the existing authenticated workspace service without setting full-page `_loading`. Successful requests replace only `_data['analytics']`; all-time order counts, products, orders, recommendations, inventory and pagination remain the same objects/values. The existing content widget stays mounted.

The navy banner reserves a small indicator slot beside its title, so showing progress does not add a row or move the dashboard. It keeps the last successful amount and caption together. Ordinary failures add a small message/Retry inside Sales Overview; they do not replace the dashboard with an error page. The separate Sales Analytics view also shows the local refresh status. Normal trigger colors, radius, icons, spacing and menu behavior remain.

## 4. Functions, inputs/outputs and data flow

1. The checked period menu calls `_changePeriod('day' | '7' | 'month')`. The initial period remains Weekly (`7`). Duplicate requests for the same pending/successful choice are ignored; retrying a failed choice is allowed.
2. `_refreshSales` records a sales request number and the current full-load generation, then calls `SellerApplicationService.workspace(period, ordersPage)`.
3. That unchanged service sends the session bearer token to `GET /api/mobile/seller/workspace/`. Django continues authenticating the actual account, checking active approved seller access and scoping PostgreSQL orders to its owned products. Revenue remains the shared completed-and-paid calculation; no revenue is calculated in Flutter.
4. `_readAnalytics` checks the response period, label, finite nonnegative revenue and completed-order count. A response for an older request/full-refresh generation cannot overwrite the latest choice.
5. A successful response merges only analytics. The selector, amount, caption and trend receive that same validated map. During loading/failure, the selector's checked value and caption still describe the last successful figures, rather than attaching a new period name to old revenue. Retry uses the last requested period.
6. A 401/403 denial clears seller data/access, cancels both request generations and prevents a later reply from restoring data. This also applies to a denial from an older period request. Other network/server/validation failures remain local to Sales Overview.
7. `_load()` still performs full reloads. Starting it invalidates any pending sales-only request and clears its transient state. Existing Home pull-to-refresh continues to update the seller `refreshRevision`; relevant product/order actions continue calling their full reload callbacks.

Example: Weekly shows 70.00. The seller requests Daily, then Monthly. Weekly 70.00 stays labelled Weekly while the small progress indicator runs. If Monthly succeeds first, its amount/caption appear together. A late Daily success is ignored. If Monthly fails, Weekly figures remain and Retry requests Monthly again. Test amounts are isolated fixtures, never working database records.

## 5. Backend / API behavior

No new endpoint or service method. The existing workspace endpoint returns a complete payload; period-only operations deliberately consume only its analytics portion. Bearer authentication, seller ownership, order statuses, revenue timestamp rules and period parameters are unchanged. The service was inspected and reused without edits. A sales request relies on the endpoint's own authorization checks instead of adding a redundant access-status read; full reloads keep their existing access-status check.

## 6. Database / migration impact

None. No Django business logic, PostgreSQL schema, migrations, orders, payments or seller approvals changed. Tests use memory fixtures or mocked HTTP. This mobile fix contains no credentials, live tokens or customer record exports.

## 7. Verification

The working tree passed **74 Flutter tests** across:

```powershell
flutter test --no-pub test/seller_home_layout_test.dart test/seller_workspace_test.dart test/seller_home_entry_test.dart test/seller_sales_overview_test.dart test/seller_sales_refresh_test.dart --reporter expanded
flutter analyze --no-pub
```

Coverage includes period requests/amounts/captions, bearer transport, retained Home widget identity, unchanged scroll offset and non-analytics data, all visible sections, delayed/out-of-order selection, ordinary failure/retry, initial malformed data, full refresh, existing pull-to-refresh, and 401/403 data clearing. The pending indicator is explicitly asserted to be inside the still-mounted KPI banner. Formatting/whitespace checks passed. The exact staged snapshot was additionally copied onto a clean detached Git worktree without unrelated working-tree edits: **all 74 tests passed in 22 seconds**, and whole-app analysis reported **No issues found** in 13.6 seconds. These checks verify the files selected for the commit, not merely the dirty development checkout.

## 8. Limitations, troubleshooting and safe practice

The workspace API still performs its normal complete read; this fix reduces UI replacement rather than introducing a smaller backend endpoint. The Sales Trend stays mounted and receives the refreshed analytics trend. A full refresh or authorization failure can still replace the entire seller section intentionally. Error text may add a small footer to the KPI; it does not reset the scroll controller. No installed-phone or live network test is claimed.

If changing the period still blanks the seller section, confirm the running build includes `_changePeriod → _refreshSales` and reload the Flutter app. Check that its local indicator is inside the banner and that normal errors do not set `_error`/`_loading`. Authentication denials must still clear the data. Do not remove request guards to make a delayed test pass.

Safe practice exercise: run the focused refresh tests, add a temporary delay to the test service's Daily response, request Daily then Monthly, and complete Monthly first. Verify Monthly survives the late Daily response. Restore the test change and rerun. For manual checking, use an existing approved account, note the current scroll position/figures, switch periods quickly, and inspect local retry after a network failure. Do not mark orders paid or change seller approval merely to populate this UI.
