mod docs;

use std::path::PathBuf;

use dioxus::prelude::*;

#[cfg(feature = "server")]
use tower_http::services::ServeDir;

#[derive(Debug, Clone, Routable, PartialEq)]
#[rustfmt::skip]
pub enum Route {
    #[layout(Navbar)]
        #[route("/")]
        Home {},
        #[nest("/docs")]
            #[layout(docs::DocsLayout)]
                #[route("/")]
                Docs {},

                #[route("/:doc_name")]
                Doc { doc_name: String },
}

const FAVICON: Asset = asset!("/assets/favicon.ico");
const MAIN_CSS: Asset = asset!("/assets/main.css");
const TAILWIND_CSS: Asset = asset!("/assets/tailwind.css");

fn main() {
    #[cfg(feature = "web")]
    dioxus::launch(App);

    #[cfg(feature = "server")]
    {
        tokio::runtime::Runtime::new()
            .unwrap()
            .block_on(async move {
                launch_server(App).await;
            });
    }
}

#[cfg(feature = "server")]
async fn launch_server(component: fn() -> Element) {
    use axum::routing::get_service;
    use std::net::{IpAddr, Ipv4Addr, SocketAddr};

    // Get the address the server should run on. If the CLI is running, the CLI proxies fullstack into the main address
    // and we use the generated address the CLI gives us
    let ip =
        dioxus::cli_config::server_ip().unwrap_or_else(|| IpAddr::V4(Ipv4Addr::new(127, 0, 0, 1)));
    let port = dioxus::cli_config::server_port().unwrap_or(8080);
    let address = SocketAddr::new(ip, port);
    let listener = tokio::net::TcpListener::bind(address).await.unwrap();

    let router = axum::Router::new()
        .nest_service("/posts", get_service(ServeDir::new("posts")))
        .serve_dioxus_application(ServeConfig::new().unwrap(), App)
        .into_make_service();
    axum::serve(listener, router).await.unwrap();
}

#[component]
fn App() -> Element {
    rsx! {
        document::Link { rel: "icon", href: FAVICON }
        document::Link { rel: "stylesheet", href: MAIN_CSS }
        document::Link { rel: "stylesheet", href: TAILWIND_CSS }
        Router::<Route> {}
    }
}

#[component]
fn Home() -> Element {
    rsx! {
        h1 { "ts home page" }
    }
}

#[component]
fn Docs() -> Element {
    rsx! {
        docs::Docs {}
    }
}

#[component]
fn Doc(doc_name: String) -> Element {
    rsx! {
        docs::Doc { doc_name: doc_name }
    }
}

#[component]
fn Navlink(to: Route, text: String) -> Element {
    rsx! {
        Link {
            to: to,
            class: "hover:text-white!",
            "{text}"
        }
    }
}

#[component]
fn Navbar() -> Element {
    rsx! {
        div {
            id: "navbar",
            class: "flex items-center gap-8 px-8! py-4! bg-(--ctp-mantle) border-b-2! border-(--ctp-surface1)!",
            Navlink{
                to: Route::Home {},
                text: "Home".to_string()
            }
            Navlink {
                to: Route::Docs {},
                text: "Docs".to_string()
            }
        }

        Outlet::<Route> {}
    }
}
