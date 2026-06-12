/* eslint-disable @typescript-eslint/no-explicit-any */
"use client";
import img1 from "@/app/assets/auth/basketball.png";
import Image from "next/image";
import { useState } from "react";
import { useRouter } from "next/navigation";
import toast from "react-hot-toast";
import baseApi from "@/api/baseAPi";
import { ENDPOINTS } from "@/api/endPoints";

export default function SetPassword() {
  const router = useRouter();

  const [formData, setFormData] = useState({
    password: "",
    confirmPassword: "",
  });

  const [showPopup, setShowPopup] = useState(false);
  const [loading, setLoading] = useState(false);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setFormData({ ...formData, [e.target.name]: e.target.value });
  };

  const handleUpdate = async () => {
    const { password, confirmPassword } = formData;

    if (!password || !confirmPassword) {
      toast.error("Please fill all fields");
      return;
    }

    if (password !== confirmPassword) {
      toast.error("Passwords do not match");
      return;
    }

    const email = localStorage.getItem("reset_email");
    const otp = localStorage.getItem("reset_otp");

    if (!email || !otp) {
      toast.error("Session expired. Please restart the process.");
      router.push("/forgetPassword");
      return;
    }

    try {
      setLoading(true);
      const res = await baseApi.post(ENDPOINTS.resetPassword, {
        email: email,
        new_password: password,
        confirm_password: confirmPassword,
        otp: otp,
      });

      if (res.status === 200 || res.status === 201) {
        toast.success("Password updated successfully!");

        // Clear reset data from localStorage
        localStorage.removeItem("reset_email");
        localStorage.removeItem("reset_otp");

        // Show popup
        setShowPopup(true);

        // Reset form
        setFormData({
          password: "",
          confirmPassword: "",
        });

        // Redirect to login after 2 seconds
        setTimeout(() => {
          setShowPopup(false);
          router.push("/singin");
        }, 2000);
      }
    } catch (error: any) {
      console.error("Reset Password Error:", error);
      toast.error(
        error.response?.data?.message ||
          error.response?.data?.error ||
          "Failed to reset password. Please try again.",
      );
    } finally {
      setLoading(false);
    }
  };

  const isFormValid =
    formData.password &&
    formData.confirmPassword &&
    formData.password === formData.confirmPassword;

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 min-h-screen bg-white relative">
      {/* Left side - Form */}
      <div className="flex flex-col md:justify-center px-10 md:px-12 lg:px-56 bg-white min-h-screen">
        <div className="font-bold text-[28px] lg:text-[32px] mb-10 md:mb-12 mt-40 md:mt-0">
          <h2 className="text-left mb-2 md:mb-0">Set a new password</h2>
          <p className="text-[#B1B1B1] text-[18px] font-medium">
            Create a new password. Ensure it differs from previous ones for
            security
          </p>
        </div>

        <div className="space-y-4">
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

          {/* Confirm Password */}
          <div>
            <label className="block text-sm md:text-[18px] font-semibold mb-1">
              Confirm Password
            </label>
            <input
              type="password"
              name="confirmPassword"
              value={formData.confirmPassword}
              onChange={handleChange}
              className="w-full p-3 md:p-4 lg:py-5 border border-[#B1B1B1] rounded-2xl outline-[#B1B1B1]"
              placeholder="Confirm your password"
            />
          </div>

          {/* Update Password Button */}
          <div className="flex justify-center space-x-4">
            <button
              onClick={handleUpdate}
              disabled={!isFormValid || loading}
              className={`w-full font-bold text-[20px] lg:text-[24px] py-3 lg:py-4 rounded-xl mt-6 md:mt-8 
                                ${
                                  isFormValid && !loading
                                    ? "bg-[#E8632C] text-white cursor-pointer"
                                    : "bg-[#E8632C80] text-white cursor-not-allowed"
                                }`}
            >
              {loading ? "Updating..." : "Update Password"}
            </button>
          </div>
        </div>
      </div>

      {/* Right side - Image */}
      <div className="bg-[#EDEDED] flex items-center justify-center">
        <Image
          src={img1}
          width={500}
          height={300}
          alt="Login Image"
          className="hidden sm:block md:w-[99%] md:h-[65%] lg:w-[75%] lg:h-[80%] p-4 md:mt-10"
        />
      </div>

      {/* ✅ Success Popup */}
      {showPopup && (
        <div className="fixed inset-0 flex items-center justify-center bg-black/40 z-50">
          <div className="bg-white rounded-2xl shadow-lg p-8 w-[350px] text-center">
            <div className="flex justify-center mb-4">
              <div className="w-16 h-16 border-2 border-[#E8632C] rounded-full flex items-center justify-center">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  fill="none"
                  viewBox="0 0 24 24"
                  strokeWidth={2}
                  stroke="#E8632C"
                  className="w-8 h-8"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    d="M5 13l4 4L19 7"
                  />
                </svg>
              </div>
            </div>
            <h2 className="text-xl font-bold mb-2">Successful</h2>
            <p className="text-gray-500 mb-6">
              Congratulations! Your password has been changed.
            </p>
            <button
              // onClick={() => router.push("/signin")}
              className="w-full bg-[#E8632C] text-white py-3 rounded-lg font-semibold hover:opacity-90"
            >
              Continue to Login
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
