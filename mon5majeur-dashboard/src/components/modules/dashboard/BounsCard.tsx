"use client";

import { CiGift } from "react-icons/ci";
import { useEffect, useState } from "react";
import baseApi from "@/api/baseAPi";
import { ENDPOINTS } from "@/api/endPoints";
import type { BonusOffer } from "./all/AllBonus";

export default function BounsCard() {
  const [stats, setStats] = useState({ totalBonus: 0, activeBonus: 0 });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchBonusData = async () => {
      try {
        setLoading(true);
        const response = await baseApi.get<BonusOffer[]>(ENDPOINTS.adminBonusCatalog);
        setStats({
          totalBonus: response.data.length,
          activeBonus: response.data.filter((o) => o.is_active).length,
        });
      } catch (error) {
        console.error("Error fetching bonus data:", error);
      } finally {
        setLoading(false);
      }
    };

    fetchBonusData();
  }, []);

  const statsData = [
    { label: "Total Bonuses", value: stats.totalBonus, icon: <CiGift /> },
    { label: "Active Bonuses", value: stats.activeBonus, icon: <CiGift /> },
  ];

  return (
    <div className="grid grid-cols-2 sm:grid-cols-2 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-6 mt-6">
      {statsData.map((stat, index) => (
        <div key={index} className="bg-white shadow rounded-2xl  p-4 lg:px-6 ">
          <div className="flex justify-between mb-4">
            <div className="text-[16px] md:text-[18px] lg:text-[20px] text-[#828282]">
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
