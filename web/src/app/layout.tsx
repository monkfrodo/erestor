import type { Metadata, Viewport } from "next";
import "./globals.css";
import { SWRegistrar } from "./sw-registrar";

export const metadata: Metadata = {
  title: "Erestor",
  description: "Personal intelligence assistant",
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
  themeColor: "#1e1c1a",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="pt-BR">
      <body className="font-body antialiased">
        {children}
        <SWRegistrar />
      </body>
    </html>
  );
}
