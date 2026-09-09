/* eslint-disable @typescript-eslint/no-explicit-any */
"use client";

import React, { useState } from "react";
import toast from "react-hot-toast";
import baseApi from "@/api/baseAPi";
import { ENDPOINTS } from "@/api/endPoints";

export default function ResetPassword() {
  const [oldPassword, setOldPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [loading, setLoading] = useState(false);

  const handlePasswordSave = async () => {
    if (!oldPassword || !newPassword || !confirmPassword) {
      toast.error("Please fill all three password fields");
      return;
    }

    if (newPassword !== confirmPassword) {
      toast.error("New passwords do not match");
      return;
    }

    // Mirrors the server's own rule, so the common case fails instantly
    // instead of after a round trip.
    if (newPassword.length < 6) {
      toast.error("Password must be at least 6 characters");
      return;
    }

    try {
      setLoading(true);
      const res = await baseApi.post<{ message?: string }>(
        ENDPOINTS.changePasswordAuth,
        {
          old_password: oldPassword,
          new_password: newPassword,
          confirm_new_password: confirmPassword,
        },
      );

      if (res.status === 200 || res.status === 201) {
        toast.success(res.data?.message || "Password changed successfully");
        setOldPassword("");
        setNewPassword("");
        setConfirmPassword("");
      }
    } catch (error: unknown) {
      console.error("Change Password Error:", error);
      const errorMessage =
        (error as any)?.response?.data?.message ||
        (error as any)?.response?.data?.detail ||
        "Failed to change password. Please try again.";
      toast.error(errorMessage);
    } finally {
      setLoading(false);
    }
  };

  const fieldClass =
    "w-full p-3 md:p-4 border border-[#319EE1] rounded-2xl outline-[#319EE1]";
  const labelClass = "block text-sm md:text-[18px] mb-1.5 text-[#828282]";

  return (
    <div>
      <div className="mt-16">
        <h2 className="text-[30px] font-semibold">Change Password</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mt-6">
          <div>
            <label className={labelClass}>Old Password</label>
            <input
              type="password"
              value={oldPassword}
              onChange={(e) => setOldPassword(e.target.value)}
              className={fieldClass}
              placeholder="Enter your old password"
            />
          </div>

          <div>
            <label className={labelClass}>New Password</label>
            <input
              type="password"
              value={newPassword}
              onChange={(e) => setNewPassword(e.target.value)}
              className={fieldClass}
              placeholder="Enter your new password"
            />
          </div>

          <div>
            <label className={labelClass}>Confirm New Password</label>
            <input
              type="password"
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              className={fieldClass}
              placeholder="Re-enter your new password"
            />
          </div>

          <div className="flex items-end justify-start space-x-4">
            <button
              onClick={handlePasswordSave}
              disabled={loading}
              className="w-[50%] lg:w-[60%] cursor-pointer hover:opacity-80 hover:bg-[#319EE1] hover:scale-[96%] transition duration-300 bg-[#319EE1] text-white py-4 rounded-2xl mt-3 disabled:cursor-not-allowed disabled:opacity-60"
            >
              {loading ? "Saving..." : "Save Changes"}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
