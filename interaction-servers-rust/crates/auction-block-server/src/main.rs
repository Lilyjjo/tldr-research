use auction_block_server::BlockServer;
use color_eyre::eyre::Context;
use suave_rust::{amm_auction_config::AmmAuctionConfig, amm_auction_suapp::AmmAuctionSuapp};

#[tokio::main]
async fn main() {
    let config = AmmAuctionConfig::new("../poc_first_swap_auction/.env")
        .await
        .expect("failed to build auction amm config");

    let amm_auction_wrapper = AmmAuctionSuapp::new_from_config(config.clone())
        .await
        .wrap_err("failed to build amm auction suapp wrapper")
        .expect("failed to build amm auction suapp wrapper");

    // setup block server
    let block_server = BlockServer::new(config.wss_l1)
        .await
        .expect("failed to create new block server")
        .run_until_stopped(amm_auction_wrapper)
        .await
        .expect("failed to start block server");

    block_server.await.unwrap();
}
