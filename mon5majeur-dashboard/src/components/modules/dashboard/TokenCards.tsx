"use client";

import { FiPackage } from "react-icons/fi";
import { MdDone } from "react-icons/md";
import { TbCoins } from "react-icons/tb";
import { RiCoinLine } from "react-icons/ri";
import { useEffect, useState } from "react";
import baseApi from "@/api/baseAPi";
import { ENDPOINTS } from "@/api/endPoints";

interface TokenPackStats {
  total_packs: number;
  active_packs: number;
  tokens_sold: number;
  purchases_count: number;
}

export default function TokenCards() {
  const [stats, setStats] = useState<TokenPackStats>({
    total_packs: 0,
    active_packs: 0,
    tokens_sold: 0,
    purchases_count: 0,
  });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchStats = async () => {
      try {
        setLoading(true);
        const response = await baseApi.get<TokenPackStats>(ENDPOINTS.adminTokenPackStats);
        setStats(response.data);
      } catch (error) {
        console.error("Error fetching token pack stats:", error);
      } finally {
        setLoading(false);
      }
    };

    fetchStats();
  }, []);

  const statsData = [
    { label: "Total Token Packs", value: stats.total_packs, icon: <FiPackage /> },
    {
      label: "Active Token Packs",
      value: stats.active_packs,
      icon: <MdDone className="border rounded-full p-0.5" />,
    },
    { label: "Total Tokens Sold", value: stats.tokens_sold, icon: <TbCoins /> },
    { label: "Purchases Made", value: stats.purchases_count, icon: <RiCoinLine /> },
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
