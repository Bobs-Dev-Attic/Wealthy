-- Prevent direct RPC invocation of the trigger-only SECURITY DEFINER function.
-- The on_auth_user_created trigger still fires (triggers do not require EXECUTE).
revoke execute on function public.handle_new_user() from anon, authenticated, public;
