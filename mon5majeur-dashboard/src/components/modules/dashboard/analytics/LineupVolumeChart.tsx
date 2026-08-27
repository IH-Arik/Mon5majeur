"use client";

import {
  Bar,
  BarChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";

interface NightVolume {
  night_date: string;
  lineups_count: number;
}

// Single measure (validated lineups), single hue — no adjacent-series CVD
// concern since there's only one series to read.
const BAR_COLOR = "#E8632C";

export default function LineupVolumeChart({ nights }: { nights: NightVolume[] }) {
  const data = nights.map((n) => ({
    night: new Date(n.night_date).toLocaleDateString("en-GB", {
      day: "2-digit",
      month: "short",
    }),
    lineups: n.lineups_count,
  }));

  return (
    <div className="bg-white p-6 rounded-xl shadow-sm w-full h-full">
      <h2 className="text-lg md:text-xl font-semibold text-gray-700 mb-1">
        Validated Lineups per Night
      </h2>
      <p className="text-sm text-gray-400 mb-4">Last {nights.length} match-nights</p>

      <div className="h-[280px] -ml-4">
        {data.length === 0 ? (
          <div className="h-full flex items-center justify-center text-gray-400 text-sm">
            No match-nights yet this season
          </div>
        ) : (
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={data} barCategoryGap="20%">
              <CartesianGrid vertical={false} strokeDasharray="3 3" stroke="#f3f3f3" />
              <XAxis
                dataKey="night"
                axisLine={false}
                tickLine={false}
                tick={{ fontSize: 11, fill: "#999" }}
                interval="preserveStartEnd"
              />
              <YAxis
                axisLine={false}
                tickLine={false}
                tick={{ fontSize: 12, fill: "#999" }}
                allowDecimals={false}
              />
              <Tooltip
                cursor={{ fill: "#f8f8f8" }}
                contentStyle={{ fontSize: "12px", borderRadius: "6px", borderColor: "#eee" }}
                formatter={(value) => [`${value}`, "Lineups"]}
              />
              <Bar dataKey="lineups" fill={BAR_COLOR} radius={[4, 4, 0, 0]} maxBarSize={28} />
            </BarChart>
          </ResponsiveContainer>
        )}
      </div>
    </div>
  );
}
