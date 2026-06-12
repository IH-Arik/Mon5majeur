"use client";

import React, { useState } from "react";
import AllBonus from "./all/AllBonus";
import AllToken from "./token/AllToken";
import BounsCard from "./BounsCard";
import TokenCards from "./TokenCards";

export default function BonusManagement() {
  const [activeTab, setActiveTab] = useState<"all" | "token">("all");

  return (
    <div>
      {/* Cards Section */}
      {activeTab === "all" ? <BounsCard /> : <TokenCards />}

      {/* Buttons */}
      <div className="flex gap-4 mb-6 mt-6">
        <button
          onClick={() => setActiveTab("all")}
          className={`px-4 py-2 rounded cursor-pointer ${
            activeTab === "all"
              ? "bg-[#E8632C] text-white"
              : "bg-gray-200 text-gray-700"
          }`}
        >
          All Bonus
        </button>
        <button
          onClick={() => setActiveTab("token")}
          className={`px-4 py-2 rounded cursor-pointer ${
            activeTab === "token"
              ? "bg-[#E8632C] text-white"
              : "bg-gray-200 text-gray-700"
          }`}
        >
          Token Packs
        </button>
      </div>

      {/* Content */}
      <div className="bg-white rounded-2xl ">
        {activeTab === "all" ? (
          <div>
            <AllBonus></AllBonus>
          </div>
        ) : (
          <div>
            <AllToken></AllToken>
          </div>
        )}
      </div>
    </div>
  );
}
