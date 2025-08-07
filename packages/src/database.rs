use rocket::fairing::AdHoc;
use rocket::response::Debug;
use rocket::response::{content, status};
use rocket::serde::{self, Serialize};
use rocket::{Build, Rocket};
use rocket_sync_db_pools::database;

use diesel::prelude::*;

// #[derive(Database)]
#[database("packages")]
struct PackagesDb(diesel::SqliteConnection);

type Result<T, E = Debug<diesel::result::Error>> = std::result::Result<T, E>;

#[derive(Queryable, Selectable, Serialize)]
#[serde(crate = "rocket::serde")]
#[diesel(table_name = packages)]
struct Package {
    id: i32,
    name: String,
    version: String,
    description: String,
}

table! {
    packages (id) {
        id -> Integer,
        name -> Text,
        version -> Text,
        description -> Text,
    }
}

#[get("/packages?<limit>&<page>")]
async fn get_packages(
    db: PackagesDb,
    limit: i64,
    page: i64,
) -> Result<status::Custom<content::RawJson<String>>> {
    if (page == 0) || (limit == 0) {
        return Ok(status::Custom(
            rocket::http::Status::BadRequest,
            content::RawJson("{\"error\": \"Page and limit must be greater than 0\"}".to_string()),
        ));
    }

    let offset = (page - 1) * limit;

    let data = db
        .run(move |conn| {
            packages::table
                .offset(offset)
                .limit(limit)
                .select(Package::as_select())
                .load(conn)
                .expect("Error loading data")
        })
        .await;

    Ok(status::Custom(
        rocket::http::Status::Ok,
        content::RawJson(
            serde::json::to_string(&data)
                .unwrap_or_else(|_| "{\"error\": \"Serialization error\"}".to_string()),
        ),
    ))
}

async fn run_migrations(rocket: Rocket<Build>) -> Rocket<Build> {
    use diesel_migrations::{EmbeddedMigrations, MigrationHarness, embed_migrations};

    const MIGRATIONS: EmbeddedMigrations = embed_migrations!("db/migrations");

    PackagesDb::get_one(&rocket)
        .await
        .expect("Failed to get database connection")
        .run(|conn| {
            conn.run_pending_migrations(MIGRATIONS)
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
            .mount("/", routes![get_packages])
    })
}
