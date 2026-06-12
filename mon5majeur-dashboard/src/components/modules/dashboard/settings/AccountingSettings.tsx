"use client";
import React, { useRef, useState } from 'react'
import toast from 'react-hot-toast';
import { FaCamera } from 'react-icons/fa';
import img2 from '@/app/assets/Ellipse 87.png';

export default function AccountingSettings() {

  const [image, setImage] = useState<string | null>(null);
  const [firstName, setFirstName] = useState("");
  const [lastName, setLastName] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [oldPassword, setoldPassword] = useState("");
  const fileInputRef = useRef<HTMLInputElement | null>(null);

  // Handle file input change (upload image)
  const handleImageChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (file) {
      const reader = new FileReader();
      reader.onloadend = () => {
        setImage(reader.result as string);
      };
      reader.readAsDataURL(file);
    }
  };

  const handleClick = () => {
    fileInputRef.current?.click();
  };

  const handleSave = () => {
    toast.success("Profile updated successfully!");
    console.log("Saved Data:", { image, firstName, lastName });
  };


  const handlePasswordSave = () => {
    if (!newPassword || !oldPassword) {
      toast.error("Please fill both password fields!");
      return;
    }

    if (newPassword !== oldPassword) {
      toast.error("Passwords do not match!");
      return;
    }

    toast.success("Password updated successfully!");
    console.log("Password Data:", { newPassword, oldPassword });
    // Reset password fields
    setNewPassword("");
    setoldPassword("");
  };


  return (
    <div>
            <div className="flex flex-col mt-10 ">
        {/* Profile Image with edit icon */}
        <div
          className="relative w-32 h-32 cursor-pointer"
          onClick={handleClick}
        >
          <img
            src={
              image || img2.src}
            alt="Profile"
            className="w-28 h-28 rounded-full object-cover border-2 border-[#319EE1]"
          />

          {/* Camera Icon */}
          <div className="absolute bottom-4 right-4 bg-[#319EE1] p-2 rounded-full text-white shadow-lg">
            <FaCamera size={14} />
          </div>
        </div>

        {/* Hidden file input */}
        <input
          type="file"
          accept="image/*"
          ref={fileInputRef}
          onChange={handleImageChange}
          className="hidden"
        />
      </div>



      {/* Form Fields */}
      <div className="mt-10 w-full">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mt-6">
          <div>
            <label className="block text-sm md:text-[18px] mb-1.5 text-[#828282]">
              First Name
            </label>
            <input
              type="text"
              className="w-full p-3 md:p-4 border border-[#319EE1] rounded-2xl outline-[#319EE1]"
              placeholder="Enter your first name"
              value={firstName}
              onChange={e => setFirstName(e.target.value)}
            />
          </div>

          <div>
            <label className="block text-sm md:text-[18px] mb-1.5 text-[#828282]">
              Last Name
            </label>
            <input
              type="text"
              className="w-full p-3 md:p-4 border border-[#319EE1] rounded-2xl outline-[#319EE1]"
              placeholder="Enter your last name"
              value={lastName}
              onChange={e => setLastName(e.target.value)}
            />
          </div>

          <div className="flex justify-start space-x-4">
            <button
              onClick={handleSave}
              className="w-[50%] lg:w-[30%] cursor-pointer hover:opacity-80 hover:bg-[#319EE1] hover:scale-[96%] transition duration-300 bg-[#319EE1] text-white py-4 rounded-2xl mt-3">
              Save Changes
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
