/* eslint-disable @typescript-eslint/no-explicit-any */
"use client";

import React, { useCallback, useEffect, useState } from "react";
import toast from "react-hot-toast";
import { GoSearch } from "react-icons/go";
import baseApi from "@/api/baseAPi";
import { ENDPOINTS } from "@/api/endPoints";
import Pagination from "@/components/shared/Pagination";

type TicketStatus = "open" | "pending" | "resolved" | "closed";

const STATUSES: TicketStatus[] = ["open", "pending", "resolved", "closed"];

interface TicketMessage {
  body: string;
  author_is_admin: boolean;
  author_name: string;
  sent_at: string;
}

interface TicketSummary {
  id: string;
  subject: string;
  status: TicketStatus;
  user_email: string;
  user_name: string;
  message_count: number;
  awaiting_admin: boolean;
  created_at: string;
  last_activity_at: string;
}

interface TicketDetail extends TicketSummary {
  messages: TicketMessage[];
}

interface Counters {
  open: number;
  pending: number;
  resolved: number;
  closed: number;
  awaiting_admin: number;
}

const statusStyles: Record<TicketStatus, string> = {
  open: "bg-yellow-100 text-yellow-800",
  pending: "bg-blue-100 text-blue-800",
  resolved: "bg-green-100 text-green-800",
  closed: "bg-gray-200 text-gray-700",
};

const PAGE_SIZE = 10;

function formatWhen(iso: string): string {
  const d = new Date(iso);
  return Number.isNaN(d.getTime()) ? "—" : d.toLocaleString();
}

function errorText(error: unknown, fallback: string): string {
  return (
    (error as any)?.response?.data?.message ||
    (error as any)?.response?.data?.detail ||
    fallback
  );
}

