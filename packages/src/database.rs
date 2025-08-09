use rocket::fairing::AdHoc;
use rocket::{Build, Rocket};
use rocket_sync_db_pools::database;

use crate::{auth, packages};

#[database("packages")]
pub struct PackagesDb(diesel::SqliteConnection);

async fn run_migrations(rocket: Rocket<Build>) -> Rocket<Build> {
    use diesel_migrations::{EmbeddedMigrations, MigrationHarness, embed_migrations};

    const MIGRATIONS: EmbeddedMigrations = embed_migrations!("db/migrations");

    PackagesDb::get_one(&rocket)
        .await
        .expect("Failed to get database connection")
        .run(|conn| {
            conn.run_pending_migrations(MIGRATIONS)
                .map(|outputs| {
                    for output in outputs {
                        println!("Migration output: {}", output);
                    }
                })
                .expect("Failed to run migrations");
        })
        .await;

    rocket
}

pub fn stage() -> AdHoc {
    AdHoc::on_ignite("Database Stage", |rocket| async {
        rocket
            .attach(PackagesDb::fairing())
            .attach(AdHoc::on_ignite("Run Migrations", run_migrations))
            .mount(
                "/",
                routes![packages::get_packages, packages::create_package],
            )
            .mount("/auth", routes![auth::signup, auth::login])
    })
}
