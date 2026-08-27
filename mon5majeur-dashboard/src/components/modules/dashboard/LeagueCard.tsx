"use client";

import { FiUserPlus, FiUsers } from "react-icons/fi";
import { IoGameControllerOutline } from "react-icons/io5";
import { useEffect, useState } from "react";
import baseApi from "@/api/baseAPi";
import { ENDPOINTS } from "@/api/endPoints";

interface LeagueStats {
  total_global_leagues: number;
  total_public_leagues: number;
  total_private_leagues: number;
  private_league_players: number;
  global_league_players: number;
}

export default function LeagueCard() {
  const [stats, setStats] = useState<LeagueStats>({
    total_global_leagues: 0,
    total_public_leagues: 0,
    total_private_leagues: 0,
    private_league_players: 0,
    global_league_players: 0,
  });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchStats = async () => {
      try {
        setLoading(true);
        const response = await baseApi.get<LeagueStats>(ENDPOINTS.adminLeagueStats);
        setStats(response.data);
      } catch (error) {
        console.error("Error fetching league stats:", error);
      } finally {
        setLoading(false);
      }
    };

    fetchStats();
  }, []);

  const statsData = [
    { label: "Total Global League", value: stats.total_global_leagues, icon: <IoGameControllerOutline /> },
    { label: "Total Public Leagues", value: stats.total_public_leagues, icon: <FiUsers /> },
    { label: "Total Private Leagues", value: stats.total_private_leagues, icon: <FiUserPlus /> },
    { label: "Global League Players", value: stats.global_league_players, icon: <FiUsers /> },
    { label: "Private League Players", value: stats.private_league_players, icon: <FiUserPlus /> },
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
