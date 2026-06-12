'use client';

import React, { useState } from "react";
import { GoSearch } from "react-icons/go";
import { RiDeleteBin6Line } from "react-icons/ri";
import Pagination from "@/components/shared/Pagination";
import Swal from "sweetalert2";
import { CiEdit } from "react-icons/ci";
import { FiPlus } from "react-icons/fi";
import CreateToken from "./CreateToken";
import EditToken from "./EditToken";

type UserStatus = "Active" | "Inactive";

interface User {
    id: string;
    pack_name: string;
    token: number;
    status: UserStatus;
    price: number;
    created: Date;
    expired: Date;
}


const initialUsers: User[] = [
    { id: "1", pack_name: "Welcome Bonus", token: 200, status: "Active", price: 50, created: new Date("2023-01-20"), expired: new Date("2024-01-20") },
    { id: "2", pack_name: "Referral Bonus", token: 400, status: "Active", price: 30, created: new Date("2024-01-20"), expired: new Date("2025-01-20") },
    { id: "3", pack_name: "Seasonal Bonus", token: 200, status: "Inactive", price: 100, created: new Date("2023-06-20"), expired: new Date("2024-06-20") },
    { id: "4", pack_name: "Holiday Bonus", token: 400, status: "Active", price: 25, created: new Date("2023-01-20"), expired: new Date("2023-12-20") },
    { id: "5", pack_name: "VIP Bonus", token: 200, status: "Active", price: 75, created: new Date("2023-01-20"), expired: new Date("2024-01-20") },
    { id: "6", pack_name: "Seasonal Bonus", token: 200, status: "Inactive", price: 100, created: new Date("2023-06-20"), expired: new Date("2024-06-20") },
    { id: "7", pack_name: "Holiday Bonus", token: 400, status: "Active", price: 25, created: new Date("2023-01-20"), expired: new Date("2023-12-20") },
    { id: "8", pack_name: "VIP Bonus", token: 200, status: "Active", price: 75, created: new Date("2023-01-20"), expired: new Date("2024-01-20") },
];

const statusColors: Record<UserStatus, string> = {
    Active: "text-green-500",
    Inactive: "text-red-400",
};

const statusOptions: UserStatus[] = ["Active", "Inactive"];

