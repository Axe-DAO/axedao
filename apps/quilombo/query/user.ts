import { infiniteQueryOptions, queryOptions, useInfiniteQuery, useQuery } from '@tanstack/react-query';
import axios from 'axios';

import { QueryConfig } from '@/config/constants';
import { SearchParams } from '@/config/validation-schema';
import { User, UserSearchResult } from '@/types/model';
import { QUERY_KEYS, SearchByAddressParams } from '.';

const fetchUser = async (id: string): Promise<User> => axios.get(`/api/users/${id}`).then((response) => response.data);
export const fetchUserOptions = (id: string | undefined) => {
  return {
    queryKey: [QUERY_KEYS.user.getUser, id],
    queryFn: async () => fetchUser(id ?? ''),
    staleTime: QueryConfig.staleTimeUser,
    enabled: !!id,
  } as const;
};

export const searchUsers = async ({ offset, pageSize, searchTerm }: SearchParams): Promise<UserSearchResult> => {
  let queryParams = `?offset=${offset}`;
  queryParams += searchTerm ? `&searchTerm=${searchTerm}` : '';
  queryParams += pageSize ? `&limit=${pageSize}` : '';
  return axios.get(`/api/users${queryParams}`).then((response) => response.data);
};
export const searchUsersOptions = ({ offset, pageSize, searchTerm }: SearchParams) => {
  return {
    queryKey: [QUERY_KEYS.user.searchUsers, searchTerm],
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    queryFn: async ({ pageParam }: { pageParam: any }) =>
      searchUsers({ offset: Number(pageParam), pageSize, searchTerm }),
    initialPageParam: offset || 0,
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    getNextPageParam: (lastPage: any) => lastPage.nextOffset,
    staleTime: QueryConfig.staleTimeDefault,
  } as const;
};

export const useFetchUser = (id: string) => {
  return useQuery(queryOptions(fetchUserOptions(id)));
};

export const useSearchUsers = (params: SearchParams) => {
  return useInfiniteQuery(infiniteQueryOptions(searchUsersOptions(params)));
};

export const searchUsersByAddresses = async ({ addresses }: SearchByAddressParams): Promise<User[]> => {
  return axios.post('/api/users/search', { addresses }).then((response) => response.data.data);
};

export const searchUsersByAddressesOptions = ({ addresses }: SearchByAddressParams) => {
  return {
    queryKey: [QUERY_KEYS.user.searchByAddresses, addresses],
    queryFn: () => searchUsersByAddresses({ addresses }),
    staleTime: QueryConfig.staleTimeDefault,
    enabled: !!addresses,
  } as const;
};

export const useSearchUsersByAddresses = (params: SearchByAddressParams) => {
  return useQuery(queryOptions(searchUsersByAddressesOptions(params)));
};
