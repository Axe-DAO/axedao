import { Country } from 'country-state-city';
import { and, count, eq, ilike, inArray, ne, notExists, or, SQLWrapper } from 'drizzle-orm';
import { drizzle, PostgresJsDatabase } from 'drizzle-orm/postgres-js';
import postgres from 'postgres';

import ENV from '@/config/environment';
import { GroupSearchParams, SearchParams } from '@/config/validation-schema';
import * as schema from '@/db/schema';
import { Group, UserSession } from '@/types/model';

/**
 * NOTE: All DB functions in this file can only be run server-side. If you need to retrieve DB data from a client
 * component, use the API route handlers provide access to the DB.
 */

// Disable prefetch as it is not supported for "Transaction" pool mode
// The below setup is based on: https://github.com/orgs/supabase/discussions/21789
// due to CONNECT_TIMEOUT issues with Supabase.
export const client = postgres(ENV.databaseUrl, { prepare: false });
export const drizzleClient = drizzle(client, { schema, logger: false });
declare global {
  // eslint-disable-next-line no-var
  var database: PostgresJsDatabase<typeof schema> | undefined;
}
export const db = global.database || drizzleClient;
if (process.env.NODE_ENV !== 'production') global.database = db;

////////////////////////////////////////////////////////////////////

export async function isGlobalAdmin(userId: string) {
  const res = await db.query.users.findFirst({
    where: eq(schema.users.id, userId),
    columns: { isGlobalAdmin: true },
  });
  return res?.isGlobalAdmin;
}

export async function searchUsers(options: SearchParams) {
  const { pageSize = 20, offset = 0, searchTerm } = options;
  const orFilters: (SQLWrapper | undefined)[] = [];

  if (searchTerm) {
    orFilters.push(ilike(schema.users.name, `%${searchTerm}%`));
    orFilters.push(ilike(schema.users.nickname, `%${searchTerm}%`));
  }

  return await db.query.users.findMany({
    limit: pageSize,
    offset,
    where: orFilters.length ? or(...orFilters) : undefined,
  });
}

export async function fetchSessionData(walletAddress: string): Promise<UserSession | undefined> {
  if (!walletAddress) return undefined;
  return await db.query.users.findFirst({
    where: (users, { eq }) => eq(users.walletAddress, walletAddress),
    columns: { id: true, walletAddress: true, isGlobalAdmin: true },
  });
}

export async function fetchUser(userId: string): Promise<schema.SelectUser | undefined> {
  return db.query.users.findFirst({
    where: (users, { eq }) => eq(users.id, userId),
  });
}

export async function countUsers() {
  const result = await db.select({ count: count() }).from(schema.users);
  return result.length ? result[0].count : null;
}

export async function searchGroups(options: GroupSearchParams): Promise<Group[]> {
  const { pageSize = 20, offset = 0, searchTerm, city, country, verified } = options;

  const filters: (SQLWrapper | undefined)[] = [];
  if (searchTerm) filters.push(ilike(schema.groups.name, `%${searchTerm}%`));
  if (city) filters.push(eq(schema.groups.city, city));
  if (country) filters.push(eq(schema.groups.country, country));
  if (typeof verified === 'boolean') filters.push(eq(schema.groups.verified, verified));

  const result = await db.query.groups.findMany({
    limit: pageSize,
    offset,
    where: filters.length ? and(...filters) : undefined,
  });

  return result.map((group) => ({ ...group, countryName: Country.getCountryByCode(group.country)?.name ?? '' }));
}

export async function isGroupMember(groupId: string, userId: string): Promise<boolean> {
  const result = await db
    .select()
    .from(schema.users)
    .fullJoin(schema.groups, eq(schema.groups.id, groupId))
    .where(
      and(
        eq(schema.users.id, userId),
        eq(schema.users.groupId, groupId),
        ne(schema.groups.leader, userId),
        notExists(
          db
            .select()
            .from(schema.groupAdmins)
            .where(and(eq(schema.groupAdmins.userId, userId), eq(schema.groupAdmins.groupId, groupId))),
        ),
      ),
    );
  return !!result.length;
}

export async function isGroupAdmin(groupId: string, userId: string): Promise<boolean> {
  const result = await db
    .select({ value: count() })
    .from(schema.groupAdmins)
    .where(and(eq(schema.groupAdmins.userId, userId), eq(schema.groupAdmins.groupId, groupId)));
  return result.length > 0 && result[0].value > 0;
}

export async function fetchGroup(groupId: string): Promise<Group | undefined> {
  const result = await db.query.groups.findFirst({
    where: (groups, { eq }) => eq(groups.id, groupId),
  });
  return result
    ? {
        ...result,
        countryName: result?.country ? (Country.getCountryByCode(result.country)?.name ?? '') : '',
      }
    : undefined;
}

export async function fetchGroupMembers(groupId: string): Promise<schema.SelectUser[]> {
  return await db
    .select()
    .from(schema.users)
    .where(and(eq(schema.users.groupId, groupId)));
}

export async function fetchGroupAdminIds(groupId: string): Promise<string[]> {
  const result = await db
    .select({ id: schema.groupAdmins.userId })
    .from(schema.groupAdmins)
    .where(eq(schema.groupAdmins.groupId, groupId));
  return result.map((entry) => entry.id);
}

export async function insertUser(userValues: schema.InsertUser) {
  const rows = await db
    .insert(schema.users)
    .values(userValues)
    .returning({ id: schema.users.id, createdAt: schema.users.createdAt, updatedAt: schema.users.updatedAt });
  const user = { ...userValues, ...rows[0] };
  return user;
}

export async function insertGroup(group: schema.InsertGroup) {
  const groups = await db.insert(schema.groups).values(group).returning();
  return groups.length ? groups[0] : undefined;
}

export async function deleteGroup(groupId: string) {
  await db.delete(schema.groups).where(eq(schema.groups.id, groupId));
}

export async function removeGroupMember(memberId: string) {
  await db.update(schema.users).set({ groupId: null }).where(eq(schema.users.id, memberId));
}

export async function updateUser(user: Omit<schema.InsertUser, 'walletAddress' | 'updatedAt'>) {
  const users = await db.update(schema.users).set(user).where(eq(schema.users.id, user.id)).returning();
  return users.length ? users[0] : undefined;
}

export async function updateGroup(group: Partial<schema.InsertGroup> & { id: string }) {
  const groups = await db.update(schema.groups).set(group).where(eq(schema.groups.id, group.id)).returning();
  return groups.length ? groups[0] : undefined;
}

export async function addGroupAdmin(entry: schema.InsertGroupAdmin) {
  await db.insert(schema.groupAdmins).values(entry).onConflictDoNothing(); // Ignore if already exists
}

export async function removeGroupAdmin(groupId: string, adminId: string) {
  await db
    .delete(schema.groupAdmins)
    .where(and(eq(schema.groupAdmins.groupId, groupId), eq(schema.groupAdmins.userId, adminId)));
}

export async function searchUsersByAddresses(addresses: string[]) {
  return await db.query.users.findMany({
    where: (users) => inArray(users.walletAddress, addresses),
    orderBy: (users, { asc }) => [asc(users.id)],
  });
}
