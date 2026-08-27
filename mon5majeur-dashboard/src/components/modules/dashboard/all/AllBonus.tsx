"use client";

import React, { useEffect, useState } from "react";
import Swal from "sweetalert2";
import { CiEdit } from "react-icons/ci";
import EditBonus from "./EditBonus";
import baseApi from "@/api/baseAPi";
import { ENDPOINTS } from "@/api/endPoints";

export interface BonusOffer {
  slug: string;
  display_name: string;
  token_cost: number;
  is_active: boolean;
}

export default function AllBonus() {
  const [offers, setOffers] = useState<BonusOffer[]>([]);
  const [loading, setLoading] = useState(true);
  const [isEditOpen, setIsEditOpen] = useState(false);
  const [selectedBonus, setSelectedBonus] = useState<BonusOffer | null>(null);
  const [togglingSlug, setTogglingSlug] = useState<string | null>(null);

  const fetchOffers = async () => {
    try {
      setLoading(true);
      const response = await baseApi.get<BonusOffer[]>(ENDPOINTS.adminBonusCatalog);
      setOffers(response.data);
    } catch (error) {
      console.error("Error fetching bonuses:", error);
      Swal.fire({
        title: "Error!",
        text: "Failed to fetch bonuses",
        icon: "error",
        confirmButtonColor: "#319EE1",
      });
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchOffers();
  }, []);

  const handleEditClick = (bonus: BonusOffer) => {
    setSelectedBonus(bonus);
    setIsEditOpen(true);
  };

  const handleToggleActive = async (bonus: BonusOffer) => {
    setTogglingSlug(bonus.slug);
    try {
      const response = await baseApi.patch<BonusOffer>(
        ENDPOINTS.adminBonusCatalogItem(bonus.slug),
        { is_active: !bonus.is_active },
      );
      setOffers((prev) =>
        prev.map((o) => (o.slug === bonus.slug ? response.data : o)),
      );
    } catch (error) {
      console.error("Error updating bonus status:", error);
      Swal.fire({
        title: "Error!",
        text: "Failed to update bonus status",
        icon: "error",
        confirmButtonColor: "#319EE1",
      });
    } finally {
      setTogglingSlug(null);
    }
  };

  const handleSaved = (updated: BonusOffer) => {
    setOffers((prev) => prev.map((o) => (o.slug === updated.slug ? updated : o)));
  };

  return (
    <div>
      <div className="bg-white shadow rounded-lg overflow-hidden p-6">
        <h2 className="text-[22px] font-semibold">Manage Bonuses</h2>
        <p className="mb-6 text-[#828282]">
          These 5 bonus types are built into the app — you can change their
          token price or turn one off, but not add or remove a bonus type.
        </p>

        <div className="overflow-x-auto">
          <table className="min-w-full text-sm text-left">
            <thead className="text-[#828282] text-[12px]">
              <tr>
                <th className="px-6 py-3">Bonus</th>
                <th className="px-6 py-3">Token Cost</th>
                <th className="px-6 py-3">Status</th>
                <th className="px-6 py-3">Action</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={4} className="text-center py-8 text-gray-500">
                    Loading bonuses...
                  </td>
                </tr>
              ) : (
                offers.map((offer, i) => (
                  <tr
                    key={offer.slug}
                    className={`${i % 2 === 0 ? "bg-[#f8f8f8]" : "bg-white"}`}
                  >
                    <td className="px-6 py-4">{offer.display_name}</td>
                    <td className="px-6 py-4">{offer.token_cost} tokens</td>
                    <td className="px-6 py-4 font-medium">
                      <button
                        disabled={togglingSlug === offer.slug}
                        onClick={() => handleToggleActive(offer)}
                        className={`cursor-pointer disabled:opacity-50 ${
                          offer.is_active ? "text-green-500" : "text-red-400"
                        }`}
                      >
                        {offer.is_active ? "Active" : "Inactive"}
                      </button>
                    </td>
                    <td className="px-6 py-4">
                      <div
                        onClick={() => handleEditClick(offer)}
                        className="text-blue-500 cursor-pointer hover:text-blue-700 text-[24px] w-fit"
                        title="Edit price"
                      >
                        <CiEdit />
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {isEditOpen && selectedBonus && (
        <EditBonus
          isOpen={isEditOpen}
          onClose={() => setIsEditOpen(false)}
          bonus={selectedBonus}
          onSaved={handleSaved}
        />
      )}
    </div>
  );
}
