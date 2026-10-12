--V61_STATEMENT--
ALTER TABLE invoices ADD COLUMN issued_final INTEGER NOT NULL DEFAULT 0 CHECK(issued_final IN (0,1));

--V61_STATEMENT--
UPDATE invoices SET issued_final=1;

--V61_STATEMENT--
CREATE TABLE IF NOT EXISTS document_snapshots(kind TEXT NOT NULL CHECK(kind IN ('cotizacion','factura','recibo')),record_id TEXT NOT NULL,snapshot_json TEXT NOT NULL CHECK(json_valid(snapshot_json)),PRIMARY KEY(kind,record_id)) STRICT;

--V61_STATEMENT--
INSERT OR IGNORE INTO document_snapshots(kind,record_id,snapshot_json) SELECT 'factura',i.id,json_object('company',COALESCE((SELECT value FROM settings WHERE key='company_name'),'Mi negocio'),'logo',COALESCE((SELECT value FROM settings WHERE key='logo_data'),''),'name',c.name,'phone',c.phone,'address',c.address,'email',c.email) FROM invoices i JOIN clients c ON i.client_id=c.id;

--V61_STATEMENT--
INSERT OR IGNORE INTO document_snapshots(kind,record_id,snapshot_json) SELECT 'cotizacion',q.id,json_object('company',COALESCE((SELECT value FROM settings WHERE key='company_name'),'Mi negocio'),'logo',COALESCE((SELECT value FROM settings WHERE key='logo_data'),''),'name',c.name,'phone',c.phone,'address',c.address,'email',c.email) FROM quotes q JOIN clients c ON q.client_id=c.id;

--V61_STATEMENT--
INSERT OR IGNORE INTO document_snapshots(kind,record_id,snapshot_json) SELECT 'recibo',r.id,json_object('company',COALESCE((SELECT value FROM settings WHERE key='company_name'),'Mi negocio'),'logo',COALESCE((SELECT value FROM settings WHERE key='logo_data'),''),'name',c.name,'phone',c.phone,'address',c.address,'email',c.email) FROM receipts r JOIN payments pay ON pay.id=r.payment_id JOIN invoices i ON i.id=pay.invoice_id JOIN clients c ON c.id=i.client_id;

--V61_STATEMENT--
CREATE TRIGGER IF NOT EXISTS trg_v61_invoice_finalize BEFORE UPDATE OF issued_final ON invoices WHEN OLD.issued_final=0 AND NEW.issued_final=1 BEGIN SELECT CASE WHEN (SELECT COUNT(*) FROM invoice_lines WHERE invoice_id=NEW.id)<1 THEN RAISE(ABORT,'Factura sin renglones') END; SELECT CASE WHEN ((SELECT COALESCE(SUM(line_total_cents),0) FROM invoice_lines WHERE invoice_id=NEW.id)+(SELECT COALESCE(SUM(line_total_cents),0) FROM invoice_charges WHERE invoice_id=NEW.id)+NEW.shipping_cents-NEW.discount_cents)<=0 THEN RAISE(ABORT,'Factura con total inválido') END; END;

--V61_STATEMENT--
CREATE TRIGGER IF NOT EXISTS trg_v61_invoice_update BEFORE UPDATE ON invoices WHEN OLD.issued_final=1 BEGIN SELECT RAISE(ABORT,'Factura emitida inmutable; registre ajuste separado'); END;

--V61_STATEMENT--
CREATE TRIGGER IF NOT EXISTS trg_v61_invoice_delete BEFORE DELETE ON invoices BEGIN SELECT RAISE(ABORT,'Factura no se elimina'); END;

--V61_STATEMENT--
CREATE TRIGGER IF NOT EXISTS trg_v61_invoice_lines_update BEFORE UPDATE ON invoice_lines BEGIN SELECT RAISE(ABORT,'Registro histórico inmutable: invoice_lines'); END;

--V61_STATEMENT--
CREATE TRIGGER IF NOT EXISTS trg_v61_invoice_lines_delete BEFORE DELETE ON invoice_lines BEGIN SELECT RAISE(ABORT,'Registro histórico inmutable: invoice_lines'); END;

