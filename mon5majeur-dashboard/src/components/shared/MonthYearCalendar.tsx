"use client";

import { useState } from "react";
import DatePicker from "react-datepicker";
import "react-datepicker/dist/react-datepicker.css";
import { Calendar, ChevronDown } from "lucide-react"; // icons

export default function MonthYearPicker() {
  const [selectedDate, setSelectedDate] = useState<Date | null>(new Date());

  const handleDateChange = (date: Date | null) => {
    setSelectedDate(date);

    if (date) {
      const month = date.toLocaleString("default", { month: "long" });
      const year = date.getFullYear();
      console.log(`Search for: ${month}, ${year}`);
      // এখানে তোমার টেবিল ফিল্টার ফাংশন কল করবে
      // filterTableByMonthYear(month, year);
    }
  };

  return (
    <div className="relative inline-flex items-center">
      {/* left calendar icon */}
      <Calendar className="absolute left-3 text-gray-500 w-4 h-4 pointer-events-none" />

      <DatePicker
        selected={selectedDate}
        onChange={handleDateChange}
        dateFormat="MMMM, yyyy"
        showMonthYearPicker
        className="border border-gray-300 rounded-md pl-9 pr-8 py-1.5 cursor-pointer focus:outline-none focus:ring-1 focus:ring-gray-400"
      />

      {/* right down arrow icon */}
      <ChevronDown className="absolute right-3 text-gray-500 w-4 h-4 pointer-events-none" />
    </div>
  );
}
