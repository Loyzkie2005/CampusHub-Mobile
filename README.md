# CampusHub Flutter mobile app

The mobile client for CampusHub at USTP Oroquieta. It uses the existing Django APIs for marketplace, seller access, orders, bookings, services and accounts. FastAPI is used for chat only.

Start with the [whole-project overview](https://github.com/Loyzkie2005/Campushub/blob/main/docs/campushub-system-overview.md), [engineering rules](https://github.com/Loyzkie2005/Campushub/blob/main/AGENTS.md) and [latest project context](https://github.com/Loyzkie2005/Campushub/blob/main/CAMPUSHUB_CONTEXT.md). This README describes source organization; use the existing deployment and feature guides for environment-specific configuration.

## Entry points and source structure

| Location | Responsibility |
| --- | --- |
| `lib/main.dart` | Normal application startup, existing cart/theme loading and post-frame push startup |
| `lib/module_app/routes/` | Existing routes and profile/onboarding destination selection |
| `lib/module_app/screens/` | Screen composition, state and interaction |
| `lib/module_app/widgets/` | Shared Home, navigation, profile, seller and other components |
| `lib/module_app/services/` | HTTP/device/application service clients; backend business rules remain in Django |
| `lib/module_app/models/` | Parse API records into mobile presentation models |
| `lib/module_app/session/` | Existing session persistence and restoration |
| `lib/module_app/theme/` | Shared colors/typography helpers, including scoped Inter styles |
| `assets/` | Bundled fonts, licenses and images |
| `test/` | Isolated regression fixtures, widget tests and render harnesses |
| `tool/qa/` | Optional development previews; these do not replace normal startup |
| `android/`, `ios/`, other platform folders | Native platform integration |

`main()` initializes the real app. `AppRoutes.forUser(user)` reads profile/onboarding state and returns its existing destination. `ProductService.fetchApproved()` reads the configured Django catalog, parses ProductItem records and reports actual loading errors. The shared Home displays those records; it does not fabricate products or determine backend visibility.

## Current design and Home structure

Home/navigation use bundled Inter: headings 600, menu labels 500, KPI numbers 700 and descriptions 400. Root/default UI remains Poppins; the CampusHub wordmark is SugarPie and profile identity remains Montserrat. Read the [current typography guide](https://github.com/Loyzkie2005/Campushub/blob/main/docs/mobile-typography.md) and [mobile design reference](DESIGN.md) before changing fonts or layouts.

Approved sellers retain shared Home and see welcome/banner, KPI cards, Suggested Product Bundles directly below KPIs, Recent Orders, Inventory Attention, Sales Trend, then the Marketplace/Facilities/Services previews. Existing seller access, sidebar destinations, regular-user navigation and backend authorization remain authoritative. See the [seller guide](https://github.com/Loyzkie2005/Campushub/blob/main/docs/mobile-seller-application.md).

## Development verification

Run from this Flutter package directory using the installed project-compatible SDK. Read the relevant feature guide for its exact targeted tests and setup. Common read/check commands are:

```powershell
flutter analyze
flutter test --no-pub test/home_page_test.dart test/seller_home_layout_test.dart
```

These commands are examples, not results from this documentation update. Tests use their existing isolated fixtures. Adding font assets requires rebuilding/relaunching the normal app to load its manifest; do not replace `lib/main.dart` with a QA target to bypass login. Use the device selected in your normal IDE workflow. Django and chat have separate server addresses/configuration; see the [project overview](https://github.com/Loyzkie2005/Campushub/blob/main/docs/campushub-system-overview.md#applications-and-architecture) and [chat setup](https://github.com/Loyzkie2005/Campushub/blob/main/backend/chat_service/README.md).

Safe learning exercise: open `ProductService.fetchApproved`, identify `/api/products/approved/`, then find its `core/urls.py` route and `approved_products` handler. Verify that the JSON `products` list becomes ProductItem records before it reaches a card. This traces a read path without editing accounts, API addresses or database records. For failures, distinguish API connection errors from authentication/authorization and from empty data; use the [product-loading guide](https://github.com/Loyzkie2005/Campushub/blob/main/docs/mobile-product-loading.md) rather than inserting sample records.
