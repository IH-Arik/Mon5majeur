'use client';
import React from 'react';

type PaginationProps = {
  currentPage: number;
  totalPages: number;
  onPageChange: (page: number) => void;
};

export default function Pagination({ currentPage, totalPages, onPageChange }: PaginationProps) {
  const pages = Array.from({ length: totalPages }, (_, i) => i + 1);

  return (
    <div className="p-4 flex items-center justify-between text-sm text-gray-600">
      <span className='text-[#828282]'>
        Showing page {currentPage} of {totalPages}
      </span>
      <div className="flex gap-2">
        {/* Previous */}
        <button
          className="px-2 py-1 rounded border disabled:cursor-not-allowed border-gray-300 disabled:opacity-50 hover:bg-gray-100 transition"
          onClick={() => onPageChange(currentPage - 1)}
          disabled={currentPage === 1}
        >
          &lt;
        </button>

        {/* Page Numbers */}
        {pages.map((page) => (
          <button
            key={page}
            className={`px-3 py-1 rounded border transition ${
              page === currentPage
                ? 'bg-orange-500 text-white border-orange-500'
                : 'border-gray-300 hover:bg-gray-100'
            }`}
            onClick={() => onPageChange(page)}
          >
            {page}
          </button>
        ))}

        {/* Next */}
        <button
          className="px-2 py-1 rounded border disabled:cursor-not-allowed border-gray-300 disabled:opacity-50 hover:bg-gray-100 transition"
          onClick={() => onPageChange(currentPage + 1)}
          disabled={currentPage === totalPages}
        >
          &gt;
        </button>
      </div>
    </div>
  );
}
