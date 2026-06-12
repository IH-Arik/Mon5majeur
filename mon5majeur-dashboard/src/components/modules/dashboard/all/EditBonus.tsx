'use client';

import { ArrowUpTrayIcon } from '@heroicons/react/16/solid';
import Image from 'next/image';
import { useEffect, useState, ChangeEvent, FormEvent } from 'react';
import toast from 'react-hot-toast';

type EditBonusProps = {
    isOpen: boolean;
    onClose: () => void;
    bonusData?: {
        bonusName: string;
        type: string;
        price: string;
        createdDate: string;
        expiredDate: string;
        logoUrl?: string; // optional for preview
    } | null;
};

const EditBonus = ({ isOpen, onClose, bonusData }: EditBonusProps) => {
    const [form, setForm] = useState({
        bonusName: '',
        type: '',
        price: '',
        createdDate: '',
        expiredDate: '',
        logo: null as File | null,
    });

    // Safely initialize preview with optional chaining
    const [preview, setPreview] = useState<string | null>(bonusData?.logoUrl ?? null);

    // Prefill form when modal opens or bonusData changes
    useEffect(() => {
        if (bonusData) {
            setForm({
                bonusName: bonusData.bonusName || '',
                type: bonusData.type || '',
                price: bonusData.price || '',
                createdDate: bonusData.createdDate || '',
                expiredDate: bonusData.expiredDate || '',
                logo: null,
            });

            if (bonusData.logoUrl) {
                setPreview(bonusData.logoUrl);
            } else {
                setPreview(null);
            }
        }
    }, [bonusData]);

    // Don't render if modal is closed or bonusData is missing
    if (!isOpen || !bonusData) return null;

    const handleChange = (e: ChangeEvent<HTMLInputElement>) => {
        const { name, value, files } = e.target;

        if (name === 'logo' && files?.[0]) {
            const file = files[0];
            setForm((prev) => ({ ...prev, logo: file }));

            const reader = new FileReader();
            reader.onloadend = () => {
                setPreview(reader.result as string);
            };
            reader.readAsDataURL(file);
        } else {
            setForm((prev) => ({ ...prev, [name]: value }));
        }
    };

    const handleSubmit = (e: FormEvent) => {
        e.preventDefault();
        toast.success('Bonus updated successfully!');
        console.log('Updated:', form);
        onClose();
    };

    return (
        <div className="fixed inset-0 z-50 flex justify-center items-center px-4">
            <div className="absolute inset-0 bg-black opacity-80"></div>

            <div className="relative z-10 bg-white rounded-2xl p-8 w-full md:w-1/2 max-w-2xl">
                <h3 className="text-[24px] font-semibold mb-5 text-[#E8632C]">Edit Bonus</h3>

                {/* Upload Logo */}
                <label
                    htmlFor="logoInput"
                    className="flex flex-col justify-center items-center border-2 w-32 h-32 border-dashed border-gray-300 rounded-xl text-gray-500 cursor-pointer mb-6 mx-auto overflow-hidden"
                >
                    {preview ? (
                        <Image
                            src={preview}
                            alt="Logo Preview"
                            width={128}
                            height={128}
                            className="object-cover w-full h-full"
                        />
                    ) : (
                        <>
                            <ArrowUpTrayIcon className="w-6 h-6 text-gray-500" />
                            <span className="mt-2 text-sm text-center">Upload logo</span>
                        </>
                    )}
                </label>
                <input
                    type="file"
                    id="logoInput"
                    name="logo"
                    accept="image/*"
                    onChange={handleChange}
                    className="hidden"
                />

                <form onSubmit={handleSubmit}>
                    {/* Bonus Name */}
                    <div className="mb-4">
                        <label className="block text-[#828282] text-[18px] font-medium mb-1">Bonus Name</label>
                        <input
                            type="text"
                            name="bonusName"
                            value={form.bonusName}
                            onChange={handleChange}
                            className="px-4 text-[18px] border border-[#828282] focus:ring-1 focus:ring-[#828282] focus:outline-none py-2 h-[60px] w-full rounded-2xl text-[#828282]"
                        />
                    </div>

                    {/* Type */}
                    <div className="mb-4">
                        <label className="block text-[#828282] text-[18px] font-medium mb-1">Type</label>
                        <input
                            type="text"
                            name="type"
                            value={form.type}
                            onChange={handleChange}
                            className="px-4 text-[18px] border border-[#828282] focus:ring-1 focus:ring-[#828282] focus:outline-none py-2 h-[60px] w-full rounded-2xl text-[#828282]"
                        />
                    </div>

                    {/* Price */}
                    <div className="mb-4">
                        <label className="block text-[#828282] text-[18px] font-medium mb-1">Price</label>
                        <input
                            type="text"
                            name="price"
                            value={form.price}
                            onChange={handleChange}
                            className="px-4 text-[18px] border border-[#828282] focus:ring-1 focus:ring-[#828282] focus:outline-none py-2 h-[60px] w-full rounded-2xl text-[#828282]"
                        />
                    </div>

                    {/* Dates */}
                    <div className="mb-4 flex gap-4">

                        <div className="w-full">
                            <label className="block text-[#828282] text-[18px] font-medium mb-1">Expired Date</label>
                            <input
                                type="date"
                                name="expiredDate"
                                value={form.expiredDate}
                                onChange={handleChange}
                                className="px-4 text-[18px] border border-[#828282] focus:ring-1 focus:ring-[#828282] focus:outline-none py-2 h-[60px] w-full rounded-2xl text-[#828282]"
                            />
                        </div>
                    </div>

                    {/* Buttons */}
                    <div className="flex justify-center mt-6">
                        <button
                            type="submit"
                            className="hover:opacity-80 hover:bg-[#E8632C] transition duration-300 bg-[#E8632C] text-white px-6 py-3 rounded-md"
                        >
                            Update Bonus
                        </button>
                        <button
                            type="button"
                            className="ml-4 bg-red-500 text-white duration-300 border border-white px-7 rounded-md hover:bg-[#a12020]"
                            onClick={onClose}
                        >
                            Cancel
                        </button>
                    </div>
                </form>
            </div>
        </div>
    );
};

export default EditBonus;
