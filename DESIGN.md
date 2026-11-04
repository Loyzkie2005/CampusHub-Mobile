---
name: CampusHub Mobile Discovery
description: Scoped visual system for the Flutter shared header, regular-user Home and floating bottom navigation with accessible selection feedback.
colors:
  navy: "#1A1851"
  gold: "#FCB315"
  white: "#FFFFFF"
  light: "#FFFFFF"
  image-surface: "#FFFFFF"
  marketplace-card-surface: "#FFFFFF"
  marketplace-image-surface: "#FFFFFF"
  muted: "#475569"
  metadata: "#64748B"
  line: "#E2E8F0"
  booking-muted: "#66687A"
  booking-outline: "#E2E4EC"
  booking-surface-light: "#F8FAFC"
typography:
  brand:
    fontFamily: "SugarPie"
    fontSize: "24sp"
    fontWeight: 400
  greeting:
    fontFamily: "Inter"
    fontSize: "15sp"
    fontWeight: 600
    lineHeight: 1.25
  section:
    fontFamily: "Inter"
    fontSize: "19sp"
    fontWeight: 600
  body:
    fontFamily: "Inter"
    fontSize: "14sp"
    fontWeight: 400
  metadata:
    fontFamily: "Inter"
    fontSize: "12sp"
    fontWeight: 400
  navigation:
    fontFamily: "Inter"
    fontSize: "11sp"
    fontWeight: 500
    lineHeight: 1.15
    letterSpacing: "-0.1sp"
  identity:
    fontFamily: "Montserrat"
    fontSize: "13sp"
    fontWeight: 600
  facility-detail-section:
    fontFamily: "Montserrat"
    fontSize: "16sp"
    fontWeight: 600
    lineHeight: 1.45
  facility-detail-body:
    fontFamily: "Montserrat"
    fontSize: "14sp"
    fontWeight: 400
    lineHeight: 1.45
  facility-detail-value:
    fontFamily: "Montserrat"
    fontSize: "13sp"
    fontWeight: 500
    lineHeight: 1.45
rounded:
  field-row: "12dp"
  catalog-card: "14dp"
spacing:
  inline: "4dp"
  small: "8dp"
  card-gap: "12dp"
  row: "16dp"
  page: "20dp"
  section: "24dp"
