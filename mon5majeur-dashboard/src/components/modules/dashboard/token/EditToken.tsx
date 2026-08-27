"use client";

import { useEffect, useState, FormEvent } from "react";
import toast from "react-hot-toast";
import baseApi from "@/api/baseAPi";
import { ENDPOINTS } from "@/api/endPoints";
import type { TokenPack } from "./AllToken";

type EditTokenProps = {
  isOpen: boolean;
  onClose: () => void;
  pack: TokenPack;
  onSaved: (updated: TokenPack) => void;
};

const EditToken = ({ isOpen, onClose, pack, onSaved }: EditTokenProps) => {
  const [tokenAmount, setTokenAmount] = useState(String(pack.token_amount));
  const [priceUsd, setPriceUsd] = useState(String(pack.price_usd));
  const [isActive, setIsActive] = useState(pack.is_active);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    setTokenAmount(String(pack.token_amount));
    setPriceUsd(String(pack.price_usd));
    setIsActive(pack.is_active);
  }, [pack]);

  if (!isOpen) return null;

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    const tokens = Number(tokenAmount);
    const price = Number(priceUsd);
    if (!Number.isFinite(tokens) || tokens <= 0) {
      toast.error("Token amount must be a positive number");
      return;
    }
    if (!Number.isFinite(price) || price < 0) {
      toast.error("Price must be a non-negative number");
      return;
    }

    setSaving(true);
    try {
      const response = await baseApi.patch<TokenPack>(
        ENDPOINTS.adminTokenPackCatalogItem(pack.slug),
        { token_amount: tokens, price_usd: price, is_active: isActive },
      );
      onSaved(response.data);
      toast.success("Token pack updated successfully!");
      onClose();
    } catch (error) {
      console.error("Error updating token pack:", error);
      toast.error("Failed to update token pack");
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex justify-center items-center px-4">
      <div className="absolute inset-0 bg-black opacity-80"></div>

      <div className="relative z-10 bg-white rounded-2xl p-8 w-full md:w-1/2 max-w-2xl">
        <h3 className="text-[24px] font-semibold mb-1 text-[#E8632C]">Edit Pack</h3>
        <p className="text-[#828282] mb-5">{pack.display_name}</p>

        <form onSubmit={handleSubmit}>
          <div className="mb-4">
            <label className="block text-[#828282] text-[18px] font-medium mb-1">
              Token Amount
            </label>
            <input
              type="number"
              min={1}
              value={tokenAmount}
              onChange={(e) => setTokenAmount(e.target.value)}
              className="px-4 text-[18px] border border-[#828282] focus:ring-1 focus:ring-[#828282] focus:outline-none py-2 h-[60px] w-full rounded-2xl text-[#828282]"
            />
          </div>

          <div className="mb-4">
            <label className="block text-[#828282] text-[18px] font-medium mb-1">
              Display Price (USD)
            </label>
            <input
              type="number"
              min={0}
              step="0.01"
              value={priceUsd}
              onChange={(e) => setPriceUsd(e.target.value)}
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
              {saving ? "Saving..." : "Update Pack"}
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

export default EditToken;
