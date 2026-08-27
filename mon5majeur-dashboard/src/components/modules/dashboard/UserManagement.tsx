"use client";

import Image from "next/image";
import React, { useEffect, useState } from "react";
import { GoSearch } from "react-icons/go";
import { RiDeleteBin6Line } from "react-icons/ri";
import Pagination from "@/components/shared/Pagination";
import Swal from "sweetalert2";
import baseApi from "@/api/baseAPi";
import { ENDPOINTS } from "@/api/endPoints";

type UserStatus = "Active" | "Pending" | "Banned" | "Inactive";

interface ApiUser {
  id: string;
  email: string;
  full_name: string | null;
  avatar_url: string | null;
  status: UserStatus;
  created_at: string;
}

interface ApiPage<T> {
  data: T[];
  meta: { page: number; size: number; total: number; pages: number };
}

// Changing status here is the only way the dashboard edits is_active /
// is_verified / is_banned — it mirrors the exact state machine the backend
// derives `status` from (see User.status in the backend), so a change here
// never lands on a combination the backend itself wouldn't produce.
const STATUS_PAYLOAD: Record<UserStatus, Record<string, boolean>> = {
  Active: { is_banned: false, is_active: true, is_verified: true },
  Pending: { is_banned: false, is_active: true, is_verified: false },
  Banned: { is_banned: true },
  Inactive: { is_banned: false, is_active: false },
};

const statusColors: Record<UserStatus, string> = {
  Active: "text-green-500",
  Pending: "text-blue-500",
  Banned: "text-red-500",
  Inactive: "text-red-400",
};

const statusOptions: UserStatus[] = ["Active", "Pending", "Banned", "Inactive"];

const usersPerPage = 6;

