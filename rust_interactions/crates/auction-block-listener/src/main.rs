use auction_block_listener::BlockServer;
use auction_interface::{amm_auction::AuctionSuapp, amm_auction_config::AmmAuctionConfig};
use color_eyre::eyre::Context;

#[tokio::main]
async fn main() {
    let config = AmmAuctionConfig::new("../solidity_code/.env")
        .await
        .expect("failed to build auction amm config");

    let amm_auction_wrapper = AuctionSuapp::new_from_config(config.clone())
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
