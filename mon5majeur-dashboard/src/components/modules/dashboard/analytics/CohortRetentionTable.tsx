interface CohortRow {
  cohort_week: string;
  cohort_size: number;
  retained: Record<string, number>;
  rates: Record<string, number>;
}

// Sequential heatmap band for a 0..1 rate — a light->dark single hue, exactly
// as a magnitude encoding should be. Never used to imply status (good/bad).
function bandFor(rate: number): string {
  if (rate >= 0.5) return "bg-[#E8632C] text-white";
  if (rate >= 0.3) return "bg-[#f3ab8c] text-[#5a2c14]";
  if (rate >= 0.15) return "bg-[#fbe0d1] text-[#5a2c14]";
  if (rate > 0) return "bg-[#fdf1e9] text-[#5a2c14]";
  return "bg-[#f8f8f8] text-gray-400";
}

export default function CohortRetentionTable({
  dayOffsets,
  rows,
}: {
  dayOffsets: number[];
  rows: CohortRow[];
}) {
  return (
    <div className="bg-white p-6 rounded-xl shadow-sm w-full h-full">
      <h2 className="text-lg md:text-xl font-semibold text-gray-700 mb-1">
        Cohort Retention
      </h2>
      <p className="text-sm text-gray-400 mb-4">
        Rows = signup week. A blank cell means that day offset hasn&apos;t happened
        yet for this cohort — not 0%.
      </p>

      {rows.length === 0 ? (
        <div className="py-10 text-center text-gray-400 text-sm">No signups yet</div>
      ) : (
        <div className="overflow-x-auto">
          <table className="min-w-full text-sm text-left">
            <thead className="text-[#828282] text-[12px]">
              <tr>
                <th className="px-3 py-2">Cohort Week</th>
                <th className="px-3 py-2">Size</th>
                {dayOffsets.map((d) => (
                  <th key={d} className="px-3 py-2 text-center">
                    D{d}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {rows.map((row) => (
                <tr key={row.cohort_week} className="border-t border-[#f0f0f0]">
                  <td className="px-3 py-2 whitespace-nowrap">
                    {new Date(row.cohort_week).toLocaleDateString("en-GB", {
                      day: "2-digit",
                      month: "short",
                      year: "numeric",
                    })}
                  </td>
                  <td className="px-3 py-2">{row.cohort_size}</td>
                  {dayOffsets.map((d) => {
                    const key = String(d);
                    const rate = row.rates[key];
                    if (rate === undefined) {
                      return (
                        <td key={d} className="px-3 py-2 text-center text-gray-300">
                          —
                        </td>
                      );
                    }
                    return (
                      <td key={d} className="px-1 py-1 text-center">
                        <div className={`rounded px-2 py-1 ${bandFor(rate)}`}>
                          {Math.round(rate * 100)}%
                        </div>
                      </td>
                    );
                  })}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
