# Mon5Majeur Dashboard API Analysis

Date: August 17, 2026

## Summary

This document has been updated against the client brief in `M5M_Brief_Dashboard_Retention_EN.pdf`.

This dashboard is a Next.js admin panel with these main areas:

1. Auth
2. User Management
3. Bonus & Store Management
4. Analytics & Reporting
5. Security & Compliance
6. Settings
7. League Management
8. Match & Score Management

Some API integration already exists for auth and bonus stats/listing, but most of the dashboard still uses static/mock data. This file lists the APIs that should exist for the dashboard to be fully functional.

## What the client actually asked for

The brief is narrower than a full admin/CMS build. The founder asked for a lean retention dashboard with simple numbers and tables, not a polished analytics product.

Key client instructions from the PDF:

- keep visuals simple; plain numbers or basic HTML tables are enough
- do not spend time on fancy charts, animations, or heavy dataviz
- optimize for speed of delivery, roughly a 3-dev-day scope
- every retention/activity metric must be based on a validated lineup ("compo")
- do not count app opens or league membership as activity
- "night" means NBA match night in US/EST using the Goalserve date
- per-night metrics should only run on real match nights

## Client priority blocks from the brief

The PDF defines these 5 blocks in order:

1. Top-bar counters
   `downloads`, `today_signups`, `dau_tonight`, `dau_7_match_night_avg`, `lineups_tonight`, `account_deletions`
2. Cohort retention grid
   weekly cohorts with `D1`, `D3`, `D7`, `D14`, `D30`, `D60`, `D90`
3. Activation
   percentage of signups who have ever submitted a first validated lineup
4. Lineup volume per night
   last 30 match nights, simple count per night
5. Players in a private league
   distinct users active in at least 1 private league over the last 30 match nights

Important product note:

- the cohort retention grid is the core requirement in the brief
- the 7-match-night rolling DAU is explicitly tied to sponsor billing
- account deletions are both a churn signal and a GDPR/compliance metric
- private-league participation should show total-user context too if easy

## Scope correction vs this dashboard codebase

The current dashboard codebase includes many generic admin sections such as bonuses, token packs, FAQ, settings, leagues, and match management. Those may still be useful later, but they are not the main client ask in the retention brief.

So there are effectively 2 scopes:

1. Brief-driven retention MVP
   what the client explicitly asked for right now
2. Full admin panel completion
   what the broader dashboard frontend appears to support eventually

If we want to match the brief first, backend work should prioritize retention APIs before broader admin CRUD surfaces.

## Current frontend findings

- `src/api/endPoints.ts` contains only a small subset of needed endpoints.
- Bonus endpoints are partly wired, but token-pack endpoints are inconsistent.
- User, league, match, analytics, FAQ, notifications, profile, and settings areas are mostly mock/static right now.
- `adminLogin` currently points to `/auth/login/`, but the dashboard likely needs an admin-only login or a role check on the normal login.
- `allTokens`, `totalTokens`, `activeTokens`, `searchTokens` currently point to paths that do not match the backend structure used in the mobile app.

## Retention MVP APIs required by the client brief

These are the most important APIs if we are implementing exactly what the PDF asks for.

### 1. Retention overview / top-bar counters

- `GET /api/admin/retention/overview/`
  Purpose: fetch the 5 quick top-bar figures from the brief
  Response example:
  `{"downloads_total":312,"today_signups":12,"dau_tonight":128,"dau_7_match_night_avg":141,"lineups_tonight":96,"account_deletions":4}`

Rules:

- `dau_tonight` = distinct users with at least 1 validated lineup on the current match night
- `dau_7_match_night_avg` = average DAU over the last 7 match nights, not 7 calendar days
- `lineups_tonight` = count of validated lineups on the current match night
- `account_deletions` should come from fulfilled GDPR erasure/deletion events

### 2. Cohort retention grid

