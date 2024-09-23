import { useAtom, useAtomValue } from 'jotai';
import { enqueueSnackbar } from 'notistack';
import { useEffect } from 'react';

import { CreateNewGroupForm, UpdateGroupForm } from '@/config/validation-schema';
import { GroupAndUserParams } from '@/query';
import {
  useAddAdminMutation,
  useCreateGroupMutation,
  useDeleteGroupMutation,
  useFetchGroupMembers,
  useFetchGroupProfile,
  useRemoveAdminMutation,
  useRemoveMemberMutation,
  useUpdateGroupMutation,
} from '@/query/group';
import { FileUploadParams, useUploadImageMutation } from '@/query/image';
import { currentUserProfileAtom } from './state/currentUser';
import { groupIdAtom, groupMembersAtom, groupProfileAtom } from './state/group';

export const useInitGroup = (groupId: string) => {
  const [groupProfile, setGroupProfile] = useAtom(groupProfileAtom);
  const { data, error, isPending } = useFetchGroupProfile(groupId);
  useEffect(() => {
    if (data) setGroupProfile(data);
  }, [data, setGroupProfile]);

  return { groupProfile, error, isPending };
};

export const useGroupMembers = () => {
  const groupId = useAtomValue(groupIdAtom);
  const [groupMembers, setGroupMembers] = useAtom(groupMembersAtom);
  const { data: members, error, isPending } = useFetchGroupMembers(groupId ?? '');
  useEffect(() => {
    if (members) setGroupMembers(members);
  }, [members, setGroupMembers]);

  return { groupMembers, error, isPending };
};

export const useCreateGroup = () => {
  const [currentUserProfile, setCurrentUserProfile] = useAtom(currentUserProfileAtom);
  const { mutateAsync, error, isPending } = useCreateGroupMutation();
  const createGroup = async (data: CreateNewGroupForm) =>
    mutateAsync(data, {
      onError: (error) => enqueueSnackbar(`An error occured trying to create the group: ${error.message}`),
    }).then((newGroup) => {
      if (currentUserProfile) {
        currentUserProfile.user.groupId = newGroup.id;
        currentUserProfile.group = newGroup;
        setCurrentUserProfile(currentUserProfile);
      }
    });
  return { createGroup, error, isPending };
};

export const useDeleteGroup = () => {
  const [currentUserProfile, setCurrentUserProfile] = useAtom(currentUserProfileAtom);
  const { mutateAsync, error, isPending } = useDeleteGroupMutation();
  const deleteGroup = async (groupId: string) =>
    mutateAsync(groupId, {
      onError: (error) => enqueueSnackbar(`An error occured trying to delete the group: ${error.message}`),
    }).then(() => {
      if (currentUserProfile) {
        currentUserProfile.user.groupId = null;
        currentUserProfile.group = null;
        setCurrentUserProfile(currentUserProfile);
      }
    });
  return { deleteGroup, error, isPending };
};

export const useUpdateGroup = () => {
  const [currentUserProfile, setCurrentUserProfile] = useAtom(currentUserProfileAtom);
  const { mutateAsync, error, isPending } = useUpdateGroupMutation();
  const { mutateAsync: mutateImage } = useUploadImageMutation();
  const updateGroup = async (params: { groupId: string; data: UpdateGroupForm }) => {
    if (params.data.logo && params.data.logo instanceof File) {
      const uploadParams: FileUploadParams = {
        file: params.data.logo,
        name: params.groupId ? `group-logo-${params.groupId}` : undefined,
      };
      const hash = await mutateImage(uploadParams);
      if (hash) params.data.logo = hash;
      else {
        console.warn('Logo upload successful, but no hash returned.');
        delete params.data.logo;
      }
    }

    if (params.data.banner && params.data.banner instanceof File) {
      const uploadParams: FileUploadParams = {
        file: params.data.banner,
        name: params.groupId ? `group-logo-${params.groupId}` : undefined,
      };
      const hash = await mutateImage(uploadParams);
      if (hash) params.data.banner = hash;
      else {
        console.warn('Logo upload successful, but no hash returned.');
        delete params.data.banner;
      }
    }

    return mutateAsync(params, {
      onError: (error) => enqueueSnackbar(`An error occured trying to update the group: ${error.message}`),
    }).then((groupUpdate) => {
      if (currentUserProfile) {
        // TODO The data model currently enforces that an admin user is also a member of the group
        // and we therefore update the current user. This might change in the future.
        currentUserProfile.group = groupUpdate;
        setCurrentUserProfile(currentUserProfile);
      }
    });
  };
  return { updateGroup, error, isPending };
};

export const useAddAdmin = () => {
  const [groupProfile, setGroupProfile] = useAtom(groupProfileAtom);
  const { mutateAsync, error, isPending } = useAddAdminMutation();
  const addAdmin = async (params: GroupAndUserParams) =>
    mutateAsync(params, {
      onError: (error) => enqueueSnackbar(`An error occured trying to add the admin to the group: ${error.message}`),
    }).then((newAdminList) => {
      if (groupProfile) {
        groupProfile.adminIds = newAdminList;
        setGroupProfile(groupProfile);
      }
    });
  return { addAdmin, error, isPending };
};

export const useRemoveAdmin = () => {
  const [groupProfile, setGroupProfile] = useAtom(groupProfileAtom);
  const { mutateAsync, error, isPending } = useRemoveAdminMutation();
  const removeAdmin = async (params: GroupAndUserParams) =>
    mutateAsync(params, {
      onError: (error) =>
        enqueueSnackbar(`An error occured trying to remove the admin from the group: ${error.message}`),
    }).then((newAdminList) => {
      if (groupProfile) {
        groupProfile.adminIds = newAdminList;
        setGroupProfile(groupProfile);
      }
    });
  return { removeAdmin, error, isPending };
};

export const useRemoveMember = () => {
  const [, setGroupMembers] = useAtom(groupMembersAtom);
  const { mutateAsync, error, isPending } = useRemoveMemberMutation();
  const removeMember = async (params: GroupAndUserParams) =>
    mutateAsync(params, {
      onError: (error) => enqueueSnackbar(`An error occured trying to remove the group member: ${error.message}`),
    }).then((updatedMembers) => setGroupMembers(updatedMembers));
  return { removeMember, error, isPending };
};
