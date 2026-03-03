CREATE INDEX service.idx_ads_price_btree
  ON service.ads USING btree(price);

CREATE INDEX service.idx_ads_status_price_btree
  ON service.ads USING btree(status_id, price);

CREATE INDEX service.idx_ads_header_prefix_btree
  ON service.ads USING btree(header_text text_pattern_ops);

ANALYZE service.ads;
