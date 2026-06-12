// "use client";
// import React from "react";
// import {
//   PieChart,
//   Pie,
//   Cell,
//   ResponsiveContainer,
//   Tooltip,
// } from "recharts";

// export default function DurationChart() {
//   const data = [
//     { name: "0-15m", value: 35, color: "#06b6d4" },
//     { name: "15-30m", value: 42, color: "#fbbf24" },
//     { name: "30-60m", value: 23, color: "#a78bfa" },
//   ];

//   return (
//     <div className="bg-white p-6 rounded-xl shadow-sm w-full h-[300px] md:h-[400px] lg:h-[550px]">
//       {/* Header */}
//       <h2 className=" text-lg md:text-xl lg:text-2xl font-semibold text-gray-800">
//         Average Session Duration
//       </h2>
//       <p className="text-sm text-gray-400 md:mt-4">
//         Distribution of player session lengths
//       </p>

//       {/* Chart container */}
//       <div className="h-[180px] md:h-[240px] lg:h-[300px] flex items-center justify-center">
//         <ResponsiveContainer width="80%" height="100%">
//           <PieChart>
//             <Pie
//               data={data}
//               cx="50%"
//               cy="50%"
//               innerRadius={70}
//               outerRadius={100} // You can increase this to 110 or 120 for even bigger slices
//               dataKey="value"
//               paddingAngle={2}
//             >
//               {data.map((entry, index) => (
//                 <Cell key={`cell-${index}`} fill={entry.color} />
//               ))}
//             </Pie>
//             <Tooltip
//               formatter={(value: any) => `${value}%`}
//               contentStyle={{
//                 fontSize: "11px",
//                 borderRadius: "6px",
//                 borderColor: "#eee",
//               }}
//             />
//           </PieChart>
//         </ResponsiveContainer>
//       </div>

//       {/* Legend */}
//       <div className="flex justify-center gap-5 mt-6 text-xs text-gray-600 flex-wrap">
//         {data.map((item, i) => (
//           <div key={i} className="flex items-center gap-2">
//             <div
//               className="w-3 h-3 rounded-full"
//               style={{ backgroundColor: item.color }}
//             ></div>
//             <span>{item.name}</span>
//           </div>
//         ))}
//       </div>
//     </div>
//   );
// }




"use client";
import React, { useState, useEffect } from "react";
import {
  PieChart,
  Pie,
  Cell,
  ResponsiveContainer,
  Tooltip,
} from "recharts";

export default function DurationChart() {
  const data = [
    { name: "0-15m", value: 35, color: "#06b6d4" },
    { name: "15-30m", value: 42, color: "#fbbf24" },
    { name: "30-60m", value: 23, color: "#a78bfa" },
  ];

  // Radius states
  const [innerRadius, setInnerRadius] = useState(50);
  const [outerRadius, setOuterRadius] = useState(70);

  // Adjust radius based on screen width
  useEffect(() => {
    const handleResize = () => {
      const width = window.innerWidth;

      if (width >= 1024) {
        // lg and above
        setInnerRadius(130);
        setOuterRadius(170);
      } else if (width >= 768) {
        // md
        setInnerRadius(70);
        setOuterRadius(90);
      } else {
        // sm
        setInnerRadius(50);
        setOuterRadius(70);
      }
    };

    // Set initially
    handleResize();

    // Add resize listener
    window.addEventListener("resize", handleResize);

    // Clean up
    return () => window.removeEventListener("resize", handleResize);
  }, []);

  return (
    <div className="bg-white p-6 rounded-xl shadow-sm w-full h-[300px] md:h-[400px] lg:h-[550px]">
      {/* Header */}
      <h2 className=" text-lg md:text-xl lg:text-2xl font-semibold text-gray-800">
        Average Session Duration
      </h2>
      <p className="text-sm text-gray-400 md:mt-4">
        Distribution of player session lengths
      </p>

      {/* Chart container */}
      <div className="h-[180px] md:h-[240px] lg:h-[400px] flex items-center justify-center">
        <ResponsiveContainer width="80%" height="100%">
          <PieChart>
            <Pie
              data={data}
              cx="50%"
              cy="50%"
              innerRadius={innerRadius}
              outerRadius={outerRadius}
              dataKey="value"
              paddingAngle={2}
            >
              {data.map((entry, index) => (
                <Cell key={`cell-${index}`} fill={entry.color} />
              ))}
            </Pie>
            <Tooltip
              formatter={(value: any) => `${value}%`}
              contentStyle={{
                fontSize: "11px",
                borderRadius: "6px",
                borderColor: "#eee",
              }}
            />
          </PieChart>
        </ResponsiveContainer>
      </div>

      {/* Legend */}
      <div className="flex justify-center gap-5 mt-6 text-xs text-gray-600 flex-wrap">
        {data.map((item, i) => (
          <div key={i} className="flex items-center gap-2">
            <div
              className="w-3 h-3 rounded-full"
              style={{ backgroundColor: item.color }}
            ></div>
            <span>{item.name}</span>
          </div>
        ))}
      </div>
    </div>
  );
}
