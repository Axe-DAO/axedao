import { isNil, omitBy } from 'lodash';
import { getServerSession } from 'next-auth';
import { NextRequest, NextResponse } from 'next/server';
import { InferType } from 'yup';

import { nextAuthOptions } from '@/config/next-auth-options';
import { updateGroupSchema } from '@/config/validation-schema';
import { deleteGroup, fetchGroup, fetchGroupAdminIds, isGroupAdmin, updateGroup } from '@/db';
import { generateErrorMessage } from '@/utils';

/**
 * Returns a Group object for a given group ID.
 * @param req
 * @returns a Group
 */
export async function GET(req: NextRequest, { params }: { params: { groupId: string } }) {
  try {
    const { groupId } = params;
    const group = await fetchGroup(groupId);
    if (!group) return NextResponse.json({ error: `Group ID '${groupId}' does not exist` }, { status: 404 });

    return Response.json(group);
  } catch (error) {
    console.error(error);
    return Response.json(
      { error: true, message: generateErrorMessage(error, 'An unexpected error occurred while fetching group') },
      {
        status: 500,
      },
    );
  }
}

/**
 * Updates a group
 * @param req Partial<Group>
 * @param groupId
 * @returns
 */
export async function PATCH(req: NextRequest, { params }: { params: { groupId: string } }) {
  const session = await getServerSession(nextAuthOptions);

  if (!session?.user.id) {
    return NextResponse.json({ error: 'Unauthorized, try to login again' }, { status: 401 });
  }

  const { groupId } = params;
  const isAdmin = await isGroupAdmin(groupId, session.user.id);

  if (!isAdmin)
    return Response.json(
      { error: true, message: 'Unauthorized! Only group admins can update a group' },
      {
        status: 401,
      },
    );

  const body = await req.json();
  const isValid = await updateGroupSchema.validate(body);
  if (!isValid) {
    return Response.json(
      { error: true, message: 'Invalid profile data' },
      {
        status: 400,
      },
    );
  }

  const groupData = body as InferType<typeof updateGroupSchema>;

  const groupDataClean = omitBy(groupData, isNil);

  const oldGroup = await fetchGroup(groupId);
  if (!oldGroup)
    return NextResponse.json(
      { error: 'Unable to locate the group to update. Please confirm that the group still exists.' },
      { status: 404 },
    );

  const updatedGroup = await updateGroup({ ...groupDataClean, id: oldGroup.id });
  return Response.json(updatedGroup);
}

/**
 * Deletes the group with the specified ID.
 * @param request
 * @param param1
 * @returns
 */
export async function DELETE(request: NextRequest, { params }: { params: { groupId: string } }) {
  const session = await getServerSession(nextAuthOptions);

  if (!session?.user.id) {
    return NextResponse.json({ error: 'Unauthorized, try to login again' }, { status: 401 });
  }

  try {
    const { groupId } = params;
    const group = await fetchGroup(groupId);
    if (!group) return NextResponse.json({ error: `Group ID ${groupId} does not exist` }, { status: 404 });

    const adminIds = await fetchGroupAdminIds(groupId);

    if (!adminIds.some((id) => id === session.user.id)) {
      return Response.json(
        { error: true, message: 'Unauthorized to delete the group. Missing admin privileges.' },
        {
          status: 403,
        },
      );
    }

    await deleteGroup(groupId);

    return Response.json({ success: true });
  } catch (error) {
    console.error(error);
    return Response.json(
      { error: true, message: generateErrorMessage(error, 'An unexpected error occurred while deleting group') },
      {
        status: 500,
      },
    );
  }
}
