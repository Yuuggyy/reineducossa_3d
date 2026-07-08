-- Backfill : recree la ligne admin_profiles pour tout compte auth.users existant
-- qui aurait ete cree AVANT le trigger on_auth_user_created (donc orpheline)
INSERT INTO public.admin_profiles (id, email, nom)
SELECT id, email, COALESCE(raw_user_meta_data->>'nom', 'Admin')
FROM auth.users
ON CONFLICT (id) DO NOTHING;

SELECT 'admin_profiles backfill OK, ' || count(*) || ' compte(s) admin' AS status
FROM public.admin_profiles;
