-- JOIN #1: ads + sellers + users
SELECT
  a.ad_id,
  a.header_text,
  a.price,
  s.seller_type,
  u.full_name
FROM service.ads a
JOIN service.sellers s ON s.seller_id = a.seller_id
JOIN service.users u ON u.user_id = s.user_id
ORDER BY a.ad_id;

-- JOIN #2: ads + vehicles + dictionaries
SELECT
  a.ad_id,
  a.header_text,
  v.brand,
  v.model,
  bt.name AS body_type,
  tr.name AS transmission,
  ft.name AS fuel_type
FROM service.ads a
JOIN service.vehicles v ON v.vehicle_id = a.vehicle_id
LEFT JOIN service.body_types bt ON bt.id = v.body_type_id
LEFT JOIN service.transmissions tr ON tr.id = v.transmission_id
LEFT JOIN service.fuel_types ft ON ft.id = v.fuel_type_id
ORDER BY a.ad_id;

-- JOIN #3: users + favourites + ads
SELECT
  u.user_id,
  u.full_name,
  COUNT(f.ad_id) AS favourites_count,
  AVG(a.price) AS avg_favourite_price
FROM service.users u
JOIN service.favourites f ON f.user_id = u.user_id
JOIN service.ads a ON a.ad_id = f.ad_id
GROUP BY u.user_id, u.full_name
ORDER BY favourites_count DESC, u.user_id;

-- JOIN #4: vehicles + mileage_log
SELECT
  v.vehicle_id,
  v.brand,
  v.model,
  MAX(ml.mileage_km) AS max_mileage,
  AVG(ml.mileage_km)::numeric(10, 2) AS avg_mileage,
  COUNT(ml.mileage_id) AS measurements
FROM service.vehicles v
LEFT JOIN service.mileage_log ml ON ml.vehicle_id = v.vehicle_id
GROUP BY v.vehicle_id, v.brand, v.model
ORDER BY v.vehicle_id;

-- JOIN #5: ads + sellers + feedbacks + contracts
SELECT
  a.ad_id,
  a.header_text,
  s.seller_id,
  COALESCE(AVG(fb.rating), 0)::numeric(10, 2) AS avg_seller_rating,
  COUNT(DISTINCT c.contract_id) AS contracts_count
FROM service.ads a
JOIN service.sellers s ON s.seller_id = a.seller_id
LEFT JOIN service.feedbacks fb ON fb.seller_id = s.seller_id
LEFT JOIN service.contracts c ON c.ad_id = a.ad_id
GROUP BY a.ad_id, a.header_text, s.seller_id
ORDER BY a.ad_id;
