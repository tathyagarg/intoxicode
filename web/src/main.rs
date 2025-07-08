mod docs;

use dioxus::prelude::*;

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
}

const FAVICON: Asset = asset!("/assets/favicon.ico");
const MAIN_CSS: Asset = asset!("/assets/main.css");
const TAILWIND_CSS: Asset = asset!("/assets/tailwind.css");

fn main() {
    dioxus::launch(App);
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
            class: "flex items-center gap-8 px-8! py-4! bg-(--ctp-mantle)",
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
