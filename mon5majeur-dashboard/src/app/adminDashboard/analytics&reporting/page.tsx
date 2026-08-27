import Image from "next/image";
import img1 from "@/app/assets/ball.png";
import RetentionOverview from "@/components/modules/dashboard/analytics/RetentionOverview";

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
                priority
              />
            </div>
          </div>
        </div>
      </section>
      <h2 className="text-center text-[28px] font-semibold mt-15 mb-2">Retention Analytics</h2>
      <p className="text-center text-gray-500 mb-6">
        Every figure below counts a validated lineup — never &quot;opened the app&quot;.
      </p>
      <RetentionOverview />
    </div>
  );
}
