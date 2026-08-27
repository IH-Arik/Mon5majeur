"use client";

import React, { useEffect, useState } from "react";
import toast from "react-hot-toast";
import Swal from "sweetalert2";
import { FaPlus, FaChevronDown, FaChevronUp } from "react-icons/fa";
import { CiEdit } from "react-icons/ci";
import { RiDeleteBin6Line } from "react-icons/ri";
import baseApi from "@/api/baseAPi";
import { ENDPOINTS } from "@/api/endPoints";

interface FaqEntry {
  id: string;
  question: string;
  answer: string;
  order: number;
  is_active: boolean;
}

export default function Security() {
  const [faqs, setFaqs] = useState<FaqEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [openId, setOpenId] = useState<string | null>(null);
  const [isPopupOpen, setPopupOpen] = useState(false);
  const [editing, setEditing] = useState<FaqEntry | null>(null);
  const [question, setQuestion] = useState("");
  const [answer, setAnswer] = useState("");
  const [saving, setSaving] = useState(false);

  const fetchFaqs = async () => {
    try {
      setLoading(true);
      const response = await baseApi.get<FaqEntry[]>(ENDPOINTS.adminFaqs);
      setFaqs(response.data);
    } catch (error) {
      console.error("Error fetching FAQs:", error);
      toast.error("Failed to load FAQs");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchFaqs();
  }, []);

  const toggleFAQ = (id: string) => setOpenId(openId === id ? null : id);

  const openCreate = () => {
    setEditing(null);
    setQuestion("");
    setAnswer("");
    setPopupOpen(true);
  };

  const openEdit = (faq: FaqEntry) => {
    setEditing(faq);
    setQuestion(faq.question);
    setAnswer(faq.answer);
    setPopupOpen(true);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!question.trim() || !answer.trim()) {
      toast.error("Both question and answer are required");
      return;
    }

    setSaving(true);
    try {
      if (editing) {
        await baseApi.patch(ENDPOINTS.adminFaqItem(editing.id), { question, answer });
        toast.success("FAQ updated!");
      } else {
        await baseApi.post(ENDPOINTS.adminFaqs, { question, answer });
        toast.success("FAQ created!");
      }
      setPopupOpen(false);
      fetchFaqs();
    } catch (error) {
      console.error("Error saving FAQ:", error);
      toast.error("Failed to save FAQ");
    } finally {
      setSaving(false);
    }
  };

  const handleToggleActive = async (faq: FaqEntry) => {
    try {
      await baseApi.patch(ENDPOINTS.adminFaqItem(faq.id), { is_active: !faq.is_active });
      fetchFaqs();
    } catch (error) {
      console.error("Error toggling FAQ status:", error);
      toast.error("Failed to update FAQ status");
    }
  };

  const handleDelete = (faq: FaqEntry) => {
    Swal.fire({
      title: "Delete this FAQ?",
      text: faq.question,
      icon: "warning",
      showCancelButton: true,
      confirmButtonColor: "#d33",
      cancelButtonColor: "#319EE1",
      confirmButtonText: "Yes, delete it!",
    }).then(async (result) => {
      if (!result.isConfirmed) return;
      try {
        await baseApi.delete(ENDPOINTS.adminFaqItem(faq.id));
        fetchFaqs();
      } catch (error) {
        console.error("Error deleting FAQ:", error);
        toast.error("Failed to delete FAQ");
      }
    });
  };

  return (
    <div className="mt-15  mx-auto p-6 bg-white rounded-2xl">
      <div className="flex items-center justify-between mb-">
        <h2 className="text-2xl font-semibold">Frequently Asked Questions</h2>
        <button
          onClick={openCreate}
          className="text-lg cursor-pointer bg-gray-200 p-2 rounded-full hover:bg-gray-300"
        >
          <FaPlus />
        </button>
      </div>

      <p className="text-[16px] text-gray-600 mb-10">
        Matches player support content and common queries to reduce support tickets
      </p>

      <div className="space-y-2">
        {loading ? (
          <p className="text-gray-500 py-8 text-center">Loading FAQs...</p>
        ) : faqs.length === 0 ? (
          <p className="text-gray-500 py-8 text-center">No FAQ entries yet</p>
        ) : (
          faqs.map((faq) => (
            <div key={faq.id} className="border-b border-[#828282]">
              <div className="w-full flex justify-between items-center px-1 py-3">
                <button
                  onClick={() => toggleFAQ(faq.id)}
                  className="flex-1 flex justify-between items-center text-left focus:outline-none cursor-pointer"
                >
                  <span
                    className={`text-left text-[20px] font-medium ${
                      faq.is_active ? "" : "text-gray-400 line-through"
                    }`}
                  >
                    {faq.question}
                  </span>
                </button>
                <div className="flex items-center gap-3 ml-4">
                  <button
                    onClick={() => handleToggleActive(faq)}
                    className={`text-sm cursor-pointer ${faq.is_active ? "text-green-500" : "text-red-400"}`}
                    title="Toggle visibility in the app"
                  >
                    {faq.is_active ? "Active" : "Hidden"}
                  </button>
                  <button
                    onClick={() => openEdit(faq)}
                    className="text-blue-500 hover:text-blue-700 cursor-pointer text-[20px]"
                    title="Edit"
                  >
                    <CiEdit />
                  </button>
                  <button
                    onClick={() => handleDelete(faq)}
                    className="text-red-500 hover:text-red-700 cursor-pointer text-[18px]"
                    title="Delete"
                  >
                    <RiDeleteBin6Line />
                  </button>
                  <button onClick={() => toggleFAQ(faq.id)} className="cursor-pointer">
                    {openId === faq.id ? <FaChevronUp /> : <FaChevronDown />}
                  </button>
                </div>
              </div>
              {openId === faq.id && (
                <div className="px-4 pb-4 text-[18px] text-gray-700">{faq.answer}</div>
              )}
            </div>
          ))
        )}
      </div>

      {isPopupOpen && (
        <div className="fixed inset-0 z-50 flex justify-center items-center px-4">
          <div className="absolute inset-0 bg-black opacity-80"></div>

          <div className="relative z-10 bg-white rounded-2xl p-8 w-full md:w-1/2 max-w-2xl">
            <h3 className="text-[24px] font-semibold mb-5 text-[#E8632C]">
              {editing ? "Edit FAQ" : "Create New FAQ"}
            </h3>

            <form onSubmit={handleSubmit}>
              <div className="mb-4">
                <label className="block text-[#828282] text-[18px] font-medium mb-1">
                  Question
                </label>
                <input
                  type="text"
                  value={question}
                  onChange={(e) => setQuestion(e.target.value)}
                  placeholder="Enter the FAQ question"
                  className="px-4 text-[18px] border border-[#828282] focus:ring-1 focus:ring-[#828282] focus:outline-none py-2 h-[60px] w-full rounded-2xl text-[#828282]"
                />
              </div>

              <div className="mb-4">
                <label className="block text-[#828282] text-[18px] font-medium mb-1">
                  Answer
                </label>
                <textarea
                  value={answer}
                  onChange={(e) => setAnswer(e.target.value)}
                  placeholder="Enter the answer"
                  rows={4}
                  className="px-4 text-[18px] border border-[#828282] focus:ring-1 focus:ring-[#828282] focus:outline-none py-3 w-full rounded-2xl text-[#828282] resize-none"
                />
              </div>

              <div className="flex justify-center mt-6">
                <button
                  type="submit"
                  disabled={saving}
                  className="hover:opacity-80 hover:bg-[#E8632C] transition duration-300 bg-[#E8632C] text-white px-6 py-3 rounded-md disabled:opacity-50"
                >
                  {saving ? "Saving..." : "Submit"}
                </button>
                <button
                  type="button"
                  className="ml-4 bg-red-500 text-white duration-300 border border-white px-7 rounded-md hover:bg-[#a12020]"
                  onClick={() => setPopupOpen(false)}
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
