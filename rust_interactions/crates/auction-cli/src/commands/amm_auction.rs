use std::time::{SystemTime, UNIX_EPOCH};

use auction_interface::amm_auction::AuctionSuapp;
use color_eyre::{eyre, eyre::Context};

use crate::cli::amm_auction::{
    AddSwapsArgs, AuctionArgs, AuctionStatsArgs, BidArgs, InitializeSuappArgs, SwapArgs,
};

pub(crate) async fn trigger_auction(
    _args: &AuctionArgs,
    amm_auction: &mut AuctionSuapp,
) -> eyre::Result<()> {
    println!("auction cli logic");
    amm_auction
        .trigger_auction()
        .await
        .wrap_err("failed to send bid ccr")?;
    println!("fin");
    amm_auction
        .print_auction_stats()
        .await
        .wrap_err("failed to print auction stats")?;
    Ok(())
}

pub(crate) async fn send_bid(args: &BidArgs, amm_auction: &mut AuctionSuapp) -> eyre::Result<()> {
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
    amm_auction: &mut AuctionSuapp,
) -> eyre::Result<()> {
    println!("new pending transaction logic");
    amm_auction
        .new_pending_txn(&args.swapper, args.swap_amount, args.token_0_in)
        .await
        .wrap_err("failed to send swap tx ccr")?;
    println!("fin");
    Ok(())
}

pub(crate) async fn initialize_suapp(
    _args: &InitializeSuappArgs,
    amm_auction: &mut AuctionSuapp,
) -> eyre::Result<()> {
    println!("new suapp initialization logic");
    // initialize the suapp's Confidential Store logic for the L1 Block, L1's URL, and signing
    // key
    amm_auction
        .clear_swaps()
        .await
        .wrap_err("failed to send clear swaps ccr")?;
    println!("cleared pending swaps");
    amm_auction
        .initialize_l1_block()
        .await
        .wrap_err("failed to send l1 block initialize ccr")?;
    println!("initialized l1 block");
    amm_auction
        .set_l1_url()
        .await
        .wrap_err("failed to send L1 init ccr")?;
    println!("set l1 url");
    amm_auction
        .set_bundle_url()
        .await
        .wrap_err("failed to send L1 init ccr")?;
    println!("set bundle url");
    amm_auction
        .set_signing_key()
        .await
        .wrap_err("failed to send signing key init ccr")?;
    println!("set suave signing key");
    send_swaps(amm_auction)
        .await
        .context("failed to send swaps")?;
    println!("fin setup");

    Ok(())
}

fn get_random_amount() -> u128 {
    let seed = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .expect("Time went backwards")
        .as_micros();

    (seed % 100) + 1
}

async fn send_swaps(amm_auction: &mut AuctionSuapp) -> eyre::Result<()> {
    println!("adding swaps");

    let mut swap_amount = get_random_amount();
    let mut token_0_in = swap_amount % 2 == 0;
    if let Err(e) = amm_auction
        .new_pending_txn(&"swapper_0".to_string(), swap_amount, token_0_in)
        .await
    {
        println!("--> !!! failed to send swap for swapper_0: {:?}", e);
    } else {
        println!("--> sent swap for swapper_0 for: {}", swap_amount);
    }
    swap_amount = get_random_amount();
    token_0_in = swap_amount % 2 == 0;
    if let Err(e) = amm_auction
        .new_pending_txn(&"swapper_1".to_string(), swap_amount, token_0_in)
        .await
    {
        println!("--> !!! failed to send swap for swapper_1: {:#?}", e);
    } else {
        println!("--> sent swap for swapper_1 for: {}", swap_amount);
    }
    swap_amount = get_random_amount();
    token_0_in = swap_amount % 2 == 0;
    if let Err(e) = amm_auction
        .new_pending_txn(&"swapper_2".to_string(), swap_amount, token_0_in)
        .await
    {
        println!("--> !!! failed to send swap for swapper_2: {:?}", e);
    } else {
        println!("--> sent swap for swapper_2 for: {}", swap_amount);
    }

    Ok(())
}

pub(crate) async fn add_swaps(
    _args: &AddSwapsArgs,
    amm_auction: &mut AuctionSuapp,
) -> eyre::Result<()> {
    send_swaps(amm_auction)
        .await
        .context("failed to send swaps")?;

    Ok(())
}

pub(crate) async fn auction_stats(
    _args: &AuctionStatsArgs,
    amm_auction: &mut AuctionSuapp,
) -> eyre::Result<()> {
    amm_auction
        .print_auction_stats()
        .await
        .wrap_err("failed to print auction stats")?;
    Ok(())
}
