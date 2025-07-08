use crate::Route;

use dioxus::prelude::*;
use gloo_net::http::Request;

#[component]
pub fn DocsLayout() -> Element {
    let docs_list = use_resource(|| async move {
        const ASSET: Asset = asset!("/assets/docs/01_doc_1.md");

        let paths = Request::get(ASSET.to_string().as_str())
            .send()
            .await?
            .text()
            .await;
        println!("Paths: {:?}", paths);

        paths
    });

    rsx! {
        div {
            class: "docs-layout",
            header {
                class: "docs-header",
                h1 { "Documentation" },
                div {
                    class: "docs-nav",
                    {
                        let result = docs_list.read();
                        match &*result {
                            Some(Ok(paths)) => rsx! { h1 { "found paths: {paths}" } },
                            Some(Err(e)) => rsx! { h1 { "Error fetching paths: {e}" } },
                            None => rsx! { h1 { "Loading..." } },
                        }
                    }
                    Outlet::<Route> {}
                }
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
