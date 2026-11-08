# Mobile Seller Recent Orders

## 1. Cause / reason

The requested product-focused summary replaces the earlier reduced Recent Orders card, which deliberately hid purchased products and offered an outlined View Details button. The existing API already supplied a first-product preview and fulfillment/payment fields, so it was reused. Two details gaps were confirmed: individual item images were omitted from the mobile detail response, and the Flutter detail page inferred Cash on Pickup even for legacy orders without a recorded receiving method. Authorization errors during fulfillment also left the old detail page open.

## 2. Exact files and anchors

Paths below beginning with `backend/` are relative to the parent CampusHub backend repository; Flutter paths are relative to this mobile repository.

| File | Current line / anchor | Change |
| --- | --- | --- |
| `lib/module_app/widgets/seller/seller_recent_orders.dart` | 15 empty title, 69 status fallback, 209 `_height`, 320 `_productSummary`, 392 `_metadata`, 559 FilledButton | Product-focused card, image/fallback, quantity, receiving method, extra-item count, explicitly labelled order total, payment/date, full-width action and scaled-height calculation. |
| `lib/module_app/screens/seller_workspace_content.dart` | 366 authorization failure; 1254 image/fallback; 1282 `_showOrderDetails`; 1294–1334 recorded values | Keep the existing detail route, use actual customer/payment/receiving data, show item images/fallbacks and creation date, and recheck access on denied fulfillment. |
| `backend/core/modules/marketplace/services/mobile_order_previews.py` | 30 `item_thumbnail`, 50 `product_preview` | Reuse image normalization for the first preview and each purchased item; never give later items the first item's photo. |
| `backend/core/modules/marketplace/mobile_seller_views.py` | 125 `serialize_order_row`, 128 `thumbnail_url` | Add an optional string thumbnail field to existing serialized item rows. No new endpoint. |
| `test/seller_recent_orders_test.dart` | 84 authorization cases, 128 responsive summary cases, 212 successful fulfillment, 308 ordinary error | New focused card/detail/workflow checks. |
| `test/seller_home_layout_test.dart` | 138 summary, 196 legacy fallback, 230 details, 400 badges and later carousel/responsive cases | Update existing tests for visible product information, full action label, neutral status colors and honest empty text. |
| `test/seller_workspace_test.dart` | existing Orders Received detail exercise | Do not expect an invented Cash on Pickup value from an unclassified legacy fixture. |
| `backend/core/api/test_mobile_seller_workspace.py` | 347 item-image helpers, 368 detail contract | Verify recorded item images, variants, subtotal, payment and receiving data. |
| `backend/core/modules/marketplace/test_order_fulfillment.py` | 189 workspace refresh after each transition | Confirm subsequent API reads report updated order status while payment remains Unpaid. |

## 3. UI and interaction changes

Each card keeps its existing customer/reference header and status badge. It now adds a real product thumbnail or the existing `ProductImage` fallback, purchased name, quantity, receiving method and `+N more items` where applicable. Order Total is explicitly labelled; it always uses the stored whole-order total rather than presenting the total as the first item's price. Payment Status and Order Date form a separate row. The full-width navy View Order Details action opens the existing detail route.

Use existing identity typography, navy/white/gold, subtle borders, 12px card/button corners and restrained dividers. Completed/Cancelled badges use neutral navy text rather than green/red fills; their actual status words remain. Keep pending/processing/ready distinctions and supported Seller Delivery labels. No fulfillment/payment buttons were added to the summary.

The existing carousel remains limited to the newest five supplied records. Swipes and dot buttons stay synchronized. Its ID-based selection retention still handles reordering, shrinkage and empty refreshes. `_height()` measures the same rendered regions for every supplied page and chooses the tallest, keeping one carousel height without cropping scaled content. Wider cards place the labelled total beside product information; narrow/enlarged layouts place it below. Customer/product names retain bounded wrapping with full values available in details.

No recent orders yet is the honest empty title. Workspace-level loading/error/Retry and existing pull-to-refresh remain responsible for fetching the complete workspace. Product image loading/failure uses the existing image component, including its missing-image fallback. There is no duplicate Recent Orders API call or fabricated preview data.

## 4. Data flow, functions, inputs and outputs

1. PostgreSQL stores order/customer/item snapshots, total, status/payment values, timestamps and receiving fields. Existing `seller_order_queryset(account)` in `services/order_access.py` filters the primary product to the authenticated owner and preserves the exclusion of ambiguous legacy mixed-item records.
2. The existing bearer-authenticated `workspace()` verifies an active approved, non-suspended seller. It reads recent orders in `-created_at, -pk` order independently of the paginated full Orders list. `buyer_full_names()` resolves supported buyer identities in batch without treating a username as a verified full name.
3. `order_items(order)` remains the canonical snapshot reader for product names, variants, quantities and subtotals. The mobile adapter adds `thumbnail_url` using `item_thumbnail(order, index)`. This helper prefers that item's saved image, uses the order/current primary product fallback only for the first item, handles existing list/JSON image formats, and returns an empty string for a missing later image. Bundle previews remain the purchased bundle, not its ingredients.
4. The unchanged `SellerApplicationService.workspace()` sends the session bearer token and reads the existing JSON. `homeRecentOrders` supplies `recent_orders`, falling back to the existing first order page for older API payloads. No new price or authorization calculation exists in Flutter.
5. `SellerRecentOrders` reads first-item preview fields, compatible item snapshots and stored `total`. Known `pickup` becomes Customer Pickup; known `seller_delivery` becomes Seller Delivery. Unknown methods stay unrecorded. The callback receives the exact selected order map, not the first carousel row.
6. `onDetails` still calls `_showOrderDetails(context, row, fullProductDetails: true)`. This opens the same `ProfileDetailScaffold` with the customer's full recorded name, reference/status/payment/receiving fields, date, destination or pickup location, all purchased items/images/fallbacks, variants, quantities, subtotals, total and existing eligible action.
7. Opening/closing details performs **no refresh**. An action still uses the existing confirmation dialog and `orderProgress(id, action)` callback/API. Only a confirmed successful action closes details and requests the existing full workspace refresh; the next open uses the refreshed row. Ordinary conflicts/errors leave details open with the existing error message. A 401/403 closes stale details and invokes the normal access-checking refresh so unauthorized seller data is cleared.

