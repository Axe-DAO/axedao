import { isNil, omitBy } from 'lodash';
import { NextRequest, NextResponse } from 'next/server';
import * as yup from 'yup';

import { searchUsersByAddresses } from '@/db';

const searchByAddressesSchema = yup.object({
  addresses: yup.array().of(yup.string().required()).required(),
});

/**
 * Route handler for user search. Currently only supports search by addresses.
 * @param request - The request object
 * @returns { data: User[] }
 */
export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { addresses } = await searchByAddressesSchema.validate(omitBy({ ...body }, isNil));

    const users = await searchUsersByAddresses(addresses);

    return Response.json({ data: users });
  } catch (error) {
    console.error('Error processing user search:', error);
    return NextResponse.json({ error: 'Invalid request data' }, { status: 400 });
  }
}