components:
  facility-detail-action:
    backgroundColor: "{colors.navy}"
    textColor: "{colors.white}"
    rounded: "{rounded.field-row}"
    padding: "14dp vertical, 16dp horizontal"
    height: "52dp minimum; grows with scaled text"
  facility-gallery-action:
    backgroundColor: "#F5F6FA"
    textColor: "{colors.navy}"
    rounded: "circle"
    size: "48dp minimum"
  product-details:
    purpose: "Existing marketplace product detail route; actual Django product/options"
    surface: "Current October30 reference-layout follow-up: flat white information, navy #1A1851 type/icons, scoped gold #FCB316 Buy Now, neutral #F4F4F8 gallery and #667085 metadata; no summary gradient/container or seller/review cards.620dp reading width with20dp gutters. All existing information retained."
    header: "Titleless gallery header; stemless22dp chevron Back; matching borderless #EEF0F3 gray48dp circles for Back/Cart/Favorite, including selected Favorite. Navy outline/filled heart still conveys saved state. White collapsed toolbar; original actions retained."
    gallery: "Compact neutral photo stage: shared _ProductHeroImage.heightFor uses width clamped240..320dp plus48dp below-photo pagination for2+ images or16dp spacing for a single photo. BoxFit.contain preserves the whole upload. Centered dots retain48dp targets and original swipe/page/reduced-motion callbacks."
    typography: "Poppins UI; navy product name20sp/600 and price20sp/700 with existing Roboto peso glyph, section16sp/600, description14sp, metadata12sp."
    heading: "_ProductHeading: conditional badge+name left, price right, then saved category, working48dp review summary and actual sold count. LayoutBuilder/TextPainter stack price below name if width<260dp, scaled20sp>28dp or price consumes>38% of width.24dp section rhythm."
    reviews: "Flat Ratings & Reviews section retains actual supplied aggregate or honest No reviews yet; header review jump remains. Gold fractional actual-rating stars, muted navy-neutral unrated outlines."
    related-products: "Existing140dp white related cards; native48dp Favorite controls and scaler-aware list height preserve readability. Existing product-navigation/favorite services."
    badge: "Pale gold/navy badge left of product name: New only for saved submission within7days, Hot only for positive supplied soldCount; eligibility unchanged."
    description: "Always-visible full saved description; flat seller row with44dp saved photo/fallback, wrapping name, flexible Online/Offline and original chat chevron. Conditional expiry/unavailability and all recommendation information retained."
    choices: "Phone groups each use a full-width row; two groups split only when content>=600dp and scaled13sp<=18dp.48dp real-color targets; text options use white outlined StadiumBorder pills, solid navy/white when selected, native selected semantics. Exact saved options/payloads preserved."
    empty-variants: "Hide the entire option area when saved enabled options are absent; no heading, empty message, samples or forced size/color values"
    purchase: "Inline selection; no quantity sheet/stepper; existing cart/checkout receive quantity 1 and actual selected price/payload"
    actions: "White SafeArea footer,620dp max: all three existing Chat | Add to Cart | gold/navy Buy Now actions,52dp minimum pill-shaped Buy Now. Large-text two-row fallback and original loading/added/disabled callbacks/guards retained."
    data: "Existing ProductItem/ProductCustomizationConfig and Django customization_options; serializer adds seller_photo_url from actual owner.profile_photo when present; no new endpoint/controller/schema"
  seller-my-products:
    purpose: "Owned seller product management; UI-only refinement, no sample data"
    header: "Existing white CampusHub header; local Search icon toggles to X; fixed Back/My Products/Add row"
    search: "Initially hidden; autofocus Search my products; X clears/collapses; existing local workspace query"
    filters: "All, Single, Bundles, Pending, Approved, Rejected, Archived; compact scrollable chips; navy/white selected state"
    row: "White with thin outline, 12dp radius/padding, 76dp product image, name/category/type/status, price and stock"
    typography: "Poppins; 18sp section title,14sp product name,12sp metadata and stock,13sp price"
    actions: "Add popup: existing single-product form or bundle-suggestions flow; vertical dots: existing details/inventory"
    data: "Existing owner-scoped workspace serializer; no new endpoint/model/controller or production fixtures"
  campus-home-banner:
    placement: "Directly below Welcome, above seller sections and catalogs"
    photo: "assets/img/ustp_oroquieta_entrance.png; user-supplied campus entrance"
    backgroundColor: "{colors.navy}; solid 78% navy tint over photo, no gradient"
    textColor: "{colors.white}"
    actionColor: "Gold to soft gold gradient (gold/white blend); navy text; explicit user exception"
    typography: "Inter; 18sp/600 title,12sp/400 description,12sp/500 action"
    rounded: "14dp"
    padding: "16dp"
    playback: "5-second automatic horizontal swipe; 450ms easeInOutCubic; centered dots, no arrow/play buttons"
    layout: "Measure tallest scaled text; add24dp photo space, minimum188dp; lower-left compact button with48dp target"
    interaction: "Manual banner swipe; retained tab callbacks; stop in background/inactive Home and for reduced motion; accessible pause action"
  seller-sales-period:
    placement: "Right of Sales Overview"
    menu: "Open below the trigger with8dp gap; no initialValue centering; checked items retain current period and original callback"
    options: "Daily (today), Weekly (last 7 days, default), Monthly (this month)"
    appearance: "Selected text and chevron, white surface, navy text, thin outline, 48dp minimum height"
    data: "Existing authenticated workspace API and canonical Django period helper"
  search:
    backgroundColor: "{colors.white}"
    textColor: "{colors.navy}"
    typography: "{typography.body}"
    rounded: "pill (half-height end caps)"
    padding: "14dp horizontal, 10dp vertical"
    height: "48dp minimum; no adjacent Home filter button"
  catalog-card:
    backgroundColor: "{colors.white}"
    textColor: "{colors.navy}"
    rounded: "{rounded.catalog-card}"
  service-row:
    layout: "Facilities and Services use responsive ResourceCardGrid: full-width phone cards, two columns on wider layouts; Home retains wider horizontal previews. See resource-catalog-card."
    backgroundColor: "{colors.light}"
    textColor: "{colors.navy}"
    rounded: "{rounded.field-row}"
    padding: "16dp"
  resource-catalog-card:
    purpose: "Shared facility/service listing and Home preview; original detail routes and catalog data"
    surface: "White, 14dp radius, thin #E2E8F0 border, 10dp content padding, no internal dividers or heavy shadow"
    image: "4:3 AspectRatio, existing ProductImage URL/decoding/fallback, Stack overlays"
    reviews: "8dp top-left, compact navy pill, white Inter 11sp/500 text, #FCB316 star (explicit scoped exception); valid supplied rating 1..5 plus positive actual review count, otherwise No reviews yet"
    content: "Category, full name, configured capacity or saved service description, configured billing label, bottom-aligned 48dp minimum View Details"
    layout: "Image above details, full-width phone cards; two equal columns only at content width>=732dp (360dp minimum per card); natural equal row height. Home horizontal previews are320dp before existing text scaling/viewport clamp. Position restored after side-by-side experiment; final runtime checks pending command approval."
    location: "Saved location only, bottom-left of 4:3 image inset8dp, Material location icon, white Inter11sp text on94% navy, up to two preview lines with full tooltip/accessibility text; no duplicate body row"
    typography: "Existing bundled Inter, 14sp/600 name, 11-12sp/400 metadata, 13sp/600 rate; other app fonts unchanged"
    data: "Existing FacilityItem/ServiceItem; retain existing API display price labels, compatible configured analysis fees only for From pricing; no review aggregates currently supplied by APIs"
    favorite: "No new card favorite control; existing Facility Details local favorite behavior remains"
  cart-action:
    backgroundColor: "{colors.gold}"
    textColor: "{colors.navy}"
  bottom-navigation:
    backgroundColor: "{colors.white}"
    textColor: "{colors.navy}"
    typography: "{typography.navigation}"
    rounded: "28dp floating white dock; selected items have no background container"
    padding: "12dp side gaps,12dp below dock in addition to device safe bottom; centered max620dp"
    height: "68dp minimum content height, plus seller16dp action rise when applicable; Scaffold reserves full height"
    motion: "220ms easeOutCubic, 2dp icon lift, 1.08x selected scale, 140ms glyph crossfade; immediate with Reduce Motion"
