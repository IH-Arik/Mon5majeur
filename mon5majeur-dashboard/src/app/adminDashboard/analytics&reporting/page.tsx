import Image from "next/image";
import img1 from "@/app/assets/ball.png";
import UserChart from "@/components/modules/dashboard/chart/UserChart";
import DurationChart from "@/components/modules/dashboard/chart/DurationChart";
import LeagueChart from "@/components/modules/dashboard/chart/LeagueChart";

export default function Page() {
  return (
    <div>
      <section className="w-full">
        <div className="grid grid-cols-1 md:grid-cols-12 md:h-[400px] lg:h-[500px] overflow-hidden">
          {/* Left (8/12 on md+) */}
          <div className="md:col-span-7 lg:col-span-8 bg-[#FFE1D4] flex flex-col justify-center p-6 sm:p-8 lg:px-12 gap-6">
            <h1 className="text-3xl sm:text-4xl lg:text-[45px] font-semibold leading-tight text-[#111111]">
              Comprehensive <br className="hidden sm:block" /> Game Analytics
            </h1>

            <p className="text-base sm:text-lg text-[#333333] max-w-xl">
              Uncover deep insights into player behavior, content performance, and
              monetization strategies to drive game growth and engagement.
            </p>

            <button className="border border-[#111111] hover:border-white  px-10 lg:px-14 py-2 w-fit hover:bg-[#E8632C] hover:text-white transition">
              Explore
            </button>
          </div>

          {/* Right (4/12 on md+) */}
          <div className="md:col-span-5 lg:col-span-4 relative flex items-center justify-center h-64 sm:h-80 md:h-auto">
            {/* Prevent overflow on large screens */}
            <div className="relative w-full h-full">
              <Image
                src={img1}
                alt="Basketball"
                fill
                className="object-vover object-center"
                // sizes="(max-width: 768px) 100vw, (max-width: 1024px) 40vw, 33vw"
                priority
              />
            </div>
          </div>
        </div>
      </section>
      <h2 className="text-center text-[28px] font-semibold mt-15 mb-10">User Activity & Engagement</h2>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <UserChart></UserChart>
        <DurationChart></DurationChart>
        <LeagueChart></LeagueChart>
      </div>
    </div>
  );
}
