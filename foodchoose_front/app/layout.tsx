import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "뭐 먹을건데",
  description:
    "각자 먹고 싶은 음식과 먹기 싫은 음식을 적으면 AI가 모두의 취향을 분석해 최선의 메뉴를 선택해줘요.",
  openGraph: {
    title: "뭐 먹을건데",
    description:
      "각자 먹고 싶은 음식과 먹기 싫은 음식을 적으면 AI가 모두의 취향을 분석해 최선의 메뉴를 선택해줘요.",
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