---

# Design System: CampusHub Mobile Discovery

Current direction - October 29, 2026: pure white Facility Details information/page/footer; remove decorative navy/gold blur and frosted photo controls. Back/Favorite/photo arrows/counter use solid light gray #F5F6FA with navy icons and no gold edge. Chat text follows its icon in TextButton.icon; original callback and large-text separate-row fallback remain. Keep existing edge-to-edge sharp uploaded-photo carousel, section order, saved data, rate accordion, favorites and gold booking footer. Earlier blur/frame descriptions below are historical. No backend/API/schema/dependency/asset changes or app build/install/restart. Current measured verification, source anchors, functions/data flow and safe exercise: docs/mobile-services-navigation.md top.


## Facilities and Services card scope - October 29, 2026

The existing listing and Home preview cards share the `resource-catalog-card` specification above. The latest correction restores the image-above-details arrangement while retaining wider sizing, reviews at top-left and location at bottom-left. Current source anchors, data flow and pending runtime verification are in [the mobile services guide](../docs/mobile-services-navigation.md#restore-card-arrangement-and-retain-wider-sizing---october-29-2026); earlier reports retain the review-API limitation. Marketplace product cards, seller Home order/KPIs, existing main navigation and other screens are unchanged.

## Current accepted scope - November 2, 2026

This file describes component design and contains earlier implementation snapshots below. Current user instructions and the newest [project context](../CAMPUSHUB_CONTEXT.md) / [feature guide](../docs/mobile-seller-application.md) entries supersede conflicting historical text. See the [whole-project overview](../docs/campushub-system-overview.md) for planning, architecture and module ownership.

Latest seller Home details: Inventory Alerts uses Montserrat in its scoped header/cards, a14sp semibold product with SKU below, compact top-right Low Stock/Out of Stock pill,26sp/700 Available Stock beside16sp threshold, and13sp On Hand/Reserved in one light neutral row. Keep14dp padding/thin border/white surface and exact canonical values; low/out only, maximum3, same Inventory destination. Recent Orders is a compact summary only: actual full buyer name14sp/600 (two lines), smaller muted11sp `Order #<recorded code>` below, unchanged compact status at top-right, Order Total label with22sp/700 navy value, date/right-aligned payment, and View Details. Remove all product previews from the cards and their reserved height. Product name/quantity/recorded variant/photo belong behind the carousel detail action; other detail callers retain their defaults. Keep Montserrat, navy #1A1851, gold #FCB316 and white, manual carousel and centered dots inside the same bordered card below View Details; compact24x44dp dot controls with24dp between centers, no extra bottom padding with pagination,8dp only when there is no pagination. No backend stock/workflow or unrelated section changes. These current buyer-first summary/inside-footer rules supersede older product-preview/ID-first/top-dot descriptions below.

Home, promotional banners, preview cards, seller summary widgets and menu/tab labels use the bundled Inter family: headings 600, menu labels 500 even when selected, KPI numbers 700 and descriptions 400. Poppins remains the app-wide default elsewhere, SugarPie remains the CampusHub wordmark, and Montserrat remains profile identity. The [typography guide](../docs/mobile-typography.md) names the actual helpers/assets and verification.

Recent Orders is a scoped Montserrat exception: title16sp/600, subtitle12sp muted, buyer14sp/600, secondary labelled reference11sp, amount22sp/700 and metadata12sp; keep navy #1A1851/white and gold #FCB316 selected indicator. Its status badge is a text-sized pill with11dp horizontal/6dp vertical padding,999dp radius and11sp/600 label. Pending uses #FFF3D6/#8C5900, Processing/Ready for Pickup #EAF0FF/#24428A, Completed #EAF6EE/#21643C, Cancelled #FDECEC/#9F2D2D and unknown recorded labels neutral #F1F1F5/navy. These requested semantic colors apply only here. Keep the original status label; top-align the badge with the buyer identity, ellipsize long IDs to one line and loosely cap exceptional badge labels without Expanded/fixed width. Header See All stays right with flexible width. Use the subtitle Latest orders received from buyers.; newest five owner orders across all statuses; existing exact-order details and Orders Received route. Dots sit inside the same card below View Details and hide for zero/one; empty content is No Recent Orders plus New customer orders will appear here. This supersedes the historical open-only action preview and external/above-card dots without changing other sections.

Home has no saved-category shortcut chips; preference storage and Marketplace category filters remain. Buyer Home retains its promotional banner. Approved seller Home omits that banner/button/dots. Its existing photo and stacked Welcome Back, / full name open the drawer; there is no separate hamburger or greeting below the header. Keep Montserrat12sp muted caption/14sp semibold navy name, single-line name ellipsis, full-name spoken action, natural header height, SafeArea and minimum48dp targets. Search and Notifications stay right. The caption can wrap at large text. Other tabs and buyer Home retain their existing headers. Sales Overview with Weekly/four KPIs starts8dp below the header, followed by Recent Orders, Inventory Alerts, Suggested Product Bundles, existing Sales Trend, then Explore CampusHub (Marketplace, Facilities, Services). The existing manual order preview receives up to five newest real owner records across all statuses from Django, independent of full-list pagination and Sales dates. Shared preview strips keep their natural heights, bounded widths and126dp image areas. Full workflow/empty/error/route behavior remains in the seller guide.

Current source anchors are `HomePage.build`, `SellerWorkspaceContent.homeHighlights`, `InterTypography`, `CampusHubDrawer` and `FloatingBottomNavbar`. They receive existing state/data/callbacks and produce presentation; Django retains all authorization and business rules. Safe practice: compare a heading/label/KPI/description with the four styles in `seller_home_layout_test.dart` and run that existing test without changing any API data. This documentation correction changes no runtime component.

## Overview

**Creative North Star: "Compact campus discovery"**

The October 29 Facility Details refinement adds a route-scoped record of the incumbent mobile system. Its professional minimalist dossier puts the actual facility name and key facts before rental rates, with a viewport-wide gallery and a focused reading column. It is an Operate/code-led refinement, not a replacement identity or a rule for unrelated screens. Existing shared header, Home and navigation records retain their original scopes.

This document records the Flutter shared header, regular/seller Home discovery and existing bottom navigation. It is scoped to those surfaces, rather than every mobile screen or the Django web interface. Navigation reuses the bundled Iconsax symbols and existing selection feedback on an inset floating white dock. Real campus records carry the content, with navy structure and the existing mobile gold accent.

The shared header provides the existing dedicated Search action. Home begins with the actual user's greeting, then buyer promotional banners or the approved seller's Sales Overview. Seller sections precede the three existing horizontal catalog previews in the order recorded above. Existing imagery and honest fallbacks remain. [PRODUCT.md](../PRODUCT.md) supplies product goals; [the Home guide](../docs/mobile-services-navigation.md) and [seller guide](../docs/mobile-seller-application.md) record functions, data flow, verification and safe exercises.

**Key Characteristics:**

- White and light surfaces, navy information, restrained mobile gold.
- Compact scanning with explicit catalog headings and familiar Material interactions.
- Real records and distinct loading, error, empty, and no-match states.
- Scalable Home content and complete accessible action names.

## Colors

Facility Details uses opaque #FFFFFF page/footer/information, #1A1851 text, #F5F6FA controls/cards, #50596D supporting text, #E3E5ED card outlines and #FCB315 action. No decorative blur, frosted control or gold control edge.

The palette is institutional navy, mobile gold, and white/light, with navy-derived muted text and separators.

### Primary

- **Campus Navy** (`navy`): headings, readable content, icons, focus borders, and navigation selection.
- **Campus Gold** (`gold`): existing brand accents, approved selection highlights and active carousel indicators. Status always retains its recorded text; color does not establish availability or completion.

### Neutral

Current Home container treatment: white card/search/header surfaces on the light page; image/fallback areas use `image-surface`. Separate containers with `line`; resting card and search shadows are removed. Secondary text uses `muted`. Metadata uses `metadata` only on white/page, with measured contrast at least 4.5:1.

- **White** (`white`): header, catalog cards, bottom navigation, and favorite control.
- **Campus Light** (`light`): search field, service rows, catalog messages, and image fallbacks.
- **Muted Navy** (`muted`): seller names, descriptions, capacity, and secondary instructions.
- **Quiet Line** (`line`): card and search outlines.

**The Mobile Gold Rule.** This scoped Flutter system retains its mobile gold token; the web palette is maintained separately.

**The Honest State Rule.** A color or marker never supplies evidence of availability, popularity, unread counts, or completion. Use recorded text and actual state.

## Typography

Facility Details retains bundled Montserrat locally through _detailText, including variable weights and device scaling. Saved title and primary amount remain30sp/700, now navy; supporting labels remain12–13sp muted. The full saved price has one spoken label. No duplicate footer price. Scaled names wrap and Chat moves below the title above1.3x scale.

**Display Font:** bundled Sugar Pie for the shared header wordmark only; retain configured fonts elsewhere.
**Home/navigation font:** bundled Inter through InterTypography. Headings are 600, menus 500, KPI numbers 700 and descriptions 400. **Root/default font elsewhere:** bundled Poppins through AppTypography. Profile identity name/program/year-section retain Montserrat.

The header wordmark uses the supplied brush script at regular weight and natural spacing; the content hierarchy uses readable mixed-case labels. No display-sized hero text or invented eyebrow labels are needed on this Home surface.

### Hierarchy

- **Brand:** the regular SugarPie `brand` role; the header scales its wordmark down when horizontal space requires it.
- **Greeting:** the `greeting` role; actual first name with a generic welcome fallback.
- **Section:** the `section` role; Marketplace, Facilities, Services.
- **Titles:** Home product/service names use Inter14/600; facility names use Inter15/600. Existing product-detail page typography remains a separate component rule.
- **Body and metadata:** the `body` and `metadata` roles; longer supporting text uses comfortable line height and bounded previews.
- **Navigation:** Inter11/500 for selected and unselected labels; selection remains expressed through existing state/icon/color feedback.

**The Reading Space Rule.** Home text follows the device TextScaler. Card heights grow from scaled text measurements; section titles and actions share flexible width and wrap when necessary. Service cards gain width (up to 1.5x) with larger text to preserve their action labels. Only bottom destination labels use `TextScaler.noScaling`, matching the compact native Material navigation convention; full semantic names and scalable tooltips remain.

## Layout

Facility Details uses one continuous scroll: existing edge-to-edge sharp photo carousel, then white information bounded to620dp with20dp gutters. Original sections and safe fixed booking footer remain. Chat text follows its icon; large text places the action below the name.

Home marketplace cards show name, price, recorded category, relevant stock state and the plain seller name. Category has no badge; seller has no Seller: prefix. Missing data is not replaced with an invented seller. Preview strips use the tallest actual content at device text scale rather than a fixed guessed card height.

Flutter values in this file use logical pixels (`dp`) and text sizes (`sp`); they are not CSS measurements. Home currently uses16dp horizontal,8dp top and32dp bottom ListView padding; the smaller top inset raises the welcome below the shared header. Section blocks use the section spacing token; horizontal cards use the card-gap token.

The content is one vertically scrollable, refreshable page. Base card widths are176dp products,204dp facilities and196dp services; text scaling grows them up to1.5x within the available viewport. Each group uses126dp image areas and12dp gaps. All three groups preview at most six actual records and support manual horizontal scrolling. Dedicated Search retains its existing fetched-record filtering and detail routes.

The shared header retains its existing brand, Search, Notifications and profile/menu paths. Messages remains in its existing drawer/Profile access. Bottom navigation retains its role-aware destinations, Add Product action for approved sellers, SafeArea and existing touch targets. Visual labels remain compact while full semantic names/tooltips remain available. Font documentation does not authorize navigation changes.

## Elevation & Depth

Facility Details retains pale outlined rates and neutral amenity circles. Opaque white information and solid #F5F6FA controls are used in normal and high-contrast modes; no filters or colored control borders.

The scoped surfaces are flat at rest: no card or navigation shadow, no gradient, and no glass effect. White/light contrast, thin boundaries, image clipping, and spacing separate content. Native Material ink, focus, tooltip, and dialog behavior remain legitimate interaction materials.

**The Flat Surface Rule.** Keep resting catalog and navigation surfaces flat; preserve visible native feedback for interaction and focus.

## Shapes

Facility Details retains16dp card outlines,14dp booking corners,48dp controls,52dp amenity circles and56dp+ footer controls. Existing edge-to-edge gallery and8dp counter/24dp control clips remain.

Fields, service rows, and catalog messages share the gently rounded `field-row` shape. Product and facility cards use the slightly larger `catalog-card` shape and a thin quiet outline. Images clip within card boundaries. Circular favorite/cart actions remain recognizable Material icon controls; circular controls are not a general pill-container rule.

## Components

### Facility Details - pure white, gray controls and Chat, October 29, 2026

Current direction: remove colored blur and frosted control backing. Opaque white information/page/footer, neutral #F5F6FA photo controls with navy icons and no gold edge. Keep existing edge-to-edge uploaded-photo carousel, real count/up to five dots, 48dp targets, native swipe/arrow controls and local favorite. Chat text follows the icon in the original facility contact action; large text keeps its separate-row fallback. Preserve Montserrat, saved sections/rates,620dp content measure/20dp gutters and gold booking footer. No backend/API/schema/dependency/asset changes or app build/install/restart.

Verification:32/32 focused tests passed, two-file analysis clean,20 widget captures;390dp and320dp2x top inspected. Exact anchors, functions/data flow, troubleshooting and exercise: docs/mobile-services-navigation.md top.

## Shared floating bottom navigation — October 29, 2026

Operate: shared FloatingBottomNavbar only. Keep white/navy#1A1851, mobile gold#FCB315, Inter11/500 labels and bundled Iconsax/custom Home/Add artwork. The dock has12dp side gaps,620dp maximum width,28dp corners, neutral#E2E4EC outline and low-opacity navy shadow with6dp downward offset/20dp blur. SafeArea wraps the dock; an additional12dp bottom gap clears the system inset. Top padding8dp and seller rise16dp are reserved in layout. Scaffold.bottomNavigationBar keeps content clear; no Dashboard overlay/extendBody change.

Latest October30 follow-up removes the7% navy selected-background DecoratedBox entirely. The36x28dp layout slot, filled active glyph/navy color, restrained motion, native ink/focus, selected semantics, tooltips and reduced-motion behavior remain.4dp label padding preserves narrow-screen separation; existing label scale-down and full spoken names remain. Ordinary accounts keep five original destinations. Approved sellers keep four destinations plus the56dp gold action raised16dp, without changing role logic, destination indices or action routing. Current verification and learning guide: docs/mobile-profile.md, Navbar selection without a background box.

Sixteen focused tests passed4s including4 actual widget captures; two-file analysis clean3.2s, final format2files0changes and scoped whitespace check passed. Test widths320/390/768dp, seller landscape844dp,2x/3x text, reduced motion, safe area/body clearance, selection/semantics, action-vs-page behavior and narrow labels. Source anchors: floating_bottom_navbar.dart layout constants/_buildNavItem/_buildCenterActionButton/build; floating_bottom_navbar_test.dart. Full eight-part implementation/learning guide: docs/mobile-profile.md top, with a safe414dp fixture exercise. No app run/build/install/restart or native device actions; the user's Ctrl+F5 workflow stays in their control. No backend/API/permissions/database/records/dependency/asset changes. This supersedes the historical full-width/flush-edge navbar notes below.

## Historical implementation records

The records below preserve earlier decisions and may describe superseded fonts, layout, identity fields or navigation. Use the current accepted scope above, latest context and linked feature guides for the implemented design.

### Seller workspace drawer

Scoped to the existing SellerDashboardPage; regular Home and five-tab navigation remain separate. White scrollable drawer, width88% clamped to280–360dp, SafeArea,16dp horizontal inset and no elevation. Keep actual seller name, Program and Year/Section; no Approved Seller badge. AuthUser has no uploaded photo field; retain the existing default avatar. Final SETTINGS group contains only Account Settings, reusing existing Account & Security; no My Profile entry.

Use drawer-local Montserrat roles: seller name16sp/700/1.3, metadata12sp/1.4, Program12sp/600, section11sp/700/1.4 with0.8sp tracking, row/Back14sp/500/1.35 and selected row600. Secondary information uses72% navy and decorative lines12% navy on white; no unrelated gray accent. Keep outlined icons22dp, chevrons20dp and minimum52dp row height. Align section headings and Back with the row icon gutter; section spacing24dp above/8dp below. Selected rows use6% navy, a3dp Flutter gold #FCB315 left edge and selected semantics; no gradients or random status colors. Expand/wrap text instead of clipping at large font scales. Headings are OVERVIEW, PRODUCT MANAGEMENT, ORDER MANAGEMENT, RECOMMENDATIONS, REPORTS, SETTINGS; Back to CampusHub sits after a thin divider. Messages/Notifications belong in the seller header only. Decorative icons do not repeat visible labels to assistive technology.

Seller header: navy #1A1851, existing white/gold logo_dark, shared CampusHubBrand with white Campus/gold Hub and the same bundled SugarPie wordmark as regular Home. White outlined header actions, actual ChatService unread badge only when positive; no fake notification indicator. Keep destination title below the header in Montserrat20sp/700. Seller content background #F7F8FC and white flat cards. Home order: Sales Overview, Suggested Product Bundles, My Bundle Suggestions, Sales Trend, Inventory Attention, Recent Orders. Compact previews/See All reuse existing destinations/data; no technical Apriori metrics, global search or Quick Actions. The regular Home header and five-tab styling remain unchanged.

Seller content uses white, thin boundaries, compact rows and 48dp action targets. Overview has two columns with equal-height row cards, collapsing to one at large text. Inventory displays the server's actual variant rows/derived bundles. Loading, access denial, connection errors and genuine empty results remain distinct. No synthetic recommendation rows or visible research metrics. Existing Profile/Settings and Add Product components are reused. Implementation/data-flow/testing guide: `docs/mobile-seller-application.md` (from repository root).

Seller Home refinement: greet the actual first name, then Total Sales, Total Orders, Active Products and Pending Orders in the compact2-column grid. Only Total Sales follows the labeled sales period; orders/products/pending counts are current/all seller records. Product-pair cards use equal image/name columns separated by a plus icon, with View Suggestion and Create Bundle below. See All (with a trailing chevron icon, matching Home) opens existing seller destinations. My Bundle Suggestions contains actual owned bundle listings with normal Product review statuses, not saved pairs with invented approval. Sales Trend exposes the existing period filter and safe baseline. The dedicated seller route's drawer has the accessible name Seller navigation; regular Home and its five tabs remain separate. Recipe editor uses the existing Montserrat form style, real categories/variant choices and required quantities; never show a standalone bundle stock/threshold input.

### Buttons

Actions are concise and familiar: navy text for See All and Retry, a white favorite icon control, and a gold cart icon control. Preserve each action's tooltip, disabled state, native focus/ink feedback, and existing business action. A disabled cart control uses light/muted treatment when a product cannot be purchased.

### Cards / Containers

Product cards combine an actual image or honest fallback, favorite action, name, seller, price, and cart action. The compact Home variant uses the catalog-card shape and flat outline. It reuses the existing favorite, cart, and product-detail methods. Do not inherit the separate legacy product-card decoration into this scoped Home pattern.

Facility cards use the same flat outlined form, a larger horizontal width, actual imagery, name, recorded capacity where present, recorded status, a small gold marker, and an arrow. `capacity_label` takes precedence; a positive numeric capacity is the fallback. A marker does not promise that a time slot is free. Tapping opens the existing facility detail route.

Service rows are light rounded surfaces with an existing facility-type icon, name, description/category fallback, and chevron. They show active catalog services and open real service details. The existing details action says **How to Request This Service** and explains the type-specific requirements/contact guidance; it is not an online intake form.

### Inputs / Fields

The single labeled Home search uses a light fill, quiet outline, navy search icon/cursor, and navy focus border. The clear action appears only with input. Search matches fetched product names/sellers/categories, facility names/types/locations, and service names/categories/descriptions without creating sample results. Its field label remains visible above the hint.

### Navigation

The shared header provides drawer access and an outlined Notifications bell, inset by an additional12dp from the right. Messages remains available through the drawer and Profile. Notifications opens an honest explanation that mobile notifications are not yet available; there is no fabricated badge or feed.

The bottom destinations remain **Home, Marketplace, Services, Facilities, Profile**, in that order. The compact-label correction changes label scaling only. Incumbent icon artwork and selection styling in `floating_bottom_navbar.dart` are outside this redesign; this document does not freeze either into a future visual rule. Every destination exposes its full name and selected state through one semantics node, a tooltip, and a full-height tappable region. Existing Navigator, PageController, and retained-tab behavior remain the interaction model. There is no visible center add action on this configuration.

### Catalog feedback

Each catalog owns its loading indicator, error with Retry, empty message, and no-match message. One failed catalog does not hide the others. Pull-to-refresh reloads real catalogs while retaining search input. Feedback uses the same quiet surfaces and typography as content.

## Do's and Don'ts

### Do:

- **Do** keep Facility Details facts before rates, its photo viewport-wide, and its dossier/footer contents bounded; preserve scaled text and native actions.

- **Do** keep this document scoped to the shared header, regular-user Home discovery, and current bottom navigation.
- **Do** use real names, imagery, prices, capacity, status, and unread counts, with explicit fallbacks when records are missing.
- **Do** preserve scalable Home content, full accessible action names, visible focus feedback, and native Material tooltips.
- **Do** reuse the current routes, retained tabs, image helpers, favorite/cart methods, and catalog models.

### Don't:

- **Don't** invent facility reviews, imagery, maps, prices, availability or billing support, or turn this route's single-rate-panel composition into an app-wide rule.

- **Don't** add a promotional carousel, oversized hero, fake Hot/New labels, or seller/admin analytics to this Home surface.
- **Don't** introduce extra badge colors, gradients, glass, or resting card/navigation shadows into these scoped surfaces.
- **Don't** interpret Open for Booking as evidence that every schedule is free, or service guidance as online request submission.
- **Don't** turn the bottom-label scaling exception into a rule that prevents Home content from scaling.


### Dedicated Search

Home retains its white surface and compact48dp-minimum pill search entry below the greeting, with no Home filter button. Tapping pushes SearchPage with Back and an automatically focused input; the shared CampusHub header contains no search field. SearchPage uses white behind white product cards and compact suggestion rows, navy text, gold selected category filters and bundled Montserrat styling. Empty input shows history-based Recommended for You only when qualified results remain in the current public catalog; otherwise Recently Added Products, sorted by saved submitted_at, plus Explore Available Products. There is no Popular Searches section without real popularity data. Typing replaces discovery with query matches; submitting exposes All/Products/Facilities/Services results. See the dedicated Search section in the feature guide for data flow and limitations.


### Approved seller Home selection

The existing dashboard root chooses the existing SellerDashboardPage/SellerDrawer for approved seller access, using Django's boolean rather than account type. Seller Home has its own navy brand header and six sales sections; no regular five-tab navigation. Other accounts keep regular Home and menu. Profile retains Apply to Sell for non-approved users, with status subtitle, and has no seller-management destination. Back to CampusHub is an explicit public-browsing mode without logout; Home/regular drawer Seller Dashboard returns approved users to seller Home. Startup/resume access checks have loading/error/retry and never invent approval. Current gold is #FCB315. No new navigation framework or screen design.


### Correction: one shared Home, seller additions only

Supersedes the earlier approved-seller root-page replacement. Everyone retains the same normal white header, greeting/search, Marketplace/Facilities/Services and five-tab navbar. Approved sellers get compact Sales Overview and Suggested Product Bundles between Search and Marketplace. Render existing seller workspace data inline as a Column inside Home's scroll; no new initial page, nested Scaffold or seller header replaces regular Home. Existing seller tools are explicit module navigation from the drawer/See All; Profile has no seller-dashboard shortcut. Gold remains #FCB315.


### White header / Sugar Pie correction

Shared Home and existing seller module headers are white with navy icons. CampusHubBrand uses the existing bundled SugarPie24/w400 wordmark, navy Campus and #FCB315 Hub. Regular labels retain existing Montserrat/system typography. Seller Home remains inline additions on regular Home with the same five-tab navigation; this header-only correction must not create another initial page or change drawer structure.


### Poppins mobile UI and sharp drawer

Current mobile UI uses bundled Poppins weights400/500/600/700/800/900 for labels, forms, cards, navigation and seller tools. AppTypography replaces runtime GoogleFonts requests; all six faces ship offline. CampusHub header retains SugarPie. Profile identity name/program/year-section and seller drawer identity retain Montserrat. Drawer is an opaque white surface (light) or campus navy (dark), no blur filter or translucent surface. Menu Poppins14/500 (selected600), section11/700 with0.6tracking, 52dp minimum growing rows,22dp outline icons, readable navy-derived secondary text and consistent gutter. Full identity text can wrap at large font settings; retain all existing menu labels/actions/RBAC. No business, backend or regular five-tab navigation changes.

### Seller navigation hierarchy and header profile

Current header right-side order is Notifications then a34dp initials/default avatar inside a48dp Profile action; Messages moves into Communication in the approved seller drawer with its existing real unread count. Keep the white SugarPie header. Drawer identity is full-width name (Montserrat17/700), program/year-section (Montserrat12/500), saved email (Poppins12),24dp lower spacing and a thin divider. No duplicate drawer avatar. Six groups: Overview/Dashboard; Seller Management/My Products/Inventory/My Bundles/Orders; Recommendations/Suggested Product Bundles/My Bundle Suggestions; Reports/Sales Analytics; Communication/Messages; Settings/Account Settings. Section padding20dp top/8dp bottom, consistent52dp growing navigation rows and gold selected edge. Dashboard returns shared Home; Profile opens existing tab4. No new seller root, account system or bottom-navigation changes. Account API currently has no photo URL; keep initials fallback until a real field exists. Implementation/functions/verification guide: `docs/mobile-seller-application.md`, latest section.

### White sidebar destinations and direct tab selection

Latest user preference overrides the older dark seller surfaces: drawer and seller destination page are always white with navy text and the existing gold selected edge. Keep the same CampusHub header throughout top-level sidebar selection, including existing Messages and embedded Account Settings content. Other account settings pages retain their standalone layout by default. Root five-tab navigation is tap-only with immediate page selection; horizontal swipes do not move between tabs. Keep state retention and independent inner horizontal catalog/gallery scrolling. Do not change global saved theme, API logic or introduce a separate seller Home. See `docs/mobile-seller-application.md` latest section for functions, checks and limitations.

### Seller center Add Product action and Iconsax

Approved sellers: Home | Marketplace | Add Product | Services | Facilities. The middle position is an action with an Iconsax box-add outline in a small gold container, not a page or floating overlay. Non-sellers keep Home | Marketplace | Services | Facilities | Profile. All nav/header/drawer glyphs use locally bundled Iconsax; inactive outlines, selected filled variants, existing restrained motion. Preserve48dp+ touch targets, Poppins11 labels, white/navy/gold palette and the header Profile avatar. Profile remains existing page4 and may have no selected seller-bar destination. Root tabs stay tap-only. Remove My Bundle Suggestions entry/preview; keep Suggested Product Bundles and My Bundles. Route successful suggested bundle creation to My Bundles. Existing APIs/data and form/body iconography remain. Package attribution/license: `THIRD_PARTY_NOTICES.md`; implementation and verification: `docs/mobile-seller-application.md` latest section.

### Reference-layout raised seller action

Latest layout request supersedes the small inline center container above. Use a56dp circle in existing gold#FCB315 with a navy28dp Iconsax box-add, raised16dp relative to the supporting white bar. Reserve that16dp inside the actual navbar layout and hit region; normal seller row84dp before safe area. Four supporting24dp icons sit lower with11dp Poppins labels,4dp icon/label rhythm and the existing selected Home silhouette/motion. Keep equal slots, all labels/routes and white surface flush with bottom/side edges. Non-seller bar stays flat and unchanged. No dark reference recolor, new shadow, notch, separate FAB or business change. User controls Ctrl+F5: no automatic app run/build/install/restart for visual verification; report source-only limits.

### User-supplied navigation glyphs (October 19, 2026)

Replace the box-add glyph above with the supplied filled rounded-square-plus vector, preserving the28dp navy glyph inside the same raised gold56dp circle. Inactive Home uses the supplied house outline/door stroke, while selected Home retains the earlier supplied filled house. Both use the existing muted/selected navy tints; preserve labels, animation, semantics and layout. These exact vectors are local CustomPaint paths, not downloaded replacements. Other navigation glyphs retain Iconsax. Source-only checks while the user's Ctrl+F5 session is active.

Latest glyph correction: Add Product now uses the user's outlined circle-plus SVG instead of the rounded-square plus, at the same size/tint inside the raised gold circle. The shared and seller header drawer controls use the three-horizontal-line Iconsax `menu_1_copy`, replacing the four-dot `menu_copy`. Preserve existing tooltip, touch region and drawer callback. Home glyphs and all layouts/colors stay unchanged.

Latest simplification: remove the plus glyph's outline ring, keeping a plain rounded plus inside the same raised gold button. The seller sidebar now has a56dp actual-name initial avatar (blank-name user-outline fallback) above identity with16dp gap; no real photo exists in the current account API. Keep Montserrat identity and Poppins controls. Profile divider spacing is24dp above/16dp below, named in `_SellerDrawerStyle`, with the existing1dp line. Keep the whole sidebar scrollable and current user/session/routes unchanged.

### Seller Add Product: one continuous page (October 19, 2026)

Operate mode, scoped to `SellerAddProductPage`; preserve existing Home, public catalogs, seller tools and navigation. A fixed56dp white AppBar has Back and Add Product in Poppins20/600, campus navy, thin bottom divider, no shadow. One vertically scrolling Form has16dp gutters, max640dp width,24dp section gaps and12dp input/container corners on#F7F8FC. White sections use16dp padding,16dp/600 headings,13dp/500 visible field labels with8dp separation and16dp field gaps. Inputs grow with content/text scaling; minimum52dp submission button stays at the end of the scroll. No stepper, horizontal page switching, draggable sheet, sample autocomplete or seller selector.

Exact hierarchy: Product Information(Name, realCategory, requiredDescription), Pricing & Inventory(positivePrice, nonnegativeQuantity, existing optional perishableExpiry), Product Images, Product Review, Submit for Approval. Stack price/quantity at360–390dp. One image follows the existing mobile API contract; outlined image-plus picker,96dp preview and Replace/Remove controls, honest empty/error state. Review text is supporting13dp copy; full-width navy/white submit has loading and duplicate-tap protection. Retain the shared navy/white palette, Poppins and existing institutional gold token; no new status color. Inline error copy uses the same restrained navy with live-region semantics.

The actual project uses StatefulWidget/Navigator, not GetX. Reuse current seller approval/category read and authenticated submission services; server ownership and Pending review stay authoritative. Shared image_picker and ProductImage are reused; no new package or backend. Verified with isolated Flutter captures at360px/390px/1.3x text and keyboard insets,19 headless tests and scoped static analysis. Native app session remains untouched. Implementation/report: `docs/mobile-seller-application.md`, first section.