- `GET /api/admin/retention/cohorts/`
  Purpose: the core retention table from the brief
  Query params:
  `limit_weeks` optional
  Response example:
  `{"offsets":["D1","D3","D7","D14","D30","D60","D90"],"rows":[{"cohort_week":"2026-07-06","cohort_size":120,"retention":{"D1":0.42,"D3":0.31,"D7":0.22,"D14":0.14,"D30":0.09,"D60":0.07,"D90":0.06}}]}`

Rules:

- each row is a signup week cohort
- each cell is the percentage of the cohort that submitted at least 1 validated lineup on `signup_date + N days`
- incomplete recent cohorts should be allowed; the empty triangle is expected

### 3. Activation

- `GET /api/admin/retention/activation/`
  Purpose: share of users who have ever validated their first lineup
  Response example:
  `{"activation_rate":0.52,"activated_users":624,"total_signups":1200}`

### 4. Lineup volume by match night

- `GET /api/admin/retention/lineups-per-night/`
  Query params:
  `limit=30`
  Purpose: count validated lineups for each of the last 30 match nights
  Response example:
  `{"results":[{"night_date":"2026-08-10","lineups_count":72},{"night_date":"2026-08-11","lineups_count":66}]}`

### 5. Private-league participation

- `GET /api/admin/retention/private-league-participation/`
  Query params:
  `limit=30`
  Purpose: count distinct users active in at least 1 private league over the last 30 match nights
  Response example:
  `{"players_in_private":264,"total_active_players":1203}`

### 6. Match-night calendar support

- `GET /api/admin/retention/match-nights/`
  Optional but useful
  Purpose: expose the last/current match nights if the frontend should render labels or debug night selection logic

## Data assumptions that must be confirmed

The brief itself assumes these data sources:

- `lineups(id, user_id, league_id, night_date, validated_at)`
- `users(id, created_at)`
- `leagues(id, type ['global'|'public'|'private'], created_by)`
- `match_nights(night_date)`

Before implementation, confirm whether the Mon5Majeur backend has equivalent real models/collections and where GDPR deletion events are stored.

## Recommended implementation order

If the goal is to satisfy the client brief first, the order should be:

1. Admin auth / role protection
2. Retention overview counters
3. Cohort retention grid
4. Activation metric
5. Lineups per match night
6. Private-league participation
7. Only then broader admin panel APIs if still needed

## Full admin panel APIs beyond the brief

The remaining sections below are still relevant for completing the broader dashboard frontend, but they are not the founder's primary request in `M5M_Brief_Dashboard_Retention_EN.pdf`.

## Recommended API groups

## 1. Auth APIs

Used by:

- `src/components/modules/auth/Singin.tsx`
- `src/components/modules/auth/ForgotPassword.tsx`
- `src/components/modules/auth/Code.tsx`
- `src/components/modules/auth/SetPassword.tsx`
- dashboard logout / session handling

Required endpoints:

- `POST /api/auth/login/`
  Purpose: sign in admin/staff user
  Request:
  `{"email":"admin@example.com","password":"..."}`
  Response:
  `{"access":"...","refresh":"...","user":{"id":"...","email":"...","name":"...","role":"admin"}}`
  Notes:
  user role must be checked; non-admin users should be rejected

- `POST /api/auth/forgot-password/`
  Purpose: send reset OTP/email

- `POST /api/auth/verify-forgot-password-otp/`
  Purpose: verify OTP before password reset
  Notes:
  frontend currently does not call this yet; it only stores OTP locally. This should be integrated.

- `POST /api/auth/change-password/`
  Purpose: reset password with email + OTP + new password

- `POST /api/auth/refresh/`
  Purpose: refresh expired access token
  Notes:
  `baseAPi.ts` already has a commented refresh-token flow; backend endpoint should exist if not already exposed

- `POST /api/auth/logout/`
  Optional but recommended
  Purpose: revoke refresh token / invalidate session

## 2. Admin profile / topbar APIs

Used by:

- `src/app/adminDashboard/layout.tsx`
- `src/components/modules/dashboard/settings/AccountingSettings.tsx`
- `src/components/modules/dashboard/settings/ResetPassword.tsx`

Required endpoints:

