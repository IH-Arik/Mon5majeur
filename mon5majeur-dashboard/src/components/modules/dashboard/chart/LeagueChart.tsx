"use client";
import React from "react";
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  BarElement,
  Title,
  Tooltip,
  Legend,
} from "chart.js";
import { Bar } from "react-chartjs-2";

ChartJS.register(CategoryScale, LinearScale, BarElement, Title, Tooltip, Legend);

export default function LeagueChart() {
  const data = {
    labels: ["Mode 1", "Mode 2", "Mode 3", "Mode 4", "Mode 5"],
    datasets: [
      {
        label: "Players",
        data: [3000, 6000, 3500, 5000, 5800],
        backgroundColor: "#F46A1F",
        borderRadius: 8,
      },
    ],
  };

  const options = {
    responsive: true,
    plugins: {
      legend: { display: false },
      title: {
        display: true,
        text: "League Participation",
        align: "start" as const,
        font: { size: 16, weight: "bold" as const },
        color: "#1B2A4A",
      },
    },
    scales: {
      y: {
        beginAtZero: true,
        ticks: {
          stepSize: 1500,
        },
      },
      x: {
        grid: { display: false },
      },
    },
  };

  return (
    <div className="md:w-[640px] lg:w-[750px] bg-white p-5 rounded-xl  lg:h-[500px]">
      <div className="mb-2">
        <h2 className="text-[#1B2A4A] text-lg md:text-xl lg:text-2xl font-semibold">League Participation</h2>
        <p className="text-sm text-gray-400">Breakdown by game mode</p>
      </div>
      <Bar data={data} options={{ ...options, plugins: { ...options.plugins, title: { display: false } } }} />
    </div>
  );
}
