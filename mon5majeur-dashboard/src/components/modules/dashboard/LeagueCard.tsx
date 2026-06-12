

"use client"

import { FiUserPlus, FiUsers } from 'react-icons/fi';
import { IoGameControllerOutline } from 'react-icons/io5';
import { MdDone } from 'react-icons/md';
import { TbUserX } from 'react-icons/tb';

const stats = [
  { label: 'Total Global League', value: 1203, icon: <IoGameControllerOutline /> },
  { label: 'Total Public League', value: 1090, icon: <MdDone className='border rounded-full p-0.5' /> },
  { label: 'Total Private League', value: 125, icon: <FiUserPlus /> },
  { label: 'Total Private League Users ', value: 80, icon: <IoGameControllerOutline /> },
  { label: 'Total Global League User ', value: 1203, icon: <FiUsers /> },
  { label: 'Monthly Active user', value: 1090, icon: <MdDone className='border rounded-full p-0.5' /> },
  { label: 'Total Public League Created ', value: 125, icon: <FiUserPlus /> },
  { label: 'Total private league created ', value: 80, icon: <TbUserX /> },
];


export default function LeagueCard() {
  return (
     <div className="grid grid-cols-2 sm:grid-cols-2 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-6 mt-6">
        {stats.map((stat, index) => (
          <div key={index} className="bg-white shadow rounded-2xl  p-4 lg:px-6 ">
            {/* Icon and Text Layout */}
            <div className="flex justify-between mb-4"> {/* Add bottom margin for gap */}
              <div className="text-[18px] md:text-[18px] lg:text-[20px] text-[#828282]">{stat.label}</div>
              <div className=" text-[20px] text-[#828282]">{stat.icon}</div>
            </div>

            {/* Value */}
            <div className="text-[24px] md:text-[25px] lg:text-[28px] font-semibold text-gray-800">
              {stat.value}
            </div>
          </div>
        ))}
      </div>
  )
}
