"use client";

import { FiPackage } from "react-icons/fi";
import { MdDone } from "react-icons/md";
import { TbCoins } from "react-icons/tb";
import { RiCoinLine } from "react-icons/ri";

const stats = [
  { label: "Total Token Packs", value: 45, icon: <FiPackage /> },
  {
    label: "Active Token Packs",
    value: 38,
    icon: <MdDone className="border rounded-full p-0.5" />,
  },
  { label: "Total Tokens Sold", value: 2450, icon: <TbCoins /> },
  { label: "Revenue from Tokens", value: 15680, icon: <RiCoinLine /> },
];

export default function TokenCards() {
  return (
    <div className="grid grid-cols-2 sm:grid-cols-2 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-6 mt-6">
      {stats.map((stat, index) => (
        <div key={index} className="bg-white shadow rounded-2xl  p-4 lg:px-6 ">
          {/* Icon and Text Layout */}
          <div className="flex justify-between mb-4">
            {" "}
            {/* Add bottom margin for gap */}
            <div className="text-[16px] md:text-[18px] lg:text-[20px] text-[#828282]">
              {stat.label}
            </div>
            <div className=" text-[20px] text-[#828282]">{stat.icon}</div>
          </div>

          {/* Value */}
          <div className="text-[24px] md:text-[25px] lg:text-[28px] font-semibold text-gray-800">
            {stat.value}
          </div>
        </div>
      ))}
    </div>
  );
}