--V61_STATEMENT--
CREATE TRIGGER IF NOT EXISTS trg_v61_invoice_charges_update BEFORE UPDATE ON invoice_charges BEGIN SELECT RAISE(ABORT,'Registro histórico inmutable: invoice_charges'); END;

--V61_STATEMENT--
CREATE TRIGGER IF NOT EXISTS trg_v61_invoice_charges_delete BEFORE DELETE ON invoice_charges BEGIN SELECT RAISE(ABORT,'Registro histórico inmutable: invoice_charges'); END;

--V61_STATEMENT--
CREATE TRIGGER IF NOT EXISTS trg_v61_payments_update BEFORE UPDATE ON payments BEGIN SELECT RAISE(ABORT,'Registro histórico inmutable: payments'); END;

--V61_STATEMENT--
CREATE TRIGGER IF NOT EXISTS trg_v61_payments_delete BEFORE DELETE ON payments BEGIN SELECT RAISE(ABORT,'Registro histórico inmutable: payments'); END;

--V61_STATEMENT--
CREATE TRIGGER IF NOT EXISTS trg_v61_receipts_update BEFORE UPDATE ON receipts BEGIN SELECT RAISE(ABORT,'Registro histórico inmutable: receipts'); END;

--V61_STATEMENT--
CREATE TRIGGER IF NOT EXISTS trg_v61_receipts_delete BEFORE DELETE ON receipts BEGIN SELECT RAISE(ABORT,'Registro histórico inmutable: receipts'); END;

--V61_STATEMENT--
CREATE TRIGGER IF NOT EXISTS trg_v61_deliveries_update BEFORE UPDATE ON deliveries BEGIN SELECT RAISE(ABORT,'Registro histórico inmutable: deliveries'); END;

--V61_STATEMENT--
CREATE TRIGGER IF NOT EXISTS trg_v61_deliveries_delete BEFORE DELETE ON deliveries BEGIN SELECT RAISE(ABORT,'Registro histórico inmutable: deliveries'); END;

--V61_STATEMENT--
CREATE TRIGGER IF NOT EXISTS trg_v61_delivery_lines_update BEFORE UPDATE ON delivery_lines BEGIN SELECT RAISE(ABORT,'Registro histórico inmutable: delivery_lines'); END;

--V61_STATEMENT--
CREATE TRIGGER IF NOT EXISTS trg_v61_delivery_lines_delete BEFORE DELETE ON delivery_lines BEGIN SELECT RAISE(ABORT,'Registro histórico inmutable: delivery_lines'); END;

--V61_STATEMENT--
CREATE TRIGGER IF NOT EXISTS trg_v61_stock_movements_update BEFORE UPDATE ON stock_movements BEGIN SELECT RAISE(ABORT,'Registro histórico inmutable: stock_movements'); END;

--V61_STATEMENT--
CREATE TRIGGER IF NOT EXISTS trg_v61_stock_movements_delete BEFORE DELETE ON stock_movements BEGIN SELECT RAISE(ABORT,'Registro histórico inmutable: stock_movements'); END;

--V61_STATEMENT--
CREATE TRIGGER IF NOT EXISTS trg_v61_batch_outputs_update BEFORE UPDATE ON batch_outputs BEGIN SELECT RAISE(ABORT,'Registro histórico inmutable: batch_outputs'); END;

--V61_STATEMENT--
CREATE TRIGGER IF NOT EXISTS trg_v61_batch_outputs_delete BEFORE DELETE ON batch_outputs BEGIN SELECT RAISE(ABORT,'Registro histórico inmutable: batch_outputs'); END;

--V61_STATEMENT--
CREATE TRIGGER IF NOT EXISTS trg_v61_batch_consumptions_update BEFORE UPDATE ON batch_consumptions BEGIN SELECT RAISE(ABORT,'Registro histórico inmutable: batch_consumptions'); END;

