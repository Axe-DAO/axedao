import clsx from 'clsx';
import { Metadata, Viewport } from 'next';
import { getServerSession } from 'next-auth';

import Navbar from '@/components/Navbar';
import SessionProvider from '@/components/SessionProvider';
import { fontFiraCode, fontInter, fontOpenSans } from '@/config/fonts';
import { nextAuthOptions } from '@/config/next-auth-options';
import { siteConfig } from '@/config/site';
import StateProvider from './_providers/jotai.provider';
import ThemeProvider from './_providers/nextUI.provider';
import QueryProvider from './_providers/query.provider';
import SnackbarProvider from './_providers/snackbar.provider';
import Web3Provider from './_providers/wagmi.provider';

import BreadcrumbTracker from '@/components/BreadcrumbTracker';
import '@/styles/globals.css';

export const metadata: Metadata = {
  title: {
    default: siteConfig.name,
    template: `%s - ${siteConfig.name}`,
  },
  description: siteConfig.description,
  icons: {
    icon: '/quilombo-icon-192x192.png',
    shortcut: '/favicon.ico',
    apple: '/quilombo-icon-apple-touch.png',
    other: [
      {
        rel: 'icon',
        type: 'image/png',
        sizes: '32x32',
        url: '/quilombo-icon-32x32.png',
      },
      {
        rel: 'icon',
        type: 'image/png',
        sizes: '16x16',
        url: '/quilombo-icon-16x16.png',
      },
    ],
  },
};

export const viewport: Viewport = {
  themeColor: [
    { media: '(prefers-color-scheme: light)', color: 'white' },
    { media: '(prefers-color-scheme: dark)', color: 'black' },
  ],
};

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const session = await getServerSession(nextAuthOptions);
  return (
    <html lang="en" suppressHydrationWarning>
      <head />
      <body
        className={clsx(
          'min-h-screen bg-background font-sans antialiased',
          fontInter.variable,
          fontFiraCode.variable,
          fontOpenSans.variable,
        )}
      >
        <SessionProvider session={session}>
          <ThemeProvider themeProps={{ attribute: 'class', defaultTheme: 'dark', children: null }}>
            <SnackbarProvider>
              <QueryProvider>
                {/* Note: Web3Provider and StateProvider rely on @tanstack/react-query. */}
                <Web3Provider>
                  <StateProvider>
                    <BreadcrumbTracker />
                    <div className="relative flex min-h-screen flex-col">
                      <Navbar />
                      <main className="container mx-auto max-w-3xl flex-grow mb-[60px]">{children}</main>
                    </div>
                  </StateProvider>
                </Web3Provider>
              </QueryProvider>
            </SnackbarProvider>
          </ThemeProvider>
        </SessionProvider>
      </body>
    </html>
  );
}
