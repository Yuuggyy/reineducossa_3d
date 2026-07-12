-- ── SEED PRODUITS : La Reine du Cossa ──────────────────────────────
INSERT INTO public.restaurants (nom, slug)
VALUES ('La Reine du Cossa', 'reineducossa')
ON CONFLICT (slug) DO NOTHING;

DO $$
DECLARE rid UUID;
BEGIN
  SELECT id INTO rid FROM public.restaurants WHERE slug = 'reineducossa';
  INSERT INTO public.produits (restaurant_id, nom, description, prix, categorie, disponible) VALUES
    (rid, 'Cassolette Cossas Teriyaki', 'Cossas poeles, sauce teriyaki maison, riz', 30.00, 'Cossas Signature', true),
    (rid, 'Cassolette Cossas Legumes', 'Cossas et legumes de saison sautes', 35.00, 'Cossas Signature', true),
    (rid, 'Tempura de Cossas Tartare', 'Cossas en tempura dores, sauce tartare maison', 28.00, 'Cossas Signature', true),
    (rid, 'Cossas Grilles Nature', 'Cossas entiers grilles, citron et piment', 25.00, 'Cossas Signature', true),
    (rid, 'Brochettes de Cossas marines', 'Marines au gingembre, citronnelle, grilles', 22.00, 'Cossas Signature', true),
    (rid, 'Cossas ail et piment', 'Sautes a l ail, piment oiseau, beurre', 20.00, 'Cossas Signature', true),
    (rid, 'Tilapia Braise sauce piment', 'Tilapia entier braise, piment et tomates fraiches', 15.00, 'Poissons', true),
    (rid, 'Capitaine Grille', 'Grand poisson du fleuve, citron, herbes', 22.00, 'Poissons', true),
    (rid, 'Liboke de Poisson', 'Poisson cuit en feuilles de bananier, epices', 18.00, 'Poissons', true),
    (rid, 'Filet de Poisson Sauce Vierge', 'Filet grille, tomates fraiches, capres, citron', 20.00, 'Poissons', true),
    (rid, 'Carpaccio de Capitaine', 'Fine tranche marinee, huile d olive, citron', 20.00, 'Entrees', true),
    (rid, 'Cocktail de Crevettes', 'Crevettes froides, sauce cocktail maison', 22.00, 'Entrees', true),
    (rid, 'Salade Nicoise', 'Thon, oeufs, olives, tomates, anchois', 22.00, 'Entrees', true),
    (rid, 'Riz Blanc', NULL, 3.00, 'Accompagnements', true),
    (rid, 'Plantain Frit', NULL, 3.00, 'Accompagnements', true),
    (rid, 'Pondu (saka-saka)', 'Feuilles de manioc mijotees', 4.00, 'Accompagnements', true),
    (rid, 'Frites Maison', NULL, 4.00, 'Accompagnements', true),
    (rid, 'Kwanga (pain de manioc)', NULL, 2.00, 'Accompagnements', true),
    (rid, 'Salade de Fruits Frais', NULL, 10.00, 'Desserts', true),
    (rid, 'Creme Brulee Coco', 'Creme brulee a la noix de coco', 10.00, 'Desserts', true),
    (rid, 'Eau Minerale 75cl', NULL, 2.00, 'Boissons', true),
    (rid, 'Biere Primus 65cl', NULL, 4.00, 'Boissons', true),
    (rid, 'Vin Blanc (verre)', 'Vin blanc sec, ideal avec les fruits de mer', 8.00, 'Boissons', true),
    (rid, 'Jus de Fruit Frais', 'Mangue, passion, ananas', 5.00, 'Boissons', true)
  ON CONFLICT DO NOTHING;
END $$;
