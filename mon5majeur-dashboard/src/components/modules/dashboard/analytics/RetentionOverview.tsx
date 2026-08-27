"use client";

import { useEffect, useState } from "react";
import baseApi from "@/api/baseAPi";
import { ENDPOINTS } from "@/api/endPoints";
import LineupVolumeChart from "./LineupVolumeChart";
import CohortRetentionTable from "./CohortRetentionTable";

interface RetentionOverview {
  counters: {
    downloads: number;
    signups_today: number;
    dau: number;
    dau_7day_avg: number;
    dau_7day_nights_used: number;
    lineups_tonight: number;
    account_deletions: number;
    night_date: string | null;
  };
  cohorts: {
    day_offsets: number[];
    rows: {
      cohort_week: string;
      cohort_size: number;
      retained: Record<string, number>;
      rates: Record<string, number>;
    }[];
  };
  activation: {
    total_users: number;
    activated_users: number;
    activation_rate: number;
  };
  lineup_volume: {
    nights: { night_date: string; lineups_count: number }[];
  };
  private_league: {
    players_in_private: number;
    total_players: number;
    nights_considered: number;
  };
}

function StatTile({ label, value, hint }: { label: string; value: string | number; hint?: string }) {
  return (
    <div className="bg-white shadow rounded-2xl p-4 lg:px-6">
      <div className="text-[14px] md:text-[16px] text-[#828282] mb-2">{label}</div>
      <div className="text-[22px] md:text-[26px] font-semibold text-gray-800">{value}</div>
      {hint && <div className="text-[12px] text-gray-400 mt-1">{hint}</div>}
    </div>
  );
}

export default function RetentionOverview() {
  const [data, setData] = useState<RetentionOverview | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);

  useEffect(() => {
    const fetchOverview = async () => {
      try {
        setLoading(true);
        setError(false);
        const response = await baseApi.get<RetentionOverview>(ENDPOINTS.adminRetentionOverview);
        setData(response.data);
      } catch (err) {
        console.error("Error fetching retention overview:", err);
        setError(true);
      } finally {
        setLoading(false);
      }
    };

    fetchOverview();
  }, []);

  if (loading) {
    return <p className="text-gray-500 py-10 text-center">Loading analytics...</p>;
  }

  if (error || !data) {
    return (
      <p className="text-red-500 py-10 text-center">
        Failed to load retention analytics. Confirm you are signed in as an admin.
      </p>
    );
  }

  const { counters, cohorts, activation, lineup_volume, private_league } = data;

  return (
    <div className="mt-6">
      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-4 mb-6">
        <StatTile label="Total Accounts" value={counters.downloads} />
        <StatTile label="Signups Today" value={counters.signups_today} />
        <StatTile
          label="DAU Tonight"
          value={counters.night_date ? counters.dau : "—"}
          hint={counters.night_date ? counters.night_date : "no game night yet"}
        />
        <StatTile
          label="DAU 7-Night Avg"
          value={counters.dau_7day_avg}
          hint={`over ${counters.dau_7day_nights_used} night(s)`}
        />
        <StatTile label="Lineups Tonight" value={counters.lineups_tonight} />
        <StatTile label="Account Deletions" value={counters.account_deletions} />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 mb-6">
        <StatTile
          label="Activation Rate"
          value={`${Math.round(activation.activation_rate * 100)}%`}
          hint={`${activation.activated_users} of ${activation.total_users} signups ever validated a lineup`}
        />
        <StatTile
          label="Private League Players"
          value={`${private_league.players_in_private} / ${private_league.total_players}`}
          hint={`over the last ${private_league.nights_considered} match-night(s)`}
        />
      </div>

      <div className="grid grid-cols-1 gap-4 mb-6">
        <LineupVolumeChart nights={lineup_volume.nights} />
      </div>

      <div className="grid grid-cols-1 gap-4">
        <CohortRetentionTable dayOffsets={cohorts.day_offsets} rows={cohorts.rows} />
      </div>
    </div>
  );
}
