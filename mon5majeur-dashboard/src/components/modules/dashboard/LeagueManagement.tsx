"use client";

import React, { useEffect, useState } from "react";
import Pagination from "@/components/shared/Pagination";
import MonthYearCalendar from "@/components/shared/MonthYearCalendar";
import baseApi from "@/api/baseAPi";
import { ENDPOINTS } from "@/api/endPoints";

interface LeaderboardRow {
  rank: number;
  user_id: string;
  team_name: string;
  score: number;
  monthly_winner: boolean;
}

const rowsPerPage = 6;

export default function LeagueManagement() {
  const now = new Date();
  const [year, setYear] = useState(now.getFullYear());
  const [month, setMonth] = useState(now.getMonth() + 1);
  const [rows, setRows] = useState<LeaderboardRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [currentPage, setCurrentPage] = useState(1);

  const totalPages = Math.max(1, Math.ceil(rows.length / rowsPerPage));
  const startIndex = (currentPage - 1) * rowsPerPage;
  const paginatedRows = rows.slice(startIndex, startIndex + rowsPerPage);

  useEffect(() => {
    const fetchLeaderboard = async () => {
      try {
        setLoading(true);
        const response = await baseApi.get<{ rows: LeaderboardRow[] }>(
          ENDPOINTS.adminGlobalLeaderboard,
          { params: { year, month } },
        );
        setRows(response.data.rows);
        setCurrentPage(1);
      } catch (error) {
        console.error("Error fetching global leaderboard:", error);
      } finally {
        setLoading(false);
      }
    };

    fetchLeaderboard();
  }, [year, month]);

  const handleMonthChange = (y: number, m: number) => {
    setYear(y);
    setMonth(m);
  };

  const handlePageChange = (page: number) => setCurrentPage(page);

  return (
    <div>
      <div className="flex justify-between py-4">
        <h2 className="text-[18px] md:text-[26px] font-semibold">Top Players</h2>
        <MonthYearCalendar onChange={handleMonthChange} />
      </div>
      <div className="bg-white shadow rounded-lg overflow-hidden">
        <div className="p-6 pt-10">
          <h2 className="text-xl font-semibold mb-4">Global League Leaderboard</h2>
          <div className="overflow-x-auto">
            <table className="min-w-full text-sm text-left">
              <thead className="text-[#828282]">
                <tr>
                  <th className="px-6 py-3">Rank</th>
                  <th className="px-6 py-3">Team Name</th>
                  <th className="px-6 py-3">Score</th>
                  <th className="px-6 py-3">Reward</th>
                </tr>
              </thead>
              <tbody>
                {loading ? (
                  <tr>
                    <td colSpan={4} className="text-center py-8 text-gray-500">
                      Loading leaderboard...
                    </td>
                  </tr>
                ) : paginatedRows.length === 0 ? (
                  <tr>
                    <td colSpan={4} className="text-center py-8 text-gray-500">
                      No Global League activity this month
                    </td>
                  </tr>
                ) : (
                  paginatedRows.map((row) => (
                    <tr key={row.user_id} className="odd:bg-[#f8f8f8] even:bg-white ">
                      <td className="px-6 py-4">{row.rank}</td>
                      <td className="px-6 py-4">{row.team_name}</td>
                      <td className="px-6 py-4">{row.score}</td>
                      <td className="px-6 py-4">
                        {row.monthly_winner ? "🏆 Monthly Winner" : "-"}
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>

          <Pagination
            currentPage={currentPage}
            totalPages={totalPages}
            onPageChange={handlePageChange}
          />
        </div>
      </div>
    </div>
  );
}
