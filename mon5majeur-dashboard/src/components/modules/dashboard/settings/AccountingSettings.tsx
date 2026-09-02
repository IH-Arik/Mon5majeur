/* eslint-disable @typescript-eslint/no-explicit-any */
"use client";

import React, { useEffect, useRef, useState } from "react";
import toast from "react-hot-toast";
import { FaCamera } from "react-icons/fa";
import img2 from "@/app/assets/Ellipse 87.png";
import baseApi from "@/api/baseAPi";
import { ENDPOINTS } from "@/api/endPoints";

interface MeResponse {
  full_name: string | null;
  avatar_url: string | null;
}

export default function AccountingSettings() {
  // Preview of a freshly picked file, before it is uploaded.
  const [preview, setPreview] = useState<string | null>(null);
  const [avatarUrl, setAvatarUrl] = useState<string | null>(null);
  const [pickedFile, setPickedFile] = useState<File | null>(null);
  const [firstName, setFirstName] = useState("");
  const [lastName, setLastName] = useState("");
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const fileInputRef = useRef<HTMLInputElement | null>(null);

  // The backend stores one `full_name`, so the two boxes are a display
  // convention: split on the first space, rejoin on save.
  useEffect(() => {
    const load = async () => {
      try {
        setLoading(true);
        const res = await baseApi.get<MeResponse>(ENDPOINTS.me);
        const [first, ...rest] = (res.data.full_name || "").trim().split(" ");
        setFirstName(first || "");
        setLastName(rest.join(" "));
        setAvatarUrl(res.data.avatar_url);
      } catch (error: unknown) {
        console.error("Load profile error:", error);
        toast.error("Could not load your profile");
      } finally {
        setLoading(false);
      }
    };
    load();
  }, []);

  const handleImageChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;
    setPickedFile(file);
    const reader = new FileReader();
    reader.onloadend = () => setPreview(reader.result as string);
    reader.readAsDataURL(file);
  };

  const handleClick = () => {
    fileInputRef.current?.click();
  };

  const handleSave = async () => {
    if (!firstName.trim()) {
      toast.error("Please enter your first name");
      return;
    }

    try {
      setSaving(true);

      // Upload first: the profile only ever points at a stored file, so a
      // failed upload must not leave the name saved against a stale avatar.
      let uploadedUrl = avatarUrl;
      if (pickedFile) {
        const form = new FormData();
        form.append("file", pickedFile);
        const upload = await baseApi.post<{ public_url: string | null }>(
          ENDPOINTS.fileUpload,
          form,
        );
        uploadedUrl = upload.data?.public_url ?? uploadedUrl;
      }

      const res = await baseApi.patch<MeResponse>(ENDPOINTS.me, {
        full_name: [firstName.trim(), lastName.trim()].filter(Boolean).join(" "),
        avatar_url: uploadedUrl,
      });

      setAvatarUrl(res.data.avatar_url);
      setPickedFile(null);
      setPreview(null);
      toast.success("Profile updated successfully");
    } catch (error: unknown) {
      console.error("Save profile error:", error);
      const errorMessage =
        (error as any)?.response?.data?.message ||
        (error as any)?.response?.data?.detail ||
        "Failed to update profile. Please try again.";
      toast.error(errorMessage);
    } finally {
      setSaving(false);
    }
  };

  const fieldClass =
    "w-full p-3 md:p-4 border border-[#319EE1] rounded-2xl outline-[#319EE1]";
  const labelClass = "block text-sm md:text-[18px] mb-1.5 text-[#828282]";

  return (
    <div>
      <div className="flex flex-col mt-10">
        <div
          className="relative w-32 h-32 cursor-pointer"
          onClick={handleClick}
        >
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={preview || avatarUrl || img2.src}
            alt="Profile"
            className="w-28 h-28 rounded-full object-cover border-2 border-[#319EE1]"
          />

          <div className="absolute bottom-4 right-4 bg-[#319EE1] p-2 rounded-full text-white shadow-lg">
            <FaCamera size={14} />
          </div>
        </div>

        <input
          type="file"
          accept="image/*"
          ref={fileInputRef}
          onChange={handleImageChange}
          className="hidden"
        />
      </div>

      <div className="mt-10 w-full">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mt-6">
          <div>
            <label className={labelClass}>First Name</label>
            <input
              type="text"
              className={fieldClass}
              placeholder="Enter your first name"
              value={firstName}
              disabled={loading}
              onChange={(e) => setFirstName(e.target.value)}
            />
          </div>

          <div>
            <label className={labelClass}>Last Name</label>
            <input
              type="text"
              className={fieldClass}
              placeholder="Enter your last name"
              value={lastName}
              disabled={loading}
              onChange={(e) => setLastName(e.target.value)}
            />
          </div>

          <div className="flex justify-start space-x-4">
            <button
              onClick={handleSave}
              disabled={loading || saving}
              className="w-[50%] lg:w-[30%] cursor-pointer hover:opacity-80 hover:bg-[#319EE1] hover:scale-[96%] transition duration-300 bg-[#319EE1] text-white py-4 rounded-2xl mt-3 disabled:cursor-not-allowed disabled:opacity-60"
            >
              {saving ? "Saving..." : "Save Changes"}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
