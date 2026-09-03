"use client";

import { FiUserPlus, FiUsers } from "react-icons/fi";
import { MdDone } from "react-icons/md";
import { TbUserX } from "react-icons/tb";
import { useEffect, useState } from "react";
import baseApi from "@/api/baseAPi";
import { ENDPOINTS } from "@/api/endPoints";

interface UserStats {
  total_users: number;
  new_signups_30d: number;
  monthly_active_users: number;
  banned_users: number;
}

export default function CardUser() {
  const [stats, setStats] = useState<UserStats>({
    total_users: 0,
    new_signups_30d: 0,
    monthly_active_users: 0,
    banned_users: 0,
  });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchStats = async () => {
      try {
        setLoading(true);
        const response = await baseApi.get<UserStats>(ENDPOINTS.adminUserStats);
        setStats(response.data);
      } catch (error) {
        console.error("Error fetching user stats:", error);
      } finally {
        setLoading(false);
      }
    };

    fetchStats();
  }, []);

  const statsData = [
    { label: "Total User", value: stats.total_users, icon: <FiUsers /> },
    {
      label: "Active Users (Lineup, 30d)",
      // "Active" here means submitted a full lineup, not merely opened the
      // app — mirrors the Retention Analytics definition so the two
      // dashboards never disagree on what "active" means.
      hint: "Users who submitted a complete 5-player lineup in the last 30 days. Logging in without playing does not count.",
      value: stats.monthly_active_users,
      icon: <MdDone className="border rounded-full p-0.5" />,
    },
    { label: "New Registration (30d)", value: stats.new_signups_30d, icon: <FiUserPlus /> },
    { label: "Banned Users", value: stats.banned_users, icon: <TbUserX /> },
  ];

  return (
    <div className="grid grid-cols-2 sm:grid-cols-2 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-6 mt-6">
      {statsData.map((stat, index) => (
        <div key={index} className="bg-white shadow rounded-2xl  p-4 lg:px-6 ">
          <div className="flex justify-between mb-4">
            <div
              className="text-[16px] md:text-[18px] lg:text-[20px] text-[#828282]"
              title={stat.hint}
            >
              {stat.label}
            </div>
            <div className=" text-[20px] text-[#828282]">{stat.icon}</div>
          </div>

          <div className="text-[24px] md:text-[25px] lg:text-[28px] font-semibold text-gray-800">
            {loading ? "..." : stat.value}
          </div>
        </div>
      ))}
    </div>
  );
}
