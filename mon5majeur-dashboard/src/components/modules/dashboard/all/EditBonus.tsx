"use client";

import { useEffect, useState, FormEvent } from "react";
import toast from "react-hot-toast";
import baseApi from "@/api/baseAPi";
import { ENDPOINTS } from "@/api/endPoints";
import type { BonusOffer } from "./AllBonus";

type EditBonusProps = {
  isOpen: boolean;
  onClose: () => void;
  bonus: BonusOffer;
  onSaved: (updated: BonusOffer) => void;
};

const EditBonus = ({ isOpen, onClose, bonus, onSaved }: EditBonusProps) => {
  const [tokenCost, setTokenCost] = useState(String(bonus.token_cost));
  const [isActive, setIsActive] = useState(bonus.is_active);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    setTokenCost(String(bonus.token_cost));
    setIsActive(bonus.is_active);
  }, [bonus]);

  if (!isOpen) return null;

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    const parsed = Number(tokenCost);
    if (!Number.isFinite(parsed) || parsed < 0) {
      toast.error("Token cost must be a non-negative number");
      return;
    }

    setSaving(true);
    try {
      const response = await baseApi.patch<BonusOffer>(
        ENDPOINTS.adminBonusCatalogItem(bonus.slug),
        { token_cost: parsed, is_active: isActive },
      );
      onSaved(response.data);
      toast.success("Bonus updated successfully!");
      onClose();
    } catch (error) {
      console.error("Error updating bonus:", error);
      toast.error("Failed to update bonus");
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex justify-center items-center px-4">
      <div className="absolute inset-0 bg-black opacity-80"></div>

      <div className="relative z-10 bg-white rounded-2xl p-8 w-full md:w-1/2 max-w-2xl">
        <h3 className="text-[24px] font-semibold mb-1 text-[#E8632C]">Edit Bonus</h3>
        <p className="text-[#828282] mb-5">{bonus.display_name}</p>

        <form onSubmit={handleSubmit}>
          <div className="mb-4">
            <label className="block text-[#828282] text-[18px] font-medium mb-1">
              Token Cost
            </label>
            <input
              type="number"
              min={0}
              value={tokenCost}
              onChange={(e) => setTokenCost(e.target.value)}
              className="px-4 text-[18px] border border-[#828282] focus:ring-1 focus:ring-[#828282] focus:outline-none py-2 h-[60px] w-full rounded-2xl text-[#828282]"
            />
          </div>

          <label className="flex items-center gap-2 mb-4 text-[#828282] text-[18px] font-medium">
            <input
              type="checkbox"
              checked={isActive}
              onChange={(e) => setIsActive(e.target.checked)}
              className="w-5 h-5"
            />
            Active (visible and purchasable in the app)
          </label>

          <div className="flex justify-center mt-6">
            <button
              type="submit"
              disabled={saving}
              className="hover:opacity-80 hover:bg-[#E8632C] transition duration-300 bg-[#E8632C] text-white px-6 py-3 rounded-md disabled:opacity-50"
            >
              {saving ? "Saving..." : "Update Bonus"}
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
