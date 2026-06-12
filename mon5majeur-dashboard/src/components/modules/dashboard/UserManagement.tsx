'use client';

import Image from "next/image";
import React, { useState } from "react";
import { GoSearch } from "react-icons/go";
import { RiDeleteBin6Line } from "react-icons/ri";
import Pagination from "@/components/shared/Pagination";
import Swal from 'sweetalert2';

type UserStatus = "Active" | "Pending" | "Banned" | "Inactive";

interface User {
    id: string;
    name: string;
    email: string;
    status: UserStatus;
    joined: string;
    image?: string;
}

const initialUsers: User[] = [
    {
        id: "1",
        name: "Alice Johnson",
        email: "alice@example.com",
        status: "Active",
        joined: "2023-01-20",
        image: "https://randomuser.me/api/portraits/women/1.jpg"
    },
    {
        id: "2",
        name: "Bob Smith",
        email: "bob@example.com",
        status: "Pending",
        joined: "2024-01-20",
        image: "https://randomuser.me/api/portraits/men/2.jpg"
    },
    {
        id: "3",
        name: "Charlie Brown",
        email: "charlie@example.com",
        status: "Banned",
        joined: "2023-06-20",
        image: "https://randomuser.me/api/portraits/men/3.jpg"
    },
    {
        id: "4",
        name: "Diana Prince",
        email: "diana@example.com",
        status: "Inactive",
        joined: "2023-01-20",
        image: "https://randomuser.me/api/portraits/women/4.jpg"
    },
    {
        id: "5",
        name: "Eve Adams",
        email: "eve@example.com",
        status: "Active",
        joined: "2023-01-20",
        image: "https://randomuser.me/api/portraits/women/5.jpg"
    },
    {
        id: "6",
        name: "Charlie Brown",
        email: "charlie@example.com",
        status: "Banned",
        joined: "2023-06-20",
        image: "https://randomuser.me/api/portraits/men/3.jpg"
    },
    {
        id: "7",
        name: "Diana Prince",
        email: "diana@example.com",
        status: "Inactive",
        joined: "2023-01-20",
        image: "https://randomuser.me/api/portraits/women/4.jpg"
    },
    {
        id: "8",
        name: "Eve Adams",
        email: "eve@example.com",
        status: "Active",
        joined: "2023-01-20",
        image: "https://randomuser.me/api/portraits/women/5.jpg"
    }
];

const statusColors: Record<UserStatus, string> = {
    Active: "text-green-500",
    Pending: "text-blue-500",
    Banned: "text-red-500",
    Inactive: "text-red-400"
};



const statusOptions: UserStatus[] = ["Active", "Pending", "Banned", "Inactive"];

export default function UserManagement() {
    const [users, setUsers] = useState(initialUsers);
    const [currentPage, setCurrentPage] = useState(1);

    const usersPerPage = 6;
    const totalPages = Math.ceil(users.length / usersPerPage);
    const startIndex = (currentPage - 1) * usersPerPage;
    const paginatedUsers = users.slice(startIndex, startIndex + usersPerPage);

    const handlePageChange = (page: number) => {
        setCurrentPage(page);
    };

    const handleStatusChange = (index: number, newStatus: UserStatus) => {
        const updatedUsers = [...users];
        const globalIndex = startIndex + index;
        updatedUsers[globalIndex].status = newStatus;
        setUsers(updatedUsers);
    };



    const handleDelete = (userId: string) => {
        Swal.fire({
            title: "Are you sure?",
            text: "You won't be able to revert this!",
            icon: "warning",
            showCancelButton: true,
            confirmButtonColor: "#319EE1",
            cancelButtonColor: "#d33",
            confirmButtonText: "Yes, delete it!"
        }).then((result) => {
            if (result.isConfirmed) {
                setUsers((prev) => prev.filter((user) => user.id !== userId));

                Swal.fire({
                    title: "Deleted!",
                    text: "User has been deleted.",
                    icon: "success",
                    confirmButtonColor: "#319EE1"
                });

                // If the last user on the current page is deleted and the page becomes empty, move back one page
                if ((users.length - 1) <= (currentPage - 1) * usersPerPage && currentPage > 1) {
                    setCurrentPage(currentPage - 1);
                }
            }
        });
    };



    return (
        <div>
            <div className="bg-white shadow rounded-lg overflow-hidden">
                {/* Search bar */}
                <div className="px-2 md:px-0 md:pl-6 pt-6 grid md:grid-cols-2 gap-4">
                    <div className=" flex items-center border border-[#828282] rounded px-3 py-2 gap-2 w-full max-w-md">
                        <GoSearch className="text-gray-500 text-lg" />
                        <input
                            type="text"
                            placeholder="Search users by name or email..."
                            className="w-full outline-none"
                        />
                    </div>
                </div>

                {/* Table */}
                <div className="overflow-x-auto p-6">
                    <table className="min-w-full text-sm text-left">
                        <thead className="text-[#828282]">
                            <tr>
                                <th className="px-6 py-3">User</th>
                                <th className="px-6 py-3">Email</th>
                                <th className="px-6 py-3">Status</th>
                                <th className="px-6 py-3">Joined Date</th>
                                <th className="px-6 py-3">Action</th>
                            </tr>
                        </thead>
                        <tbody>
                            {paginatedUsers.map((user, i) => (
                                <tr key={i} className={`${i % 2 === 0 ? 'bg-[#f8f8f8]' : 'bg-white'}`}>
                                    <td className="px-6 py-4 flex items-center gap-2">
                                        <Image
                                            src={user.image || "/default-avatar.png"}
                                            alt={user.name}
                                            width={32}
                                            height={32}
                                            className="rounded-full object-cover"
                                        />
                                        {user.name}
                                    </td>
                                    <td className="px-6 py-4">{user.email}</td>
                                    <td className="px-6 py-4 font-medium">
                                        <div className="flex items-center gap-2">
                                            <select
                                                value={user.status}
                                                onChange={(e) =>
                                                    handleStatusChange(i, e.target.value as UserStatus)
                                                }
                                                className={`bg-transparent font-medium focus:outline-none ${statusColors[user.status]}`}
                                            >
                                                {statusOptions.map((status) => (
                                                    <option key={status} value={status} className="text-black">
                                                        {status}
                                                    </option>
                                                ))}
                                            </select>
                                        </div>
                                    </td>
                                    <td className="px-6 py-4">{user.joined}</td>
                                    <td onClick={() => handleDelete(user.id)} className="text-red-500 cursor-pointer hover:text-red-700 flex md:justify-center justify-start text-[20px]">
                                        <RiDeleteBin6Line />
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>

                {/* Pagination */}
                <Pagination
                    currentPage={currentPage}
                    totalPages={totalPages}
                    onPageChange={handlePageChange}
                />
            </div>
        </div>
    );
}
