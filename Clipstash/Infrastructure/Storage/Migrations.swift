import GRDB

enum Migrations {
    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_initial_schema") { db in
            try db.create(table: "clipboard_items") { t in
                t.column("id", .text).primaryKey()
                t.column("content_blob", .blob).notNull()
                t.column("thumbnail_blob", .blob)
                t.column("content_kind", .text).notNull()
                t.column("content_hash", .text).notNull()
                t.column("text_preview", .text)
                t.column("source_bundle_id", .text)
                t.column("source_app_name", .text)
                t.column("size_bytes", .integer).notNull()
                t.column("created_at", .integer).notNull()
                t.column("is_pinned", .integer).notNull().defaults(to: 0)
                t.column("pinned_slot", .integer)
                t.column("pinned_template", .text)
            }
            try db.create(
                index: "idx_items_created_at",
                on: "clipboard_items",
                columns: ["created_at"]
            )
            try db.create(
                index: "idx_items_hash",
                on: "clipboard_items",
                columns: ["content_hash"]
            )
            try db.execute(sql: """
                CREATE UNIQUE INDEX idx_items_pinned_slot
                ON clipboard_items(pinned_slot)
                WHERE pinned_slot IS NOT NULL
            """)
        }

        return migrator
    }
}
