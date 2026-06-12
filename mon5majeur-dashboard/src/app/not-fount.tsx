import Image from "next/image";
import img1 from "@/app/assets/auth/404.jpg";
import Link from "next/link";

export default function NotFound() {
  return (
    <div className="flex gap-10 flex-col md:flex-row items-center justify-center min-h-screen bg-black text-white px-6">
      {/* Image Section */}
      <div className="flex justify-center md:justify-end w-full md:w-1/2 mb-8 md:mb-0">
        <Image
          src={img1}
          alt="404 Illustration"
          width={500}
          height={500}
          className="rounded-2xl shadow-lg"
          priority
        />
      </div>

      {/* Text Section */}
      <div className="flex flex-col items-center md:items-start text-center md:text-left w-full md:w-1/2 space-y-4">
        <h2 className="text-6xl font-semibold">Page Not Found</h2>
        <p className="text-gray-300 max-w-md">
          Oops! The page you’re looking for doesn’t exist or might have been moved.
        </p>

        <Link
          href="/"
          className="inline-block mt-6 px-6 py-3 bg-[#319EE1] text-white rounded-lg transition"
        >
          Go Home
        </Link>
      </div>
    </div>
  );
}
