import axios, { AxiosError } from 'axios';

import { GroupMemberRole } from '@/store/groupMembers.store';
import { User } from '@/types/model';

export const generateErrorMessage = (error: unknown, defaultMessage: string) => {
  let message = defaultMessage;
  const isAxiosError = error instanceof AxiosError;
  if (error instanceof Error && typeof error?.message === 'string') {
    message = error.message;
  }
  if (isAxiosError && error.response?.data?.error && error.response?.data?.message) {
    message = error.response?.data?.message;
  }

  return message;
};

export const uploadImage = async (imageFile: File, name?: string) => {
  const data = new FormData();
  data.set('file', imageFile);
  if (name) data.set('name', name);
  const res = await axios.post('/api/images', data, { headers: { 'Content-Type': 'multipart/form-data' } });
  const url: string = res.data?.url;
  if (url) return url;
};

export const getGroupMemberRole = (userId: string, founder?: string, leader?: string, adminIds?: string[]) => {
  let role = 'member';
  if (userId === founder) {
    role = 'founder';
  } else if (userId === leader) {
    role = 'leader';
  } else if (adminIds?.includes(userId)) {
    role = 'admin';
  }
  return role as GroupMemberRole;
};

export const removeTrailingSlash = (val: string) => (val.endsWith('/') ? val.substring(0, val.length - 1) : val);

/**
 * Adds two numbers and returns the result.
 *
 * @param pathname - The literal pathname e.g /api/groups/76848.
 * @param path - The path of the route.ts file according to Nextjs conventions e.g /api/groups/[groupId].
 * @returns A boolean of whether pathname is handled by the file in path match.
 */
export const matchesPathname = (pathname: string, path: string) => {
  if (pathname === path) {
    return true;
  }
  const basePathname = removeTrailingSlash(pathname.split('?')[0] as string);
  const basePath = removeTrailingSlash(path.split('?')[0] as string);
  if (basePathname === basePath) {
    return true;
  }
  const basePathRegex = new RegExp(
    `^${basePath.replace(/(\[[a-zA-Z0-9-]+\])+/g, '[a-zA-Z0-9-]+')}$`
      .replace(/\[\[\.\.\.[a-zA-Z0-9-]+\]\]/g, '?.*')
      .replace(/\[\.\.\.[a-zA-Z0-9-]+\]/g, '.*'),
  );
  if (basePathRegex.test(basePathname)) {
    return true;
  }
  return false;
};

export const isUUID = (str: string) => {
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  return uuidRegex.test(str);
};

/**
 * Extracts the hostname out of a URL
 * @param url
 * @returns the SLD, domain without the www. prefix and TLD. Example: www.facebook.com -> facebook
 * @throws MalformedUrlError
 */
export const getHostname = (url: string): string | undefined => {
  try {
    // Add a protocol if missing
    if (url.indexOf('//:') === -1) {
      url = `https://${url}`;
    }
    const host = new URL(url).hostname;
    const domain = host.replace('www.', '');
    return domain.split('.')[0];
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
  } catch (error) {}
  return undefined;
};

export const getUserDisplayName = (user: User): string => {
  let displayName = '';
  if (user.nickname) {
    displayName = user.nickname;
  }
  if (user.name) {
    displayName += displayName === '' ? user.name : ` (${user.name})`;
  }
  return displayName || `Anonymous (${user.walletAddress})`;
};