export default function UserManagement() {
  const [users, setUsers] = useState<ApiUser[]>([]);
  const [totalPages, setTotalPages] = useState(1);
  const [currentPage, setCurrentPage] = useState(1);
  const [search, setSearch] = useState("");
  const [loading, setLoading] = useState(true);
  const [updatingId, setUpdatingId] = useState<string | null>(null);

  const fetchUsers = async (page: number, searchTerm: string) => {
    try {
      setLoading(true);
      const response = await baseApi.get<ApiPage<ApiUser>>(ENDPOINTS.adminUsersList, {
        params: { page, size: usersPerPage, search: searchTerm || undefined },
      });
      setUsers(response.data.data);
      setTotalPages(Math.max(1, response.data.meta.pages));
    } catch (error) {
      console.error("Error fetching users:", error);
      Swal.fire({
        title: "Error!",
        text: "Failed to fetch users",
        icon: "error",
        confirmButtonColor: "#319EE1",
      });
    } finally {
      setLoading(false);
    }
  };

  // Debounce search so every keystroke doesn't fire a request.
  useEffect(() => {
    const timeout = setTimeout(() => {
      setCurrentPage(1);
      fetchUsers(1, search);
    }, 400);
    return () => clearTimeout(timeout);
  }, [search]);

  useEffect(() => {
    fetchUsers(currentPage, search);
    // `search` is intentionally excluded: the debounced effect above already
    // refetches on search changes (and resets to page 1) — adding it here
    // too would fire a second, non-debounced request per keystroke.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [currentPage]);

  const handlePageChange = (page: number) => setCurrentPage(page);

  const handleStatusChange = async (user: ApiUser, newStatus: UserStatus) => {
    setUpdatingId(user.id);
    try {
      const response = await baseApi.patch<ApiUser>(
        ENDPOINTS.adminUserItem(user.id),
        STATUS_PAYLOAD[newStatus],
      );
      setUsers((prev) => prev.map((u) => (u.id === user.id ? response.data : u)));
    } catch (error) {
      console.error("Error updating user status:", error);
      Swal.fire({
        title: "Error!",
        text: "Failed to update user status",
        icon: "error",
        confirmButtonColor: "#319EE1",
      });
    } finally {
      setUpdatingId(null);
    }
  };

  const handleDelete = (user: ApiUser) => {
    Swal.fire({
      title: "Permanently delete this account?",
      text: "This erases the user's data (GDPR erasure) — it cannot be undone. To temporarily block them instead, use the Banned status.",
      icon: "warning",
      showCancelButton: true,
      confirmButtonColor: "#d33",
      cancelButtonColor: "#319EE1",
      confirmButtonText: "Yes, delete permanently",
    }).then(async (result) => {
      if (!result.isConfirmed) return;
      try {
        await baseApi.delete(ENDPOINTS.adminUserItem(user.id));
        Swal.fire({
          title: "Deleted!",
          text: "User has been deleted.",
          icon: "success",
          confirmButtonColor: "#319EE1",
        });
        const isLastOnPage = users.length === 1 && currentPage > 1;
        if (isLastOnPage) {
          setCurrentPage((p) => p - 1);
        } else {
          fetchUsers(currentPage, search);
        }
      } catch (error) {
        console.error("Error deleting user:", error);
        Swal.fire({
          title: "Error!",
          text: "Failed to delete user",
          icon: "error",
          confirmButtonColor: "#319EE1",
        });
      }
    });
  };

  const formatDate = (iso: string) => {
    const d = new Date(iso);
    return Number.isNaN(d.getTime()) ? "—" : d.toLocaleDateString("en-GB");
  };

  return (
    <div>
      <div className="bg-white shadow rounded-lg overflow-hidden">
        <div className="px-2 md:px-0 md:pl-6 pt-6 grid md:grid-cols-2 gap-4">
          <div className="flex items-center border border-[#828282] rounded px-3 py-2 gap-2 w-full max-w-md">
            <GoSearch className="text-gray-500 text-lg" />
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search users by name or email..."
              className="w-full outline-none"
            />
          </div>
        </div>

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
              {loading ? (
                <tr>
                  <td colSpan={5} className="text-center py-8 text-gray-500">
                    Loading users...
                  </td>
                </tr>
              ) : users.length === 0 ? (
                <tr>
                  <td colSpan={5} className="text-center py-8 text-gray-500">
                    No users found
                  </td>
                </tr>
              ) : (
                users.map((user, i) => (
                  <tr key={user.id} className={`${i % 2 === 0 ? "bg-[#f8f8f8]" : "bg-white"}`}>
                    <td className="px-6 py-4 flex items-center gap-2">
                      {user.avatar_url ? (
                        <Image
                          src={user.avatar_url}
                          alt={user.full_name || user.email}
                          width={32}
                          height={32}
                          className="rounded-full object-cover"
                        />
                      ) : (
                        <div className="w-8 h-8 rounded-full bg-gray-300 flex items-center justify-center text-white text-xs font-semibold">
                          {(user.full_name || user.email).charAt(0).toUpperCase()}
                        </div>
                      )}
                      {user.full_name || "—"}
                    </td>
                    <td className="px-6 py-4">{user.email}</td>
                    <td className="px-6 py-4 font-medium">
                      <select
                        disabled={updatingId === user.id}
                        value={user.status}
                        onChange={(e) => handleStatusChange(user, e.target.value as UserStatus)}
                        className={`bg-transparent font-medium focus:outline-none disabled:opacity-50 ${statusColors[user.status]}`}
                      >
                        {statusOptions.map((status) => (
                          <option key={status} value={status} className="text-black">
                            {status}
                          </option>
                        ))}
                      </select>
                    </td>
                    <td className="px-6 py-4">{formatDate(user.created_at)}</td>
                    <td
                      onClick={() => handleDelete(user)}
                      className="text-red-500 cursor-pointer hover:text-red-700 flex md:justify-center justify-start text-[20px]"
                    >
                      <RiDeleteBin6Line />
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
  );
}