export default function SupportCenter() {
  const [tickets, setTickets] = useState<TicketSummary[]>([]);
  const [counters, setCounters] = useState<Counters | null>(null);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [statusFilter, setStatusFilter] = useState<TicketStatus | "">("");
  const [search, setSearch] = useState("");
  const [loading, setLoading] = useState(false);

  const [selected, setSelected] = useState<TicketDetail | null>(null);
  const [reply, setReply] = useState("");
  const [sending, setSending] = useState(false);

  const loadCounters = useCallback(async () => {
    try {
      const res = await baseApi.get<Counters>(ENDPOINTS.adminTicketCounters);
      setCounters(res.data);
    } catch (error: unknown) {
      console.error("Ticket counters error:", error);
    }
  }, []);

  const loadTickets = useCallback(async () => {
    try {
      setLoading(true);
      const res = await baseApi.get<{ items: TicketSummary[]; total: number }>(
        ENDPOINTS.adminTickets,
        {
          params: {
            page,
            size: PAGE_SIZE,
            ...(statusFilter ? { status: statusFilter } : {}),
            ...(search.trim() ? { search: search.trim() } : {}),
          },
        },
      );
      setTickets(res.data.items);
      setTotal(res.data.total);
    } catch (error: unknown) {
      console.error("Load tickets error:", error);
      toast.error(errorText(error, "Could not load tickets"));
    } finally {
      setLoading(false);
    }
  }, [page, statusFilter, search]);

  useEffect(() => {
    loadTickets();
  }, [loadTickets]);

  useEffect(() => {
    loadCounters();
  }, [loadCounters]);

  const openTicket = async (id: string) => {
    try {
      const res = await baseApi.get<TicketDetail>(ENDPOINTS.adminTicketItem(id));
      setSelected(res.data);
      setReply("");
    } catch (error: unknown) {
      console.error("Open ticket error:", error);
      toast.error(errorText(error, "Could not open ticket"));
    }
  };

  // Both actions refresh the list and counters: a reply or status change
  // moves the ticket between the filtered buckets shown above the table.
  const afterMutation = async (updated: TicketDetail) => {
    setSelected(updated);
    await Promise.all([loadTickets(), loadCounters()]);
  };

  const sendReply = async () => {
    if (!selected || !reply.trim()) return;
    try {
      setSending(true);
      const res = await baseApi.post<TicketDetail>(
        ENDPOINTS.adminTicketReply(selected.id),
        { message: reply.trim() },
      );
      setReply("");
      toast.success("Reply sent");
      await afterMutation(res.data);
    } catch (error: unknown) {
      console.error("Reply error:", error);
      toast.error(errorText(error, "Could not send reply"));
    } finally {
      setSending(false);
    }
  };

  const changeStatus = async (status: TicketStatus) => {
    if (!selected) return;
    try {
      const res = await baseApi.patch<TicketDetail>(
        ENDPOINTS.adminTicketStatus(selected.id),
        { status },
      );
      toast.success(`Marked ${status}`);
      await afterMutation(res.data);
    } catch (error: unknown) {
      console.error("Status change error:", error);
      toast.error(errorText(error, "Could not change status"));
    }
  };

  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE));

  return (
    <div className="mt-10">
      <h2 className="text-[30px] font-semibold">Support Center</h2>
      <p className="text-[16px] text-gray-600 mt-1">
        Tickets raised by players from the app.
      </p>

      {/* Counters */}
      {counters && (
        <div className="grid grid-cols-2 lg:grid-cols-5 gap-4 mt-6">
          {[
            { label: "Awaiting Reply", value: counters.awaiting_admin },
            { label: "Open", value: counters.open },
            { label: "Pending", value: counters.pending },
            { label: "Resolved", value: counters.resolved },
            { label: "Closed", value: counters.closed },
          ].map((c) => (
            <div key={c.label} className="bg-white shadow rounded-2xl p-4">
              <div className="text-[16px] text-[#828282]">{c.label}</div>
              <div className="text-[24px] font-semibold text-gray-800">
                {c.value}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Filters */}
      <div className="flex flex-wrap gap-3 items-center mt-6">
        <div className="relative">
          <GoSearch className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input
            value={search}
            onChange={(e) => {
              setPage(1);
              setSearch(e.target.value);
            }}
            placeholder="Search subject, email or name"
            className="pl-9 pr-3 py-2 border border-gray-300 rounded-xl outline-[#319EE1] w-72"
          />
        </div>

        <button
          onClick={() => {
            setPage(1);
            setStatusFilter("");
          }}
          className={`px-4 py-2 rounded cursor-pointer ${
            statusFilter === ""
              ? "bg-[#E8632C] text-white"
              : "bg-gray-200 text-gray-700"
          }`}
        >
          All
        </button>
        {STATUSES.map((s) => (
          <button
            key={s}
            onClick={() => {
              setPage(1);
              setStatusFilter(s);
            }}
            className={`px-4 py-2 rounded capitalize cursor-pointer ${
              statusFilter === s
                ? "bg-[#E8632C] text-white"
                : "bg-gray-200 text-gray-700"
            }`}
          >
            {s}
          </button>
        ))}
      </div>

      {/* Table */}
      <div className="bg-white shadow rounded-lg overflow-hidden mt-6">
        <div className="overflow-x-auto">
          <table className="min-w-full text-sm text-left">
            <thead className="text-[#828282]">
              <tr>
                <th className="px-6 py-3">Subject</th>
                <th className="px-6 py-3">Player</th>
                <th className="px-6 py-3">Status</th>
                <th className="px-6 py-3">Messages</th>
                <th className="px-6 py-3">Last activity</th>
                <th className="px-6 py-3"></th>
              </tr>
            </thead>
            <tbody>
              {loading && (
                <tr>
                  <td colSpan={6} className="px-6 py-6 text-gray-500">
                    Loading…
                  </td>
                </tr>
              )}

              {!loading && tickets.length === 0 && (
                <tr>
                  <td colSpan={6} className="px-6 py-6 text-gray-500">
                    No tickets{statusFilter ? ` with status "${statusFilter}"` : ""}.
                  </td>
                </tr>
              )}

              {!loading &&
                tickets.map((t) => (
                  <tr key={t.id} className="odd:bg-[#f8f8f8] even:bg-white">
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-2">
                        {t.awaiting_admin && (
                          <span
                            title="Waiting on a reply"
                            className="w-2 h-2 rounded-full bg-[#E8632C] shrink-0"
                          />
                        )}
                        <span>{t.subject}</span>
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <div>{t.user_name || "—"}</div>
                      <div className="text-gray-500 text-xs">{t.user_email}</div>
                    </td>
                    <td className="px-6 py-4">
                      <span
                        className={`px-2 py-1 rounded text-xs capitalize ${statusStyles[t.status]}`}
                      >
                        {t.status}
                      </span>
                    </td>
                    <td className="px-6 py-4">{t.message_count}</td>
                    <td className="px-6 py-4">{formatWhen(t.last_activity_at)}</td>
                    <td className="px-6 py-4">
                      <button
                        onClick={() => openTicket(t.id)}
                        className="text-[#319EE1] underline cursor-pointer"
                      >
                        View
                      </button>
                    </td>
                  </tr>
                ))}
            </tbody>
          </table>
        </div>

        {totalPages > 1 && (
          <Pagination
            currentPage={page}
            totalPages={totalPages}
            onPageChange={setPage}
          />
        )}
      </div>

      {/* Conversation */}
      {selected && (
        <div
          className="fixed inset-0 bg-black/40 flex items-center justify-center z-50 p-4"
          onClick={() => setSelected(null)}
        >
          <div
            className="bg-white rounded-2xl w-full max-w-2xl max-h-[85vh] flex flex-col"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="p-6 border-b">
              <div className="flex justify-between items-start gap-4">
                <div>
                  <h3 className="text-xl font-semibold">{selected.subject}</h3>
                  <p className="text-sm text-gray-500">
                    {selected.user_name || "—"} · {selected.user_email}
                  </p>
                </div>
                <button
                  onClick={() => setSelected(null)}
                  className="text-gray-400 hover:text-gray-700 text-2xl leading-none cursor-pointer"
                >
                  ×
                </button>
              </div>

              <div className="flex gap-2 mt-4 flex-wrap">
                {STATUSES.map((s) => (
                  <button
                    key={s}
                    onClick={() => changeStatus(s)}
                    disabled={selected.status === s}
                    className={`px-3 py-1 rounded text-xs capitalize cursor-pointer disabled:cursor-default ${
                      selected.status === s
                        ? statusStyles[s]
                        : "bg-gray-100 text-gray-600 hover:bg-gray-200"
                    }`}
                  >
                    {s}
                  </button>
                ))}
              </div>
            </div>

            <div className="p-6 overflow-y-auto flex-1 space-y-4">
              {selected.messages.map((m, i) => (
                <div
                  key={i}
                  className={`max-w-[85%] rounded-2xl px-4 py-3 ${
                    m.author_is_admin
                      ? "ml-auto bg-[#319EE1] text-white"
                      : "bg-gray-100 text-gray-800"
                  }`}
                >
                  <div className="whitespace-pre-wrap break-words">{m.body}</div>
                  <div
                    className={`text-[11px] mt-1 ${
                      m.author_is_admin ? "text-white/70" : "text-gray-500"
                    }`}
                  >
                    {m.author_name || (m.author_is_admin ? "Support" : "Player")} ·{" "}
                    {formatWhen(m.sent_at)}
                  </div>
                </div>
              ))}
            </div>

            <div className="p-6 border-t">
              {selected.status === "closed" ? (
                <p className="text-sm text-gray-500">
                  This ticket is closed. Reopen it above to reply.
                </p>
              ) : (
                <div className="flex gap-3">
                  <textarea
                    value={reply}
                    onChange={(e) => setReply(e.target.value)}
                    rows={2}
                    placeholder="Write a reply…"
                    className="flex-1 p-3 border border-gray-300 rounded-xl outline-[#319EE1] resize-none"
                  />
                  <button
                    onClick={sendReply}
                    disabled={sending || !reply.trim()}
                    className="px-6 bg-[#319EE1] text-white rounded-xl cursor-pointer disabled:opacity-60 disabled:cursor-not-allowed"
                  >
                    {sending ? "Sending…" : "Send"}
                  </button>
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
