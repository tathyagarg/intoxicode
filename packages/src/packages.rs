use rocket::serde::json::Json;
use std::fs::File;

use diesel::result::DatabaseErrorKind;
use rocket::form::{Form, FromForm};
use rocket::fs::TempFile;
use rocket::http::CookieJar;
use rocket::response::{content, status};
use rocket::serde::{self, Deserialize, Serialize};

use tar::Archive;
// use async_tar::Archive;
// use tokio::io::BufReader;
use flate2::read::GzDecoder;
use std::io::BufReader;
use tokio::task;

use chrono::NaiveDateTime;
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
    timestamp: Option<NaiveDateTime>,
}

#[derive(Deserialize, Serialize, Insertable, Clone)]
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
        timestamp -> Nullable<Timestamp>,
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

#[derive(FromForm)]
pub struct UploadForm<'r> {
    json: Json<PackageInsert>,
    file: TempFile<'r>,
}

#[post("/packages", data = "<form>")]
pub async fn create_package(
    db: PackagesDb,
    mut form: Form<UploadForm<'_>>,
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

    let package_data: PackageInsert =
        <rocket::serde::json::Json<PackageInsert> as Clone>::clone(&form.json).into_inner();

    if package_data.version.chars().next() != Some('v') {
        return Ok(status::Custom(
            rocket::http::Status::BadRequest,
            content::RawJson("{\"error\": \"Version must start with 'v'\"}".to_string()),
        ));
    }

    let package = Package {
        name: package_data.name.clone(),
        version: package_data.version.clone(),
        description: package_data.description.clone(),
        author: Some(author_username.clone()),
        timestamp: None,
    };

    let fp = format!(
        "packages/{}-{}.tar.gz",
        package_data.name, package_data.version
    );

    if let Err(_) = form.file.persist_to(fp.clone()).await {
        return Err(rocket::response::Debug(
            rocket::http::Status::InternalServerError,
        ));
    }

    if let Err(e) = verify_tarball(fp.clone()).await {
        println!("Error verifying tarball: {:?}", e);
        let _ = std::fs::remove_file(fp);

        return Err(e);
    }

    let res = db
        .run(move |conn| {
            conn.transaction(|conn| {
                let res = diesel::insert_into(packages::table)
                    .values(&package)
                    .execute(conn);

                if res.is_err() {
                    match res.err().unwrap() {
                        diesel::result::Error::DatabaseError(err_type, _) => match err_type {
                            DatabaseErrorKind::UniqueViolation => {
                                return Err(diesel::result::Error::DatabaseError(
                                    DatabaseErrorKind::UniqueViolation,
                                    Box::new(
                                        "Package with this name and version already exists"
                                            .to_string(),
                                    ),
                                ));
                            }
                            _ => {
                                println!("Database error: {:?}", err_type);
                                return Err(diesel::result::Error::RollbackTransaction);
                            }
                        },
                        err => {
                            println!("Error inserting package: {:?}", err);
                            return Err(diesel::result::Error::RollbackTransaction);
                        }
                    }
                }

                Ok(())
            })
        })
        .await;

    if let Err(e) = res {
        let _ = std::fs::remove_file(fp);

        if let diesel::result::Error::DatabaseError(DatabaseErrorKind::UniqueViolation, _) = e {
            return Ok(status::Custom(
                rocket::http::Status::Conflict,
                content::RawJson(
                    "{\"error\": \"Package with this name and version already exists\"}"
                        .to_string(),
                ),
            ));
        }

        return Err(rocket::response::Debug(
            rocket::http::Status::InternalServerError,
        ));
    }

    Ok(status::Custom(
        rocket::http::Status::Created,
        content::RawJson("{\"message\": \"Package created successfully\"}".to_string()),
    ))
}

async fn verify_tarball(path: String) -> Result<(), rocket::response::Debug<rocket::http::Status>> {
    // just check if path ends with .tar.gz
    if !path.ends_with(".tar.gz") {
        return Err(rocket::response::Debug(rocket::http::Status::BadRequest));
    }

    Ok(())
}
