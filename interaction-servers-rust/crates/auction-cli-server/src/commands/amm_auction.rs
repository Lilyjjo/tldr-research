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
    InitializeSuappArgs,
    SwapArgs,
};

pub(crate) async fn trigger_auction(
    _args: &AuctionArgs,
    amm_auction: &mut AmmAuctionSuapp,
) -> eyre::Result<()> {
    println!("auction cli logic");
    amm_auction
        .trigger_auction()
        .await
        .wrap_err("failed to send bid ccr")?;
    println!("fin");
    Ok(())
}

pub(crate) async fn send_bid(
    args: &BidArgs,
    amm_auction: &mut AmmAuctionSuapp,
) -> eyre::Result<()> {
    println!("new bid logic");
    amm_auction
        .new_bid(
            &args.bidder,
            10000000000, // TODO figure out what a good automation is
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
    amm_auction: &mut AmmAuctionSuapp,
) -> eyre::Result<()> {
    println!("new pending transaction logic");
    amm_auction
        .new_pending_txn(&args.swapper, vec![0u8; 32].into())
        .await
        .wrap_err("failed to send swap tx ccr")?;
    println!("fin");
    Ok(())
}

pub(crate) async fn initialize_suapp(
    _args: &InitializeSuappArgs,
    amm_auction: &mut AmmAuctionSuapp,
) -> eyre::Result<()> {
    println!("new suapp initialization logic");
    // initialize the suapp's Confidential Store logic for the L1 Block, Sepolia's URL, and signing
    // key
    amm_auction
        .initialize_l1_block()
        .await
        .wrap_err("failed to send l1 block initialize ccr")?;
    amm_auction
        .set_sepolia_url()
        .await
        .wrap_err("failed to send sepolia init ccr")?;
    amm_auction
        .set_signing_key()
        .await
        .wrap_err("failed to send signing key init ccr")?;
    println!("fin");
    Ok(())
}