--V61_STATEMENT--
CREATE TRIGGER IF NOT EXISTS trg_v61_batch_consumptions_delete BEFORE DELETE ON batch_consumptions BEGIN SELECT RAISE(ABORT,'Registro histórico inmutable: batch_consumptions'); END;

--V61_STATEMENT--
CREATE TRIGGER IF NOT EXISTS trg_v61_recipe_lines_update BEFORE UPDATE ON recipe_lines BEGIN SELECT RAISE(ABORT,'Registro histórico inmutable: recipe_lines'); END;

--V61_STATEMENT--
CREATE TRIGGER IF NOT EXISTS trg_v61_recipe_lines_delete BEFORE DELETE ON recipe_lines BEGIN SELECT RAISE(ABORT,'Registro histórico inmutable: recipe_lines'); END;

--V61_STATEMENT--
CREATE TRIGGER IF NOT EXISTS trg_v61_recipe_versions_update BEFORE UPDATE ON recipe_versions BEGIN SELECT RAISE(ABORT,'Registro histórico inmutable: recipe_versions'); END;

--V61_STATEMENT--
CREATE TRIGGER IF NOT EXISTS trg_v61_recipe_versions_delete BEFORE DELETE ON recipe_versions BEGIN SELECT RAISE(ABORT,'Registro histórico inmutable: recipe_versions'); END;

--V61_STATEMENT--
CREATE TRIGGER IF NOT EXISTS trg_v61_quote_lines_update BEFORE UPDATE ON quote_lines BEGIN SELECT RAISE(ABORT,'Registro histórico inmutable: quote_lines'); END;

--V61_STATEMENT--
CREATE TRIGGER IF NOT EXISTS trg_v61_quote_lines_delete BEFORE DELETE ON quote_lines BEGIN SELECT RAISE(ABORT,'Registro histórico inmutable: quote_lines'); END;

--V61_STATEMENT--
CREATE TRIGGER IF NOT EXISTS trg_v61_quote_charges_update BEFORE UPDATE ON quote_charges BEGIN SELECT RAISE(ABORT,'Registro histórico inmutable: quote_charges'); END;

--V61_STATEMENT--
CREATE TRIGGER IF NOT EXISTS trg_v61_quote_charges_delete BEFORE DELETE ON quote_charges BEGIN SELECT RAISE(ABORT,'Registro histórico inmutable: quote_charges'); END;

--V61_STATEMENT--
CREATE TRIGGER IF NOT EXISTS trg_v61_document_snapshots_update BEFORE UPDATE ON document_snapshots BEGIN SELECT RAISE(ABORT,'Registro histórico inmutable: document_snapshots'); END;

--V61_STATEMENT--
CREATE TRIGGER IF NOT EXISTS trg_v61_document_snapshots_delete BEFORE DELETE ON document_snapshots BEGIN SELECT RAISE(ABORT,'Registro histórico inmutable: document_snapshots'); END;

--V61_STATEMENT--
CREATE TRIGGER IF NOT EXISTS trg_v61_batches_update BEFORE UPDATE ON batches BEGIN SELECT RAISE(ABORT,'Registro histórico inmutable: batches'); END;

--V61_STATEMENT--
CREATE TRIGGER IF NOT EXISTS trg_v61_batches_delete BEFORE DELETE ON batches BEGIN SELECT RAISE(ABORT,'Registro histórico inmutable: batches'); END;

--V61_STATEMENT--
CREATE TRIGGER IF NOT EXISTS trg_v61_quotes_update BEFORE UPDATE ON quotes WHEN NOT(NEW.status='aceptada' AND OLD.status='emitida' AND NEW.id=OLD.id AND NEW.number=OLD.number AND NEW.client_id=OLD.client_id AND NEW.discount_cents=OLD.discount_cents AND NEW.shipping_cents=OLD.shipping_cents AND NEW.notes=OLD.notes) BEGIN SELECT RAISE(ABORT,'Cotización histórica inmutable'); END;

--V61_STATEMENT--
CREATE TRIGGER IF NOT EXISTS trg_v61_quotes_delete BEFORE DELETE ON quotes BEGIN SELECT RAISE(ABORT,'Registro histórico inmutable: quotes'); END;

