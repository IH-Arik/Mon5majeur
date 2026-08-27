"use client";

import React, { useEffect, useState } from "react";
import Swal from "sweetalert2";
import { CiEdit } from "react-icons/ci";
import EditToken from "./EditToken";
import baseApi from "@/api/baseAPi";
import { ENDPOINTS } from "@/api/endPoints";

export interface TokenPack {
  slug: string;
  display_name: string;
  token_amount: number;
  price_usd: number;
  is_active: boolean;
}

export default function AllToken() {
  const [packs, setPacks] = useState<TokenPack[]>([]);
  const [loading, setLoading] = useState(true);
  const [isEditOpen, setIsEditOpen] = useState(false);
  const [selectedPack, setSelectedPack] = useState<TokenPack | null>(null);
  const [togglingSlug, setTogglingSlug] = useState<string | null>(null);

  const fetchPacks = async () => {
    try {
      setLoading(true);
      const response = await baseApi.get<TokenPack[]>(ENDPOINTS.adminTokenPackCatalog);
      setPacks(response.data);
    } catch (error) {
      console.error("Error fetching token packs:", error);
      Swal.fire({
        title: "Error!",
        text: "Failed to fetch token packs",
        icon: "error",
        confirmButtonColor: "#319EE1",
      });
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchPacks();
  }, []);

  const handleEditClick = (pack: TokenPack) => {
    setSelectedPack(pack);
    setIsEditOpen(true);
  };

  const handleToggleActive = async (pack: TokenPack) => {
    setTogglingSlug(pack.slug);
    try {
      const response = await baseApi.patch<TokenPack>(
        ENDPOINTS.adminTokenPackCatalogItem(pack.slug),
        { is_active: !pack.is_active },
      );
      setPacks((prev) => prev.map((p) => (p.slug === pack.slug ? response.data : p)));
    } catch (error) {
      console.error("Error updating token pack status:", error);
      Swal.fire({
        title: "Error!",
        text: "Failed to update token pack status",
        icon: "error",
        confirmButtonColor: "#319EE1",
      });
    } finally {
      setTogglingSlug(null);
    }
  };

  const handleSaved = (updated: TokenPack) => {
    setPacks((prev) => prev.map((p) => (p.slug === updated.slug ? updated : p)));
  };

  return (
    <div>
      <div className="bg-white shadow rounded-lg overflow-hidden p-6">
        <h2 className="text-[22px] font-semibold">Token Packs</h2>
        <p className="mb-6 text-[#828282]">
          These 4 packs are built into the app&apos;s shop screen — you can
          change their token amount, display price, or turn one off, but not
          add or remove a pack.
        </p>

        <div className="overflow-x-auto">
          <table className="min-w-full text-sm text-left">
            <thead className="text-[#828282] text-[12px]">
              <tr>
                <th className="px-6 py-3">Pack Name</th>
                <th className="px-6 py-3">Tokens</th>
                <th className="px-6 py-3">Price</th>
                <th className="px-6 py-3">Status</th>
                <th className="px-6 py-3">Action</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={5} className="text-center py-8 text-gray-500">
                    Loading token packs...
                  </td>
                </tr>
              ) : (
                packs.map((pack, i) => (
                  <tr
                    key={pack.slug}
                    className={`${i % 2 === 0 ? "bg-[#f8f8f8]" : "bg-white"}`}
                  >
                    <td className="px-6 py-4">{pack.display_name}</td>
                    <td className="px-6 py-4">{pack.token_amount}</td>
                    <td className="px-6 py-4">${pack.price_usd.toFixed(2)}</td>
                    <td className="px-6 py-4 font-medium">
                      <button
                        disabled={togglingSlug === pack.slug}
                        onClick={() => handleToggleActive(pack)}
                        className={`cursor-pointer disabled:opacity-50 ${
                          pack.is_active ? "text-green-500" : "text-red-400"
                        }`}
                      >
                        {pack.is_active ? "Active" : "Inactive"}
                      </button>
                    </td>
                    <td className="px-6 py-4">
                      <div
                        onClick={() => handleEditClick(pack)}
                        className="text-blue-500 cursor-pointer hover:text-blue-700 text-[24px] w-fit"
                        title="Edit"
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

      {isEditOpen && selectedPack && (
        <EditToken
          isOpen={isEditOpen}
          onClose={() => setIsEditOpen(false)}
          pack={selectedPack}
          onSaved={handleSaved}
        />
      )}
    </div>
  );
}
