"use client";
import img1 from "@/app/assets/auth/basketball.png";
import Image from "next/image";
import { useState, useEffect } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import toast from "react-hot-toast";

export default function Code() {
  const router = useRouter();
  const [otp, setOtp] = useState(["", "", "", "", "", ""]);
  const [email, setEmail] = useState("");

  useEffect(() => {
    const resetEmail = localStorage.getItem("reset_email");
    if (resetEmail) {
      setEmail(resetEmail);
    }
  }, []);

  const handleChange = (value: string, index: number) => {
    if (/^[0-9]?$/.test(value)) {
      const newOtp = [...otp];
      newOtp[index] = value;
      setOtp(newOtp);

      // Auto focus next input
      if (value && index < 5) {
        const next = document.getElementById(`otp-${index + 1}`);
        next?.focus();
      }
    }
  };

  const handleBackspace = (
    index: number,
    event: React.KeyboardEvent<HTMLInputElement>,
  ) => {
    if (event.key === "Backspace" && otp[index] === "" && index > 0) {
      const prev = document.getElementById(`otp-${index - 1}`);
      prev?.focus();
    }
  };

  const handleVerifyCode = () => {
    const otpString = otp.join("");
    localStorage.setItem("reset_otp", otpString);
    toast.success("OTP verified successfully!");
    setTimeout(() => {
      router.push("/setPassword");
    }, 1000);
  };

  const isOtpComplete = otp.every((digit) => digit !== ""); // Check if all OTP fields are filled

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 min-h-screen bg-white">
      {/* Left side - OTP Form */}
      <div className="flex flex-col md:justify-center px-10  md:px-11 lg:px-56 min-h-screen bg-white">
        <div className="font-bold text-[28px] lg:text-[32px] mb-10 md:mb-12 mt-40 md:mt-0">
          <h2 className="text-left mb-2 md:mb-0">Check your email</h2>
          <p className="text-[#B1B1B1] text-[18px] font-medium">
            We sent a reset link to {email || "your email"}
            enter 6 digit code that mentioned in the email
          </p>
        </div>

        {/* OTP Inputs */}
        <div className="flex justify-center space-x-2 md:space-x-4 lg:space-x-8 mb-6 md:mb-8">
          {otp.map((digit, index) => (
            <input
              key={index}
              id={`otp-${index}`}
              type="text"
              maxLength={1}
              value={digit}
              onChange={(e) => handleChange(e.target.value, index)}
              onKeyDown={(e) => handleBackspace(index, e)}
              className="w-12 md:w-14 h-12 md:h-14 text-center border border-gray-400 rounded-md text-lg font-semibold focus:outline-none focus:ring-1 focus:ring-[#B1B1B1] transition duration-300"
            />
          ))}
        </div>

        {/* Verify Code*/}
        <button
          onClick={handleVerifyCode}
          disabled={!isOtpComplete}
          className={`w-full font-bold text-[20px] lg:text-[24px] py-3 lg:py-4 rounded-xl mt-6 
                                ${
                                  isOtpComplete
                                    ? "bg-[#E8632C] text-white cursor-pointer"
                                    : "bg-[#E8632C80] text-white cursor-not-allowed"
                                }`}
        >
          Verify Code
        </button>

        {/* Resend Link */}
        <p className="mt-4 text-gray-500 text-center">
          Haven’t got the email yet?{" "}
          <Link href="/admin/auth/login">
            <span className="font-semibold underline text-[#E8632C] cursor-pointer">
              Resend code
            </span>
          </Link>
        </p>
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
    </div>
  );
}
