import { redirect } from "next/navigation";

export default function HomePage() {
  // শুধু redirect করবে
  redirect("/singin");
}