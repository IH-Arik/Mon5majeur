/* eslint-disable @typescript-eslint/no-explicit-any */
"use client"
import img1 from "@/app/assets/auth/basketball.png"
import Image from "next/image"
import { useState } from "react"
import { useRouter } from "next/navigation"
import toast from "react-hot-toast"
import baseApi from "@/api/baseAPi"
import { ENDPOINTS } from "@/api/endPoints"

export default function ForgotPassword() {
    const router = useRouter()

    const [formData, setFormData] = useState({ email: "" });
    const [loading, setLoading] = useState(false);

    const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
        setFormData({ ...formData, [e.target.name]: e.target.value });
    };

    const handleForget = async () => {
        const { email } = formData;

        if (!email) {
            toast.error("Please enter your email");
            return;
        }

        try {
            setLoading(true);
            const res = await baseApi.post(ENDPOINTS.forgetPassword, { email });

            if (res.status === 200 || res.status === 201) {
                toast.success("Verification code sent to your email");
                localStorage.setItem("reset_email", email);
                setTimeout(() => {
                    router.push("/verifyCode"); 
                }, 1500);
            }
        } catch (error: unknown) {
            console.error("Forgot Password Error:", error);
            const errorMessage = 
                (error as any)?.response?.data?.message || 
                (error as any)?.response?.data?.email?.[0] ||
                "Failed to send reset code. Please try again.";
            toast.error(errorMessage);
        } finally {
            setLoading(false);
        }
    };  

    return (
        <div className="grid grid-cols-1 md:grid-cols-2 bg-white min-h-screen">
            {/* Left side - Form */}
            <div className="flex flex-col md:justify-center px-10 md:px-12 lg:px-56 bg-white min-h-screen">
                <div className="font-bold text-[28px] lg:text-[32px] mb-10 md:mb-12 mt-40 md:mt-0">
                    <h2 className="text-left mb-2 md:mb-0">Forgot password</h2>
                    <p className="text-[#B1B1B1] text-[18px] font-medium">
                        Please enter your email to reset the password
                    </p>
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

                    {/* Reset Password Button */}
                    <div className="flex justify-center space-x-4">
                        <button
                            onClick={handleForget}
                            disabled={!formData.email || loading}
                            className={`w-full font-bold text-[20px] lg:text-[24px] py-3 lg:py-4 rounded-xl mt-6 
                                ${formData.email && !loading
                                    ? "bg-[#E8632C] text-white cursor-pointer"
                                    : "bg-[#E8632C80] text-white cursor-not-allowed"
                                }`}
                        >
                            {loading ? "Sending..." : "Reset Password"}
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
                    className="p-4 md:mt-10 hidden sm:block md:w-[99%] md:h-[65%] lg:w-[75%] lg:h-[80%]"
                />
            </div>
        </div>
    )
}
