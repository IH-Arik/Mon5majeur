"use client";

import { useEffect, useState } from "react";
import toast from "react-hot-toast";
import baseApi from "@/api/baseAPi";
import { ENDPOINTS } from "@/api/endPoints";

type ContentSlug = "about_us" | "legal_notices" | "privacy_policy" | "terms_of_use";

interface ContentPage {
  slug: string;
  title: string;
  body: string;
}

export default function ContentPageEditor({
  slug,
  heading,
}: {
  slug: ContentSlug;
  heading: string;
}) {
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    const fetchPage = async () => {
      try {
        setLoading(true);
        const response = await baseApi.get<ContentPage[]>(ENDPOINTS.adminContentPages);
        const page = response.data.find((p) => p.slug === slug);
        if (page) {
          setTitle(page.title);
          setBody(page.body);
        }
      } catch (error) {
        console.error("Error fetching content page:", error);
        toast.error("Failed to load content");
      } finally {
        setLoading(false);
      }
    };

    fetchPage();
  }, [slug]);

  const handleSave = async () => {
    setSaving(true);
    try {
      await baseApi.patch(ENDPOINTS.adminContentPageItem(slug), { title, body });
      toast.success("Saved successfully!");
    } catch (error) {
      console.error("Error saving content page:", error);
      toast.error("Failed to save");
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return <p className="mt-10 text-gray-500">Loading...</p>;
  }

  return (
    <div className="mt-10 max-w-3xl">
      <h1 className="text-[20px] font-semibold mb-4">{heading}</h1>

      <label className="block text-[#828282] text-[16px] font-medium mb-1">Title</label>
      <input
        type="text"
        value={title}
        onChange={(e) => setTitle(e.target.value)}
        className="px-4 text-[16px] border border-[#828282] focus:ring-1 focus:ring-[#828282] focus:outline-none py-2 h-[50px] w-full rounded-2xl text-[#333] mb-4"
      />

      <label className="block text-[#828282] text-[16px] font-medium mb-1">Body</label>
      <textarea
        value={body}
        onChange={(e) => setBody(e.target.value)}
        rows={16}
        className="px-4 text-[15px] border border-[#828282] focus:ring-1 focus:ring-[#828282] focus:outline-none py-3 w-full rounded-2xl text-[#333] resize-y font-mono"
      />

      <button
        onClick={handleSave}
        disabled={saving}
        className="mt-4 hover:opacity-80 hover:bg-[#E8632C] transition duration-300 bg-[#E8632C] text-white px-6 py-3 rounded-md disabled:opacity-50"
      >
        {saving ? "Saving..." : "Save Changes"}
      </button>
    </div>
  );
}
