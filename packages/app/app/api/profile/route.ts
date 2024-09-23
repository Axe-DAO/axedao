import { NextRequest, NextResponse } from 'next/server';

import { nextAuthOptions } from '@/config/next-auth-options';
import { ProfileForm, profileFormSchema } from '@/config/validation-schema';
import { fetchUserProfile, updateUser } from '@/db';
import { UserProfile } from '@/types/model';
import { getServerSession } from 'next-auth';
import { notFound } from 'next/navigation';

/**
 * Returns the UserProfile of the logged-in user, i.e. the user whose session token is passed in the request.
 * @returns the UserProfile of the logged-in user
 * @throws 401 if the user is not logged in, 404 if the profile is not found
 */
export async function GET() {
  const session = await getServerSession(nextAuthOptions);

  if (!session?.user.id) {
    return NextResponse.json({ error: 'Unauthorized, try to login again' }, { status: 401 });
  }

  const profile = await fetchUserProfile(session.user.id);
  if (!profile) return notFound();

  return Response.json(profile);
}

/**
 * Updates the current user's profile with the data in the request body.
 * @param request - ProfileForm
 * @returns The updated UserProfile
 * @throws 400 if the input data is invalid, 401 if the user is not logged in, 404 if the profile is not found, 500 if an unexpected error occurs.
 */
export async function PATCH(request: NextRequest) {
  const session = await getServerSession(nextAuthOptions);

  if (!session?.user.id) {
    return NextResponse.json({ error: 'Unauthorized, try to login again' }, { status: 401 });
  }

  const body = await request.json();
  let formData: ProfileForm;
  try {
    formData = profileFormSchema.validateSync(body);
  } catch (error) {
    console.error('Unable to validate input data', error);
    return NextResponse.json({ error: `Invalid input data` }, { status: 400 });
  }

  const profile = await fetchUserProfile(session.user.id);
  if (!profile) return notFound();
  try {
    const profileData = formData as Omit<ProfileForm, 'avatar'> & {
      avatar: string | null | undefined;
    };

    const updatedUser = await updateUser({ id: session.user.id, ...profileData });
    // we're re-using the user's group from the profile since it wasn't affected by the update
    const responseData: UserProfile = { user: updatedUser!, group: profile.group };
    return Response.json(responseData);
  } catch (error) {
    console.error('Error updating user profile', error);
    return NextResponse.json({ error: 'Error updating user profile' }, { status: 500 });
  }
}
