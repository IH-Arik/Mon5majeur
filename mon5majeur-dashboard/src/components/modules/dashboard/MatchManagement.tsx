"use client";

import React, { useEffect, useState } from "react";
import Swal from "sweetalert2";
import Pagination from "@/components/shared/Pagination";
import baseApi from "@/api/baseAPi";
import { ENDPOINTS } from "@/api/endPoints";

type MatchStatusFilter = "stuck" | "completed";

interface MatchRow {
  id: string;
  league_name: string;
  home_team: string;
  away_team: string;
  nba_date: string;
  status: string;
  home_score: number | null;
  away_score: number | null;
}

interface MatchPage {
  data: MatchRow[];
  total: number;
  page: number;
  size: number;
}

const pageSize = 10;

export default function MatchManagement() {
  const [filter, setFilter] = useState<MatchStatusFilter>("stuck");
  const [matches, setMatches] = useState<MatchRow[]>([]);
  const [total, setTotal] = useState(0);
  const [currentPage, setCurrentPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [actingId, setActingId] = useState<string | null>(null);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [homeInput, setHomeInput] = useState("");
  const [awayInput, setAwayInput] = useState("");

  const totalPages = Math.max(1, Math.ceil(total / pageSize));

  const fetchMatches = async (status: MatchStatusFilter, page: number) => {
    try {
      setLoading(true);
      const response = await baseApi.get<MatchPage>(ENDPOINTS.adminMatches, {
        params: { status, page, size: pageSize },
      });
      setMatches(response.data.data);
      setTotal(response.data.total);
    } catch (error) {
      console.error("Error fetching matches:", error);
      Swal.fire({
        title: "Error!",
        text: "Failed to fetch matches",
        icon: "error",
        confirmButtonColor: "#319EE1",
      });
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchMatches(filter, currentPage);
  }, [filter, currentPage]);

  const handleFilterChange = (next: MatchStatusFilter) => {
    setFilter(next);
    setCurrentPage(1);
  };

  const handleRescore = async (match: MatchRow) => {
    setActingId(match.id);
    try {
      await baseApi.post(ENDPOINTS.adminMatchRescore(match.id));
      Swal.fire({
        title: "Rescored!",
        text: "The match was scored from each side's saved lineup.",
        icon: "success",
        confirmButtonColor: "#319EE1",
      });
      fetchMatches(filter, currentPage);
    } catch (error) {
      console.error("Error rescoring match:", error);
      Swal.fire({
        title: "Could not rescore",
        text:
          (error as { response?: { data?: { detail?: string } } })?.response?.data?.detail ||
          "Check that the NBA games for this night are marked final.",
        icon: "error",
        confirmButtonColor: "#319EE1",
      });
    } finally {
      setActingId(null);
    }
  };

  const startEdit = (match: MatchRow) => {
    setEditingId(match.id);
    setHomeInput(String(match.home_score ?? 0));
    setAwayInput(String(match.away_score ?? 0));
  };

  const handleSaveScore = async (match: MatchRow) => {
    const home = Number(homeInput);
    const away = Number(awayInput);
    if (!Number.isFinite(home) || !Number.isFinite(away) || home < 0 || away < 0) {
      Swal.fire({
        title: "Invalid score",
        text: "Scores must be non-negative numbers",
        icon: "error",
        confirmButtonColor: "#319EE1",
      });
      return;
    }

    setActingId(match.id);
    try {
      await baseApi.patch(ENDPOINTS.adminMatchScore(match.id), {
        home_score: home,
        away_score: away,
      });
      setEditingId(null);
      fetchMatches(filter, currentPage);
    } catch (error) {
      console.error("Error overriding score:", error);
      Swal.fire({
        title: "Error!",
        text: "Failed to update score",
        icon: "error",
        confirmButtonColor: "#319EE1",
      });
    } finally {
      setActingId(null);
    }
  };

  const formatDate = (iso: string) => {
    const d = new Date(iso);
    return Number.isNaN(d.getTime()) ? iso : d.toLocaleDateString("en-GB");
  };

  return (
    <div className="bg-white shadow rounded-lg overflow-hidden p-6">
      <div className="flex gap-4 mb-6">
        <button
          onClick={() => handleFilterChange("stuck")}
          className={`px-4 py-2 rounded cursor-pointer ${
            filter === "stuck" ? "bg-[#E8632C] text-white" : "bg-gray-200 text-gray-700"
          }`}
        >
          Awaiting Score
        </button>
        <button
          onClick={() => handleFilterChange("completed")}
          className={`px-4 py-2 rounded cursor-pointer ${
            filter === "completed" ? "bg-[#E8632C] text-white" : "bg-gray-200 text-gray-700"
          }`}
        >
          Completed (corrections)
        </button>
      </div>

      <div className="overflow-x-auto">
        <table className="min-w-full text-sm text-left">
          <thead className="text-[#828282]">
            <tr>
              <th className="px-6 py-3">League</th>
              <th className="px-6 py-3">Match</th>
              <th className="px-6 py-3">Night</th>
              <th className="px-6 py-3">Score</th>
              <th className="px-6 py-3">Action</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={5} className="text-center py-8 text-gray-500">
                  Loading matches...
                </td>
              </tr>
            ) : matches.length === 0 ? (
              <tr>
                <td colSpan={5} className="text-center py-8 text-gray-500">
                  {filter === "stuck" ? "No matches awaiting score" : "No completed matches"}
                </td>
              </tr>
            ) : (
              matches.map((match, i) => (
                <tr key={match.id} className={i % 2 === 0 ? "bg-[#f8f8f8]" : "bg-white"}>
                  <td className="px-6 py-4">{match.league_name}</td>
                  <td className="px-6 py-4">
                    {match.home_team} vs {match.away_team}
                  </td>
                  <td className="px-6 py-4">{formatDate(match.nba_date)}</td>
                  <td className="px-6 py-4">
                    {editingId === match.id ? (
                      <div className="flex items-center gap-2">
                        <input
                          type="number"
                          min={0}
                          value={homeInput}
                          onChange={(e) => setHomeInput(e.target.value)}
                          className="w-16 border border-[#828282] rounded px-2 py-1"
                        />
                        -
                        <input
                          type="number"
                          min={0}
                          value={awayInput}
                          onChange={(e) => setAwayInput(e.target.value)}
                          className="w-16 border border-[#828282] rounded px-2 py-1"
                        />
                      </div>
                    ) : match.home_score !== null && match.away_score !== null ? (
                      `${match.home_score} - ${match.away_score}`
                    ) : (
                      "—"
                    )}
                  </td>
                  <td className="px-6 py-4">
                    {filter === "stuck" ? (
                      <button
                        onClick={() => handleRescore(match)}
                        disabled={actingId === match.id}
                        className="text-blue-500 hover:text-blue-700 cursor-pointer disabled:opacity-50"
                      >
                        {actingId === match.id ? "Scoring..." : "Rescore"}
                      </button>
                    ) : editingId === match.id ? (
                      <div className="flex gap-3">
                        <button
                          onClick={() => handleSaveScore(match)}
                          disabled={actingId === match.id}
                          className="text-green-600 hover:text-green-800 cursor-pointer disabled:opacity-50"
                        >
                          Save
                        </button>
                        <button
                          onClick={() => setEditingId(null)}
                          className="text-gray-500 hover:text-gray-700 cursor-pointer"
                        >
                          Cancel
                        </button>
                      </div>
                    ) : (
                      <button
                        onClick={() => startEdit(match)}
                        className="text-blue-500 hover:text-blue-700 cursor-pointer"
                      >
                        Override Score
                      </button>
                    )}
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
        onPageChange={setCurrentPage}
      />
    </div>
  );
}
