"use client";
import Link from "next/link";
import Image from "next/image";
import { useState } from "react";
import { usePathname, useRouter } from "next/navigation";
import { FaBars, FaTimes, FaStore, FaUsers } from "react-icons/fa";

import { Toaster } from "react-hot-toast";

// 🖼️ Images
import img1 from "@/app/assets/LOGO-MON5MAJEUR-FOND-01_1-removebg-preview 1.png";
import img2 from "@/app/assets/auth/Avatar.png";
import img3 from "@/app/assets/auth/Vector (9).png";
import img4 from "@/app/assets/auth/Vector (10).png";
import { IoNotificationsOutline, IoSettingsOutline } from "react-icons/io5";
import { SiIndiansuperleague } from "react-icons/si";
import { MdOutlineAnalytics, MdOutlineSportsScore } from "react-icons/md";
import { GrCompliance } from "react-icons/gr";

export default function Layout({ children }: { children: React.ReactNode }) {
  const [isOpen, setIsOpen] = useState(false);
  const [isNotifOpen, setIsNotifOpen] = useState(false);
  const pathname = usePathname();
  const router = useRouter();

  const handleLogout = () => {
    // Remove all items from localStorage
    localStorage.removeItem("reset_email");
    localStorage.removeItem("access_token");
    localStorage.removeItem("refresh_token");
    localStorage.removeItem("user");

    // Redirect to login page
    router.push("/singin");
  };

  const notifications = [
    {
      id: 1,
      name: "Helena",
      message: "is uploaded new video in Halloween theme",
      time: "8:20am",
      avatar: img2, // use existing imported image or add more
    },
    {
      id: 2,
      name: "Oscar",
      message: "is uploaded new video in Halloween theme",
      time: "8:20am",
      avatar: img2,
    },
    {
      id: 3,
      name: "Daniel",
      message: "is uploaded new video in Halloween theme",
      time: "8:20am",
      avatar: img2,
    },
  ];

  const menuItems = [
    {
      href: "/adminDashboard/userManagement",
      label: "User Management",
      icon: <FaUsers size={17} />,
    },
    // { href: "/adminDashboard/leagueManagement", label: "League Management", icon: <SiIndiansuperleague /> },
    // { href: "/adminDashboard/match&scoreManagement", label: "Match & Score Management", icon: <MdOutlineSportsScore size={30} /> },
    {
      href: "/adminDashboard/bonus&storeManagement",
      label: "Bonus & Store Management",
      icon: <FaStore size={20} />,
    },
    {
      href: "/adminDashboard/analytics&reporting",
      label: "Analytics & Reporting",
      icon: <MdOutlineAnalytics size={20} />,
    },
    {
      href: "/adminDashboard/security&compliance",
      label: "Security & Compliance",
      icon: <GrCompliance />,
    },
  ];

  return (
    <div className="flex min-h-screen relative">
      {/* Sidebar */}
      <aside
        className={`fixed border-r border-[#B1B1B1] top-0 min-h-screen left-0 w-72 lg:w-80 bg-white text-black flex flex-col justify-between p-4 lg:p-3 z-50 transform transition-transform duration-300
        ${isOpen ? "translate-x-0" : "-translate-x-full md:translate-x-0"}`}
      >
        <div className="md:px-2 lg:px-4 pt-8">
          {/* Mobile Close Button */}
          <div className="flex items-center justify-between md:hidden mb-6">
            <Image src={img1} alt="Logo" width={40} height={40} />
            <button onClick={() => setIsOpen(false)}>
              <FaTimes size={24} className="text-red-500 hover:scale-105" />
            </button>
          </div>

          {/* Desktop Logo */}
          <div className="hidden md:flex items-center mb-10 justify-center">
            <Image src={img1} alt="Logo" width={90} height={70} />
          </div>

          {/* Menu */}
          <nav className="space-y-2">
            {menuItems.map((item) => {
              const isActive = pathname === item.href;
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  className={`flex items-center gap-3 py-4 px-3 rounded-xl transition-colors duration-200 text-[14px] md:text-[16px] lg:text-[19px] 
                    ${
                      isActive
                        ? "bg-[#E8632C] text-white font-medium"
                        : "hover:bg-white hover:text-[#E8632C]"
                    }`}
                >
                  {item.icon} {item.label}
                </Link>
              );
            })}
          </nav>
        </div>

        {/* Logout */}
        <div className="mt-6 p-4">
          <button
            onClick={handleLogout}
            className="mt-8 w-full bg-black py-3 hover:shadow-2xl rounded-lg flex justify-center gap-4"
          >
            <Image src={img4} alt="Logout" width={20} height={20} />
            <p className="text-xl text-white">Log out</p>
          </button>
        </div>
      </aside>

      {/* Overlay for mobile */}
      {isOpen && (
        <div
          className="fixed inset-0 bg-black/50 md:hidden z-40"
          onClick={() => setIsOpen(false)}
        ></div>
      )}

      {/* Main Content */}
      <main className="flex-1 bg-[#F8F8F8] text-black w-full">
        {/* ✅ Topbar (mobile + desktop) */}
        <div className="h-20 border-b border-[#B1B1B1] md:ml-72 lg:ml-80 bg-white px-4 flex items-center justify-between">
          {/* Left section: Hamburger + Profile */}
          <div className="flex items-center gap-4">
            {/* Hamburger menu (mobile only) */}
            <button
              onClick={() => setIsOpen(!isOpen)}
              className="block md:hidden p-2 rounded-md border border-gray-300 bg-white"
            >
              <FaBars size={22} />
            </button>
          </div>

          <div className="h-20 border-b border-[#B1B1B1] bg-white px-4 flex items-center justify-between gap-5">
            {/* ✅ Left: Profile section */}
            <div className="flex items-center gap-3 border border-[#B1B1B1] px-3 py-1 md:py-2 rounded-xl cursor-pointer hover:shadow-sm">
              <Image
                src={img2}
                alt="User Avatar"
                width={36}
                height={36}
                className="rounded-full object-cover w-8 "
              />
              <div className="text-sm leading-tight ">
                <div className="font-medium text-black">Olivia Rhye</div>
                <div className="text-gray-500 text-xs">
                  olivia@untitledui.com
                </div>
              </div>
              {/* <Image
                src={img3}
                alt="Dropdown Arrow"
                width={16}
                height={16}
                className=""
              /> */}
            </div>

            {/* ✅ Right: Notification + Settings */}
            <div className="flex items-center gap-4 ">
              <div className="relative z-50">
                {/* 🔔 Bell Icon */}
                <IoNotificationsOutline
                  onClick={(e) => {
                    e.stopPropagation(); // Prevent bubbling
                    setIsNotifOpen((prev) => !prev); // Toggle independently
                  }}
                  className="text-gray-600 hover:text-black cursor-pointer"
                  size={28}
                />
                <span className="absolute top-1 right-1 block h-2 w-2 rounded-full ring-2 ring-white bg-red-500"></span>

                {/* ✅ Notification Modal */}
                {isNotifOpen && (
                  <>
                    {/* Background Overlay */}
                    <div
                      className="fixed inset-0 bg-black opacity-50 z-[99]"
                      onClick={() => setIsNotifOpen(false)}
                    ></div>

                    {/* Popup Box */}
                    <div
                      className="fixed top-20 right-8 md:right-20 w-80 md:w-96  bg-white rounded-xl shadow-xl z-[100] p-4"
                      onClick={(e) => e.stopPropagation()} // Prevent closing on internal click
                    >
                      <h4 className="text-md font-semibold mb-4 text-[#E8632C]">
                        Notifications
                      </h4>

                      <div className="space-y-3 max-h-60 overflow-y-auto">
                        {notifications.length > 0 ? (
                          notifications.map((n) => (
                            <div
                              key={n.id}
                              className="flex items-start gap-3 p-2"
                            >
                              <div className="w-9 h-9 rounded-full overflow-hidden">
                                <Image
                                  src={n.avatar}
                                  alt={n.name}
                                  width={36}
                                  height={36}
                                  className="object-cover w-full h-full rounded-full"
                                />
                              </div>
                              <div className="flex-1">
                                <p className="text-sm text-gray-700 leading-snug">
                                  <span className="font-semibold">
                                    {n.name}
                                  </span>{" "}
                                  {n.message}
                                </p>
                              </div>
                              <span className="text-xs text-gray-400">
                                {n.time}
                              </span>
                            </div>
                          ))
                        ) : (
                          <p className="text-sm text-gray-500">
                            No new notifications.
                          </p>
                        )}
                      </div>
                    </div>
                  </>
                )}
              </div>
              <Link href="/adminDashboard/settings">
                <IoSettingsOutline
                  className="text-gray-600 hover:text-black cursor-pointer "
                  size={24}
                />
              </Link>
            </div>
          </div>
        </div>
        {/* Page Content */}
        <div className="overflow-y-scroll md:ml-72 lg:ml-80 ">
          <Toaster position="top-center" reverseOrder={false} />
          <div className="p-6">{children}</div>
        </div>
      </main>
    </div>
  );
}
