import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "골라음식 - 오늘 뭐 먹지?",
  description: "친구들과 함께 AI가 추천하는 음식을 골라보세요!",
  openGraph: {
    title: "골라음식 - 오늘 뭐 먹지?",
    description: "친구들과 함께 AI가 추천하는 음식을 골라보세요!",
    type: "website",
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="ko">
      <body className="bg-[#FFF8F0] min-h-screen">{children}</body>
    </html>
  );
}
