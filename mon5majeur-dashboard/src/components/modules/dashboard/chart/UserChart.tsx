"use client";
import React, { useState } from "react";
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Area,
} from "recharts";

export default function UserChart() {
  const [filter, setFilter] = useState<"Weekly" | "Monthly" | "Yearly">("Weekly");

  const data = {
    Weekly: [
      { day: "Tue", users: 50 },
      { day: "Thr", users: 120 },
      { day: "Sat", users: 90 },
      { day: "Mon", users: 300 },
      { day: "Wed", users: 700 },
      { day: "Fri", users: 950 },
      { day: "Sun", users: 1000 },
    ],
    Monthly: [
      { day: "Week 1", users: 400 },
      { day: "Week 2", users: 700 },
      { day: "Week 3", users: 900 },
      { day: "Week 4", users: 1200 },
    ],
    Yearly: [
      { day: "Jan", users: 500 },
      { day: "Mar", users: 900 },
      { day: "Jun", users: 1300 },
      { day: "Sep", users: 1700 },
      { day: "Dec", users: 2100 },
    ],
  };

  return (
    <div className="bg-white p-6 rounded-xl shadow-sm w-full max-w-full h-full">
      {/* Header */}
      <div className="flex flex-col md:flex-row justify-between items-start md:items-center mb-4 gap-2">
        <div>
          <h2 className="text-lg md:text-xl lg:text-2xl font-semibold text-gray-700">
            Daily Active Users
          </h2>
          <p className="text-sm text-gray-400 mt-1">
            Engagement over the last 14 days
          </p>
        </div>

        <select
          value={filter}
          onChange={(e) => setFilter(e.target.value as any)}
          className="text-sm font-medium text-gray-700 border border-gray-300 rounded-md px-3 py-1.5 focus:outline-none focus:ring-2 focus:ring-cyan-500 mb-0 md:mb-14 lg:mb-0"
        >
          <option>Weekly</option>
          <option>Monthly</option>
          <option>Yearly</option>
        </select>
      </div>

      {/* Chart */}
      <div className="h-[220px] md:h-[200px]  lg:h-[400px] -ml-9 mt-10">
        <ResponsiveContainer width="100%" height="100%">
          <LineChart data={data[filter]}>
            <defs>
              <linearGradient id="colorUv" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor="#06b6d4" stopOpacity={0.2} />
                <stop offset="100%" stopColor="#06b6d4" stopOpacity={0} />
              </linearGradient>
            </defs>
            <CartesianGrid vertical={false} strokeDasharray="3 3" stroke="#f3f3f3" />
            <XAxis
              dataKey="day"
              axisLine={false}
              tickLine={false}
              tick={{ fontSize: 12, fill: "#999" }}
            />
            <YAxis
              axisLine={false}
              tickLine={false}
              tick={{ fontSize: 12, fill: "#999" }}
              tickFormatter={(v) => (v >= 1000 ? "1k+" : v)}
            />
            <Tooltip
              cursor={{ stroke: "transparent" }}
              contentStyle={{
                fontSize: "12px",
                borderRadius: "6px",
                borderColor: "#eee",
              }}
            />
            <Area
              type="monotone"
              dataKey="users"
              stroke="none"
              fill="url(#colorUv)"
            />
            <Line
              type="monotone"
              dataKey="users"
              stroke="#06b6d4"
              strokeWidth={2.5}
              dot={false}
            />
          </LineChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}
