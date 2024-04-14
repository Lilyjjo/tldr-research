use std::io::Bytes;

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
    println!("new bid logic");
    amm_auction
        .new_bid(
            &args.bidder,
            args.target_block,
            args.bid_amount,
            args.swap_amount,
            args.token_0_in,
        )
        .await
        .wrap_err("failed to send bid ccr")?;
    println!("fin");
    Ok(())
}

pub(crate) async fn send_swap_tx(
    args: &SwapArgs,
    amm_auction: &AmmAuctionSuapp,
) -> eyre::Result<()> {
    // TODO write
    println!("new pending transaction logic");
    amm_auction
        .new_pending_txn(&args.swapper, vec![0u8; 32].into())
        .await
        .wrap_err("failed to send swap tx ccr")?;
    println!("fin");
    Ok(())
}
