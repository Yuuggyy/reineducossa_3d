-- ============================================================
-- O POETA — SETUP COMPLET (UN SEUL SCRIPT, UNE SEULE FOIS)
-- Copier-coller en entier dans Supabase > SQL Editor
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- ÉTAPE 1 : PURGE TOTALE
-- ────────────────────────────────────────────────────────────
SET session_replication_role = replica;

DO $$ DECLARE r RECORD;
BEGIN
  FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public')
  LOOP
    EXECUTE 'DROP TABLE IF EXISTS public.' || quote_ident(r.tablename) || ' CASCADE';
  END LOOP;
END $$;

DO $$ DECLARE r RECORD;
BEGIN
  FOR r IN (
    SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
  )
  LOOP
    EXECUTE 'DROP FUNCTION IF EXISTS public.' || quote_ident(r.proname) || '(' || r.args || ') CASCADE';
  END LOOP;
END $$;

SET session_replication_role = DEFAULT;

-- ────────────────────────────────────────────────────────────
-- ÉTAPE 2 : EXTENSIONS
-- ────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ────────────────────────────────────────────────────────────
-- ÉTAPE 3 : TABLES
-- ────────────────────────────────────────────────────────────

CREATE TABLE public.categories (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nom         TEXT NOT NULL,
  description TEXT,
  emoji       TEXT DEFAULT '🍽️',
  ordre       INTEGER DEFAULT 0,
  actif       BOOLEAN DEFAULT true,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.produits (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  categorie_id UUID REFERENCES public.categories(id) ON DELETE SET NULL,
  nom          TEXT NOT NULL,
  description  TEXT,
  prix         NUMERIC(10,2) NOT NULL DEFAULT 0,
  image_url    TEXT,
  disponible   BOOLEAN DEFAULT true,
  ordre        INTEGER DEFAULT 0,
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.commandes (
  id                 UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  numero_table       TEXT NOT NULL,
  statut             TEXT NOT NULL DEFAULT 'recue'
                       CHECK (statut IN ('recue', 'en_cours', 'terminee', 'annulee')),
  demandes_speciales TEXT,
  montant_total      NUMERIC(10,2) DEFAULT 0,
  created_at         TIMESTAMPTZ DEFAULT NOW(),
  updated_at         TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.commande_items (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  commande_id UUID NOT NULL REFERENCES public.commandes(id) ON DELETE CASCADE,
  produit_id  UUID REFERENCES public.produits(id) ON DELETE SET NULL,
  nom_produit TEXT NOT NULL,
  prix_unit   NUMERIC(10,2) NOT NULL,
  quantite    INTEGER NOT NULL DEFAULT 1,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.appels_serveur (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  numero_table TEXT NOT NULL,
  message      TEXT DEFAULT 'Un client demande le serveur',
  traite       BOOLEAN DEFAULT false,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.admin_profiles (
  id         UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email      TEXT NOT NULL,
  nom        TEXT,
  role       TEXT DEFAULT 'admin',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.parametres (
  id             INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  nom_restaurant TEXT DEFAULT 'La Reine du Cossa',
  logo_url       TEXT,
  adresse        TEXT DEFAULT '3, Avenue Milambo, Gombe, Kinshasa',
  telephone      TEXT DEFAULT '+243 856 646 098',
  whatsapp       TEXT DEFAULT '243856646098',
  horaires       TEXT DEFAULT 'Tous les jours 11h00 - 23h00',
  updated_at     TIMESTAMPTZ DEFAULT NOW()
);

-- ────────────────────────────────────────────────────────────
-- ÉTAPE 4 : FONCTIONS ET TRIGGERS
-- ────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_produits_updated_at
  BEFORE UPDATE ON public.produits
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_commandes_updated_at
  BEFORE UPDATE ON public.commandes
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_parametres_updated_at
  BEFORE UPDATE ON public.parametres
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Trigger : crée automatiquement un profil admin quand un user s'inscrit
CREATE OR REPLACE FUNCTION public.handle_new_admin()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.admin_profiles (id, email, nom)
  VALUES (NEW.id, NEW.email, COALESCE(NEW.raw_user_meta_data->>'nom', 'Admin'))
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_admin();

-- ────────────────────────────────────────────────────────────
-- ÉTAPE 5 : RLS (UN SEUL BLOC, SANS AMBIGUÏTÉ)
-- ────────────────────────────────────────────────────────────

ALTER TABLE public.categories      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.produits        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.commandes       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.commande_items  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.appels_serveur  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_profiles  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.parametres      ENABLE ROW LEVEL SECURITY;

-- CATÉGORIES : lecture publique, écriture admin
CREATE POLICY "cat_select"  ON public.categories FOR SELECT USING (true);
CREATE POLICY "cat_insert"  ON public.categories FOR INSERT WITH CHECK (auth.uid() IN (SELECT id FROM public.admin_profiles));
CREATE POLICY "cat_update"  ON public.categories FOR UPDATE USING (auth.uid() IN (SELECT id FROM public.admin_profiles));
CREATE POLICY "cat_delete"  ON public.categories FOR DELETE USING (auth.uid() IN (SELECT id FROM public.admin_profiles));

-- PRODUITS : lecture publique, écriture admin
CREATE POLICY "prod_select" ON public.produits FOR SELECT USING (true);
CREATE POLICY "prod_insert" ON public.produits FOR INSERT WITH CHECK (auth.uid() IN (SELECT id FROM public.admin_profiles));
CREATE POLICY "prod_update" ON public.produits FOR UPDATE USING (auth.uid() IN (SELECT id FROM public.admin_profiles));
CREATE POLICY "prod_delete" ON public.produits FOR DELETE USING (auth.uid() IN (SELECT id FROM public.admin_profiles));

-- COMMANDES : insertion SANS connexion, gestion admin
CREATE POLICY "cmd_insert"  ON public.commandes FOR INSERT WITH CHECK (true);
CREATE POLICY "cmd_select"  ON public.commandes FOR SELECT USING (auth.uid() IN (SELECT id FROM public.admin_profiles));
CREATE POLICY "cmd_update"  ON public.commandes FOR UPDATE USING (auth.uid() IN (SELECT id FROM public.admin_profiles));
CREATE POLICY "cmd_delete"  ON public.commandes FOR DELETE USING (auth.uid() IN (SELECT id FROM public.admin_profiles));

-- COMMANDE ITEMS : insertion SANS connexion, lecture admin
CREATE POLICY "item_insert" ON public.commande_items FOR INSERT WITH CHECK (true);
CREATE POLICY "item_select" ON public.commande_items FOR SELECT USING (auth.uid() IN (SELECT id FROM public.admin_profiles));

-- APPELS SERVEUR : insertion SANS connexion, gestion admin
CREATE POLICY "appel_insert" ON public.appels_serveur FOR INSERT WITH CHECK (true);
CREATE POLICY "appel_select" ON public.appels_serveur FOR SELECT USING (auth.uid() IN (SELECT id FROM public.admin_profiles));
CREATE POLICY "appel_update" ON public.appels_serveur FOR UPDATE USING (auth.uid() IN (SELECT id FROM public.admin_profiles));

-- PARAMÈTRES : lecture publique, écriture admin
CREATE POLICY "param_select" ON public.parametres FOR SELECT USING (true);
CREATE POLICY "param_update" ON public.parametres FOR UPDATE USING (auth.uid() IN (SELECT id FROM public.admin_profiles));

-- ADMIN PROFILES : accès propre uniquement
CREATE POLICY "ap_select" ON public.admin_profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "ap_update" ON public.admin_profiles FOR UPDATE USING (auth.uid() = id);

-- ────────────────────────────────────────────────────────────
-- ÉTAPE 6 : STORAGE BUCKET
-- ────────────────────────────────────────────────────────────

INSERT INTO storage.buckets (id, name, public)
VALUES ('menu-images', 'menu-images', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "img_select" ON storage.objects;
DROP POLICY IF EXISTS "img_insert" ON storage.objects;
DROP POLICY IF EXISTS "img_update" ON storage.objects;
DROP POLICY IF EXISTS "img_delete" ON storage.objects;
DROP POLICY IF EXISTS "lecture_publique_images" ON storage.objects;
DROP POLICY IF EXISTS "upload_admin_images" ON storage.objects;
DROP POLICY IF EXISTS "update_admin_images" ON storage.objects;
DROP POLICY IF EXISTS "delete_admin_images" ON storage.objects;
DROP POLICY IF EXISTS "menu_images_select_all" ON storage.objects;
DROP POLICY IF EXISTS "menu_images_insert_admin" ON storage.objects;
DROP POLICY IF EXISTS "menu_images_update_admin" ON storage.objects;
DROP POLICY IF EXISTS "menu_images_delete_admin" ON storage.objects;

CREATE POLICY "img_select" ON storage.objects FOR SELECT USING (bucket_id = 'menu-images');
CREATE POLICY "img_insert" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'menu-images' AND auth.uid() IN (SELECT id FROM public.admin_profiles));
CREATE POLICY "img_update" ON storage.objects FOR UPDATE USING (bucket_id = 'menu-images' AND auth.uid() IN (SELECT id FROM public.admin_profiles));
CREATE POLICY "img_delete" ON storage.objects FOR DELETE USING (bucket_id = 'menu-images' AND auth.uid() IN (SELECT id FROM public.admin_profiles));

-- ────────────────────────────────────────────────────────────
-- ÉTAPE 7 : DONNÉES PAR DÉFAUT
-- ────────────────────────────────────────────────────────────

INSERT INTO public.parametres (id, nom_restaurant, adresse, telephone, whatsapp, horaires)
VALUES (1, 'La Reine du Cossa', '3, Avenue Milambo, Gombe, Kinshasa', '+243 856 646 098', '243856646098', 'Tous les jours 11h00 - 23h00')
ON CONFLICT (id) DO NOTHING;

-- ────────────────────────────────────────────────────────────
-- ÉTAPE 8 : BACKFILL ADMIN (pour compte existant avant le trigger)
-- ────────────────────────────────────────────────────────────

INSERT INTO public.admin_profiles (id, email, nom)
SELECT id, email, COALESCE(raw_user_meta_data->>'nom', 'Admin')
FROM auth.users
ON CONFLICT (id) DO NOTHING;

-- ────────────────────────────────────────────────────────────
-- ÉTAPE 9 : MENU LA REINE DU COSSA (crevettes geantes, fruits de mer)
INSERT INTO public.categories (nom, description, emoji, ordre, actif) VALUES
('Cossas Signature',   'Nos cossas cuisines avec passion',  '🦐', 1, true),
('Poissons',           'Poissons du fleuve et de mer',       '🐟', 2, true),
('Entrees',            'Entrees froides et chaudes',         '🥗', 3, true),
('Accompagnements',    'Riz, plantain, pondu, legumes',      '🍚', 4, true),
('Desserts',           'Douceurs de saison',                 '🍰', 5, true),
('Boissons',           'Boissons fraiches et vins',          '🥤', 6, true)
ON CONFLICT DO NOTHING;

INSERT INTO public.produits (nom, description, prix, categorie_id, disponible, ordre) VALUES
('Cassolette Cossas Teriyaki','Cossas poeles, sauce teriyaki maison, riz',30.00,(SELECT id FROM categories WHERE nom='Cossas Signature'),true,1),
('Cassolette Cossas Legumes','Cossas et legumes de saison sautes',35.00,(SELECT id FROM categories WHERE nom='Cossas Signature'),true,2),
('Tempura de Cossas Tartare','Cossas en tempura dores, sauce tartare maison',28.00,(SELECT id FROM categories WHERE nom='Cossas Signature'),true,3),
('Cossas Grilles Nature','Cossas entiers grilles, citron et piment',25.00,(SELECT id FROM categories WHERE nom='Cossas Signature'),true,4),
('Brochettes de Cossas marines','Marines au gingembre, citronnelle, grilles',22.00,(SELECT id FROM categories WHERE nom='Cossas Signature'),true,5),
('Cossas ail et piment','Sautes a l ail, piment oiseau, beurre',20.00,(SELECT id FROM categories WHERE nom='Cossas Signature'),true,6),
('Tilapia Braise sauce piment','Tilapia entier braise, piment et tomates fraiches',15.00,(SELECT id FROM categories WHERE nom='Poissons'),true,1),
('Capitaine Grille','Grand poisson du fleuve, citron, herbes',22.00,(SELECT id FROM categories WHERE nom='Poissons'),true,2),
('Liboke de Poisson','Poisson cuit en feuilles de bananier, epices',18.00,(SELECT id FROM categories WHERE nom='Poissons'),true,3),
('Filet de Poisson Sauce Vierge','Filet grille, tomates fraiches, capres, citron',20.00,(SELECT id FROM categories WHERE nom='Poissons'),true,4),
('Carpaccio de Capitaine','Fine tranche marinee, huile d olive, citron',20.00,(SELECT id FROM categories WHERE nom='Entrees'),true,1),
('Cocktail de Crevettes','Crevettes froides, sauce cocktail maison',22.00,(SELECT id FROM categories WHERE nom='Entrees'),true,2),
('Salade Nicoise','Thon, oeufs, olives, tomates, anchois',22.00,(SELECT id FROM categories WHERE nom='Entrees'),true,3),
('Riz Blanc',NULL,3.00,(SELECT id FROM categories WHERE nom='Accompagnements'),true,1),
('Plantain Frit',NULL,3.00,(SELECT id FROM categories WHERE nom='Accompagnements'),true,2),
('Pondu (saka-saka)','Feuilles de manioc mijotees',4.00,(SELECT id FROM categories WHERE nom='Accompagnements'),true,3),
('Frites Maison',NULL,4.00,(SELECT id FROM categories WHERE nom='Accompagnements'),true,4),
('Kwanga (pain de manioc)',NULL,2.00,(SELECT id FROM categories WHERE nom='Accompagnements'),true,5),
('Salade de Fruits Frais',NULL,10.00,(SELECT id FROM categories WHERE nom='Desserts'),true,1),
('Creme Brulee Coco','Creme brulee a la noix de coco',10.00,(SELECT id FROM categories WHERE nom='Desserts'),true,2),
('Eau Minerale 75cl',NULL,2.00,(SELECT id FROM categories WHERE nom='Boissons'),true,1),
('Biere Primus 65cl',NULL,4.00,(SELECT id FROM categories WHERE nom='Boissons'),true,2),
('Vin Blanc (verre)','Vin blanc sec, ideal avec les fruits de mer',8.00,(SELECT id FROM categories WHERE nom='Boissons'),true,3),
('Jus de Fruit Frais','Mangue, passion, ananas',5.00,(SELECT id FROM categories WHERE nom='Boissons'),true,4)
ON CONFLICT DO NOTHING;


-- ────────────────────────────────────────────────────────────
-- VÉRIFICATION FINALE
-- ────────────────────────────────────────────────────────────
SELECT
  (SELECT count(*) FROM public.categories) AS nb_categories,
  (SELECT count(*) FROM public.produits)   AS nb_produits,
  (SELECT count(*) FROM public.admin_profiles) AS nb_admins,
  'Setup terminé OK' AS status;