export default function AllToken() {
    const [users, setUsers] = useState<User[]>(initialUsers);
    const [currentPage, setCurrentPage] = useState(1);
    const [isOpen, setIsOpen] = useState(false); // Create bonus modal
    const [isEditOpen, setIsEditOpen] = useState(false); // Edit bonus modal
    const [selectedBonus, setSelectedBonus] = useState<User | null>(null);

    const usersPerPage = 6;
    const totalPages = Math.ceil(users.length / usersPerPage);
    const startIndex = (currentPage - 1) * usersPerPage;
    const paginatedUsers = users.slice(startIndex, startIndex + usersPerPage);

    const handlePageChange = (page: number) => setCurrentPage(page);

    const handleCreateBonus = () => {
        setIsOpen(true);
    };

    const handleStatusChange = (index: number, newStatus: UserStatus) => {
        const updatedUsers = [...users];
        const globalIndex = startIndex + index;
        updatedUsers[globalIndex].status = newStatus;
        setUsers(updatedUsers);
    };

    const handleEditClick = (bonus: User) => {
        setSelectedBonus(bonus);
        setIsEditOpen(true);
    };

    const handleDelete = (userId: string) => {
        Swal.fire({
            title: "Are you sure?",
            text: "You won't be able to revert this!",
            icon: "warning",
            showCancelButton: true,
            confirmButtonColor: "#319EE1",
            cancelButtonColor: "#d33",
            confirmButtonText: "Yes, delete it!",
        }).then((result) => {
            if (result.isConfirmed) {
                setUsers((prev) => prev.filter((user) => user.id !== userId));
                Swal.fire({
                    title: "Deleted!",
                    text: "User has been deleted.",
                    icon: "success",
                    confirmButtonColor: "#319EE1",
                });
                if ((users.length - 1) <= (currentPage - 1) * usersPerPage && currentPage > 1) {
                    setCurrentPage(currentPage - 1);
                }
            }
        });
    };

    // Format date to yyyy-mm-dd for input type date
    const formatDateForInput = (date: Date) => {
        return date.toISOString().split("T")[0];
    };

    // Format date for display in table (e.g. dd/mm/yyyy)
    const formatDateDisplay = (date: Date) => {
        return date.toLocaleDateString("en-GB");
    };

    return (
        <div>
            <div className="bg-white shadow rounded-lg overflow-hidden p-6">
                <h2 className="text-[22px] font-semibold">Token Packs</h2>
                <p className="mb-4 text-[#828282]">View, create, edit, and delete token packs for your users.</p>

                {/* Search */}
                <div className="flex flex-col md:flex-row justify-between">
                    <div className="flex items-center border border-[#828282] rounded px-3 py-2 gap-2 mb-6 w-full md:w-80 lg:w-full max-w-md">
                        <GoSearch className="text-gray-500 text-lg" />
                        <input type="text" placeholder="Search token packs..." className="w-full outline-none" />
                    </div>
                    <div>
                        <button
                            onClick={handleCreateBonus}
                            className="flex cursor-pointer w-full items-center gap-2 bg-[#E8632C] text-white px-4 py-2 rounded-xl hover:bg-[#d85b25]"
                        >
                            <FiPlus className="text-white text-lg " />
                            Create New Bonus
                        </button>
                    </div>
                </div>

                {/* Table */}
                <div className="overflow-x-auto">
                    <table className="min-w-full text-sm text-left">
                        <thead className="text-[#828282] text-[12px]">
                            <tr>
                                <th className="px-6 py-3">Pack Name</th>
                                <th className="px-6 py-3">Token</th>
                                <th className="px-6 py-3">Price</th>
                                <th className="px-6 py-3">Status</th>
                                {/* <th className="px-6 py-3">Created</th>
                <th className="px-6 py-3">Expired</th> */}
                                <th className="px-6 py-3">Action</th>
                            </tr>
                        </thead>
                        <tbody>
                            {paginatedUsers.map((user, i) => (
                                <tr key={user.id} className={`${i % 2 === 0 ? 'bg-[#f8f8f8]' : 'bg-white'}`}>
                                    <td className="px-6 py-4">{user.pack_name}</td>
                                    <td className="px-6 py-4">{user.token}</td>
                                    <td className="px-6 py-4">$ {user.price}</td>
                                    <td className="px-6 py-4 font-medium">
                                        <select
                                            value={user.status}
                                            onChange={(e) => handleStatusChange(i, e.target.value as UserStatus)}
                                            className={`bg-transparent font-medium focus:outline-none ${statusColors[user.status]}`}
                                        >
                                            {statusOptions.map((status) => (
                                                <option key={status} value={status} className="text-black">{status}</option>
                                            ))}
                                        </select>
                                    </td>
                                    {/* <td className="px-6 py-4">{formatDateDisplay(user.created)}</td>
                  <td className="px-6 py-4">{formatDateDisplay(user.expired)}</td> */}
                                    <td className="flex gap-4 px-6 py-4">
                                        <div
                                            onClick={() => handleEditClick(user)}
                                            className="text-blue-500 cursor-pointer hover:text-blue-700 text-[24px]"
                                            title="Edit"
                                        >
                                            <CiEdit />
                                        </div>
                                        <div
                                            onClick={() => handleDelete(user.id)}
                                            className="text-red-500 cursor-pointer hover:text-red-700 flex justify-center text-[20px]"
                                        >
                                            <RiDeleteBin6Line />
                                        </div>
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>

                {/* Pagination */}
                <Pagination currentPage={currentPage} totalPages={totalPages} onPageChange={handlePageChange} />
            </div>

            {/* Create Bonus Modal */}
            <CreateToken isOpen={isOpen} onClose={() => setIsOpen(false)} />

            {/* Edit Bonus Modal */}
            {isEditOpen && selectedBonus && (
                <EditToken
                    isOpen={isEditOpen}
                    onClose={() => setIsEditOpen(false)}
                    bonusData={{
                        packName: selectedBonus.pack_name,
                        token: selectedBonus.token.toString(),
                        price: selectedBonus.price.toString(),
                        createdDate: formatDateForInput(selectedBonus.created),
                        expiredDate: formatDateForInput(selectedBonus.expired),
                        // logoUrl: selectedBonus.logoUrl || undefined, // add if you have it
                    }}
                />
            )}
        </div>
    );
}
