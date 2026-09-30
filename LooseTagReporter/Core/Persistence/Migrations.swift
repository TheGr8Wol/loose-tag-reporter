import Foundation
import GRDB

enum AppDatabase {
    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_core") { db in
            try db.create(table: "store") { t in
                t.column("id", .text).primaryKey()
                t.column("code", .text).notNull().unique()
                t.column("name", .text).notNull()
                t.column("is_multi_floor", .boolean).notNull()
            }

            try db.create(table: "store_floor") { t in
                t.column("id", .text).primaryKey()
                t.column("store_id", .text).notNull().references("store", onDelete: .cascade)
                t.column("code", .text).notNull()
                t.column("label", .text).notNull()
                t.column("sort_order", .integer).notNull().defaults(to: 0)
                t.uniqueKey(["store_id", "code"])
            }

            try db.create(table: "location_node") { t in
                t.column("id", .text).primaryKey()
                t.column("store_id", .text).notNull().references("store", onDelete: .cascade)
                t.column("floor_id", .text).references("store_floor")
                t.column("area_type", .text).notNull()
                t.column("parent_id", .text).references("location_node")
                t.column("code", .text).notNull()
                t.column("label", .text).notNull()
                t.column("kind", .text).notNull()
                t.column("is_other_bucket", .boolean).notNull().defaults(to: false)
                t.column("is_template", .boolean).notNull().defaults(to: false)
                t.column("sort_order", .integer).notNull().defaults(to: 0)
                t.column("active", .boolean).notNull().defaults(to: true)
            }

            try db.create(table: "product_ref") { t in
                t.column("item_code", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("category", .text)
                t.column("active", .boolean).notNull().defaults(to: true)
            }

            try db.create(table: "colour_code") { t in
                t.column("code", .text).primaryKey()
                t.column("name", .text)
                t.column("active", .boolean).notNull().defaults(to: true)
            }

            try db.create(table: "size_code") { t in
                t.column("code", .text).primaryKey()
                t.column("article_field", .text).notNull()
                t.column("label", .text).notNull()
                t.column("active", .boolean).notNull().defaults(to: true)
            }

            try db.create(table: "trading_hours") { t in
                t.column("id", .text).primaryKey()
                t.column("store_id", .text).notNull().references("store", onDelete: .cascade)
                t.column("weekday", .integer).notNull()
                t.column("open_time", .text).notNull()
                t.column("close_time", .text).notNull()
                t.uniqueKey(["store_id", "weekday"])
            }

            try db.create(table: "flag_threshold_rule") { t in
                t.column("id", .text).primaryKey()
                t.column("store_id", .text).notNull().references("store", onDelete: .cascade)
                t.column("scope", .text).notNull()
                t.column("scope_ref_id", .text)
                t.column("trading_phase", .text).notNull()
                t.column("area_type", .text)
                t.column("min_tag_count", .integer).notNull()
            }

            try db.create(table: "report") { t in
                t.column("id", .text).primaryKey()
                t.column("client_uuid", .text).notNull().unique()
                t.column("store_id", .text).notNull()
                t.column("location_id", .text).notNull()
                t.column("location_other_text", .text)
                t.column("found_bucket", .text).notNull()
                t.column("found_at", .datetime).notNull()
                t.column("found_at_is_estimate", .boolean).notNull()
                t.column("found_window_start", .datetime)
                t.column("found_window_end", .datetime)
                t.column("notes", .text)
                t.column("status", .text).notNull()
                t.column("tag_count", .integer).notNull()
                t.column("device_id", .text).notNull()
                t.column("reporter_emp_id", .text).notNull()
                t.column("app_version", .text)
                t.column("created_at", .datetime).notNull()
                t.column("synced_at", .datetime)
                t.column("sync_state", .text).notNull()
            }

            try db.create(table: "tag") { t in
                t.column("id", .text).primaryKey()
                t.column("report_id", .text).notNull().references("report", onDelete: .cascade)
                t.column("tag_barcode", .text)
                t.column("item_code", .text) // nullable
                t.column("size", .text).notNull()
                t.column("colour", .text).notNull()
                t.column("identify_method", .text).notNull()
                t.column("tag_state", .text).notNull()
                t.column("item_name", .text)
                t.column("item_category", .text)
                t.column("style_family_id", .text)
                t.column("sort_order", .integer).notNull().defaults(to: 0)
            }

            try db.create(table: "report_photo") { t in
                t.column("id", .text).primaryKey()
                t.column("report_id", .text).notNull().references("report", onDelete: .cascade)
                t.column("local_path", .text)
                t.column("storage_path", .text)
                t.column("captured_at", .datetime).notNull()
            }

            try db.create(table: "outbox") { t in
                t.column("client_uuid", .text).primaryKey()
                t.column("created_at", .datetime).notNull()
                t.column("attempts", .integer).notNull().defaults(to: 0)
                t.column("last_error", .text)
            }

            try db.create(table: "report_draft") { t in
                t.column("slot", .integer).primaryKey()
                t.column("payload_json", .text).notNull()
                t.column("updated_at", .datetime).notNull()
            }

            try db.create(table: "seed_meta") { t in
                t.column("key", .text).primaryKey()
                t.column("value", .text).notNull()
            }
        }

        return migrator
    }
}
