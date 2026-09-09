// src/api/endpoints.js

export const ENDPOINTS = {
  BASEURL: "https://api.mon5majeur.com/api",
  adminLogin: "/admin/auth/login/",
  forgetPassword:"/auth/forgot-password/",
  otpVerify:"/auth/verify-forgot-password-otp/",
  resetPassword:"/auth/change-password/",
  // Change password while logged in (Settings → Reset Password)
  changePasswordAuth:"/auth/change-password-auth/",

  // Signed-in admin's own profile (Settings → Accounting)
  me: "/v1/users/me",
  fileUpload: "/v1/files",

  // Bonus catalog (5 fixed bonus types — price/active-status only, no create/delete)
  adminBonusCatalog: "/admin/bonuses/",
  adminBonusCatalogItem: (slug: string) => `/admin/bonuses/${slug}/`,

  // Token pack catalog (4 fixed packs — amount/price/active-status only, no create/delete)
  adminTokenPackCatalog: "/admin/token-packs/",
  adminTokenPackCatalogItem: (slug: string) => `/admin/token-packs/${slug}/`,
  adminTokenPackStats: "/admin/token-packs/stats/",

  // User management (the real /api/v1 admin router — not /api compat)
  adminUsersList: "/v1/users",
  adminUserStats: "/v1/users/stats/",
  adminUserItem: (id: string | number) => `/v1/users/${id}`,

  // League management
  adminLeagueStats: "/admin/leagues/stats/",
  adminGlobalLeaderboard: "/admin/leagues/global-leaderboard/",

  // Match & score management
  adminMatches: "/admin/matches/",
  adminMatchRescore: (id: string) => `/admin/matches/${id}/rescore/`,
  adminMatchScore: (id: string) => `/admin/matches/${id}/score/`,

  // Content pages (About Us / Legal Notices / Privacy Policy / Terms of Use)
  adminContentPages: "/admin/content/pages/",
  adminContentPageItem: (slug: string) => `/admin/content/pages/${slug}/`,

  // FAQ (free-form — create/update/delete)
  adminFaqs: "/admin/content/faqs/",
  adminFaqItem: (id: string) => `/admin/content/faqs/${id}/`,

  // Retention analytics (the real /api/v1 router — not /api compat)
  adminRetentionOverview: "/v1/analytics/retention/overview",

  // Support Center — ticket inbox
  adminTickets: "/admin/support/tickets/",
  adminTicketCounters: "/admin/support/tickets/counters/",
  adminTicketItem: (id: string) => `/admin/support/tickets/${id}/`,
  adminTicketReply: (id: string) => `/admin/support/tickets/${id}/reply/`,
  adminTicketStatus: (id: string) => `/admin/support/tickets/${id}/status/`,
};

