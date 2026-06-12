// src/api/endpoints.js

export const ENDPOINTS = {
  BASEURL: "https://api.mon5majeur.com/api",
  adminLogin: "/auth/login/",
  forgetPassword:"/auth/forgot-password/",
  otpVerify:"/auth/verify-forgot-password-otp/",
  resetPassword:"/auth/change-password/",

  allBonus:"/bonuses/",
  createBonus:"/bonuses/",
  totalBonus:"/bonuses/total_bonuses/",
  activeBonus:"/bonuses/active_bonuses/",
  searchBonus:"bonuses/search_bonuses/",

  allTokens:"/tokens/",
  createToken: "/tokens/",
  totalTokens:"/bonuses/total_tokens/",
  activeTokens:"/bonuses/active_tokens/",
  searchTokens:"/bonuses/search_tokens/",

};

