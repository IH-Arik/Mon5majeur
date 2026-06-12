"use client";

import React, { useState } from 'react';
import toast from 'react-hot-toast';
import { FaPlus, FaChevronDown, FaChevronUp } from 'react-icons/fa';


const faqs = [
    {
        question: 'How are points calculated per player?',
        answer: 'Points are calculated based on player performance in matches, including goals, assists, and other metrics.',
    },
    {
        question: 'Can I play in multiple leagues at the same time?',
        answer: 'Yes, you can join and play in multiple leagues simultaneously.',
    },
    {
        question: 'How do I join a private league?',
        answer: 'You can join a private league using an invitation code provided by the league manager.',
    },
    {
        question: 'Can I join a public league?',
        answer: 'Yes, public leagues are open for anyone to join without an invite code.',
    },
    {
        question: 'Can I leave a league during the season?',
        answer: 'Yes, you can leave a league during the season, but once you do, you will no longer be able to manage your team or rejoin the same league until the next season begins.',
    },
];

export default function Security() {
    const [openIndex, setOpenIndex] = useState(null);
    const [isPopupOpen, setPopupOpen] = useState(false);

    const toggleFAQ = (index: any) => {
        setOpenIndex(openIndex === index ? null : index);
    };

    return (
        <div className="mt-15  mx-auto p-6 bg-white rounded-2xl">
            <div className="flex items-center justify-between mb-">
                <h2 className="text-2xl font-semibold">Frequently Asked Questions</h2>
                <button
                    onClick={() => setPopupOpen(true)}
                    className="text-lg cursor-pointer bg-gray-200 p-2 rounded-full hover:bg-gray-300"
                >
                    <FaPlus />
                </button>
            </div>

            <p className="text-[16px] text-gray-600 mb-10">
                Matches player support content and common queries to reduce support tickets
            </p>

            <div className="space-y-2">
                {faqs.map((faq, index) => (
                    <div key={index} className="border-b border-[#828282]">
                        <button
                            onClick={() => toggleFAQ(index)}
                            className="w-full flex justify-between items-center px-1 py-3 focus:outline-none cursor-pointer"
                        >
                            <span className="text-left text-[20px] font-medium">{faq.question}</span>
                            {openIndex === index ? <FaChevronUp /> : <FaChevronDown />}
                        </button>
                        {openIndex === index && (
                            <div className="px-4 pb-4 text-[18px] text-gray-700">{faq.answer}</div>
                        )}
                    </div>
                ))}
            </div>

            {/* Popup Modal */}
            {isPopupOpen && (
                <div className="fixed inset-0 z-50 flex justify-center items-center px-4">
                    <div className="absolute inset-0 bg-black opacity-80"></div>

                    <div className="relative z-10 bg-white rounded-2xl p-8 w-full md:w-1/2 max-w-2xl">
                        <h3 className="text-[24px] font-semibold mb-5 text-[#E8632C]">Create New FAQ</h3>

                        <form
                            onSubmit={(e) => {
                                e.preventDefault();
                                toast.success('FAQ created!');
                                setPopupOpen(false);
                            }}
                        >
                            {/* FAQ Question */}
                            <div className="mb-4">
                                <label className="block text-[#828282] text-[18px] font-medium mb-1">Question</label>
                                <input
                                    type="text"
                                    name="question"
                                    placeholder="Enter the FAQ question"
                                    className="px-4 text-[18px] border border-[#828282] focus:ring-1 focus:ring-[#828282] focus:outline-none py-2 h-[60px] w-full rounded-2xl text-[#828282]"
                                />
                            </div>

                            {/* FAQ Answer */}
                            <div className="mb-4">
                                <label className="block text-[#828282] text-[18px] font-medium mb-1">Answer</label>
                                <textarea
                                    name="answer"
                                    placeholder="Enter the answer"
                                    rows={4}
                                    className="px-4 text-[18px] border border-[#828282] focus:ring-1 focus:ring-[#828282] focus:outline-none py-3 w-full rounded-2xl text-[#828282] resize-none"
                                />
                            </div>

                            {/* Buttons */}
                            <div className="flex justify-center mt-6">
                                <button
                                    type="submit"
                                    className="hover:opacity-80 hover:bg-[#E8632C] transition duration-300 bg-[#E8632C] text-white px-6 py-3 rounded-md"
                                >
                                    Submit
                                </button>
                                <button
                                    type="button"
                                    className="ml-4 bg-red-500 text-white duration-300 border border-white px-7 rounded-md hover:bg-[#a12020]"
                                    onClick={() => setPopupOpen(false)}
                                >
                                    Cancel
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            )}

        </div>
    );
}
