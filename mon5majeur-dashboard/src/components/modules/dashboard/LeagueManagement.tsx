'use client';

import React, { useState } from "react";
import Pagination from "@/components/shared/Pagination";
import MonthYearCalendar from "@/components/shared/MonthYearCalendar";

interface User {
    id: string;
    rank: string;
    teamname: string;
    score: string;
    bouns?: string;
}

const initialUsers: User[] = [
    { id: "1", rank: "1", teamname: "Team Alpha", score: "1200", bouns: "Platinum" },
    { id: "2", rank: "2", teamname: "Team Beta", score: "1150", bouns: "Platinum" },
    { id: "3", rank: "3", teamname: "Team Gamma", score: "1100", bouns: "Gold" },
    { id: "4", rank: "4", teamname: "Team Delta", score: "1050" },
    { id: "5", rank: "5", teamname: "Team Epsilon", score: "1000", bouns: "Diamond" },
    { id: "6", rank: "6", teamname: "Team Zeta", score: "950" },
    { id: "7", rank: "7", teamname: "Team Eta", score: "900", bouns: "Platinum" },
    { id: "8", rank: "8", teamname: "Team Theta", score: "850", bouns: "Diamond" },
];

export default function LeagueManagement() {
    const [users, setUsers] = useState(initialUsers);
    const [currentPage, setCurrentPage] = useState(1);

    const usersPerPage = 6;
    const totalPages = Math.ceil(users.length / usersPerPage);
    const startIndex = (currentPage - 1) * usersPerPage;
    const paginatedUsers = users.slice(startIndex, startIndex + usersPerPage);

    const handlePageChange = (page: number) => {
        setCurrentPage(page);
    };

    return (
        <div>
            <div className="flex justify-between py-4">
                <h2 className=' text-[18px] md:text-[26px] font-semibold'>Top Players</h2>
                <MonthYearCalendar></MonthYearCalendar>
            </div>
            <div className="bg-white shadow rounded-lg overflow-hidden">
                <div className="p-6 pt-10">
                    <h2 className="text-xl font-semibold mb-4">Leaderboard</h2>
                    <div className="overflow-x-auto">
                        <table className="min-w-full text-sm text-left">
                            <thead className="text-[#828282]">
                                <tr>
                                    <th className="px-6 py-3">Rank</th>
                                    <th className="px-6 py-3">Teamname</th>
                                    <th className="px-6 py-3">Score</th>
                                    <th className="px-6 py-3">Bouns</th>
                                </tr>
                            </thead>
                            <tbody>
                                {paginatedUsers.map((user) => (
                                    <tr key={user.id} className="odd:bg-[#f8f8f8] even:bg-white ">
                                        <td className="px-6 py-4">{user.rank}</td>
                                        <td className="px-6 py-4">{user.teamname}</td>
                                        <td className="px-6 py-4">{user.score}</td>
                                        <td className="px-6 py-4">{user.bouns || "-"}</td>
                                    </tr>
                                ))}
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
