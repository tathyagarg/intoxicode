use rocket::http::CookieJar;
use rocket::response::{content, status};
use rocket::serde::json::Json;
use rocket::serde::{self, Deserialize, Serialize};

use diesel::prelude::*;

use crate::auth::verify_jwt;
use crate::database::PackagesDb;

type Result<T, E = rocket::response::Debug<rocket::http::Status>> = std::result::Result<T, E>;

#[derive(Queryable, Selectable, Serialize, Deserialize, Insertable)]
#[serde(crate = "rocket::serde")]
#[diesel(table_name = packages)]
struct Package {
    name: String,
    version: String,
    description: String,
    author: Option<String>,
}

#[derive(Deserialize, Serialize, Insertable)]
#[serde(crate = "rocket::serde")]
#[diesel(table_name = packages)]
pub struct PackageInsert {
    name: String,
    version: String,
    description: String,
}

table! {
    packages (name) {
        name -> Text,
        version -> Text,
        description -> Text,
        author -> Nullable<Text>,
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

#[derive(Deserialize, Serialize)]
#[serde(crate = "rocket::serde")]
pub struct CreatePackageData {
    token: String,
    package_data: PackageInsert,
}

#[post("/packages", data = "<package_data>")]
pub async fn create_package(
    db: PackagesDb,
    package_data: Json<PackageInsert>,
    cookies: &CookieJar<'_>,
) -> Result<status::Custom<content::RawJson<String>>> {
    let token = cookies
        .get("auth_token")
        .map(|cookie| cookie.value().to_string())
        .unwrap_or_else(|| "".to_string());

    let verification_result = verify_jwt(&token);

    if verification_result.is_err() {
        return Ok(status::Custom(
            rocket::http::Status::Unauthorized,
            content::RawJson("{\"error\": \"Invalid or expired token\"}".to_string()),
        ));
    }

    let author_username = verification_result.unwrap();

    let package = Package {
        name: package_data.name.clone(),
        version: package_data.version.clone(),
        description: package_data.description.clone(),
        author: Some(author_username.clone()),
    };

    let res = db
        .run(move |conn| {
            diesel::insert_into(packages::table)
                .values(&package)
                .execute(conn)
        })
        .await;

    if res.is_err() {
        return Err(rocket::response::Debug(
            rocket::http::Status::InternalServerError,
        ));
    }

    Ok(status::Custom(
        rocket::http::Status::Created,
        content::RawJson("{\"message\": \"Package created successfully\"}".to_string()),
    ))
}