- `GET /api/admin/me/`
  Purpose: fetch logged-in admin profile for topbar
  Response fields:
  `id`, `first_name`, `last_name`, `email`, `avatar_url`, `role`

- `PATCH /api/admin/me/`
  Purpose: update admin first name / last name / avatar
  Notes:
  should support multipart if avatar upload is allowed

- `POST /api/auth/change-password-auth/`
  Purpose: change password while logged in
  Request:
  `{"old_password":"...","new_password":"...","confirm_password":"..."}`

- `GET /api/admin/notifications/`
  Purpose: fetch topbar notifications

- `PATCH /api/admin/notifications/{id}/read/`
  Purpose: mark one notification read

- `POST /api/admin/notifications/read-all/`
  Purpose: clear badge state

## 3. User Management APIs

Used by:

- `src/components/modules/dashboard/CardUser.tsx`
- `src/components/modules/dashboard/UserManagement.tsx`

Required endpoints:

- `GET /api/admin/users/stats/`
  Purpose: dashboard cards
  Response fields:
  `total_users`, `monthly_active_users`, `new_registrations`, `blocked_users`

- `GET /api/admin/users/`
  Purpose: paginated user list
  Query params:
  `page`, `page_size`, `search`, `status`, `joined_from`, `joined_to`
  Response:
  `{"count":123,"next":"...","previous":"...","results":[...]}`
  Result item fields:
  `id`, `name`, `email`, `status`, `joined_at`, `avatar_url`

- `PATCH /api/admin/users/{id}/status/`
  Purpose: update user status
  Expected statuses:
  `active`, `pending`, `banned`, `inactive`

- `DELETE /api/admin/users/{id}/`
  Purpose: delete or soft-delete user

- `GET /api/admin/users/{id}/`
  Optional
  Purpose: open future user details drawer/page

## 4. Bonus Management APIs

Used by:

- `src/components/modules/dashboard/BounsCard.tsx`
- `src/components/modules/dashboard/all/AllBonus.tsx`
- `src/components/modules/dashboard/all/CreateBonus.tsx`
- `src/components/modules/dashboard/all/EditBonus.tsx`

Current frontend expectation:

- stats:
  `GET /bonuses/total_bonuses/`
  `GET /bonuses/active_bonuses/`
- list:
  `GET /bonuses/`

Recommended admin API:

- `GET /api/admin/bonuses/stats/`
  Response:
  `{"total_bonuses":4,"active_bonuses":3}`

- `GET /api/admin/bonuses/`
  Query params:
  `page`, `page_size`, `search`, `status`, `type`
  Result fields:
  `id`, `bonus_name`, `bonus_type`, `status`, `price`, `created_at`, `expired_at`, `logo_url`

- `POST /api/admin/bonuses/`
  Purpose: create bonus
  Request fields:
  `bonus_name`, `bonus_type`, `price`, `created_at`, `expired_at`, `logo`

- `PATCH /api/admin/bonuses/{id}/`
  Purpose: edit bonus

- `PATCH /api/admin/bonuses/{id}/status/`
  Purpose: activate/deactivate / mark coming soon
  Notes:
  frontend currently has `Active`, `Comming soon`, `Inactive`
  Better backend enum:
  `active`, `coming_soon`, `inactive`

- `DELETE /api/admin/bonuses/{id}/`

## 5. Token Pack / Store APIs

Used by:

- `src/components/modules/dashboard/TokenCards.tsx`
- `src/components/modules/dashboard/token/AllToken.tsx`
- `src/components/modules/dashboard/token/CreateToken.tsx`
- `src/components/modules/dashboard/token/EditToken.tsx`

Needed endpoints:

- `GET /api/admin/token-packs/stats/`
  Response:
  `total_packs`, `active_packs`, `total_tokens_sold`, `revenue_tokens`

- `GET /api/admin/token-packs/`
  Query params:
  `page`, `page_size`, `search`, `status`
  Result fields:
  `id`, `pack_name`, `token_amount`, `price`, `status`, `created_at`, `expired_at`, `logo_url`

- `POST /api/admin/token-packs/`

- `PATCH /api/admin/token-packs/{id}/`

