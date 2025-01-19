import { nextui } from '@nextui-org/theme';
import { withTV } from 'tailwind-variants/transformer';
// eslint-disable-next-line @typescript-eslint/no-require-imports
const defaultTheme = require('tailwindcss/defaultTheme');

/** @type {import('tailwindcss').Config} */
module.exports = withTV({
  content: [
    './pages/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
    './app/**/*.{js,ts,jsx,tsx,mdx}',
    './node_modules/@nextui-org/theme/dist/**/*.{js,ts,jsx,tsx}',
  ],
  theme: {
    screens: {
      xs: '480px',
      ...defaultTheme.screens, // 'sm': '640px', 'md': '768px', 'lg': '1024px', 'xl': '1280px', '2xl': '1536px'
    },
    extend: {
      fontFamily: {
        sans: 'var(--font-open-sans)',
        inter: 'var(--font-inter)',
      },
    },
  },
  darkMode: 'class',
  plugins: [
    nextui({
      layout: {
        height: {
          small: '10px',
          medium: '12px',
          large: '14px',
        },
      },
      themes: {
        dark: {
          colors: {
            primary: {
              DEFAULT: '#79D91F',
              50: '#4A9107',
              100: '#4F960D',
              200: '#59A116',
              300: '#66AE23',
              400: '#71B92E',
              500: '#7DC639',
              600: '#8FD84B',
              700: '#A3E664',
              800: '#B7F180',
              900: '#D3FAAE',
              foreground: '#000000',
            },
            secondary: {
              DEFAULT: '#aa825c',
              50: '#15100b',
              100: '#2a2117',
              200: '#55412e',
              300: '#947251',
              400: '#aa825c',
              500: '#bf9368',
              600: '#d8ac81',
              700: '#e1bf9d',
              800: '#ead1b9',
              900: '#f2e3d5',
              foreground: '#000000',
            },
          },
        },
        light: {
          colors: {
            primary: {
              DEFAULT: '#7FD92A',
              50: '#1F3A06',
              100: '#2D520A',
              200: '#3E6F11',
              300: '#538F1B',
              400: '#69AE29',
              500: '#7DC639',
              600: '#8FD84B',
              700: '#A3E664',
              800: '#B7F180',
              900: '#D3FAAE',
              foreground: '#000000',
            },
            secondary: {
              DEFAULT: '#D4A373',
              50: '#15100b',
              100: '#2a2117',
              200: '#55412e',
              300: '#947251',
              400: '#aa825c',
              500: '#bf9368',
              600: '#d8ac81',
              700: '#e1bf9d',
              800: '#ead1b9',
              900: '#f2e3d5',
              foreground: '#000000',
            },
          },
        },
      },
    }),
  ],
});
