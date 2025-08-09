use rocket::response::{content, status};
use rocket::serde::json::Json;
use rocket::serde::{self, Deserialize, Serialize};
use serde_json::json;

use hmac::{Hmac, Mac};
use jwt::{AlgorithmType, Header, SignWithKey, Token, VerifyWithKey};
use sha2::Sha384;
use std::collections::BTreeMap;

use argon2::{
    Argon2,
    password_hash::{PasswordHash, PasswordHasher, PasswordVerifier, SaltString, rand_core::OsRng},
};

use diesel::prelude::*;

use crate::database::PackagesDb;

type Result<T, E = rocket::response::Debug<rocket::http::Status>> = std::result::Result<T, E>;

const DEFAULT_TOKEN_EXPIRATION_SECS: u64 = 60 * 60;

#[derive(Serialize, Deserialize, Insertable, Clone, Queryable, Debug)]
#[serde(crate = "rocket::serde")]
#[diesel(table_name = users)]
struct User {
    username: String,
    salt: String,
    password: String,
}

#[derive(FromForm, Deserialize, Serialize)]
#[serde(crate = "rocket::serde")]
pub struct SignupForm {
    username: String,
    password: String,
}

table! {
    users (username) {
        username -> Text,
        salt -> Text,
        password -> Text,
    }
}

#[post("/signup", data = "<user>")]
pub async fn signup(
    db: PackagesDb,
    user: Json<SignupForm>,
) -> Result<status::Custom<content::RawJson<String>>> {
    let argon2 = Argon2::default();
    let salt = SaltString::generate(&mut OsRng);

    let password_hash = argon2
        .hash_password(user.password.as_bytes(), &salt)
        .unwrap();

    let user_object = User {
        username: user.username.clone(),
        salt: salt.to_string(),
        password: password_hash.to_string(),
    };

    let res = db
        .run(move |conn| {
            diesel::insert_into(users::table)
                .values(&user_object)
                .execute(conn)
        })
        .await;

    if res.is_err() {
        return Err(rocket::response::Debug(
            rocket::http::Status::InternalServerError,
        ));
    }

    let token = issue_jwt(user.username.clone(), DEFAULT_TOKEN_EXPIRATION_SECS);

    Ok(status::Custom(
        rocket::http::Status::Created,
        content::RawJson(
            serde::json::to_string(&json!({
                "message": "User created successfully",
                "username": user.username,
                "token": token,
            }))
            .unwrap_or_else(|_| "{\"error\": \"Serialization error\"}".to_string()),
        ),
    ))
}

#[post("/login", data = "<user>")]
pub async fn login(
    db: PackagesDb,
    user: Json<SignupForm>,
) -> Result<status::Custom<content::RawJson<String>>> {
    let password = user.password.clone();

    let user_record = db
        .run(move |conn| {
            users::table
                .filter(users::username.eq(&user.username))
                .first(conn)
        })
        .await
        .map(Json::<User>)
        .ok();

    if user_record.is_none() {
        return Ok(status::Custom(
            rocket::http::Status::Unauthorized,
            content::RawJson(
                serde_json::to_string(&json!({
                    "error": "Invalid username or password"
                }))
                .unwrap_or_else(|_| "{\"error\": \"Serialization error\"}".to_string()),
            ),
        ));
    }

    let user_record = user_record.unwrap();
    let argon2 = Argon2::default();
    let parsed_hash = PasswordHash::new(&user_record.password).unwrap();
    if argon2
        .verify_password(password.as_bytes(), &parsed_hash)
        .is_ok()
    {
        let token = issue_jwt(user_record.username.clone(), DEFAULT_TOKEN_EXPIRATION_SECS);

        Ok(status::Custom(
            rocket::http::Status::Ok,
            content::RawJson(
                serde_json::to_string(&json!({
                    "message": "Login successful",
                    "username": user_record.username,
                    "token": token,
                }))
                .unwrap_or_else(|_| "{\"error\": \"Serialization error\"}".to_string()),
            ),
        ))
    } else {
        Ok(status::Custom(
            rocket::http::Status::Unauthorized,
            content::RawJson(
                serde_json::to_string(&json!({
                    "error": "Invalid username or password"
                }))
                .unwrap_or_else(|_| "{\"error\": \"Serialization error\"}".to_string()),
            ),
        ))
    }
}

fn get_key() -> Hmac<Sha384> {
    Hmac::new_from_slice(b"secret_key").expect("Failed to create HMAC key")
}

pub fn issue_jwt(username: String, expiration: u64) -> String {
    let key = get_key();

    let mut claims = BTreeMap::new();
    claims.insert("sub", username);
    claims.insert(
        "exp",
        (std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs()
            + expiration)
            .to_string(),
    );

    let header = Header {
        algorithm: AlgorithmType::Hs384,
        ..Default::default()
    };

    let token = Token::new(header, claims).sign_with_key(&key).unwrap();

    token.as_str().to_string()
}

pub fn verify_jwt(token_str: &String) -> Result<String> {
    let key = get_key();

    let token_result = token_str.as_str().verify_with_key(&key);

    if token_result.is_err() {
        return Err(rocket::response::Debug(rocket::http::Status::Unauthorized));
    }

    let token: Token<Header, BTreeMap<String, String>, _> = token_result.unwrap();

    let claims = token.claims();
    let sub = claims.get("sub").cloned().unwrap_or_default();

    let exp = claims
        .get("exp")
        .and_then(|s| s.parse::<u64>().ok())
        .unwrap_or(0);

    let current_time = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_secs();

    if exp < current_time {
        return Err(rocket::response::Debug(rocket::http::Status::Unauthorized));
    }

    Ok(sub)
}
