// import axios from "axios";

// // Create an axios instance
// const baseApi = axios.create({
//   baseURL: "https://api.mon5majeur.com/api", // Your API base URL
// });

// // Add a request interceptor to include the access token in the headers
// baseApi.interceptors.request.use(
//   (config) => {
//     if (typeof window !== "undefined") {
//       const token = localStorage.getItem("access_token");
//       if (token) {
//         config.headers = config.headers || {};
//         config.headers.Authorization = `Bearer ${token}`;
//       }
//     }
//     return config;
//   },
//   (error) => {
//     return Promise.reject(error);
//   }
// );

// export default baseApi;

import axios from "axios";

const baseApi = axios.create({
  baseURL: process.env.NEXT_PUBLIC_API_URL,
});

// Add token to all requests
baseApi.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem("access_token");
    if (token) {
      config.headers = config.headers || {};
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  },
);

// Handle 401 errors and refresh token
// baseApi.interceptors.response.use(
//   (response) => response,
//   async (error) => {
//     const originalRequest = error.config;

//     if (error.response?.status === 401 && !originalRequest._retry) {
//       originalRequest._retry = true;

//       try {
//         const refreshToken = localStorage.getItem("refresh_token");
//         const res = await axios.post("your-refresh-endpoint", {
//           refresh: refreshToken,
//         });

//         if (res.data.access) {
//           localStorage.setItem("access_token", res.data.access);
//           originalRequest.headers.Authorization = `Bearer ${res.data.access}`;
//           return baseApi(originalRequest);
//         }
//       } catch (refreshError) {
//         localStorage.clear();
//         window.location.href = "/";
//         return Promise.reject(refreshError);
//       }
//     }

//     return Promise.reject(error);
//   }
// );

export default baseApi;
