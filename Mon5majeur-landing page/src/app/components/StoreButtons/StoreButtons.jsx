import React from "react";
import Image from "next/image";

// The app is live on both stores (Arik QA item 15).
export const PLAY_STORE_URL =
  "https://play.google.com/store/apps/details?id=com.mon5majeur.app";
export const APP_STORE_URL =
  "https://apps.apple.com/fr/app/mon5majeur/id6753639666";

const imageClass =
  "h-10 sm:h-14 md:h-16 hover:opacity-90 transition-opacity bg-dark/50 rounded-lg w-auto object-contain";

/** The Google Play and App Store badges, each opening its store page. */
function StoreButtons({ labels = {}, className = "" }) {
  return (
    <div className={`flex flex-row items-center gap-4 sm:gap-6 ${className}`}>
      <a
        href={PLAY_STORE_URL}
        target="_blank"
        rel="noopener noreferrer"
        className="transition-transform active:scale-95"
        aria-label={labels.googlePlay || "Google Play"}
      >
        <Image
          src="/images/google-play.png"
          height={64}
          width={180}
          alt={labels.googlePlay || "Google Play"}
          className={imageClass}
        />
      </a>
      <a
        href={APP_STORE_URL}
        target="_blank"
        rel="noopener noreferrer"
        className="transition-transform active:scale-95"
        aria-label={labels.appStore || "App Store"}
      >
        <Image
          src="/images/app-store.png"
          height={64}
          width={180}
          alt={labels.appStore || "App Store"}
          className={imageClass}
        />
      </a>
    </div>
  );
}

export default StoreButtons;
