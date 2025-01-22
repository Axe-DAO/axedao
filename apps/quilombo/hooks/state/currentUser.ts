import { atom } from 'jotai';
import { atomWithQuery } from 'jotai-tanstack-query';

import { SocialLink } from '@/db/schema';
import { fetchCurrentUserOptions } from '@/query/currentUser';
import { fetchGroupOptions } from '@/query/group';
import { Group, User } from '@/types/model';
import { getImageUrl, getUserDisplayName } from '@/utils';

export const triggerCurrentUserIdAtom = atom<string | undefined>();

export const currentUserAtom = atomWithQuery<User | undefined>((get) =>
  fetchCurrentUserOptions(get(triggerCurrentUserIdAtom)),
);

export const currentUserGroupAtom = atomWithQuery<Group | undefined>((get) =>
  fetchGroupOptions(get(currentUserGroupIdAtom)),
);

export const currentUserDisplayNameAtom = atom<string>((get) => getUserDisplayName(get(currentUserAtom).data));

export const currentUserIdAtom = atom<string | undefined>((get) => get(currentUserAtom).data?.id);

export const currentUserGroupIdAtom = atom<string | undefined>(
  (get) => get(currentUserAtom).data?.groupId ?? undefined,
);

export const currentUserLinksAtom = atom<SocialLink[] | undefined>((get) => get(currentUserAtom).data?.links);

export const currentUserAvatarAtom = atom<string | undefined>((get) => get(currentUserAtom).data?.avatar ?? undefined);

export const currentUserWalletAddressAtom = atom<string | undefined>(
  (get) => get(currentUserAtom).data?.walletAddress ?? undefined,
);

export const currentUserAvatarUrlAtom = atom<string | undefined>((get) =>
  getImageUrl(get(currentUserAtom).data?.avatar),
);
