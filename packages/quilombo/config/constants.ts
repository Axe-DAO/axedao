import { LinkType } from '@/db/schema';
import { ImageType } from '@/types/model';
import { ResizeOptions } from 'sharp';

export const titles = [
  'mestre',
  'mestra',
  'contra-mestre',
  'contra-mestra',
  'mestrando',
  'mestranda',
  'professor',
  'professora',
  'instrutor',
  'instrutora',
  'monitor',
  'monitora',
  'aluno',
  'aluna',
  'iniciante',
] as const;

export const linkTypes = ['twitter', 'facebook', 'instagram', 'linkedin'] as const;

export const validFileExtensions = { image: ['jpg', 'gif', 'png', 'jpeg', 'svg', 'webp'] } as const;

export const linkBaseUrls = [
  {
    type: 'twitter',
    baseUrls: ['twitter.com', 'twitter.co', 'x.com', 'twitterinc.com'],
  },
  {
    type: 'facebook',
    baseUrls: ['facebook.com', 'facebook.co', 'facebook.net', 'fb.com', 'fb.me'],
  },
  {
    type: 'instagram',
    baseUrls: ['instagram.com', 'ig.me'],
  },
  {
    type: 'linkedin',
    baseUrls: ['linkedin.com', 'linkedin.cn'],
  },
];

export const PATHS = {
  login: '/auth/login',
  search: '/search',
  profile: '/profile',
  admin: '/admin',
  axe: '/axe',
  dao: '/dao',
  users: '/users',
  groups: '/groups',
  settings: '/settings',
};

// Note: The order of these roles in the array is used to sort group members by role in the UI
export const GROUP_ROLES = ['founder', 'leader', 'admin', 'member'] as const;

export const QUERY_DEFAULT_PAGE_SIZE = 25;

export const QueryConfig = {
  staleTimeDefault: 1000 * 60 * 15, // 15 minutes
  staleTimeGroup: 1000 * 60 * 60 * 24, // 24 hours
  staleTimeGroupMembers: 1000 * 60 * 60, // 1 hour
  staleTimeUser: 1000 * 60 * 60 * 24, // 24 hours
};

export const GROUP_DESCRIPTION_MAX_LENGTH = 500;

export const SEARCH_INPUT_DEBOUNCE = 750;

export const IMAGE_TYPES = ['userAvatar', 'groupLogo', 'groupBanner'] as const;

export const FILE_PREFIXES: Record<ImageType, string> = {
  userAvatar: 'user-avatar',
  groupLogo: 'group-logo',
  groupBanner: 'group-banner',
};

export const IMAGE_FORMATS: Record<ImageType, ResizeOptions> = {
  userAvatar: { width: 300, height: 300 },
  groupLogo: { width: 200, height: 200 },
  groupBanner: { height: 250, width: 800, fit: 'cover', position: 'attention' },
};

export const MAX_IMAGE_UPLOAD_SIZE_MB = 4.5; // 4.5 MB is the current limit for Vercel serverless functions! https://vercel.com/docs/concepts/limits/overview#serverless-function-payload-size-limit

export const PINATA_FILE_GROUP = 'd923dfed-5f8d-440b-ae87-e8a43504eaa5'; // quilombo group ID

export type IconDictionary = Record<LinkType, JSX.Element>; // TODO not used
