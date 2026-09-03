"use client";

import Image from "next/image";
import React, { useEffect, useState } from "react";
import { GoSearch } from "react-icons/go";
import { RiDeleteBin6Line } from "react-icons/ri";
import { FaSort, FaSortUp, FaSortDown } from "react-icons/fa";
import Pagination from "@/components/shared/Pagination";
import Swal from "sweetalert2";
import baseApi from "@/api/baseAPi";
import { ENDPOINTS } from "@/api/endPoints";

type UserStatus = "Active" | "Pending" | "Banned" | "Inactive";
type SortField = "full_name" | "created_at";
type SortDir = "asc" | "desc";

interface ApiUser {
  id: string;
  email: string;
  full_name: string | null;
  avatar_url: string | null;
  status: UserStatus;
  created_at: string;
}

// Fuller shape returned by GET /v1/users/{id} — only the row fields above
// are needed for the table, but the detail modal shows all of this.
interface ApiUserDetail extends ApiUser {
  language: string;
  is_superuser: boolean;
  auth_provider: string;
  team_logo: string | null;
  team_name: string | null;
  favourite_team: string | null;
  date_of_birth: string | null;
  terms_accepted: boolean;
  push_notifications_enabled: boolean;
  is_profile_complete: boolean;
  token_balance: number;
  premium_until: string | null;
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

function Avatar({ user, size = 8 }: { user: ApiUser; size?: number }) {
  const dim = size === 8 ? 32 : 64;
  const boxClass = size === 8 ? "w-8 h-8 text-xs" : "w-16 h-16 text-xl";
  if (user.avatar_url) {
    return (
      <Image
        src={user.avatar_url}
        alt={user.full_name || user.email}
        width={dim}
        height={dim}
        className={`rounded-full object-cover ${size === 8 ? "w-8 h-8" : "w-16 h-16"}`}
      />
    );
  }
  return (
    <div
      className={`${boxClass} rounded-full bg-gray-300 flex items-center justify-center text-white font-semibold`}
    >
      {(user.full_name || user.email).charAt(0).toUpperCase()}
    </div>
  );
}

function SortIcon({ active, dir }: { active: boolean; dir: SortDir }) {
  if (!active) return <FaSort className="inline ml-1 text-gray-300" size={12} />;
  return dir === "asc" ? (
    <FaSortUp className="inline ml-1" size={12} />
  ) : (
    <FaSortDown className="inline ml-1" size={12} />
  );
}

export default function UserManagement() {
  const [users, setUsers] = useState<ApiUser[]>([]);
  const [totalPages, setTotalPages] = useState(1);
  const [currentPage, setCurrentPage] = useState(1);
  const [search, setSearch] = useState("");
  const [sortBy, setSortBy] = useState<SortField>("created_at");
  const [sortDir, setSortDir] = useState<SortDir>("desc");
  const [loading, setLoading] = useState(true);
  const [updatingId, setUpdatingId] = useState<string | null>(null);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [bulkBusy, setBulkBusy] = useState(false);

  const [detailUser, setDetailUser] = useState<ApiUserDetail | null>(null);
  const [detailLoading, setDetailLoading] = useState(false);

  const fetchUsers = async (
    page: number,
    searchTerm: string,
    sf: SortField = sortBy,
    sd: SortDir = sortDir,
  ) => {
    try {
      setLoading(true);
      const response = await baseApi.get<ApiPage<ApiUser>>(ENDPOINTS.adminUsersList, {
        params: {
          page,
          size: usersPerPage,
          search: searchTerm || undefined,
          sort_by: sf,
          sort_dir: sd,
        },
      });
      setUsers(response.data.data);
      setTotalPages(Math.max(1, response.data.meta.pages));
      // A row selected on a page that no longer shows it would silently
      // apply a bulk action to something the admin can no longer see.
      setSelected(new Set());
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
  }, [currentPage, sortBy, sortDir]);

  const handlePageChange = (page: number) => setCurrentPage(page);

  const toggleSort = (field: SortField) => {
    if (sortBy === field) {
      setSortDir((d) => (d === "asc" ? "desc" : "asc"));
    } else {
      setSortBy(field);
      setSortDir("asc");
    }
    setCurrentPage(1);
  };

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

  // ── Row selection / bulk actions ──────────────────────────────────────────
  // No dedicated bulk endpoint on the backend: the current page is at most
  // `usersPerPage` (6) rows, so looping the existing per-user PATCH/DELETE
  // calls is simple and fast enough — not worth a new backend contract for.

  const toggleOne = (id: string) => {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const toggleAllOnPage = () => {
    setSelected((prev) =>
      prev.size === users.length ? new Set() : new Set(users.map((u) => u.id)),
    );
  };

  const selectedUsers = users.filter((u) => selected.has(u.id));

  const handleBulkBan = async () => {
    const result = await Swal.fire({
      title: `Ban ${selected.size} user(s)?`,
      text: "They will be blocked from logging in until unbanned.",
      icon: "warning",
      showCancelButton: true,
      confirmButtonColor: "#d33",
      cancelButtonColor: "#319EE1",
      confirmButtonText: "Yes, ban them",
    });
    if (!result.isConfirmed) return;

    setBulkBusy(true);
    try {
      const results = await Promise.allSettled(
        selectedUsers.map((u) =>
          baseApi.patch(ENDPOINTS.adminUserItem(u.id), STATUS_PAYLOAD.Banned),
        ),
      );
      const failed = results.filter((r) => r.status === "rejected").length;
      await fetchUsers(currentPage, search);
      if (failed > 0) {
        Swal.fire({
          title: "Partially completed",
          text: `${failed} of ${selectedUsers.length} could not be banned.`,
          icon: "warning",
          confirmButtonColor: "#319EE1",
        });
      } else {
        Swal.fire({
          title: "Banned",
          text: `${selectedUsers.length} user(s) banned.`,
          icon: "success",
          confirmButtonColor: "#319EE1",
        });
      }
    } finally {
      setBulkBusy(false);
    }
  };

  const handleBulkDelete = async () => {
    const result = await Swal.fire({
      title: `Permanently delete ${selected.size} user(s)?`,
      text: "This erases their data (GDPR erasure) for every selected account — it cannot be undone.",
      icon: "warning",
      showCancelButton: true,
      confirmButtonColor: "#d33",
      cancelButtonColor: "#319EE1",
      confirmButtonText: "Yes, delete permanently",
    });
    if (!result.isConfirmed) return;

    setBulkBusy(true);
    try {
      const results = await Promise.allSettled(
        selectedUsers.map((u) => baseApi.delete(ENDPOINTS.adminUserItem(u.id))),
      );
      const failed = results.filter((r) => r.status === "rejected").length;
      // The page's own contents shifted (rows removed), so re-anchor to
      // page 1 rather than guessing how many pages are left.
      setCurrentPage(1);
      await fetchUsers(1, search);
      if (failed > 0) {
        Swal.fire({
          title: "Partially completed",
          text: `${failed} of ${selectedUsers.length} could not be deleted.`,
          icon: "warning",
          confirmButtonColor: "#319EE1",
        });
      } else {
        Swal.fire({
          title: "Deleted",
          text: `${selectedUsers.length} user(s) deleted.`,
          icon: "success",
          confirmButtonColor: "#319EE1",
        });
      }
    } finally {
      setBulkBusy(false);
    }
  };

  // ── Detail view ────────────────────────────────────────────────────────────

  const openDetail = async (user: ApiUser) => {
    setDetailLoading(true);
    try {
      const response = await baseApi.get<ApiUserDetail>(ENDPOINTS.adminUserItem(user.id));
      setDetailUser(response.data);
    } catch (error) {
      console.error("Error fetching user detail:", error);
      Swal.fire({
        title: "Error!",
        text: "Failed to load user details",
        icon: "error",
        confirmButtonColor: "#319EE1",
      });
    } finally {
      setDetailLoading(false);
    }
  };

  const formatDate = (iso: string | null) => {
    if (!iso) return "—";
    const d = new Date(iso);
    return Number.isNaN(d.getTime()) ? "—" : d.toLocaleDateString("en-GB");
  };

  const formatDateTime = (iso: string | null) => {
    if (!iso) return "—";
    const d = new Date(iso);
    return Number.isNaN(d.getTime()) ? "—" : d.toLocaleString("en-GB");
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
              placeholder="Search users by name, email, or team..."
              className="w-full outline-none"
            />
          </div>
        </div>

        {/* Bulk action bar — only takes space once something is selected */}
        {selected.size > 0 && (
          <div className="mx-6 mt-4 flex items-center justify-between bg-[#F0F7FC] border border-[#319EE1] rounded-lg px-4 py-3">
            <span className="text-sm font-medium text-[#319EE1]">
              {selected.size} selected
            </span>
            <div className="flex gap-3">
              <button
                onClick={handleBulkBan}
                disabled={bulkBusy}
                className="px-4 py-1.5 text-sm rounded-md bg-yellow-500 text-white hover:bg-yellow-600 disabled:opacity-50 cursor-pointer"
              >
                Ban selected
              </button>
              <button
                onClick={handleBulkDelete}
                disabled={bulkBusy}
                className="px-4 py-1.5 text-sm rounded-md bg-red-500 text-white hover:bg-red-600 disabled:opacity-50 cursor-pointer"
              >
                Delete selected
              </button>
              <button
                onClick={() => setSelected(new Set())}
                disabled={bulkBusy}
                className="px-4 py-1.5 text-sm rounded-md border border-gray-300 hover:bg-gray-50 disabled:opacity-50 cursor-pointer"
              >
                Clear
              </button>
            </div>
          </div>
        )}

        <div className="overflow-x-auto p-6">
          <table className="min-w-full text-sm text-left">
            <thead className="text-[#828282]">
              <tr>
                <th className="px-3 py-3 w-10">
                  <input
                    type="checkbox"
                    checked={users.length > 0 && selected.size === users.length}
                    onChange={toggleAllOnPage}
                    className="cursor-pointer"
                  />
                </th>
                <th
                  className="px-6 py-3 cursor-pointer select-none hover:text-black"
                  onClick={() => toggleSort("full_name")}
                >
                  User <SortIcon active={sortBy === "full_name"} dir={sortDir} />
                </th>
                <th className="px-6 py-3">Email</th>
                <th className="px-6 py-3">Status</th>
                <th
                  className="px-6 py-3 cursor-pointer select-none hover:text-black"
                  onClick={() => toggleSort("created_at")}
                >
                  Joined Date <SortIcon active={sortBy === "created_at"} dir={sortDir} />
                </th>
                <th className="px-6 py-3">Action</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={6} className="text-center py-8 text-gray-500">
                    Loading users...
                  </td>
                </tr>
              ) : users.length === 0 ? (
                <tr>
                  <td colSpan={6} className="text-center py-8 text-gray-500">
                    No users found
                  </td>
                </tr>
              ) : (
                users.map((user, i) => (
                  <tr key={user.id} className={`${i % 2 === 0 ? "bg-[#f8f8f8]" : "bg-white"}`}>
                    <td className="px-3 py-4">
                      <input
                        type="checkbox"
                        checked={selected.has(user.id)}
                        onChange={() => toggleOne(user.id)}
                        className="cursor-pointer"
                      />
                    </td>
                    <td
                      className="px-6 py-4 flex items-center gap-2 cursor-pointer hover:underline"
                      onClick={() => openDetail(user)}
                    >
                      <Avatar user={user} />
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

      {/* Detail modal */}
      {(detailUser || detailLoading) && (
        <div
          className="fixed inset-0 bg-black/40 flex items-center justify-center z-50 p-4"
          onClick={() => setDetailUser(null)}
        >
          <div
            className="bg-white rounded-2xl w-full max-w-lg max-h-[85vh] overflow-y-auto"
            onClick={(e) => e.stopPropagation()}
          >
            {detailLoading || !detailUser ? (
              <div className="p-10 text-center text-gray-500">Loading...</div>
            ) : (
              <div className="p-6">
                <div className="flex justify-between items-start mb-6">
                  <div className="flex items-center gap-4">
                    <Avatar user={detailUser} size={16} />
                    <div>
                      <h3 className="text-lg font-semibold">
                        {detailUser.full_name || "No name set"}
                      </h3>
                      <p className="text-sm text-gray-500">{detailUser.email}</p>
                    </div>
                  </div>
                  <button
                    onClick={() => setDetailUser(null)}
                    className="text-gray-400 hover:text-gray-700 text-2xl leading-none cursor-pointer"
                  >
                    ×
                  </button>
                </div>

                <div className="grid grid-cols-2 gap-x-4 gap-y-3 text-sm">
                  <DetailRow label="Status">
                    <span className={statusColors[detailUser.status]}>
                      {detailUser.status}
                    </span>
                  </DetailRow>
                  <DetailRow label="Auth provider">{detailUser.auth_provider}</DetailRow>
                  <DetailRow label="Language">{detailUser.language.toUpperCase()}</DetailRow>
                  <DetailRow label="Admin">
                    {detailUser.is_superuser ? "Yes" : "No"}
                  </DetailRow>
                  <DetailRow label="Team name">{detailUser.team_name || "—"}</DetailRow>
                  <DetailRow label="Favourite team">
                    {detailUser.favourite_team || "—"}
                  </DetailRow>
                  <DetailRow label="Date of birth">
                    {formatDate(detailUser.date_of_birth)}
                  </DetailRow>
                  <DetailRow label="Profile complete">
                    {detailUser.is_profile_complete ? "Yes" : "No"}
                  </DetailRow>
                  <DetailRow label="Terms accepted">
                    {detailUser.terms_accepted ? "Yes" : "No"}
                  </DetailRow>
                  <DetailRow label="Push notifications">
                    {detailUser.push_notifications_enabled ? "On" : "Off"}
                  </DetailRow>
                  <DetailRow label="Token balance">{detailUser.token_balance}</DetailRow>
                  <DetailRow label="Premium until">
                    {formatDateTime(detailUser.premium_until)}
                  </DetailRow>
                  <DetailRow label="Joined">{formatDateTime(detailUser.created_at)}</DetailRow>
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

function DetailRow({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <div className="text-[#828282] text-xs">{label}</div>
      <div className="font-medium">{children}</div>
    </div>
  );
}
