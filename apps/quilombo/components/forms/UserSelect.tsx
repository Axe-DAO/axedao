import { Autocomplete, AutocompleteItem } from '@nextui-org/autocomplete';
import { FieldProps, useField } from 'formik';
import { SearchIcon } from 'lucide-react';

import useUserSearch from '@/hooks/useUserSearch';
import { User } from '@/types/model';
import { getUserDisplayName } from '@/utils';
import { useSession } from 'next-auth/react';

type keyMode = 'id' | 'walletAddress';

type Props = FieldProps['field'] & {
  disableCurrentUser?: boolean;
  keyMode?: keyMode;
  onSelect?: (user: User | null) => void;
  users?: User[];
  label?: string;
};

/**
 * AutomComplete component for selecting a user and storing either the user's ID or walletAddress
 * in the form.
 * The keyMode prop controls what is stored in the form:
 * - 'id': user ID as key and stored in form
 * - 'walletAddress': user walletAddress as key and stored in form
 * @param props
 * @returns
 */
const UserSelect = ({ disableCurrentUser = true, keyMode = 'id', onSelect, users, label, ...props }: Props) => {
  const [field, , form] = useField(props);
  const { data: session } = useSession();
  const { users: searchUsers, isLoading, setSearchTerm } = useUserSearch();

  const availableUsers = users || searchUsers;

  return (
    <Autocomplete
      {...field}
      items={availableUsers}
      className="mb-3"
      isLoading={isLoading}
      inputProps={{ classNames: { inputWrapper: '!min-h-12' } }}
      listboxProps={{ emptyContent: 'No users found' }}
      label={label || 'Select User'}
      aria-label={label || 'Select User'}
      startContent={<SearchIcon className="h-4 w-4" strokeWidth={1.4} />}
      selectedKey={field.value}
      disabledKeys={disableCurrentUser && session?.user.id ? [session.user.id] : undefined}
      onInputChange={(value) => {
        if (!field.value && !users) setSearchTerm(value);
      }}
      onSelectionChange={(key) => {
        form.setValue(key?.toString() || '');
        if (!users) setSearchTerm(undefined);
        onSelect?.(
          !key
            ? null
            : availableUsers.find((u) => (keyMode === 'walletAddress' ? u.walletAddress === key : u.id === key)) ||
                null,
        );
      }}
      {...props}
    >
      {(user: User) => {
        const displayName = getUserDisplayName(user);
        const key = keyMode === 'walletAddress' ? user.walletAddress : user.id;
        return (
          <AutocompleteItem key={key} aria-label={`User ${displayName}`} textValue={displayName}>
            {displayName}
          </AutocompleteItem>
        );
      }}
    </Autocomplete>
  );
};
export default UserSelect;
