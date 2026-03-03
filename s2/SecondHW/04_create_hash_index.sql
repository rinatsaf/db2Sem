

CREATE INDEX service.idx_ads_price_hash
  ON service.ads USING hash(price);

ANALYZE service.ads;
