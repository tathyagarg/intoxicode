use std::path::Path;
use std::{io::Write, pin::Pin};

use clap::{Args, Parser, Subcommand};
use futures::future::{BoxFuture, FutureExt};
use reqwest;
use tokio;

use flate2::read::GzDecoder;
use tar::Archive;

#[derive(Parser)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    Deps {},
    Install(InstallArgs),
    Uninstall { package: String },
    List { include_versions: bool },
}

#[derive(Args)]
struct InstallArgs {
    package: String,

    #[clap(short, long, default_value = "latest")]
    version: String,
}

#[allow(dead_code)]
#[derive(serde::Deserialize)]
struct PackageInfo {
    name: String,
    version: String,
    description: String,
    author: String,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let api_root = std::env::var("API_ROOT").unwrap_or_else(|_| "".to_string());

    let args = Cli::parse();

    match args.command {
        Commands::Install(install_args) => {
            let package_info = reqwest::get(format!(
                "{}/packages/info/{}?limit=1",
                api_root, install_args.package
            ))
            .await?
            .json::<Vec<PackageInfo>>()
            .await?;

            let actual_version = &package_info.first().unwrap().version;

            install_dependency(api_root, install_args.package, actual_version.to_string()).await;

            // let body = reqwest::get(format!(
            //     "{}/packages/download/{}/{}",
            //     api_root, install_args.package, install_args.version
            // ))
            // .await?
            // .bytes()
            // .await?;

            // let fname = format!("deps/{}.tar.gz", install_args.package);

            // std::fs::write(fname.clone(), &body)?;

            // let tar_gz = std::fs::File::open(fname.clone())?;
            // let decompressor = GzDecoder::new(tar_gz);
            // let mut archive = Archive::new(decompressor);
            // archive.unpack("deps")?;

            // std::fs::remove_file(fname)?;

            // let new_line = format!("{}:{}\n", install_args.package, actual_version);
            // let manifest = Path::new("manifest.txt");

            // if manifest.exists() {
            //     let mut file = std::fs::OpenOptions::new()
            //         .write(true)
            //         .append(true)
            //         .open(manifest)?;

            //     writeln!(file, "{}", new_line.trim())?;
            // } else {
            //     std::fs::write(manifest, new_line)?;
            // }
        }
        Commands::Uninstall { package } => {}
        Commands::List { include_versions } => {
            if include_versions {
                println!("Listing all packages with versions...");
            } else {
                println!("Listing all packages...");
            }
        }
        Commands::Deps {} => {
            println!("Installing all dependencies in manifest.txt...")
        }
    }

    Ok(())
}

pub fn install_dependency(
    api_root: String,
    package: String,
    version: String,
) -> BoxFuture<'static, ()> {
    async move {
        let body = reqwest::get(format!(
            "{}/packages/download/{}/{}",
            api_root, package, version
        ))
        .await
        .unwrap()
        .bytes()
        .await
        .unwrap();

        let fname = format!("deps/{}.tar.gz", package);

        std::fs::write(fname.clone(), &body).unwrap();

        let tar_gz = std::fs::File::open(fname.clone()).unwrap();
        let decompressor = GzDecoder::new(tar_gz);
        let mut archive = Archive::new(decompressor);
        archive.unpack("deps").unwrap();

        std::fs::remove_file(fname).unwrap();

        let new_line = format!("{}:{}\n", package, version);
        let manifest = Path::new("manifest.txt");
        if manifest.exists() {
            let mut file = std::fs::OpenOptions::new()
                .write(true)
                .append(true)
                .open(manifest)
                .unwrap();

            writeln!(file, "{}", new_line.trim()).unwrap();
        } else {
            std::fs::write(manifest, new_line).unwrap();
        }

        let dep_manifest = format!("deps/{}/manifest.txt", package);
        if Path::new(&dep_manifest).exists() {
            let contents = std::fs::read_to_string(dep_manifest).unwrap();
            for line in contents.lines() {
                let mut parts = line.split(':');
                let dep_name = parts.next().unwrap().to_string();
                let dep_version = parts.next().unwrap().to_string();
                install_dependency(api_root.clone(), dep_name, dep_version).await;
            }
        }
    }
    .boxed()
}