- `PATCH /api/admin/token-packs/{id}/status/`

- `DELETE /api/admin/token-packs/{id}/`

Important note:

- Current `src/api/endPoints.ts` mixes token endpoints under `/bonuses/...`.
- Token packs should have their own admin namespace, not bonus namespace.

## 6. Analytics & Reporting APIs

Used by:

- `src/app/adminDashboard/analytics&reporting/page.tsx`
- `src/components/modules/dashboard/chart/UserChart.tsx`
- `src/components/modules/dashboard/chart/DurationChart.tsx`
- `src/components/modules/dashboard/chart/LeagueChart.tsx`

Needed endpoints:

- `GET /api/admin/analytics/daily-active-users/`
  Query params:
  `period=weekly|monthly|yearly`
  Response example:
  `{"labels":["Tue","Wed"],"series":[50,90]}`

- `GET /api/admin/analytics/session-duration/`
  Query params:
  `period=weekly|monthly|yearly`
  Response example:
  `{"buckets":[{"name":"0-15m","value":35},{"name":"15-30m","value":42},{"name":"30-60m","value":23}]}`

- `GET /api/admin/analytics/league-participation/`
  Query params:
  `period=weekly|monthly|yearly`
  Response example:
  `{"labels":["Global","Public","Private"],"series":[3000,2200,1400]}`

- `GET /api/admin/analytics/overview/`
  Optional but recommended
  Purpose: landing-page hero KPIs

- `GET /api/admin/reports/export/`
  Optional
  Purpose: CSV/Excel export for selected analytics range

## 7. League Management APIs

Used by:

- `src/components/modules/dashboard/LeagueCard.tsx`
- `src/components/modules/dashboard/LeagueManagement.tsx`
- page exists but sidebar link is currently disabled

Needed endpoints:

- `GET /api/admin/leagues/stats/`
  Response fields inferred from cards:
  `total_global_leagues`
  `total_public_leagues`
  `total_private_leagues`
  `total_private_league_users`
  `total_global_league_users`
  `monthly_active_users`
  `total_public_leagues_created`
  `total_private_leagues_created`

- `GET /api/admin/leagues/leaderboard/`
  Query params:
  `year`, `month`, `league_type=global|public|private`
  Response item fields:
  `rank`, `team_name`, `score`, `bonus_label`

- `GET /api/admin/leagues/`
  Optional
  Purpose: browse all leagues, not only leaderboard summary

- `GET /api/admin/leagues/{id}/`
  Optional

- `PATCH /api/admin/leagues/{id}/status/`
  Optional
  Purpose: suspend/reopen league

## 8. Match & Score Management APIs

Used by:

- `src/components/modules/dashboard/MatchManagement.tsx`
- page exists but sidebar link is currently disabled

Needed endpoints:

- `GET /api/admin/matches/review-queue/`
  Query params:
  `page`, `page_size`, `status=pending|disputed`, `league_id`, `date`
  Result fields:
  `id`, `match_label`, `league_name`, `score`, `status`

- `GET /api/admin/matches/{id}/`
  Purpose: detailed dispute / verification view

- `PATCH /api/admin/matches/{id}/resolve/`
  Purpose: resolve disputed score
  Request example:
  `{"status":"verified","notes":"..."}` or score correction payload

- `PATCH /api/admin/matches/{id}/status/`
  Purpose: mark pending/disputed/resolved

## 9. FAQ / Security & Compliance APIs

Used by:

- `src/components/modules/dashboard/Security.tsx`

Needed endpoints:

- `GET /api/admin/faqs/`
  Purpose: fetch FAQ list
  Result fields:
  `id`, `question`, `answer`, `order`, `is_published`

- `POST /api/admin/faqs/`
  Purpose: create FAQ

- `PATCH /api/admin/faqs/{id}/`
  Optional but strongly recommended
  Purpose: edit FAQ

- `DELETE /api/admin/faqs/{id}/`
  Optional but strongly recommended

- `PATCH /api/admin/faqs/reorder/`
  Optional

The current UI only supports create + accordion open/close, but edit/delete/reorder will almost certainly be needed in practice.

