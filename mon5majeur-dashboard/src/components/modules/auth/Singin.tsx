/* eslint-disable @typescript-eslint/no-explicit-any */
"use client";
import img1 from "@/app/assets/auth/basketball.png";
import img2 from "@/app/assets/auth/Apple (1).png";
import img3 from "@/app/assets/auth/google (1).png";
import Image from "next/image";
import Link from "next/link";
import { useState } from "react";
import { useRouter } from "next/navigation";
import toast from "react-hot-toast";
import baseApi from "@/api/baseAPi";
import { ENDPOINTS } from "@/api/endPoints";

interface User {
  id: string;
  email: string;
  name?: string;
}

interface LoginResponse {
  access: string;
  refresh: string;
  user: User;
}

export default function Singin() {
  const router = useRouter();

  const [formData, setFormData] = useState({ email: "", password: "" });
  const [loading, setLoading] = useState(false);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setFormData({ ...formData, [e.target.name]: e.target.value });
  };

  const handleLogin = async () => {
    const { email, password } = formData;

    if (!email || !password) {
      toast.error("Please enter both email and password");
      return;
    }

    try {
      setLoading(true);
      const res = await baseApi.post<LoginResponse>(
        ENDPOINTS.adminLogin,
        formData,
      );
      console.log(res, "naeem");

      if (res.status === 200 || res.status === 201) {
        if (res.data?.access) {
          localStorage.setItem("access_token", res.data.access);
          localStorage.setItem("refresh_token", res.data.refresh);
          localStorage.setItem("user", JSON.stringify(res.data.user));
          toast.success("Logged in successfully!");
          router.push("/adminDashboard/userManagement");
        } else {
          console.log("Response data:", res.data);
          toast.error("Invalid response format");
        }
      }
    } catch (error: any) {
      console.error("Login Error:", error);
      toast.error(
        error.response?.data?.message ||
          "Login failed. Please check your credentials.",
      );
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 bg-white min-h-screen">
      {/* Left side - Form */}
      <div className="flex flex-col justify-center p-4 md:px-12 lg:px-56 bg-white min-h-screen">
        <div className="text-center font-bold text-[32px] mb-10 md:mb-16">
          <h2>Sign in</h2>
        </div>

        <div className="space-y-4">
          {/* Email */}
          <div>
            <label className="block text-sm md:text-[18px] font-semibold mb-1">
              Email
            </label>
            <input
              type="email"
              name="email"
              value={formData.email}
              onChange={handleChange}
              className="w-full p-3 md:p-4 lg:py-5 border border-[#B1B1B1] rounded-2xl outline-[#B1B1B1]"
              placeholder="Enter your email"
            />
          </div>

          {/* Password */}
          <div>
            <label className="block text-sm md:text-[18px] font-semibold mb-1">
              Password
            </label>
            <input
              type="password"
              name="password"
              value={formData.password}
              onChange={handleChange}
              className="w-full p-3 md:p-4 lg:py-5 border border-[#B1B1B1] rounded-2xl outline-[#B1B1B1]"
              placeholder="Enter your password"
            />
          </div>

          <div className="flex justify-between items-center mt-3">
            <div className="flex items-center">
              <input type="checkbox" id="rememberMe" className="mr-2" />
              <label htmlFor="rememberMe">Remember me</label>
            </div>
            <Link href="/forgetPassword">
              <p className="text-[#E8632C] underline">Forgot password</p>
            </Link>
          </div>

          {/* Login Button */}
          <div className="flex justify-center space-x-4">
            <button
              onClick={handleLogin}
              disabled={loading}
              className={`w-full font-bold text-[20px] lg:text-[24px] cursor-pointer bg-[#E8632C] text-white py-2 md:py-3 lg:py-4 rounded-xl mt-6 md:mt-8 ${loading ? "opacity-70 cursor-not-allowed" : ""}`}
            >
              {loading ? "Logging in..." : "Log in"}
            </button>
          </div>
        </div>

        <div className="flex items-center mt-6 md:mt-8">
          <div className="h-[1px] w-full bg-[#B1B1B1]"></div>
          <p className="mx-4">or</p>
          <div className="h-[1px] w-full bg-[#B1B1B1]"></div>
        </div>

        {/* Google & Apple Login */}
        <div className="space-y-4 mt-6 md:mt-8">
          <button className="flex text-black p-3 lg:p-4 w-full cursor-pointer items-center space-x-2 justify-center bg-[#F8F8F8] border border-[#B1B1B1] rounded-2xl outline-[#B1B1B1]">
            <Image src={img3} alt="Icon" width={30} height={30} />
            <span className="text-[16px] sm:text-base md:text-[18px]">
              Sign in with Google account
            </span>
          </button>
          <button className="flex text-black p-3 lg:p-4 w-full cursor-pointer items-center space-x-2 justify-center border bg-[#F8F8F8] border-[#B1B1B1] rounded-2xl outline-[#B1B1B1]">
            <Image src={img2} alt="Icon" width={30} height={30} />
            <span className="text-[16px] sm:text-base md:text-[18px]">
              Sign in with Apple account
            </span>
          </button>
        </div>
      </div>

      {/* Right side - Image */}
      <div className="bg-[#EDEDED] flex items-center justify-center">
        <Image
          src={img1}
          width={500}
          height={300}
          alt="Login Image"
          className="p-4 md:mt-10 hidden sm:block md:w-[99%] md:h-[65%] lg:w-[75%] lg:h-[80%]"
        />
      </div>
    </div>
  );
}
