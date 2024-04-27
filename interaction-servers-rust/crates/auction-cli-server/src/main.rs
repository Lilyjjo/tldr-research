use std::{collections::HashMap, process::ExitCode, str::FromStr};

use alloy_primitives::{Address, Bytes, FixedBytes, B256, U16, U160, U256};
use auction_cli_server::{cli::Cli, commands};
use color_eyre::{eyre, eyre::Context};
use suave_rust::amm_auction_suapp::AmmAuctionSuapp;

fn main() -> ExitCode {
    if let Err(err) = run() {
        eprintln!("{err:?}");
        return ExitCode::FAILURE;
    }

    ExitCode::SUCCESS
}

// Run our asynchronous command code in a blocking manner
fn run() -> eyre::Result<()> {
    let rt = tokio::runtime::Runtime::new().wrap_err("failed to create a new runtime")?;

    rt.block_on(async_main())
}

async fn async_main() -> eyre::Result<()> {
    // load environment variables
    let env_file = if !cfg!(feature = "local") {
        "local.env"
    } else {
        "rigil.env"
    };
    println!("env file in use: {}", env_file);
    dotenv::from_filename(env_file).ok();

    // collect CLI EOA entities
    let mut eoas = HashMap::<String, (String, String)>::new();
    eoas.insert(
        "funded_suave".to_string(),
        (
            std::env::var("FUNDED_ADDRESS_SUAVE")
                .wrap_err("FUNDED_ADDRESS_SUAVE env var not set")?,
            std::env::var("FUNDED_PRIVATE_KEY_SUAVE")
                .wrap_err("FUNDED_PRIVATE_KEY_SUAVE env var not set")?,
        ),
    );
    eoas.insert(
        "suapp_signing_key".to_string(),
        (
            std::env::var("FUNDED_ADDRESS_SEPOLIA_PUT_IN_SUAPP")
                .wrap_err("FUNDED_ADDRESS_SEPOLIA_PUT_IN_SUAPP env var not set")?,
            std::env::var("FUNDED_PRIVATE_KEY_SEPOLIA_PUT_IN_SUAPP")
                .wrap_err("FUNDED_PRIVATE_KEY_SEPOLIA_PUT_IN_SUAPP env var not set")?,
        ),
    );
    eoas.insert(
        "alice".to_string(),
        (
            std::env::var("FUNDED_ADDRESS_SEPOLIA_0")
                .wrap_err("FUNDED_ADDRESS_SEPOLIA_0 env var not set")?,
            std::env::var("FUNDED_PRIVATE_KEY_SEPOLIA_0")
                .wrap_err("FUNDED_PRIVATE_KEY_SEPOLIA_0 env var not set")?,
        ),
    );
    eoas.insert(
        "bob".to_string(),
        (
            std::env::var("FUNDED_ADDRESS_SEPOLIA_1")
                .wrap_err("FUNDED_ADDRESS_SEPOLIA_1 env var not set")?,
            std::env::var("FUNDED_PRIVATE_KEY_SEPOLIA_1")
                .wrap_err("FUNDED_PRIVATE_KEY_SEPOLIA_1 env var not set")?,
        ),
    );
    eoas.insert(
        "caleb".to_string(),
        (
            std::env::var("FUNDED_ADDRESS_SEPOLIA_2")
                .wrap_err("FUNDED_ADDRESS_SEPOLIA_2 env var not set")?,
            std::env::var("FUNDED_PRIVATE_KEY_SEPOLIA_2")
                .wrap_err("FUNDED_PRIVATE_KEY_SEPOLIA_2 env var not set")?,
        ),
    );

    let amm_auction_wrapper = AmmAuctionSuapp::new(
        std::env::var("SUAPP_AMM").wrap_err("SUAPP_AMM env var not set")?,
        std::env::var("AUCTION_DEPOSITS").wrap_err("AUCTION_DEPOSITS env var not set")?,
        std::env::var("POOL").wrap_err("POOL env var not set")?,
        std::env::var("TOKEN_0").wrap_err("TOKEN_0 env var not set")?,
        std::env::var("TOKEN_1").wrap_err("TOKEN_1 env var not set")?,
        std::env::var("SWAP_ROUTER").wrap_err("SWAP_ROUTER env var not set")?,
        std::env::var("EXECUTION_NODE").wrap_err("EXECUTION_NODE env var not set")?,
        std::env::var("RPC_URL_SUAVE").wrap_err("RPC_URL_SUAVE env var not set")?,
        std::env::var("RPC_URL_SEPOLIA").wrap_err("RPC_URL_SEPOLIA env var not set")?,
        &eoas,
    )
    .await
    .expect("failed to build amm auction wrapper");

    let args = Cli::get_args()?;
    commands::run(args, amm_auction_wrapper).await
}