## 10. Settings content APIs

Used by:

- `src/components/modules/dashboard/settings/LegalNotice.tsx`
- `src/components/modules/dashboard/settings/TermsAndConditions.tsx`
- `src/components/modules/dashboard/settings/SupportCenter.tsx`

Needed endpoints:

- `GET /api/admin/content/legal-notice/`
- `PUT /api/admin/content/legal-notice/`

- `GET /api/admin/content/terms-and-conditions/`
- `PUT /api/admin/content/terms-and-conditions/`

- `GET /api/admin/content/support-center/`
- `PUT /api/admin/content/support-center/`

Optional:

- `GET /api/admin/content/privacy-policy/`
- `PUT /api/admin/content/privacy-policy/`
- `GET /api/admin/content/about-us/`
- `PUT /api/admin/content/about-us/`

This would let the dashboard manage the same static content used by the mobile app.

## Recommended response conventions

For all admin list endpoints:

- use paginated shape:
  `count`, `next`, `previous`, `results`

For all admin mutation endpoints:

- return updated resource or a compact success payload
- include validation errors in a structured format

Recommended standard error shape:

```json
{
  "detail": "Validation failed",
  "errors": {
    "field_name": ["Error message"]
  }
}
```

## Recommended auth / security rules

- all `/api/admin/*` endpoints should require authenticated admin or staff role
- login response should include role/permissions
- frontend should redirect to `/singin` on `401`
- refresh-token endpoint should be wired in `src/api/baseAPi.ts`
- audit logging is recommended for:
  user status changes
  bonus create/edit/delete
  token pack create/edit/delete
  match resolution
  legal/settings content edits

## Suggested endpoint map for frontend cleanup

Current `src/api/endPoints.ts` should eventually look more like:

```ts
export const ENDPOINTS = {
  adminLogin: "/auth/login/",
  refreshToken: "/auth/refresh/",
  forgetPassword: "/auth/forgot-password/",
  otpVerify: "/auth/verify-forgot-password-otp/",
  resetPassword: "/auth/change-password/",

  adminMe: "/admin/me/",
  adminNotifications: "/admin/notifications/",

  userStats: "/admin/users/stats/",
  users: "/admin/users/",

  bonusStats: "/admin/bonuses/stats/",
  bonuses: "/admin/bonuses/",

  tokenPackStats: "/admin/token-packs/stats/",
  tokenPacks: "/admin/token-packs/",

  analyticsDau: "/admin/analytics/daily-active-users/",
  analyticsSessionDuration: "/admin/analytics/session-duration/",
  analyticsLeagueParticipation: "/admin/analytics/league-participation/",

  leagueStats: "/admin/leagues/stats/",
  leagueLeaderboard: "/admin/leagues/leaderboard/",

  matchReviewQueue: "/admin/matches/review-queue/",

  faqs: "/admin/faqs/",

  legalNotice: "/admin/content/legal-notice/",
  termsAndConditions: "/admin/content/terms-and-conditions/",
  supportCenter: "/admin/content/support-center/",
};
```

## Priority order

If backend work starts now, this order makes the most sense:

1. Auth + admin role protection
2. User Management APIs
3. Bonus APIs
4. Token Pack APIs
5. Admin profile/settings APIs
6. FAQ APIs
7. Analytics APIs
8. League Management APIs
9. Match Review APIs
10. Static content management APIs

## Biggest current gaps

- OTP verification page does not call backend verify endpoint yet
- user management is fully mock
- token pack management is fully mock
- analytics is fully mock
- notifications/profile in admin layout are mock
- FAQ/security is mock
- league and match management are mock
- legal/support/settings content is not connected

## Final recommendation

Before implementing more frontend, create a dedicated `/api/admin/*` backend surface instead of reusing random app/mobile endpoints. The dashboard needs:

- role-based admin auth
- paginated list APIs
- stats endpoints for cards/charts
- content-management endpoints
- audit-safe mutation endpoints

That structure will keep the dashboard much easier to maintain than patching together mobile-facing endpoints.
