use crate::Route;

use dioxus::prelude::*;
use gloo_net::http::Request;
use serde::Deserialize;

#[derive(Deserialize, Debug)]
struct Documents {
    pages: Vec<Document>,
}

#[derive(Deserialize, Debug)]
struct Document {
    path: String,
    title: String,
}

#[component]
pub fn DocsLayout() -> Element {
    let docs_list = use_resource(|| async move {
        const ASSET: Asset = asset!("/assets/docs/map.json");

        let paths = Request::get(ASSET.to_string().as_str())
            .send()
            .await?
            .json::<Documents>()
            .await;
        println!("Paths: {:?}", paths);

        paths
    });

    rsx! {
        div {
            class: "flex flex-row h-screen",
            div {
                class: "flex-1 bg-(--ctp-mantle) p-2!",
                {
                    let result = docs_list.read();
                    match &*result {
                        Some(Ok(paths)) => {
                            rsx! {
                                h1 { "Documentation" }
                                ul {
                                    class: "list-disc pl-4",
                                    {
                                        paths.pages.iter().map(|doc| {
                                            rsx! {
                                                li {
                                                    class: "py-2",
                                                    Link {
                                                        to: Route::Doc { doc_name: doc.path.clone() },
                                                        class: "hover:text-white!",
                                                        "{doc.title}"
                                                    }
                                                }
                                            }
                                        })
                                    }
                                }
                            }
                        },
                        Some(Err(e)) => rsx! { h1 { "Error fetching paths: {e}" } },
                        None => rsx! { h1 { "Loading..." } },
                    }
                }
            }
            div {
                class: "flex-3 bg-(--ctp-base) p-4",
                "meow"
                Outlet::<Route> {}
            }
        }
    }
}

#[component]
pub fn Docs() -> Element {
    rsx! {
        div {
            class: "docs",
            h1 { "Docs" }
            p { "This is the documentation page." }
        }
    }
}

#[component]
pub fn Doc(doc_name: String) -> Element {
    rsx! {
        div {
            class: "doc",
            h1 { "Doc: {doc_name}" }
            p { "This is the documentation for {doc_name}." }
        }
    }
}