--V61_STATEMENT--
CREATE TRIGGER IF NOT EXISTS trg_v61_stock_kind BEFORE INSERT ON stock_movements BEGIN SELECT CASE WHEN NEW.kind='produccion' AND (NEW.delta_bottles!=(SELECT bottles FROM batch_outputs WHERE id=NEW.batch_output_id) OR NEW.delivery_line_id IS NOT NULL) THEN RAISE(ABORT,'Producción no cuadra') WHEN NEW.kind='entrega' AND (NEW.delta_bottles!=(SELECT -qty FROM delivery_lines WHERE id=NEW.delivery_line_id) OR NEW.delivery_line_id IS NULL) THEN RAISE(ABORT,'Entrega no cuadra') END; END;

--V61_STATEMENT--
CREATE TRIGGER IF NOT EXISTS trg_v61_consumption_recipe BEFORE INSERT ON batch_consumptions BEGIN SELECT CASE WHEN NOT EXISTS (SELECT 1 FROM recipe_lines rl JOIN batches b ON b.recipe_id=rl.recipe_id WHERE b.id=NEW.batch_id AND rl.ingredient_id=NEW.ingredient_id) THEN RAISE(ABORT,'Ingrediente no pertenece a formula') END; END;

--V61_STATEMENT--
CREATE TRIGGER IF NOT EXISTS trg_v61_batch_fridge BEFORE INSERT ON batches WHEN NEW.status='disponible' AND NEW.refrigerated_at IS NULL AND EXISTS (SELECT 1 FROM recipe_lines rl JOIN ingredients i ON i.id=rl.ingredient_id WHERE rl.recipe_id=NEW.recipe_id AND (lower(i.name) LIKE '%leche%' OR lower(i.name) LIKE '%huevo%' OR lower(i.name) LIKE '%yema%' OR lower(i.name) LIKE '%nata%' OR lower(i.name) LIKE '%crema%' OR lower(i.allergen) LIKE '%lact%' OR lower(i.allergen) LIKE '%huevo%')) BEGIN SELECT RAISE(ABORT,'Producto perecedero requiere refrigeración'); END;

--V61_STATEMENT--
CREATE TRIGGER IF NOT EXISTS trg_v61_payment_final BEFORE INSERT ON payments WHEN (SELECT issued_final FROM invoices WHERE id=NEW.invoice_id)!=1 BEGIN SELECT RAISE(ABORT,'Factura no emitida definitivamente'); END;

--V61_STATEMENT--
CREATE TRIGGER IF NOT EXISTS trg_v61_delivery_final BEFORE INSERT ON deliveries WHEN (SELECT issued_final FROM invoices WHERE id=NEW.invoice_id)!=1 BEGIN SELECT RAISE(ABORT,'Factura no emitida definitivamente'); END;

--V61_STATEMENT--
DROP VIEW IF EXISTS v_invoice_balances;

--V61_STATEMENT--
CREATE VIEW v_invoice_balances AS SELECT i.id,i.number,i.client_id,i.issued_at,i.status,IFNULL((SELECT SUM(line_total_cents) FROM invoice_lines WHERE invoice_id=i.id),0)+IFNULL((SELECT SUM(line_total_cents) FROM invoice_charges WHERE invoice_id=i.id),0)+i.shipping_cents-i.discount_cents AS total_cents, IFNULL((SELECT SUM(amount_cents) FROM payments WHERE invoice_id=i.id),0) paid_cents,IFNULL((SELECT SUM(line_total_cents) FROM invoice_lines WHERE invoice_id=i.id),0)+IFNULL((SELECT SUM(line_total_cents) FROM invoice_charges WHERE invoice_id=i.id),0)+i.shipping_cents-i.discount_cents-IFNULL((SELECT SUM(amount_cents) FROM payments WHERE invoice_id=i.id),0) balance_cents FROM invoices i WHERE i.issued_final=1;

--V61_STATEMENT--
UPDATE settings SET value='6.1-mobile' WHERE key='schema_version';

--V61_STATEMENT--
PRAGMA user_version=61;