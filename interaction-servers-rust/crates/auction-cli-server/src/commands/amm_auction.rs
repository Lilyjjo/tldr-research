use color_eyre::{
    eyre,
    eyre::{
        ensure,
        eyre,
        Context,
    },
};
use suave_rust::amm_auction_suapp::AmmAuctionSuapp;

use crate::cli::amm_auction::{
    AuctionArgs,
    BidArgs,
    SwapArgs,
};

pub(crate) async fn trigger_auction(
    args: &AuctionArgs,
    amm_auction: &AmmAuctionSuapp,
) -> eyre::Result<()> {
    // TODO write
    println!("auction cli logic");
    Ok(())
}

pub(crate) async fn send_bid(args: &BidArgs, amm_auction: &AmmAuctionSuapp) -> eyre::Result<()> {
    // TODO write
    println!("bid cli logic");
    Ok(())
}

pub(crate) async fn send_swap_tx(
    args: &SwapArgs,
    amm_auction: &AmmAuctionSuapp,
) -> eyre::Result<()> {
    // TODO write
    println!("swap cli logic");
    Ok(())
}
