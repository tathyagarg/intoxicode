use rocket::response::Debug;
use rocket::response::{content, status};
use rocket::serde::{self, Deserialize, Serialize};

use diesel::prelude::*;

use crate::database::PackagesDb;

type Result<T, E = Debug<diesel::result::Error>> = std::result::Result<T, E>;

#[derive(Queryable, Selectable, Serialize, Deserialize, Insertable)]
#[serde(crate = "rocket::serde")]
#[diesel(table_name = packages)]
struct Package {
    name: String,
    version: String,
    description: String,
}

#[derive(Deserialize, Serialize, Insertable)]
#[serde(crate = "rocket::serde")]
#[diesel(table_name = packages)]
struct PackageInsert {
    name: String,
    version: String,
    description: String,
}

table! {
    packages (name) {
        name -> Text,
        version -> Text,
        description -> Text,
    }
}

#[get("/packages?<limit>&<page>")]
pub async fn get_packages(
    db: PackagesDb,
    limit: Option<i64>,
    page: Option<i64>,
) -> Result<status::Custom<content::RawJson<String>>> {
    if (page == Some(0)) || (limit == Some(0)) {
        return Ok(status::Custom(
            rocket::http::Status::BadRequest,
            content::RawJson("{\"error\": \"Page and limit must be greater than 0\"}".to_string()),
        ));
    }

    let limit = limit.unwrap_or(10);
    let page = page.unwrap_or(1);

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
