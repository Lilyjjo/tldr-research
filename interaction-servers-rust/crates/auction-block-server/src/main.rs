use std::{collections::HashMap, process::ExitCode, str::FromStr};

use alloy_primitives::{Address, Bytes, FixedBytes, B256, U16, U160, U256};
use auction_block_server::BlockServer;
use color_eyre::{eyre, eyre::Context};
use suave_rust::amm_auction_suapp::{self, AmmAuctionSuapp};

#[tokio::main]
async fn main() {
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
            std::env::var("FUNDED_ADDRESS_SUAVE").expect("FUNDED_ADDRESS_SUAVE env var not set"),
            std::env::var("FUNDED_PRIVATE_KEY_SUAVE")
                .expect("FUNDED_PRIVATE_KEY_SUAVE env var not set"),
        ),
    );
    eoas.insert(
        "suapp_signing_key".to_string(),
        (
            std::env::var("FUNDED_ADDRESS_SEPOLIA_PUT_IN_SUAPP")
                .expect("FUNDED_ADDRESS_SEPOLIA_PUT_IN_SUAPP env var not set"),
            std::env::var("FUNDED_PRIVATE_KEY_SEPOLIA_PUT_IN_SUAPP")
                .expect("FUNDED_PRIVATE_KEY_SEPOLIA_PUT_IN_SUAPP env var not set"),
        ),
    );
    eoas.insert(
        "alice".to_string(),
        (
            std::env::var("FUNDED_ADDRESS_SEPOLIA_0")
                .expect("FUNDED_ADDRESS_SEPOLIA_0 env var not set"),
            std::env::var("FUNDED_PRIVATE_KEY_SEPOLIA_0")
                .expect("FUNDED_PRIVATE_KEY_SEPOLIA_0 env var not set"),
        ),
    );
    eoas.insert(
        "bob".to_string(),
        (
            std::env::var("FUNDED_ADDRESS_SEPOLIA_1")
                .expect("FUNDED_ADDRESS_SEPOLIA_1 env var not set"),
            std::env::var("FUNDED_PRIVATE_KEY_SEPOLIA_1")
                .expect("FUNDED_PRIVATE_KEY_SEPOLIA_1 env var not set"),
        ),
    );
    eoas.insert(
        "caleb".to_string(),
        (
            std::env::var("FUNDED_ADDRESS_SEPOLIA_2")
                .expect("FUNDED_ADDRESS_SEPOLIA_2 env var not set"),
            std::env::var("FUNDED_PRIVATE_KEY_SEPOLIA_2")
                .expect("FUNDED_PRIVATE_KEY_SEPOLIA_2 env var not set"),
        ),
    );

    let amm_auction_wrapper = AmmAuctionSuapp::new(
        std::env::var("SUAPP_AMM").expect("SUAPP_AMM env var not set"),
        std::env::var("AUCTION_DEPOSITS").expect("AUCTION_DEPOSITS env var not set"),
        std::env::var("POOL").expect("POOL env var not set"),
        std::env::var("TOKEN_0").expect("TOKEN_0 env var not set"),
        std::env::var("TOKEN_1").expect("TOKEN_1 env var not set"),
        std::env::var("SWAP_ROUTER").expect("SWAP_ROUTER env var not set"),
        std::env::var("EXECUTION_NODE").expect("EXECUTION_NODE env var not set"),
        std::env::var("RPC_URL_SUAVE").expect("RPC_URL_SUAVE env var not set"),
        std::env::var("RPC_URL_SEPOLIA").expect("RPC_URL_SEPOLIA env var not set"),
        &eoas,
    )
    .await
    .expect("failed to build amm auction wrapper");

    let rpc_url: String = std::env::var("WSS_SEPOLIA").expect("WSS_SEPOLIA env var not set");

    // setup block server
    let block_server = BlockServer::new(rpc_url)
        .await
        .expect("failed to create new block server")
        .run_until_stopped(amm_auction_wrapper)
        .await
        .expect("failed to start block server");

    block_server.await.unwrap();
}
