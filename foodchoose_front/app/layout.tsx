import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "뭐 먹을건데",
  description:
    "먹고 싶은 음식과 먹기 싫은 음식 카테고리를 고르면 오늘 메뉴를 하나 정해줘요.",
  openGraph: {
    title: "뭐 먹을건데",
    description:
      "먹고 싶은 음식과 먹기 싫은 음식 카테고리를 고르면 오늘 메뉴를 하나 정해줘요.",
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
      <body>{children}</body>
    </html>
  );
}
