#[macro_use]
extern crate rocket;

pub mod auth;
mod database;
pub mod packages;

#[get("/")]
fn index() -> &'static str {
    "Hello, world!"
}

#[launch]
fn rocket() -> _ {
    rocket::build()
        .mount("/", routes![index])
        .attach(database::stage())
}
