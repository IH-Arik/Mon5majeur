/* eslint-disable @typescript-eslint/no-explicit-any */
"use client";

import React, { useState, useEffect } from "react";
import { GoSearch } from "react-icons/go";
import { RiDeleteBin6Line } from "react-icons/ri";
import Pagination from "@/components/shared/Pagination";
import Swal from "sweetalert2";
import { CiEdit } from "react-icons/ci";
import { FiPlus } from "react-icons/fi";
import CreateBonus from "./CreateBonus";
import EditBonus from "./EditBonus";
import baseApi from "@/api/baseAPi";
import { ENDPOINTS } from "@/api/endPoints";

type UserStatus = "Active" | "Comming soon" | "Inactive";

interface User {
  id: string;
  bonus_name: string;
  type: string;
  status: UserStatus;
  price: number;
  created: Date;
  expired: Date;
  // optionally add logoUrl here if available
}

interface ApiBonusResponse {
  id: number;
  bonus_name: string;
  bonus_type: string;
  status: boolean;
  price: number;
  created_at: string;
  expired_at: string;
}

const statusColors: Record<UserStatus, string> = {
  Active: "text-green-500",
  "Comming soon": "text-blue-500",
  Inactive: "text-red-400",
};

const statusOptions: UserStatus[] = ["Active", "Comming soon", "Inactive"];

export default function AllBonus() {
  const [users, setUsers] = useState<User[]>([]);
  const [currentPage, setCurrentPage] = useState(1);
  const [isOpen, setIsOpen] = useState(false); // Create bonus modal
  const [isEditOpen, setIsEditOpen] = useState(false); // Edit bonus modal
  const [selectedBonus, setSelectedBonus] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  const usersPerPage = 6;
  const totalPages = Math.ceil(users.length / usersPerPage);
  const startIndex = (currentPage - 1) * usersPerPage;
  const paginatedUsers = users.slice(startIndex, startIndex + usersPerPage);

  // Parse date string in format "DD-MM-YYYY HH:mm:ss"
  const parseApiDate = (dateStr: string) => {
    const [datePart, timePart] = dateStr.split(" ");
    const [day, month, year] = datePart.split("-");
    return new Date(`${year}-${month}-${day}T${timePart}`);
  };

  // Fetch all bonuses
  useEffect(() => {
    const fetchBonuses = async () => {
      try {
        setLoading(true);
        const response = await baseApi.get<ApiBonusResponse[]>(ENDPOINTS.allBonus);

        // Map API response to User interface
        const bonuses = response.data.map((bonus) => ({
          id: bonus.id.toString(),
          bonus_name: bonus.bonus_name,
          type: bonus.bonus_type,
          status: bonus.status ? "Active" : ("Inactive" as UserStatus),
          price: bonus.price,
          created: parseApiDate(bonus.created_at),
          expired: parseApiDate(bonus.expired_at),
        }));

        setUsers(bonuses);
      } catch (error) {
        console.error("Error fetching bonuses:", error);
        Swal.fire({
          title: "Error!",
          text: "Failed to fetch bonuses",
          icon: "error",
          confirmButtonColor: "#319EE1",
        });
      } finally {
        setLoading(false);
      }
    };

    fetchBonuses();
  }, []);

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
        if (
          users.length - 1 <= (currentPage - 1) * usersPerPage &&
          currentPage > 1
        ) {
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
        <h2 className="text-[22px] font-semibold">Manage Bonuses</h2>
        <p className="mb-4 text-[#828282]">
          View, create, edit, and delete bonus offers for your users.
        </p>

        {/* Search */}
        <div className="flex flex-col md:flex-row justify-between">
          <div className="flex items-center border border-[#828282] rounded px-3 py-2 gap-2 mb-6 w-full md:w-80 lg:w-full max-w-md">
            <GoSearch className="text-gray-500 text-lg" />
            <input
              type="text"
              placeholder="Search users by bonus name..."
              className="w-full outline-none"
            />
          </div>
          <div>
            <button
              onClick={handleCreateBonus}
              className="flex cursor-pointer w-full items-center gap-2 bg-[#E8632C] text-white px-4 py-2 rounded-xl hover:bg-[#d85b25]"
            >
              <FiPlus className="text-white text-lg" />
              Create New Bonus
            </button>
          </div>
        </div>

        {/* Table */}
        <div className="overflow-x-auto">
          <table className="min-w-full text-sm text-left">
            <thead className="text-[#828282] text-[12px]">
              <tr>
                <th className="px-6 py-3">Bonus Name</th>
                <th className="px-6 py-3">Type</th>
                <th className="px-6 py-3">Status</th>
                <th className="px-6 py-3">Price</th>
                <th className="px-6 py-3">Created</th>
                <th className="px-6 py-3">Expired</th>
                <th className="px-6 py-3">Action</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={7} className="text-center py-8 text-gray-500">
                    Loading bonuses...
                  </td>
                </tr>
              ) : paginatedUsers.length === 0 ? (
                <tr>
                  <td colSpan={7} className="text-center py-8 text-gray-500">
                    No bonuses found
                  </td>
                </tr>
              ) : (
                paginatedUsers.map((user, i) => (
                  <tr
                    key={user.id}
                    className={`${i % 2 === 0 ? "bg-[#f8f8f8]" : "bg-white"}`}
                  >
                    <td className="px-6 py-4">{user.bonus_name}</td>
                    <td className="px-6 py-4">{user.type}</td>
                    <td className="px-6 py-4 font-medium">
                      <select
                        value={user.status}
                        onChange={(e) =>
                          handleStatusChange(i, e.target.value as UserStatus)
                        }
                        className={`bg-transparent font-medium focus:outline-none ${statusColors[user.status]}`}
                      >
                        {statusOptions.map((status) => (
                          <option
                            key={status}
                            value={status}
                            className="text-black"
                          >
                            {status}
                          </option>
                        ))}
                      </select>
                    </td>
                    <td className="px-6 py-4">{user.price}</td>
                    <td className="px-6 py-4">
                      {formatDateDisplay(user.created)}
                    </td>
                    <td className="px-6 py-4">
                      {formatDateDisplay(user.expired)}
                    </td>
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
                ))
              )}
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

      {/* Create Bonus Modal */}
      <CreateBonus isOpen={isOpen} onClose={() => setIsOpen(false)} />

      {/* Edit Bonus Modal */}
      {isEditOpen && selectedBonus && (
        <EditBonus
          isOpen={isEditOpen}
          onClose={() => setIsEditOpen(false)}
          bonusData={{
            bonusName: selectedBonus.bonus_name,
            type: selectedBonus.type,
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
