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
  title_fr: string;
  body_fr: string;
}

type Lang = "en" | "fr";

export default function ContentPageEditor({
  slug,
  heading,
}: {
  slug: ContentSlug;
  heading: string;
}) {
  const [lang, setLang] = useState<Lang>("en");
  const [titleEn, setTitleEn] = useState("");
  const [bodyEn, setBodyEn] = useState("");
  const [titleFr, setTitleFr] = useState("");
  const [bodyFr, setBodyFr] = useState("");
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    const fetchPage = async () => {
      try {
        setLoading(true);
        const response = await baseApi.get<ContentPage[]>(ENDPOINTS.adminContentPages);
        const page = response.data.find((p) => p.slug === slug);
        if (page) {
          setTitleEn(page.title);
          setBodyEn(page.body);
          setTitleFr(page.title_fr);
          setBodyFr(page.body_fr);
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
      await baseApi.patch(ENDPOINTS.adminContentPageItem(slug), {
        title: titleEn,
        body: bodyEn,
        title_fr: titleFr,
        body_fr: bodyFr,
      });
      toast.success("Saved successfully! The app reads this live - no new build needed.");
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

  const isEn = lang === "en";
  const title = isEn ? titleEn : titleFr;
  const setTitle = isEn ? setTitleEn : setTitleFr;
  const body = isEn ? bodyEn : bodyFr;
  const setBody = isEn ? setBodyEn : setBodyFr;

  return (
    <div className="mt-10 max-w-3xl">
      <h1 className="text-[20px] font-semibold mb-4">{heading}</h1>

      {/* The app shows whichever language the player has selected -
          falling back to English if the French fields are still empty -
          so both versions live on this one page, not on separate tabs. */}
      <div className="flex gap-2 mb-4">
        <button
          type="button"
          onClick={() => setLang("en")}
          className={`px-4 py-1.5 rounded-full text-[14px] font-medium ${
            isEn ? "bg-[#E8632C] text-white" : "bg-gray-100 text-[#828282]"
          }`}
        >
          English
        </button>
        <button
          type="button"
          onClick={() => setLang("fr")}
          className={`px-4 py-1.5 rounded-full text-[14px] font-medium ${
            !isEn ? "bg-[#E8632C] text-white" : "bg-gray-100 text-[#828282]"
          }`}
        >
          Français{!titleFr && !bodyFr ? " (empty - falls back to English)" : ""}
        </button>
      </div>

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
