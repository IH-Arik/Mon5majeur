'use client';

import React, { useState } from "react";
import Pagination from "@/components/shared/Pagination";

interface MatchData {
  id: string;
  match: string;
  league: string;
  score: string;
  status: string;
}

const initialMatches: MatchData[] = [
  { id: "1", match: "Team A vs Team B", league: "Summer Slam League", score: "12-75", status: "Pending" },
  { id: "2", match: "Team C vs Team D", league: "Champions Cup", score: "98-102", status: "Pending" },
  { id: "3", match: "Team E vs Team F", league: "Pro League", score: "76-65", status: "Disputed" },
  { id: "4", match: "Team G vs Team H", league: "Winter League", score: "112-90", status: "Pending" },
  { id: "5", match: "Team I vs Team J", league: "City League", score: "89-84", status: "Disputed" },
  { id: "6", match: "Team K vs Team L", league: "National Cup", score: "70-75", status: "Pending" },
  { id: "7", match: "Team M vs Team N", league: "Premier League", score: "102-99", status: "Disputed" },
  { id: "8", match: "Team O vs Team P", league: "All Stars", score: "88-91", status: "Disputed" },
  { id: "9", match: "Team I vs Team J", league: "City League", score: "89-84", status: "Disputed" },
  { id: "10", match: "Team K vs Team L", league: "National Cup", score: "70-75", status: "Pending" },
  { id: "11", match: "Team M vs Team N", league: "Premier League", score: "102-99", status: "Disputed" },
  { id: "12", match: "Team O vs Team P", league: "All Stars", score: "88-91", status: "Disputed" },
];

export default function MatchManagement() {
  // Filter only Pending and Disputed matches
  const filteredMatches = initialMatches.filter(
    (match) => match.status === "Pending" || match.status === "Disputed"
  );

  const [matches, setMatches] = useState(filteredMatches);
  const [currentPage, setCurrentPage] = useState(1);

  const matchesPerPage = 10; // Show 10 matches per page
  const totalPages = Math.ceil(matches.length / matchesPerPage);
  const startIndex = (currentPage - 1) * matchesPerPage;
  const paginatedMatches = matches.slice(startIndex, startIndex + matchesPerPage);

  const handlePageChange = (page: number) => setCurrentPage(page);

  const getStatusClasses = (status: string) => {
    switch (status) {
      case "Pending":
        return "bg-yellow-100 text-yellow-800";
      case "Disputed":
        return "bg-red-100 text-red-800";
      default:
        return "";
    }
  };

  return (
    <div className="bg-white shadow rounded-lg overflow-hidden mt-6">
      <div className="p-6">
        <div className="overflow-x-auto">
          <table className="min-w-full text-sm text-left border-collapse">
            <thead className="text-[#828282] text-[12px] tracking-wider">
              <tr>
                <th className="px-6 py-3 font-semibold">Match</th>
                <th className="px-6 py-3 font-semibold">League</th>
                <th className="px-6 py-3 font-semibold">Score</th>
                <th className="px-6 py-3 font-semibold">Status</th>
              </tr>
            </thead>
            <tbody>
              {paginatedMatches.map((match) => (
                <tr key={match.id} className="odd:bg-[#f8f8f8] even:bg-white transition">
                  <td className="px-6 py-4 text-gray-800">{match.match}</td>
                  <td className="px-6 py-4 text-gray-800">{match.league}</td>
                  <td className="px-6 py-4 font-medium text-gray-900">{match.score}</td>
                  <td className="px-6 py-4">
                    <span
                      className={`px-2 py-1 rounded-full text-xs font-medium ${getStatusClasses(match.status)}`}
                    >
                      {match.status}
                    </span>
                  </td>
                </tr>
              ))}
              {paginatedMatches.length === 0 && (
                <tr>
                  <td colSpan={4} className="px-6 py-4 text-center text-gray-500">
                    No matches found.
                  </td>
                </tr>
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
  );
}