Annotated example: a snapshot contains First Product, quantity 1, subtotal 20.00, plus Second Product with subtotal 105.50. The card shows First Product, Quantity: 1, +1 more item and **Order Total 125.50**. Details still shows both individual subtotals/variants. It never labels 125.50 as First Product's unit price. These example values belong to isolated UI fixtures only.

## 5. Backend / API behavior

The existing `/api/mobile/seller/workspace/` response gains only `items[].thumbnail_url`. Existing clients can ignore the extra field. First-product preview behavior, account scoping, ordering, paging, receiving/payment presentation, order statuses and fulfillment rules remain.

`/api/mobile/seller/orders/<id>/progress/` still uses the approved-owner boundary and shared locked fulfillment transitions. Processing/readiness/delivery progress does not record Paid or Completed. Existing payment recording remains separate; no payment action or payment API was introduced. A foreign order remains inaccessible. Existing ambiguous multi-item legacy orders remain excluded by the backend scope; the UI handles multi-item snapshots without broadening authorization rules.

## 6. Database / migration impact

No table, model, migration, inventory rule or working order/payment changes. The new API field is a read-only projection from already stored images. Django tests run on disposable PostgreSQL records. A separate `SET TRANSACTION READ ONLY` check called the existing authenticated workspace view for an actual approved seller: its two recent orders matched owner scope, newest-first ordering, stored amounts/status/payment and the new item-image contract. No identities or bearer token were printed/saved by that check. It performed zero writes.

## 7. Verification

- **83 Flutter tests passed** across the six seller layout, workspace, Home entry, sales transport, in-place sales refresh and new Recent Orders suites. New cases cover 280dp/normal, 320dp/2x, 390dp and 600dp/1.3x; exact customer/reference/status/product/quantity/receiving/total/payment/date; missing photos; multi-item totals; dot/selected-order navigation; no summary fulfillment controls; existing details; no reload on opening; successful action/reopen with updated status; ordinary action error; and 401/403 access rechecks. Existing See All, carousel shrink/reorder, empty/loading/error/Retry, responsive and nonblocking sales cases remain green.
- **32 Django tests passed** across `api.test_mobile_seller_workspace` and `modules.marketplace.test_order_fulfillment`; no system-check issues. Cover owner isolation, latest order list across pages, historical names/images, image normalization, per-item image attribution, variants/quantities/subtotals, query growth, authentication/approval/suspension, forbidden foreign access/payment actions and actual fulfillment transitions. After each transition, a workspace read verifies the new status and Unpaid payment state.
- Whole-app `flutter analyze --no-pub`: **No issues found**, 13.7s. Dart formatting and scoped whitespace checks passed. Inspected the actual normal card render; existing responsive/light/dark-surroundings test renders were regenerated. No accessibility score or physical-device test is claimed.

Root-project evidence: `scratch/seller-recent-orders-20261107/` contains `final-flutter-tests.log`, `final-analyze.log`, `backend-tests.log`, render PNGs and `read-only-result.json`. Rendered fixture records are not working database inserts.

Reproduce Flutter checks from this repository:

```powershell
flutter test --no-pub test/seller_home_layout_test.dart test/seller_workspace_test.dart test/seller_home_entry_test.dart test/seller_sales_overview_test.dart test/seller_sales_refresh_test.dart test/seller_recent_orders_test.dart --reporter expanded
flutter analyze --no-pub
```

Backend checks from the parent project use the session's existing disposable PostgreSQL runner:

```powershell
backend/core/venv/Scripts/python.exe -B scratch/schedule-policy-20261105/run_tests.py api.test_mobile_seller_workspace modules.marketplace.test_order_fulfillment
```

## 8. Limitations, troubleshooting and safe practice

No APK build/install or live fulfillment/payment operation was performed. Older backend deployments without `items[].thumbnail_url` retain the existing first-item image fallback; deploy the compatible backend projection to supply every recorded item image. Missing historical images cannot be recreated and show the existing fallback. Full product/customer strings remain available in details when the compact summary wraps/ellipsizes them.

Opening details uses the current workspace snapshot without an extra network request. Successful updates invoke the existing reload; an external change becomes visible after normal refresh. Genuine order updates still use the full reload because counts, inventory and sales may also need refreshing. Ordinary fulfillment errors do not imply success or change payment; authentication denials recheck access. These are deliberate continuations of the existing workflow, not a new details/payment implementation.

If a card has the wrong image, inspect its saved `product_preview.thumbnail_url` and `items[].thumbnail_url` before editing a current product image. If a total seems high for the previewed product, check +N more items and the Order Total label, then inspect the stored subtotals in details. Do not multiply current product price by quantity to reconstruct historical charges. If a legacy receiving method is unknown, leave it unrecorded rather than selecting Pickup automatically.

Safe practice exercise: run the new focused test suite, change only a test fixture's first item name/quantity and second item's subtotal, and confirm the summary still labels the whole amount Order Total while details keeps both items. Revert the fixture and rerun. For a safe manual review, inspect existing orders, swipe dots, open details and return without confirming a status/payment action. Never create paid orders, modify stock or approve a seller merely to populate a screenshot.
